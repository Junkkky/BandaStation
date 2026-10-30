// AI EDIT START - space overmap module integration
/// Mapped vessel ports opt into the shared sector without checking a primary map name.
SUBSYSTEM_DEF(stationtrauma_space_voyage)
	name = "StationTrauma space voyage"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/lighting,
		/datum/controller/subsystem/shuttle,
		/datum/controller/subsystem/icon_smooth,
	)

	/// Owned sector ID to resident sector instance mapping.
	var/list/sectors = list()
	/// Prevents overlapping sector preparation.
	var/loading = FALSE

/** All small destinations are resident before any vessel can enter the sector network. */
/datum/controller/subsystem/stationtrauma_space_voyage/proc/load_sectors()
	if(loading)
		return FALSE
	if(length(sectors))
		for(var/id in sectors)
			var/datum/stationtrauma_overmap_sector/space/sector = sectors[id]
			if(!sector.ready)
				return FALSE
		return TRUE
	loading = TRUE
	for(var/sector_type in list(/datum/stationtrauma_overmap_sector/space/home, /datum/stationtrauma_overmap_sector/space))
		var/datum/stationtrauma_overmap_sector/space/sector = new sector_type
		sectors[sector.id] = sector
		if(!sector.load_locations())
			return FALSE
	loading = FALSE
	return TRUE

/datum/controller/subsystem/stationtrauma_space_voyage/Initialize()
	var/list/vessels = list()
	var/list/config = SSmapping.current_map.space_overmap
	if(config)
		var/obj/docking_port/stationary/stationtrauma_space_station/port
		try
			port = prepare_station(config)
		catch(var/exception/failure)
			log_mapping("Overmap station preparation failed: [failure] at [failure.file]:[failure.line]")
			return SS_INIT_FAILURE
		// Atom initialization needs its native cleanup even when one mapped atom fails.
		for(var/list/ship_config as anything in config["ships"])
			if(!islist(ship_config))
				log_mapping("Invalid expedition ship profile")
				return SS_INIT_FAILURE
			var/map_path = ship_config["template"]
			if(!istext(map_path) || !fexists(map_path))
				log_mapping("Missing expedition ship template [map_path]")
				return SS_INIT_FAILURE
			var/obj/docking_port/mobile/stationtrauma_space/ship = load_stationtrauma_space_ship(map_path)
			if(!ship)
				log_mapping("Failed to load expedition ship [map_path]")
				return SS_INIT_FAILURE
			ship.dispatchable = !!ship_config["dispatchable"]
			if(ship_config["starts_docked"])
				ship.starting_dock = port.site_id
				ship.overmap_x = 1000
	// Only startup scans mapped hulls; navigation processing uses the sector registry.
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in world)
		if(!vessel.registered)
			vessel.register()
		vessels += vessel
	if(!length(vessels))
		return SS_INIT_NO_NEED
	for(var/obj/effect/landmark/stationtrauma_space_sector/scenario in GLOB.landmarks_list)
		for(var/map_path in scenario.ship_templates)
			var/obj/docking_port/mobile/stationtrauma_space/extra = load_stationtrauma_space_ship(map_path)
			if(!extra)
				log_mapping("Failed to load sector ship [map_path]")
				return SS_INIT_FAILURE
			extra.register()
			vessels += extra
	if(!load_sectors())
		log_mapping("Failed to load sector destinations")
		return SS_INIT_FAILURE
	try
		for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in vessels)
			var/datum/stationtrauma_overmap_sector/space/sector = sectors[vessel.overmap_sector]
			if(!sector?.ready)
				CRASH("Unknown or unavailable sector [vessel.overmap_sector]")
			if(!sector.attach(vessel))
				CRASH("Failed to register sector ship [vessel.shuttle_id]")
	catch(var/exception/failure)
		stack_trace("Space sector initialization failed: [failure] at [failure.file]:[failure.line]")
		return SS_INIT_FAILURE
	log_mapping("Space sectors ready: [length(sectors)] sectors, [length(vessels)] ships")
	return SS_INIT_SUCCESS
// AI EDIT END
