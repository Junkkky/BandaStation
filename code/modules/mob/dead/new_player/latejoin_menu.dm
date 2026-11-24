#define JOB_CHOICE_YES "Yes"
#define JOB_CHOICE_REROLL "Reroll"
#define JOB_CHOICE_CANCEL "Cancel"

GLOBAL_DATUM_INIT(latejoin_menu, /datum/latejoin_menu, new)

/// The native selector uses the same availability and spawn path as the TGUI menu.
/datum/latejoin_menu/proc/fallback_ui(mob/dead/new_player/user)
	var/client/requester = user?.client
	var/datum/mind/request_mind = user?.mind
	var/editing_slot = requester?.prefs?.default_slot
	if(!user?.check_latejoin_request(requester, request_mind, editing_slot, skip_arrivals_checks = TRUE))
		return
	var/list/choices = list()
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		var/availability = user.IsJobUnavailable(job.title, latejoin = TRUE)
		if(!user?.is_latejoin_request_current(requester, request_mind, editing_slot))
			return
		if(availability == JOB_AVAILABLE)
			choices[job.title] = list(job.title, null)
	for(var/list/destination as anything in get_away_destinations(user, requester, request_mind, editing_slot))
		var/list/jobs = destination["jobs"]
		for(var/title in jobs)
			var/list/job_data = jobs[title]
			if(!job_data["unavailable_reason"])
				choices["[destination["name"]] — [title] ([job_data["used_slots"]]/[job_data["open_slots"]])"] = list(title, destination["id"])
	if(!user?.is_latejoin_request_current(requester, request_mind, editing_slot))
		return
	if(!length(choices))
		to_chat(user, span_warning("В данный момент для вас нет доступных профессий."))
		return

	var/choice = input(user, "Выберите должность и место прибытия.", "Позднее присоединение") as null|anything in choices
	var/list/selection = choices[choice]
	if(selection && user?.is_latejoin_request_current(requester, request_mind, editing_slot))
		user.AttemptLateSpawn(selection[1], selection[2])

/datum/latejoin_menu/ui_close(mob/dead/new_player/user)
	. = ..()
	if(istype(user))
		user.jobs_menu_mounted = TRUE // Don't flood a user's chat if they open and close the UI.

/datum/latejoin_menu/ui_interact(mob/dead/new_player/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		// In case they reopen the GUI
		// FIXME: this can cause a runtime since user can be a living mob
		if(istype(user))
			user.jobs_menu_mounted = FALSE
			addtimer(CALLBACK(src, PROC_REF(scream_at_player), user), 5 SECONDS)

		ui = new(user, src, "JobSelection", "Позднее присоединение")
		ui.open()

/datum/latejoin_menu/proc/scream_at_player(mob/dead/new_player/player)
	if(!QDELETED(player) && !player.jobs_menu_mounted)
		to_chat(player, span_notice("If the late join menu isn't showing, hold CTRL while clicking the join button!"))

/datum/latejoin_menu/ui_data(mob/user)
	var/mob/dead/new_player/owner = user
	if(!istype(owner))
		return list()
	var/client/requester = owner.client
	var/datum/mind/request_mind = owner.mind
	var/editing_slot = requester?.prefs?.default_slot
	if(!owner.is_latejoin_request_current(requester, request_mind, editing_slot))
		return list()
	var/list/departments = list()
	var/round_duration = world.time - SSticker.round_start_time
	var/list/data = list(
		"disable_jobs_for_non_observers" = SSlag_switch.measures[DISABLE_NON_OBSJOBS],
		"round_duration" = round_duration < 1 SECONDS ? "0 секунд" : DisplayTimeText(round_duration, round_seconds_to = 1),
		"edit_slot" = editing_slot,
		"departments" = departments,
	)
	if(SSshuttle.emergency)
		switch(SSshuttle.emergency.mode)
			if(SHUTTLE_ESCAPE)
				data["shuttle_status"] = "Станция эвакуирована."
			if(SHUTTLE_CALL, SHUTTLE_DOCKED, SHUTTLE_IGNITING, SHUTTLE_ESCAPE)
				data["shuttle_status"] = "На станции идёт эвакуация."

	for(var/datum/job/prioritized_job in SSjob.prioritized_jobs)
		if(prioritized_job.current_positions >= prioritized_job.total_positions)
			SSjob.prioritized_jobs -= prioritized_job

	for(var/datum/job_department/department as anything in SSjob.joinable_departments)
		var/list/department_jobs = list()
		var/list/department_data = list(
			"jobs" = department_jobs,
			"open_slots" = 0,
		)
		departments[department.department_name] = department_data

		for(var/datum/job/job_datum as anything in department.department_jobs)
			//Jobs under multiple departments should only be displayed if this is their first department or the command department
			if(LAZYLEN(job_datum.departments_list) > 1 && job_datum.departments_list[1] != department.type && !(department.department_bitflags & DEPARTMENT_BITFLAG_COMMAND))
				continue

			var/job_availability = owner.IsJobUnavailable(job_datum.title, latejoin = TRUE)
			if(!owner?.is_latejoin_request_current(requester, request_mind, editing_slot))
				return list()
			if(job_availability == JOB_UNAVAILABLE_SLOTFULL && (job_datum.job_flags & JOB_HIDE_WHEN_EMPTY))
				continue

			if(job_availability == JOB_AVAILABLE)
				if(job_datum.total_positions < 0)
					department_data["open_slots"] = "∞"
				else if(department_data["open_slots"] != "∞")
					department_data["open_slots"] += max(0, job_datum.total_positions - job_datum.current_positions)
			department_jobs[job_datum.title] = get_job_row(requester, job_datum, job_availability)

	data["away_destinations"] = get_away_destinations(owner, requester, request_mind, editing_slot)
	return owner?.is_latejoin_request_current(requester, request_mind, editing_slot) ? data : list()

/// Build the common row data once per job, before applying hull-specific capacity.
/datum/latejoin_menu/proc/get_job_row(client/requester, datum/job/job, availability)
	var/datum/job_character_selection/selection = requester.prefs.select_job_character(job, latejoin = TRUE)
	var/character_profile = selection.error ? "Недоступный профиль" : "Профиль [selection.slot]"
	if(selection.randomized)
		character_profile += ", случайные имя и внешность"
	var/list/job_data = list(
		"prioritized" = (job in SSjob.prioritized_jobs),
		"used_slots" = job.current_positions,
		"open_slots" = job.total_positions < 0 ? "∞" : job.total_positions,
		"jobIcon" = job.tgui_icon,
		"character_profile" = character_profile,
		"public_title" = selection.error ? null : requester.prefs.get_donor_job_title(job, selection.slot),
		"unavailable_reason" = availability == JOB_AVAILABLE ? null : get_job_unavailable_error_message(availability, job.title),
	)
	qdel(selection)
	return job_data

/// Offer named hulls and, where a new hull is needed, the option to launch it on boarding.
/datum/latejoin_menu/proc/get_away_destinations(mob/dead/new_player/owner, client/requester, datum/mind/request_mind, editing_slot)
	var/list/destinations = list()
	if(!SSmapping.current_map?.space_overmap || !SSstationtrauma_space_voyage.initialized)
		return destinations
	for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
		if(!mission.get_instance_limit())
			continue
		var/list/role_rows = list()
		var/list/role_details = list()
		for(var/job_type in mission.minimum_crew)
			var/datum/job/away_mission/job = SSjob.get_job_type(job_type)
			if(!job)
				continue
			var/availability = owner.IsJobUnavailable(job.title, latejoin = TRUE)
			if(!owner?.is_latejoin_request_current(requester, request_mind, editing_slot))
				return list()
			role_rows[job] = get_job_row(requester, job, availability)
			role_details[job.title] = list("description" = job.description, "command" = job_type == mission.commander_job)
		var/limit = mission.get_instance_limit()
		if(!limit || !length(role_rows))
			continue
		var/list/details = list("color" = /datum/job_department/away_missions::ui_color, "jobs" = role_details)
		var/list/vessels = mission.get_loaded_ships()
		var/list/boardable_roles = list()
		for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in vessels)
			destinations += list(get_away_destination(mission, vessel, role_rows, details, boardable_roles))
		if(length(vessels) < limit && length(boardable_roles) < length(role_rows))
			destinations += list(get_away_destination(mission, null, role_rows, details, boardable_roles))
	return destinations

/// Use the same hull roster and cryopod access checks that authorize boarding.
/datum/latejoin_menu/proc/get_away_destination(datum/roundstart_away_mission/mission, obj/docking_port/mobile/stationtrauma_space/vessel, list/role_rows, list/details, list/boardable_roles)
	var/list/jobs = list()
	var/vacancies = 0
	var/arrival_ready = !vessel || mission.find_latejoin_spawn(vessel)
	for(var/datum/job/away_mission/job as anything in role_rows)
		var/list/base_row = role_rows[job]
		var/list/job_data = base_row.Copy()
		var/capacity = initial(job.total_positions)
		var/occupied = vessel ? vessel.count_away_crew(job) : 0
		job_data["open_slots"] = capacity
		job_data["used_slots"] = occupied
		if(vessel)
			if(occupied >= capacity)
				job_data["unavailable_reason"] = "На этом корабле все места этой роли заняты."
			else if(!arrival_ready)
				job_data["unavailable_reason"] = "Точка прибытия у криокапсулы сейчас недоступна."
			else
				boardable_roles |= job
		else if(job in boardable_roles)
			job_data["unavailable_reason"] = "Для этой роли есть место на действующем корабле."
		if(!job_data["unavailable_reason"])
			vacancies += max(0, capacity - occupied)
		jobs[job.title] = job_data
	return list(
		"id" = vessel ? REF(vessel) : REF(mission),
		"name" = vessel ? vessel.name : "Новый корпус — [mission.name]",
		"jobs" = jobs,
		"open_slots" = vacancies,
		"details" = details,
	)

/datum/latejoin_menu/ui_static_data(mob/user)
	var/static/list/premium_job_icons = list()
	var/list/departments = list()

	for(var/datum/job_department/department as anything in SSjob.joinable_departments)
		var/list/department_jobs = list()
		var/list/department_data = list(
			"jobs" = department_jobs,
			"color" = department.ui_color,
		)
		departments[department.department_name] = department_data

		for(var/datum/job/job_datum as anything in department.department_jobs)
			//Jobs under multiple departments should only be displayed if this is their first department or the command department
			if(LAZYLEN(job_datum.departments_list) > 1 && job_datum.departments_list[1] != department.type && !(department.department_bitflags & DEPARTMENT_BITFLAG_COMMAND))
				continue

			var/list/job_data = list(
				"command" = !!(job_datum.departments_bitflags & DEPARTMENT_BITFLAG_COMMAND),
				"description" = job_datum.description,
			)
			if(job_datum.required_donator_level)
				if(isnull(premium_job_icons[job_datum.type]))
					premium_job_icons[job_datum.type] = icon2base64(get_job_hud_icon(job_datum)) || ""
				job_data["job_icon"] = premium_job_icons[job_datum.type]

			department_jobs[job_datum.title] = job_data

	return list("departments_static" = departments)

/datum/latejoin_menu/ui_state(mob/user)
	return GLOB.new_player_state

/datum/latejoin_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	if(!ui.user.client || ui.user.client.interviewee || !isnewplayer(ui.user))
		return TRUE

	var/mob/dead/new_player/owner = ui.user

	switch(action)
		if("ui_mounted_with_no_bluescreen")
			owner.jobs_menu_mounted = TRUE
		if("select_job")
			var/client/requester = owner.client
			var/datum/mind/request_mind = owner.mind
			var/editing_slot = requester.prefs.default_slot
			var/job_title = params["job"]
			var/away_target = params["away_target"]
			if(!isnull(away_target) && (!istext(away_target) || job_title == "Random"))
				return TRUE
			if(params["edit_slot"] != editing_slot || !owner.check_latejoin_request(requester, request_mind, editing_slot, skip_arrivals_checks = job_title != "Random"))
				return TRUE
			if(job_title == "Random")
				job_title = get_random_job(owner)
			if(istext(job_title) && owner?.is_latejoin_request_current(requester, request_mind, editing_slot))
				owner.AttemptLateSpawn(job_title, away_target)
			return TRUE
		if("viewpoll")
			var/datum/poll_question/poll = locate(params["viewpoll"]) in GLOB.polls
			if(!poll)
				return TRUE

			owner.poll_player(poll)
			return TRUE

		if("votepollref")
			var/datum/poll_question/poll = locate(params["votepollref"]) in GLOB.polls
			if(!poll)
				return TRUE

			owner.vote_on_poll_handler(poll, params)
			return TRUE

/// Gives the user a random job that they can join as, and prompts them if they'd actually like to keep it, rerolling if not. Cancellable by the user.
/// WARNING: BLOCKS THREAD!
/datum/latejoin_menu/proc/get_random_job(mob/dead/new_player/owner)
	var/client/requester = owner.client
	var/datum/mind/request_mind = owner.mind
	var/editing_slot = requester?.prefs?.default_slot
	var/list/jobs = list()
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(job.required_donator_level)
			continue
		var/availability = owner.IsJobUnavailable(job.title, latejoin = TRUE)
		if(!owner?.is_latejoin_request_current(requester, request_mind, editing_slot))
			return
		if(availability == JOB_AVAILABLE)
			jobs += job.title

	while(length(jobs))
		var/random = pick_n_take(jobs)
		var/list/random_job_options = list(JOB_CHOICE_YES, JOB_CHOICE_REROLL, JOB_CHOICE_CANCEL)
		var/random_job = tgui_alert(owner, "[job_title_ru(random)]?", "Случайная должность", random_job_options)
		if(!owner?.is_latejoin_request_current(requester, request_mind, editing_slot) || !random_job || random_job == JOB_CHOICE_CANCEL)
			return
		if(random_job == JOB_CHOICE_YES)
			return random
	to_chat(owner, span_warning("В данный момент для вас нет доступной случайной профессии."))

#undef JOB_CHOICE_YES
#undef JOB_CHOICE_REROLL
#undef JOB_CHOICE_CANCEL
