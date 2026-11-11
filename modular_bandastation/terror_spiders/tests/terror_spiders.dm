/datum/unit_test/terror_spider_castes

/datum/unit_test/terror_spider_castes/Run()
	var/mob/living/basic/spider/giant/regular = allocate(/mob/living/basic/spider/giant/guard)
	var/mob/living/basic/spider/giant/terror/red/broodmate = allocate(/mob/living/basic/spider/giant/terror/red)
	var/list/castes = subtypesof(/mob/living/basic/spider/giant/terror)
	var/list/action_states = icon_states('modular_bandastation/terror_spiders/icons/actions.dmi')
	TEST_ASSERT_EQUAL(length(castes), 14, "The Terror Spider roster must contain fourteen castes.")
	for(var/caste in castes)
		var/mob/living/basic/spider/giant/terror/spider = allocate(caste)
		var/list/states = icon_states(spider.icon)
		TEST_ASSERT(spider.icon_living in states, "[caste] has no living icon.")
		TEST_ASSERT(spider.icon_dead in states, "[caste] has no death icon.")
		TEST_ASSERT(spider.faction_check_atom(broodmate), "[caste] is not allied to terror spiders.")
		TEST_ASSERT(!spider.faction_check_atom(regular), "[caste] was allied to ordinary spiders.")
		for(var/datum/action/ability as anything in spider.actions)
			if(ability.button_icon == 'modular_bandastation/terror_spiders/icons/actions.dmi')
				TEST_ASSERT(ability.button_icon_state in action_states, "[ability.type] has no HUD icon.")
				TEST_ASSERT(ability.background_icon_state in action_states, "[ability.type] has no HUD background.")

	var/mob/living/basic/spider/giant/terror/brown/brown = allocate(/mob/living/basic/spider/giant/terror/brown)
	TEST_ASSERT(!HAS_TRAIT(brown, TRAIT_WEB_WEAVER), "The breacher should not spin webs.")
	TEST_ASSERT(HAS_TRAIT(brown, TRAIT_VENTCRAWLER_ALWAYS), "The breacher cannot enter an open vent.")
	var/mob/living/basic/spider/giant/terror/prince/prince = allocate(/mob/living/basic/spider/giant/terror/prince)
	TEST_ASSERT(!HAS_TRAIT(prince, TRAIT_VENTCRAWLER_ALWAYS), "The prince can enter a vent.")
	TEST_ASSERT(locate(/datum/action/cooldown/mob_cooldown/terror_prince_slam) in prince.actions, "The Prince should have his area slam.")
	TEST_ASSERT(!HAS_TRAIT(prince, TRAIT_WEB_WEAVER), "The Prince should not spin webs.")

	var/datum/action/cooldown/mob_cooldown/terror_knight_mode/attack/attack = locate() in broodmate.actions
	var/datum/action/cooldown/mob_cooldown/terror_knight_mode/defense/defense = locate() in broodmate.actions
	TEST_ASSERT_NOTNULL(attack, "The Knight needs an attack stance.")
	TEST_ASSERT_NOTNULL(defense, "The Knight needs a defense stance.")
	TEST_ASSERT(attack.Activate(), "The Knight failed to enter attack stance.")
	TEST_ASSERT_EQUAL(broodmate.melee_damage_lower, 30, "Attack stance did not strengthen the bite.")
	TEST_ASSERT(broodmate.speed < initial(broodmate.speed), "Attack stance did not speed up the Knight.")
	TEST_ASSERT(defense.Activate(), "The Knight failed to switch to defense stance.")
	TEST_ASSERT_EQUAL(broodmate.terror_damage_coefficients[BRUTE], 0.4, "Defense stance did not reduce incoming brute damage.")
	TEST_ASSERT_EQUAL(broodmate.melee_damage_upper, 10, "Defense stance did not weaken the bite.")
	broodmate.reset_terror_stance()
	TEST_ASSERT_EQUAL(broodmate.melee_damage_upper, 15, "The Knight did not return to his normal bite when the stance ended.")
	TEST_ASSERT_EQUAL(broodmate.speed, initial(broodmate.speed), "The Knight did not return to normal speed.")

	var/mob/living/basic/spider/giant/terror/gray/gray = allocate(/mob/living/basic/spider/giant/terror/gray)
	var/obj/structure/spider/stickyweb/terror/transparent/web = allocate(/obj/structure/spider/stickyweb/terror/transparent)
	TEST_ASSERT_EQUAL(gray.icon_state, "terror_gray_cloaked", "A newly spun web did not hide the gray spider.")
	TEST_ASSERT(gray.icon_state in icon_states(gray.icon), "The gray spider has no cloak sprite.")
	var/mob/living/carbon/human/webbed_prey = allocate(/mob/living/carbon/human)
	gray.melee_damage_upper = gray.melee_damage_lower
	gray.melee_attack(webbed_prey, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(webbed_prey.get_brute_loss(), gray.melee_damage_lower * 3, "The Lurker's bite did not triple while standing on a web.")
	qdel(web)
	TEST_ASSERT_EQUAL(gray.icon_state, initial(gray.icon_living), "A removed web still concealed the gray spider.")

	var/mob/living/basic/spider/giant/terror/black/black = allocate(/mob/living/basic/spider/giant/terror/black)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human)
	black.melee_attack(prey, ignore_cooldown = TRUE)
	black.melee_attack(prey, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(prey.reagents.get_reagent_amount(/datum/reagent/toxin/terror_black_venom), 40, "Two exposed bites did not stack Widow venom.")
	TEST_ASSERT(locate(/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/venom) in black.actions, "The Widow is missing her venom spit.")
	TEST_ASSERT(locate(/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/smoke) in black.actions, "The Widow is missing her smoke spit.")

	var/mob/living/basic/spider/giant/terror/reaper/reaper = allocate(/mob/living/basic/spider/giant/terror/reaper)
	var/blood_before_bite = prey.blood_volume
	reaper.adjust_brute_loss(20, forced = TRUE)
	TEST_ASSERT(reaper.melee_attack(prey, ignore_cooldown = TRUE), "The Reaper failed to bite a living victim.")
	TEST_ASSERT_EQUAL(reaper.get_brute_loss(), 5, "The Reaper's bite did not heal the expected damage.")
	TEST_ASSERT_EQUAL(prey.blood_volume, blood_before_bite - 25, "The Reaper's bite did not draw blood.")
	reaper.Life(2)
	TEST_ASSERT_EQUAL(reaper.get_brute_loss(), 6, "The Reaper did not lose health without feeding.")

	var/mob/living/basic/spider/giant/terror/queen/queen = allocate(/mob/living/basic/spider/giant/terror/queen)
	var/mob/living/basic/spider/giant/terror/purple/purple = allocate(/mob/living/basic/spider/giant/terror/purple)
	purple.terror_queen_ref = WEAKREF(queen)
	purple.queen_separation = 2 MINUTES
	purple.Life(1)
	TEST_ASSERT_EQUAL(purple.queen_separation, 0, "Returning to the queen did not restore the purple spider's bond.")
	queen.moveToNullspace()
	purple.queen_separation = 3 MINUTES - 2 SECONDS
	purple.Life(1)
	TEST_ASSERT_EQUAL(purple.melee_damage_upper, 25, "The Guardian weakened before three minutes apart.")
	purple.Life(1)
	TEST_ASSERT_EQUAL(purple.melee_damage_upper, 10, "The Guardian did not weaken after three minutes apart.")
	TEST_ASSERT(purple.terror_degenerating, "The Guardian did not start degenerating after losing its bond.")
	var/datum/action/cooldown/mob_cooldown/terror_guardian_membrane/membrane = locate() in purple.actions
	TEST_ASSERT_NOTNULL(membrane, "The Guardian needs a membrane ability.")
	TEST_ASSERT(membrane.Activate(), "The Guardian failed to create a membrane.")
	var/obj/effect/forcefield/terror_membrane/barrier = locate() in get_turf(purple)
	TEST_ASSERT_NOTNULL(barrier, "The Guardian's membrane was not created.")
	TEST_ASSERT(barrier.CanAllowThrough(reaper, NORTH), "The membrane blocked a Terror Spider.")
	TEST_ASSERT(!barrier.CanAllowThrough(prey, NORTH), "The membrane admitted a human.")

/datum/unit_test/terror_spider_brood
	normal_floor_required = TRUE

/datum/unit_test/terror_spider_brood/Run()
	var/mob/living/basic/spider/giant/terror/green/green = allocate(/mob/living/basic/spider/giant/terror/green)
	var/datum/action/cooldown/mob_cooldown/lay_eggs/terror/lay = locate() in green.actions
	var/datum/action/cooldown/mob_cooldown/wrap/terror/wrap = locate() in green.actions
	TEST_ASSERT_NOTNULL(lay, "A green spider should be able to lay eggs.")
	TEST_ASSERT_NOTNULL(wrap, "A green spider should be able to wrap corpses.")

	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human)
	TEST_ASSERT(!wrap.Activate(prey), "A living victim must never be wrapped.")
	wrap.wrap_target(prey)
	TEST_ASSERT_EQUAL(green.fed, 0, "A living victim must not grant a meal after the wrap delay.")
	prey.death()
	wrap.wrap_target(prey)
	TEST_ASSERT_EQUAL(green.fed, 1, "Wrapping a corpse must grant one meal.")
	prey.forceMove(run_loc_floor_bottom_left)
	wrap.wrap_target(prey)
	TEST_ASSERT_EQUAL(green.fed, 1, "The same corpse must not grant a second meal.")
	var/mob/living/carbon/human/other_prey = allocate(/mob/living/carbon/human)
	other_prey.death()
	wrap.wrap_target(other_prey)
	TEST_ASSERT(!lay.IsAvailable(), "Two meals should not suffice for a clutch.")
	var/mob/living/carbon/human/third_prey = allocate(/mob/living/carbon/human)
	third_prey.death()
	wrap.wrap_target(third_prey)
	TEST_ASSERT_EQUAL(green.fed, 3, "The Healer must count three distinct meals.")
	TEST_ASSERT(lay.IsAvailable(), "Three distinct corpses should unlock a clutch.")

	var/datum/dynamic_ruleset/midround/spiders/ruleset = allocate(/datum/dynamic_ruleset/midround/spiders)
	var/list/low_population = ruleset.get_founders(31)
	var/list/mid_population = ruleset.get_founders(40)
	var/list/high_population = ruleset.get_founders(50)
	TEST_ASSERT_EQUAL(ruleset.min_pop, 31, "The spider event must start above 30 players.")
	TEST_ASSERT_EQUAL(low_population[/mob/living/basic/spider/giant/terror/white], 2, "Low population should get two Defilers or Princesses.")
	TEST_ASSERT_EQUAL(mid_population[/mob/living/basic/spider/giant/terror/queen/princess], 3, "Mid population should get three Defilers or Princesses.")
	TEST_ASSERT_EQUAL(high_population[/mob/living/basic/spider/giant/terror/queen], 1, "High population should get one Queen or Prince.")
	TEST_ASSERT_EQUAL(high_population[/mob/living/basic/spider/giant/terror/prince], 1, "High population should get one Queen or Prince.")

	var/obj/effect/mob_spawn/ghost_role/spider/terror/clutch = allocate(
		/obj/effect/mob_spawn/ghost_role/spider/terror,
		run_loc_floor_bottom_left,
		/mob/living/basic/spider/giant/terror/green,
		"Guard the nest.",
	)
	TEST_ASSERT_EQUAL(clutch.uses, 1, "A clutch should produce only one spider.")
	TEST_ASSERT_EQUAL(clutch.mob_type, green.type, "The clutch was not configured with the chosen caste.")
	TEST_ASSERT(!clutch.allow_spawn(null, silent = TRUE), "Immature eggs can be claimed.")
	clutch.process(100)
	TEST_ASSERT(clutch.allow_spawn(null, silent = TRUE), "Mature eggs cannot be claimed.")
	var/obj/structure/spider/eggcluster/physical_clutch = clutch.egg
	green.mind_initialize()
	var/datum/antagonist/spider/terror/panel_role = allocate(/datum/antagonist/spider/terror)
	TEST_ASSERT(panel_role.show_in_antagpanel && panel_role.can_be_owned(green.mind), "Traitor Panel should offer the terror spider role.")
	clutch.special(green)
	TEST_ASSERT_EQUAL(green.directive, "Guard the nest.", "The hatched spider did not inherit its directive.")
	var/datum/antagonist/spider/terror/hatched_role = green.mind.has_antag_datum(/datum/antagonist/spider/terror)
	TEST_ASSERT_NOTNULL(hatched_role, "The spawner did not assign the distinct terror spider role.")
	TEST_ASSERT_EQUAL(hatched_role.directive, green.directive, "The antagonist role did not inherit the brood directive.")
	TEST_ASSERT(!panel_role.can_be_owned(green.mind), "Traitor Panel should reject a duplicate terror spider role.")
	TEST_ASSERT(QDELETED(physical_clutch), "Hatched eggs must disappear.")
	TEST_ASSERT(!QDELETED(clutch), "Hatching deleted the spawner before it could send COMSIG_GHOSTROLE_SPAWNED.")

	var/mob/living/basic/spider/giant/terror/queen/princess/princess = allocate(/mob/living/basic/spider/giant/terror/queen/princess)
	var/datum/weakref/princess_ref = WEAKREF(princess)
	var/obj/structure/spider/eggcluster/terror/brood/royal_clutch = allocate(
		/obj/structure/spider/eggcluster/terror/brood,
		run_loc_floor_bottom_left,
		/mob/living/basic/spider/giant/terror/purple,
		"Guard the princess.",
		princess_ref,
		2,
	)
	var/list/brood_counts = count_terror_brood(princess_ref)
	TEST_ASSERT_EQUAL(brood_counts["total"], 2, "Unhatched eggs did not count toward the royal brood cap.")
	royal_clutch.amount_grown = 100
	royal_clutch.process(2)
	TEST_ASSERT(QDELETED(royal_clutch), "A hatched royal clutch did not disappear.")
	brood_counts = count_terror_brood(princess_ref)
	TEST_ASSERT_EQUAL(brood_counts["total"], 2, "A two-egg royal clutch did not produce two linked spiderlings.")
	var/mob/living/basic/spider/growing/spiderling/terror/royal_spiderling = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(royal_spiderling, "The royal clutch did not produce a spiderling.")
	TEST_ASSERT_EQUAL(royal_spiderling.grow_as, /mob/living/basic/spider/giant/terror/purple, "The royal clutch spawned the wrong caste.")
	TEST_ASSERT_EQUAL(royal_spiderling.directive, "Guard the princess.", "The royal spiderling did not inherit its directive.")

/datum/unit_test/terror_spider_wall_breaching
	/// Restore the shared floor even if an assertion aborts the breach.
	var/turf/test_wall

/datum/unit_test/terror_spider_wall_breaching/Destroy()
	test_wall?.ChangeTurf(/turf/open/indestructible)
	test_wall = null
	return ..()

/datum/unit_test/terror_spider_wall_breaching/Run()
	test_wall = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/wall)
	var/turf/spider_turf = get_step(test_wall, EAST)
	var/mob/living/basic/spider/giant/terror/red/knight = allocate(__IMPLIED_TYPE__, spider_turf)
	knight.ai_controller.force_ai_off()
	var/started_at = world.time
	knight.UnarmedAttack(test_wall, proximity_flag = TRUE)
	TEST_ASSERT(test_wall.density, "A Knight broke the wall immediately.")
	TEST_ASSERT_NULL(test_wall.GetComponent(/datum/component/torn_wall), "A Knight damaged the wall without waiting for a strike.")
	UNTIL(test_wall.GetComponent(/datum/component/torn_wall) || world.time >= started_at + 10 SECONDS)
	var/datum/component/torn_wall/cracks = test_wall.GetComponent(/datum/component/torn_wall)
	TEST_ASSERT_NOTNULL(cracks, "A Knight did not crack the wall after the first strike.")
	TEST_ASSERT_EQUAL(cracks.current_stage, 0, "A Knight skipped the first damage stage.")
	TEST_ASSERT(world.time >= started_at + 2 SECONDS, "The first strike took less than two seconds.")
	UNTIL(!test_wall.density || world.time >= started_at + 10 SECONDS)
	TEST_ASSERT(!test_wall.density, "A Knight did not complete the three-strike breach.")
	TEST_ASSERT(world.time >= started_at + 6 SECONDS, "A full breach took less than six seconds.")

	test_wall = test_wall.ChangeTurf(/turf/closed/wall/r_wall)
	knight.UnarmedAttack(test_wall, proximity_flag = TRUE)
	TEST_ASSERT(!DOING_INTERACTION(knight, /datum/element/wall_tearer), "A Knight started breaching a reinforced wall.")
	knight.moveToNullspace()
	var/mob/living/basic/spider/giant/terror/brown/destroyer = allocate(__IMPLIED_TYPE__, spider_turf)
	destroyer.ai_controller.force_ai_off()
	started_at = world.time
	destroyer.melee_attack(test_wall)
	TEST_ASSERT(test_wall.density, "A Destroyer broke the reinforced wall immediately.")
	UNTIL(test_wall.GetComponent(/datum/component/torn_wall) || world.time >= started_at + 10 SECONDS)
	cracks = test_wall.GetComponent(/datum/component/torn_wall)
	TEST_ASSERT_NOTNULL(cracks, "A Destroyer did not crack the reinforced wall.")
	TEST_ASSERT(world.time >= started_at + 4 SECONDS, "The first reinforced strike took less than four seconds.")
	destroyer.forceMove(get_step(spider_turf, EAST))
	UNTIL(!DOING_INTERACTION(destroyer, /datum/element/wall_tearer) || world.time >= started_at + 10 SECONDS)
	TEST_ASSERT(!DOING_INTERACTION(destroyer, /datum/element/wall_tearer), "Movement did not interrupt breaching.")
	TEST_ASSERT(test_wall.density && cracks.current_stage == 0, "The interrupted strike advanced the damage stage.")

/datum/unit_test/terror_spider_parasite

/datum/unit_test/terror_spider_parasite/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human)
	TEST_ASSERT(host.try_implant_terror_eggs(), "The parasite could not infect an exposed host.")
	TEST_ASSERT(!host.try_implant_terror_eggs(), "A host must only carry one clutch.")
	var/obj/item/organ/terror_eggs/embryo = host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG)
	TEST_ASSERT(istype(embryo), "Infection did not put an egg in the surgical parasite slot.")

	embryo.egg_progress = 120
	embryo.Remove(host)
	embryo.hatch_egg()
	TEST_ASSERT_NULL(locate(/mob/living/basic/spider/growing/spiderling/terror) in run_loc_floor_bottom_left, "A removed egg must not hatch.")
	qdel(embryo)
	TEST_ASSERT(host.try_implant_terror_eggs(), "The host should be infectable again after extraction.")
	embryo = host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG)
	embryo.on_life(2)
	embryo.hatch_egg()
	TEST_ASSERT_EQUAL(embryo.eggs_hatched, 0, "The eggs emerged before maturity.")
	embryo.egg_progress = 120
	embryo.hatch_egg()
	TEST_ASSERT_EQUAL(embryo.eggs_hatched, 1, "The first spiderling did not hatch from mature eggs.")
	TEST_ASSERT_EQUAL(host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG), embryo, "The clutch should remain after its first spiderling hatches.")
	var/mob/living/basic/spider/growing/spiderling/terror/spiderling = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(spiderling, "Mature parasite eggs did not spawn a spiderling.")
	var/static/list/first_caste_pool = list(/mob/living/basic/spider/giant/terror/gray, /mob/living/basic/spider/giant/terror/red, /mob/living/basic/spider/giant/terror/reaper)
	TEST_ASSERT(spiderling.grow_as in first_caste_pool, "The first parasite spiderling came from the wrong caste pool.")
