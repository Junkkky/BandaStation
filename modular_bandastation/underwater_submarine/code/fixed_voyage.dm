/** Travel leaves the whole submarine and its surrounding ocean at permanent coordinates. */
/obj/docking_port/mobile/stationtrauma
	/// Current destination and route origin; the physical vessel always stays at home.
	var/obj/docking_port/stationary/stationtrauma/fixed_location
	/// Only our explicitly installed ocean seams are removed on departure.
	var/list/ocean_passages = list()
	/// Six event-driven strips project actors, without rendering a second ocean.
	var/list/ocean_previews = list()

/obj/docking_port/mobile/stationtrauma/Destroy()
	disconnect_ocean_passages()
	return ..()

/** Change only this vessel's areas, including the real ocean occupied by outside swimmers. */
/obj/docking_port/mobile/stationtrauma/proc/set_fixed_parallax(direction)
	var/list/areas = shuttle_areas.Copy()
	for(var/deck in 0 to decks - 1)
		areas[get_area(locate(1, 1, z + deck))] = TRUE
	for(var/area/zone as anything in areas)
		zone.set_parallax_movedir(direction)

/** A voyage never deletes actors or construction at either endpoint. */
/obj/docking_port/mobile/stationtrauma/proc/disconnect_ocean_passages()
	QDEL_LIST(ocean_previews)
	for(var/datum/component/stationtrauma_ocean_passage/passage as anything in ocean_passages)
		if(!QDELETED(passage))
			qdel(passage)
	ocean_passages.Cut()

/** Reserve a northern exit and southern return, beyond the visible buildings on all decks. */
/obj/docking_port/mobile/stationtrauma/proc/connect_ocean_location(obj/docking_port/stationary/stationtrauma/berth)
	if(!berth || !(berth in berths) || berth.z == z || SSfloodwater.loading_ocean_levels.len)
		return FALSE
	var/clearance = max(30, maxviewdist())
	var/ship_edge = y + height + clearance
	var/site_edge = berth.y - clearance
	if(ship_edge >= world.maxy - TRANSITIONEDGE || site_edge <= TRANSITIONEDGE + 1)
		return FALSE
	var/list/endpoints = list()
	for(var/deck in 0 to decks - 1)
		for(var/column in 1 to world.maxx)
			var/turf/open/ship_gate = locate(column, ship_edge, z + deck)
			var/turf/open/site_gate = locate(column, site_edge, berth.z + deck)
			var/turf/open/ship_landing = get_step(ship_gate, SOUTH)
			var/turf/open/site_landing = get_step(site_gate, NORTH)
			for(var/turf/open/tile as anything in list(ship_gate, site_gate, ship_landing, site_landing))
				var/datum/component/floodwater/water = tile?.GetComponent(/datum/component/floodwater)
				if(!isspaceturf(tile) || !water?.infinite_source || tile.destination_z || tile.GetComponent(/datum/component/stationtrauma_ocean_passage))
					return FALSE
				for(var/atom/movable/obstacle as anything in tile)
					if(obstacle.density)
						return FALSE
			endpoints += list(list(ship_gate, site_gate, ship_landing, site_landing))
	// Validate the whole corridor before publishing any of its links.
	for(var/list/pair as anything in endpoints)
		var/turf/open/ship_gate = pair[1]
		var/turf/open/site_gate = pair[2]
		ocean_passages += ship_gate.AddComponent(/datum/component/stationtrauma_ocean_passage, pair[4], NORTH)
		ocean_passages += site_gate.AddComponent(/datum/component/stationtrauma_ocean_passage, pair[3], SOUTH)
	for(var/deck in 0 to decks - 1)
		var/turf/ship_gate = locate(1, ship_edge, z + deck)
		var/turf/site_gate = locate(1, site_edge, berth.z + deck)
		ocean_previews += new /datum/stationtrauma_ocean_preview(ship_gate.GetComponent(/datum/component/stationtrauma_ocean_passage), world.maxx)
		ocean_previews += new /datum/stationtrauma_ocean_preview(site_gate.GetComponent(/datum/component/stationtrauma_ocean_passage), world.maxx)
	return TRUE

/** Load destinations while the unchanged boat keeps its active water, equipment and passengers. */
/obj/docking_port/mobile/stationtrauma/proc/travel_to(destination, animate_trip = TRUE)
	if(travelling || !fixed_location || SSfloodwater.loading_ocean_levels.len || SSfloodwater.loading_structure_turfs.len)
		return FALSE
	if(istext(destination))
		for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
			if(berth.name == destination)
				destination = berth
				break
	if(!istext(destination) && !(destination in berths))
		return FALSE
	var/distance = distance_to(destination)
	if(isnull(distance) || distance <= 0)
		return FALSE
	travelling = TRUE
	var/obj/docking_port/stationary/stationtrauma/selected = istext(destination) ? null : destination
	voyage_target = selected ? selected.name : destination
	voyage_status = "В пути: [voyage_target]"
	voyage_distance = distance
	voyage_started = world.time
	voyage_duration = animate_trip ? max(5 SECONDS, distance / max(1, cruise_speed) * 1 SECONDS) : 0
	voyage_progress = 0
	loading_fraction = istext(destination) ? 0 : 1
	disconnect_ocean_passages()
	set_fixed_parallax(EAST)
	var/success = FALSE
	var/exception/voyage_error
	try
		sleep(world.tick_lag)
		var/obj/docking_port/stationary/stationtrauma/berth = istext(destination) ? load_destination(destination) : destination
		if(berth)
			while(world.time < voyage_started + voyage_duration)
				sleep(world.tick_lag)
			if(connect_ocean_location(berth))
				fixed_location = berth
				voyage_progress = 1
				voyage_status = "Стоянка: [berth.name]"
				success = TRUE
	catch(var/exception/failure)
		voyage_error = failure
	if(!success)
		disconnect_ocean_passages()
		var/restored = connect_ocean_location(fixed_location)
		voyage_status = restored ? "Рейс отменён, восстановлен проход: [fixed_location.name]" : "Проход перекрыт. Освободите океанский коридор и повторите рейс."
	set_fixed_parallax(NONE)
	travelling = FALSE
	if(voyage_error)
		stack_trace("StationTrauma fixed voyage failed: [voyage_error]")
	return success
