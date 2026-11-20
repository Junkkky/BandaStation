/// A heavy lever owns a direct reference to one event gateway, never a station gateway.
/obj/structure/gate_closure_lever
	name = "тугой рычаг гейта"
	desc = "Старый рычаг сопротивляется каждому движению. Нужно тянуть непрерывно тридцать секунд."
	icon = 'modular_bandastation/gate_closure/icons/rusty_lever.dmi'
	icon_state = "left"
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE
	/// Gateway controlled by this lever.
	var/obj/machinery/gateway/gate_closure/gateway
	/// Prevent parallel attempts from accelerating the scene.
	var/busy = FALSE
	/// Looping creak while someone is pulling; stopped when the pull ends.
	var/creak_timer

/obj/structure/gate_closure_lever/Destroy()
	deltimer(creak_timer)
	if(gateway?.lever == src)
		gateway.lever = null
	gateway = null
	return ..()

/obj/structure/gate_closure_lever/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || busy || !isliving(user) || user.incapacitated || !user.Adjacent(src) || QDELETED(gateway))
		return
	busy = TRUE
	playsound(src, 'sound/machines/lever/lever_start.ogg', 50, FALSE)
	creak_timer = addtimer(CALLBACK(src, PROC_REF(creak)), 3 SECONDS, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	var/completed = do_after(user, 30 SECONDS, target = src, timed_action_flags = IGNORE_SLOWDOWNS)
	if(QDELETED(src))
		return
	deltimer(creak_timer)
	creak_timer = null
	if(completed && !QDELETED(gateway) && user.Adjacent(src))
		gateway.switch_route(user)
		icon_state = gateway.target ? "right" : "left"
		playsound(src, 'sound/machines/lever/lever_stop.ogg', 50, FALSE)
	busy = FALSE

/// The rusty mechanism groans throughout the long pull, so everyone nearby hears the attempt.
/obj/structure/gate_closure_lever/proc/creak()
	playsound(src, pick('sound/effects/creak/creak1.ogg', 'sound/effects/creak/creak2.ogg', 'sound/effects/creak/creak3.ogg'), 60, TRUE)
