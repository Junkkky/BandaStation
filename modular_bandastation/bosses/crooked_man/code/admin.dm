ADMIN_VERB(grant_crooked_phase, R_FUN, "Gate Closure - Фаза и порталы", "Выдать игроку пространственную фазу или порталы привратника, либо забрать их.", ADMIN_CATEGORY_EVENTS)
	var/static/list/abilities = list(
		"Пространственная фаза" = /datum/action/cooldown/spell/spatial_phase,
		"Порталы привратника" = /datum/action/cooldown/event_target/pinhead_portal,
	)
	var/ability_name = tgui_input_list(user, "Какую способность выдать или забрать?", "Способности Gate Closure", abilities)
	if(isnull(ability_name) || !check_rights_for(user, R_FUN))
		return
	var/ability_type = abilities[ability_name]
	var/list/candidates = list()
	for(var/mob/living/player in GLOB.player_list)
		if(player.client && player.stat != DEAD)
			var/has_ability = !!(locate(ability_type) in player.actions)
			candidates["[has_ability ? "(есть) " : ""][player.real_name] ([player.ckey])"] = player
	var/choice = tgui_input_list(user, "Отмеченные (есть) уже имеют способность; выбор забирает её. Есть поиск.", ability_name, candidates)
	if(isnull(choice) || !check_rights_for(user, R_FUN))
		return
	var/mob/living/recipient = candidates[choice]
	if(QDELETED(recipient) || !recipient.client || recipient.stat == DEAD || !(recipient in GLOB.player_list))
		to_chat(user, span_warning("Выбранный игрок больше недоступен."), confidential = TRUE)
		return
	var/datum/action/owned = locate(ability_type) in recipient.actions
	if(owned)
		qdel(owned)
		log_admin("[key_name(user)] removed [ability_name] from [key_name(recipient)].")
		message_admins("[key_name_admin(user)] забрал «[ability_name]» у [key_name_admin(recipient)].")
		return
	var/datum/action/granted = new ability_type(recipient)
	granted.Grant(recipient)
	log_admin("[key_name(user)] granted [ability_name] to [key_name(recipient)].")
	message_admins("[key_name_admin(user)] выдал «[ability_name]» [key_name_admin(recipient)].")
	if(ability_type == /datum/action/cooldown/spell/spatial_phase)
		to_chat(recipient, span_notice("Вы можете использовать пространственную фазу. Повторное нажатие вернёт вас обратно."))
	else
		to_chat(recipient, span_notice("Вы можете открывать порталы: выберите точку из списка, затем кликните, где откроется портал. Повторное нажатие закроет его."))
	BLACKBOX_LOG_ADMIN_VERB("Grant Gate Closure Ability")
