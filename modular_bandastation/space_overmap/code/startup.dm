/// Start navigation automatically only when Raven is the selected primary map.
SUBSYSTEM_DEF(stationtrauma_space_voyage)
	name = "StationTrauma space voyage"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/lighting,
		/datum/controller/subsystem/shuttle,
		/datum/controller/subsystem/icon_smooth,
	)

/datum/controller/subsystem/stationtrauma_space_voyage/Initialize()
	if(SSmapping.current_map.map_name != "Raven Overmap")
		return SS_INIT_NO_NEED
	GLOB.stationtrauma_space_loaded = TRUE
	var/obj/docking_port/mobile/stationtrauma_space/vessel = locate() in world
	var/exception/load_error
	try
		if(vessel)
			vessel = load_stationtrauma_space(vessel)
	catch(var/exception/failure)
		load_error = failure
	if(!vessel || load_error)
		stack_trace("Raven primary-map navigation failed: [load_error]")
		return SS_INIT_FAILURE
	var/obj/machinery/computer/stationtrauma_space_navigation/console = locate() in world
	for(var/turf/open/floor/spawn_turf in orange(2, console))
		if(!vessel.shuttle_areas[get_area(spawn_turf)] || spawn_turf.is_blocked_turf(TRUE))
			continue
		new /obj/effect/landmark/latejoin(spawn_turf)
		new /obj/effect/landmark/start/assistant/override(spawn_turf)
		new /obj/effect/landmark/observer_start(spawn_turf)
		log_mapping("Raven Overmap ready: vessel ([vessel.x], [vessel.y], [vessel.z]); crew spawn ([spawn_turf.x], [spawn_turf.y], [spawn_turf.z])")
		return SS_INIT_SUCCESS
	stack_trace("Raven has no free crew spawn near the bridge console")
	return SS_INIT_FAILURE
