GLOBAL_LIST_EMPTY(dead_players_during_shift)

/// Whether this body can go through the organic, humanoid cremation stages.
/mob/living/carbon/human/proc/has_crematable_body()
	return (bodytype & BODYTYPE_ORGANIC) && (bodyshape & BODYSHAPE_HUMANOID)

/mob/living/carbon/human/should_husk_from_burn_damage(total_burn)
	if(!..())
		deferred_husk_damage = 0
		return FALSE
	if(!has_crematable_body())
		return TRUE
	var/turf/open/lava/lava = loc
	var/resists_heat = HAS_TRAIT(src, TRAIT_RESISTHEAT)
	var/fire_reaches_body = on_fire && !resists_heat && get_fire_protection() < FIRE_SUIT_MAX_TEMP_PROTECT
	var/still_overheated = (cremation_exposure || deferred_husk_damage) && !resists_heat && coretemperature > get_body_temp_heat_damage_limit()
	// After rescue, health updates can still see the old burns or residual heat from the fire.
	if(fire_reaches_body || still_overheated || (istype(lava) && lava.is_burning_occupant(src)) || total_burn <= deferred_husk_damage)
		deferred_husk_damage = total_burn
		return FALSE
	return TRUE

/// Called only for sustained fire or direct lava exposure. Extinguishing pauses the current stage.
/mob/living/carbon/human/proc/advance_cremation(seconds_per_tick)
	if(stat != DEAD || cremation_stage == CREMATION_ASH || !has_crematable_body())
		return
	if(HAS_TRAIT(src, TRAIT_GODMODE) || HAS_TRAIT(src, TRAIT_UNHUSKABLE) || HAS_TRAIT(src, TRAIT_STASIS))
		return

	cremation_exposure += seconds_per_tick SECONDS
	if(cremation_stage == NONE && cremation_exposure >= CREMATION_HUSK_TIME)
		become_husk(BURN)
	if(cremation_stage == CREMATION_HUSK && cremation_exposure >= 5 MINUTES)
		cremation_stage = CREMATION_CHARRED
		update_body_parts()
	if(cremation_stage == CREMATION_CHARRED && cremation_exposure >= 10 MINUTES)
		cremation_stage = CREMATION_SKELETON
		update_body_parts()
	if(cremation_stage == CREMATION_SKELETON && cremation_exposure >= 12 MINUTES)
		cremation_stage = CREMATION_ASH
		visible_message(span_warning("Обгоревшие кости рассыпаются в пепел."))
		dust(just_ash = TRUE, drop_items = TRUE, give_moodlet = FALSE)

/mob/living/carbon/human/gib_animation()
	new /obj/effect/temp_visual/gib_animation(loc, dna.species.gib_anim)

/mob/living/carbon/human/spawn_dust(just_ash)
	if(just_ash)
		if(cremation_stage == CREMATION_ASH && islava(loc))
			new /obj/effect/decal/cleanable/ash/floating(loc)
			return
		return ..()

	var/bone_type = /obj/effect/decal/remains/human
	// BANDASTATION EDIT START - IPC chassis leave mechanical remains when dusted.
	if(is_species(src, /datum/species/ipc))
		bone_type = /obj/effect/decal/remains/robot
	else if(isplasmaman(src))
		bone_type = /obj/effect/decal/remains/plasma

	var/obj/effect/decal/remains/bones = new bone_type(loc)
	// BANDASTATION EDIT END
	bones.pixel_z = -6
	bones.pixel_w = rand(-1, 1)

/mob/living/carbon/human/death(gibbed)
	if(stat == DEAD)
		return
	if(cremation_stage == NONE)
		cremation_exposure = 0
		deferred_husk_damage = 0
	stop_sound_channel(CHANNEL_HEARTBEAT)
	var/obj/item/organ/heart/human_heart = get_organ_slot(ORGAN_SLOT_HEART)
	human_heart?.beat = BEAT_NONE
	human_heart?.Stop()

	force_say(list(""), immediate = TRUE)

	. = ..()

	if(client && !HAS_TRAIT(src, TRAIT_SUICIDED) && !(client in GLOB.dead_players_during_shift))
		GLOB.dead_players_during_shift += client

	if(SSticker.HasRoundStarted())
		SSblackbox.ReportDeath(src)
		log_message("has died (BRUTE: [src.get_brute_loss()], BURN: [src.get_fire_loss()], TOX: [src.get_tox_loss()], OXY: [src.get_oxy_loss()]", LOG_ATTACK)
		if(key) // Prevents log spamming of keyless mob deaths (like xenobio monkeys)
			investigate_log("has died at [loc_name(src)].<br>\
				BRUTE: [src.get_brute_loss()] BURN: [src.get_fire_loss()] TOX: [src.get_tox_loss()] OXY: [src.get_oxy_loss()] STAM: [src.get_stamina_loss()]<br>\
				<b>Brain damage</b>: [src.get_organ_loss(ORGAN_SLOT_BRAIN) || "0"]<br>\
				<b>[get_bloodtype()?.get_blood_name() || "Blood"] volume</b>: [src.get_blood_volume(apply_modifiers = TRUE)]cl ([round((src.get_blood_volume(apply_modifiers = TRUE) / BLOOD_VOLUME_NORMAL) * 100, 0.1)]%)<br>\
				<b>Reagents</b>:<br>[reagents_readout()]", INVESTIGATE_DEATHS)
	to_chat(src, span_warning("Вы погибли. Если ваше тело не было уничтожено, вас могут вернуть к жизни другие игроки. \
		Если вы не хотите возвращаться в тело, используйте кнопку \"Do Not Resuscitate\" (DNR) внизу экрана."))
	if(SSlag_switch.measures[DISABLE_DEAD_KEYLOOP] && !client?.holder)
		to_chat(src, span_warning("Движение будучи призраком в данный момент отключено. Чтобы покинуть тело используйте Ghost вёрб во вкладке OOC."))

/mob/living/carbon/human/proc/reagents_readout()
	var/readout = "[get_bloodtype()?.get_blood_name() || "Blood"]stream:"
	for(var/datum/reagent/reagent in reagents?.reagent_list)
		readout += "<br>[round(reagent.volume, 0.001)] юнитов [reagent.name]"

	readout += "<br>Желудок:"
	var/obj/item/organ/stomach/belly = get_organ_slot(ORGAN_SLOT_STOMACH)
	for(var/datum/reagent/bile in belly?.reagents?.reagent_list)
		if(!belly.food_reagents[bile.type])
			readout += "<br>[round(bile.volume, 0.001)] юнитов [bile.name]"

	return readout

/mob/living/carbon/human/proc/makeSkeleton()
	set_species(/datum/species/skeleton)
	var/obj/item/bodypart/head = get_bodypart(BODY_ZONE_HEAD)
	if(head)
		ADD_TRAIT(head, TRAIT_DISFIGURED, INNATE_TRAIT)
	return TRUE

/mob/living/carbon/proc/Drain()
	become_husk(CHANGELING_DRAIN)
	ADD_TRAIT(src, TRAIT_BADDNA, CHANGELING_DRAIN)
	set_blood_volume(0)
	return TRUE
