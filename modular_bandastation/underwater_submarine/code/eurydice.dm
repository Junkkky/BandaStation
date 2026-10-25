/** Temporary deck zoning until the vessel has its own rooms and power grid. */
/area/station/stationtrauma/eurydice
	name = "Эвридика: нижняя палуба"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/area/station/stationtrauma/eurydice/middle
	name = "Эвридика: средняя палуба"

/area/station/stationtrauma/eurydice/upper
	name = "Эвридика: верхняя палуба"

/area/station/stationtrauma/eurydice/bridge
	name = "Эвридика: мостик"

/** Keep editor saves using the initial placeholder paths compatible with station zoning. */
/area/shuttle/stationtrauma/eurydice
	parent_type = /area/station/stationtrauma/eurydice

/area/shuttle/stationtrauma/eurydice/middle
	parent_type = /area/station/stationtrauma/eurydice/middle

/area/shuttle/stationtrauma/eurydice/upper
	parent_type = /area/station/stationtrauma/eurydice/upper

/area/shuttle/stationtrauma/eurydice/bridge
	parent_type = /area/station/stationtrauma/eurydice/bridge

/** Editable primary-map hull; navigation never copies its turfs. */
/obj/docking_port/mobile/stationtrauma/eurydice
	requires_pgd = TRUE
	name = "НИС «Эвридика»"
	shuttle_id = "stationtrauma_eurydice"
	area_type = /area/station/stationtrauma/eurydice
	width = 133
	height = 39

/** A placeholder room, not a working dry-dock simulation. */
/area/stationtrauma_voyage_site/eurydice_dock
	name = "Эвридика: временный док"

/obj/docking_port/stationary/stationtrauma/eurydice_dock
	name = "Временный док"
	shuttle_id = "stationtrauma_eurydice_dock"

/** Fill the primary map's untouched exterior before native atom initialization. */
SUBSYSTEM_DEF(stationtrauma_ocean)
	name = "StationTrauma ocean"
	ss_flags = SS_NO_FIRE
	dependencies = list(/datum/controller/subsystem/spatial_grid)
	dependents = list(/datum/controller/subsystem/atoms)

/datum/controller/subsystem/stationtrauma_ocean/Initialize()
	var/obj/docking_port/mobile/stationtrauma/eurydice/vessel = locate() in world
	if(!vessel)
		return SS_INIT_NO_NEED
	var/obj/docking_port/stationary/stationtrauma/eurydice_dock/dock = locate() in world
	if(!dock)
		stack_trace("Eurydice primary map is missing its dock map")
		return SS_INIT_FAILURE
	GLOB.stationtrauma_voyage_loaded = TRUE
	var/datum/map_template/stationtrauma_route/ocean = new
	ocean.loading_budget = new
	ocean.loading_decks = vessel.decks
	var/list/levels = list()
	for(var/obj/docking_port/anchor as anything in list(vessel, dock))
		for(var/deck in 0 to vessel.decks - 1)
			levels += anchor.z + deck
			SSfloodwater.loading_ocean_levels["[anchor.z + deck]"] = TRUE
	var/exception/load_error
	try
		for(var/obj/docking_port/anchor as anything in list(vessel, dock))
			ocean.loading_first_z = anchor.z
			ocean.exterior_ocean_area = anchor == vessel ? /area/space/ocean/stationtrauma_berth/home : null
			for(var/deck in 0 to vessel.decks - 1)
				if(!ocean.fill_ocean(anchor.z + deck))
					throw EXCEPTION("Could not fill Eurydice exterior z=[anchor.z + deck]")
		// Mapped ocean must scroll with the vessel too, without changing its turf variables or machinery.
		var/area/home = GLOB.areas_by_type[/area/space/ocean/stationtrauma_berth/home]
		if(!home)
			home = new /area/space/ocean/stationtrauma_berth/home
		for(var/turf/tile as anything in vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir))
			ocean.loading_budget.yield()
			if(!istype(tile.loc, vessel.area_type) && (istype(tile, /turf/open/space/ocean) || istype(tile, /turf/open/space/openspace/ocean)))
				tile.change_area(tile.loc, home)
	catch(var/exception/failure)
		load_error = failure
	for(var/level in levels)
		SSfloodwater.loading_ocean_levels -= "[level]"
	qdel(ocean)
	if(load_error)
		stack_trace("Eurydice primary ocean failed: [load_error]")
		return SS_INIT_FAILURE
	return SS_INIT_SUCCESS

/** Bind the already initialized primary vessel and open its initial dock connection once. */
SUBSYSTEM_DEF(stationtrauma_voyage)
	name = "StationTrauma voyage"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/lighting,
		/datum/controller/subsystem/shuttle,
		/datum/controller/subsystem/icon_smooth,
	)

/datum/controller/subsystem/stationtrauma_voyage/Initialize()
	var/obj/docking_port/mobile/stationtrauma/eurydice/vessel = locate() in SSshuttle.mobile_docking_ports
	if(!vessel)
		return SS_INIT_NO_NEED
	var/obj/docking_port/stationary/stationtrauma/eurydice_dock/dock = locate() in SSshuttle.stationary_docking_ports
	if(!dock || !vessel.configure_berths(list(dock)))
		stack_trace("Eurydice primary vessel or dock has invalid bounds/areas")
		return SS_INIT_FAILURE
	vessel.fixed_location = dock
	vessel.overmap = new(vessel)
	vessel.overmap.preload_destinations()
	vessel.overmap.status = "Стоянка: [dock.name]"
	vessel.set_fixed_parallax(NONE)
	if(!vessel.connect_ocean_location(dock))
		stack_trace("Eurydice could not open the initial dock connection")
		return SS_INIT_FAILURE
	log_mapping("Eurydice ready: vessel ([vessel.x], [vessel.y], [vessel.z]); dock ([dock.x], [dock.y], [dock.z])")
	return SS_INIT_SUCCESS
