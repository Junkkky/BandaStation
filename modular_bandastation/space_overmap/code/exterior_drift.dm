/area/space/stationtrauma_space_home
	/// Navigation of the hull whose flight level this area covers.
	var/datum/weakref/navigation_ref

/area/space/stationtrauma_space_home/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	catch_drifter(arrived)

/** Like native hyperspace: whoever leaves a hull under way clings to it or is swept away astern. */
/area/space/stationtrauma_space_home/proc/catch_drifter(atom/movable/drifter)
	var/datum/stationtrauma_overmap/space/navigation = navigation_ref?.resolve()
	if(!navigation?.parallax_direction || QDELETED(drifter) || drifter.anchored || iseffect(drifter) || istype(drifter, /obj/projectile) || HAS_TRAIT(drifter, TRAIT_HYPERSPACED))
		return
	drifter.AddComponent(/datum/component/shuttle_cling/stationtrauma, REVERSE_DIR(navigation.parallax_direction), navigation)

/datum/stationtrauma_overmap/space/update_parallax()
	var/was_moving = parallax_direction
	. = ..()
	if(was_moving || !parallax_direction || !exterior || QDELETED(vessel))
		return
	// Whoever is already outside when the hull gets under way is left behind as well.
	var/list/bounds = vessel.return_coords()
	var/border = SHUTTLE_TRANSIT_BORDER
	var/turf/low = locate(max(1, min(bounds[1], bounds[3]) - border), max(1, min(bounds[2], bounds[4]) - border), vessel.z)
	var/turf/high = locate(min(world.maxx, max(bounds[1], bounds[3]) + border), min(world.maxy, max(bounds[2], bounds[4]) + border), vessel.z)
	for(var/turf/open/space/tile in block(low, high))
		if(tile.loc != exterior)
			continue
		for(var/atom/movable/drifter in tile)
			exterior.catch_drifter(drifter)

/**
 * Sweep a drifter left far behind onto the open-space level of this loss, tumbling across it away from the hull.
 *
 * Arguments:
 * * drifter - Movable past the transit border of the flight level
 * * direction - Astern, the way the drift carried it
 */
/datum/stationtrauma_overmap/space/proc/strand(atom/movable/drifter, direction)
	var/datum/stationtrauma_lost_space/loss = lost_space()
	// Creating a level can wait on another one: the drifter may have been caught meanwhile.
	if(!loss?.level || QDELETED(src) || QDELETED(drifter) || !exterior || get_area(drifter) != exterior)
		return FALSE
	// Enter at the far side, so the throw crosses the whole level while a nearby wreck loads.
	var/margin = TRANSITIONEDGE + 8
	var/entry_x = direction == EAST ? margin : direction == WEST ? world.maxx - margin : rand(margin * 4, world.maxx - margin * 4)
	var/entry_y = direction == NORTH ? margin : direction == SOUTH ? world.maxy - margin : rand(margin * 4, world.maxy - margin * 4)
	var/turf/entry = locate(entry_x, entry_y, loss.level.z_value)
	drifter.forceMove(entry)
	if(isliving(drifter))
		var/mob/living/lost = drifter
		shake_camera(lost, 3 SECONDS, 2)
		to_chat(lost, span_userdanger("Корабль уходит, а вас закручивает и уносит в открытый космос!"))
	drifter.safe_throw_at(get_edge_target_turf(entry, direction), world.maxx, 1, spin = TRUE, force = MOVE_FORCE_EXTREMELY_STRONG)
	loss.refresh_signal()
	return TRUE

/** The loss this hull is having now, or an idle open-space level claimed for a new one, or a new level. */
/datum/stationtrauma_overmap/space/proc/lost_space()
	var/datum/stationtrauma_lost_space/idle
	for(var/datum/stationtrauma_lost_space/loss as anything in GLOB.stationtrauma_lost_spaces)
		var/datum/stationtrauma_overmap_sector/space/here = sector
		if(loss.navigation_ref?.resolve() == src && loss.sector_id == here?.id && world.time - loss.last_loss < ST_LOST_SHARED_TIME && (loss.pos_x - pos_x) ** 2 + (loss.pos_y - pos_y) ** 2 <= ST_LOST_WRECK_RANGE ** 2)
			loss.last_loss = world.time
			return loss
		if(!idle && !loss.busy())
			idle = loss
	if(!idle)
		idle = new
		// Recorded first: a parallel loss must not claim it while the level is still being created.
		idle.last_loss = world.time
		GLOB.stationtrauma_lost_spaces += idle
		idle.level = SSmapping.add_new_zlevel("Открытый космос", ZTRAITS_AWAY)
		if(QDELETED(src))
			return null
	idle.claim(src)
	return idle

/// Open-space levels of losses overboard; a z-level cannot be removed, so idle ones are claimed again.
GLOBAL_LIST_EMPTY(stationtrauma_lost_spaces)

/**
 * One loss overboard: the open-space level the lost are swept onto, where on the chart it happened, and the wreck its edges lead to.
 *
 * One hull at one place within a short time shares a level; another hull or place takes another level.
 */
/datum/stationtrauma_lost_space
	/// Open-space level of this loss.
	var/datum/space_level/level
	/// Hull the crew was lost from.
	var/datum/weakref/navigation_ref
	/// Sector of the loss.
	var/sector_id
	/// Chart position of the loss.
	var/pos_x
	/// Chart ordinate of the loss.
	var/pos_y
	/// world.time of the latest loss here; a recent loss holds the level before anyone arrives.
	var/last_loss = 0
	/// Increments on every claim, so a wreck load started for an earlier loss cannot retarget the edges.
	var/revision = 0
	/// Charted object whose level the edges lead into once it is loaded; null keeps the edges looping.
	var/datum/stationtrauma_overmap_site/space/wreck
	/// Distress destination charted while a beacon transmits on this level.
	var/datum/stationtrauma_overmap_site/space/distress/signal

/** Whether anyone still needs this level: a fresh loss, the living, a transmitting beacon or a rescue in progress. */
/datum/stationtrauma_lost_space/proc/busy()
	if(!level || world.time - last_loss < ST_LOST_SHARED_TIME || signal?.docking_owner)
		return TRUE
	if(length(stationtrauma_distress_callsigns(level.z_value)))
		return TRUE
	for(var/mob/living/lost as anything in GLOB.mob_living_list)
		if(lost.z == level.z_value && lost.stat != DEAD)
			return TRUE
	return FALSE

/** Take the level for a new loss of `navigation` at its current chart position. */
/datum/stationtrauma_lost_space/proc/claim(datum/stationtrauma_overmap/space/navigation)
	revision++
	navigation_ref = WEAKREF(navigation)
	var/datum/stationtrauma_overmap_sector/space/sector = navigation.sector
	sector_id = sector?.id
	pos_x = navigation.pos_x
	pos_y = navigation.pos_y
	last_loss = world.time
	drop_signal()
	wreck = null
	var/closest = ST_LOST_WRECK_RANGE
	for(var/id in navigation.sites)
		var/datum/stationtrauma_overmap_site/space/site = navigation.sites[id]
		if(!istype(site) || istype(site, /datum/stationtrauma_overmap_site/space/planet) || istype(site, /datum/stationtrauma_overmap_site/space/distress) || site.landing || site.physical_docking || site.failed)
			continue
		if(QDELETED(site.berth) && !site.awaits_map())
			continue
		var/distance = sqrt((site.pos_x - pos_x) ** 2 + (site.pos_y - pos_y) ** 2)
		if(distance <= closest)
			closest = distance
			wreck = site
	set_edges(level.z_value)
	if(wreck)
		INVOKE_ASYNC(src, PROC_REF(reach_wreck), revision)

/** Load the nearby wreck, then lead every edge of the level into its level: drifting or flying off the edge arrives there. */
/datum/stationtrauma_lost_space/proc/reach_wreck(expected)
	var/datum/stationtrauma_overmap_site/space/target = wreck
	target.load_map()
	UNTIL(!target.loading_map)
	if(revision != expected || wreck != target || target.failed || QDELETED(target.berth) || signal?.berth)
		return
	set_edges(target.berth.z)

/**
 * Point every border tile of the level at the opposite side of `target_z`, as native cross-linked space does.
 *
 * Arguments:
 * * target_z - Receiving level; this level itself loops, null leaves plain borders
 */
/datum/stationtrauma_lost_space/proc/set_edges(target_z)
	var/z = level.z_value
	var/inner_max_x = world.maxx - TRANSITIONEDGE
	var/inner_max_y = world.maxy - TRANSITIONEDGE
	var/list/x_low = list(1, 1, inner_max_x, 1)
	var/list/y_low = list(inner_max_y, 1, 1 + TRANSITIONEDGE, 1 + TRANSITIONEDGE)
	var/list/x_high = list(world.maxx, world.maxx, world.maxx, 1 + TRANSITIONEDGE)
	var/list/y_high = list(world.maxy, 1 + TRANSITIONEDGE, inner_max_y, inner_max_y)
	var/list/x_arrival = list(0, 0, TRANSITIONEDGE + 2, inner_max_x - 1)
	var/list/y_arrival = list(TRANSITIONEDGE + 2, inner_max_y - 1, 0, 0)
	for(var/side in 1 to 4)
		for(var/turf/open/tile in block(x_low[side], y_low[side], z, x_high[side], y_high[side], z))
			tile.destination_x = target_z ? (x_arrival[side] || tile.x) : null
			tile.destination_y = target_z ? (y_arrival[side] || tile.y) : null
			tile.destination_z = target_z
		CHECK_TICK

/** Chart or withdraw the distress destination as beacons on this level switch on and off. */
/datum/stationtrauma_lost_space/proc/refresh_signal()
	var/transmitting = length(stationtrauma_distress_callsigns(level.z_value))
	if(transmitting && !signal)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		if(!sector)
			return
		signal = new
		signal.id = "distress_[GLOB.stationtrauma_lost_spaces.Find(src)]"
		signal.loss = src
		signal.pos_x = pos_x
		signal.pos_y = pos_y
		signal.map_loader = CALLBACK(src, PROC_REF(place_rescue_berth))
		sector.sites[signal.id] = signal
	else if(!transmitting && signal && !signal.docking_owner)
		drop_signal()

/** Withdraw the distress destination and its berth. */
/datum/stationtrauma_lost_space/proc/drop_signal()
	if(!signal)
		return
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
	if(sector?.sites[signal.id] == signal)
		sector.sites -= signal.id
	if(signal.berth)
		qdel(signal.berth, force = TRUE)
		signal.berth = null
	QDEL_NULL(signal)

/** The rescue approach puts the berth beside the transmitting beacon; the seam needs plain borders, so they stop looping. */
/datum/stationtrauma_lost_space/proc/place_rescue_berth()
	var/turf/beacon_tile
	for(var/obj/item/stationtrauma_distress_beacon/beacon as anything in GLOB.stationtrauma_distress_beacons)
		var/turf/tile = get_turf(beacon)
		if(beacon.active && tile?.z == level.z_value)
			beacon_tile = tile
			break
	if(!beacon_tile || !signal)
		return FALSE
	set_edges(null)
	var/margin = ST_LOST_BERTH_MARGIN
	signal.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(clamp(beacon_tile.x, margin, world.maxx - margin), clamp(beacon_tile.y, margin, world.maxy - margin), level.z_value))
	signal.entrance = beacon_tile
	return TRUE

/** Distress destination at the chart point of a loss, listed while a beacon transmits on its open-space level. */
/datum/stationtrauma_overmap_site/space/distress
	name = "Сигнал бедствия"
	radius = 20
	discovered = FALSE
	needs_scan = TRUE
	approach_scene = "sos"
	/// Loss whose level this destination leads to.
	var/datum/stationtrauma_lost_space/loss

/datum/stationtrauma_overmap_site/space/distress/Destroy()
	loss = null
	return ..()

/datum/stationtrauma_overmap_site/space/distress/distress_callsigns()
	return loss?.level ? stationtrauma_distress_callsigns(loss.level.z_value) : list()

/// Hull-relative drift on a flight level; past the native transit border the drifter is swept into open space.
/datum/component/shuttle_cling/stationtrauma
	/// Hull whose motion pulls; the drift ends once it stops.
	var/datum/weakref/navigation_ref
	/// Set once the drifter has been handed to the hull's stranding; it is not retried.
	var/stranding = FALSE

/datum/component/shuttle_cling/stationtrauma/Initialize(direction, datum/stationtrauma_overmap/space/navigation)
	// The parent checks the position at once, so the hull must be known first.
	navigation_ref = WEAKREF(navigation)
	return ..()

/datum/component/shuttle_cling/stationtrauma/is_on_hyperspace(atom/movable/clinger)
	var/datum/stationtrauma_overmap/space/navigation = navigation_ref?.resolve()
	var/turf/tile = clinger?.loc
	return navigation?.parallax_direction && navigation.exterior && isspaceturf(tile) && tile.loc == navigation.exterior

/datum/component/shuttle_cling/stationtrauma/update_state()
	var/datum/stationtrauma_overmap/space/navigation = navigation_ref?.resolve()
	var/atom/movable/clinger = parent
	// The exterior area lies on the hull's own level, so the distance is never across levels.
	if(!stranding && is_on_hyperspace(clinger) && !QDELETED(navigation.vessel) && get_dist(clinger, navigation.vessel) > max(navigation.vessel.width, navigation.vessel.height) + SHUTTLE_TRANSIT_BORDER)
		stranding = TRUE
		INVOKE_ASYNC(navigation, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, strand), clinger, direction)
	return ..()
