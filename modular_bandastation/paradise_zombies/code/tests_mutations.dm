#ifdef UNIT_TESTS

/** Isolates outbreak state until every real infected host has completed its normal cleanup. */
/datum/unit_test/paradise_zombie_mutation_test
	parent_type = /datum/unit_test/paradise_zombie_combat
	abstract_type = /datum/unit_test/paradise_zombie_mutation_test
	/// Incoming round state, restored after parent teardown has deleted all allocated infected bodies.
	var/datum/paradise_zombie_mutation_progression/previous_progression

/datum/unit_test/paradise_zombie_mutation_test/New()
	. = ..()
	previous_progression = GLOB.paradise_zombie_mutation_progression
	GLOB.paradise_zombie_mutation_progression = new

/datum/unit_test/paradise_zombie_mutation_test/Destroy()
	. = ..()
	var/datum/paradise_zombie_mutation_progression/test_progression = GLOB.paradise_zombie_mutation_progression
	GLOB.paradise_zombie_mutation_progression = previous_progression
	previous_progression = null
	qdel(test_progression)
	return .

/** Creates an ordinary mature zombie through actual infection and mind initialization. */
/datum/unit_test/paradise_zombie_mutation_test/proc/make_zombie(turf/location)
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent, location)
	host.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(host.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The mutation fixture failed to contract its real infection.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(host, TRAIT_PARADISE_ZOMBIE), "The mutation fixture did not fully transform.")
	TEST_ASSERT_NOTNULL(host.GetComponent(/datum/component/paradise_zombie_mutation), "The mature fixture did not acquire its real mutation controller.")
	return host

/** Unlocks all tiers with eight real infected minds, then applies the requested production form. */
/datum/unit_test/paradise_zombie_mutation_test/proc/make_mutant(form_id)
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	TEST_ASSERT_NOTNULL(host, "The main mutation fixture was not created.")
	for(var/support_index in 1 to 7)
		TEST_ASSERT_NOTNULL(make_zombie(run_loc_floor_top_right), "A supporting infection fixture was not created.")
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT(controller.apply_form(form_id), "The real mutation controller rejected the fixture form [form_id].")
	TEST_ASSERT_EQUAL(controller.form?.id, form_id, "The fixture controller applied the wrong form.")
	return host

/** Mutation drops removable equipment, refuses a stuck item and still permits ordinary restraint. */
/datum/unit_test/paradise_zombie_mutation_equipment
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_equipment/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	for(var/support_index in 1 to 7)
		make_zombie(run_loc_floor_top_right)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	var/obj/item/storage/backpack/backpack = allocate(/obj/item/storage/backpack)
	var/obj/item/clothing/glasses/sunglasses/glasses = allocate(/obj/item/clothing/glasses/sunglasses)
	TEST_ASSERT(host.equip_to_slot_if_possible(backpack, ITEM_SLOT_BACK, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The pre-mutation zombie could not wear its backpack.")
	TEST_ASSERT(host.equip_to_slot_if_possible(glasses, ITEM_SLOT_EYES, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The pre-mutation zombie could not wear its glasses.")
	ADD_TRAIT(backpack, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!controller.apply_form("twitcher"), "Mutation bypassed equipment which could not be removed.")
	TEST_ASSERT_NULL(controller.form, "A rejected equipment check still applied a form.")
	TEST_ASSERT_NULL(GLOB.paradise_zombie_mutation_progression.fixed_choices[WEAKREF(host.mind)], "A rejected equipment check permanently spent the mind's choice.")
	REMOVE_TRAIT(backpack, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(controller.apply_form("twitcher"), "The real controller rejected removable equipment.")
	TEST_ASSERT_EQUAL(backpack.loc, get_turf(host), "Mutation deleted or retained its backpack instead of dropping it.")
	TEST_ASSERT_EQUAL(glasses.loc, get_turf(host), "Mutation deleted or retained its glasses instead of dropping them.")
	TEST_ASSERT(!host.equip_to_slot_if_possible(backpack, ITEM_SLOT_BACK, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "A mutated body could equip ordinary clothing again.")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(host.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "Mutation's clothing restriction also blocked handcuffs.")
	TEST_ASSERT_EQUAL(host.handcuffed, cuffs, "The real cuff item did not occupy the restraint slot.")
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation), "Cure left the mutation controller attached.")
	TEST_ASSERT(host.equip_to_slot_if_possible(backpack, ITEM_SLOT_BACK, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "Cure left the mutation's clothing restriction behind.")

/** Ordinary death keeps a physical mutation; surgical cure reverses only its own additive bonuses. */
/datum/unit_test/paradise_zombie_mutation_death_and_surgery
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_death_and_surgery/Run()
	var/mob/living/carbon/human/host = make_mutant("brute")
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	var/datum/component/paradise_zombie_mutation_body/renderer = controller.body_renderer
	var/datum/dna/original_dna = host.dna
	var/datum/species/original_species = host.dna.species
	var/list/original_limbs = host.get_bodyparts()
	original_limbs = original_limbs.Copy()
	var/bonus = controller.applied_health_bonus
	var/base_health = host.maxHealth - bonus
	host.setMaxHealth(host.maxHealth + 25)
	host.updatehealth()
	host.death()
	TEST_ASSERT_EQUAL(host.GetComponent(/datum/component/paradise_zombie_mutation), controller, "Ordinary death removed the body's chosen mutation.")
	TEST_ASSERT_EQUAL(controller.body_renderer, renderer, "Ordinary death replaced the mutation's real renderer.")
	var/list/progress = GLOB.paradise_zombie_mutation_progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 1, "A corpse prematurely released its rare mutation slot.")
	host.timeofdeath = world.time - 15 SECONDS
	var/datum/component/paradise_zombie_regen/regeneration = host.GetComponent(/datum/component/paradise_zombie_regen)
	regeneration.process(1)
	TEST_ASSERT_NOTEQUAL(host.stat, DEAD, "The mutated zombie failed its ordinary Paradise resurrection.")
	TEST_ASSERT_EQUAL(controller.form.id, "brute", "Resurrection forgot the body's selected form.")
	TEST_ASSERT_EQUAL(host.maxHealth, base_health + bonus + 25, "Resurrection lost an unrelated maximum-health modifier.")
	var/obj/item/bodypart/head/head = host.get_bodypart(BODY_ZONE_HEAD)
	head.add_surgical_state(SURGERY_SKIN_OPEN | SURGERY_BONE_SAWED)
	var/obj/item/bodypart/arm = host.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 11, burn = 3, forced = TRUE, wound_bonus = CANT_WOUND)
	var/brute_before_cure = arm.brute_dam
	var/burn_before_cure = arm.burn_dam
	var/obj/item/organ/paradise_zombie_tumor/tumor = host.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "The mutated body lost its surgical cure target.")
	tumor.Remove(host)
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in host.diseases, "Tumor removal did not cure the underlying infection.")
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation_body), "Surgical cure left DS13 body overlays active.")
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation), "Surgical cure left the mutation's physiology active.")
	TEST_ASSERT_EQUAL(host.maxHealth, base_health + 25, "Surgical cure overwrote an independent maximum-health change.")
	TEST_ASSERT_EQUAL(host.dna, original_dna, "Mutation lifecycle replaced the host's DNA datum.")
	TEST_ASSERT_EQUAL(host.dna.species, original_species, "Mutation lifecycle replaced the host's species datum.")
	for(var/obj/item/bodypart/limb as anything in original_limbs)
		TEST_ASSERT_EQUAL(limb.owner, host, "Mutation or cure replaced an original physical limb.")
	TEST_ASSERT_EQUAL(arm.brute_dam, brute_before_cure, "Removing a visual mutation healed unrelated brute injury.")
	TEST_ASSERT_EQUAL(arm.burn_dam, burn_before_cure, "Removing a visual mutation healed unrelated burn injury.")
	TEST_ASSERT(LIMB_HAS_SURGERY_STATE(head, SURGERY_SKIN_OPEN | SURGERY_BONE_SAWED), "Mutation cleanup closed the surgical opening.")
	progress = GLOB.paradise_zombie_mutation_progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 0, "Surgical cure did not release the body's rare mutation slot.")
	TEST_ASSERT_EQUAL(GLOB.paradise_zombie_mutation_progression.fixed_choices[WEAKREF(host.mind)], "brute", "Surgical cure forgot the mind's permanent specialization.")

/** A form stays on its old body, while the mind keeps its choice and direct disease deletion cleans the new body. */
/datum/unit_test/paradise_zombie_mutation_mind_and_force_clear
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_mind_and_force_clear/Run()
	var/mob/living/carbon/human/old_body = make_mutant("hunter")
	var/datum/mind/moving_mind = old_body.mind
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(new_body.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The mind-transfer destination failed to contract its real infection.")
	infection.stage = 8
	infection.process_infection_cycle()
	var/datum/component/paradise_zombie_mutation/new_controller = new_body.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT_NOTNULL(new_controller, "The fully infected mindless destination had no mutation controller.")
	moving_mind.transfer_to(new_body)
	var/datum/component/paradise_zombie_mutation/old_controller = old_body.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT_EQUAL(old_controller.form.id, "hunter", "Mind transfer removed the old body's physical mutation.")
	TEST_ASSERT_NULL(new_controller.form, "Mind transfer automatically copied a physical mutation into the destination.")
	TEST_ASSERT(!new_controller.apply_form("brute"), "Mind transfer let an already specialized mind select another form.")
	TEST_ASSERT(new_controller.apply_form("hunter"), "The same mind could not select its existing specialization in a new infected body.")
	var/new_max_health = new_body.maxHealth
	var/new_bonus = new_controller.applied_health_bonus
	var/datum/disease/paradise_zombie/old_infection = locate() in old_body.diseases
	old_infection.cure()
	TEST_ASSERT_EQUAL(new_controller.form.id, "hunter", "Curing the abandoned body removed the new body's mutation.")
	qdel(infection)
	TEST_ASSERT_NULL(new_body.GetComponent(/datum/component/paradise_zombie_mutation), "Direct disease deletion left the physical mutation controller behind.")
	TEST_ASSERT_NULL(new_body.GetComponent(/datum/component/paradise_zombie_mutation_body), "Direct disease deletion left mutated body overlays behind.")
	TEST_ASSERT_EQUAL(new_body.maxHealth, new_max_health - new_bonus, "Direct disease deletion retained the mutation's health bonus.")
	TEST_ASSERT_EQUAL(GLOB.paradise_zombie_mutation_progression.fixed_choices[WEAKREF(moving_mind)], "hunter", "Direct disease deletion erased the mind's fixed choice.")
	var/datum/disease/paradise_zombie/reinfection = new
	TEST_ASSERT(new_body.ForceContractDisease(reinfection, make_copy = FALSE, del_on_fail = TRUE), "A cured body could not be reinfected through the real disease boundary.")
	reinfection.stage = 8
	reinfection.process_infection_cycle()
	new_controller = new_body.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT_NOTNULL(new_controller, "Reinfection did not recreate the mutation controller.")
	TEST_ASSERT(!new_controller.apply_form("brute"), "Cure and reinfection reset the mind's permanent specialization.")
	TEST_ASSERT(new_controller.apply_form("hunter"), "A cured and reinfected mind could not regain its permitted specialization.")
/** Mutation exposure retains an independently owned researched strain and refuses protected or invalid sources. */
/datum/unit_test/paradise_zombie_mutation_exposure
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_exposure/Run()
	var/mob/living/carbon/human/source = make_mutant("spitter")
	var/datum/disease/paradise_zombie/source_infection = locate() in source.diseases
	source_infection.cure_stage = 2
	source_infection.spreading_modifier = INFINITY
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.satiety = 0
	victim.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/alpha, 1)
	TEST_ASSERT(!paradise_zombie_mutation_expose(victim, source), "A mutation exposed a victim protected by Alpha.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in victim.diseases, "A blocked Alpha exposure installed an infection anyway.")
	victim.reagents.remove_reagent(/datum/reagent/medicine/paradise_zombie_cure/alpha, 1)
	TEST_ASSERT(paradise_zombie_mutation_expose(victim, source), "An eligible mutation could not transmit its owned strain.")
	var/datum/disease/paradise_zombie/transmitted = locate() in victim.diseases
	TEST_ASSERT_NOTNULL(transmitted, "The actual transmission did not install a disease on the victim.")
	TEST_ASSERT_NOTEQUAL(transmitted, source_infection, "Transmission shared a single disease datum between two bodies.")
	TEST_ASSERT_EQUAL(transmitted.affected_mob, victim, "The transmitted strain retained the source body as its owner.")
	TEST_ASSERT_EQUAL(transmitted.cure_stage, 2, "Transmission discarded the source strain's completed research sequence.")
	TEST_ASSERT_EQUAL(transmitted.spreading_modifier, INFINITY, "Transmission discarded the source strain's spread properties.")
	transmitted.cure_stage = 3
	TEST_ASSERT_EQUAL(source_infection.cure_stage, 2, "Researching a transmitted strain modified the source's disease instance.")
	var/mob/living/carbon/human/second_victim = allocate(/mob/living/carbon/human/consistent)
	second_victim.satiety = 0
	ADD_TRAIT(source, TRAIT_PARADISE_NPC_ZOMBIE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(source, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!paradise_zombie_mutation_expose(second_victim, source), "An ordinary noninfectious NPC source transmitted a mutation strain.")
	REMOVE_TRAIT(source, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE, TRAIT_SOURCE_UNIT_TESTS)
	REMOVE_TRAIT(source, TRAIT_PARADISE_NPC_ZOMBIE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(source, TRAIT_PARADISE_PLAGUE_ZOMBIE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!paradise_zombie_mutation_expose(second_victim, source), "A wizard-plague source entered ordinary mutation transmission.")
	REMOVE_TRAIT(source, TRAIT_PARADISE_PLAGUE_ZOMBIE, TRAIT_SOURCE_UNIT_TESTS)
	source_infection.cure()
	TEST_ASSERT(!paradise_zombie_mutation_expose(second_victim, source), "A cured former mutant could still transmit the plague.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in second_victim.diseases, "An excluded source still installed a disease as a side effect.")

/** Rejects the actual unequip after canUnEquip has passed, exercising reservation rollback. */
/datum/component/paradise_zombie_test_block_unequip

/datum/component/paradise_zombie_test_block_unequip/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ITEM_PRE_UNEQUIP, PROC_REF(block_unequip))

/datum/component/paradise_zombie_test_block_unequip/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ITEM_PRE_UNEQUIP)

/datum/component/paradise_zombie_test_block_unequip/proc/block_unequip()
	SIGNAL_HANDLER
	return COMPONENT_ITEM_BLOCK_UNEQUIP

/** A final equipment-drop failure releases the claimed slot without committing the mind's choice. */
/datum/unit_test/paradise_zombie_mutation_drop_rollback
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_drop_rollback/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	for(var/support_index in 1 to 7)
		make_zombie(run_loc_floor_top_right)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	var/obj/item/storage/backpack/backpack = allocate(/obj/item/storage/backpack)
	TEST_ASSERT(host.equip_to_slot_if_possible(backpack, ITEM_SLOT_BACK, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The drop-rollback fixture could not wear its backpack.")
	var/datum/component/paradise_zombie_test_block_unequip/blocker = backpack.AddComponent(/datum/component/paradise_zombie_test_block_unequip)
	TEST_ASSERT(controller.can_begin(), "The final-drop fixture incorrectly failed at the preliminary equipment check.")
	TEST_ASSERT(!controller.apply_form("brute"), "Mutation bypassed a real PRE_UNEQUIP rejection after claiming its slot.")
	TEST_ASSERT(!QDELETED(backpack) && backpack.loc == host, "A failed mutation deleted or moved the blocked equipment.")
	TEST_ASSERT_NULL(controller.form, "A failed final equipment drop retained a mutation form.")
	TEST_ASSERT_NULL(controller.body_renderer, "A failed final equipment drop installed a mutant body.")
	TEST_ASSERT_NULL(GLOB.paradise_zombie_mutation_progression.fixed_choices[WEAKREF(host.mind)], "A failed final equipment drop permanently fixed the mind's choice.")
	var/list/progress = GLOB.paradise_zombie_mutation_progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 0, "A failed final equipment drop leaked its special-form reservation.")
	TEST_ASSERT_EQUAL(progress["brute_claimed"], 0, "A failed final equipment drop leaked its Brute reservation.")
	qdel(blocker)
	TEST_ASSERT(controller.apply_form("brute"), "Releasing the failed drop did not permit a later valid mutation.")

/** An item stuck in a hand survives infection and blocks mutation, while the zombie's abstract claws do not. */
/datum/unit_test/paradise_zombie_mutation_stuck_held_item
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_stuck_held_item/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	host.mind_initialize()
	var/obj/item/crowbar/tool = allocate(/obj/item/crowbar)
	TEST_ASSERT(host.put_in_hands(tool), "The ordinary fixture could not pick up its tool before infection.")
	ADD_TRAIT(tool, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/disease/paradise_zombie/infection = new()
	TEST_ASSERT(host.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The fixture could not contract its real infection while holding the stuck tool.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(host.is_holding(tool), "Ordinary zombification unexpectedly removed the stuck tool.")
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT_NOTNULL(controller, "The fully transformed fixture did not acquire a mutation controller.")
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 2 MINUTES
	TEST_ASSERT(!controller.can_begin(), "Mutation ignored a nonremovable item already held before infection.")
	TEST_ASSERT(!controller.apply_form("twitcher"), "Mutation applied a form without removing the stuck tool.")
	TEST_ASSERT_NULL(controller.form, "The blocked hand check still applied a physical mutation.")
	TEST_ASSERT_NULL(GLOB.paradise_zombie_mutation_progression.fixed_choices[WEAKREF(host.mind)], "A stuck held item permanently spent the mind's mutation choice.")
	var/list/progress = GLOB.paradise_zombie_mutation_progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 0, "A stuck held item consumed a special-form slot.")
	REMOVE_TRAIT(tool, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(host.dropItemToGround(tool), "The released tool could not be dropped normally.")
	var/datum/action/cooldown/paradise_zombie_claws/claw_action = locate() in host.actions
	TEST_ASSERT_NOTNULL(claw_action, "The infected fixture did not receive its ordinary claw action.")
	TEST_ASSERT(claw_action.Activate(), "The ordinary action could not extend its abstract claws.")
	TEST_ASSERT(controller.can_begin() && controller.apply_form("twitcher"), "The zombie's abstract claws incorrectly blocked a valid mutation.")

#endif
