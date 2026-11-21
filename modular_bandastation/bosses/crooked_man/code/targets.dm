/// An eye or organ shielding the Crooked Man; shooting it down tears off a share of his health.
/obj/structure/crooked_target
	anchored = TRUE
	density = TRUE
	/// Boss it shields; cleared when either side is deleted.
	var/mob/living/basic/boss/crooked_man/boss
	/// Share of the boss's maximum health torn off when this is destroyed.
	var/health_cut = 0.08
	/// Size the borrowed 32px icon is drawn at.
	var/scale = 1.5
	/// How high it floats up and down, in pixels.
	var/hover_height = 4
	/// Time for one rise or one fall.
	var/hover_time = 1 SECONDS

/obj/structure/crooked_target/Initialize(mapload, mob/living/basic/boss/crooked_man/boss)
	. = ..()
	if(!istype(boss))
		return INITIALIZE_HINT_QDEL
	src.boss = boss
	boss.targets += src
	transform = matrix() * scale
	// Hovers above the floor, bobbing slowly.
	animate(src, pixel_z = hover_height, time = hover_time, loop = -1, easing = SINE_EASING)
	animate(pixel_z = 0, time = hover_time, easing = SINE_EASING)
	// His own blows and stomps must not break what shields him.
	RegisterSignal(src, COMSIG_ATOM_ATTACK_BASIC_MOB, PROC_REF(on_basic_attack))
	new /obj/effect/temp_visual/cult/sparks/crooked(loc)
	playsound(src, 'sound/effects/blob/blobattack.ogg', 60, TRUE)

/obj/structure/crooked_target/Destroy()
	boss?.targets -= src
	boss = null
	return ..()

/obj/structure/crooked_target/atom_destruction(damage_flag)
	boss?.target_destroyed(src)
	new /obj/effect/gibspawner/generic(get_turf(src))
	return ..()

/obj/structure/crooked_target/proc/on_basic_attack(datum/source, mob/user)
	SIGNAL_HANDLER
	if(user == boss)
		return COMSIG_BASIC_ATTACK_CANCEL_CHAIN

/// While any eye is open the Crooked Man takes half damage.
/obj/structure/crooked_target/eye
	name = "огромный глаз"
	desc = "Налитый кровью глаз парит над полом и неотрывно смотрит. Пока он открыт, Скрюченный крепче."
	icon = 'icons/mob/simple/carp.dmi'
	icon_state = "eyeball"
	max_integrity = 250

/// While any organ beats the Crooked Man takes no damage at all and slowly heals.
/obj/structure/crooked_target/organ
	name = "пульсирующий орган"
	desc = "Огромное сердце, вросшее в пол. Пока оно бьётся, Скрюченный неуязвим."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "demon_heart-on"
	max_integrity = 400
	health_cut = 0.1
	scale = 3.5
	hover_height = 3
	hover_time = 1.5 SECONDS
	/// Share of the boss's maximum health each organ restores per second.
	var/heal_per_second = 0.0007

/obj/structure/crooked_target/organ/Initialize(mapload, mob/living/basic/boss/crooked_man/boss)
	. = ..()
	START_PROCESSING(SSobj, src)

/// A burst heart spills its gore all around.
/obj/structure/crooked_target/organ/atom_destruction(damage_flag)
	var/turf/here = get_turf(src)
	if(here)
		new /obj/effect/gibspawner/human/bodypartless(here)
		playsound(here, 'sound/effects/wounds/crackandbleed.ogg', 100, TRUE)
	return ..()

/obj/structure/crooked_target/organ/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/crooked_target/organ/process(seconds_per_tick)
	if(QDELETED(boss) || boss.stat == DEAD)
		return PROCESS_KILL
	// Shots may be bullets or lasers; heal whichever wounds he has.
	var/static/list/healed_types = list(BRUTE, BURN)
	boss.heal_ordered_damage(boss.maxHealth * heal_per_second * seconds_per_tick, healed_types)

/// Opens staring eyes around him; while any is open he takes half damage.
/datum/action/cooldown/crooked_eyes
	button_icon = 'modular_bandastation/bosses/icons/action_buttons.dmi'
	button_icon_state = "crooked_eyes"
	name = "Глаза"
	desc = "Открывает вокруг огромные глаза. Пока хоть один открыт, вы получаете вдвое меньше урона."
	cooldown_time = 45 SECONDS
	/// Most eyes open at once.
	var/max_eyes = 3

/datum/action/cooldown/crooked_eyes/Activate(atom/target)
	var/mob/living/basic/boss/crooked_man/crooked = owner
	if(!istype(crooked))
		return FALSE
	var/open = 0
	for(var/obj/structure/crooked_target/eye/eye in crooked.targets)
		open++
	if(!crooked.spawn_targets(/obj/structure/crooked_target/eye, max_eyes - open))
		crooked.balloon_alert(crooked, "некуда открыть глаза")
		return FALSE
	crooked.visible_message(span_danger("Вокруг [crooked] раскрываются огромные глаза!"))
	StartCooldown()
	return TRUE
