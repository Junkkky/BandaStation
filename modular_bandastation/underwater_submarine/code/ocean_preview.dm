/** Actor-only continuation through reserved open ocean; local water, lighting and lower decks render once. */
/datum/stationtrauma_ocean_preview
	/// Stable coordinates survive turf replacement while the strip is being rebuilt.
	var/list/local_origin
	/// Coordinates of the corresponding gate on the other stack.
	var/list/remote_origin
	/// North or south, away from the local vessel or location.
	var/direction
	/// Number of columns shared by this strip's gates.
	var/width
	/// Both gates own the lifetime of this visual connection.
	var/list/passages
	/// Geometry subscriptions on both sides, including temporarily obstructed cells.
	var/list/watched_tiles = list()
	/// Remote ocean turf -> corresponding local ocean turf.
	var/list/tiles = list()
	/// Real actor -> visual carrier; null while its first refresh is pending.
	var/list/projections = list()
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

/datum/stationtrauma_ocean_preview/New(datum/component/stationtrauma_ocean_passage/passage, width, prepare_only = FALSE)
	. = ..()
	var/turf/local_gate = passage.parent
	var/turf/remote_gate = passage.landing
	local_origin = list(local_gate.x, local_gate.y, local_gate.z)
	remote_origin = list(remote_gate.x, remote_gate.y, remote_gate.z)
	direction = passage.direction
	src.width = width
	var/turf/reverse_gate = get_step(remote_gate, REVERSE_DIR(direction))
	passages = list(passage, reverse_gate.GetComponent(/datum/component/stationtrauma_ocean_passage))
	for(var/datum/component/stationtrauma_ocean_passage/gate as anything in passages)
		RegisterSignal(gate, COMSIG_QDELETING, PROC_REF(close))
	if(!prepare_only)
		rebuild()

/datum/stationtrauma_ocean_preview/Destroy()
	closing = TRUE
	clear()
	for(var/datum/component/stationtrauma_ocean_passage/gate as anything in passages)
		UnregisterSignal(gate, COMSIG_QDELETING)
	passages = null
	return ..()

/datum/stationtrauma_ocean_preview/proc/close()
	SIGNAL_HANDLER
	qdel(src)

/** Remove only our listeners and carriers; real actors and hydraulic state belong to their original turfs. */
/datum/stationtrauma_ocean_preview/proc/clear()
	for(var/turf/tile as anything in release_tiles())
		unwatch(tile)

/** Destructors stay non-sleeping; voyage cleanup uses this separate cooperative entry point. */
/datum/stationtrauma_ocean_preview/proc/clear_cooperatively(datum/stationtrauma_work_budget/budget)
	if(!budget)
		clear()
		return
	for(var/turf/tile as anything in release_tiles())
		budget.yield()
		unwatch(tile)

/** Detach ownership before yielding so deletion cannot race a pending cleanup. */
/datum/stationtrauma_ocean_preview/proc/release_tiles()
	enabled = FALSE
	pending_actors.Cut()
	for(var/atom/movable/actor as anything in projections.Copy())
		remove_actor(actor)
	var/list/old_tiles = watched_tiles
	watched_tiles = list()
	tiles.Cut()
	return old_tiles

/datum/stationtrauma_ocean_preview/proc/unwatch(turf/tile)
	UnregisterSignal(tile, list(COMSIG_TURF_CHANGE, COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED))

/** Hide actors immediately; the expensive subscription cleanup may then yield. */
/datum/stationtrauma_ocean_preview/proc/suspend()
	closing = TRUE
	enabled = FALSE
	for(var/atom/movable/actor as anything in projections.Copy())
		remove_actor(actor)

/** All tile subscriptions are ready before any queued carrier becomes visible. */
/datum/stationtrauma_ocean_preview/proc/activate()
	if(closing || QDELETED(src))
		return
	enabled = TRUE
	var/list/actors = pending_actors
	pending_actors = list()
	for(var/atom/movable/actor as anything in actors)
		track(actor)

/** Rebuild a bounded strip on geometry changes, never by polling the map. */
/datum/stationtrauma_ocean_preview/proc/rebuild(datum/stationtrauma_work_budget/budget)
	if(closing || QDELETED(src) || rebuilding)
		return FALSE
	// Only inactive voyage preparation may yield; live geometry keeps its existing frame atomicity.
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
	var/datum/component/stationtrauma_ocean_passage/gate = passages[1]
	if(!gate.vessel || gate.vessel.ocean_connection_active)
		activate()
	return TRUE

/** A geometry event invalidates a paused snapshot before it can be published. */
/datum/stationtrauma_ocean_preview/proc/build_strip(datum/stationtrauma_work_budget/budget, revision)
	clear_cooperatively(budget)
	var/list/candidates = list()
	var/available = TRUE
	var/step_y = direction == NORTH ? 1 : -1
	for(var/column in 0 to width - 1)
		budget?.yield()
		if(closing || QDELETED(src) || geometry_revision != revision)
			return FALSE
		// Include the reverse gate, so its last visible step coincides with the physical landing.
		for(var/distance in -1 to CEILING(maxviewdist() / 2, 1))
			var/turf/local_tile = locate(local_origin[1] + column, local_origin[2] + step_y * distance, local_origin[3])
			var/turf/remote_tile = locate(remote_origin[1] + column, remote_origin[2] + step_y * distance, remote_origin[3])
			for(var/turf/tile as anything in list(local_tile, remote_tile))
				if(!tile)
					available = FALSE
					continue
				watched_tiles += tile
				RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(geometry_changed))
				var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
				if(!isspaceturf(tile) || !water?.infinite_source)
					available = FALSE
			if(!local_tile || !remote_tile || GET_TURF_PLANE_OFFSET(local_tile) != GET_TURF_PLANE_OFFSET(remote_tile))
				available = FALSE
				continue
			candidates[remote_tile] = local_tile
	// shortcut: preview supports reserved open ocean; add scene masking and occlusion before allowing buildings in this strip.
	if(!available)
		return TRUE
	tiles = candidates
	for(var/turf/remote_tile as anything in tiles)
		budget?.yield()
		if(closing || QDELETED(src) || geometry_revision != revision)
			return FALSE
		RegisterSignals(remote_tile, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(actor_entered))
		RegisterSignal(remote_tile, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED, PROC_REF(water_changed))
		for(var/atom/movable/actor as anything in remote_tile)
			track(actor)
	return !closing && !QDELETED(src) && geometry_revision == revision

/datum/stationtrauma_ocean_preview/proc/geometry_changed()
	SIGNAL_HANDLER
	geometry_revision++
	if(closing || rebuilding)
		return
	addtimer(CALLBACK(src, PROC_REF(rebuild)), 0, TIMER_UNIQUE)

/datum/stationtrauma_ocean_preview/proc/actor_entered(datum/source, atom/movable/actor)
	SIGNAL_HANDLER
	track(actor)

/datum/stationtrauma_ocean_preview/proc/water_changed(turf/source)
	SIGNAL_HANDLER
	for(var/atom/movable/actor as anything in source)
		if(actor in projections)
			queue_refresh(actor)

/** Keep live visuals and animations, excluding effects, ghosts and the carriers themselves. */
/datum/stationtrauma_ocean_preview/proc/track(atom/movable/actor)
	if(closing || QDELETED(actor) || (!isliving(actor) && (!isobj(actor) || iseffect(actor))) || !tiles[actor.loc])
		return
	if(!enabled)
		pending_actors[actor] = TRUE
		return
	if(!(actor in projections))
		projections[actor] = null
		RegisterSignal(actor, COMSIG_MOVABLE_MOVED, PROC_REF(refresh))
		RegisterSignal(actor, COMSIG_QDELETING, PROC_REF(remove_actor))
		RegisterSignals(actor, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_ATOM_COLOR_UPDATED, COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY, COMSIG_LIVING_POST_UPDATE_TRANSFORM), PROC_REF(queue_refresh))
	// Finish initialization and immersion before capturing its mask.
	queue_refresh(actor)

/datum/stationtrauma_ocean_preview/proc/queue_refresh(atom/movable/actor)
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(refresh), actor), 0, TIMER_UNIQUE)

/** Translate only the carrier's position; the real atom remains on its original map. */
/datum/stationtrauma_ocean_preview/proc/refresh(atom/movable/actor)
	SIGNAL_HANDLER
	if(closing || !enabled || QDELETED(src) || !(actor in projections))
		return
	var/turf/local_tile = QDELETED(actor) ? null : tiles[actor.loc]
	if(!local_tile)
		remove_actor(actor)
		return
	var/obj/effect/abstract/stationtrauma_ocean_projection/carrier = projections[actor]
	if(!carrier)
		carrier = new(local_tile)
		projections[actor] = carrier
	else if(carrier.loc != local_tile)
		if(get_dist(carrier, local_tile) <= 1)
			carrier.Move(local_tile, get_dir(carrier, local_tile), actor.glide_size)
		else
			carrier.forceMove(local_tile)
	carrier.update_visual(actor)

/datum/stationtrauma_ocean_preview/proc/remove_actor(atom/movable/actor)
	SIGNAL_HANDLER
	if(!(actor in projections))
		return
	var/obj/effect/abstract/stationtrauma_ocean_projection/carrier = projections[actor]
	projections -= actor
	UnregisterSignal(actor, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_ATOM_COLOR_UPDATED, COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY, COMSIG_LIVING_POST_UPDATE_TRANSFORM))
	qdel(carrier)

/** A visual-only carrier; live vis_contents preserve outfits, alpha, direction and swimming animation. */
/obj/effect/abstract/stationtrauma_ocean_projection
	name = "ocean passage preview"
	icon = null
	invisibility = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	density = FALSE
	can_atmos_pass = ATMOS_PASS_YES

/obj/effect/abstract/stationtrauma_ocean_projection/Destroy()
	vis_contents.Cut()
	return ..()

/** Never change the real actor's filters or its native immersion relay. */
/obj/effect/abstract/stationtrauma_ocean_projection/proc/update_visual(atom/movable/actor)
	invisibility = actor.invisibility
	plane = actor.plane
	// Keep the actor's live immersion relay and filters; never add another water mask.
	vis_contents = list(actor)
