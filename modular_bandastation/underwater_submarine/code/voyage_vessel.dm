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
		"Скальный выход" = /datum/map_template/stationtrauma_route/voyage_rock,
	)
	/// True at sea, including stopped navigation and asynchronous location preparation.
	var/travelling = FALSE
	/// Shared by the navigation stations; starting engines never starts a voyage.
	var/engines_running = FALSE
	/// Prototype route distances are metres; speed is metres per second.
	var/cruise_speed = 50
	/// Mapped displacement in kg; movement never scans floodwater or cargo to calculate mass.
	var/navigation_mass = 10000000
	/// Nominal thrust in newtons per full-power PGD; initial gameplay calibration.
	var/nominal_drive_thrust = 10000000
	var/voyage_target
	var/voyage_progress = 0
	var/loading_fraction = 0
	/// Eurydice requires actual powered drives; the small mapping prototype retains its demonstration motor.
	var/requires_pgd = FALSE
	var/list/drive_engines = list()
	/// Quiet, cruise, full and boost, in that order.
	var/drive_mode = 2
	/// Virtual movement owns no physical water, turfs or power networks.
	var/datum/stationtrauma_overmap/submarine/overmap
	/// Cached navigation stations share one sonar mode and pulse cooldown.
	var/list/navigation_consoles = list()

/obj/docking_port/mobile/stationtrauma/proc/drive_power_fraction()
	var/static/list/fractions = list(0.1, 0.4, 1, 2)
	return fractions[drive_mode] * drive_command_fraction()

/obj/docking_port/mobile/stationtrauma/proc/drive_thrust_fraction()
	var/static/list/fractions = list(0.15, 0.5, 1, 1.4)
	return fractions[drive_mode] * drive_command_fraction()

/** Braking commands reverse thrust; an idle lever does not silently keep consuming full power. */
/obj/docking_port/mobile/stationtrauma/proc/drive_command_fraction()
	return overmap?.braking ? 1 : (overmap?.throttle || 0) / 100

/obj/docking_port/mobile/stationtrauma/proc/available_voyage_speed()
	if(!engines_running)
		return 0
	if(!requires_pgd)
		return cruise_speed * drive_command_fraction()
	var/thrust = 0
	for(var/obj/machinery/power/stationtrauma_pgd/engine as anything in drive_engines)
		thrust += engine.available_thrust()
	return cruise_speed * min(thrust, 6 * 1.4) / 6

/** Existing drive callers integrate old thrust before changing their output. */
/obj/docking_port/mobile/stationtrauma/proc/update_voyage_distance()
	overmap?.advance()

/obj/docking_port/mobile/stationtrauma/proc/stop_drive_output()
	for(var/obj/machinery/power/stationtrauma_pgd/engine as anything in drive_engines)
		engine.actual_power = 0
		engine.actual_thrust = 0
		engine.acoustic_signature = 0
		engine.update_drive_effects()

/obj/docking_port/mobile/stationtrauma/proc/refresh_drive_motion()
	overmap?.update_parallax()

/** Resolve only this vessel's stable site IDs. */
/obj/docking_port/mobile/stationtrauma/proc/distance_to(destination)
	var/datum/stationtrauma_overmap_site/site = overmap?.sites[destination]
	return site ? overmap.distance_to(site) : null

/** Physical travel and destination preparation advance independently. */
/obj/docking_port/mobile/stationtrauma/proc/path_progress()
	if(travelling)
		var/remaining = distance_to(overmap.selected_destination)
		voyage_progress = overmap.trip_distance && !isnull(remaining) ? clamp(1 - remaining / overmap.trip_distance, 0, 0.99) : 0
	return voyage_progress

/obj/docking_port/mobile/stationtrauma/proc/update_loading_progress(fraction)
	// Native loading ends before corridor preparation; reserve the final five percent for it.
	loading_fraction = max(loading_fraction, fraction * 0.95)

/obj/docking_port/mobile/stationtrauma/Initialize(mapload, list/areas)
	. = ..()
	register()
	map_connection = new(src, decks)

/** Finish ownership after the entire multi-z TGM has loaded, including areas created after the port. */
/obj/docking_port/mobile/stationtrauma/proc/configure_berths(list/ports)
	berths = ports.Copy()
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
		unloaded_destinations -= berth.name
	shuttle_areas.Cut()
	var/list/tiles = return_ordered_turfs(x, y, z, dir)
	for(var/turf/tile as anything in tiles)
		for(var/obj/machinery/power/stationtrauma_pgd/engine in tile)
			engine.vessel = src
			drive_engines |= engine
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
