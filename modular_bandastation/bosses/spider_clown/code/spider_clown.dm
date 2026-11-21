#define SPIDER_CLOWN_STASIS "spider_clown_stored_body"

/// Player-controlled event monster with native walking and bite animations.
/mob/living/basic/boss/spider_clown
	name = "Паук-клоун"
	// Loud in the large bodies; set_body() quiets the small one.
	speech_span = SPAN_COMMAND
	desc = "Чудовищный паук с клоунским лицом и огромной зубастой пастью."
	icon = 'modular_bandastation/bosses/spider_clown/icons/spider_clown.dmi'
	icon_state = "idle"
	icon_living = "idle"
	icon_dead = "dead"
	pixel_x = -32
	base_pixel_x = -32
	// The legs end 10px above the frame's bottom; without this the body reads as one tile further north.
	pixel_y = -8
	base_pixel_y = -8
	// Added to the config run delay (2.2): faster than a running human.
	speed = -0.5
	// The boss default crushes doors and windows it walks into; walls are torn only on purpose.
	move_force = MOVE_FORCE_DEFAULT
	maxHealth = 1000
	health = 1000
	melee_damage_lower = 20
	melee_damage_upper = 20
	melee_attack_cooldown = 1.2 SECONDS
	attack_verb_continuous = "кусает"
	attack_verb_simple = "кусаешь"
	attack_vis_effect = ATTACK_EFFECT_BITE
	ai_controller = null
	hud_type = /datum/hud/living/pinhead
	max_grab = GRAB_AGGRESSIVE
	// Night vision goggle strength (10, 25, 10), shifted into red.
	lighting_cutoff_red = 25
	lighting_cutoff_green = 10
	lighting_cutoff_blue = 10
	/// Active form: "spider", "tiny" or "true" in this body, "clown" while the human body is controlled.
	var/form = "spider"
	/// Whether this body currently looks like the small ventcrawling spider.
	var/tiny = FALSE
	/// Whether this body currently shows the clown's true form.
	var/true_form = FALSE
	/// Identity set by the event director, restored when returning to the spider form.
	var/saved_name
	/// Speech must use the current form's identity too.
	var/saved_real_name
	/// The director's original description.
	var/saved_description
	/// Mortal human body of the clown and mimic forms while it is controlled; gibbed when the spider leaves it.
	var/mob/living/carbon/human/spider_clown_body/human_body
	/// Voices chosen for the spider, tiny, true and clown forms, keyed by form.
	var/list/datum/tts_seed/form_voices = list()
	/// Manual TTS filter shared by every form, independent of its selected voice.
	var/growl_enabled = TRUE
	/// One-shot animation playing now; its eye layer replaces the current state's until it ends.
	var/eyes_animation

/mob/living/basic/boss/spider_clown/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/event_boss, list(
		/datum/action/cooldown/spell/spatial_phase,
		/datum/action/cooldown/mob_cooldown/wrap/event_spider,
		/datum/action/cooldown/mob_cooldown/lay_web/event_spider,
		/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/event_spider,
		/datum/action/cooldown/spider_big_form,
		/datum/action/cooldown/spider_disguise,
		/datum/action/cooldown/spider_tiny,
		/datum/action/cooldown/spider_true_form,
		/datum/action/cooldown/spell/jaunt/bloodcrawl/event_spider,
		/datum/action/cooldown/spider_invisibility,
		/datum/action/cooldown/event_target/spider_jump,
		/datum/action/cooldown/event_target/chain_operation/dismember/event_spider,
		/datum/action/cooldown/spell/crooked_devour/event_spider,
		/datum/action/cooldown/spell/emp/event_spider,
		/datum/action/cooldown/spell/aoe/ability_stomp/event_spider,
		/datum/action/cooldown/spider_voice,
		/datum/action/cooldown/spider_voice_filter,
		/datum/action/cooldown/event_target/spider_blood_brood,
		/datum/action/cooldown/event_target/pinhead_portal,
	))
	// The brood shares this private faction with every body of its master.
	add_faction(REF(src))
	ADD_TRAIT(src, TRAIT_THERMAL_VISION, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_WEB_SURFER, INNATE_TRAIT)
	update_sight()
	form_voices["spider"] = get_tts_seed()
	form_voices["tiny"] = form_voices["spider"]
	form_voices["true"] = form_voices["spider"]
	RegisterSignal(src, COMSIG_TTS_COMPONENT_PRE_CAST_TTS, PROC_REF(filter_tts))
	RegisterSignal(src, SIGNAL_REMOVETRAIT(TRAIT_MOVE_VENTCRAWLING), PROC_REF(on_vent_exit))
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_step))
	RegisterSignals(src, list(COMSIG_MOB_EMOTE_SOUND("laugh"), COMSIG_MOB_EMOTE_SOUND("laughevil"), COMSIG_MOB_EMOTE_SOUND("scream")), PROC_REF(on_emote_sound))
	update_appearance(UPDATE_OVERLAYS)

/mob/living/basic/boss/spider_clown/Destroy()
	// The controlled human body stays as an ordinary human if its spider is deleted.
	if(human_body)
		human_body.spider = null
		human_body = null
	return ..()

/mob/living/basic/boss/spider_clown/update_overlays()
	. = ..()
	// Every look of this body has an eye layer named after its living state.
	if(stat != DEAD)
		. += emissive_appearance(icon, "[eyes_animation || icon_state]_eyes", src)

/mob/living/basic/boss/spider_clown/look_dead()
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/mob/living/basic/boss/spider_clown/look_alive()
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/// Flicks a one-shot animation of the big spider; its glowing eyes follow the same frames.
/mob/living/basic/boss/spider_clown/proc/play_animation(animation, duration)
	if(tiny || true_form)
		return
	flick(animation, src)
	eyes_animation = animation
	update_appearance(UPDATE_OVERLAYS)
	addtimer(CALLBACK(src, PROC_REF(end_animation)), duration, TIMER_UNIQUE | TIMER_OVERRIDE)

/mob/living/basic/boss/spider_clown/proc/end_animation()
	eyes_animation = null
	update_appearance(UPDATE_OVERLAYS)

/// The full-sized spider seizes its prey aggressively from the first touch.
/mob/living/basic/boss/spider_clown/start_pulling(atom/movable/AM, state, force = pull_force, supress_message = FALSE)
	. = ..()
	if(!tiny && pulling == AM && isliving(AM) && !grab_state)
		var/mob/living/victim = AM
		victim.grippedby(src, instant = TRUE)

/mob/living/basic/boss/spider_clown/do_attack_animation(atom/attacked_atom, visual_effect_icon, used_item, no_effect)
	. = ..()
	play_animation("bite", 0.5 SECONDS)

/// The native attack sound is fixed at half volume; a monster's bite must be heard.
/mob/living/basic/boss/spider_clown/melee_attack(atom/target, list/modifiers, ignore_cooldown)
	. = ..()
	if(!. || !isliving(target))
		return
	var/static/list/growls = list(
		'sound/effects/hallucinations/growl1.ogg',
		'sound/effects/hallucinations/growl2.ogg',
		'sound/effects/hallucinations/growl3.ogg',
	)
	playsound(src, 'modular_bandastation/bosses/spider_clown/sounds/bite.ogg', 100, TRUE, 4)
	playsound(src, pick(growls), 80, TRUE, 4)

/// Clicking a severed arm or leg lying nearby eats it instead of attacking it.
/mob/living/basic/boss/spider_clown/early_melee_attack(atom/target, list/modifiers, ignore_cooldown)
	if((istype(target, /obj/item/bodypart/arm) || istype(target, /obj/item/bodypart/leg)) && isturf(target.loc) && Adjacent(target))
		face_atom(target)
		INVOKE_ASYNC(src, PROC_REF(eat_limb), target)
		return BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN
	return ..()

/// Eats a severed limb lying next to the spider, taking as long as a bite of food.
/mob/living/basic/boss/spider_clown/proc/eat_limb(obj/item/bodypart/limb)
	if(DOING_INTERACTION(src, limb))
		return
	if(!do_after(src, 1 SECONDS, limb, interaction_key = limb) || QDELETED(limb) || limb.owner || !isturf(limb.loc) || !Adjacent(limb))
		return
	visible_message(span_danger("[src] с хрустом пожирает [limb]!"), span_notice("Вы пожираете [limb]."))
	playsound(src, 'sound/effects/wounds/crackandbleed.ogg', 80, TRUE)
	new /obj/effect/decal/cleanable/blood/splatter(limb.loc)
	qdel(limb)

/// Every change of form tears the body open; it is only possible outside vents and jaunts, but works from a corpse.
/mob/living/basic/boss/spider_clown/proc/set_form(new_form)
	if(form == new_form)
		return FALSE
	var/mob/living/active = form == "clown" ? human_body : src
	if(QDELETED(active) || !isturf(active.loc))
		return FALSE
	var/turf/here = active.loc
	var/old_form = form
	// Leaving the human gibs the body itself.
	spider_clown_transform_effects(here, gibs = old_form != "clown")
	form = new_form
	if(new_form == "clown")
		// The hidden spider always comes back full-sized.
		set_body("spider")
		enter_human(here)
		return TRUE
	if(old_form == "clown")
		leave_human(here)
	set_body(new_form)
	return TRUE

/// Shows this body as the full spider, the small ventcrawling spider or the clown's true form.
/mob/living/basic/boss/spider_clown/proc/set_body(new_body)
	var/old_body = tiny ? "tiny" : (true_form ? "true" : "spider")
	if(old_body == new_body)
		return
	// The director's identity belongs to the spider; the other looks keep a copy to give back.
	if(old_body == "spider")
		saved_name = name
		saved_real_name = real_name
		saved_description = desc
	var/was_tiny = tiny
	tiny = new_body == "tiny"
	true_form = new_body == "true"
	speech_span = tiny ? null : SPAN_COMMAND
	switch(new_body)
		if("tiny")
			icon = 'modular_bandastation/bosses/spider_clown/icons/spider_clown_tiny.dmi'
			icon_state = "tiny"
			icon_dead = "tiny_dead"
			name = "паучок"
			real_name = name
			desc = "Маленький паучок. Он смотрит на вас слишком осмысленно."
			pixel_x = 0
			pixel_y = 0
		if("true")
			icon = 'modular_bandastation/bosses/spider_clown/icons/spider_clown_true.dmi'
			icon_state = "idle"
			icon_dead = "dead"
			name = saved_name
			real_name = saved_real_name
			desc = "Высокая фигура в изодранном клоунском костюме. За её спиной извиваются щупальца."
			// 64 pixels wide: the feet stand on the tile's bottom row.
			pixel_x = -16
			pixel_y = 0
		else
			icon = initial(icon)
			icon_state = initial(icon_state)
			icon_dead = initial(icon_dead)
			name = saved_name
			real_name = saved_real_name
			desc = saved_description
			pixel_x = initial(pixel_x)
			pixel_y = initial(pixel_y)
	icon_living = icon_state
	base_pixel_x = pixel_x
	base_pixel_y = pixel_y
	// Totals with the 2.2 run delay: spider 1.7, tiny 1.95.
	set_varspeed(tiny ? -0.25 : initial(speed))
	// Only the large bodies tear walls; the boss parent adds the element with these exact arguments.
	if(tiny != was_tiny)
		if(tiny)
			RemoveElement(/datum/element/wall_tearer, tear_time = 1 SECONDS)
			ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, REF(src))
		else
			AddElement(/datum/element/wall_tearer, tear_time = 1 SECONDS)
			REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, REF(src))
	set_voice(src, form_voices[new_body])
	update_appearance(UPDATE_OVERLAYS)

/// Grows a fresh mortal clown body and moves control into it; the spider waits inside, untouchable.
/mob/living/basic/boss/spider_clown/proc/enter_human(turf/here)
	human_body = new(here)
	human_body.spider = src
	human_body.add_faction(REF(src))
	RegisterSignal(human_body, COMSIG_TTS_COMPONENT_PRE_CAST_TTS, PROC_REF(filter_tts))
	RegisterSignals(human_body, list(COMSIG_MOB_EMOTE_SOUND("laugh"), COMSIG_MOB_EMOTE_SOUND("laughevil"), COMSIG_MOB_EMOTE_SOUND("scream")), PROC_REF(on_emote_sound))
	RegisterSignal(human_body, COMSIG_LIVING_DEATH, PROC_REF(on_human_death))
	var/datum/tts_seed/clown_voice = form_voices["clown"]
	if(clown_voice)
		set_voice(human_body, clown_voice)
		human_body.clown_profile.dna.tts_seed_dna = clown_voice
	human_body.setDir(dir)
	transfer_control(src, human_body)
	forceMove(human_body)
	apply_status_effect(/datum/status_effect/grouped/stasis, SPIDER_CLOWN_STASIS)

/// The spider bursts out: control returns to it and the human body, alive or dead, is gibbed with its belongings.
/mob/living/basic/boss/spider_clown/proc/leave_human(turf/here)
	var/mob/living/carbon/human/spider_clown_body/body = human_body
	human_body = null
	body.spider = null
	forceMove(here)
	remove_status_effect(/datum/status_effect/grouped/stasis, SPIDER_CLOWN_STASIS)
	setDir(body.dir)
	transfer_control(body, src)
	body.gib(DROP_ALL_REMAINS)

/// Gives control from one body to another; admins possessing without a mind move by key.
/mob/living/basic/boss/spider_clown/proc/transfer_control(mob/living/old_body, mob/living/new_body)
	if(old_body.mind)
		// A gibbed body ghostizes its player first; the key must still follow the mind into the spider.
		old_body.mind.transfer_to(new_body, force_key_move = TRUE)
	else if(old_body.key)
		new_body.PossessByPlayer(old_body.key)

/// Gibbing spills the brain, and the mind with it, before the body is deleted; the spider must burst out first.
/mob/living/basic/boss/spider_clown/proc/on_human_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(gibbed && source == human_body)
		reclaim_from_human()

/// The controlled human body is gibbed or deleted by something else: control returns to the spider inside it.
/mob/living/basic/boss/spider_clown/proc/reclaim_from_human()
	human_body.spider = null
	// Gibbing may already have spilled the spider out of the body.
	if(loc == human_body)
		forceMove(get_turf(human_body) || find_safe_turf())
	remove_status_effect(/datum/status_effect/grouped/stasis, SPIDER_CLOWN_STASIS)
	transfer_control(human_body, src)
	form = "spider"
	human_body = null

/// Sets a body's TTS voice, keeping carbon DNA in sync like the native voice change.
/mob/living/basic/boss/spider_clown/proc/set_voice(mob/living/body, datum/tts_seed/seed)
	var/datum/component/tts_component/tts = body.GetComponent(/datum/component/tts_component)
	if(!tts || !seed)
		return
	tts.tts_seed = seed
	if(iscarbon(body))
		var/mob/living/carbon/carbon_body = body
		carbon_body.dna.tts_seed_dna = seed

/// Stores a newly chosen voice for whichever form the given body currently shows.
/mob/living/basic/boss/spider_clown/proc/remember_voice(mob/living/body, datum/tts_seed/seed)
	set_voice(body, seed)
	if(body == src)
		form_voices[tiny ? "tiny" : (true_form ? "true" : "spider")] = seed
		return
	var/mob/living/carbon/human/spider_clown_body/clown = body
	if(istype(clown) && !clown.mimicking)
		form_voices["clown"] = seed
		clown.clown_profile.dna.tts_seed_dna = seed

/// Leaving a vent tears through the grille in a spray of gore.
/mob/living/basic/boss/spider_clown/proc/on_vent_exit(datum/source)
	SIGNAL_HANDLER
	if(!isturf(loc))
		return
	new /obj/effect/gibspawner/generic(loc)
	playsound(loc, 'sound/effects/splat.ogg', 100, TRUE)

/// The existing panel emotes play this monster's own laughter and metallic shriek.
/mob/living/basic/boss/spider_clown/proc/on_emote_sound(datum/source, key, list/sounds)
	SIGNAL_HANDLER
	var/static/list/emote_sounds = list(
		"laugh" = list(
			'modular_bandastation/bosses/spider_clown/sounds/laugh_1.ogg',
			'modular_bandastation/bosses/spider_clown/sounds/laugh_2.ogg',
		),
		"laughevil" = list(
			'modular_bandastation/bosses/spider_clown/sounds/laugh_evil_1.ogg',
			'modular_bandastation/bosses/spider_clown/sounds/laugh_evil_2.ogg',
		),
		"scream" = 'modular_bandastation/bosses/spider_clown/sounds/scream.ogg',
	)
	sounds[get_emote_sound_from_list(emote_sounds[key], src)] = EMOTE_SOUND_STATUS_EFFECT

/// Footstep element skips flying mobs, and every boss flies; the spider's legs still sound.
/mob/living/basic/boss/spider_clown/proc/on_step(datum/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(forced || throwing || !isturf(loc))
		return
	if(tiny)
		return
	// The tall true form treads heavily; the claws belong to the spider's legs.
	if(true_form)
		playsound(src, pick('sound/effects/footstep/heavy1.ogg', 'sound/effects/footstep/heavy2.ogg'), 90, TRUE, 4)
		return
	var/static/list/claws = list(
		'sound/effects/footstep/hardclaw1.ogg',
		'sound/effects/footstep/hardclaw2.ogg',
		'sound/effects/footstep/hardclaw3.ogg',
		'sound/effects/footstep/hardclaw4.ogg',
	)
	playsound(src, pick(claws), 70, TRUE, 2)

/mob/living/basic/boss/spider_clown/get_mob_emote_panel_entries()
	var/static/list/entries = list(
		"смеяться" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "laugh"),
		"смеяться злорадно" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "laughevil"),
		"кричать" = list("type" = TGUI_PANEL_EMOTE_TYPE_DEFAULT, "key" = "scream"),
	)
	return entries

#undef SPIDER_CLOWN_STASIS
