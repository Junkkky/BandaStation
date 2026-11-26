/datum/stationtrauma_overmap_sector/space
	/// Public stationary contacts, once per installation regardless of its number of berths.
	var/list/datum/stationtrauma_overmap_site/space/docking_target/fixed_combat_sites = list()

/datum/stationtrauma_overmap_site/space/docking_target
	/// Native deck bounds used to project a sector firing line onto this installation.
	var/list/combat_bounds

/// Resolve the current physical level without reserving a docking slot.
/datum/stationtrauma_overmap_site/space/docking_target/proc/combat_berth(datum/stationtrauma_overmap_sector/space/sector)
	if(QDELETED(sector) || sector.sites[id] != src || host || failed)
		return null
	for(var/datum/stationtrauma_overmap_site/space/site as anything in berths)
		if(sector.is_station_berth(site) && site.docking_target == src && !site.failed)
			return site
	return null

/// Find the installation's mapped silhouette once per deck. Docked shuttles do not shift its centre.
/datum/stationtrauma_overmap_site/space/docking_target/proc/physical_bounds(datum/stationtrauma_overmap_site/space/site)
	var/level = site.berth.z
	if(combat_bounds && combat_bounds[MAP_MINZ] == level)
		return combat_bounds
	var/list/areas
	if(is_station_level(level))
		areas = GLOB.the_station_areas
	else
		var/area/outpost = relay_mapped_area(site)
		if(!outpost)
			return null
		areas = list(outpost.type)
	var/low_x = world.maxx
	var/low_y = world.maxy
	var/high_x = 0
	var/high_y = 0
	for(var/area_type in areas)
		var/area/deck_area = GLOB.areas_by_type[area_type]
		for(var/turf/tile as anything in deck_area?.get_turfs_by_zlevel(level))
			if(isspaceturf(tile) || tile.is_transition_turf())
				continue
			low_x = min(low_x, tile.x)
			low_y = min(low_y, tile.y)
			high_x = max(high_x, tile.x)
			high_y = max(high_y, tile.y)
	if(!high_x)
		return null
	combat_bounds = list(low_x, low_y, level, high_x, high_y, level)
	return combat_bounds

/// Enter the near edge of the physical map along the shot's bearing and fractional lateral offset.
/datum/stationtrauma_kinetic_shot/proc/project_into_site(datum/stationtrauma_overmap_site/space/docking_target/target, datum/stationtrauma_overmap_site/space/site, offset_x, offset_y)
	var/list/bounds = target.physical_bounds(site)
	if(!bounds)
		return
	var/half_x = (bounds[MAP_MAXX] - bounds[MAP_MINX]) / 2
	var/half_y = (bounds[MAP_MAXY] - bounds[MAP_MINY]) / 2
	var/offset = (offset_x * direction_y - offset_y * direction_x) / target.radius
	var/lateral = offset * (abs(direction_y) * half_x + abs(direction_x) * half_y)
	var/x = bounds[MAP_MINX] + half_x + direction_y * lateral
	var/y = bounds[MAP_MINY] + half_y - direction_x * lateral
	var/back = INFINITY
	if(direction_x)
		var/edge_x = direction_x > 0 ? max(TRANSITIONEDGE + 2, bounds[MAP_MINX] - 2) : min(world.maxx - TRANSITIONEDGE - 1, bounds[MAP_MAXX] + 2)
		back = (x - edge_x) / direction_x
	if(direction_y)
		var/edge_y = direction_y > 0 ? max(TRANSITIONEDGE + 2, bounds[MAP_MINY] - 2) : min(world.maxy - TRANSITIONEDGE - 1, bounds[MAP_MAXY] + 2)
		back = min(back, (y - edge_y) / direction_y)
	var/turf/entry = locate(round(x - direction_x * back, 1), round(y - direction_y * back, 1), bounds[MAP_MINZ])
	if(!entry || entry.is_transition_turf())
		return
	var/obj/projectile/bullet/stationtrauma_kinetic/round = new projectile_type(entry)
	round.target_site_ref = WEAKREF(target)
	round.target_sector_ref = sector_ref
	fire_incoming(round, delta_to_angle(direction_x, direction_y), 1, ceil(2 * sqrt(half_x ** 2 + half_y ** 2)) + 6)
