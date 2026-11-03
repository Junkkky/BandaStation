#define PARADISE_PLAGUE_RITUAL_TRAIT "paradise_plague_ritual"

/** Single-use artifact which raises a dead, inhabited human as a plague-bearing servant. */
/obj/item/plague_talisman
	name = "Plague Talisman"
	desc = "A vile rune, capable of raising the dead as plague-bearing creatures of destruction. The edges have sharp hooks."
	icon = 'modular_bandastation/paradise_zombies/icons/plague_talisman.dmi'
	icon_state = "plague_talisman"
	w_class = WEIGHT_CLASS_TINY
	/// The type of disease carried by this talisman's servant; rolled when the ritual starts.
	var/chosen_plague
	/// The corpse and caster involved in the current ritual, without retaining deleted bodies.
	var/datum/weakref/ritual_target_ref
	var/datum/weakref/ritual_caster_ref
	/// Identities must remain unchanged while the five-second ritual is pending.
	var/datum/weakref/ritual_victim_mind_ref
	var/datum/weakref/ritual_master_mind_ref
	/// The pending conversion timer, cancelled when the artifact is deleted.
	var/ritual_timer
	/// Once its plague has been bestowed, this single-use artifact cannot start another ritual.
	var/expended = FALSE

/obj/item/plague_talisman/Destroy()
	cancel_conversion(consume_spent = FALSE)
	return ..()

/obj/item/plague_talisman/attack(mob/living/carbon/human/victim, mob/living/carbon/human/necromancer)
	if(!istype(victim) || !istype(necromancer))
		return ..()
	raise_victim(victim, necromancer)

/** Validates the artifact interaction, returns the soul and reserves the corpse for a five-second ritual. */
/obj/item/plague_talisman/proc/raise_victim(mob/living/carbon/human/victim, mob/living/carbon/human/necromancer)
	if(expended || ritual_timer || !istype(victim) || !istype(necromancer) || !necromancer.mind || !necromancer.is_holding(src) || !necromancer.can_perform_action(victim))
		return FALSE
	if(victim.stat != DEAD)
		to_chat(necromancer, span_warning("This artifact can only affect the dead!"))
		return FALSE
	if(victim.mob_biotypes & MOB_ROBOTIC)
		to_chat(necromancer, span_warning("This one isn't vulnerable to this form of plague magic."))
		return FALSE
	if(HAS_TRAIT(victim, PARADISE_PLAGUE_RITUAL_TRAIT) || HAS_TRAIT(victim, TRAIT_PARADISE_PLAGUE_ZOMBIE) || victim.mind?.has_antag_datum(/datum/antagonist/wizard_minion/paradise_plague_zombie))
		to_chat(necromancer, span_warning("This one is already under the artifact's influence! Give it time."))
		return FALSE
	if(!return_soul(victim) || !victim.mind)
		to_chat(necromancer, span_warning("There is no soul connected to this body..."))
		return FALSE
	if(!ispath(chosen_plague, /datum/disease))
		chosen_plague = pick_disease()
	ritual_target_ref = WEAKREF(victim)
	ritual_caster_ref = WEAKREF(necromancer)
	ritual_victim_mind_ref = WEAKREF(victim.mind)
	ritual_master_mind_ref = WEAKREF(necromancer.mind)
	ADD_TRAIT(victim, PARADISE_PLAGUE_RITUAL_TRAIT, REF(src))
	expended = TRUE
	victim.visible_message(span_danger("[necromancer] places a vile rune upon [victim]'s lifeless forehead. The rune adheres to the flesh, and [victim]'s body rots and decays at unnatural speeds!"))
	for(var/datum/disease/infection as anything in victim.diseases?.Copy())
		if(!istype(infection, /datum/disease/paradise_zombie))
			infection.cure()
	var/datum/disease/paradise_zombie/zombie_infection = locate() in victim.diseases
	if(zombie_infection)
		qdel(zombie_infection)
	ADD_TRAIT(victim, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	ADD_TRAIT(victim, TRAIT_PARADISE_PLAGUE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	zombie_infection = new /datum/disease/paradise_zombie/wizard(chosen_plague, TRUE)
	zombie_infection.infect(victim, FALSE)
	zombie_infection.stage = 8
	zombie_infection.process_infection_cycle()
	ADD_TRAIT(necromancer, TRAIT_VIRUSIMMUNE, MAGIC_TRAIT)
	ADD_TRAIT(victim, TRAIT_VIRUSIMMUNE, PARADISE_ZOMBIE_TRAIT)
	necromancer.grant_language(/datum/language/paradise_zombie, ALL, LANGUAGE_MIND)
	playsound(victim, 'modular_bandastation/paradise_zombies/sound/mutate.ogg', 50, TRUE)
	ritual_timer = addtimer(CALLBACK(src, PROC_REF(finish_convert)), 5 SECONDS, TIMER_STOPPABLE)
	return TRUE

/** Returns an eligible player's ghost without replacing a soul which has moved to another body. */
/obj/item/plague_talisman/proc/return_soul(mob/living/carbon/human/victim)
	return victim.mind && (victim.client || victim.grab_ghost())

/** Revalidates both identities before binding and rejuvenating the already-transformed servant. */
/obj/item/plague_talisman/proc/finish_convert()
	ritual_timer = null
	var/mob/living/carbon/human/victim = ritual_target_ref?.resolve()
	var/mob/living/carbon/human/necromancer = ritual_caster_ref?.resolve()
	var/datum/mind/victim_mind = ritual_victim_mind_ref?.resolve()
	var/datum/mind/master_mind = ritual_master_mind_ref?.resolve()
	if(!istype(victim) || !istype(necromancer) || !victim_mind || !master_mind || victim.mind != victim_mind || necromancer.mind != master_mind || (victim.mob_biotypes & MOB_ROBOTIC) || !HAS_TRAIT_FROM(victim, PARADISE_PLAGUE_RITUAL_TRAIT, REF(src)) || victim_mind.has_antag_datum(/datum/antagonist/wizard_minion/paradise_plague_zombie))
		cancel_conversion()
		return FALSE
	var/datum/disease/paradise_zombie/wizard/infection = locate() in victim.diseases
	var/datum/component/paradise_zombie_regen/regeneration = victim.GetComponent(/datum/component/paradise_zombie_regen)
	if(!infection || !regeneration || !HAS_TRAIT(victim, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		cancel_conversion()
		return FALSE
	victim.grab_ghost()
	var/datum/antagonist/wizard_minion/paradise_plague_zombie/servant = new()
	servant.master_ref = WEAKREF(master_mind)
	servant.chosen_plague = chosen_plague
	var/datum/antagonist/wizard/wizard = master_mind.has_antag_datum(/datum/antagonist/wizard)
	if(wizard && !wizard.wiz_team)
		wizard.create_wiz_team()
	victim_mind.add_antag_datum(servant, wizard?.wiz_team)
	regeneration.zombie_rejuv()
	victim.setMaxHealth(200)
	victim.updatehealth()
	REMOVE_TRAIT(victim, PARADISE_PLAGUE_RITUAL_TRAIT, REF(src))
	victim.visible_message(span_danger("[victim] rises into a horrendous undead creature!"))
	log_combat(necromancer, victim, "raised as a plague zombie")
	qdel(src)
	return TRUE

/** Releases the reservation; bestowed plague remains, and its spent artifact cannot be reused after cancellation. */
/obj/item/plague_talisman/proc/cancel_conversion(consume_spent = TRUE)
	if(ritual_timer)
		deltimer(ritual_timer)
		ritual_timer = null
	var/mob/living/carbon/human/victim = ritual_target_ref?.resolve()
	if(victim)
		REMOVE_TRAIT(victim, PARADISE_PLAGUE_RITUAL_TRAIT, REF(src))
	ritual_target_ref = null
	ritual_caster_ref = null
	ritual_victim_mind_ref = null
	ritual_master_mind_ref = null
	if(consume_spent && expended)
		qdel(src)

/** The original thirteen plagues, without substituting unrelated diseases from the target build. */
/obj/item/plague_talisman/proc/pick_disease()
	var/static/list/possible_diseases = list(
		/datum/disease/beesease/paradise_plague,
		/datum/disease/cold9/paradise_plague,
		/datum/disease/fluspanish/paradise_plague,
		/datum/disease/paradise_kingstons_advanced,
		/datum/disease/dna_retrovirus/paradise_plague,
		/datum/disease/tuberculosis/paradise_plague,
		/datum/disease/anxiety/paradise_plague,
		/datum/disease/wizarditis/paradise_plague,
		/datum/disease/paradise_berserker,
		/datum/disease/paradise_appendicitis,
		/datum/disease/paradise_grut_gut,
		/datum/disease/paradise_wand_rot,
		/datum/disease/paradise_mystic_malaise,
	)
	return pick(possible_diseases)

/** A plague servant retains the native wizard-minion faction, HUD and protection objective. */
/datum/antagonist/wizard_minion/paradise_plague_zombie
	name = "Necromancy-risen Plague Zombie"
	/// The necromancer's character remains the objective target across body transfers.
	var/datum/weakref/master_ref
	/// Native creator bond, removed only if this antagonist still owns it.
	var/datum/weakref/creator_ref
	/// The disease bestowed upon this servant's claws.
	var/chosen_plague

/datum/antagonist/wizard_minion/paradise_plague_zombie/can_be_owned(datum/mind/new_owner)
	return master_ref?.resolve() && ispath(chosen_plague, /datum/disease) && ..()

/datum/antagonist/wizard_minion/paradise_plague_zombie/on_gain()
	var/datum/mind/master = master_ref?.resolve()
	if(master?.current)
		creator_ref = WEAKREF(master.current)
		owner.enslaved_to = creator_ref
		SEND_SIGNAL(owner.current, COMSIG_MOB_ENSLAVED_TO, master.current)
	return ..()

/datum/antagonist/wizard_minion/paradise_plague_zombie/on_removal()
	if(owner.enslaved_to == creator_ref)
		owner.enslaved_to = null
	return ..()

/datum/antagonist/wizard_minion/paradise_plague_zombie/Destroy()
	master_ref = null
	creator_ref = null
	return ..()

/datum/antagonist/wizard_minion/paradise_plague_zombie/create_objectives()
	var/datum/mind/master = master_ref?.resolve()
	if(!master)
		return
	var/datum/objective/protect/objective = new()
	objective.owner = owner
	objective.target = master
	objective.explanation_text = "Obey every order from and protect [master.name], even at the cost of your new life."
	objectives += objective

/datum/antagonist/wizard_minion/paradise_plague_zombie/greet()
	var/datum/mind/master = master_ref?.resolve()
	var/datum/disease/plague = new chosen_plague()
	to_chat(owner.current, span_userdanger("You have been raised into undeath by <b>[master?.name]</b>! Assist your master at all costs. You have been bestowed the following plague: [plague.name]!"))
	qdel(plague)
	owner.announce_objectives()

/** Five talismans in the original restricted runic belt. */
/obj/item/storage/belt/plague_talisman
	name = "Runic Belt"
	desc = "A belt designed to safely contain Plague Talismans. Better hope it doesn't start dripping..."
	icon_state = "soulstonebelt"
	inhand_icon_state = "soulstonebelt"
	worn_icon_state = "soulstonebelt"
	storage_type = /datum/storage/plague_talisman_belt

/obj/item/storage/belt/plague_talisman/PopulateContents()
	for(var/count in 1 to 5)
		new /obj/item/plague_talisman(src)

/** The runic belt accepts five talismans and no unrelated items. */
/datum/storage/plague_talisman_belt
	max_slots = 5

/datum/storage/plague_talisman_belt/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(/obj/item/plague_talisman)

/** Wizard spellbooks discover this artifact entry through the existing subtype registry. */
/datum/spellbook_entry/item/paradise_plague_talismans
	name = "Five Plague Talismans"
	desc = "Special engraved runes, used to raise the dead into plague-ridden, animated corpses."
	item_path = /obj/item/storage/belt/plague_talisman
	category = "Поддержка"
	cost = 1

/datum/spellbook_entry/item/paradise_plague_talismans/buy_spell(mob/living/carbon/human/user, obj/item/spellbook/book, log_buy = TRUE)
	. = ..()
	if(.)
		user.grant_language(/datum/language/paradise_zombie, ALL, LANGUAGE_MIND)

#undef PARADISE_PLAGUE_RITUAL_TRAIT
