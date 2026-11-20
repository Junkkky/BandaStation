/// Invulnerable, player-controlled event monster from Katorga13.
/mob/living/basic/boss/crooked_man
	name = "Скрюченный человек"
	// Speaks in the large bold type of a megaphone or a head of staff's loud headset.
	speech_span = SPAN_COMMAND
	desc = "Его движения неестественны, а каждый сустав будто вывернут наизнанку."
	icon = 'modular_bandastation/bosses/crooked_man/icons/crooked_man.dmi'
	icon_state = ""
	icon_dead = ""
	maxHealth = 1000000
	health = 1000000
	armour_penetration = 40
	melee_damage_lower = 20
	melee_damage_upper = 20
	melee_attack_cooldown = 1 SECONDS
	speed = 2
	attack_sound = 'modular_bandastation/bosses/crooked_man/sounds/impact_1.ogg'
	pixel_x = -32
	base_pixel_x = -32
	faction = list("faithless", FACTION_HELL)
	obj_damage = 1000
	physiology = list(BRUTE = 0.1, BURN = 0.1, TOX = 0, STAMINA = 0, OXY = 0)
	ai_controller = null
	see_in_dark = 8
	lighting_cutoff_red = 30
	lighting_cutoff_green = 5
	lighting_cutoff_blue = 20
	/// Owned breathing loop; destruction cancels its sound timer.
	var/datum/looping_sound/crooked_breathing/breathing
	/// Abilities created by this boss, deleted with it even after administrative removal.
	var/list/datum/action/cooldown/spell/innate_abilities = list()

/mob/living/basic/boss/crooked_man/Initialize(mapload)
	. = ..()
	add_traits(list(
		TRAIT_GODMODE,
		TRAIT_NODEATH,
		TRAIT_NOGUNS,
		TRAIT_NOBLOOD,
		TRAIT_NODISMEMBER,
		TRAIT_NEVER_WOUNDED,
		TRAIT_NOBREATH,
		TRAIT_STUNIMMUNE,
		TRAIT_SLEEPIMMUNE,
		TRAIT_THERMAL_VISION,
	), INNATE_TRAIT)
	update_sight()
	RemoveElement(/datum/element/wall_tearer, tear_time = 1 SECONDS)
	AddElement(/datum/element/wall_tearer, tear_time = 0.5 SECONDS)
	AddComponent(/datum/component/blood_walk, blood_type = /obj/effect/decal/cleanable/blood)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(play_footstep_sound))
	breathing = new(src, start_immediately = TRUE)
	for(var/ability_type in list(
		/datum/action/cooldown/spell/crooked_phase,
		/datum/action/cooldown/spell/aoe/ability_stomp,
		/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone,
		/datum/action/cooldown/spell/crooked_devour,
	))
		var/datum/action/cooldown/spell/ability = new ability_type(src)
		innate_abilities += ability
		ability.Grant(src)

/mob/living/basic/boss/crooked_man/Destroy()
	QDEL_NULL(breathing)
	QDEL_LIST(innate_abilities)
	return ..()

/mob/living/basic/boss/crooked_man/proc/play_footstep_sound()
	SIGNAL_HANDLER
	var/static/list/steps = list(
		'modular_bandastation/bosses/crooked_man/sounds/step_1.ogg',
		'modular_bandastation/bosses/crooked_man/sounds/step_2.ogg',
		'modular_bandastation/bosses/crooked_man/sounds/step_3.ogg',
	)
	playsound(src, pick(steps), 100, TRUE, 7)

/// The original four-second breathing cadence, managed by the native sound subsystem.
/datum/looping_sound/crooked_breathing
	mid_sounds = 'modular_bandastation/bosses/crooked_man/sounds/breathing.ogg'
	mid_length = 4 SECONDS
	volume = 70
	extra_range = 8
	falloff_exponent = 0.7
