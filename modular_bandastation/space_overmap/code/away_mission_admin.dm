/// Keep the number of managed flight decks bounded for this round.
#define MAX_AWAY_MISSION_COPIES 5

/** Whether the admin can apply a change at the current stage of this overmap round. */
/datum/controller/subsystem/job/proc/can_manage_away_missions(client/administrator)
	return check_rights_for(administrator, R_ADMIN) && SSmapping.current_map?.space_overmap && (SSticker.current_state == GAME_STATE_PREGAME || SSticker.IsRoundInProgress())

/** Choose the round's mission pool and manually launch allowed copies when the round is running. */
ADMIN_VERB(configure_away_missions, R_ADMIN, "Авейки — управление спавном", "Настроить список выездных миссий, число кораблей и ручной запуск.", ADMIN_CATEGORY_EVENTS)
	if(!SSjob.can_manage_away_missions(user))
		to_chat(user, span_warning("Управление авейками доступно в лобби или во время раунда с овермапом."), confidential = TRUE)
		return

	var/starting_state = SSticker.current_state
	var/list/old_limits = SSjob.away_mission_limits
	var/list/actions = list("Автоматический выбор", "Настроить количество", "Отключить все")
	if(SSticker.IsRoundInProgress())
		actions += "Загрузить корабли"
	var/mode = isnull(old_limits) ? "автовыбор" : (length(old_limits) ? "ручная настройка" : "авейки отключены")
	var/action = tgui_input_list(user, "Текущий режим: [mode].", "Спавн авеек", actions)
	if(!(action in actions) || !SSjob.can_manage_away_missions(user) || SSticker.current_state != starting_state || SSjob.away_mission_limits != old_limits)
		return

	var/list/new_limits
	var/summary
	switch(action)
		if("Автоматический выбор")
			summary = "включил автоматический выбор авеек"
		if("Отключить все")
			new_limits = list()
			summary = "отключил все авейки. Существующие корабли остаются в раунде"
		else
			var/list/choices = list()
			for(var/datum/roundstart_away_mission/mission as anything in roundstart_away_missions())
				var/limit = mission.get_instance_limit()
				if(action != "Загрузить корабли" || limit)
					choices["[mission.name] — лимит [limit]"] = mission
			if(!length(choices))
				to_chat(user, span_notice("Включите хотя бы одну авейку, чтобы загрузить корабль."), confidential = TRUE)
				return
			var/choice = tgui_input_list(user, "Выберите миссию.", "Спавн авеек", choices)
			var/datum/roundstart_away_mission/mission = choices[choice]
			if(!mission || !SSjob.can_manage_away_missions(user) || SSticker.current_state != starting_state || SSjob.away_mission_limits != old_limits)
				return
			if(action == "Загрузить корабли")
				mission.admin_load_ships(user)
				return

			var/count = tgui_input_number(user, "Укажите предел числа кораблей. Ноль отключает миссию. В ручном режиме доступны только явно включённые миссии.", mission.name, mission.get_instance_limit(), MAX_AWAY_MISSION_COPIES, 0)
			if(!ISINTEGER(count) || count < 0 || count > MAX_AWAY_MISSION_COPIES || !SSjob.can_manage_away_missions(user) || SSticker.current_state != starting_state || SSjob.away_mission_limits != old_limits)
				return
			new_limits = old_limits?.Copy() || list()
			if(count)
				new_limits[mission.type] = count
			else
				new_limits -= mission.type
			summary = "установил лимит «[mission.name]» на [count]"

	SSjob.away_mission_limits = new_limits
	SSjob.update_away_job_capacity()
	log_admin("[key_name(user)] [summary].")
	message_admins("[key_name_admin(user)] [summary].")

/** Load additional allowed copies by request and report partial failure to the admin. */
/datum/roundstart_away_mission/proc/admin_load_ships(client/administrator)
	if(!SSjob.can_manage_away_missions(administrator) || !SSticker.IsRoundInProgress())
		return
	var/available = get_instance_limit() - length(get_loaded_ships())
	if(available <= 0)
		to_chat(administrator, span_notice("Достигнут лимит кораблей «[name]»."), confidential = TRUE)
		return
	var/count = tgui_input_number(administrator, "Сколько дополнительных кораблей загрузить сейчас?", name, 1, available, 1)
	if(!ISINTEGER(count) || count < 1 || count > available || !SSjob.can_manage_away_missions(administrator) || !SSticker.IsRoundInProgress())
		return
	var/admin_name = key_name(administrator)
	var/admin_label = key_name_admin(administrator)
	var/list/loaded_ids = list()
	var/datum/callback/check = CALLBACK(src, PROC_REF(validate_admin_away_spawn), administrator)
	for(var/index in 1 to count)
		if(!SSjob.can_manage_away_missions(administrator) || !SSticker.IsRoundInProgress() || length(get_loaded_ships()) >= get_instance_limit())
			break
		var/obj/docking_port/mobile/stationtrauma_space/vessel
		try
			vessel = SSstationtrauma_space_voyage.load_ship_template(map_path, check, new_instance = TRUE)
		catch(var/exception/failure)
			log_mapping("Admin away mission [name] failed to load: [failure]")
		if(QDELETED(vessel))
			break
		loaded_ids += vessel.shuttle_id
	if(length(loaded_ids))
		log_admin("[admin_name] загрузил корабли «[name]»: [jointext(loaded_ids, ", ")].")
		message_admins("[admin_label] загрузил кораблей «[name]»: [length(loaded_ids)].")
	if(length(loaded_ids) < count && check_rights_for(administrator, R_ADMIN))
		to_chat(administrator, span_warning("Загружено кораблей: [length(loaded_ids)] из [count]. Проверьте лимит, готовность овермапа и журнал загрузки карт."), confidential = TRUE)

/** Recheck authorization and the live limit after native map loading has yielded. */
/datum/roundstart_away_mission/proc/validate_admin_away_spawn(client/administrator, obj/docking_port/mobile/stationtrauma_space/vessel)
	return SSjob.can_manage_away_missions(administrator) && SSticker.IsRoundInProgress() && length(get_loaded_ships()) <= get_instance_limit() && find_latejoin_spawn(vessel)

#undef MAX_AWAY_MISSION_COPIES
