/** Event preparation; responds to lifecycle signals and never processes each tick. */
SUBSYSTEM_DEF(stationtrauma_training)
	name = "Character skills"
	ss_flags = SS_NO_FIRE
	/// Enabled by default; administrators may suspend preparation for a particular round.
	var/enabled = TRUE
	/// Invalidates lobby dialogs when the event setting changes.
	var/revision = 0

/datum/controller/subsystem/stationtrauma_training/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, PROC_REF(client_connected))
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(crew_joined))
	for(var/client/player as anything in GLOB.clients)
		client_connected(SSdcs, player)
	return SS_INIT_SUCCESS

/** Toggle editing, future joins and skill effects; existing minds retain their allocated levels. */
/datum/controller/subsystem/stationtrauma_training/proc/set_enabled(new_enabled)
	if(enabled == new_enabled)
		return
	enabled = new_enabled
	revision++
	for(var/client/player as anything in GLOB.clients)
		refresh_verbs(player)

/** Verify a modal still belongs to the same lobby, character slot and event session. */
/datum/controller/subsystem/stationtrauma_training/proc/can_edit(client/player, mob/dead/new_player/lobby, slot, expected_revision)
	if(!enabled || revision != expected_revision || !player?.prefs || !isnewplayer(lobby) || player.mob != lobby)
		return FALSE
	return !lobby.spawning && player.prefs.default_slot == slot

/** Subscribe once per connection; the native login signal also covers mind/body changes. */
/datum/controller/subsystem/stationtrauma_training/proc/client_connected(datum/source, client/player)
	SIGNAL_HANDLER
	RegisterSignal(player, COMSIG_CLIENT_MOB_LOGIN, PROC_REF(client_logged_in))
	refresh_verbs(player)

/** Recompute only the expedition's commands when the client's mob changes. */
/datum/controller/subsystem/stationtrauma_training/proc/client_logged_in(client/player)
	SIGNAL_HANDLER
	refresh_verbs(player)

/** Character editing lives in preferences; the round command only inspects prepared minds. */
/datum/controller/subsystem/stationtrauma_training/proc/refresh_verbs(client/player)
	if(player.mob?.mind?.GetComponent(/datum/component/stationtrauma_training))
		ASSIGN_GAME_VERB(player, /client, stationtrauma_training_show)
	else
		UNASSIGN_GAME_VERB(player, /client, stationtrauma_training_show)

/** Consume the spawning character snapshot only after its mind and assigned role exist. */
/datum/controller/subsystem/stationtrauma_training/proc/crew_joined(datum/source, mob/living/crew)
	SIGNAL_HANDLER
	if(!ishuman(crew))
		return
	var/mob/living/carbon/human/human = crew
	var/list/saved = human.stationtrauma_pending_training
	human.stationtrauma_pending_training = null
	if(!enabled || !crew.mind || crew.mind.GetComponent(/datum/component/stationtrauma_training))
		return
	for(var/profile_id in GLOB.stationtrauma_training_profiles)
		var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
		if(!profile.job_type || crew.mind.assigned_role?.type != profile.job_type)
			continue
		var/list/levels = saved?[profile_id]
		if(profile.allocation_error(levels))
			levels = profile.starting_levels()
		crew.mind.AddComponent(/datum/component/stationtrauma_training, profile_id, levels)
		break
	if(crew.client)
		refresh_verbs(crew.client)

GAME_VERB_PROC(/client, stationtrauma_training_show, "Мои навыки", "Персонаж")
	var/datum/component/stationtrauma_training/training = mob?.mind?.GetComponent(/datum/component/stationtrauma_training)
	if(!training)
		return
	var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[training.profile_id]
	var/list/lines = list("<b>[profile.name]</b>", "Навыки персонажа; опыт ТГ учитывается отдельно.")
	for(var/skill_id in GLOB.stationtrauma_training_skills)
		var/datum/stationtrauma_training_skill/skill = GLOB.stationtrauma_training_skills[skill_id]
		lines += "[skill.name]: [GLOB.stationtrauma_training_levels[training.get_level(skill_id)]]"
	to_chat(src, span_notice(lines.Join("<br>")))

ADMIN_VERB(stationtrauma_training_event, R_ADMIN, "Character Skills", "Enable character skills and their effects.", ADMIN_CATEGORY_EVENTS)
	var/action = tgui_alert(user, "Навыки [SSstationtrauma_training.enabled ? "включены" : "выключены"]. Переключает редактор и влияние навыков на действия. Уже выданные уровни сохраняются.", "Навыки", list("Включить", "Выключить", "Отмена"))
	if(!user?.holder?.check_for_rights(R_ADMIN) || !(action in list("Включить", "Выключить")))
		return
	SSstationtrauma_training.set_enabled(action == "Включить")
	log_admin("[key_name(user)] set expedition preparation to [SSstationtrauma_training.enabled].")
	message_admins("[key_name_admin(user)] set expedition preparation to [SSstationtrauma_training.enabled].")

ADMIN_VERB_AND_CONTEXT_MENU(stationtrauma_training_assign, R_ADMIN, "Set Character Skills", "Assign or remove a character skill profile.", ADMIN_CATEGORY_EVENTS, /mob/living)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_WORLD, /mob/living)
	var/datum/mind/mind = target?.mind
	if(!mind)
		return
	var/list/profiles = list("Убрать навыки")
	for(var/profile_id in GLOB.stationtrauma_training_profiles)
		var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
		profiles[profile.name] = profile_id
	var/chosen = tgui_input_list(user, "Выбранный профиль заменит навыки этого персонажа. При наличии игрока берётся настройка его текущего слота, иначе — начальные уровни.", "[target.real_name]: навыки", profiles)
	if(!user?.holder?.check_for_rights(R_ADMIN) || QDELETED(target) || QDELETED(mind) || target.mind != mind || !(chosen in profiles))
		return
	var/profile_id = profiles[chosen]
	var/datum/component/stationtrauma_training/old_training = mind.GetComponent(/datum/component/stationtrauma_training)
	if(chosen == "Убрать навыки")
		qdel(old_training)
	else
		var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
		var/list/saved = target.client?.prefs.read_preference(/datum/preference/stationtrauma_training)
		var/list/levels = saved?[profile_id]
		if(profile.allocation_error(levels))
			levels = profile.starting_levels()
		qdel(old_training)
		mind.AddComponent(/datum/component/stationtrauma_training, profile_id, levels)
	if(target.client)
		SSstationtrauma_training.refresh_verbs(target.client)
	to_chat(target, span_notice("Ведущий изменил навыки персонажа: [chosen]."))
	log_admin("[key_name(user)] set [key_name(target)] expedition preparation to [chosen].")
	message_admins("[key_name_admin(user)] set [key_name_admin(target)] expedition preparation to [chosen].")
