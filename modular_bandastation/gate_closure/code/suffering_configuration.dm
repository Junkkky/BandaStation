#define SUFFERING_SEALED 0
#define SUFFERING_AWAKENING 1
#define SUFFERING_AWAKE 2

/// The event's puzzle box: sealed on its altar, the first touch lifts and opens it, the second lets someone take it.
/obj/item/gate_closure_suffering
	name = "Конфигурация страданий"
	desc = "Тяжёлая шкатулка из тёмного металла. Сквозь её швы сочится фиолетовый свет."
	icon = 'modular_bandastation/gate_closure/icons/suffering_configuration.dmi'
	icon_state = "sealed"
	// Held in place on the altar until it wakes: no pickup, pulling or telekinesis before that.
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	w_class = WEIGHT_CLASS_NORMAL
	light_color = "#d23cff"
	var/stage = SUFFERING_SEALED

/obj/item/gate_closure_suffering/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/gate_closure_suffering/attack_hand(mob/user, list/modifiers)
	if(stage == SUFFERING_AWAKE)
		return ..()
	if(stage == SUFFERING_SEALED && isliving(user) && user.Adjacent(src))
		INVOKE_ASYNC(src, PROC_REF(awaken), user)
	return TRUE

/// Rise, open with a burst of light and lightning, then hover until taken.
/obj/item/gate_closure_suffering/proc/awaken(mob/living/user)
	stage = SUFFERING_AWAKENING
	log_game("[key_name(user)] woke [src] at [AREACOORD(src)].")
	message_admins("[ADMIN_LOOKUPFLW(user)] пробудил «[name]» [ADMIN_VERBOSEJMP(src)].")
	playsound(src, 'sound/effects/magic/lightningbolt.ogg', 40, TRUE)
	animate(src, pixel_z = 12, time = 1.5 SECONDS, easing = SINE_EASING | EASE_OUT)
	sleep(1.5 SECONDS)
	if(QDELETED(src) || stage != SUFFERING_AWAKENING || !isturf(loc))
		return
	flick("opening", src)
	icon_state = "open"
	playsound(src, 'modular_bandastation/bosses/gatekeeper/sounds/portal_open.ogg', 70, FALSE)
	sleep(1.2 SECONDS)
	if(QDELETED(src) || stage != SUFFERING_AWAKENING || !isturf(loc))
		return
	new /obj/effect/temp_visual/circle_wave/suffering(get_turf(src))
	for(var/mob/living/witness in viewers(7, src))
		shake_camera(witness, 1 SECONDS, 1)
	lightning(6)
	stage = SUFFERING_AWAKE
	anchored = FALSE
	set_light(3, 1.5)
	DO_FLOATING_ANIM(src)
	add_filter("suffering_glow", 2, list("type" = "outline", "color" = "#d23cff80", "size" = 1))
	animate(get_filter("suffering_glow"), size = 2.5, time = 1 SECONDS, loop = -1, easing = SINE_EASING)
	animate(size = 1, time = 1 SECONDS, easing = SINE_EASING)
	START_PROCESSING(SSobj, src)

/// Harmless arcs from the box to the floor around it.
/obj/item/gate_closure_suffering/proc/lightning(arcs)
	var/turf/origin = get_turf(src)
	var/list/turf/targets = list()
	for(var/turf/open/arc_target in range(3, origin))
		if(arc_target != origin)
			targets += arc_target
	for(var/arc in 1 to min(arcs, length(targets)))
		Beam(pick_n_take(targets), icon_state = "lightning[rand(1, 12)]", time = 0.4 SECONDS)
	playsound(origin, 'sound/effects/magic/lightningbolt.ogg', arcs > 2 ? 50 : 20, TRUE)

/obj/item/gate_closure_suffering/process(seconds_per_tick)
	if(!isturf(loc))
		return PROCESS_KILL
	if(SPT_PROB(35, seconds_per_tick))
		lightning(rand(1, 2))

/// Taken from the air, it settles in the hand and goes quiet.
/obj/item/gate_closure_suffering/pickup(mob/user)
	. = ..()
	if(stage != SUFFERING_AWAKE)
		return
	STOP_PROCESSING(SSobj, src)
	STOP_FLOATING_ANIM(src)
	remove_filter("suffering_glow")
	set_light(0)

/obj/effect/temp_visual/circle_wave/suffering
	color = "#e52b87"
	duration = 1 SECONDS
	amount_to_scale = 9

#undef SUFFERING_SEALED
#undef SUFFERING_AWAKENING
#undef SUFFERING_AWAKE
