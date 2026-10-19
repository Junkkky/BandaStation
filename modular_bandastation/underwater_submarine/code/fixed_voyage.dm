/** Travel leaves the whole submarine and its surrounding ocean at permanent coordinates. */
/obj/docking_port/mobile/stationtrauma
	/// Current destination and route origin; the physical vessel always stays at home.
	var/obj/docking_port/stationary/stationtrauma/fixed_location
	/// Only our explicitly installed ocean seams are removed on departure.
	var/list/ocean_passages = list()
	/// Six event-driven strips project actors, without rendering a second ocean.
	var/list/ocean_previews = list()
	/// One flag opens every prepared gate together after the journey completes.
	var/ocean_connection_active = FALSE
	/// A removed/replaced gate invalidates a preparation paused between server ticks.
	var/ocean_connection_revision = 0
	/// Revision captured before building the inactive corridor.
	var/ocean_prepared_revision = 0

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
	ocean_connection_active = FALSE
	ocean_connection_revision++
	QDEL_LIST(ocean_previews)
	QDEL_LIST(ocean_passages)

/** Close every gate immediately, then spread subscription destruction over server ticks. */
/obj/docking_port/mobile/stationtrauma/proc/disconnect_ocean_cooperatively(datum/stationtrauma_work_budget/budget)
	ocean_connection_active = FALSE
	ocean_connection_revision++
	var/list/previews = ocean_previews
	var/list/passages = ocean_passages
	ocean_previews = list()
	ocean_passages = list()
	for(var/datum/stationtrauma_ocean_preview/preview as anything in previews)
		if(!QDELETED(preview))
			preview.suspend()
	for(var/datum/stationtrauma_ocean_preview/preview as anything in previews)
		if(!QDELETED(preview))
			preview.clear_cooperatively(budget)
			qdel(preview)
	for(var/datum/component/stationtrauma_ocean_passage/passage as anything in passages)
		budget.yield()
		if(!QDELETED(passage))
			qdel(passage)

/** Keep the existing corridor rules, allowing only this vessel's own prepared gates. */
/obj/docking_port/mobile/stationtrauma/proc/ocean_gate_available(turf/open/tile, allow_owned = FALSE)
	var/datum/component/floodwater/water = tile?.GetComponent(/datum/component/floodwater)
	if(!isspaceturf(tile) || !water?.infinite_source || tile.destination_z)
		return FALSE
	var/datum/component/stationtrauma_ocean_passage/passage = tile.GetComponent(/datum/component/stationtrauma_ocean_passage)
	if(passage && (!allow_owned || passage.vessel != src))
		return FALSE
	for(var/atom/movable/obstacle as anything in tile)
		if(obstacle.density)
			return FALSE
	return TRUE

/** Prepare inactive gates and previews cooperatively; publish only a complete corridor. */
/obj/docking_port/mobile/stationtrauma/proc/connect_ocean_location(obj/docking_port/stationary/stationtrauma/berth, datum/stationtrauma_work_budget/budget, activate = TRUE)
	if(!berth || !(berth in berths) || berth.z == z || SSfloodwater.loading_ocean_levels.len || ocean_passages.len || ocean_previews.len)
		return FALSE
	budget ||= new
	ocean_prepared_revision = ocean_connection_revision
	var/ready = FALSE
	try
		ready = prepare_ocean_location(berth, budget)
		if(ready && activate)
			ready = activate_ocean_passages(budget)
	catch(var/exception/failure)
		disconnect_ocean_cooperatively(budget)
		throw failure
	if(!ready)
		disconnect_ocean_cooperatively(budget)
	return ready

/** Native components remain disabled while yields permit the rest of the game to run. */
/obj/docking_port/mobile/stationtrauma/proc/prepare_ocean_location(obj/docking_port/stationary/stationtrauma/berth, datum/stationtrauma_work_budget/budget)
	var/clearance = max(30, maxviewdist())
	var/ship_edge = y + height + clearance
	var/site_edge = berth.y - clearance
	if(ship_edge >= world.maxy - TRANSITIONEDGE || site_edge <= TRANSITIONEDGE + 1)
		return FALSE
	for(var/deck in 0 to decks - 1)
		for(var/column in 1 to world.maxx)
			budget.yield()
			if(QDELETED(src) || QDELETED(berth) || ocean_prepared_revision != ocean_connection_revision)
				return FALSE
			var/turf/open/ship_gate = locate(column, ship_edge, z + deck)
			var/turf/open/site_gate = locate(column, site_edge, berth.z + deck)
			var/turf/open/ship_landing = get_step(ship_gate, SOUTH)
			var/turf/open/site_landing = get_step(site_gate, NORTH)
			for(var/turf/open/tile as anything in list(ship_gate, site_gate, ship_landing, site_landing))
				if(!ocean_gate_available(tile))
					return FALSE
			ocean_passages += ship_gate.AddComponent(/datum/component/stationtrauma_ocean_passage, site_landing, NORTH, src)
			ocean_passages += site_gate.AddComponent(/datum/component/stationtrauma_ocean_passage, ship_landing, SOUTH, src)
	for(var/deck in 0 to decks - 1)
		var/turf/ship_gate = locate(1, ship_edge, z + deck)
		var/turf/site_gate = locate(1, site_edge, berth.z + deck)
		for(var/turf/gate as anything in list(ship_gate, site_gate))
			var/datum/stationtrauma_ocean_preview/preview = new(gate.GetComponent(/datum/component/stationtrauma_ocean_passage), world.maxx, TRUE)
			ocean_previews += preview
			if(!preview.rebuild(budget) || QDELETED(src) || ocean_prepared_revision != ocean_connection_revision)
				return FALSE
	return TRUE

/** Recheck live gates, then open both directions in one non-yielding publication. */
/obj/docking_port/mobile/stationtrauma/proc/activate_ocean_passages(datum/stationtrauma_work_budget/budget)
	if(QDELETED(src) || !ocean_passages.len || ocean_prepared_revision != ocean_connection_revision)
		return FALSE
	for(var/datum/component/stationtrauma_ocean_passage/passage as anything in ocean_passages)
		budget?.yield()
		if(QDELETED(src) || QDELETED(passage) || !ocean_gate_available(passage.parent, TRUE) || !ocean_gate_available(passage.landing, TRUE))
			return FALSE
	if(ocean_prepared_revision != ocean_connection_revision)
		return FALSE
	for(var/datum/stationtrauma_ocean_preview/preview as anything in ocean_previews)
		if(QDELETED(preview) || preview.closing || preview.rebuilding)
			return FALSE
	ocean_connection_active = TRUE
	for(var/datum/stationtrauma_ocean_preview/preview as anything in ocean_previews)
		preview.activate()
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
	var/datum/stationtrauma_work_budget/budget = new
	set_fixed_parallax(EAST)
	disconnect_ocean_cooperatively(budget)
	var/success = FALSE
	var/exception/voyage_error
	try
		sleep(world.tick_lag)
		var/obj/docking_port/stationary/stationtrauma/berth = istext(destination) ? load_destination(destination) : destination
		if(berth && connect_ocean_location(berth, budget, FALSE))
			while(world.time < voyage_started + voyage_duration)
				sleep(world.tick_lag)
			if(activate_ocean_passages(budget))
				fixed_location = berth
				voyage_progress = 1
				voyage_status = "Стоянка: [berth.name]"
				success = TRUE
	catch(var/exception/failure)
		voyage_error = failure
	if(!success)
		disconnect_ocean_cooperatively(budget)
		var/restored = connect_ocean_location(fixed_location, budget)
		voyage_status = restored ? "Рейс отменён, восстановлен проход: [fixed_location.name]" : "Проход перекрыт. Освободите океанский коридор и повторите рейс."
	set_fixed_parallax(NONE)
	travelling = FALSE
	if(voyage_error)
		stack_trace("StationTrauma fixed voyage failed: [voyage_error]")
	return success
