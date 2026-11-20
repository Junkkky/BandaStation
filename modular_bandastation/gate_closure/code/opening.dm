GLOBAL_VAR_INIT(event_gateway_opening, FALSE)
GLOBAL_VAR_INIT(event_gateway_opened, FALSE)

/// These portals only decorate the director's transfer; touching them cannot move anyone.
/obj/effect/portal/event_boss/opening
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/portal/event_boss/opening/teleport(atom/movable/moving, force = FALSE)
	return FALSE

/// CheckboxInput submits [label, original index] pairs, not plain labels.
/datum/tgui_checkbox_input/event_gateway/set_choices(list/selections)
	var/list/labels = list()
	for(var/list/choice as anything in selections)
		if(!islist(choice) || length(choice) != 2 || !istext(choice[1]) || !isnum(choice[2]))
			continue
		var/index = choice[2]
		if(index != round(index) || index < 1 || index > length(items) || items[index] != choice[1])
			continue
		labels |= choice[1]
	return ..(labels)

ADMIN_VERB(event_gateway_opening, R_FUN, "Gate Closure - Открытие гейта", "Выбрать игроков и запустить открытие гейта с переносом на пляж.", ADMIN_CATEGORY_EVENTS)
	var/obj/machinery/gateway/centerstation/gateway = GLOB.the_gateway
	if(QDELETED(gateway) || SSmapping.current_map.map_name != "Cyberiad Gate Closure" || GLOB.event_gateway_opening || GLOB.event_gateway_opened)
		to_chat(user, span_warning("Открытие гейта сейчас недоступно."), confidential = TRUE)
		return
	var/list/candidates = list()
	var/list/candidate_keys = list()
	for(var/mob/living/player in GLOB.mob_living_list)
		var/turf/player_location = get_turf(player)
		if(player.stat == DEAD || !is_station_level(player_location?.z))
			continue
		candidates["[length(candidates) + 1]. [player.real_name] ([player.ckey || "без игрока"])"] = WEAKREF(player)
		candidate_keys[WEAKREF(player)] = player.ckey
	if(!length(candidates))
		to_chat(user, span_warning("На станции нет подходящих персонажей."), confidential = TRUE)
		return
	// Use the checkbox window directly: the native-input fallback only allows one player.
	var/datum/tgui_checkbox_input/event_gateway/selection = new(user.mob, "Выберите персонажей для переноса. Куклы без игрока тоже доступны.", "Открытие гейта", assoc_to_keys(candidates), 1, length(candidates), 0, GLOB.always_state)
	selection.ui_interact(user.mob)
	selection.wait()
	var/list/choices = selection?.choices?.Copy()
	QDEL_NULL(selection)
	if(!length(choices) || !check_rights_for(user, R_FUN))
		return
	var/list/selected = list()
	for(var/choice in choices)
		if(!istext(choice) || !(choice in candidates))
			continue
		var/datum/weakref/body = candidates[choice]
		if(istype(body))
			var/mob/living/player = body.resolve()
			if(!QDELETED(player) && player.ckey == candidate_keys[body])
				selected[body] = player.ckey
	if(!length(selected) || tgui_alert(user, "Выбрано персонажей: [length(selected)]. Через 15 секунд тряски они окажутся на пляже, а гейт начнёт бить током входящих.", "Открытие гейта", list("Start", "Cancel")) != "Start")
		return
	if(!check_rights_for(user, R_FUN) || QDELETED(gateway) || gateway != GLOB.the_gateway || SSmapping.current_map.map_name != "Cyberiad Gate Closure")
		return
	if(!gateway.start_event_opening(user, selected))
		to_chat(user, span_warning("Не удалось начать открытие: проверьте питание гейта и доступность пляжа. Повторное открытие после завершения недоступно."), confidential = TRUE)

/// Reserves a single opening, then runs the scene without blocking the admin verb.
/obj/machinery/gateway/centerstation/proc/start_event_opening(client/director, list/selected)
	if(!check_rights_for(director, R_FUN) || src != GLOB.the_gateway || SSmapping.current_map.map_name != "Cyberiad Gate Closure" || GLOB.event_gateway_opening || GLOB.event_gateway_opened || !powered())
		return FALSE
	var/datum/gateway_destination/point/beach
	for(var/datum/gateway_destination/point/point in GLOB.gateway_destinations)
		if(point.id == AWAYSTART_BEACH && length(point.target_turfs))
			beach = point
			break
	if(!beach || !length(selected))
		return FALSE
	var/list/landings = list()
	var/area/beach_area = get_area(beach.target_turfs[1])
	for(var/turf/open/misc/beach/sand/landing in beach_area)
		if(!landing.is_blocked_turf())
			landings += landing
	if(length(landings) < length(selected))
		to_chat(director, span_warning("Недостаточно свободных точек на пляже."), confidential = TRUE)
		return FALSE
	GLOB.event_gateway_opening = TRUE
	if(target)
		deactivate()
	update_appearance()
	log_admin("[key_name(director)] started the event gateway opening for [length(selected)] selected bodies.")
	message_admins("[key_name_admin(director)] запустил открытие гейта: выбрано [length(selected)] тел.")
	INVOKE_ASYNC(src, PROC_REF(run_event_opening), director, selected.Copy(), landings)
	return TRUE

/// Eight harmless tremors over fifteen seconds, then transfer only the chosen bodies.
/obj/machinery/gateway/centerstation/proc/run_event_opening(client/director, list/selected, list/landings)
	var/obj/effect/portal/event_boss/opening/visual = new(get_turf(src), 16 SECONDS)
	INVOKE_ASYNC(src, PROC_REF(event_opening_blackout))
	for(var/pulse in 1 to 8)
		if(QDELETED(src) || src != GLOB.the_gateway || !check_rights_for(director, R_FUN))
			break
		for(var/mob/living/person in GLOB.mob_living_list)
			var/turf/person_location = get_turf(person)
			if(person.stat == DEAD || !is_station_level(person_location?.z))
				continue
			shake_camera(person, 2 SECONDS, 1)
			// The native distant-explosion pair, played locally so the whole station hears the same muffled rumble.
			// Only the first five tremors boom: with the sound tails that is about ten of the fifteen seconds.
			if(pulse <= 5)
				person.playsound_local(person_location, pick('sound/effects/explosion/explosionfar.ogg', 'sound/effects/explosion/explosion_distant.ogg'), 60, TRUE)
			person.Knockdown(2 SECONDS, ignore_canstun = TRUE)
		sleep(pulse == 8 ? 1 SECONDS : 2 SECONDS)
	if(QDELETED(src) || src != GLOB.the_gateway || !check_rights_for(director, R_FUN))
		QDEL_NULL(visual)
		GLOB.event_gateway_opening = FALSE
		if(!QDELETED(src))
			if(GLOB.event_gateway_red)
				activate(GLOB.event_gateway_shock)
			update_appearance()
		return
	var/transferred = 0
	for(var/datum/weakref/body as anything in selected)
		var/mob/living/player = body.resolve()
		var/turf/player_location = get_turf(player)
		if(QDELETED(player) || player.ckey != selected[body] || player.stat == DEAD || !is_station_level(player_location?.z))
			continue
		var/turf/landing
		while(length(landings))
			landing = pick_n_take(landings)
			if(!landing.is_blocked_turf())
				break
			landing = null
		if(!landing)
			break
		new /obj/effect/portal/event_boss/opening(get_turf(player), 3 SECONDS)
		new /obj/effect/portal/event_boss/opening(landing, 3 SECONDS)
		player.buckled?.unbuckle_mob(player, force = TRUE)
		player.forceMove(landing)
		player.Knockdown(4 SECONDS, ignore_canstun = TRUE)
		transferred++
	QDEL_NULL(visual)
	GLOB.event_gateway_opened = TRUE
	GLOB.event_gateway_opening = FALSE
	GLOB.event_gateway_red = TRUE
	GLOB.event_gateway_previous = null
	activate(GLOB.event_gateway_shock)
	update_appearance()
	log_admin("Event gateway opening finished: [transferred]/[length(selected)] bodies transferred; the station gateway now shocks anyone entering.")
	message_admins("Открытие гейта завершено: перенесено [transferred]/[length(selected)] тел. Гейт теперь бьёт током.")

/// The station goes dark a second into the opening and stays dark until just after the transfer; APCs restore themselves.
/obj/machinery/gateway/centerstation/proc/event_opening_blackout()
	sleep(1 SECONDS)
	if(QDELETED(src) || !GLOB.event_gateway_opening)
		return
	power_fail(15, 15)

/obj/machinery/gateway/centerstation/process()
	. = ..()
	if(src == GLOB.the_gateway && GLOB.event_gateway_opened && GLOB.event_gateway_red && !target && powered())
		activate(GLOB.event_gateway_shock)

/// Activation and deactivation must not re-enable APC consumption on the event map.
/obj/machinery/gateway/centerstation/update_use_power(new_use_power)
	if(SSmapping.current_map.map_name == "Cyberiad Gate Closure")
		new_use_power = NO_POWER_USE
	return ..(new_use_power)
