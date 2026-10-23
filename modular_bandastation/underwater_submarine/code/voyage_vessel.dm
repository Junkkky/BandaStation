/** A permanent vessel marker owns its decks, equipment and route state. */
/obj/docking_port/mobile/stationtrauma
	name = "подлодка «Нырок»"
	shuttle_id = "stationtrauma_prototype"
	area_type = /area/shuttle/stationtrauma
	width = 17
	height = 11
	/// Number of connected decks in the permanent vessel footprint.
	var/decks = 3
	/// Explicit destinations supplied by the prototype loader.
	var/list/berths = list()
	/// Destinations become persistent berths on their first visit.
	var/list/unloaded_destinations = list(
		"Исследовательский пост" = /datum/map_template/stationtrauma_route/voyage_outpost,
		"Затопленные руины" = /datum/map_template/stationtrauma_route/voyage_ruins,
	)
	/// Departure animation and destination loading share one command lock.
	var/travelling = FALSE
	/// Shared by the navigation stations; starting engines never starts a voyage.
	var/engines_running = FALSE
	var/selected_destination
	/// Visible state on the navigation console.
	var/voyage_status = "На стоянке"
	/// Prototype route distances are metres; speed is metres per second.
	var/cruise_speed = 50
	var/voyage_distance = 0
	var/voyage_target
	var/voyage_started = 0
	var/voyage_duration = 0
	var/voyage_progress = 0
	var/loading_fraction = 0

/** Distance is route metadata, independent of the z coordinates used to store a location. */
/obj/docking_port/mobile/stationtrauma/proc/distance_to(destination)
	if(!istext(destination) && !istype(destination, /obj/docking_port/stationary/stationtrauma))
		return null
	var/obj/docking_port/stationary/stationtrauma/origin = fixed_location
	if(!origin)
		return null
	var/position
	if(istype(destination, /obj/docking_port/stationary/stationtrauma))
		var/obj/docking_port/stationary/stationtrauma/berth = destination
		position = berth.route_position
	else
		for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
			if(berth.name == destination)
				return abs(berth.route_position - origin.route_position)
		var/datum/map_template/stationtrauma_route/template_type = unloaded_destinations[destination]
		if(!template_type)
			return null
		var/obj/docking_port/stationary/stationtrauma/berth_type = initial(template_type.destination_berth_type)
		position = initial(berth_type.route_position)
	return abs(position - origin.route_position)

/** Arrival readiness bounds the approach; reaching the timer alone never reports a completed trip. */
/obj/docking_port/mobile/stationtrauma/proc/path_progress()
	if(travelling)
		var/time_fraction = voyage_duration ? (world.time - voyage_started) / voyage_duration : 1
		voyage_progress = max(voyage_progress, min(0.98, time_fraction, 0.1 + 0.88 * loading_fraction))
	return voyage_progress

/obj/docking_port/mobile/stationtrauma/proc/update_loading_progress(fraction)
	loading_fraction = max(loading_fraction, fraction)

/obj/docking_port/mobile/stationtrauma/Initialize(mapload, list/areas)
	. = ..()
	register()

/** Finish ownership after the entire multi-z TGM has loaded, including areas created after the port. */
/obj/docking_port/mobile/stationtrauma/proc/configure_berths(list/ports)
	berths = ports.Copy()
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
		unloaded_destinations -= berth.name
	shuttle_areas.Cut()
	var/list/tiles = return_ordered_turfs(x, y, z, dir)
	for(var/turf/tile as anything in tiles)
		var/area/ship_area = get_area(tile)
		if(!istype(ship_area, area_type))
			if(isspaceturf(tile))
				continue
			return FALSE
		shuttle_areas[ship_area] = TRUE
		for(var/obj/machinery/computer/stationtrauma_navigation/console in tile)
			console.link_vessel(src)
	for(var/turf/tile as anything in tiles)
		if(shuttle_areas[get_area(tile)])
			SSfloodwater.ensure_water_domain(tile)
	return !!shuttle_areas.len

/** Enumerate every deck when binding the permanent vessel's areas and equipment. */
/obj/docking_port/mobile/stationtrauma/return_ordered_turfs(_x, _y, _z, _dir)
	. = list()
	for(var/deck in 0 to decks - 1)
		. += ..(_x, _y, _z + deck, _dir)

/obj/docking_port/mobile/stationtrauma/is_in_shuttle_bounds(atom/target)
	var/turf/tile = get_turf(target)
	return tile && tile.z >= z && tile.z < z + decks && tile.x >= x && tile.x < x + width && tile.y >= y && tile.y < y + height && shuttle_areas[get_area(tile)]

/** The marker retains native bounds, but even forced shuttle commands must not copy this vessel. */
/obj/docking_port/mobile/stationtrauma/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	return DOCKING_BLOCKED
