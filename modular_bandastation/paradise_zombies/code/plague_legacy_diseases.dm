/// Paradise's original bee infestation, isolated from TG's different recovery model.
/datum/disease/beesease/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Beesease"
	form = "Infection"
	max_stages = 4
	cure_text = "Sugar"
	cures = list(/datum/reagent/consumable/sugar)
	agent = "Apidae Infection"
	viable_mobtypes = list(/mob/living/carbon/human)
	desc = "If left untreated subject will regurgitate bees."
	severity = DISEASE_SEVERITY_BIOHAZARD

/datum/disease/beesease/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2)
			if(prob(2))
				to_chat(affected_mob, span_notice("You taste honey in your mouth."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_notice("Your stomach rumbles."))
			if(prob(2))
				to_chat(affected_mob, span_danger("Your stomach stings painfully."))
				if(prob(20))
					affected_mob.adjust_tox_loss(2)
		if(4)
			if(prob(10))
				affected_mob.visible_message(span_danger("[affected_mob] buzzes."), span_userdanger("Your stomach buzzes violently!"))
			if(prob(5))
				to_chat(affected_mob, span_danger("You feel something moving in your throat."))
			if(prob(1))
				affected_mob.visible_message(span_danger("[affected_mob] coughs up a swarm of bees!"), span_userdanger("You cough up a swarm of bees!"))
				new /mob/living/basic/bee(affected_mob.loc)

/// ICE9 cold retains its original cooling, frost damage, and lack of spontaneous recovery.
/datum/disease/cold9/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "The Cold"
	max_stages = 3
	cure_text = "Spaceacillin"
	cures = list(/datum/reagent/medicine/spaceacillin)
	agent = "ICE9-rhinovirus"
	desc = "If left untreated the subject will slow, as if partly frozen."
	severity = DISEASE_SEVERITY_HARMFUL

/datum/disease/cold9/paradise_plague/on_plague_cycle()
	if(stage < 2)
		return
	var/stage_factor = stage - 1
	affected_mob.bodytemperature -= 7.5 * stage_factor
	if(prob(2 * stage_factor))
		affected_mob.emote("sneeze")
	if(prob(2 * stage_factor))
		affected_mob.emote("cough")
	if(prob(3 * stage_factor))
		to_chat(affected_mob, span_danger("Your throat feels sore."))
	if(prob(5 * stage_factor))
		to_chat(affected_mob, span_danger("You feel stiff."))
		affected_mob.adjust_fire_loss(1)

/// The original Spanish Inquisition flu heats its victim and burns at both symptomatic stages.
/datum/disease/fluspanish/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Spanish Inquisition Flu"
	max_stages = 3
	cure_text = "Spaceacillin"
	cures = list(/datum/reagent/medicine/spaceacillin)
	cure_chance = 10
	agent = "1nqu1s1t10n flu virion"
	spreading_modifier = 0.75
	desc = "If left untreated the subject will burn to death for being a heretic."
	severity = DISEASE_SEVERITY_HARMFUL

/datum/disease/fluspanish/paradise_plague/on_plague_cycle()
	if(stage < 2)
		return
	var/stage_factor = stage - 1
	affected_mob.bodytemperature += 10 * stage_factor
	if(prob(3 * stage_factor))
		affected_mob.emote("sneeze")
	if(prob(3 * stage_factor))
		affected_mob.emote("cough")
	if(prob(2.5 * stage_factor))
		to_chat(affected_mob, span_danger("You're burning in your own skin!"))
		affected_mob.adjust_fire_loss(5)

/// Retrovirus keeps its strain-specific rest/mutadone cure and original two DNA-scrambling outcomes.
/datum/disease/dna_retrovirus/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Retrovirus"
	max_stages = 4
	cure_text = "Rest or an injection of mutadone"
	cure_chance = 6
	spreading_modifier = 0.4
	stage_prob = 2
	desc = "A DNA-altering retrovirus that scrambles the structural and unique enzymes of a host constantly."
	severity = DISEASE_SEVERITY_BIOHAZARD
	/// Sixty percent of new strains are cured by lying down rather than mutadone.
	var/restcure = FALSE

/datum/disease/dna_retrovirus/paradise_plague/New()
	. = ..()
	agent = "Virus class [pick("A", "B", "C", "D", "E", "F")][pick("A", "B", "C", "D", "E", "F")]-[rand(50, 300)]"
	if(prob(40))
		cures = list(/datum/reagent/medicine/mutadone)
	else
		restcure = TRUE

/datum/disease/dna_retrovirus/paradise_plague/Copy()
	var/datum/disease/dna_retrovirus/paradise_plague/copied = ..()
	copied.restcure = restcure
	return copied

/datum/disease/dna_retrovirus/paradise_plague/on_plague_cycle()
	var/rest_chance
	switch(stage)
		if(1)
			rest_chance = 30
		if(2, 3)
			rest_chance = 20
		if(4)
			rest_chance = 5
	if(restcure && affected_mob.body_position == LYING_DOWN && prob(rest_chance))
		to_chat(affected_mob, span_notice("You feel better."))
		cure()
		return
	switch(stage)
		if(1)
			if(prob(8))
				to_chat(affected_mob, span_danger("Your head hurts."))
			if(prob(9))
				to_chat(affected_mob, "You feel a tingling sensation in your chest.")
			if(prob(9))
				to_chat(affected_mob, span_danger("You feel angry."))
		if(2)
			if(prob(8))
				to_chat(affected_mob, span_danger("Your skin feels loose."))
			if(prob(10))
				to_chat(affected_mob, "You feel very strange.")
			if(prob(4))
				to_chat(affected_mob, span_danger("You feel a stabbing pain in your head!"))
				affected_mob.Paralyze(4 SECONDS)
			if(prob(4))
				to_chat(affected_mob, span_danger("Your stomach churns."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_danger("Your entire body vibrates."))
			if(prob(35))
				scramble_host()
		if(4)
			if(prob(60))
				scramble_host()

/// Paradise's UI/SE map to TG identity/mutation blocks; feature DNA is not a third outcome.
/datum/disease/dna_retrovirus/paradise_plague/proc/scramble_host()
	if(!affected_mob.has_dna())
		return
	var/scramble_identity = prob(50)
	scramble_dna(affected_mob, ui = scramble_identity, se = !scramble_identity, probability = rand(15, 45))

/// Fungal tuberculosis uses the donor's salbutamol cure and stage-specific symptoms.
/datum/disease/tuberculosis/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	form = "Disease"
	name = "Fungal tuberculosis"
	max_stages = 5
	cure_text = "Spaceacillin & Salbutamol"
	cures = list(/datum/reagent/medicine/spaceacillin, /datum/reagent/medicine/salbutamol)
	agent = "Fungal Tubercle bacillus Cosmosis"
	cure_chance = 5
	desc = "A rare highly transmittable virulent virus. Causes fever, blood vomiting, lung damage, weight loss, and fatigue."
	required_organ = ORGAN_SLOT_LUNGS
	severity = DISEASE_SEVERITY_HARMFUL

/datum/disease/tuberculosis/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2)
			if(prob(2))
				affected_mob.emote("cough")
				to_chat(affected_mob, span_danger("Your chest hurts."))
			if(prob(2))
				to_chat(affected_mob, span_danger("Your stomach violently rumbles!"))
			if(prob(5))
				to_chat(affected_mob, span_danger("You feel a cold sweat form."))
		if(4)
			if(prob(2))
				to_chat(affected_mob, span_userdanger("You see four of everything"))
				affected_mob.set_dizzy_if_lower(10 SECONDS)
			if(prob(2))
				to_chat(affected_mob, span_danger("You feel a sharp pain from your lower chest!"))
				affected_mob.adjust_oxy_loss(5)
				affected_mob.emote("gasp")
			if(prob(10))
				to_chat(affected_mob, span_danger("You feel air escape from your lungs painfully."))
				affected_mob.adjust_oxy_loss(25)
				affected_mob.emote("gasp")
		if(5)
			if(prob(2))
				to_chat(affected_mob, span_userdanger("[pick("You feel your heart slowing...", "You relax and slow your heartbeat.")]"))
				affected_mob.adjust_stamina_loss(70)
			if(prob(10))
				affected_mob.adjust_stamina_loss(100)
				affected_mob.visible_message(span_warning("[affected_mob] faints!"), span_userdanger("You surrender yourself and feel at peace..."))
				affected_mob.AdjustSleeping(10 SECONDS)
			if(prob(2))
				to_chat(affected_mob, span_userdanger("You feel your mind relax and your thoughts drift!"))
				affected_mob.adjust_confusion_up_to(16 SECONDS, 200 SECONDS)
			if(prob(10))
				affected_mob.paradise_vomit(20)
			if(prob(3))
				to_chat(affected_mob, span_warning("<i>[pick("Your stomach silently rumbles...", "Your stomach seizes up and falls limp, muscles dead and lifeless.", "You could eat a crayon")]</i>"))
				// The donor counted two-second life ticks; TG stores deciseconds.
				affected_mob.overeatduration = max(affected_mob.overeatduration - 200 SECONDS, 0)
				affected_mob.adjust_nutrition(-100)
			if(prob(15))
				to_chat(affected_mob, span_danger("[pick("You feel uncomfortably hot...", "You feel like unzipping your jumpsuit", "You feel like taking off some clothes...")]"))
				affected_mob.bodytemperature += 40

/// The original anxiety has longer confusion attacks and short-lived butterflies.
/datum/disease/anxiety/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Severe Anxiety"
	form = "Infection"
	max_stages = 4
	cure_text = "Ethanol"
	cures = list(/datum/reagent/consumable/ethanol)
	agent = "Excess Lepidopticides"
	viable_mobtypes = list(/mob/living/carbon/human)
	desc = "If left untreated subject will regurgitate butterflies."
	severity = DISEASE_SEVERITY_MINOR

/datum/disease/anxiety/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2)
			if(prob(5))
				to_chat(affected_mob, span_notice("You feel anxious."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_notice("Your stomach flutters."))
			if(prob(5))
				to_chat(affected_mob, span_notice("You feel panicky."))
			if(prob(2))
				to_chat(affected_mob, span_danger("You're overtaken with panic!"))
				affected_mob.adjust_confusion(rand(4 SECONDS, 6 SECONDS))
		if(4)
			if(prob(10))
				to_chat(affected_mob, span_danger("You feel butterflies in your stomach."))
			if(prob(5))
				affected_mob.visible_message(span_danger("[affected_mob] stumbles around in a panic."), span_userdanger("You have a panic attack!"))
				affected_mob.adjust_confusion(rand(12 SECONDS, 16 SECONDS))
				affected_mob.adjust_jitter(rand(12 SECONDS, 16 SECONDS))
			if(prob(2))
				affected_mob.visible_message(span_danger("[affected_mob] coughs up butterflies!"), span_userdanger("You cough up butterflies!"))
				spawn_butterflies()

/// Spawn the donor's pair, each with its own five-to-twenty-five-second decomposition timer.
/datum/disease/anxiety/paradise_plague/proc/spawn_butterflies()
	var/list/butterflies = list()
	for(var/count in 1 to 2)
		butterflies += new /mob/living/basic/butterfly/paradise_plague(affected_mob.loc)
	return butterflies

/// These butterflies disappear instead of accumulating permanently on the server.
/mob/living/basic/butterfly/paradise_plague
	gold_core_spawnable = NO_SPAWN
	/// Cancel the pending lifetime callback when the butterfly is deleted early.
	var/decompose_timer

/mob/living/basic/butterfly/paradise_plague/Initialize(mapload)
	. = ..()
	decompose_timer = addtimer(CALLBACK(src, PROC_REF(decompose)), rand(5, 25) SECONDS, TIMER_STOPPABLE)

/mob/living/basic/butterfly/paradise_plague/Destroy()
	if(decompose_timer)
		deltimer(decompose_timer)
	return ..()

/// Remove the insect and its corpse just as the donor's melt did.
/mob/living/basic/butterfly/paradise_plague/proc/decompose()
	visible_message(span_notice("[src] decomposes due to being outside of its original habitat for too long!"), span_userdanger("You decompose for being too long out of your habitat!"))
	qdel(src)

/// Wizarditis produces sayings, disposable clothes and rare teleports; it grants no TG spell arsenal.
/datum/disease/wizarditis/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Wizarditis"
	desc = "Subjects show signs of dementia, yelling obscure sentences, and a growing feeling of inner power."
	max_stages = 4
	cure_text = "The Manly Dorf"
	cures = list(/datum/reagent/consumable/ethanol/manly_dorf)
	cure_chance = 100
	agent = "Rincewindus Vulgaris"
	spreading_modifier = 0.75
	severity = DISEASE_SEVERITY_MINOR
	/// TG uses indexed hand slots rather than Paradise's left/right equipment slot flags.
	var/list/magic_fashion = list()

/datum/disease/wizarditis/paradise_plague/New()
	. = ..()
	magic_fashion = list(
		"left_hand" = /obj/item/staff,
		"right_hand" = /obj/item/staff,
		"[ITEM_SLOT_HEAD]" = /obj/item/clothing/head/wizard,
		"[ITEM_SLOT_OCLOTHING]" = /obj/item/clothing/suit/wizrobe,
		"[ITEM_SLOT_FEET]" = /obj/item/clothing/shoes/sandal,
	)

/datum/disease/wizarditis/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2, 3)
			if(prob(2))
				affected_mob.say(pick("ТЫ!!! НЕ ПРОЙ-ДЁШЬ!!!", "Экспеллиармус!", "Мерлинова борода!", "Почувствуй силу тёмной стороны!"))
			if(prob(8))
				to_chat(affected_mob, span_danger("You feel [pick("that you don't have enough mana", "that the winds of magic are gone", "that this location gives you a +1 to INT", "an urge to summon familiar")]."))
		if(4)
			if(prob(1))
				affected_mob.say(pick("FORTI GY AMA!", "GITTAH WEIGH!", "TOKI WO TOMARE!", "TARCOL MINTI ZHERI!", "ONI SOMA!", "EI NATH!", "BIRUZ BENNAR!", "NWOLC EGNEVER!"))
			if(prob(3))
				to_chat(affected_mob, span_danger("You feel [pick("the tidal wave of raw power building inside", "that this location gives you a +2 to INT and +1 to WIS", "an urge to teleport", "the magic bubbling in your veins", "an urge to summon familiar")]."))
			if(prob(3))
				spawn_wizard_clothes()
			if(prob(0.033))
				teleport()

/// Replace one eligible slot with one DROPDEL magical item, preserving irremovable equipment.
/datum/disease/wizarditis/paradise_plague/proc/spawn_wizard_clothes()
	var/mob/living/carbon/human/host = affected_mob
	if(!istype(host))
		return FALSE
	var/list/eligible_slots = list()
	for(var/slot in magic_fashion)
		var/hand_index = slot == "left_hand" ? LEFT_HANDS : (slot == "right_hand" ? RIGHT_HANDS : 0)
		var/equipment_slot = hand_index ? ITEM_SLOT_HANDS : text2num(slot)
		var/obj/item/current = hand_index ? host.get_item_for_held_index(hand_index) : host.get_item_by_slot(equipment_slot)
		if((locate(magic_fashion[slot]) in host) || !host.canUnEquip(current))
			continue
		if(hand_index && !host.has_hand_for_held_index(hand_index))
			continue
		if(equipment_slot == ITEM_SLOT_HEAD && (!host.get_bodypart(BODY_ZONE_HEAD) || isplasmaman(host)))
			continue
		if(equipment_slot == ITEM_SLOT_OCLOTHING && !host.get_bodypart(BODY_ZONE_CHEST))
			continue
		if(equipment_slot == ITEM_SLOT_FEET && !host.num_legs)
			continue
		eligible_slots += slot
	if(!length(eligible_slots))
		return FALSE
	var/chosen_slot = pick(eligible_slots)
	var/hand_index = chosen_slot == "left_hand" ? LEFT_HANDS : (chosen_slot == "right_hand" ? RIGHT_HANDS : 0)
	var/equipment_slot = hand_index ? ITEM_SLOT_HANDS : text2num(chosen_slot)
	var/obj/item/current = hand_index ? host.get_item_for_held_index(hand_index) : host.get_item_by_slot(equipment_slot)
	if(current && !host.dropItemToGround(current))
		return FALSE
	var/item_type = magic_fashion[chosen_slot]
	var/obj/item/attire = new item_type()
	attire.item_flags |= DROPDEL
	if(hand_index)
		if(!host.put_in_hand(attire, hand_index, forced = TRUE))
			qdel(attire)
			return FALSE
	else if(!host.equip_to_slot_or_del(attire, equipment_slot))
		return FALSE
	return TRUE

/// The original rare teleport chooses a clear non-space area within an eighty-tile area search.
/datum/disease/wizarditis/paradise_plague/proc/teleport()
	if(!check_teleport_valid(affected_mob, get_turf(affected_mob), TELEPORT_CHANNEL_MAGIC))
		return FALSE
	var/list/possible_areas = get_areas_in_range(80, affected_mob)
	for(var/area/space/space_area in possible_areas.Copy())
		possible_areas -= space_area
	if(!length(possible_areas))
		return FALSE
	var/area/chosen_area = pick(possible_areas)
	var/list/teleport_turfs = list()
	for(var/turf/destination as anything in get_area_turfs(chosen_area.type))
		if(isspaceturf(destination) || destination.density)
			continue
		var/clear = TRUE
		for(var/obj/obstacle in destination)
			if(obstacle.density)
				clear = FALSE
				break
		if(clear)
			teleport_turfs += destination
	if(!length(teleport_turfs))
		return FALSE
	affected_mob.say("SCYAR NILA [uppertext(chosen_area.name)]!")
	return do_teleport(affected_mob, pick(teleport_turfs), no_effects = TRUE, channel = TELEPORT_CHANNEL_MAGIC)
