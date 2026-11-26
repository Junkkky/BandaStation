/// Verify the actual patrol hull and the transition from lobby preferences to mapped spawns.
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
	/// Physical projectiles captured at fire time, keyed by their mount.
	var/list/fired_rounds = list()

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
	SSmapping.current_map.space_overmap = original_overmap || list("station_id" = "unit_test")
	SSjob.away_mission_limits = list(/datum/roundstart_away_mission/nt_patrol = 1)
	SSjob.update_away_job_capacity()
	SSjob.unassigned = list()
	for(var/job_type in mission.crew_jobs)
		var/datum/job/away_mission/job = SSjob.get_job_type(job_type)
		original_jobs[job] = list(job.current_positions, job.roundstart_spawns)
		job.current_positions = 0
		job.roundstart_spawns = null
	var/datum/job/away_mission/medic = SSjob.get_job_type(/datum/job/away_mission/nt_patrol_medic)
	var/mob/dead/new_player/solo = make_volunteer()
	var/datum/preference_middleware/away_missions/away_preferences = locate() in solo.mock_client.prefs.middleware
	TEST_ASSERT(away_preferences.set_away_job_preference(list("job" = medic.title, "level" = JP_HIGH), solo), "The character menu must accept a single High patrol role")
	SSjob.unassigned += solo
	solo.ready = PLAYER_NOT_READY
	TEST_ASSERT_NULL(mission.find_crew(list()), "A patrol preference alone must not launch a ship until its volunteer is ready")
	solo.ready = PLAYER_READY_TO_PLAY
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
		SSjob.assign_roundstart_away_missions(TRUE, loaded_templates)
		ship = solo.mind.away_mission_ship?.resolve()
		if(length(loaded_templates))
			template = loaded_templates[1]
			allocated += template
		TEST_ASSERT_NOTNULL(ship, "Roundstart must load and reserve the real patrol hull for a lone ready volunteer")
		TEST_ASSERT_EQUAL(length(loaded_templates), 1, "A solo roundstart needs exactly one newly loaded hull")
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
		var/registered_name = ship.name
		var/registered_callsign = first_board.callsign
		ship.draw_away_ship_name(list("Вымпел"))
		TEST_ASSERT_EQUAL(ship.name, registered_name, "The latejoin name must stay fixed after registration")
		TEST_ASSERT_EQUAL(first_board.callsign, registered_callsign, "The transponder must keep the original callsign")
		TEST_ASSERT_NULL(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, arrival_check, new_instance = TRUE), "A third copy must not exceed the configured limit")
	else
		template = allocate(/datum/map_template/stationtrauma_space/ship, mission.map_path, mission.name)
		ship = template.load_ship()
		TEST_ASSERT_NOTNULL(ship, "The actual patrol map must load")
		var/datum/stationtrauma_overmap_sector/space/sector = allocate(/datum/stationtrauma_overmap_sector/space)
		sector.id = "unit_test_nt_patrol"
		sector.ready = TRUE
		TEST_ASSERT(sector.attach(ship), "The native overmap must accept the patrol destroyer")
		var/list/solo_candidates = mission.find_crew(list())
		TEST_ASSERT(length(solo_candidates) && mission.seat_crew(solo_candidates, TRUE, null, ship), "A single ready medic must be discovered and seated aboard the patrol hull")
	TEST_ASSERT_EQUAL(solo.mind.assigned_role, medic, "The solo volunteer must receive the selected High role before station fallback")
	TEST_ASSERT(!(solo in SSjob.unassigned), "The station must no longer be able to assign this volunteer as an assistant")
	var/list/crew_spawns = mission.find_crew_spawns(ship)
	TEST_ASSERT(medic.get_roundstart_spawn_point(solo) in crew_spawns[medic.type], "The solo medic must spawn on a medic landmark aboard the assigned hull")
	SSjob.free_job_position(medic.title, solo.mind)
	exterior = ship.overmap.exterior
	STOP_PROCESSING(SSfastprocess, ship.overmap)
	var/turf/arrival = mission.find_latejoin_spawn(ship)
	TEST_ASSERT_NOTNULL(arrival, "The loaded ship must provide a walkable cryopod arrival tile")
	var/obj/machinery/cryopod/away_mission/cryopod = locate() in get_step(arrival, WEST)
	var/obj/machinery/computer/cryopod/cryo_console = cryopod?.get_linked_control_computer()
	TEST_ASSERT_NOTNULL(cryo_console, "The arrival tile must be in front of a cryopod with its own control console")
	TEST_ASSERT(isclosedturf(get_turf_pixel(cryo_console)), "The cryopod console must be displayed on a wall")
	var/obj/structure/closet/obstruction = allocate(/obj/structure/closet, arrival)
	TEST_ASSERT_NULL(mission.find_latejoin_spawn(ship), "A blocked cryopod arrival tile must not be offered")
	qdel(obstruction)
	TEST_ASSERT_EQUAL(mission.find_latejoin_spawn(ship), arrival, "Clearing the arrival tile must reopen the same spawn")
	TEST_ASSERT_EQUAL(length(ship.owned_z_levels), 1, "The patrol destroyer must use exactly one deck")
	TEST_ASSERT_EQUAL(ship.width, 17, "Native hull width including machinery")
	TEST_ASSERT_EQUAL(ship.height, 24, "Native hull length including engines and the exterior gun mount")
	TEST_ASSERT(ship.combat_power_managed && ship.combat_power_ref?.resolve(), "The patrol hull must have a linked combat distributor")
	check_weapons(ship)
	TEST_ASSERT_NOTNULL(ship.combat_shield_ref?.resolve(), "The patrol hull must have a linked shield generator")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m)
	TEST_ASSERT(slot.accepts(ship), "The real hull must fit a standard M slot")
	var/hatches_ready = 0
	var/bridge_windows = 0
	var/obj/machinery/stasis/stasis_bed
	var/obj/machinery/computer/operating/surgery_monitor
	var/obj/machinery/fax/bridge_fax
	var/list/power_storage = list()
	var/list/vents = list()
	var/list/scrubbers = list()
	for(var/turf/tile as anything in ship.return_turfs())
		for(var/obj/machinery/door/airlock/hull_airlock in tile)
			TEST_ASSERT(hull_airlock.check_access_list(list(ACCESS_CENT_SPECOPS)) && !hull_airlock.check_access_list(list(ACCESS_CENT_GENERAL)), "Ship airlocks must require the ERT clearance")
		if(istype(get_area(tile), /area/shuttle/stationtrauma_space/nt_patrol/medbay))
			stasis_bed ||= locate(/obj/machinery/stasis) in tile
			surgery_monitor ||= locate(/obj/machinery/computer/operating) in tile
		for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch in tile)
			TEST_ASSERT(hatch.require_gangway_access, "The dock must check ERT access at both endpoints")
			if(!slot.hatch_problem(ship, hatch))
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
			bridge_fax ||= locate(/obj/machinery/fax) in tile
			for(var/obj/structure/window/reinforced/plasma/plastitanium/pane in tile)
				TEST_ASSERT(!CANATMOSPASS(pane, get_step(tile, NORTH), FALSE), "The bridge window at [COORD(tile)] must seal the hull")
				bridge_windows++
	TEST_ASSERT_EQUAL(bridge_windows, 11, "The stepped bow must have eleven armored observation panes")
	var/centcom_fax_id = bridge_fax?.special_networks["nanotrasen"]?["fax_id"]
	TEST_ASSERT(bridge_fax?.is_operational && bridge_fax.visible_to_network && centcom_fax_id && centcom_fax_id != bridge_fax.fax_id, "The bridge fax must reach CentCom under its own return address")
	TEST_ASSERT(stasis_bed?.stasis_running(), "The patrol medbay must start with a working stasis bed")
	TEST_ASSERT(surgery_monitor?.is_operational && surgery_monitor.table?.computer == surgery_monitor, "The operating room needs a powered monitor paired with its table")
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

	var/list/candidates = list()
	for(var/job_type in mission.crew_jobs)
		var/datum/job/away_mission/job = SSjob.get_job_type(job_type)
		candidates[job] = list()
		var/volunteers = job.spawn_positions
		if(istype(job, /datum/job/away_mission/nt_patrol_officer))
			volunteers++ // The extra patrol volunteer must remain in the station queue.
		for(var/index in 1 to volunteers)
			var/mob/dead/new_player/player = make_volunteer()
			TEST_ASSERT(player.mock_client.prefs.update_preference(GLOB.preference_entries_by_key["away_mission_role"], job.title), "The actual preference handler must accept the crew role")
			candidates[job] += player
			SSjob.unassigned += player

	var/mob/dead/new_player/medic_player = candidates[medic][1]
	medic_player.ready = PLAYER_NOT_READY
	var/list/withdrawn_candidates = list()
	withdrawn_candidates[medic] = list(medic_player)
	TEST_ASSERT(!mission.seat_crew(withdrawn_candidates, TRUE, null, ship), "A hull that loses its last volunteer during loading must be rejected")
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
	var/list/preferred_crew = mission.match_full_crew(mission.rank_crew_candidates(candidates))
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
		var/list/rows = list()
		rows[commander] = list()
		var/list/first_destination = GLOB.latejoin_menu.get_away_destination(mission, ship, rows, list(), list())
		var/list/second_destination = GLOB.latejoin_menu.get_away_destination(mission, second_ship, rows, list(), list())
		TEST_ASSERT_EQUAL(first_destination["name"], ship.name, "The latejoin menu must use the hull's registered name")
		TEST_ASSERT_EQUAL(first_destination["open_slots"], 0, "The first hull has no commander vacancy")
		TEST_ASSERT_EQUAL(second_destination["open_slots"], 1, "The second hull has a commander vacancy")
		var/list/vessels = mission.get_loaded_ships()
		TEST_ASSERT_NULL(mission.find_boardable_ship(commander, vessels, REF(ship)), "An occupied named hull must not fall back to an open copy")
		TEST_ASSERT_EQUAL(mission.find_boardable_ship(commander, vessels, REF(second_ship)), second_ship, "The open named hull must resolve to the exact ship")
		TEST_ASSERT_NULL(mission.find_boardable_ship(commander, vessels, REF(src)), "A stale or unrelated target must not fall back to a ship")
		TEST_ASSERT_EQUAL(commander.total_positions, 2, "Latejoin capacity must include both configured hulls")
		second_ship.record_away_crew(medic_player.mind)
		TEST_ASSERT(!second_ship.has_away_vacancy(commander), "The second commander reservation must belong to the second hull")
		SSjob.free_job_position(commander.title, medic_player.mind)
		TEST_ASSERT(second_ship.has_away_vacancy(commander), "Freeing the commander must release the position on the correct hull")
	check_pod_assembly(ship)

/datum/unit_test/overmap_nt_patrol/proc/check_pod_assembly(obj/docking_port/mobile/stationtrauma_space/ship)
	TEST_ASSERT_EQUAL(length(ship.drop_launchers), 2, "The patrol deck must carry two independent launchers")
	var/obj/machinery/stationtrauma_drop_launcher/rack = ship.drop_launchers[1]
	rack.iron = 10
	TEST_ASSERT(rack.assemble_pod() && !rack.assemble_pod(), "A rack must accept exactly one assembly order at a time")
	TEST_ASSERT(!rack.mounted_pod() && rack.assembly_seconds_left() == 10, "The capsule must begin with ten seconds of assembly remaining")
	rack.set_panel_open(TRUE)
	TEST_ASSERT(!rack.assembly_timer && rack.iron == 10, "Opening the service panel must cancel assembly and retain the iron")
	rack.set_panel_open(FALSE)
	var/obj/machinery/stationtrauma_drop_launcher/blocked = ship.drop_launchers[2]
	blocked.iron = 10
	var/start = world.time
	TEST_ASSERT(rack.assemble_pod() && blocked.assemble_pod(), "Each rack must be able to assemble its own capsule")
	var/obj/structure/closet/obstruction = allocate(/obj/structure/closet, get_turf(blocked))
	UNTIL((!rack.assembly_timer && !blocked.assembly_timer) || world.time >= start + 15 SECONDS)
	var/obj/structure/closet/stationtrauma_drop_pod/pod = rack.mounted_pod()
	TEST_ASSERT(world.time >= start + 10 SECONDS && pod && !rack.iron, "The clear rack must finish and spend the iron after ten seconds")
	TEST_ASSERT(!blocked.assembly_timer && !blocked.mounted_pod() && blocked.iron == 10, "An obstructed pad must retain its iron without producing a capsule")
	qdel(obstruction)
	qdel(pod)

/// Create a ready lobby player with the normal character preferences and a local ban cache.
/datum/unit_test/overmap_nt_patrol/proc/make_volunteer()
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	player.mind = allocate(/datum/mind)
	player.mind.set_assigned_role(SSjob.get_job_type(/datum/job/unassigned))
	var/datum/client_interface/mock = allocate(/datum/client_interface)
	mock.prefs = allocate(/datum/preferences, mock)
	mock.prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	mock.ban_cache = list()
	player.mock_client = mock
	player.key = mock.key
	player.ready = PLAYER_READY_TO_PLAY
	return player

/// Limit outgoing test rounds to the empty space directly ahead of the bow.
/datum/unit_test/overmap_nt_patrol/proc/capture_round(mob/source, obj/projectile/bullet/stationtrauma_kinetic/round, obj/machinery/stationtrauma_autocannon/mount)
	SIGNAL_HANDLER
	round.range = 2
	fired_rounds[mount] = round

/// Fire the actual mapped mounts and exercise their separate resource requirements.
/datum/unit_test/overmap_nt_patrol/proc/check_weapons(obj/docking_port/mobile/stationtrauma_space/ship)
	TEST_ASSERT_EQUAL(length(ship.ship_autocannons), 4, "All four bow mounts must register with the native hull")
	var/list/mounts = list()
	for(var/obj/machinery/stationtrauma_autocannon/mount as anything in ship.ship_autocannons)
		mounts[mount.type] = mount
		TEST_ASSERT(istype(get_area(mount), /area/shuttle/stationtrauma_space/nt_patrol/exterior) && mount.firing_muzzle(), "[mount] needs a clear muzzle on the exterior bow")
	var/obj/machinery/stationtrauma_autocannon/gun = mounts[/obj/machinery/stationtrauma_autocannon]
	var/obj/machinery/stationtrauma_autocannon/heavy/heavy = mounts[/obj/machinery/stationtrauma_autocannon/heavy]
	var/obj/machinery/stationtrauma_autocannon/laser/laser = mounts[/obj/machinery/stationtrauma_autocannon/laser]
	var/obj/machinery/stationtrauma_autocannon/heavy/plasma/plasma = mounts[/obj/machinery/stationtrauma_autocannon/heavy/plasma]
	TEST_ASSERT(gun && heavy && laser && plasma, "The patrol needs light and heavy kinetics, a laser and a plasma cannon")
	var/obj/machinery/computer/stationtrauma_weapon_console/unmetered = allocate(__IMPLIED_TYPE__, get_turf(laser))
	TEST_ASSERT(gun.grid_power_ready(unmetered) && !laser.grid_power_ready(unmetered) && !plasma.grid_power_ready(unmetered), "An unmetered shuttle area must not provide free energy weapon shots")
	qdel(unmetered)
	var/obj/structure/stationtrauma_autocannon_barrel/barrel = locate() in get_step(heavy, heavy.dir)
	TEST_ASSERT(barrel && heavy.firing_muzzle() == get_step(barrel, heavy.dir), "The heavy kinetic round must clear the forward barrel")
	var/obj/structure/stationtrauma_autocannon_barrel/plasma/focus = locate() in get_step(plasma, plasma.dir)
	TEST_ASSERT(focus && plasma.firing_muzzle() == get_step(focus, plasma.dir), "The plasma bolt must clear its matching focusing section")
	var/turf/bow_window = get_step(gun, SOUTH)
	TEST_ASSERT(locate(/obj/structure/window/reinforced/plasma/plastitanium) in bow_window, "The bow window must remain intact")
	var/obj/machinery/stationtrauma_autocannon_loader/loader = locate() in get_step(bow_window, SOUTH)
	TEST_ASSERT(loader && gun.interior_loader() == loader, "The light gun must link through the bow to the bridge tray")
	var/obj/machinery/stationtrauma_autocannon_loader/compact/tray = heavy.interior_loader()
	TEST_ASSERT(istype(tray) && tray.mounted_gun() == heavy && tray.reserve_capacity < loader.reserve_capacity, "The heavy mount has its own small interior feed")
	var/obj/machinery/stationtrauma_autocannon_loader/plasma/plasma_tray = plasma.interior_loader()
	TEST_ASSERT(istype(plasma_tray) && plasma_tray.mounted_gun() == plasma, "The bridge plasma tray must feed the plasma breech")
	var/original_dir = plasma.dir
	var/original_shells = plasma.shells
	var/original_reserve = plasma_tray.reserve_shells
	for(var/side in list(-90, 90))
		plasma.setDir(turn(original_dir, side))
		TEST_ASSERT(plasma.interior_loader() == plasma_tray && plasma_tray.mounted_gun() == plasma, "A side-facing plasma feed must link both ways across the hull tile")
		plasma.shells = 0
		plasma_tray.reserve_shells = 1
		plasma_tray.feed_gun()
		TEST_ASSERT(plasma.shells == 1 && !plasma_tray.reserve_shells, "A side-facing plasma tray must feed a cartridge into the breech")
	plasma.setDir(turn(original_dir, 180))
	TEST_ASSERT_NULL(plasma_tray.mounted_gun(), "The muzzle must not accept ammunition from the front")
	plasma.setDir(original_dir)
	plasma.shells = original_shells
	plasma_tray.reserve_shells = original_reserve
	TEST_ASSERT(!laser.ammo_type && !laser.shells && !laser.interior_loader(), "The single-tile laser must operate without a loader or ammunition")
	var/obj/machinery/computer/stationtrauma_weapon_console/controls = locate() in get_area(loader)
	TEST_ASSERT_EQUAL(controls?.current_vessel(), ship, "The bridge controls must link to their own hull")
	if(!original_overmap || !ship.overmap?.sector)
		return
	var/datum/stationtrauma_overmap/space/map = ship.overmap
	var/mob/living/carbon/human/gunner = allocate(/mob/living/carbon/human/consistent, get_turf(controls))
	RegisterSignal(gunner, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(capture_round))
	for(var/obj/machinery/stationtrauma_autocannon/mount as anything in ship.ship_autocannons)
		var/heading = mount.firing_heading(map)
		var/aim_x = map.pos_x + 150 * sin(heading)
		var/aim_y = map.pos_y + 150 * cos(heading)
		var/stock = mount.shells
		if(mount == laser || mount == plasma)
			mount.capacitor_charge = mount.energy_per_shot - 1
			TEST_ASSERT_EQUAL(mount.readiness(map), "charging", "[mount] must report insufficient charge")
			TEST_ASSERT(!mount.fire_round(controls, gunner, map, aim_x, aim_y) && mount.shells == stock, "An undercharged [mount] must preserve its ammunition")
		mount.capacitor_charge += mount.charge_demand(ship)
		var/charge = mount.capacitor_charge
		if(mount == plasma)
			plasma.shells = 0
			TEST_ASSERT_EQUAL(plasma.readiness(map), "empty", "The charged plasma breech must still require a cartridge")
			TEST_ASSERT(!plasma.fire_round(controls, gunner, map, aim_x, aim_y) && plasma.capacitor_charge == charge, "An empty plasma breech must preserve its charge")
			plasma_tray.reserve_shells = 1
			plasma_tray.feed_gun()
			TEST_ASSERT(plasma.shells == 1 && !plasma_tray.reserve_shells, "The mapped plasma tray must transfer one cartridge into the breech")
			stock = plasma.shells
		TEST_ASSERT_EQUAL(mount.readiness(map), "ready", "[mount] must be ready for fire control")
		TEST_ASSERT(mount.fire_round(controls, gunner, map, aim_x, aim_y), "The mounted [mount] must fire its native projectile")
		TEST_ASSERT_EQUAL(mount.shells, stock - (mount != laser), "Only cartridge- or shell-fed mounts may consume ammunition")
		TEST_ASSERT_EQUAL(mount.capacitor_charge, charge - mount.energy_per_shot, "[mount] must draw exactly one shot from its capacitor")
		var/obj/effect/projectile/muzzle/flash = locate(mount.muzzle_flash_type) in mount.firing_muzzle()
		TEST_ASSERT(flash && flash.light_color == mount.muzzle_flash_color, "A real shot must produce the matching flash and light at the muzzle of [mount]")
		var/obj/projectile/bullet/stationtrauma_kinetic/fired = fired_rounds[mount]
		var/datum/stationtrauma_kinetic_shot/shot = fired?.outgoing_shot
		TEST_ASSERT(shot && abs(closer_angle_difference(mount.last_shot_heading, delta_to_angle(shot.direction_x, shot.direction_y))) < 0.05, "The plot flash must match the actual sector trajectory of [mount]")
		TEST_ASSERT(abs(closer_angle_difference(mount.last_shot_heading, heading)) <= 1.51, "Each round must stay within the gun's small aiming spread")
	var/list/plot = controls.ui_data(gunner)
	TEST_ASSERT_EQUAL(length(plot["muzzle_flashes"]), 4, "Fire control must publish one flash for each gun that fired")
	var/obj/projectile/bullet/stationtrauma_kinetic/energy/laser/laser_round = fired_rounds[laser]
	var/obj/projectile/bullet/stationtrauma_kinetic/heavy/heavy_round = fired_rounds[heavy]
	var/obj/projectile/bullet/stationtrauma_kinetic/energy/plasma/plasma_round = fired_rounds[plasma]
	TEST_ASSERT(istype(laser_round) && istype(heavy_round) && istype(plasma_round), "The mounted guns must launch their own projectile profiles")
	TEST_ASSERT(plasma_round.damage > heavy_round.damage && plasma_round.shield_impact > heavy_round.shield_impact, "A plasma hit must deal more damage to a target and its shield than a heavy kinetic round")
	var/turf/target = get_step(run_loc_floor_bottom_left, NORTHEAST).ChangeTurf(/turf/closed/wall)
	target.bullet_act(heavy_round)
	var/kinetic_cracked_wall = target.density && target.GetComponent(/datum/component/torn_wall)
	target = target.ChangeTurf(/turf/open/indestructible)
	target = target.ChangeTurf(/turf/closed/wall)
	target.bullet_act(plasma_round)
	var/plasma_breached_wall = !target.density
	target.ChangeTurf(/turf/open/indestructible)
	TEST_ASSERT(kinetic_cracked_wall && plasma_breached_wall, "A full plasma hit must breach fresh hull plating that one heavy kinetic hit only cracks")
	QDEL_LIST_ASSOC_VAL(fired_rounds)
	check_salvo(controls, gunner, map, mounts)
	UnregisterSignal(gunner, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)

/// Submit a battery selection through the mapped console and observe the physical rounds at each muzzle.
/datum/unit_test/overmap_nt_patrol/proc/check_salvo(obj/machinery/computer/stationtrauma_weapon_console/controls, mob/living/carbon/human/gunner, datum/stationtrauma_overmap/space/map, list/mounts)
	var/obj/machinery/stationtrauma_autocannon/gun = mounts[/obj/machinery/stationtrauma_autocannon]
	var/obj/machinery/stationtrauma_autocannon/heavy/heavy = mounts[/obj/machinery/stationtrauma_autocannon/heavy]
	var/obj/machinery/stationtrauma_autocannon/laser/laser = mounts[/obj/machinery/stationtrauma_autocannon/laser]
	var/obj/machinery/stationtrauma_autocannon/heavy/plasma/plasma = mounts[/obj/machinery/stationtrauma_autocannon/heavy/plasma]
	// A single shell in the light gun ends its burst before it yields. All submissions share one tick.
	gun.shells = 1
	gun.capacitor_charge = gun.capacitor_capacity
	heavy.shells = 0
	heavy.capacitor_charge = heavy.capacitor_capacity
	laser.capacitor_charge = laser.capacitor_capacity
	plasma.shells = plasma.feed_capacity
	plasma.capacitor_charge = plasma.capacitor_capacity
	ADD_TRAIT(gunner, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/tgui/ui = allocate(/datum/tgui, gunner, controls, "ShipWeapons")
	ui.process_status()
	TEST_ASSERT_EQUAL(ui.status, UI_INTERACTIVE, "The operator on the bridge must have an interactive fire-control window")
	var/heading = laser.firing_heading(map) + 15
	var/aim_x = map.pos_x + 150 * sin(heading)
	var/aim_y = map.pos_y + 150 * cos(heading)
	var/list/selection = list(REF(heavy), REF(laser), REF(controls), REF(plasma), REF(laser))
	var/list/salvo = list("weapons" = selection, "x" = aim_x, "y" = aim_y)
	gunner.forceMove(get_step(get_step(controls, SOUTH), SOUTH))
	TEST_ASSERT(!controls.ui_act("fire", salvo, ui, ui.state), "An operator who stepped away must lose control even with an open window")
	gunner.forceMove(get_turf(controls))
	var/list/aft = list("weapons" = selection, "x" = 2 * map.pos_x - aim_x, "y" = 2 * map.pos_y - aim_y)
	TEST_ASSERT(!controls.ui_act("fire", aft, ui, ui.state), "The forward battery must reject a target astern")
	TEST_ASSERT_EQUAL(length(fired_rounds), 0, "A rejected salvo must leave all muzzles silent")
	TEST_ASSERT(controls.ui_act("fire", salvo, ui, ui.state), "A duplicate, an unrelated reference and an empty gun must not block the ready mounts")
	TEST_ASSERT(fired_rounds[laser] && fired_rounds[plasma] && length(fired_rounds) == 2, "Only the two ready selected mounts must launch projectiles")
	TEST_ASSERT(abs(closer_angle_difference(laser.last_shot_heading, heading)) <= 1.51 && abs(closer_angle_difference(plasma.last_shot_heading, heading)) <= 1.51, "Both projectiles must stay within the spread of the submitted bearing")
	TEST_ASSERT(!controls.ui_act("fire", salvo, ui, ui.state), "A repeated salvo during reload must be rejected")
	TEST_ASSERT_EQUAL(laser.capacitor_charge, laser.capacitor_capacity - laser.energy_per_shot, "A duplicate selection or click must not consume a second laser shot")
	TEST_ASSERT_EQUAL(plasma.shells, plasma.feed_capacity - 1, "A repeated salvo must not consume a second plasma cartridge")
	TEST_ASSERT(controls.ui_act("fire", list("weapon" = REF(gun), "x" = aim_x, "y" = aim_y), ui, ui.state), "The single-weapon command must still operate the unselected light gun")
	TEST_ASSERT(fired_rounds[gun] && !gun.shells, "The light gun must fire its shell on the single-weapon command")

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
		TEST_ASSERT(ship.overmap.engine_output(nozzle, regulated = FALSE) > 0, "The connected nozzle at [COORD(nozzle)] must deliver thrust")
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
	var/obj/machinery/door/airlock/highsecurity/armory_hatch
	var/obj/structure/closet/secure_closet/gear_locker
	var/obj/structure/closet/crate/secure/weapon/ammo_crate
	var/obj/item/gun/energy/disabler/smg/disabler
	var/obj/item/gun/ballistic/automatic/laser/laser_rifle
	var/rechargers = 0
	for(var/turf/tile as anything in ship.return_turfs())
		if(!istype(get_area(tile), /area/shuttle/stationtrauma_space/nt_patrol/armory))
			continue
		armory_hatch ||= locate(/obj/machinery/door/airlock/highsecurity) in tile
		gear_locker ||= locate(/obj/structure/closet/secure_closet) in tile
		ammo_crate ||= locate(/obj/structure/closet/crate/secure/weapon) in tile
		if(locate(/obj/structure/rack/gunrack) in tile)
			disabler ||= locate(/obj/item/gun/energy/disabler/smg) in tile
			laser_rifle ||= locate(/obj/item/gun/ballistic/automatic/laser) in tile
		if(locate(/obj/machinery/recharger) in tile)
			rechargers++
	var/datum/id_trim/nt_patrol/armory/trim = allocate(/datum/id_trim/nt_patrol/armory)
	TEST_ASSERT(armory_hatch?.check_access_list(trim.access), "The patrol officer's ID must open the armory")
	TEST_ASSERT(gear_locker?.locked && gear_locker.check_access_list(trim.access) && !gear_locker.check_access_list(list()), "The patrol armory ID must unlock the equipment locker")
	TEST_ASSERT((locate(/obj/item/shield/riot) in gear_locker) && (locate(/obj/item/clothing/suit/armor/riot) in gear_locker), "The patrol shield and armor must load inside the locker")
	TEST_ASSERT(disabler && laser_rifle && disabler.loc != laser_rifle.loc, "The Amber and Red weapons must load onto separate racks")
	TEST_ASSERT_EQUAL(rechargers, 1, "The armory must provide a recharger")
	TEST_ASSERT(ammo_crate?.locked && ammo_crate.check_access_list(list(ACCESS_CENT_SPECOPS)) && !ammo_crate.check_access_list(list()), "Patrol crew must be able to unlock the ammunition reserve")
	for(var/obj/machinery/stationtrauma_autocannon/gun as anything in ship.ship_autocannons)
		if(!gun.ammo_type)
			continue
		var/rounds = 0
		for(var/obj/item/stack/stationtrauma_autocannon_shell/ammo in ammo_crate)
			if(ammo.merge_type == gun.ammo_type)
				rounds += ammo.get_amount()
		TEST_ASSERT_EQUAL(rounds, 2 * gun.feed_capacity, "The armory crate must hold two full reloads for [gun]")

/// Simulate the claim becoming invalid during the native loader's yielding work.
/datum/unit_test/overmap_nt_patrol/proc/reject_patrol_arrival()
	return FALSE

/// Map cleanup yields, so perform it before the no-sleep datum teardown.
/datum/unit_test/overmap_nt_patrol/proc/discard_test_hull()
	QDEL_LIST_ASSOC_VAL(fired_rounds)
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
	for(var/mob/dead/new_player/player in allocated)
		player.key = null
		player.mock_client = null
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
