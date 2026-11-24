GLOBAL_LIST_EMPTY(used_away_ship_names)

/obj/docking_port/mobile/stationtrauma_space
	/// The registered short name used by this mission's transponder.
	var/away_ship_name
	/// A ship grants this right only on its first successful boarding.
	var/away_crew_boarded = FALSE
	/// The original commander may file one new name with the registry.
	var/datum/weakref/away_naming_commander

/// Register the first crew arrival, including the roundstart crew arriving together.
/obj/docking_port/mobile/stationtrauma_space/proc/note_first_away_boarding(datum/mind/commander)
	if(away_crew_boarded)
		return
	away_crew_boarded = TRUE
	away_naming_commander = commander ? WEAKREF(commander) : null

/// Only the original commander can change the registration while holding a seat on this hull.
/obj/docking_port/mobile/stationtrauma_space/proc/can_name_away_ship(datum/mind/commander)
	if(QDELETED(commander) || commander != away_naming_commander?.resolve() || commander.away_mission_ship?.resolve() != src)
		return FALSE
	var/datum/roundstart_away_mission/mission = away_mission_for_template(source_template)
	return mission?.commander_job && commander.assigned_role?.type == mission.commander_job

/// Register a valid and unused callsign, leaving the commander able to retry a rejected name.
/obj/docking_port/mobile/stationtrauma_space/proc/rename_away_ship(datum/mind/commander, new_name)
	if(!can_name_away_ship(commander) || !istext(new_name))
		return FALSE
	new_name = trim(new_name)
	var/static/regex/invalid_name = regex(@"[^a-zA-Zа-яА-ЯёЁ0-9 -]")
	if(!length_char(new_name) || length_char(new_name) > MAX_NAME_LEN || invalid_name.Find(new_name) || !filter_name_ic(new_name) || !register_away_ship_name(new_name))
		return FALSE
	away_naming_commander = null
	return TRUE

/// Draw a name without replacement, with fresh registry numbers if the pool is exhausted.
/obj/docking_port/mobile/stationtrauma_space/proc/draw_away_ship_name(list/names)
	for(var/candidate in shuffle(names))
		if(register_away_ship_name(candidate))
			return
	var/static/last_registry_number = 0
	do
		last_registry_number++
	while(!register_away_ship_name("Патруль-[last_registry_number]"))

/// Reserve the name for the round and update the hull and its factory transponder together.
/obj/docking_port/mobile/stationtrauma_space/proc/register_away_ship_name(new_name)
	var/registry_key = lowertext(new_name)
	if(GLOB.used_away_ship_names[registry_key])
		return FALSE

	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in SSshuttle.mobile_docking_ports)
		if(vessel == src || QDELETED(vessel))
			continue
		if(lowertext(vessel.name) == registry_key)
			return FALSE
		for(var/obj/machinery/computer/stationtrauma_transponder/transponder as anything in vessel.transponders)
			var/obj/item/circuitboard/computer/stationtrauma_transponder/board = transponder.circuit
			if(istype(board) && lowertext(board.callsign) == registry_key)
				return FALSE

	GLOB.used_away_ship_names[registry_key] = TRUE
	away_ship_name = new_name
	name = "ОКН «[new_name]»"
	for(var/obj/machinery/computer/stationtrauma_transponder/nt_patrol/transponder in transponders)
		var/obj/item/circuitboard/computer/stationtrauma_transponder/nt/patrol/board = transponder.circuit
		if(istype(board) && board.loc == transponder)
			board.callsign = new_name
	return TRUE

/// Mark a successful latejoin at character creation, before starting equipment or UI can yield.
/datum/job/away_mission/proc/note_away_latejoin(datum/mind/arrival)
	var/obj/docking_port/mobile/stationtrauma_space/vessel = arrival.away_mission_ship?.resolve()
	if(!vessel)
		return
	var/datum/roundstart_away_mission/mission = get_away_mission()
	vessel.note_first_away_boarding(type == mission?.commander_job ? arrival : null)

/obj/machinery/computer/stationtrauma_transponder/nt_patrol/ui_data(mob/user)
	. = ..()
	.["can_name_ship"] = can_register_ship_name(user)

/obj/machinery/computer/stationtrauma_transponder/nt_patrol/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	var/mob/user = ui?.user
	if(. || action != "name_ship" || !can_register_ship_name(user))
		return
	var/obj/docking_port/mobile/stationtrauma_space/original_vessel = vessel
	var/obj/item/circuitboard/computer/stationtrauma_transponder/original_board = circuit
	var/datum/ui_state/overmap_console_prompt/prompt_state = new(src)
	var/new_name = tgui_input_text(user, "Введите название. Можно использовать буквы, цифры, пробел и дефис.", "Название судна", max_length = MAX_NAME_LEN, encode = FALSE, timeout = 30 SECONDS, ui_state = prompt_state)
	qdel(prompt_state)
	if(!new_name || QDELETED(src) || vessel != original_vessel || circuit != original_board || !can_register_ship_name(user))
		return FALSE
	if(!vessel.rename_away_ship(user.mind, new_name))
		to_chat(user, span_warning("Название уже использовалось в этом раунде или содержит недопустимые символы."))
		return FALSE
	log_game("Away mission [vessel.shuttle_id] registered as [vessel.name] by [key_name(user)].")
	to_chat(user, span_notice("Название зарегистрировано: [vessel.name]."))
	return TRUE

/// Preserve the roundstart authorization and recheck the physical console after the prompt.
/obj/machinery/computer/stationtrauma_transponder/nt_patrol/proc/can_register_ship_name(mob/user)
	if(QDELETED(user) || QDELETED(vessel) || !vessel.can_name_away_ship(user.mind))
		return FALSE
	var/obj/item/circuitboard/computer/stationtrauma_transponder/nt/patrol/board = circuit
	return istype(board) && board.loc == src && is_operational && !panel_open && vessel.is_in_shuttle_bounds(src) && Adjacent(user) && can_interact(user)
