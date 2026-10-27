/// Mapped vessel ports opt into the shared sector without checking a primary map name.
SUBSYSTEM_DEF(stationtrauma_space_voyage)
	name = "StationTrauma space voyage"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/lighting,
		/datum/controller/subsystem/shuttle,
		/datum/controller/subsystem/icon_smooth,
	)

	var/datum/stationtrauma_overmap_sector/space/sector

/datum/controller/subsystem/stationtrauma_space_voyage/Initialize()
	var/list/vessels = list()
	// Only startup scans mapped hulls; navigation processing uses the sector registry.
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in world)
		if(!vessel.registered)
			vessel.register()
		vessels += vessel
	if(!length(vessels))
		return SS_INIT_NO_NEED
	GLOB.stationtrauma_space_loaded = TRUE
	try
		for(var/obj/effect/landmark/stationtrauma_space_sector/scenario in GLOB.landmarks_list)
			for(var/map_path in scenario.ship_templates)
				var/obj/docking_port/mobile/stationtrauma_space/extra = load_stationtrauma_space_ship(map_path)
				if(!extra)
					CRASH("Failed to load sector ship [map_path]")
				extra.register()
				vessels += extra
		sector = new
		if(!sector.load_locations())
			CRASH("Failed to load sector destinations")
		for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in vessels)
			if(!sector.attach(vessel))
				CRASH("Failed to register sector ship [vessel.shuttle_id]")
	catch(var/exception/failure)
		stack_trace("Space sector initialization failed: [failure]")
		return SS_INIT_FAILURE
	log_mapping("Space sector ready: [length(sector.ships)] ships, [length(sector.sites)] destinations")
	return SS_INIT_SUCCESS
