/** Native shuttle hull participating in the overmap. */
/obj/docking_port/mobile/stationtrauma_space
	name = "Корабль"
	shuttle_id = "overmap_ship"
	area_type = /area/shuttle/stationtrauma_space
	/// Owned virtual navigation instance attached to this physical hull.
	var/datum/stationtrauma_overmap/space/overmap
	/// Navigation metres and heading; physical coordinates are supplied by the native port.
	var/overmap_x = 0
	/// Mapped starting northing in virtual sector units.
	var/overmap_y = 0
	/// Mapped initial compass heading in degrees.
	var/overmap_course = 90
	/// Optional sector site ID to dock at during scenario initialization.
	var/starting_dock
	/// Mapped starting sector ID.
	var/overmap_sector = "epsilon_eridani"
	/// Whether a station terminal may call this idle ship to its berth.
	var/dispatchable = FALSE
	/// Crew main-engine switch; propulsion requires this and intact engines.
	var/engines_running = FALSE
	/// Mapped combustion controller; ordinary ships keep their existing propulsion model.
	var/datum/weakref/combustion_controller
	/// Mapper-declared role; physical berth compatibility still uses the actual hull dimensions.
	var/ship_class = ST_SHIP_MEDIUM
	/// Whether this hull may use planetary surface berths.
	var/can_land = TRUE
	/// Connected transponder consoles; each console unregisters during teardown.
	var/list/transponders = list()

/** Check mapped hull class and landing capability against the destination kind. */
/obj/docking_port/mobile/stationtrauma_space/proc/permits_docking(datum/stationtrauma_overmap_site/space/site)
	if(QDELETED(site))
		return FALSE
	if(ship_class == ST_SHIP_CAPITAL)
		return !site.landing && !site.physical_docking
	return (ship_class == ST_SHIP_SMALL || ship_class == ST_SHIP_MEDIUM) && (!site.landing || can_land)

/** Pair receivers after the native pass has registered every nozzle, regardless of map order. */
/obj/docking_port/mobile/stationtrauma_space/linkup(obj/docking_port/stationary/dock)
	. = ..()
	var/obj/machinery/computer/ship_combustion/chamber = combustion_controller?.resolve()
	chamber?.bind_propulsion()
	bind_plasma_heaters()

/** Plasma heaters have no controller, so each unfed nozzle looks for one directly behind it. */
/obj/docking_port/mobile/stationtrauma_space/proc/bind_plasma_heaters()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_list)
		if(!engine.requires_combustion || engine.combustion_feed?.resolve())
			continue
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/heater = locate() in get_step(engine, REVERSE_DIR(engine.dir))
		heater?.bind_nozzle(src)

/** Whether any compartment still has equipment power; unpowered-by-design hulls always do. */
/obj/docking_port/mobile/stationtrauma_space/proc/has_power()
	for(var/area/ship_area as anything in shuttle_areas)
		if(ship_area.powered(AREA_USAGE_EQUIP))
			return TRUE
	return FALSE

/** Pilot fuel gauges: the combustion chamber's supply, otherwise the plasma heaters' supply; null for unfuelled drives. */
/obj/docking_port/mobile/stationtrauma_space/proc/fuel_gauges()
	var/obj/machinery/computer/ship_combustion/chamber = combustion_controller?.resolve()
	if(chamber)
		return chamber.fuel_reserve()
	var/list/networks = list()
	var/heaters = 0
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_list)
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/heater = engine.combustion_feed?.resolve()
		if(!istype(heater))
			continue
		heaters++
		if(heater.parents[1])
			networks |= heater.parents[1]
	return heaters ? stationtrauma_fuel_gauges(networks, list(/datum/gas/plasma = "Плазма")) : null

/obj/docking_port/mobile/stationtrauma_space/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE
	for(var/obj/machinery/computer/stationtrauma_transponder/device as anything in transponders)
		device.vessel = null
	transponders.Cut()
	var/obj/machinery/computer/ship_combustion/chamber = combustion_controller?.resolve()
	chamber?.stop_chamber("Потеря связи с кораблём")
	combustion_controller = null
	QDEL_NULL(overmap)
	return ..()

/** Physical anchor for a destination connected by a remote map seam. */
/obj/docking_port/stationary/stationtrauma_space_site
	name = "Стыковочная площадка"
