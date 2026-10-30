// AI EDIT START - space overmap module integration
/datum/stationtrauma_overmap/space
	/// The original physical berth retained while the ship visits a planetary surface.
	var/obj/docking_port/stationary/stationtrauma_space_flight/flight_berth
	/// Native shuttle movement yields; navigation commands cannot interrupt a partially moved hull.
	var/relocating = FALSE

/** Retained native berth marking the hull position on its stationary flight level. */
/obj/docking_port/stationary/stationtrauma_space_flight
	name = "Орбитальная стоянка"
	shuttle_id = "stationtrauma_space_flight"
	area_type = /area/space/stationtrauma_space_home

/** Surface berth sized for the prototype hull; actual compatibility uses native port bounds. */
/obj/docking_port/stationary/stationtrauma_space_surface
	name = "Лунная посадочная площадка"
	shuttle_id = "stationtrauma_space_surface"
	width = 21
	height = 32
	dheight = 16
	area_type = /area/stationtrauma_space_site/planet

/** Generic templates replace space instead of stacking over it; restore the vacuum below the whole hull first. */
/datum/stationtrauma_overmap/space/proc/prepare_flight_berth()
	flight_berth = new(get_turf(vessel))
	flight_berth.width = vessel.width
	flight_berth.height = vessel.height
	flight_berth.dwidth = vessel.dwidth
	flight_berth.dheight = vessel.dheight
	flight_berth.setDir(vessel.dir)
	for(var/turf/tile as anything in vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir))
		if(vessel.shuttle_areas[get_area(tile)] && !isspaceturf(tile) && !isshuttleturf(tile))
			tile.insert_baseturf(2, /turf/open/space)
			tile.insert_baseturf(3, /turf/baseturf_skipover/shuttle)

/** Skip native trampling; expedition docking checks occupancy again after preflight. */
/turf/toShuttleMove(turf/oldT, move_mode, obj/docking_port/mobile/shuttle)
	if(istype(shuttle, /obj/docking_port/mobile/stationtrauma_space))
		return move_mode
	return ..()

/obj/docking_port/mobile/stationtrauma_space/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	if(!overmap?.relocating)
		return DOCKING_BLOCKED
	var/datum/stationtrauma_overmap_site/space/site = overmap.sites[overmap.selected_destination]
	if(new_dock != overmap.flight_berth && ((!site?.landing && !site?.physical_docking) || site.berth != new_dock || !permits_docking(site)))
		return DOCKING_BLOCKED
	return ..(new_dock, movement_direction, FALSE)

/** Reused by native docking before and after its yielding preflight; never trample players or their construction. */
/obj/docking_port/mobile/stationtrauma_space/check_dock(obj/docking_port/stationary/target, silent = FALSE)
	if(!..())
		return FALSE
	// Native index order pairs each hull tile with its rotated target; bounding-box corners outside the hull never move.
	var/list/hull_turfs = return_ordered_turfs(x, y, z, dir)
	var/list/target_turfs = return_ordered_turfs(target.x, target.y, target.z, target.dir)
	if(length(target_turfs) != length(hull_turfs))
		return FALSE
	for(var/index in 1 to length(hull_turfs))
		if(!shuttle_areas[get_area(hull_turfs[index])])
			continue
		var/turf/tile = target_turfs[index]
		if(!isopenturf(tile) || tile.density)
			return FALSE
		for(var/atom/movable/occupant as anything in tile)
			if(isliving(occupant) || (isobj(occupant) && !iseffect(occupant) && !istype(occupant, /obj/docking_port)))
				return FALSE
	return TRUE

/** Reuse free vacuum on this ship's flight level when an evacuation departure finds its old footprint occupied. */
/datum/stationtrauma_overmap/space/proc/position_service_berth(datum/stationtrauma_overmap_site/space/site)
	var/obj/docking_port/stationary/stationtrauma_space_flight/berth = flight_berth
	if(vessel.check_dock(berth, TRUE))
		return TRUE
	if(QDELETED(exterior))
		return FALSE
	var/flight_z = berth.z
	var/list/candidates = exterior.get_turfs_by_zlevel(flight_z)
	if(!length(candidates))
		return FALSE
	candidates = candidates.Copy()
	var/list/hull_turfs = vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/candidate as anything in candidates)
		budget.yield()
		if(QDELETED(src) || !is_operational() || QDELETED(site) || QDELETED(berth) || QDELETED(exterior) || flight_berth != berth || docked != site || site.docking_owner != src || vessel.get_docked() != site.berth)
			return FALSE
		// Native ordered lists collapse off-map null turfs, so reject incomplete bounds before pairing them.
		var/list/bounds = vessel.return_coords(candidate.x, candidate.y, berth.dir)
		if(min(bounds[1], bounds[3]) < 1 || max(bounds[1], bounds[3]) > world.maxx || min(bounds[2], bounds[4]) < 1 || max(bounds[2], bounds[4]) > world.maxy)
			continue
		var/list/target_turfs = vessel.return_ordered_turfs(candidate.x, candidate.y, flight_z, berth.dir)
		if(length(target_turfs) != length(hull_turfs))
			return FALSE
		var/clear = TRUE
		for(var/index in 1 to length(hull_turfs))
			if(!vessel.shuttle_areas[get_area(hull_turfs[index])])
				continue
			var/turf/tile = target_turfs[index]
			if(!isspaceturf(tile) || get_area(tile) != exterior)
				clear = FALSE
				break
		if(!clear)
			continue
		berth.forceMove(candidate)
		if(vessel.check_dock(berth, TRUE))
			return TRUE
	return FALSE

/** Relocate the hull and its latejoin turfs through native shuttle movement. */
/datum/stationtrauma_overmap/space/proc/relocate(obj/docking_port/stationary/target)
	if(relocating || ship_docking || QDELETED(target) || QDELETED(vessel) || !vessel.check_dock(target, TRUE))
		status = "Манёвр отменён: посадочная площадка занята или перекрыта"
		return FALSE
	var/was_preparing = preparing
	var/original_direction = vessel.dir
	clear_encounters()
	preparing = TRUE
	relocating = TRUE
	var/list/crew_spawns = list()
	var/list/old_turfs = vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir)
	var/list/new_turfs = vessel.return_ordered_turfs(target.x, target.y, target.z, target.dir)
	for(var/index in 1 to length(old_turfs))
		var/turf/spawn_tile = old_turfs[index]
		if((spawn_tile in SSjob.latejoin_trackers) && vessel.shuttle_areas[get_area(spawn_tile)])
			crew_spawns[spawn_tile] = new_turfs[index]
	var/result
	try
		result = vessel.initiate_docking(target)
	catch(var/exception/failure)
		relocating = FALSE
		preparing = was_preparing
		throw failure
	relocating = FALSE
	preparing = was_preparing
	if(QDELETED(src) || QDELETED(vessel) || QDELETED(target) || result != DOCKING_SUCCESS || vessel.get_docked() != target)
		status = "Манёвр не выполнен: корабль остался у прежней стоянки"
		return FALSE
	vessel.preferred_direction = turn(vessel.preferred_direction, dir2angle(original_direction) - dir2angle(vessel.dir))
	for(var/turf/original as anything in crew_spawns)
		SSjob.latejoin_trackers -= original
		SSjob.latejoin_trackers |= crew_spawns[original]
	return TRUE
// AI EDIT END
