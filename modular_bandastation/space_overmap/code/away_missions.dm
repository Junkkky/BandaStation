/// Crewable overmap scenario offered through character preferences.
/datum/roundstart_away_mission
	/// Name used in preferences and roundstart logs.
	var/name
	/// Trusted template loaded for a complete roundstart crew or an approved latejoin request.
	var/map_path
	/// Map of job type to the minimum number of players in that job.
	var/list/minimum_crew
	/// Role in command of the crew.
	var/commander_job
	/// Short registration names suitable for this class of ship.
	var/list/ship_names = list()

/datum/roundstart_away_mission/nt_patrol
	name = "Патрульный эсминец НТ"
	map_path = "_maps/map_files/overmap_ships/nt_patrol_destroyer.dmm"
	commander_job = /datum/job/away_mission/nt_patrol_commander
	ship_names = list("Брут", "Степь", "Рубеж", "Форпост", "Гранит", "Сапсан", "Дозорный", "Меридиан")
	minimum_crew = list(
		/datum/job/away_mission/nt_patrol_commander = 1,
		/datum/job/away_mission/nt_patrol_engineer = 1,
		/datum/job/away_mission/nt_patrol_medic = 1,
		/datum/job/away_mission/nt_patrol_officer = 1,
	)

/// Server-owned mission definitions shared by preferences and the roundstart draw.
/proc/roundstart_away_missions()
	var/static/list/missions = init_subtypes(/datum/roundstart_away_mission)
	return missions

/datum/controller/subsystem/job
	/// Null means automatic selection. Otherwise only missions with a positive limit may launch.
	var/list/away_mission_limits

/// Set the available crew positions across all permitted copies of each mission.
/datum/controller/subsystem/job/proc/update_away_job_capacity()
	for(var/datum/job/away_mission/job in all_occupations)
		var/datum/roundstart_away_mission/mission = job.get_away_mission()
		job.total_positions = initial(job.total_positions) * (mission?.get_instance_limit() || 0)

/// Return how many independent copies of this mission the round can host.
/datum/roundstart_away_mission/proc/get_instance_limit()
	if(isnull(SSjob.away_mission_limits))
		return 1
	return SSjob.away_mission_limits[type] || 0

/// Return the registered copies still available to their crews.
/datum/roundstart_away_mission/proc/get_loaded_ships()
	var/list/vessels = list()
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in SSshuttle.mobile_docking_ports)
		if(vessel.source_template != map_path)
			continue
		var/datum/stationtrauma_overmap/space/navigation = vessel.overmap
		var/datum/stationtrauma_overmap_sector/space/sector = navigation?.sector
		if(!QDELETED(navigation) && navigation.is_operational() && sector?.ready && sector.ships[vessel.shuttle_id] == navigation)
			vessels += vessel
	return vessels

/// Resolve a registered mission's trusted map file.
/proc/away_mission_for_template(map_path)
	for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
		if(mission.map_path == map_path)
			return mission
	return null

/// Draw from the crewable mission pool after reserving priority station positions.
/datum/controller/subsystem/job/proc/assign_roundstart_away_missions(allow_all, list/pending_templates)
	if(!SSmapping.current_map?.space_overmap || !SSstationtrauma_space_voyage.initialized)
		return
	update_away_job_capacity()
	var/list/mission_pool = list()
	var/automatic = isnull(away_mission_limits)
	for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
		for(var/copy in 1 to mission.get_instance_limit())
			mission_pool += mission
	if(!length(mission_pool))
		return
	if(automatic)
		shuffle_inplace(mission_pool)
	var/missions_remaining = automatic ? 2 : length(mission_pool)
	var/list/antagonist_minds = list()
	for(var/datum/dynamic_ruleset/roundstart/ruleset as anything in SSdynamic.queued_rulesets | SSdynamic.antag_token_rulesets)
		antagonist_minds |= ruleset.selected_minds
	var/list/optional_assignments = list()
	for(var/datum/roundstart_away_mission/mission as anything in mission_pool)
		var/list/candidates = mission.find_crew(antagonist_minds)
		if(!candidates)
			continue
		var/datum/callback/seat_crew = CALLBACK(mission, TYPE_PROC_REF(/datum/roundstart_away_mission, seat_crew), candidates, allow_all, optional_assignments)
		var/obj/docking_port/mobile/stationtrauma_space/vessel
		for(var/obj/docking_port/mobile/stationtrauma_space/existing as anything in mission.get_loaded_ships())
			if(!optional_assignments[existing] && seat_crew.Invoke(existing))
				vessel = existing
				break
		if(!vessel)
			try
				vessel = SSstationtrauma_space_voyage.load_ship_template(mission.map_path, seat_crew, pending_templates, new_instance = TRUE)
			catch(var/exception/load_error)
				log_mapping("Roundstart away mission [mission.name] failed to load: [load_error]")
		if(!vessel)
			continue
		log_game("Roundstart away mission staffed: [mission.name] ([vessel.shuttle_id])")
		missions_remaining--
		if(!missions_remaining)
			break
	// Do not fill optional positions on one ship while another still needs its minimum crew.
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in optional_assignments)
		var/datum/callback/fill_seats = optional_assignments[vessel]
		fill_seats.Invoke()

/// Find eligible volunteers before allocating a level. The assignment is checked again after loading.
/datum/roundstart_away_mission/proc/find_crew(list/antagonist_minds)
	var/list/candidates = list()
	for(var/job_type in minimum_crew)
		var/datum/job/away_mission/job = SSjob.get_job_type(job_type)
		if(!job || job.spawn_positions < minimum_crew[job_type])
			return null
		var/list/volunteers = list()
		for(var/mob/dead/new_player/player as anything in SSjob.unassigned)
			if(QDELETED(player) || !player.is_ready_to_play() || !player.mind || (player.mind in antagonist_minds) || !player.client?.prefs.get_away_job_priority(job))
				continue
			if(SSjob.check_job_eligibility(player, job, "AWAY") == JOB_AVAILABLE)
				volunteers += player
		if(length(volunteers) < minimum_crew[job_type])
			return null
		candidates[job] = volunteers
	if(!match_required_crew(rank_crew_candidates(candidates)))
		return null
	return candidates

/// Recheck the live lobby and order ties randomly before matching or assigning any seats.
/datum/roundstart_away_mission/proc/rank_crew_candidates(list/candidates)
	var/list/ranked = list()
	for(var/datum/job/away_mission/job as anything in candidates)
		var/list/levels = list(list(), list(), list())
		for(var/mob/dead/new_player/player as anything in candidates[job])
			if(QDELETED(player) || player.ready != PLAYER_READY_TO_PLAY || !is_unassigned_job(player.mind?.assigned_role) || !(player in SSjob.unassigned))
				continue
			var/client/player_client = GET_CLIENT(player)
			var/datum/preferences/preferences = player_client?.prefs
			var/priority = preferences?.get_away_job_priority(job)
			if(!priority)
				continue
			var/datum/job_character_selection/selection = preferences.select_job_character(job)
			var/eligibility = selection.get_eligibility(job)
			qdel(selection)
			if(eligibility == JOB_AVAILABLE)
				levels[priority] += player
		for(var/priority in JP_LOW to JP_HIGH)
			levels[priority] = shuffle(levels[priority])
		ranked[job] = levels
	return ranked

/// Find a distinct volunteer for every essential seat before committing any assignments.
/datum/roundstart_away_mission/proc/match_required_crew(list/candidates)
	var/list/jobs_by_seat = list()
	for(var/datum/job/away_mission/job as anything in candidates)
		for(var/index in 1 to minimum_crew[job.type])
			jobs_by_seat += job
	var/list/players_by_seat = new(length(jobs_by_seat))
	var/list/seats_by_player = list()
	var/list/volunteers_by_job = list()
	// Give higher priorities first claim across all jobs, then add lower-ranked options.
	for(var/priority in JP_HIGH to JP_LOW step -1)
		for(var/datum/job/away_mission/job as anything in candidates)
			var/list/levels = candidates[job]
			var/list/volunteers = volunteers_by_job[job]
			if(!volunteers)
				volunteers = list()
				volunteers_by_job[job] = volunteers
			volunteers += levels[priority]
		for(var/seat in 1 to length(jobs_by_seat))
			if(!players_by_seat[seat])
				match_crew_seat(seat, jobs_by_seat, volunteers_by_job, players_by_seat, seats_by_player, list())
		if(length(seats_by_player) == length(jobs_by_seat))
			break
	if(length(seats_by_player) != length(jobs_by_seat))
		return null
	var/list/required_crew = list()
	for(var/seat in 1 to length(jobs_by_seat))
		required_crew[players_by_seat[seat]] = jobs_by_seat[seat]
	return required_crew

/// Try a free volunteer first. If none is free, move an already matched volunteer only when their seat can be backfilled.
/datum/roundstart_away_mission/proc/match_crew_seat(seat, list/jobs_by_seat, list/candidates, list/players_by_seat, list/seats_by_player, list/visited)
	var/list/volunteers = candidates[jobs_by_seat[seat]]
	for(var/mob/dead/new_player/player as anything in volunteers)
		if(visited[player] || seats_by_player[player])
			continue
		players_by_seat[seat] = player
		seats_by_player[player] = seat
		return TRUE
	for(var/mob/dead/new_player/player as anything in volunteers)
		if(visited[player])
			continue
		visited[player] = TRUE
		if(match_crew_seat(seats_by_player[player], jobs_by_seat, candidates, players_by_seat, seats_by_player, visited))
			players_by_seat[seat] = player
			seats_by_player[player] = seat
			return TRUE
	return FALSE

/// Read distinct walkable crew landmarks from this hull's native shuttle areas.
/datum/roundstart_away_mission/proc/find_crew_spawns(obj/docking_port/mobile/stationtrauma_space/vessel)
	var/list/spawns = list()
	var/list/occupied = list()
	for(var/obj/effect/landmark/away_mission/marker in GLOB.landmarks_list)
		if(!(marker.job_type in minimum_crew) || !vessel.is_in_shuttle_bounds(marker) || !vessel.shuttle_areas[get_area(marker)])
			continue
		var/turf/tile = get_turf(marker)
		if(!isfloorturf(tile) || occupied[tile] || tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		occupied[tile] = TRUE
		if(!spawns[marker.job_type])
			spawns[marker.job_type] = list()
		spawns[marker.job_type] |= tile
	return spawns

/// Reserve all essential seats together. Returning false discards a newly loaded template.
/datum/roundstart_away_mission/proc/seat_crew(list/candidates, allow_all, list/optional_assignments, obj/docking_port/mobile/stationtrauma_space/vessel)
	var/list/ranked = rank_crew_candidates(candidates)
	var/list/required_crew = match_required_crew(ranked)
	if(!required_crew)
		return FALSE
	var/list/spawns = find_crew_spawns(vessel)
	var/list/assigned = list()
	for(var/datum/job/away_mission/job as anything in candidates)
		var/list/job_spawns = spawns[job.type]
		if(length(job_spawns) < job.spawn_positions)
			log_mapping("Roundstart away mission [name] lacks crew spawn points for [job.title]")
			return FALSE
		job_spawns.Cut(job.spawn_positions + 1)
		shuffle_inplace(job_spawns)

	for(var/mob/dead/new_player/required_player as anything in required_crew)
		var/datum/job/away_mission/job = required_crew[required_player]
		assign_seats(job, list(required_player), spawns[job.type], assigned, allow_all, vessel)
		if(!(required_player in assigned))
			for(var/mob/dead/new_player/player as anything in assigned)
				var/datum/job/away_mission/assigned_job = player.mind.assigned_role
				assigned_job.current_positions--
				assigned_job.roundstart_spawns -= player
				player.mind.release_away_mission_seat()
				QDEL_NULL(player.assigned_job_character)
				player.mind.set_assigned_role(SSjob.get_job_type(/datum/job/unassigned))
				SSjob.unassigned += player
			return FALSE

	if(isnull(optional_assignments))
		fill_optional_seats(candidates, spawns, allow_all, vessel)
	else
		optional_assignments[vessel] = CALLBACK(src, PROC_REF(fill_optional_seats), candidates, spawns, allow_all, vessel)
	return TRUE

/// Fill any remaining positions after the other hulls have reserved their essential crew.
/datum/roundstart_away_mission/proc/fill_optional_seats(list/candidates, list/spawns, allow_all, obj/docking_port/mobile/stationtrauma_space/vessel)
	if(QDELETED(vessel))
		return
	var/list/ranked = rank_crew_candidates(candidates)
	var/list/assigned = list()
	for(var/priority in JP_HIGH to JP_LOW step -1)
		for(var/datum/job/away_mission/job as anything in ranked)
			var/list/levels = ranked[job]
			assign_seats(job, levels[priority], spawns[job.type], assigned, allow_all, vessel)

/// The ban check already ran in find_crew. Recheck readiness and the live profile without yielding here.
/datum/roundstart_away_mission/proc/assign_seats(datum/job/away_mission/job, list/volunteers, list/spawns, list/assigned, allow_all, obj/docking_port/mobile/stationtrauma_space/vessel)
	for(var/mob/dead/new_player/player as anything in volunteers)
		if(!length(spawns) || (!allow_all && SSjob.popcap_reached()))
			break
		if(QDELETED(player) || player.ready != PLAYER_READY_TO_PLAY || !is_unassigned_job(player.mind?.assigned_role) || !(player in SSjob.unassigned))
			continue
		var/client/player_client = GET_CLIENT(player)
		var/datum/preferences/preferences = player_client?.prefs
		if(!preferences?.get_away_job_priority(job))
			continue
		if(SSjob.assign_role(player, job, do_eligibility_checks = FALSE))
			assigned += player
			LAZYSET(job.roundstart_spawns, player, spawns[length(spawns)])
			spawns.len--
			vessel.record_away_crew(player.mind)

/obj/docking_port/mobile/stationtrauma_space
	/// Formation slot used by this instance of an away mission template.
	var/away_instance_slot
	/// Weak mind references to reservations aboard this hull, indexed by mind.
	var/list/away_crew

/datum/mind
	/// Hull that owns this player's mission vacancy, independent of their physical location.
	var/datum/weakref/away_mission_ship

/// Count occupied and reserved seats for this role on this particular hull.
/obj/docking_port/mobile/stationtrauma_space/proc/count_away_crew(datum/job/away_mission/job)
	var/occupied = 0
	for(var/datum/weakref/mind_ref as anything in away_crew)
		var/datum/mind/occupant = mind_ref.resolve()
		if(occupant?.assigned_role == job)
			occupied++
	return occupied

/// Return whether this hull has a vacancy for the requested crew role.
/obj/docking_port/mobile/stationtrauma_space/proc/has_away_vacancy(datum/job/away_mission/job)
	return count_away_crew(job) < initial(job.total_positions)

/// Record the same reservation on the hull and the mind so rollback or cryo can release it.
/obj/docking_port/mobile/stationtrauma_space/proc/record_away_crew(datum/mind/crew_mind)
	crew_mind.release_away_mission_seat()
	LAZYOR(away_crew, WEAKREF(crew_mind))
	crew_mind.away_mission_ship = WEAKREF(src)

/// Release this mind's own hull position even if they entered a cryopod elsewhere.
/datum/mind/proc/release_away_mission_seat()
	var/obj/docking_port/mobile/stationtrauma_space/vessel = away_mission_ship?.resolve()
	if(vessel)
		LAZYREMOVE(vessel.away_crew, WEAKREF(src))
	away_mission_ship = null

/// Find a walkable arrival tile on the same hull as its mapped cryopod.
/datum/roundstart_away_mission/proc/find_latejoin_spawn(obj/docking_port/mobile/stationtrauma_space/vessel)
	if(QDELETED(vessel) || !vessel.overmap?.is_operational() || vessel.overmap.relocating)
		return null
	for(var/area/compartment as anything in vessel.shuttle_areas)
		for(var/obj/machinery/cryopod/away_mission/pod in compartment)
			if(QDELETED(pod) || !vessel.is_in_shuttle_bounds(pod))
				continue
			var/turf/destination = get_step(pod, pod.dir)
			if(isfloorturf(destination) && vessel.is_in_shuttle_bounds(destination) && !destination.is_blocked_turf(exclude_mobs = TRUE))
				return destination
	return null

/// Resolve the exact offered hull, or the first boardable hull for an automatic request.
/datum/roundstart_away_mission/proc/find_boardable_ship(datum/job/away_mission/job, list/vessels, away_target)
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in vessels)
		if(!isnull(away_target) && REF(vessel) != away_target)
			continue
		if(vessel.has_away_vacancy(job) && find_latejoin_spawn(vessel))
			return vessel
	return null

/// Reserve a vacancy on the requested hull, or load a new one when no existing hull can board the role.
/mob/dead/new_player/proc/prepare_away_latejoin_spawn(datum/job/away_mission/job, client/requester, datum/mind/request_mind, editing_slot, away_target)
	var/datum/roundstart_away_mission/mission = job.get_away_mission()
	if(!mission?.get_instance_limit())
		return null
	// Another accepted claim may still be preparing or rejecting a copy.
	UNTIL(!SSstationtrauma_space_voyage.loading_ship_template || !is_latejoin_request_current(requester, request_mind, editing_slot) || !SSticker.IsRoundInProgress())
	if(!is_away_latejoin_claim_current(job, requester, request_mind, editing_slot))
		return null
	var/list/destination = list()
	var/list/vessels = mission.get_loaded_ships()
	if(away_target == REF(mission))
		if(mission.find_boardable_ship(job, vessels))
			return null
	else
		var/obj/docking_port/mobile/stationtrauma_space/vessel = mission.find_boardable_ship(job, vessels, away_target)
		if(vessel && validate_away_latejoin(job, mission, requester, request_mind, editing_slot, destination, vessel))
			return destination[1]
		if(!isnull(away_target))
			return null
	if(length(vessels) >= mission.get_instance_limit())
		return null
	var/datum/callback/validate_claim = CALLBACK(src, PROC_REF(validate_away_latejoin), job, mission, requester, request_mind, editing_slot, destination)
	try
		if(SSstationtrauma_space_voyage.load_ship_template(mission.map_path, validate_claim, new_instance = TRUE))
			return destination[1]
	catch(var/exception/load_error)
		log_mapping("Latejoin away mission [mission.name] failed to load: [load_error]")
	return null

/// The reservation must still belong to this lobby request when the loader opens a deck.
/mob/dead/new_player/proc/is_away_latejoin_claim_current(datum/job/away_mission/job, client/requester, datum/mind/request_mind, editing_slot)
	return is_latejoin_request_current(requester, request_mind, editing_slot) && spawning && request_mind.assigned_role == job && !get_latejoin_block_message(skip_arrivals_checks = TRUE)

/// Validate the original claim after mapping yields. A failed claim discards a freshly loaded hull.
/mob/dead/new_player/proc/validate_away_latejoin(datum/job/away_mission/job, datum/roundstart_away_mission/mission, client/requester, datum/mind/request_mind, editing_slot, list/destination, obj/docking_port/mobile/stationtrauma_space/vessel)
	if(!is_away_latejoin_claim_current(job, requester, request_mind, editing_slot) || !mission.get_instance_limit() || !vessel.has_away_vacancy(job))
		return FALSE
	var/turf/arrival = mission.find_latejoin_spawn(vessel)
	if(!arrival)
		return FALSE
	vessel.record_away_crew(request_mind)
	destination += arrival
	return TRUE

/// Group for latejoin and job bans. Its roles stay outside the station job lists.
/datum/job_department/away_missions
	department_name = "Вне станции"
	ui_color = "#6681a5"

/// Build the off-station group from the same server-owned mission pool used for staging.
/datum/controller/subsystem/job/proc/get_away_mission_department(available_only = FALSE)
	var/datum/job_department/away_missions/department = new
	for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
		if(available_only && !mission.get_instance_limit())
			continue
		for(var/job_type in mission.minimum_crew)
			var/datum/job/away_mission/job = get_job_type(job_type)
			if(job)
				department.department_jobs |= job
	return department

/// Independent job priorities for the current character, stored under the original opt-in key.
/datum/preference/away_mission_job_priorities
	savefile_key = "away_mission_role"
	savefile_identifier = PREFERENCE_CHARACTER
	can_randomize = FALSE
	should_update_preview = FALSE

/datum/preference/away_mission_job_priorities/create_default_value()
	return list()

/datum/preference/away_mission_job_priorities/deserialize(input, datum/preferences/preferences)
	// A single role from an older profile becomes its highest preference.
	if(istext(input))
		var/old_title = input
		input = list()
		input[old_title] = JP_HIGH
	var/list/priorities = list()
	if(!islist(input))
		return priorities
	var/has_high = FALSE
	for(var/title in input)
		if(!istext(title))
			continue
		var/datum/job/away_mission/job = SSjob.get_job(title)
		var/level = input[title]
		if(!istype(job) || !job.get_away_mission() || !(level in list(JP_LOW, JP_MEDIUM, JP_HIGH)))
			continue
		if(level == JP_HIGH)
			level = has_high ? JP_MEDIUM : JP_HIGH
			has_high = TRUE
		priorities[title] = level
	return priorities

/datum/preference/away_mission_job_priorities/is_valid(value, datum/preferences/preferences)
	return islist(value)

/datum/preference/away_mission_job_priorities/is_accessible(datum/preferences/preferences)
	return ..() && !!SSmapping.current_map?.space_overmap

/datum/preference/away_mission_job_priorities/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/// Whether the current profile volunteers for any off-station job on this map.
/datum/preferences/proc/has_away_job_preferences()
	if(!SSmapping.current_map?.space_overmap)
		return FALSE
	var/list/priorities = read_preference(/datum/preference/away_mission_job_priorities)
	for(var/title in priorities)
		var/datum/job/away_mission/job = SSjob.get_job(title)
		if(!istype(job))
			continue
		var/datum/roundstart_away_mission/mission = job.get_away_mission()
		if(mission?.get_instance_limit())
			return TRUE
	return FALSE

/// Off-station priority of the current profile for a particular crew job.
/datum/preferences/proc/get_away_job_priority(datum/job/away_mission/job)
	var/list/priorities = read_preference(/datum/preference/away_mission_job_priorities)
	return priorities[job.title]

/datum/preference_middleware/away_missions
	action_delegations = list("set_away_job_preference" = PROC_REF(set_away_job_preference))

/datum/preference_middleware/away_missions/proc/set_away_job_preference(list/params, mob/user)
	var/title = params["job"]
	var/level = params["level"]
	if(!istext(title) || (!isnull(level) && !(level in list(JP_LOW, JP_MEDIUM, JP_HIGH))))
		return FALSE
	var/datum/job/away_mission/job = SSjob.get_job(title)
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/away_mission_job_priorities]
	if(!istype(job) || !job.get_away_mission() || !preference.is_accessible(preferences))
		return FALSE
	var/list/priorities = preferences.read_preference(preference.type)
	priorities = priorities.Copy()
	if(level == JP_HIGH)
		for(var/other_job in priorities)
			if(priorities[other_job] == JP_HIGH)
				priorities[other_job] = JP_MEDIUM
	if(isnull(level))
		priorities -= title
	else
		priorities[title] = level
	return preferences.update_preference(preference, priorities)

/// Present the same mission and slot declarations the roundstart draw uses.
/datum/preference_middleware/away_missions/get_ui_static_data(mob/user)
	if(!SSmapping.current_map?.space_overmap)
		return null
	var/list/missions = list()
	for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
		var/list/roles = list()
		for(var/job_type in mission.minimum_crew)
			var/datum/job/away_mission/job = SSjob.get_job_type(job_type)
			if(job && job.spawn_positions > 0)
				roles += list(list("title" = job.title, "description" = job.description, "slots" = job.spawn_positions))
		if(length(roles) == length(mission.minimum_crew))
			missions += list(list("name" = mission.name, "color" = /datum/job_department/away_missions::ui_color, "roles" = roles))
	return list("away_missions" = missions)

/** Ship crew job, excluded from station staffing, arrivals and manifest. */
/datum/job/away_mission
	abstract_type = /datum/job/away_mission
	job_flags = JOB_EQUIP_RANK | JOB_ASSIGN_QUIRKS | JOB_ANTAG_BLACKLISTED | JOB_CANNOT_OPEN_SLOTS
	required_donator_level = 0
	random_spawns_possible = FALSE
	allow_bureaucratic_error = FALSE
	spawn_positions = 1
	total_positions = 1
	/// Exact board positions indexed by the lobby player assigned to them.
	var/list/roundstart_spawns

/datum/job/away_mission/config_check()
	return type != abstract_type && ..()

/// Find the mission that owns this crew job.
/datum/job/away_mission/proc/get_away_mission()
	for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
		if(type in mission.minimum_crew)
			return mission
	return null

/datum/job/away_mission/special_check_latejoin(client/latejoin)
	var/datum/roundstart_away_mission/mission = get_away_mission()
	return ..() && SSmapping.current_map?.space_overmap && SSstationtrauma_space_voyage.initialized && mission?.get_instance_limit()

/datum/job/away_mission/get_roundstart_spawn_point(mob/dead/new_player/player)
	var/turf/destination = LAZYACCESS(roundstart_spawns, player)
	LAZYREMOVE(roundstart_spawns, player)
	return destination

/datum/job/away_mission/get_spawn_message_information()
	. = ..()
	.[1] = "<b>Ваша роль на борту: [title].</b>\n"

/datum/job/away_mission/nt_patrol_commander
	title = "Командир патруля НТ"
	description = "Ведёт корабль и координирует действия экипажа."
	outfit = /datum/outfit/job/nt_patrol/commander

/datum/job/away_mission/nt_patrol_engineer
	title = "Бортинженер патруля НТ"
	description = "Поддерживает работу двигателей, энергосети и систем жизнеобеспечения."
	supervisors = "командиром патруля НТ"
	outfit = /datum/outfit/job/nt_patrol/engineer

/datum/job/away_mission/nt_patrol_medic
	title = "Фельдшер патруля НТ"
	description = "Оказывает первую помощь и ведёт бортовой медотсек."
	supervisors = "командиром патруля НТ"
	outfit = /datum/outfit/job/nt_patrol/medic

/datum/job/away_mission/nt_patrol_officer
	title = "Патрульный НТ"
	description = "Охраняет экипаж и сопровождает досмотровую группу."
	supervisors = "командиром патруля НТ"
	spawn_positions = 7
	total_positions = 7
	outfit = /datum/outfit/job/nt_patrol
	auto_deadmin_role_flags = DEADMIN_POSITION_SECURITY

/datum/job/away_mission/nt_patrol_officer/is_role_banned(player_key)
	return is_banned_from(player_key, list(title, JOB_SECURITY_OFFICER))

/// Map marker for a walkable, job-specific starting position aboard an away mission.
/obj/effect/landmark/away_mission
	/// Crew job type placed here when the mission starts.
	var/datum/job/away_mission/job_type

/obj/effect/landmark/away_mission/nt_patrol_commander
	job_type = /datum/job/away_mission/nt_patrol_commander

/obj/effect/landmark/away_mission/nt_patrol_engineer
	job_type = /datum/job/away_mission/nt_patrol_engineer

/obj/effect/landmark/away_mission/nt_patrol_medic
	job_type = /datum/job/away_mission/nt_patrol_medic

/obj/effect/landmark/away_mission/nt_patrol_officer
	job_type = /datum/job/away_mission/nt_patrol_officer

/// Patrol identity without station department access.
/datum/id_trim/nt_patrol
	assignment = "Патрульный эсминец НТ"
	trim_state = "trim_assistant"

/// Standard patrol uniform and protective gear.
/datum/outfit/job/nt_patrol
	name = "Патрульный НТ"
	jobtype = /datum/job/away_mission/nt_patrol_officer
	id_trim = /datum/id_trim/nt_patrol/armory
	uniform = /obj/item/clothing/under/rank/security/officer
	shoes = /obj/item/clothing/shoes/jackboots
	head = /obj/item/clothing/head/helmet
	suit = /obj/item/clothing/suit/armor/vest
	backpack_contents = list(/obj/item/flashlight = 1, /obj/item/melee/baton/security/loaded = 1)

/datum/outfit/job/nt_patrol/commander
	name = "Командир патруля НТ"
	jobtype = /datum/job/away_mission/nt_patrol_commander
	head = null
	suit = null
	backpack_contents = list(/obj/item/flashlight = 1)

/datum/outfit/job/nt_patrol/engineer
	name = "Бортинженер патруля НТ"
	jobtype = /datum/job/away_mission/nt_patrol_engineer
	id_trim = /datum/id_trim/nt_patrol
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	head = /obj/item/clothing/head/utility/hardhat/welding/up
	suit = null
	backpack_contents = list(/obj/item/storage/toolbox/mechanical = 1)

/datum/outfit/job/nt_patrol/medic
	name = "Фельдшер патруля НТ"
	jobtype = /datum/job/away_mission/nt_patrol_medic
	id_trim = /datum/id_trim/nt_patrol
	uniform = /obj/item/clothing/under/rank/medical/doctor
	head = null
	suit = null
	glasses = /obj/item/clothing/glasses/hud/health
	backpack_contents = list(/obj/item/storage/medkit/regular = 1)
