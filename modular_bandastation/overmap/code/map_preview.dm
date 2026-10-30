// AI EDIT START - overmap module integration
/** Local visual continuation of remote actors, terrain and lighting. */
/datum/stationtrauma_map_preview
	/// Stable coordinates survive turf replacement while the strip is being rebuilt.
	var/list/local_origin
	/// Coordinates of the corresponding gate on the other stack.
	var/list/remote_origin
	/// Cardinal direction away from the local vessel or location.
	var/direction
	/// Number of columns shared by this strip's gates.
	var/width
	/// Both gates own the lifetime of this visual connection.
	var/list/passages
	/// Watched turf -> remote cell, including temporarily obstructed cells.
	var/list/watched_tiles = list()
	/// Remote turf -> corresponding local exterior turf.
	var/list/tiles = list()
	/// Real actor -> visual carrier; null while its first refresh is pending.
	var/list/projections = list()
	/// Live remote lighting replaces the local exterior's ambient light on each preview tile.
	var/list/lighting = list()
	/// Remote cell -> owned lighting carrier, allowing one cell to be withdrawn independently.
	var/list/cell_lighting = list()
	/// Remote cells awaiting a coalesced geometry refresh.
	var/list/dirty_tiles = list()
	/// Serialize cooperative geometry refreshes while new changes accumulate.
	var/refreshing_geometry = FALSE
	/// Visual carrier subtype supplied by the environment adapter.
	var/projection_type = /obj/effect/abstract/stationtrauma_map_projection
	/// Inactive builds collect actors without displaying a half-prepared connection.
	var/list/pending_actors = list()
	/// Whether tracked actors may publish their visual carriers.
	var/enabled = FALSE
	/// Teardown cannot be revived by a queued geometry or actor callback.
	var/closing = FALSE
	/// Geometry notifications coalesce while a cooperative build is asleep.
	var/rebuilding = FALSE
	/// Geometry generation captured by each paused strip build.
	var/geometry_revision = 0

/datum/stationtrauma_map_preview/New(datum/component/stationtrauma_map_passage/passage, width, prepare_only = FALSE)
	. = ..()
	var/turf/local_gate = passage.parent
	var/turf/remote_gate = passage.landing
	local_origin = list(local_gate.x, local_gate.y, local_gate.z)
	remote_origin = list(remote_gate.x, remote_gate.y, remote_gate.z)
	direction = passage.direction
	src.width = width
	var/turf/reverse_gate = get_step(remote_gate, REVERSE_DIR(direction))
	passages = list(passage, reverse_gate.GetComponent(/datum/component/stationtrauma_map_passage))
	for(var/datum/component/stationtrauma_map_passage/gate as anything in passages)
		RegisterSignal(gate, COMSIG_QDELETING, PROC_REF(close))
	if(!prepare_only)
		rebuild()

/datum/stationtrauma_map_preview/Destroy()
	closing = TRUE
	clear()
	for(var/datum/component/stationtrauma_map_passage/gate as anything in passages)
		UnregisterSignal(gate, COMSIG_QDELETING)
	passages = null
	return ..()

/** Delete the preview when either owning passage disappears. */
/datum/stationtrauma_map_preview/proc/close()
	SIGNAL_HANDLER
	qdel(src)

/** Remove only our listeners and carriers; real actors and physical state belong to their original turfs. */
/datum/stationtrauma_map_preview/proc/clear()
	for(var/turf/tile as anything in release_tiles())
		unwatch(tile)

/** Destructors stay non-sleeping; voyage cleanup uses this separate cooperative entry point. */
/datum/stationtrauma_map_preview/proc/clear_cooperatively(datum/stationtrauma_work_budget/budget)
	if(!budget)
		clear()
		return
	for(var/turf/tile as anything in release_tiles())
		budget.yield()
		unwatch(tile)

/** Detach ownership before yielding so deletion cannot race a pending cleanup. */
/datum/stationtrauma_map_preview/proc/release_tiles()
	enabled = FALSE
	QDEL_LIST(lighting)
	cell_lighting.Cut()
	dirty_tiles.Cut()
	pending_actors.Cut()
	for(var/atom/actor as anything in projections.Copy())
		remove_actor(actor)
	var/list/old_tiles = watched_tiles
	watched_tiles = list()
	tiles.Cut()
	return old_tiles

/** Release geometry and occupant subscriptions on one remote turf. */
/datum/stationtrauma_map_preview/proc/unwatch(turf/tile)
	UnregisterSignal(tile, list(COMSIG_TURF_CHANGE, COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_ATOM_UPDATED_ICON))

/** Hide actors immediately; the expensive subscription cleanup may then yield. */
/datum/stationtrauma_map_preview/proc/suspend()
	closing = TRUE
	enabled = FALSE
	for(var/atom/movable/stationtrauma_map_lighting/light as anything in lighting)
		light.invisibility = INVISIBILITY_ABSTRACT
	for(var/atom/actor as anything in projections.Copy())
		remove_actor(actor)

/** All tile subscriptions are ready before any queued carrier becomes visible. */
/datum/stationtrauma_map_preview/proc/activate()
	if(closing || QDELETED(src))
		return
	enabled = TRUE
	for(var/atom/movable/stationtrauma_map_lighting/light as anything in lighting)
		light.invisibility = INVISIBILITY_LIGHTING
	var/list/actors = pending_actors
	pending_actors = list()
	for(var/atom/actor as anything in actors)
		track(actor)

/** Rebuild a bounded strip on geometry changes, never by polling the map. */
/datum/stationtrauma_map_preview/proc/rebuild(datum/stationtrauma_work_budget/budget)
	if(closing || QDELETED(src) || rebuilding)
		return FALSE
	rebuilding = TRUE
	var/revision = geometry_revision
	var/ready = FALSE
	try
		ready = build_strip(budget, revision)
	catch(var/exception/failure)
		rebuilding = FALSE
		clear_cooperatively(budget)
		throw failure
	rebuilding = FALSE
	if(!ready)
		clear_cooperatively(budget)
		if(!closing && !QDELETED(src))
			addtimer(CALLBACK(src, PROC_REF(rebuild)), 0, TIMER_UNIQUE)
		return FALSE
	var/datum/component/stationtrauma_map_passage/gate = passages[1]
	if(!gate.connection || gate.connection.active)
		activate()
	return TRUE

/** A geometry event invalidates a paused snapshot before it can be published. */
/datum/stationtrauma_map_preview/proc/build_strip(datum/stationtrauma_work_budget/budget, revision)
	clear_cooperatively(budget)
	var/list/candidates = list()
	var/step_x = direction == EAST ? 1 : direction == WEST ? -1 : 0
	var/step_y = direction == NORTH ? 1 : direction == SOUTH ? -1 : 0
	var/horizontal = !!(direction & (EAST|WEST))
	for(var/column in 0 to width - 1)
		budget?.yield()
		if(closing || QDELETED(src) || geometry_revision != revision)
			return FALSE
		// The first visible cell is the actual landing; the reverse gate belongs to the opposite side.
		for(var/distance in 0 to CEILING(maxviewdist() / 2, 1))
			var/turf/local_tile = locate(local_origin[1] + (horizontal ? 0 : column) + step_x * distance, local_origin[2] + (horizontal ? column : 0) + step_y * distance, local_origin[3])
			var/turf/remote_tile = locate(remote_origin[1] + (horizontal ? 0 : column) + step_x * distance, remote_origin[2] + (horizontal ? column : 0) + step_y * distance, remote_origin[3])
			for(var/turf/tile as anything in list(local_tile, remote_tile))
				if(!tile)
					continue
				watched_tiles[tile] = remote_tile
				RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(geometry_changed))
			if(!local_tile || !remote_tile || GET_TURF_PLANE_OFFSET(local_tile) != GET_TURF_PLANE_OFFSET(remote_tile))
				continue
			if(!local_tile_available(local_tile))
				continue
			candidates[remote_tile] = local_tile
	tiles = candidates
	for(var/turf/remote_tile as anything in tiles)
		budget?.yield()
		if(closing || QDELETED(src) || geometry_revision != revision)
			return FALSE
		watch_remote(remote_tile)
		var/atom/movable/stationtrauma_map_lighting/light = new(tiles[remote_tile], remote_tile)
		lighting += light
		cell_lighting[remote_tile] = light
		if(!isspaceturf(remote_tile))
			track(remote_tile)
		for(var/atom/movable/actor as anything in remote_tile)
			track(actor)
	return !closing && !QDELETED(src) && geometry_revision == revision

/** Invalidate paused builds; live connections refresh only the cells whose geometry changed. */
/datum/stationtrauma_map_preview/proc/geometry_changed(turf/source)
	SIGNAL_HANDLER
	geometry_revision++
	if(closing || rebuilding)
		return
	var/turf/remote_tile = watched_tiles[source]
	if(!remote_tile)
		return
	dirty_tiles[remote_tile] = TRUE
	if(!refreshing_geometry)
		addtimer(CALLBACK(src, PROC_REF(refresh_geometry)), 0, TIMER_UNIQUE)

/** Drain changed cells cooperatively; replacement turfs retain their external signal subscriptions. */
/datum/stationtrauma_map_preview/proc/refresh_geometry()
	if(closing || QDELETED(src) || rebuilding || refreshing_geometry)
		return
	refreshing_geometry = TRUE
	var/datum/stationtrauma_work_budget/budget = new
	try
		while(dirty_tiles.len)
			var/list/changed_tiles = dirty_tiles
			dirty_tiles = list()
			for(var/turf/remote_tile as anything in changed_tiles)
				budget.yield()
				if(closing || QDELETED(src) || rebuilding)
					refreshing_geometry = FALSE
					return
				if(remote_tile in watched_tiles)
					refresh_cell(remote_tile)
	catch(var/exception/failure)
		refreshing_geometry = FALSE
		throw failure
	refreshing_geometry = FALSE

/** Replace one cell's visuals and occupant subscriptions without touching the rest of the strip. */
/datum/stationtrauma_map_preview/proc/refresh_cell(turf/remote_tile)
	UnregisterSignal(remote_tile, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_ATOM_UPDATED_ICON))
	var/list/actors = list(remote_tile)
	actors += remote_tile.contents
	for(var/atom/actor as anything in actors)
		pending_actors -= actor
		remove_actor(actor)
	var/atom/movable/stationtrauma_map_lighting/old_light = cell_lighting[remote_tile]
	cell_lighting -= remote_tile
	lighting -= old_light
	qdel(old_light)
	tiles -= remote_tile
	var/turf/local_tile = locate(local_origin[1] + remote_tile.x - remote_origin[1], local_origin[2] + remote_tile.y - remote_origin[2], local_origin[3])
	if(!local_tile || GET_TURF_PLANE_OFFSET(local_tile) != GET_TURF_PLANE_OFFSET(remote_tile) || !local_tile_available(local_tile))
		return
	tiles[remote_tile] = local_tile
	watch_remote(remote_tile)
	var/atom/movable/stationtrauma_map_lighting/light = new(local_tile, remote_tile)
	lighting += light
	cell_lighting[remote_tile] = light
	if(enabled)
		light.invisibility = INVISIBILITY_LIGHTING
	if(!isspaceturf(remote_tile))
		track(remote_tile)
	for(var/atom/movable/actor as anything in remote_tile)
		track(actor)

/** Track an eligible actor after it enters a watched remote turf. */
/datum/stationtrauma_map_preview/proc/actor_entered(datum/source, atom/movable/actor)
	SIGNAL_HANDLER
	track(actor)

/** Keep native actor visuals and non-space terrain; no effects or ghosts become physical targets. */
/datum/stationtrauma_map_preview/proc/track(atom/actor)
	if(closing || QDELETED(actor) || (!(isturf(actor) && !isspaceturf(actor)) && !isliving(actor) && (!isobj(actor) || (iseffect(actor) && !istype(actor, /obj/effect/decal)))) || !tiles[isturf(actor) ? actor : actor.loc])
		return
	if(!enabled)
		pending_actors[actor] = TRUE
		return
	if(!(actor in projections))
		projections[actor] = null
		if(ismovable(actor))
			RegisterSignal(actor, COMSIG_MOVABLE_MOVED, PROC_REF(refresh))
		RegisterSignal(actor, COMSIG_QDELETING, PROC_REF(remove_actor))
		RegisterSignal(actor, COMSIG_ATOM_SET_OPACITY, PROC_REF(queue_refresh))
		if(!isturf(actor))
			RegisterSignals(actor, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_ATOM_COLOR_UPDATED, COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY, COMSIG_LIVING_POST_UPDATE_TRANSFORM), PROC_REF(queue_refresh))
	// Finish initialization and immersion before capturing its mask.
	queue_refresh(actor)

/** Coalesce appearance updates per real actor until initialization completes. */
/datum/stationtrauma_map_preview/proc/queue_refresh(atom/actor)
	SIGNAL_HANDLER
	// Timer hashes stringify arguments; equally named actors still need separate refreshes.
	addtimer(CALLBACK(src, PROC_REF(refresh), actor, REF(actor)), 0, TIMER_UNIQUE)

/** Synchronize a local carrier with its remote actor. */
/datum/stationtrauma_map_preview/proc/refresh(atom/actor)
	SIGNAL_HANDLER
	if(closing || !enabled || QDELETED(src) || !(actor in projections))
		return
	var/turf/local_tile = QDELETED(actor) ? null : tiles[isturf(actor) ? actor : actor.loc]
	if(!local_tile)
		remove_actor(actor)
		return
	var/obj/effect/abstract/stationtrauma_map_projection/carrier = projections[actor]
	if(!carrier)
		carrier = new projection_type(local_tile)
		projections[actor] = carrier
	else if(carrier.loc != local_tile)
		if(get_dist(carrier, local_tile) <= 1)
			var/atom/movable/moving_actor = ismovable(actor) ? actor : null
			carrier.Move(local_tile, get_dir(carrier, local_tile), moving_actor?.glide_size)
		else
			carrier.forceMove(local_tile)
	carrier.update_visual(actor)

/** Release actor subscriptions and delete its local visual carrier. */
/datum/stationtrauma_map_preview/proc/remove_actor(atom/actor)
	SIGNAL_HANDLER
	if(!(actor in projections))
		return
	var/obj/effect/abstract/stationtrauma_map_projection/carrier = projections[actor]
	projections -= actor
	UnregisterSignal(actor, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_ATOM_SET_OPACITY, COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_ATOM_COLOR_UPDATED, COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY, COMSIG_LIVING_POST_UPDATE_TRANSFORM))
	qdel(carrier)

/** Visual carrier retaining the remote atom's live appearance. */
/obj/effect/abstract/stationtrauma_map_projection
	name = "map passage preview"
	icon = null
	invisibility = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE
	can_atmos_pass = ATMOS_PASS_YES
	/// Real target behind this image; projectiles resolve it only after crossing the seam.
	var/atom/visual_source

/obj/effect/abstract/stationtrauma_map_projection/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_UNHITTABLE_BY_PROJECTILES, INNATE_TRAIT)

/obj/effect/abstract/stationtrauma_map_projection/Destroy()
	vis_contents.Cut()
	visual_source = null
	return ..()

/** Keep native weapon checks; a nearby image still represents a remote ranged target. */
/obj/item/gun/fire_gun(atom/target, mob/living/user, flag, params)
	if(istype(target, /obj/effect/abstract/stationtrauma_map_projection))
		flag = FALSE
	return ..()

/** Never change the real actor's filters or its native immersion relay. */
/obj/effect/abstract/stationtrauma_map_projection/proc/update_visual(atom/actor)
	visual_source = actor
	name = actor.name
	if(isturf(actor))
		var/old_opacity = opacity
		appearance = actor.appearance
		// Apply opacity through its setter so copying a wall also registers its light blocker.
		opacity = old_opacity
		vis_contents.Cut()
	else
		vis_contents = list(actor)
		if(!isprojectile(actor))
			var/datum/component/stationtrauma_map_click/clicks = actor.LoadComponent(/datum/component/stationtrauma_map_click)
			clicks.add_projection(src)
	invisibility = actor.invisibility
	plane = actor.plane
	layer = actor.layer
	dir = actor.dir
	set_opacity(actor.opacity)
	mouse_opacity = isprojectile(actor) || iseffect(actor) ? MOUSE_OPACITY_TRANSPARENT : MOUSE_OPACITY_OPAQUE

/** Shared click ownership preserves a live actor's visuals while aiming at the image's local coordinates. */
/datum/component/stationtrauma_map_click
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Every live image retaining this actor's click identity.
	var/list/projections = list()
	/// Leave an inherited flag that already belonged to another system intact.
	var/added_flag = FALSE

/datum/component/stationtrauma_map_click/Initialize()
	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE
	return ..()

/datum/component/stationtrauma_map_click/RegisterWithParent()
	var/atom/movable/actor = parent
	added_flag = !(actor.vis_flags & VIS_INHERIT_ID)
	actor.vis_flags |= VIS_INHERIT_ID

/datum/component/stationtrauma_map_click/UnregisterFromParent()
	var/atom/movable/actor = parent
	if(added_flag)
		actor.vis_flags &= ~VIS_INHERIT_ID
	for(var/datum/projection as anything in projections)
		UnregisterSignal(projection, COMSIG_QDELETING)
	projections.Cut()

/** Retain click forwarding until the last image is destroyed. */
/datum/component/stationtrauma_map_click/proc/add_projection(obj/effect/abstract/stationtrauma_map_projection/projection)
	if(projection in projections)
		return
	projections += projection
	RegisterSignal(projection, COMSIG_QDELETING, PROC_REF(remove_projection))

/** Release a deleted click projection from the real actor component. */
/datum/component/stationtrauma_map_click/proc/remove_projection(datum/projection)
	SIGNAL_HANDLER
	UnregisterSignal(projection, COMSIG_QDELETING)
	projections -= projection
	if(!projections.len)
		qdel(src)

/** Whether the local tile can display a remote scene. */
/datum/stationtrauma_map_preview/proc/local_tile_available(turf/tile)
	return isspaceturf(tile)

/** Subscribe to remote actor and terrain changes. */
/datum/stationtrauma_map_preview/proc/watch_remote(turf/tile)
	RegisterSignals(tile, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(actor_entered))
	RegisterSignal(tile, COMSIG_ATOM_UPDATED_ICON, PROC_REF(queue_refresh))
// AI EDIT END
