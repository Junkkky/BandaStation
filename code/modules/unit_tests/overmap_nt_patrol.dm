/// Verify the actual patrol hull and the all-or-nothing transition from lobby seats to mapped spawns.
/datum/unit_test/overmap_nt_patrol
	/// Original registry, isolated from test names.
	var/list/original_ship_names
	/// Original round's mission selection.
	var/list/original_mission_limits
	/// Physical template footprint retained for teardown.
	var/datum/map_template/stationtrauma_space/ship/template
	/// Additional physical hull retained for teardown.
	var/datum/map_template/stationtrauma_space/ship/second_template
	/// Original native port counters.
	var/list/original_ports
	/// Native stationary port counters, including the temporary flight berth.
	var/list/original_stationary_ports
	/// Pre-existing reusable flight deck. Restored after the rejected-load test.
	var/original_staging_level
	/// Isolated overmap exterior, restored after the loaded hull is removed.
	var/area/space/stationtrauma_space_home/exterior
	/// Original station job queue.
	var/list/original_unassigned
	/// Original map option so the opt-in preference can be exercised on the unit-test map.
	var/list/original_overmap
	/// Crew job counts and spawn lists before the test.
	var/list/original_jobs = list()
	/// Generator audio is unrelated to the map and seat contract.
	var/original_sound_processing

/datum/unit_test/overmap_nt_patrol/Run()
	try
		exercise_patrol()
	catch(var/exception/failure)
		discard_test_hull()
		throw failure
	discard_test_hull()

/// Exercise the same sector attachment that prepares the native flight berth and hull layers.
/datum/unit_test/overmap_nt_patrol/proc/exercise_patrol()
	original_ship_names = GLOB.used_away_ship_names
	GLOB.used_away_ship_names = list()
	original_mission_limits = SSjob.away_mission_limits
	original_ports = SSshuttle.assoc_mobile.Copy()
	original_stationary_ports = SSshuttle.assoc_stationary.Copy()
	original_staging_level = SSstationtrauma_space_voyage.dispatch_staging_level
	original_unassigned = SSjob.unassigned
	original_overmap = SSmapping.current_map.space_overmap
	original_sound_processing = SSsound_loops.can_fire
	SSsound_loops.can_fire = FALSE
	var/datum/roundstart_away_mission/nt_patrol/mission = locate() in roundstart_away_missions()
	TEST_ASSERT_NOTNULL(mission, "The patrol destroyer must be available from the mission pool")
	var/obj/docking_port/mobile/stationtrauma_space/ship
	var/obj/docking_port/mobile/stationtrauma_space/second_ship
	if(original_overmap && SSstationtrauma_space_voyage.initialized && length(SSstationtrauma_space_voyage.sectors))
		for(var/obj/docking_port/mobile/stationtrauma_space/existing in SSshuttle.mobile_docking_ports)
			TEST_ASSERT_NOTEQUAL(existing.source_template, mission.map_path, "The patrol destroyer must stay out of an empty roundstart fleet")
		var/list/loaded_templates = list()
		var/datum/callback/rejected_claim = CALLBACK(src, PROC_REF(reject_patrol_arrival))
		TEST_ASSERT_NULL(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, rejected_claim, loaded_templates), "A cancelled claim must leave no hull available for boarding")
		var/staging_level = SSstationtrauma_space_voyage.dispatch_staging_level
		TEST_ASSERT(staging_level && !length(loaded_templates), "A cancelled claim must return its cleaned deck and retain no template")
		var/datum/callback/arrival_check = CALLBACK(mission, TYPE_PROC_REF(/datum/roundstart_away_mission, find_latejoin_spawn))
		ship = SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check, loaded_templates)
		if(length(loaded_templates))
			template = loaded_templates[1]
			allocated += template
		TEST_ASSERT_NOTNULL(ship, "The accepted arrival check must load the actual hull from the mission template")
		TEST_ASSERT_EQUAL(length(loaded_templates), 1, "First arrival needs exactly one newly loaded hull")
		TEST_ASSERT_EQUAL(ship.z, staging_level, "The next claim must reuse the rejected load's deck")
		TEST_ASSERT_EQUAL(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check, loaded_templates), ship, "A second arrival must reuse the same loaded hull")
		TEST_ASSERT_EQUAL(length(loaded_templates), 1, "Rejoining must not allocate another ship template")

		// Explicit additional hulls must go through the same native loader and have independent decks.
		SSjob.away_mission_limits = list()
		SSjob.update_away_job_capacity()
		TEST_ASSERT_NULL(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check), "Disabling missions must prevent boarding an existing hull")
		TEST_ASSERT_NULL(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check, new_instance = TRUE), "Disabling missions must prevent manual launches")
		SSjob.away_mission_limits = list(/datum/roundstart_away_mission/nt_patrol = 2)
		SSjob.update_away_job_capacity()
		second_ship = SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check, loaded_templates, new_instance = TRUE)
		if(length(loaded_templates) > 1)
			second_template = loaded_templates[2]
			allocated += second_template
		TEST_ASSERT(second_ship && second_ship != ship, "An explicitly requested second patrol ship must load a separate hull")
		TEST_ASSERT_NOTEQUAL(second_ship.shuttle_id, ship.shuttle_id, "Every copy needs a distinct native shuttle ID")
		TEST_ASSERT_EQUAL(length(second_ship.shuttle_areas & ship.shuttle_areas), 0, "Copies must keep their machinery in separate areas")
		var/turf/second_arrival = mission.find_latejoin_spawn(second_ship)
		TEST_ASSERT(second_arrival && second_arrival.z != ship.z, "Each copy needs its own cryopod arrival")
		TEST_ASSERT_NOTEQUAL(second_ship.overmap.pos_y, ship.overmap.pos_y, "Copies must have different overmap coordinates")
		var/obj/machinery/computer/stationtrauma_transponder/nt_patrol/first_transponder = locate() in ship.transponders
		var/obj/machinery/computer/stationtrauma_transponder/nt_patrol/second_transponder = locate() in second_ship.transponders
		var/obj/item/circuitboard/computer/stationtrauma_transponder/first_board = first_transponder?.circuit
		var/obj/item/circuitboard/computer/stationtrauma_transponder/second_board = second_transponder?.circuit
		TEST_ASSERT(first_board?.callsign && second_board?.callsign && first_board.callsign != second_board.callsign, "Uncrewed copies must start with different registered callsigns")
		TEST_ASSERT_EQUAL(ship.name, "ОКН «[first_board.callsign]»", "The hull name must agree with its registered callsign")
		TEST_ASSERT_NULL(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check, new_instance = TRUE), "A third copy must not exceed the configured limit")
	else
		template = allocate(/datum/map_template/stationtrauma_space/ship, mission.map_path, mission.name)
		ship = template.load_ship()
		TEST_ASSERT_NOTNULL(ship, "The actual patrol map must load")
		var/datum/stationtrauma_overmap_sector/space/sector = allocate(/datum/stationtrauma_overmap_sector/space)
		sector.id = "unit_test_nt_patrol"
		sector.ready = TRUE
		TEST_ASSERT(sector.attach(ship), "The native overmap must accept the patrol destroyer")
	exterior = ship.overmap.exterior
	STOP_PROCESSING(SSfastprocess, ship.overmap)
	var/turf/arrival = mission.find_latejoin_spawn(ship)
	TEST_ASSERT_NOTNULL(arrival, "The loaded ship must provide a walkable cryopod arrival tile")
	var/obj/machinery/cryopod/away_mission/cryopod = locate() in get_step(arrival, WEST)
	TEST_ASSERT(cryopod && cryopod.get_linked_control_computer(), "The arrival tile must be in front of a cryopod with its own control console")
	var/obj/structure/closet/obstruction = allocate(/obj/structure/closet, arrival)
	TEST_ASSERT_NULL(mission.find_latejoin_spawn(ship), "A blocked cryopod arrival tile must not be offered")
	qdel(obstruction)
	TEST_ASSERT_EQUAL(mission.find_latejoin_spawn(ship), arrival, "Clearing the arrival tile must reopen the same spawn")
	TEST_ASSERT_EQUAL(length(ship.owned_z_levels), 1, "The patrol destroyer must use exactly one deck")
	TEST_ASSERT_EQUAL(ship.width, 17, "Native hull width including machinery")
	TEST_ASSERT_EQUAL(ship.height, 23, "Native hull length including engines")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m)
	TEST_ASSERT(slot.accepts(ship), "The real hull must fit a standard M slot")
	var/hatches_ready = 0
	var/bridge_windows = 0
	var/list/power_storage = list()
	var/list/vents = list()
	var/list/scrubbers = list()
	for(var/turf/tile as anything in ship.return_turfs())
		for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch in tile)
			if(slot.hatch_available(ship, hatch))
				hatches_ready++
		for(var/obj/machinery/power/smes/ship/storage in tile)
			power_storage += storage
		for(var/obj/machinery/atmospherics/components/unary/vent_pump/vent in tile)
			vents += vent
		for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber in tile)
			scrubbers += scrubber
		for(var/obj/machinery/machine in tile)
			if(!istype(machine, /obj/machinery/light) && !istype(machine, /obj/machinery/power/apc) && !istype(machine, /obj/machinery/airalarm))
				continue
			var/datum/component/atom_mounted/mount = machine.GetComponent(/datum/component/atom_mounted)
			TEST_ASSERT(isclosedturf(mount?.hanging_support_atom), "[machine] at [COORD(tile)] must be secured to a wall")
		if(istype(get_area(tile), /area/shuttle/stationtrauma_space/nt_patrol/bridge))
			for(var/obj/structure/window/reinforced/plasma/plastitanium/pane in tile)
				TEST_ASSERT(!CANATMOSPASS(pane, get_step(tile, NORTH), FALSE), "The bridge window at [COORD(tile)] must seal the hull")
				bridge_windows++
	TEST_ASSERT_EQUAL(bridge_windows, 4, "The bow must have four armored observation panes")
	TEST_ASSERT_EQUAL(hatches_ready, 2, "Both long sides must offer a clear native gangway hatch")
	TEST_ASSERT_EQUAL(length(power_storage), 1, "The patrol hull needs one initialized SMES")
	var/obj/machinery/power/smes/ship/storage = power_storage[1]
	TEST_ASSERT(storage.powernet && storage.terminal?.powernet && storage.powernet != storage.terminal.powernet, "The SMES must separate the input and ship powernets")
	for(var/area/compartment as anything in ship.shuttle_areas)
		if(compartment.requires_power)
			TEST_ASSERT_EQUAL(compartment.apc?.terminal?.powernet, storage.powernet, "[compartment] must be connected to the ship grid")
	TEST_ASSERT(length(vents) && length(scrubbers), "The patrol hull needs atmospheric supply and recovery")
	var/datum/pipeline/supply
	for(var/obj/machinery/atmospherics/components/unary/vent_pump/vent as anything in vents)
		TEST_ASSERT_NOTNULL(vent.nodes[1], "The supply vent at [COORD(vent)] must be connected")
		supply ||= vent.return_pipenet()
		TEST_ASSERT_EQUAL(vent.return_pipenet(), supply, "All supply vents must share one pipeline")
	var/datum/pipeline/waste
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in scrubbers)
		TEST_ASSERT_NOTNULL(scrubber.nodes[1], "The scrubber at [COORD(scrubber)] must be connected")
		waste ||= scrubber.return_pipenet()
		TEST_ASSERT_EQUAL(scrubber.return_pipenet(), waste, "All scrubbers must share one pipeline")
	TEST_ASSERT(supply && waste && supply != waste, "Ship supply and scrubber networks must remain separate")
	check_reactor(ship, storage, supply, waste)
	check_armory(ship)

	SSmapping.current_map.space_overmap = list("station_id" = "unit_test")
	SSjob.unassigned = list()
	var/list/candidates = list()
	for(var/job_type in mission.minimum_crew)
		var/datum/job/away_mission/job = SSjob.get_job_type(job_type)
		original_jobs[job] = list(job.current_positions, job.roundstart_spawns)
		job.current_positions = 0
		candidates[job] = list()
		var/volunteers = job.spawn_positions
		if(istype(job, /datum/job/away_mission/nt_patrol_officer))
			volunteers++ // The extra patrol volunteer must remain in the station queue.
		for(var/index in 1 to volunteers)
			var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
			player.mind = allocate(/datum/mind)
			player.mind.set_assigned_role(SSjob.get_job_type(/datum/job/unassigned))
			var/datum/client_interface/mock = allocate(/datum/client_interface)
			var/datum/preferences/preferences = allocate(/datum/preferences, mock)
			player.mock_client = mock
			mock.prefs = preferences
			preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
			TEST_ASSERT(preferences.update_preference(GLOB.preference_entries_by_key["away_mission_role"], job.title), "The actual preference handler must accept the crew role")
			player.ready = PLAYER_READY_TO_PLAY
			candidates[job] += player
			SSjob.unassigned += player

	var/datum/job/away_mission/medic = SSjob.get_job_type(/datum/job/away_mission/nt_patrol_medic)
	var/mob/dead/new_player/medic_player = candidates[medic][1]
	medic_player.ready = PLAYER_NOT_READY
	TEST_ASSERT(!mission.seat_crew(candidates, TRUE, null, ship), "A crew that loses its only medic during loading must fall back")
	TEST_ASSERT_EQUAL(length(SSjob.unassigned), 11, "The rejected hull must release every reserved station candidate")
	for(var/mob/dead/new_player/player as anything in SSjob.unassigned)
		TEST_ASSERT(is_unassigned_job(player.mind.assigned_role), "A failed launch must roll back each job assignment")

	medic_player.ready = PLAYER_READY_TO_PLAY
	var/datum/job/away_mission/commander = SSjob.get_job_type(/datum/job/away_mission/nt_patrol_commander)
	var/mob/dead/new_player/commander_player = candidates[commander][1]
	var/datum/preference/away_preference = GLOB.preference_entries_by_key["away_mission_role"]
	var/datum/preferences/medic_preferences = medic_player.mock_client.prefs
	var/datum/preferences/commander_preferences = commander_player.mock_client.prefs
	TEST_ASSERT(medic_preferences.update_preference(away_preference, list(commander.title = JP_LOW, medic.title = JP_LOW)), "Players must be able to opt into jobs with ranked preferences")
	TEST_ASSERT(commander_preferences.update_preference(away_preference, list(commander.title = JP_MEDIUM, medic.title = JP_HIGH)), "Players must be able to rank several jobs")
	candidates[commander] += medic_player
	candidates[medic] += commander_player
	var/list/preferred_crew = mission.match_required_crew(mission.rank_crew_candidates(candidates))
	TEST_ASSERT_EQUAL(preferred_crew?[commander_player], medic, "A higher priority must be considered before a lower one for an earlier-listed job")

	TEST_ASSERT(commander_preferences.update_preference(away_preference, list(commander.title = JP_HIGH, medic.title = JP_MEDIUM)), "The volunteer can reprioritize another job")
	candidates[medic] = list(commander_player)

	var/profile_slot = commander_preferences.default_slot == 1 ? 2 : 1
	var/list/alternate_profile = commander_preferences.savefile.get_entry("character[commander_preferences.default_slot]")
	alternate_profile = alternate_profile.Copy()
	alternate_profile["real_name"] = "Patrol Medic"
	commander_preferences.savefile.set_entry("character[profile_slot]", alternate_profile)
	var/datum/preference_middleware/jobs/job_preferences = locate() in commander_preferences.middleware
	TEST_ASSERT(job_preferences.set_job_to_profile(list("job" = medic.title, "profile" = profile_slot), commander_player), "The station job slot selector must also accept off-station roles")
	var/datum/preference/current_on_latejoin = GLOB.preference_entries[/datum/preference/toggle/late_join_always_current_slot]
	var/datum/job_character_selection/latejoin_profile = commander_preferences.select_job_character(medic, latejoin = TRUE)
	TEST_ASSERT_EQUAL(latejoin_profile.slot, commander_preferences.default_slot, "The default latejoin setting must use the active profile")
	qdel(latejoin_profile)
	commander_preferences.write_preference(current_on_latejoin, FALSE)
	latejoin_profile = commander_preferences.select_job_character(medic, latejoin = TRUE)
	TEST_ASSERT(!latejoin_profile.error && latejoin_profile.slot == profile_slot, "Off-station latejoin must honor the assigned profile when enabled")
	qdel(latejoin_profile)

	var/list/optional_assignments = list()
	TEST_ASSERT(mission.seat_crew(candidates, TRUE, optional_assignments, ship), "The full crew must be found even when the first commander candidate is the only medic")
	TEST_ASSERT_EQUAL(length(SSjob.unassigned), 7, "Reserve only essential positions until other hulls have picked their crews")
	var/datum/callback/fill_seats = optional_assignments[ship]
	fill_seats.Invoke()
	TEST_ASSERT_EQUAL(commander_player.assigned_job_character?.slot, profile_slot, "Roundstart must reserve the assigned character instead of the editing slot")
	TEST_ASSERT_EQUAL(commander_player.mind.assigned_role, medic, "Reserve the only medic before filling commander with an alternative volunteer")
	TEST_ASSERT_EQUAL(medic_player.mind.assigned_role, commander, "The alternative volunteer must take the commander position")
	TEST_ASSERT_EQUAL(length(SSjob.unassigned), 1, "Crew capacity must reserve ten volunteers and leave one available to the station")
	var/list/destinations = list()
	for(var/datum/job/away_mission/job as anything in candidates)
		for(var/mob/dead/new_player/player as anything in job.roundstart_spawns?.Copy())
			var/turf/tile = job.get_roundstart_spawn_point(player)
			TEST_ASSERT(tile && ship.is_in_shuttle_bounds(tile) && !(tile in destinations), "Every admitted player needs a distinct spawn inside the real hull")
			destinations += tile
	TEST_ASSERT_EQUAL(length(destinations), 10, "The complete roster must consume ten distinct role landmarks")
	TEST_ASSERT(!ship.has_away_vacancy(commander), "A filled commander position must be closed on its own hull")
	if(second_ship)
		TEST_ASSERT(second_ship.has_away_vacancy(commander), "The same position must stay open on the other hull")
		TEST_ASSERT_EQUAL(commander.total_positions, 2, "Latejoin capacity must include both configured hulls")
		TEST_ASSERT(!ship.rename_away_ship(commander_player.mind, "Вымпел"), "An ordinary crewmember cannot rename the ship")
		TEST_ASSERT(!ship.rename_away_ship(medic_player.mind, uppertext(second_ship.away_ship_name)), "A reserved name cannot be reused even with different letter case")
		TEST_ASSERT(ship.rename_away_ship(medic_player.mind, "Вымпел"), "The roundstart commander may register the ship name")
		TEST_ASSERT_EQUAL(ship.name, "ОКН «Вымпел»", "A commander rename must update the hull name")
		TEST_ASSERT(!ship.rename_away_ship(medic_player.mind, "Вымпел-2"), "A commander can rename the ship only once")

		// A medic first aboard fixes the fallback name, even when the commander boards next.
		second_ship.record_away_crew(commander_player.mind)
		medic.note_away_latejoin(commander_player.mind)
		second_ship.record_away_crew(medic_player.mind)
		commander.note_away_latejoin(medic_player.mind)
		TEST_ASSERT(!second_ship.rename_away_ship(medic_player.mind, "Вымпел-3"), "A commander arriving after another crewmember may not rename an already crewed ship")
		TEST_ASSERT(!second_ship.has_away_vacancy(commander), "The second commander reservation must belong to the second hull")
		// Reuse the fixture to model a fresh hull where the commander is the first latejoin.
		second_ship.away_crew_boarded = FALSE
		commander.note_away_latejoin(medic_player.mind)
		TEST_ASSERT(second_ship.rename_away_ship(medic_player.mind, "Вымпел-2"), "The commander first aboard in latejoin may name their own ship")
		SSjob.free_job_position(commander.title, medic_player.mind)
		TEST_ASSERT(second_ship.has_away_vacancy(commander), "Freeing the commander must release the position on the correct hull")

/// Verify the mapped power source and propellant route using only the fuel on board.
/datum/unit_test/overmap_nt_patrol/proc/check_reactor(obj/docking_port/mobile/stationtrauma_space/ship, obj/machinery/power/smes/ship/storage, datum/pipeline/supply, datum/pipeline/waste)
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = ship.fusion_core?.resolve()
	TEST_ASSERT(reactor?.active, "The patrol hull must bind its running fusion core")
	TEST_ASSERT(storage in reactor.grid_batteries(), "The mapped core must feed the SMES inlet")
	var/datum/pipeline/fuel = reactor.parents[1]
	var/datum/pipeline/exhaust = reactor.parents[2]
	TEST_ASSERT(fuel && exhaust && fuel != exhaust, "The mapped core needs distinct fuel and exhaust lines")
	TEST_ASSERT(!(supply in list(fuel, exhaust)) && !(waste in list(fuel, exhaust)), "Reactor gas must not enter the crew atmosphere")
	fuel.reconcile_air()
	var/list/fuel_gauges = reactor.fuel_reserve()
	TEST_ASSERT(fuel_gauges[1]["amount"] > 0 && fuel_gauges[1]["capacity"] > 0, "The native fuel gauge must show the tritium tank charge and capacity")
	var/datum/powernet/input_grid = storage.terminal.powernet
	var/prior_generation = input_grid.newavail
	reactor.process(5)
	TEST_ASSERT(reactor.output > 0, "The mapped fuel tank must supply tritium")
	TEST_ASSERT(input_grid.newavail > prior_generation, "Fusion must charge the actual electrical inlet")
	exhaust.reconcile_air()
	TEST_ASSERT_EQUAL(length(ship.engine_list), 6, "The patrol destroyer needs six nozzles")
	ship.engines_running = TRUE
	for(var/obj/machinery/power/shuttle_engine/nozzle as anything in ship.engine_list)
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = nozzle.combustion_feed?.resolve()
		TEST_ASSERT(feed && feed.core?.resolve() == reactor && feed.parents[1] == exhaust, "The nozzle at [COORD(nozzle)] needs a converter on the core exhaust line")
		feed.process_atmos(1)
		TEST_ASSERT(ship.overmap.engine_output(nozzle) > 0, "The connected nozzle at [COORD(nozzle)] must deliver thrust")
	ship.engines_running = FALSE
	check_cooling(reactor, supply, waste)

/// Check distinct gas networks, heat transfer into the coolant and the still-operative heat trip.
/datum/unit_test/overmap_nt_patrol/proc/check_cooling(obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor, datum/pipeline/supply, datum/pipeline/waste)
	var/obj/machinery/atmospherics/components/unary/heat_exchanger/exchanger = reactor.find_coolant_exchanger()
	var/datum/pipeline/cooling = exchanger?.parents[1]
	TEST_ASSERT(cooling && !(cooling in reactor.parents) && cooling != supply && cooling != waste, "The lateral coolant loop must be separate from propulsion and life support")
	cooling.reconcile_air()
	var/datum/gas_mixture/coolant = exchanger.airs[1]
	TEST_ASSERT(coolant.moles[/datum/gas/nitrogen] > 0, "The mapped coolant loop must contain nitrogen")
	var/obj/machinery/atmospherics/components/unary/thermomachine/freezer/chiller = locate() in cooling.other_atmos_machines
	TEST_ASSERT(chiller?.on && chiller.is_operational, "The coolant loop needs a running freezer powered by the ship")
	var/datum/gas_mixture/chiller_port = chiller.airs[1]
	chiller_port.temperature = T20C
	chiller.process_atmos()
	TEST_ASSERT(chiller_port.temperature < T20C, "The native freezer must cool its share of the loop")

	reactor.active = FALSE
	reactor.heat = 75
	coolant.temperature = T20C
	reactor.process(2)
	var/passive_heat = reactor.heat
	reactor.heat = 75
	var/cold_temperature = T20C - 30
	coolant.temperature = cold_temperature
	reactor.process(2)
	TEST_ASSERT(reactor.heat < passive_heat && coolant.temperature > cold_temperature, "Cold coolant must absorb heat and speed up reactor cooldown")

	coolant.temperature = cold_temperature
	reactor.heat = 99
	reactor.active = TRUE
	reactor.auto = FALSE
	reactor.level = 150
	reactor.overdrive = TRUE
	reactor.process(2)
	TEST_ASSERT(reactor.tripped && !reactor.active, "The heat interlock must still trip under sustained overload even with active cooling")

/// Verify the loaded stock and the armory's ship-specific access.
/datum/unit_test/overmap_nt_patrol/proc/check_armory(obj/docking_port/mobile/stationtrauma_space/ship)
	var/obj/machinery/door/airlock/security/armory_hatch
	var/disablers = 0
	var/energy_guns = 0
	var/rechargers = 0
	for(var/turf/tile as anything in ship.return_turfs())
		armory_hatch ||= locate(/obj/machinery/door/airlock/security) in tile
		if(!istype(get_area(tile), /area/shuttle/stationtrauma_space/nt_patrol/armory))
			continue
		for(var/obj/item/gun/energy/weapon in tile)
			if(istype(weapon, /obj/item/gun/energy/disabler))
				disablers++
			else if(istype(weapon, /obj/item/gun/energy/e_gun))
				energy_guns++
		if(locate(/obj/machinery/recharger) in tile)
			rechargers++
	var/datum/id_trim/nt_patrol/armory/trim = allocate(/datum/id_trim/nt_patrol/armory)
	TEST_ASSERT(armory_hatch && armory_hatch.check_access_list(trim.access) && !armory_hatch.check_access_list(list()), "Only authorized patrol crew may open the armory")
	TEST_ASSERT_EQUAL(disablers, 6, "The armory must stock six disablers")
	TEST_ASSERT_EQUAL(energy_guns, 3, "The armory must stock three energy guns")
	TEST_ASSERT_EQUAL(rechargers, 1, "The armory must provide a recharger")

/// Simulate the claim becoming invalid during the native loader's yielding work.
/datum/unit_test/overmap_nt_patrol/proc/reject_patrol_arrival()
	return FALSE

/// Map cleanup yields, so perform it before the no-sleep datum teardown.
/datum/unit_test/overmap_nt_patrol/proc/discard_test_hull()
	second_template?.discard_loaded_ship()
	if(!template)
		return
	var/list/levels = template.loaded_levels.Copy()
	template.discard_loaded_ship()
	if(exterior)
		for(var/deck in levels)
			for(var/turf/tile as anything in block(locate(1, 1, deck), locate(world.maxx, world.maxy, deck)))
				if(get_area(tile) == exterior)
					tile.change_area(exterior, GLOB.areas_by_type[/area/space])
		QDEL_NULL(exterior)

/datum/unit_test/overmap_nt_patrol/Destroy()
	template = null
	if(original_ports)
		SSshuttle.assoc_mobile = original_ports
		SSshuttle.assoc_stationary = original_stationary_ports
		SSstationtrauma_space_voyage.dispatch_staging_level = original_staging_level
		SSjob.unassigned = original_unassigned
		SSmapping.current_map.space_overmap = original_overmap
		SSsound_loops.can_fire = original_sound_processing
		GLOB.used_away_ship_names = original_ship_names
		SSjob.away_mission_limits = original_mission_limits
		SSjob.update_away_job_capacity()
	for(var/datum/job/away_mission/job as anything in original_jobs)
		var/list/original_job = original_jobs[job]
		job.current_positions = original_job[1]
		job.roundstart_spawns = original_job[2]
	original_jobs = null
	original_ports = null
	original_stationary_ports = null
	original_unassigned = null
	original_overmap = null
	return ..()
