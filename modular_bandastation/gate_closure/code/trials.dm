GLOBAL_VAR_INIT(event_gateway_red, FALSE)
GLOBAL_DATUM(event_gateway_previous, /datum/gateway_destination)
GLOBAL_DATUM_INIT(event_gateway_shock, /datum/gateway_destination/event_shock, new)

/// Event-only destination behind the red station gateway, never inserted in the selectable station catalogue.
/// Nobody passes: whoever steps in is shocked and thrown back.
/datum/gateway_destination/event_shock
	name = "Красный гейт"
	hidden = TRUE

/datum/gateway_destination/event_shock/get_target_turf()
	return null

/datum/gateway_destination/event_shock/incoming_pass_check(atom/movable/traveller)
	var/obj/machinery/gateway/centerstation/gateway = GLOB.the_gateway
	if(QDELETED(gateway) || !isliving(traveller))
		return FALSE
	var/mob/living/victim = traveller
	do_sparks(5, TRUE, gateway)
	victim.electrocute_act(20, gateway)
	victim.throw_at(get_ranged_target_turf(victim, gateway.dir, 3), 3, 2)
	log_combat(gateway, victim, "shocked away from the red event gateway")
	return FALSE

/// Set by an administrator: the station gateway stays dark and its console does nothing.
GLOBAL_VAR_INIT(event_gateway_disabled, FALSE)

/// Pressing Activate on the event console turns the gateway red: lightning strikes those around it,
/// and from then on only an administrator can switch it off.
/obj/machinery/gateway/centerstation/proc/event_console_activation(mob/user)
	if(GLOB.event_gateway_disabled || GLOB.event_gateway_red || GLOB.event_gateway_opening)
		return
	GLOB.event_gateway_previous = null
	GLOB.event_gateway_red = TRUE
	if(target)
		deactivate()
	activate(GLOB.event_gateway_shock)
	update_appearance()
	event_lightning(4, strike_people = TRUE)
	log_admin("[key_name(user)] activated the event station gateway; it turned red.")
	message_admins("[key_name_admin(user)] нажал Activate: станционный гейт стал красным и бьёт молниями.")

/// Short lightning arcs from the gateway; on activation they also strike everyone standing close by.
/obj/machinery/gateway/centerstation/proc/event_lightning(arcs, strike_people = FALSE)
	var/turf/origin = get_turf(src)
	if(!origin)
		return
	playsound(origin, 'sound/effects/magic/lightningbolt.ogg', strike_people ? 80 : 40, TRUE)
	do_sparks(strike_people ? 5 : 2, TRUE, src)
	if(strike_people)
		for(var/mob/living/victim in range(3, origin))
			if(victim.stat == DEAD)
				continue
			origin.Beam(victim, icon_state = "lightning[rand(1, 12)]", time = 0.5 SECONDS)
			victim.electrocute_act(15, src)
	var/list/turf/targets = list()
	for(var/turf/open/arc_target in range(3, origin))
		if(arc_target != origin)
			targets += arc_target
	for(var/arc in 1 to min(arcs, length(targets)))
		origin.Beam(pick_n_take(targets), icon_state = "lightning[rand(1, 12)]", time = 0.4 SECONDS)

/// The red gateway keeps crackling while it stands open.
/obj/machinery/gateway/centerstation/process(seconds_per_tick)
	. = ..()
	if(src == GLOB.the_gateway && target == GLOB.event_gateway_shock && SPT_PROB(20, seconds_per_tick))
		event_lightning(2)

ADMIN_VERB(event_gateway_power, R_FUN, "Gate Closure - Выключить / включить гейт", "Полностью выключить станционный гейт (и его консоль) или включить обратно.", ADMIN_CATEGORY_EVENTS)
	var/obj/machinery/gateway/centerstation/gateway = GLOB.the_gateway
	if(QDELETED(gateway) || SSmapping.current_map.map_name != "Cyberiad Gate Closure")
		to_chat(user, span_warning("Ивентовый станционный гейт недоступен."), confidential = TRUE)
		return
	if(GLOB.event_gateway_opening)
		to_chat(user, span_warning("Идёт открытие гейта, дождитесь переноса."), confidential = TRUE)
		return
	GLOB.event_gateway_disabled = !GLOB.event_gateway_disabled
	if(GLOB.event_gateway_disabled)
		GLOB.event_gateway_red = FALSE
		GLOB.event_gateway_previous = null
		if(gateway.target)
			gateway.deactivate()
	gateway.update_appearance()
	log_admin("[key_name(user)] [GLOB.event_gateway_disabled ? "disabled" : "enabled"] the event station gateway.")
	message_admins("[key_name_admin(user)] [GLOB.event_gateway_disabled ? "полностью выключил" : "снова включил"] станционный гейт.")

ADMIN_VERB(event_gateway_trial, R_FUN, "Gate Closure - Красный гейт", "Переключить станционный гейт между обычным маршрутом и красным режимом: вход бьёт током.", ADMIN_CATEGORY_EVENTS)
	if(GLOB.event_gateway_opening || GLOB.event_gateway_opened)
		to_chat(user, span_warning("Во время и после открытия гейта обычный маршрут закрыт."), confidential = TRUE)
		return
	var/obj/machinery/gateway/centerstation/gateway = GLOB.the_gateway
	if(!gateway || SSmapping.current_map.map_name != "Cyberiad Gate Closure")
		to_chat(user, span_warning("Ивентовый станционный гейт недоступен."), confidential = TRUE)
		return
	if(!check_rights_for(user, R_FUN) || QDELETED(gateway) || gateway != GLOB.the_gateway || GLOB.event_gateway_opening || GLOB.event_gateway_opened)
		return
	if(GLOB.event_gateway_red)
		GLOB.event_gateway_red = FALSE
		if(gateway.target)
			gateway.deactivate()
		if(GLOB.event_gateway_previous?.is_available())
			gateway.activate(GLOB.event_gateway_previous)
		GLOB.event_gateway_previous = null
	else
		GLOB.event_gateway_previous = gateway.target
		if(gateway.target)
			gateway.deactivate()
		GLOB.event_gateway_red = TRUE
		gateway.activate(GLOB.event_gateway_shock)
	gateway.update_appearance()
	log_admin("[key_name(user)] set event gateway red mode to [GLOB.event_gateway_red].")
	message_admins("[key_name_admin(user)] set event gateway red mode to [GLOB.event_gateway_red].")

/obj/machinery/gateway/centerstation/activate(datum/gateway_destination/destination)
	if(GLOB.event_gateway_opening || GLOB.event_gateway_disabled)
		return
	if(GLOB.event_gateway_red)
		destination = GLOB.event_gateway_shock
	return ..(destination)

/obj/machinery/gateway/centerstation/update_overlays()
	. = ..()
	if(GLOB.event_gateway_opening)
		. += show_light_overlays("portal_effect", TRUE)
		for(var/mutable_appearance/overlay as anything in .)
			if(findtext(overlay.icon_state, "portal_effect") && overlay.color != GLOB.emissive_color)
				overlay.color = "#e52b87"
		return
	if(GLOB.event_gateway_red)
		for(var/mutable_appearance/overlay as anything in .)
			if(findtext(overlay.icon_state, "portal_effect") && overlay.color != GLOB.emissive_color)
				overlay.color = COLOR_RED
