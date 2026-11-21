#define CROOKED_STAGE_AWAKENING 1
#define CROOKED_STAGE_WOMB 2
#define CROOKED_STAGE_AGONY 3
#define CROOKED_STAGGER_TRAIT "crooked_stagger"
/// How long he trembles and reddens before he bursts.
#define CROOKED_DEATH_AGONY (2.5 SECONDS)

/// Player-controlled final boss from Katorga13. A group fight: one armoured fighter holds him while the rest
/// shoot him and the eyes and organs that shield him.
/mob/living/basic/boss/crooked_man
	name = "Скрюченный человек"
	// Speaks in the large bold type of a megaphone or a head of staff's loud headset.
	speech_span = SPAN_COMMAND
	desc = "Его движения неестественны, а каждый сустав будто вывернут наизнанку."
	icon = 'modular_bandastation/bosses/crooked_man/icons/crooked_man.dmi'
	icon_state = ""
	icon_dead = ""
	// Tuned for eight shooters over about five minutes; see stage_damage and the targets for the rest.
	maxHealth = 3000
	health = 3000
	melee_damage_lower = 15
	melee_damage_upper = 15
	melee_attack_cooldown = 1.5 SECONDS
	speed = 2
	attack_sound = 'modular_bandastation/bosses/crooked_man/sounds/impact_1.ogg'
	pixel_x = -32
	base_pixel_x = -32
	faction = list("faithless", FACTION_HELL)
	obj_damage = 1000
	physiology = list(TOX = 0, STAMINA = 0, OXY = 0)
	ai_controller = null
	see_in_dark = 8
	lighting_cutoff_red = 30
	lighting_cutoff_green = 5
	lighting_cutoff_blue = 20
	/// Owned breathing loop; destruction cancels its sound timer.
	var/datum/looping_sound/crooked_breathing/breathing
	/// Abilities created by this boss, deleted with it even after administrative removal.
	var/list/datum/action/cooldown/innate_abilities = list()
	/// Fight stage; it only rises as he loses health.
	var/stage = CROOKED_STAGE_AWAKENING
	/// Share of incoming damage he takes in each stage, before his eyes and organs are counted.
	var/list/stage_damage = list(0.5, 0.5, 1)
	/// While any eye is open, damage is multiplied by this.
	var/eye_damage_factor = 0.5
	/// Live eyes and organs shielding him.
	var/list/obj/structure/crooked_target/targets = list()
	/// Keeps growls from piling up when abilities follow each other.
	COOLDOWN_DECLARE(growl_cooldown)

/mob/living/basic/boss/crooked_man/Initialize(mapload)
	. = ..()
	add_traits(list(
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
	RegisterSignal(src, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(modify_damage))
	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(check_stage))
	RegisterSignal(src, COMSIG_MOB_ABILITY_STARTED, PROC_REF(on_ability_started))
	RegisterSignals(src, list(
		COMSIG_MOB_EMOTE_SOUND("laugh"),
		COMSIG_MOB_EMOTE_SOUND("wheeze"),
		COMSIG_MOB_EMOTE_SOUND("groan"),
		COMSIG_MOB_EMOTE_SOUND("scream"),
	), PROC_REF(on_emote_sound))
	breathing = new(src, start_immediately = TRUE)
	for(var/ability_type in list(
		/datum/action/cooldown/spell/crooked_phase,
		/datum/action/cooldown/spell/aoe/ability_stomp/crooked,
		/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/crooked,
		/datum/action/cooldown/spell/crooked_devour/crooked,
		/datum/action/cooldown/mob_cooldown/goliath_tentacles/crooked,
		/datum/action/cooldown/crooked_eyes,
	))
		grant_ability(ability_type)

/mob/living/basic/boss/crooked_man/Destroy()
	QDEL_NULL(breathing)
	QDEL_LIST(innate_abilities)
	// Targets remove themselves from the list as they go, so delete from a copy.
	for(var/obj/structure/crooked_target/target as anything in targets.Copy())
		qdel(target)
	return ..()

/// He screams, trembles and reddens, then bursts and runs down into a red puddle; nothing is left to drag around.
/mob/living/basic/boss/crooked_man/death(gibbed)
	. = ..()
	if(gibbed)
		return
	visible_message(span_userdanger("[src] бьётся в судорогах и наливается кровью!"))
	playsound(src, 'modular_bandastation/bosses/crooked_man/sounds/death_scream.ogg', 100, FALSE, 15)
	Shake(4, 2, CROOKED_DEATH_AGONY)
	animate(src, color = "#ff1a1a", time = CROOKED_DEATH_AGONY, flags = ANIMATION_PARALLEL)
	addtimer(CALLBACK(src, PROC_REF(burst)), CROOKED_DEATH_AGONY)

/// The reddened body falls apart: its chunks drop to the floor, tumble and stay there as a heap of meat in his blood.
/mob/living/basic/boss/crooked_man/proc/burst()
	var/turf/here = get_turf(src)
	if(here)
		visible_message(span_userdanger("[src] разваливается на куски, растекающиеся кровавой жижей!"))
		playsound(here, 'sound/effects/splat.ogg', 100, TRUE, 10)
		playsound(here, 'sound/effects/wounds/crackandbleed.ogg', 100, TRUE, 10)
		// Height of each chunk's middle above the sprite's bottom row, from the generator of death_chunks.dmi.
		var/static/list/chunk_heights = list(79, 76, 82, 60, 60, 62, 37, 33, 44, 15, 16, 15)
		for(var/index in 1 to length(chunk_heights))
			// His feet stand 7 px above the sprite's bottom row.
			new /obj/effect/crooked_chunk(here, src, index, chunk_heights[index] - 7)
		var/list/blood_dna = list("Crooked DNA" = random_human_blood_type())
		// The puddle he melts into.
		for(var/turf/open/floor in range(1, here))
			new /obj/effect/decal/cleanable/blood(floor, null, blood_dna)
		new /obj/effect/gibspawner/generic(here)
		new /obj/effect/gibspawner/generic(here)
		event_gore_burst(here, blood_dna, sprays = 20)
	ghostize(can_reenter_corpse = FALSE)
	qdel(src)

/// One chunk of the Crooked Man's body, cut from his last appearance by a mask; it falls and stays on the floor as meat.
/obj/effect/crooked_chunk
	anchored = TRUE

/obj/effect/crooked_chunk/Initialize(mapload, mob/living/crooked, index, fall)
	. = ..()
	if(!crooked)
		return INITIALIZE_HINT_QDEL
	appearance = crooked.appearance
	name = "куски плоти"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Lies under whoever walks over it.
	layer = BELOW_MOB_LAYER
	add_filter("chunk", 1, alpha_mask_filter(icon = icon('modular_bandastation/bosses/crooked_man/icons/death_chunks.dmi', "chunk[index]")))
	var/fall_time = 0.3 SECONDS + fall * 0.005 SECONDS
	animate(src, pixel_z = -fall, pixel_w = rand(-10, 10), transform = matrix().Turn(rand(-25, 25)), time = fall_time, easing = QUAD_EASING | EASE_IN)
	animate(color = "#8a1018", time = 1 SECONDS)

/mob/living/basic/boss/crooked_man/proc/grant_ability(ability_type)
	var/datum/action/cooldown/ability = new ability_type(src)
	innate_abilities += ability
	ability.Grant(src)

/// Damage passes in part, depending on the stage; open eyes halve it, a live organ blocks it entirely.
/mob/living/basic/boss/crooked_man/proc/modify_damage(datum/source, list/damage_mods, damage, damagetype)
	SIGNAL_HANDLER
	damage_mods += current_damage_factor()

/mob/living/basic/boss/crooked_man/proc/current_damage_factor()
	if(locate(/obj/structure/crooked_target/organ) in targets)
		return 0
	. = stage_damage[stage]
	if(locate(/obj/structure/crooked_target/eye) in targets)
		. *= eye_damage_factor

/mob/living/basic/boss/crooked_man/proc/check_stage(datum/source)
	SIGNAL_HANDLER
	if(stat == DEAD)
		return
	var/fraction = health / maxHealth
	var/reached = fraction <= 0.33 ? CROOKED_STAGE_AGONY : (fraction <= 0.66 ? CROOKED_STAGE_WOMB : CROOKED_STAGE_AWAKENING)
	// A single heavy blow may skip a stage; each one still opens in turn.
	while(stage < reached)
		enter_stage(stage + 1)

/mob/living/basic/boss/crooked_man/proc/enter_stage(new_stage)
	stage = new_stage
	playsound(src, 'modular_bandastation/bosses/crooked_man/sounds/lauth.ogg', 100, TRUE, 10)
	playsound(src, 'sound/effects/hallucinations/wail.ogg', 100, TRUE, 10)
	// His body tears open for the new shape: blood and gibs fly, less than when he dies.
	var/turf/here = get_turf(src)
	if(here)
		playsound(here, 'sound/effects/wounds/crackandbleed.ogg', 100, TRUE, 8)
		playsound(here, 'sound/effects/splat.ogg', 90, TRUE, 8)
		new /obj/effect/gibspawner/generic(here)
		event_gore_burst(here, list("Crooked DNA" = random_human_blood_type()), sprays = 6, radius = 1, at_witnesses = FALSE)
	switch(stage)
		if(CROOKED_STAGE_WOMB)
			visible_message(span_userdanger("[src] выворачивается наизнанку — на его брюхе разверзается пасть, а из пола вырастают пульсирующие органы!"))
			set_look("womb")
			grant_ability(/datum/action/cooldown/mob_cooldown/tentacle_burst/crooked)
			grant_ability(/datum/action/cooldown/mob_cooldown/charge/crooked)
			spawn_targets(/obj/structure/crooked_target/organ, 3)
		if(CROOKED_STAGE_AGONY)
			visible_message(span_userdanger("[src] бьётся в агонии — из его спины вырываются извивающиеся щупальца!"))
			set_look("agony")
			melee_attack_cooldown = 1.2 SECONDS
			grant_ability(/datum/action/cooldown/mob_cooldown/tentacle_grasp/crooked)
			spawn_targets(/obj/structure/crooked_target/eye, 3)

/// His looks after the concept: a blinking eye from the start, the fanged maw from the womb, tentacles in agony.
/// They are drawn into these states frame for frame with his breathing; the corpse keeps the look for its death.
/mob/living/basic/boss/crooked_man/proc/set_look(state)
	icon_state = state
	icon_living = state
	icon_dead = state

/// Places up to `count` targets of a type on open floor he can see, at least two tiles away. Returns how many appeared.
/mob/living/basic/boss/crooked_man/proc/spawn_targets(target_type, count)
	var/list/spots = list()
	for(var/turf/open/spot in view(6, src))
		if(get_dist(src, spot) >= 2 && !spot.is_blocked_turf(TRUE) && !(locate(/obj/structure/crooked_target) in spot))
			spots += spot
	. = 0
	while(. < count && length(spots))
		new target_type(pick_n_take(spots), src)
		.++

/// A destroyed eye or organ tears off a share of his health and leaves him reeling for a moment.
/mob/living/basic/boss/crooked_man/proc/target_destroyed(obj/structure/crooked_target/target)
	targets -= target
	visible_message(span_danger("[src] корчится и воет, когда [target] лопается!"))
	playsound(src, 'sound/effects/splat.ogg', 100, TRUE)
	playsound(src, 'sound/effects/screech.ogg', 100, TRUE, 8, frequency = 0.8)
	playsound(src, 'sound/effects/hallucinations/wail.ogg', 90, TRUE, 8)
	add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), CROOKED_STAGGER_TRAIT)
	addtimer(CALLBACK(src, PROC_REF(recover)), 2 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)
	adjust_brute_loss(maxHealth * target.health_cut)

/mob/living/basic/boss/crooked_man/proc/recover()
	remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), CROOKED_STAGGER_TRAIT)

/// Every ability opens with a growl, a sound cue on top of the wind-up.
/mob/living/basic/boss/crooked_man/proc/on_ability_started(datum/source, datum/action/cooldown/ability, atom/target)
	SIGNAL_HANDLER
	if(!COOLDOWN_FINISHED(src, growl_cooldown))
		return
	COOLDOWN_START(src, growl_cooldown, 1.5 SECONDS)
	var/static/list/growls = list(
		'sound/effects/hallucinations/growl1.ogg',
		'sound/effects/hallucinations/growl2.ogg',
		'sound/effects/hallucinations/growl3.ogg',
	)
	playsound(src, pick(growls), 90, TRUE, 8)

/// The panel emotes speak with his own laugh and breath, and with growls and a wail.
/mob/living/basic/boss/crooked_man/proc/on_emote_sound(datum/source, key, list/sounds)
	SIGNAL_HANDLER
	var/static/list/emote_sounds = list(
		"laugh" = 'modular_bandastation/bosses/crooked_man/sounds/lauth.ogg',
		"wheeze" = 'modular_bandastation/bosses/crooked_man/sounds/breathing.ogg',
		"groan" = list(
			'sound/effects/hallucinations/growl1.ogg',
			'sound/effects/hallucinations/growl2.ogg',
			'sound/effects/hallucinations/growl3.ogg',
		),
		"scream" = 'sound/effects/hallucinations/wail.ogg',
	)
	sounds[get_emote_sound_from_list(emote_sounds[key], src)] = EMOTE_SOUND_STATUS_EFFECT

/mob/living/basic/boss/crooked_man/get_mob_emote_panel_entries()
	var/static/list/entries = list(
		"смеяться" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "laugh"),
		"хрипеть" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "wheeze"),
		"рычать" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "groan"),
		"кричать" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "scream"),
	)
	return entries

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

/// Stands the caster still for a wind-up; false if it moved, died or is already winding up this action.
/proc/crooked_windup(mob/living/caster, duration, datum/action/action)
	if(!do_after(caster, duration, target = caster, interaction_key = action))
		return FALSE
	return caster.stat != DEAD && isturf(caster.loc)

/// Blood sparks marking for a second where one of the Crooked Man's announced attacks will land.
/obj/effect/temp_visual/cult/sparks/crooked
	duration = 1 SECONDS
	layer = BELOW_MOB_LAYER

/// Green sparks for the bile eruption.
/obj/effect/temp_visual/cult/sparks/crooked/acid
	color = "#4cff00"

#undef CROOKED_STAGE_AWAKENING
#undef CROOKED_STAGE_WOMB
#undef CROOKED_STAGE_AGONY
#undef CROOKED_STAGGER_TRAIT
#undef CROOKED_DEATH_AGONY
