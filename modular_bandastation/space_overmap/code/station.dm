// AI EDIT START - space overmap module integration
/datum/map_config
	/// Optional expedition profile; absent for ordinary station configurations.
	var/list/space_overmap

/datum/map_config/LoadConfig(filename, error_if_missing)
	. = ..()
	var/list/config = .
	space_overmap = islist(config) && islist(config["space_overmap"]) ? config["space_overmap"] : null

/// A native station berth whose capacity is supplied by the map config.
/obj/docking_port/stationary/stationtrauma_space_station
	shuttle_id = "overmap_station"
	/// Stable sector destination ID associated with this station berth.
	var/site_id
	/// Crew-facing station destination name.
	var/station_name

/** A shared bay has two profiles on one turf; expedition hulls must retain their own profile. */
/obj/docking_port/mobile/stationtrauma_space/get_docked()
	var/obj/docking_port/stationary/stationtrauma_space_station/port = locate() in loc
	if(port)
		return port
	return ..()

/** The emergency controller normally ignores occupancy; shared bays must not crush expedition ships. */
/obj/docking_port/mobile/emergency/canDock(obj/docking_port/stationary/target)
	if(istype(target?.get_docked(), /obj/docking_port/mobile/stationtrauma_space))
		return SHUTTLE_SOMEONE_ELSE_DOCKED
	return ..()

/** Every evacuation call path ends here; expedition hulls yield the shared bay without propulsion. */
/obj/docking_port/mobile/emergency/request(obj/docking_port/stationary/S, area/signal_origin, reason, red_alert, set_coefficient = null)
	. = ..()
	// Only opt-in overmap maps place expedition bays on the evacuation berth.
	if(mode == SHUTTLE_CALL && SSmapping.current_map.space_overmap)
		clear_stationtrauma_bay(SSshuttle.getDock("emergency_home"))

/** Arrival retries cover hulls that finished docking during the call or could not leave on the first attempt. */
/obj/docking_port/mobile/emergency/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	if(!force && mode == SHUTTLE_CALL)
		clear_stationtrauma_bay(new_dock)
	return ..()

/**
 * Start a service departure for an expedition hull docked at a station bay sharing the evacuation berth.
 *
 * Native occupancy keeps the bay blocked until the hull physically leaves, so crush protection is unchanged.
 * Arguments:
 * * home - Stationary port the evacuation shuttle is heading to
 */
/obj/docking_port/mobile/emergency/proc/clear_stationtrauma_bay(obj/docking_port/stationary/home)
	if(QDELETED(home))
		return
	for(var/obj/docking_port/stationary/stationtrauma_space_station/bay in home.loc)
		var/obj/docking_port/mobile/stationtrauma_space/ship = bay.get_docked()
		if(istype(ship) && !QDELETED(ship.overmap) && ship.overmap.docked?.berth == bay)
			INVOKE_ASYNC(ship.overmap, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, yield_station_bay))

/** A called evacuation shuttle claims the shared bay before arrival; native occupancy covers its stay. */
/obj/docking_port/mobile/stationtrauma_space/canDock(obj/docking_port/stationary/target)
	. = ..()
	if(. != SHUTTLE_CAN_DOCK || !istype(target, /obj/docking_port/stationary/stationtrauma_space_station) || SSshuttle.emergency?.mode != SHUTTLE_CALL)
		return .
	for(var/obj/docking_port/stationary/home in target.loc)
		if(home.shuttle_id == "emergency_home")
			return SHUTTLE_SOMEONE_ELSE_DOCKED
	return .

/** Service departure from a shared bay: no propulsion, fuel or helm order; the hull keeps its virtual position. */
/datum/stationtrauma_overmap/space/proc/yield_station_bay()
	var/datum/stationtrauma_overmap_site/space/site = docked
	if(!site?.physical_docking || relocating || preparing || ship_docking || QDELETED(flight_berth) || !is_operational() || site.docking_owner != src || vessel.get_docked() != site.berth)
		return
	var/obj/docking_port/stationary/stationtrauma_space_flight/berth = flight_berth
	var/turf/original_position = get_turf(berth)
	var/moved = FALSE
	var/exception/relocation_error
	preparing = TRUE
	try
		if(position_service_berth(site))
			moved = relocate(berth)
	catch(var/exception/failure)
		relocation_error = failure
	// Searching moves only our empty marker. Restore it if the physical hull never left the bay.
	if(!moved && !QDELETED(berth) && !QDELETED(vessel) && vessel.get_docked() == site.berth)
		berth.forceMove(original_position)
	if(QDELETED(src))
		return
	preparing = FALSE
	if(relocation_error)
		throw relocation_error
	if(!moved)
		status = "Причал не освобождён: нет безопасной орбитальной стоянки"
		return
	// Native relocation yields; only a hull still holding this dock state drops it.
	if(docked != site)
		return
	if(site.docking_owner == src)
		site.docking_owner = null
	docked = null
	if(sites[selected_destination] == site)
		selected_destination = null
		prepared_site = null
	stop("Причал станции освобождён для эвакуационного шаттла")
	navigation_notice("Причал станции освобождён для эвакуационного шаттла; корабль переведён на орбитальную стоянку.")

/** Validate the opt-in map profile and prepare its shared native berth and terminal. */
/datum/controller/subsystem/stationtrauma_space_voyage/proc/prepare_station(list/config)
	if(!istext(config["port"]) || !islist(config["ships"]) || !length(config["ships"]))
		CRASH("Overmap station requires a native port ID and an expedition fleet")
	var/obj/docking_port/stationary/anchor = SSshuttle.getDock(config["port"])
	if(QDELETED(anchor) || !is_station_level(anchor.z) || anchor.get_docked())
		CRASH("Overmap station requires a free native station berth")
	for(var/key in list("dock_width", "dock_height", "dock_dwidth", "dock_dheight"))
		if(!ISINTEGER(config[key]) || config[key] < 0)
			CRASH("Invalid overmap station dimension [key]")
	if(config["dock_width"] < 1 || config["dock_height"] < 1 || config["dock_dwidth"] >= config["dock_width"] || config["dock_dheight"] >= config["dock_height"] || !(config["dock_direction"] in GLOB.cardinals) || !istext(config["station_id"]) || !length(config["station_id"]) || !istext(config["station_name"]) || !length(config["station_name"]))
		CRASH("Invalid overmap station profile")
	var/turf/terminal_tile
	var/list/terminal = config["dispatch_terminal"]
	if(!isnull(terminal))
		// X/Y/Z offsets are relative to the native berth; the fourth value is the terminal direction.
		if(!islist(terminal) || length(terminal) != 4 || !ISINTEGER(terminal[1]) || !ISINTEGER(terminal[2]) || !ISINTEGER(terminal[3]) || !(terminal[4] in GLOB.cardinals))
			CRASH("Invalid overmap dispatch terminal placement")
		terminal_tile = locate(anchor.x + terminal[1], anchor.y + terminal[2], anchor.z + terminal[3])
		if(!isfloorturf(terminal_tile) || !is_station_level(terminal_tile.z) || terminal_tile.is_blocked_turf())
			CRASH("Overmap dispatch terminal requires an unoccupied station floor")
	var/obj/docking_port/stationary/stationtrauma_space_station/port = new(get_turf(anchor))
	port.width = config["dock_width"]
	port.height = config["dock_height"]
	port.dwidth = config["dock_dwidth"]
	port.dheight = config["dock_dheight"]
	port.setDir(config["dock_direction"])
	port.site_id = config["station_id"]
	port.station_name = port.name = config["station_name"]
	if(terminal_tile)
		var/obj/machinery/computer/stationtrauma_dispatch/console = new(terminal_tile)
		console.site_id = port.site_id
		console.setDir(terminal[4])
	return port
// AI EDIT END
