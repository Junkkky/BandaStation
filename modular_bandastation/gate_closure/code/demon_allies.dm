ADMIN_VERB(gate_closure_demon_ally, R_FUN, "Gate Closure - Свой для демонов", "Сделать выбранного моба своим для демонов редспейса или снять это.", ADMIN_CATEGORY_EVENTS)
	var/list/candidates = list()
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		var/turf/position = get_turf(candidate)
		if(QDELETED(candidate) || !position || istype(candidate, /mob/living/basic/demon))
			continue
		var/label = "[candidate.has_faction(FACTION_HELL) ? "(свой) " : ""][candidate.real_name || candidate.name][candidate.ckey ? " ([candidate.ckey])" : ""] — [get_area_name(position, TRUE)]"
		if(label in candidates)
			label = "[label] [REF(candidate)]"
		candidates[label] = WEAKREF(candidate)
	var/choice = tgui_input_list(user, "Отмеченные (свой) уже свои для демонов. Выбор переключает состояние. Есть поиск.", "Свой для демонов", candidates)
	if(isnull(choice) || !check_rights_for(user, R_FUN))
		return
	var/datum/weakref/candidate_ref = candidates[choice]
	var/mob/living/target = candidate_ref?.resolve()
	if(QDELETED(target))
		to_chat(user, span_warning("Этот моб больше недоступен."), confidential = TRUE)
		return
	var/now_ally = !target.has_faction(FACTION_HELL)
	if(now_ally)
		target.add_faction(FACTION_HELL)
	else
		target.remove_faction(FACTION_HELL)
	log_admin("[key_name(user)] [now_ally ? "made [key_name(target)] an ally of" : "removed [key_name(target)] from the allies of"] redspace demons.")
	message_admins("[key_name_admin(user)] [now_ally ? "сделал [ADMIN_LOOKUPFLW(target)] своим для" : "снял с [ADMIN_LOOKUPFLW(target)] статус своего для"] демонов.")
