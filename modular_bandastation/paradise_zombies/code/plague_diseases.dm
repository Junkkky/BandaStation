/** Runs the original disease progression and cure rolls once every two seconds. */
/datum/disease/paradise_plague_dependency
	abstract_type = /datum/disease/paradise_plague_dependency
	spread_flags = DISEASE_SPREAD_NON_CONTAGIOUS
	spread_text = "Non-contagious"
	viable_mobtypes = list(/mob/living/carbon/human)
	stage_prob = 4
	cure_chance = 8
	/// Accumulated real seconds until the next Paradise disease cycle.
	var/cycle_seconds = 0
	/// Original fraction of stages at which the medical HUD discovers this strain.
	var/discovery_threshold = 0.5
	/// Discovery survives regression and transmission in infected blood.
	var/discovered = FALSE

/datum/disease/paradise_plague_dependency/Copy()
	var/datum/disease/paradise_plague_dependency/copied = ..()
	copied.discovery_threshold = discovery_threshold
	copied.discovered = discovered
	return copied

/datum/disease/paradise_plague_dependency/after_add()
	. = ..()
	update_discovery()

/datum/disease/paradise_plague_dependency/update_stage(new_stage)
	update_discovery()
	. = ..()
	if(!QDELETED(src))
		update_discovery()

/** A discovered infection stays visible even after treatment lowers its stage. */
/datum/disease/paradise_plague_dependency/proc/update_discovery()
	if(!discovered && stage >= CEILING(max_stages * discovery_threshold, 1))
		discovered = TRUE
		affected_mob?.med_hud_set_status()

/datum/disease/paradise_plague_dependency/stage_act(seconds_per_tick = 2)
	if(QDELETED(affected_mob))
		return FALSE
	update_discovery()
	cycle_seconds += seconds_per_tick
	while(cycle_seconds >= 2)
		cycle_seconds -= 2
		if(required_organ && !affected_mob.get_organ_slot(required_organ))
			cure()
			return FALSE
		var/has_treatment = has_cure()
		if(carrier && !has_treatment)
			return FALSE
		stage = min(stage, max_stages)
		if(!has_treatment && prob(stage_prob))
			update_stage(min(stage + 1, max_stages))
		if(has_treatment && prob(cure_chance))
			update_stage(max(stage - 1, 1))
		if((disease_flags & CURABLE) && has_treatment && prob(cure_chance))
			cure()
			return FALSE
		on_plague_cycle()
		if(QDELETED(src) || !affected_mob)
			return FALSE
	return TRUE

/** Applies one donor symptom cycle after progression and treatment. */
/datum/disease/paradise_plague_dependency/proc/on_plague_cycle()
	return

/** Advanced Kingstons mutates the host into one persistent, randomly selected species. */
/datum/disease/paradise_kingstons_advanced
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Advanced Kingstons Syndrome"
	desc = "If left untreated the subject will mutate to a different species."
	agent = "AMB45DR Bacteria"
	max_stages = 4
	cure_text = "Plasma"
	cures = list(/datum/reagent/toxin/plasma)
	cure_chance = 50
	spreading_modifier = 0.75
	severity = DISEASE_SEVERITY_BIOHAZARD
	/// Same-species equivalents available in this build; absent Paradise species are not substituted.
	var/static/list/mutation_species = list(/datum/species/human, /datum/species/tajaran, /datum/species/lizard, /datum/species/skrell, /datum/species/vulpkanin, /datum/species/jelly/slime, /datum/species/moth)
	/// The strain's immutable transformation target, preserved in blood copies.
	var/datum/species/chosen_species
	/// The strain's random disease-name suffix.
	var/chosen_suffix

/datum/disease/paradise_kingstons_advanced/New()
	. = ..()
	chosen_species = pick(mutation_species)
	chosen_suffix = pick("pox", "rot", "flu", "cough", "-gitis", "cold", "rash", "itch", "decay")
	name = "[initial(chosen_species.name)] [chosen_suffix]"

/datum/disease/paradise_kingstons_advanced/Copy()
	var/datum/disease/paradise_kingstons_advanced/copied = ..()
	copied.chosen_species = chosen_species
	copied.chosen_suffix = chosen_suffix
	return copied

/datum/disease/paradise_kingstons_advanced/on_plague_cycle()
	switch(stage)
		if(1)
			if(prob(10))
				to_chat(affected_mob, span_notice("You feel awkward."))
		if(2)
			if(prob(10))
				to_chat(affected_mob, span_danger("You itch."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_danger("Your skin starts to flake!"))
		if(4)
			if(prob(5))
				mutate_host()

/** Preserves existing DNA colours, damage, and missing limbs during mutation. */
/datum/disease/paradise_kingstons_advanced/proc/mutate_host()
	if(!ishuman(affected_mob) || !ispath(chosen_species, /datum/species))
		return FALSE
	var/mob/living/carbon/human/host = affected_mob
	if(!istype(host.dna.species, chosen_species))
		host.visible_message(span_danger("[host]'s skin splits and form contorts!"), span_userdanger("Your body mutates into a [initial(chosen_species.name)]!"))
		host.set_species(chosen_species, replace_missing = FALSE)
		return TRUE
	host.visible_message(span_danger("[host] scratches at [host.p_their()] skin!"), span_userdanger("You scratch your skin to try not to itch!"))
	host.adjust_brute_loss(5)
	host.adjust_stamina_loss(5)
	return FALSE

/** Uncontrollable aggression that can also be soothed by cannabis. */
/datum/disease/paradise_berserker
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Berserker"
	desc = "Swearing, shouting, attacking nearby crew members uncontrollably."
	agent = "Jagged Crystals"
	max_stages = 2
	stage_prob = 5
	cure_text = "Anti-Psychotics"
	cures = list(/datum/reagent/medicine/haloperidol)
	cure_chance = 10
	severity = DISEASE_SEVERITY_BIOHAZARD
	disease_flags = CURABLE

/datum/disease/paradise_berserker/on_plague_cycle()
	if(affected_mob.reagents.has_reagent(/datum/reagent/drug/cannabis))
		to_chat(affected_mob, span_notice("You mellow out."))
		cure()
		return
	switch(stage)
		if(1)
			if(prob(5))
				affected_mob.emote(pick("twitch", "grumble"))
			if(prob(5))
				affected_mob.say(pick("Grr...", "Fuck...", "Fucking...", "Fuck this fucking.. fuck.."), forced = name)
		if(2)
			if(prob(5))
				affected_mob.emote(pick("twitch", "scream"))
			if(prob(5))
				affected_mob.say(pick("AAARRGGHHH!!!!", "GRR!!!", "FUCK!! FUUUUUUCK!!!", "FUCKING SHITCOCK!!", "WROOAAAGHHH!!"), forced = name)
			if(prob(15))
				affected_mob.visible_message(span_danger("[affected_mob] twitches violently!"))
				for(var/obj/item/held as anything in affected_mob.get_held_items())
					affected_mob.dropItemToGround(held)
			if(prob(33))
				thrash()

/** Makes the actual nearby attacks while preserving the donor's miss chance. */
/datum/disease/paradise_berserker/proc/thrash()
	if(affected_mob.incapacitated)
		affected_mob.visible_message(span_danger("[affected_mob] spasms and twitches!"))
		return
	affected_mob.visible_message(span_danger("[affected_mob] thrashes around violently!"))
	for(var/mob/living/carbon/victim in range(1, affected_mob))
		if(victim == affected_mob)
			continue
		if(prob(80))
			playsound(affected_mob, SFX_PUNCH, 25, TRUE)
			victim.adjust_brute_loss(rand(1, 5))
			log_combat(affected_mob, victim, "hit with Berserker disease")
			affected_mob.visible_message(span_danger("[affected_mob] hits [victim] with [affected_mob.p_their()] thrashing!"))
		else
			playsound(affected_mob, 'sound/items/weapons/punchmiss.ogg', 25, TRUE)
			affected_mob.visible_message(span_danger("[affected_mob] fails to hit [victim] with [affected_mob.p_their()] thrashing!"))

/** The talisman's original appendicitis, cured by removing the affected organ. */
/datum/disease/paradise_appendicitis
	parent_type = /datum/disease/paradise_plague_dependency
	form = "Condition"
	name = "Appendicitis"
	desc = "If left untreated the subject will become very weak, and may vomit often."
	agent = "Shitty Appendix"
	max_stages = 3
	cure_text = "Surgery"
	severity = DISEASE_SEVERITY_MINOR
	disease_flags = CAN_CARRY|CAN_RESIST
	visibility_flags = HIDDEN_PANDEMIC
	required_organ = ORGAN_SLOT_APPENDIX
	bypasses_immunity = FALSE
	/// The surgery target whose removal immediately ends the condition.
	var/datum/weakref/appendix_ref

/datum/disease/paradise_appendicitis/after_add()
	. = ..()
	var/obj/item/organ/appendix/appendix = affected_mob.get_organ_slot(ORGAN_SLOT_APPENDIX)
	if(appendix)
		appendix_ref = WEAKREF(appendix)
		RegisterSignal(appendix, COMSIG_ORGAN_REMOVED, PROC_REF(on_appendix_removed))

/datum/disease/paradise_appendicitis/Destroy()
	var/obj/item/organ/appendix/appendix = appendix_ref?.resolve()
	if(appendix)
		UnregisterSignal(appendix, COMSIG_ORGAN_REMOVED)
	appendix_ref = null
	return ..()

/datum/disease/paradise_appendicitis/proc/on_appendix_removed(datum/source)
	SIGNAL_HANDLER
	cure()

/datum/disease/paradise_appendicitis/on_plague_cycle()
	switch(stage)
		if(1)
			if(prob(5))
				affected_mob.emote("cough")
		if(2)
			var/obj/item/organ/appendix/appendix = affected_mob.get_organ_slot(ORGAN_SLOT_APPENDIX)
			if(appendix)
				appendix.inflamation_stage = max(appendix.inflamation_stage, 1)
				appendix.update_appearance()
			if(prob(3))
				to_chat(affected_mob, span_warning("You feel a stabbing pain in your abdomen!"))
				affected_mob.Stun(rand(4 SECONDS, 6 SECONDS))
				affected_mob.adjust_tox_loss(1)
		if(3)
			if(prob(1))
				affected_mob.paradise_vomit(95)

/** Magic pressurizes stomach bile until a violent vomit throws the host backward. */
/datum/disease/paradise_grut_gut
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Grut Gut"
	desc = "A magic-infused disease that builds up DANGEROUSLY high pressure bile within the stomach."
	agent = "Eruca Stomachum"
	max_stages = 5
	stage_prob = 5
	cure_text = "Pyrotech stabilizing agents"
	cures = list(/datum/reagent/stabilizing_agent)
	severity = DISEASE_SEVERITY_DANGEROUS

/datum/disease/paradise_grut_gut/on_plague_cycle()
	switch(stage)
		if(1)
			if(prob(3))
				to_chat(affected_mob, span_danger("Your stomach feels strange."))
		if(2)
			if(prob(3))
				to_chat(affected_mob, span_danger("You feel bloated."))
			if(prob(2))
				to_chat(affected_mob, span_danger("You feel an uncomfortable pressure in your abdomen."))
		if(3)
			if(prob(3))
				to_chat(affected_mob, span_danger("You feel an uncomfortable pressure in your abdomen."))
			if(prob(2))
				affected_mob.emote("burp")
			if(prob(1))
				affected_mob.emote("groan")
		if(4)
			if(prob(1))
				affected_mob.paradise_fakevomit(no_text = TRUE)
				affected_mob.adjust_nutrition(-rand(3, 5))
			if(prob(2))
				affected_mob.emote("burp")
			if(prob(3))
				to_chat(affected_mob, span_danger("You feel horribly bloated."))
			if(prob(2))
				to_chat(affected_mob, span_danger("A deep bubbling resounds through your chest."))
		if(5)
			if(prob(2))
				affected_mob.manual_emote("belches loudly!")
			if(prob(1))
				affected_mob.emote("burp")
			if(prob(1))
				affected_mob.emote("groan")
			if(prob(3))
				to_chat(affected_mob, span_danger("Your stomach is killing you!"))
			if(prob(3))
				to_chat(affected_mob, span_danger("Your abdomen gurgles and bubbles with a fierce intensity!"))
			if(prob(2) && affected_mob.nutrition >= 100)
				affected_mob.adjust_brute_loss(5)
				affected_mob.paradise_vomit(6, FALSE, TRUE, 7, FALSE)
				affected_mob.visible_message(span_danger("[affected_mob] vomits with such force that [affected_mob.p_theyre()] sent flying backwards!"))
				do_fling()

/** Performs the original 200-tile, speed-three recoil throw. */
/datum/disease/paradise_grut_gut/proc/do_fling()
	if(QDELETED(affected_mob))
		return
	var/turf/destination = get_edge_target_turf(affected_mob, REVERSE_DIR(affected_mob.dir))
	return affected_mob.throw_at(destination, 200, 3)

/** A nose full of miniature wands that occasionally sneezes a real fireball. */
/datum/disease/paradise_wand_rot
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Wand Rot"
	desc = "A magic-infused disease that replaces one's nose hairs with tiny wands. Avoid nasal irritants."
	agent = "nasum magicum"
	max_stages = 5
	stage_prob = 5
	cure_text = "Acetaldehyde"
	cures = list(/datum/reagent/acetaldehyde)
	severity = DISEASE_SEVERITY_DANGEROUS
	/// A pending sneeze is cancelled when the disease is removed or its host changes.
	var/sneeze_timer

/datum/disease/paradise_wand_rot/Destroy()
	if(sneeze_timer)
		deltimer(sneeze_timer)
	sneeze_timer = null
	return ..()

/datum/disease/paradise_wand_rot/on_plague_cycle()
	switch(stage)
		if(1)
			if(prob(2))
				affected_mob.emote("sniff")
		if(2)
			if(prob(3))
				affected_mob.emote("sniff")
			if(prob(3))
				to_chat(affected_mob, span_danger("Your nose and throat feel uncomfortably dry."))
		if(3)
			if(prob(2))
				affected_mob.emote("cough")
			if(prob(3))
				affected_mob.emote("sniff")
			if(prob(3))
				to_chat(affected_mob, span_danger("Your nose and throat feel uncomfortably dry."))
		if(4)
			if(prob(2))
				affected_mob.emote("cough")
			if(prob(3))
				affected_mob.emote("sneeze")
			if(prob(3))
				to_chat(affected_mob, span_danger("Your throat burns and itches!"))
		if(5)
			if(prob(2))
				affected_mob.emote("cough")
			if(prob(2))
				to_chat(affected_mob, span_danger("Your nose feels like it's going to burn right off your face!"))
				affected_mob.adjust_fire_loss(5)
			if(prob(3))
				affected_mob.emote("sniff")
			if(prob(1))
				queue_sneeze()

/** Schedules the donor's 0.2-second audio lead without yielding in a life signal. */
/datum/disease/paradise_wand_rot/proc/queue_sneeze()
	if(sneeze_timer || QDELETED(affected_mob))
		return
	affected_mob.emote("sneeze")
	sneeze_timer = addtimer(CALLBACK(src, PROC_REF(sneeze_fireballs), WEAKREF(affected_mob)), 0.2 SECONDS, TIMER_STOPPABLE)

/** Revalidates the host after the delay, then uses TG's projectile launcher. */
/datum/disease/paradise_wand_rot/proc/sneeze_fireballs(datum/weakref/host_ref)
	sneeze_timer = null
	var/mob/living/carbon/host = host_ref?.resolve()
	if(QDELETED(host) || affected_mob != host || host.stat == DEAD || !(src in host.diseases) || stage != 5)
		return null
	var/turf/target = get_edge_target_turf(host, pick(GLOB.alldirs))
	playsound(host, 'sound/effects/magic/fireball.ogg', 50, TRUE)
	return host.fire_projectile(/obj/projectile/magic/fireball, target, null, host)

/** Space-matter vomit drains the surrounding tile's atmosphere for fifteen seconds. */
/datum/disease/paradise_mystic_malaise
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Mystic Malaise"
	desc = "A magic-infused disease that converts gastric juices into space-matter."
	agent = "Spatio Ventrem"
	max_stages = 5
	stage_prob = 5
	cure_text = "Liquid dark matter"
	cures = list(/datum/reagent/liquid_dark_matter)
	severity = DISEASE_SEVERITY_DANGEROUS

/datum/disease/paradise_mystic_malaise/on_plague_cycle()
	switch(stage)
		if(1)
			if(prob(2))
				to_chat(affected_mob, span_danger("You feel nauseous."))
		if(2)
			if(prob(3))
				to_chat(affected_mob, span_danger("Your stomach aches."))
		if(3)
			if(prob(3))
				to_chat(affected_mob, span_danger("You feel a growing emptiness inside you."))
			if(prob(2))
				affected_mob.emote("cough")
		if(4)
			if(prob(3))
				to_chat(affected_mob, span_danger("Your chest feels like it's going to cave in!"))
			if(prob(2))
				affected_mob.emote("cough")
			if(prob(2))
				affected_mob.emote("groan")
		if(5)
			if(prob(2))
				affected_mob.adjust_confusion(5 SECONDS)
				spawn_spacematter()

/** Creates the actual vacuum-producing spill at the host's current location. */
/datum/disease/paradise_mystic_malaise/proc/spawn_spacematter()
	var/turf/tile = get_turf(affected_mob)
	if(!tile)
		return null
	playsound(tile, 'sound/effects/splat.ogg', 50, TRUE)
	return new /obj/effect/decal/cleanable/vomit/paradise_spacematter(tile)

/** Unscoopable fifteen-second local atmosphere sink. */
/obj/effect/decal/cleanable/vomit/paradise_spacematter
	name = "spacematter vomit"
	desc = "Despite the hazard, it's dazzlingly beautiful. You should probably get away from it."
	icon_state = "vomitnebula_1"
	random_icon_states = list("vomitnebula_1", "vomitnebula_2", "vomitnebula_3", "vomitnebula_4")
	decal_reagent = null
	reagent_amount = 0
	/// Absolute expiration time; processing unregisters before deletion.
	var/expires_at

/obj/effect/decal/cleanable/vomit/paradise_spacematter/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	expires_at = world.time + 15 SECONDS
	START_PROCESSING(SSprocessing, src)

/obj/effect/decal/cleanable/vomit/paradise_spacematter/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/obj/effect/decal/cleanable/vomit/paradise_spacematter/attack_hand(mob/user, list/modifiers)
	return NONE

/obj/effect/decal/cleanable/vomit/paradise_spacematter/process(seconds_per_tick)
	var/turf/open/tile = get_turf(src)
	if(istype(tile))
		var/datum/gas_mixture/environment = tile.return_air()
		if(environment && environment.volume > 0)
			var/fraction = 1 - ((1 - min(1, 1500 / environment.volume)) ** seconds_per_tick)
			tile.remove_air(environment.total_moles() * fraction)
	if(world.time >= expires_at)
		visible_message(span_danger("[src] evaporates into nothingness!"))
		qdel(src)
