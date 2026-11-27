// The fork's role defines are loaded after the base unit-test includes.
#define SISTER_TEST_OFFICER_ROLE "centcom_role_officer"

/datum/unit_test/legendary_sword_sister_registry/Run()
	var/obj/item/dualsaber/legendary_saber/sister/sword = EASY_ALLOCATE()
	var/list/bond_by_icon = list("sister_dome" = 0, "sister_sting" = 50, "sister_dawn" = 100)
	TEST_ASSERT_EQUAL(sword.reach, 5, "Light Sister lost its ordinary dash reach.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(45 SECONDS), 25, "First Light Sister meditation stage ended at the wrong time.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(135 SECONDS - 1), 49, "Sting unlocked early.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(135 SECONDS), 50, "Sting did not unlock after the second stage.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(315 SECONDS), 100, "Light Sister did not reach full bond after the final stage.")
	TEST_ASSERT_EQUAL(sword.attack_spin_chance, 0, "Light Sister should not spin its wielder on melee attacks.")
	TEST_ASSERT_EQUAL(length(sword.actions), length(bond_by_icon), "Light Sister granted the wrong number of actions.")
	for(var/datum/action/cooldown/legendary_sword/ability in sword.actions)
		var/state = ability.button_icon_state
		TEST_ASSERT(state in bond_by_icon, "Unexpected or duplicate Light Sister action: [state].")
		TEST_ASSERT_EQUAL(ability.required_bond, bond_by_icon[state], "Wrong bond requirement for [state].")
		TEST_ASSERT(state in icon_states(ability.button_icon), "Missing Light Sister icon for [state].")
		bond_by_icon -= state
	TEST_ASSERT_EQUAL(length(bond_by_icon), 0, "Light Sister did not grant all three abilities.")

/datum/unit_test/legendary_sword_sister
	var/mob/living/carbon/human/consistent/malice_audio_listener/listener

/datum/unit_test/legendary_sword_sister/Destroy()
	listener?.clear_important_client_contents()
	listener = null
	return ..()

/// Register a real nearby listener for the spatial sound dispatcher.
/datum/unit_test/legendary_sword_sister/proc/listen_from(turf/where, sound_to_record, second_sound)
	listener = allocate(/mob/living/carbon/human/consistent/malice_audio_listener, where)
	listener.impact_sound = sound_to_record
	listener.ordinary_hit_sound = second_sound
	listener.enable_client_mobs_in_contents()
	return listener

/datum/unit_test/legendary_sword_sister/Run()
	var/turf/center = get_step(get_ranged_target_turf(run_loc_floor_bottom_left, NORTH, 2), EAST)
	var/turf/edge = get_ranged_target_turf(center, EAST, 2)
	var/turf/outside = get_step(edge, EAST)
	var/turf/other_edge = get_step(edge, NORTH)
	var/mob/living/carbon/human/consistent/wielder = listen_from(center, 'modular_bandastation/weapon/sound/melee/sister_dome_open.ogg', 'modular_bandastation/weapon/sound/melee/sister_dome_break.ogg')
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, edge)
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent, get_step(outside, NORTH))
	var/obj/item/dualsaber/legendary_saber/sister/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = SISTER_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Light Sister.")
	sword.attack_self(wielder)
	var/datum/action/cooldown/legendary_sword/sister_dome/ability = locate() in sword.actions
	var/expected_loss = 10
	wielder.adjust_stamina_loss(expected_loss)
	TEST_ASSERT(ability?.Trigger(wielder), "Could not raise the dome at zero bond.")
	TEST_ASSERT_EQUAL(length(listener.impact_origins), 1, "Raising the dome did not play its opening sound once.")
	TEST_ASSERT_EQUAL(listener.impact_origins[1], center, "The dome opening was heard from the wrong tile.")
	var/obj/effect/sister_light_dome/dome = ability.active_dome
	TEST_ASSERT_EQUAL(dome?.loc, center, "The dome was not centered on its wielder.")
	TEST_ASSERT(HAS_TRAIT(wielder, TRAIT_IMMOBILIZED), "The wielder could walk while holding the dome.")
	var/obj/structure/sister_dome_barrier/barrier = locate() in other_edge
	TEST_ASSERT_NOTNULL(barrier, "The dome left a hole in its eastern perimeter.")
	TEST_ASSERT(!attacker.Move(other_edge, WEST), "An outsider walked through the perimeter.")
	var/turf/inside = get_step(edge, WEST)
	TEST_ASSERT(!do_teleport(attacker, inside, no_effects = TRUE), "An outsider teleported through the dome.")
	TEST_ASSERT(patient.Move(outside, EAST), "Someone inside the dome could not leave.")
	TEST_ASSERT(patient.Move(edge, WEST), "Someone admitted when the dome was raised could not return.")
	TEST_ASSERT(attacker.Move(outside, SOUTH), "The dome blocked movement entirely outside its perimeter.")
	TEST_ASSERT_EQUAL(wielder.get_stamina_loss(), expected_loss, "Raising the dome or blocking passage spent the wielder's stamina.")

	var/obj/item/storage/toolbox/weapon = EASY_ALLOCATE()
	weapon.force = 11
	TEST_ASSERT(attacker.put_in_active_hand(weapon), "Could not equip the melee attacker.")
	attacker.set_combat_mode(TRUE)
	weapon.melee_attack_chain(attacker, patient)
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), 0, "The attacker hit a protected occupant across the perimeter.")
	expected_loss += 5
	TEST_ASSERT_EQUAL(round(wielder.get_stamina_loss(), DAMAGE_PRECISION), expected_loss, "An 11 damage melee blow did not cost five wielder stamina.")
	TEST_ASSERT_EQUAL(patient.get_stamina_loss(), 0, "The dome charged a protected occupant for the wielder's block.")

	var/obj/projectile/bullet/c9mm/shot = allocate(/obj/projectile/bullet/c9mm, outside)
	shot.firer = attacker
	shot.damage = 22
	shot.aim_projectile(wielder, attacker)
	expected_loss += 10
	shot.fire(get_angle(outside, center))
	if(!QDELETED(shot))
		shot.process_movement(2 * ICON_SIZE_X)
	TEST_ASSERT(QDELETED(shot) || shot.deletion_queued, "An incoming projectile crossed the dome.")
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), 0, "An incoming shot hit an occupant on the perimeter.")
	TEST_ASSERT_EQUAL(round(wielder.get_stamina_loss(), DAMAGE_PRECISION), expected_loss, "A 22 damage projectile did not cost ten stamina exactly once.")

	// Point-blank fire resolves the hit before moving onto the target's tile.
	var/obj/projectile/bullet/c9mm/point_blank = allocate(/obj/projectile/bullet/c9mm, outside)
	point_blank.firer = attacker
	point_blank.damage = 33
	point_blank.aim_projectile(patient, attacker)
	expected_loss += 15
	point_blank.fire(get_angle(attacker, patient), patient)
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), 0, "Point-blank fire bypassed the dome.")
	TEST_ASSERT_EQUAL(round(wielder.get_stamina_loss(), DAMAGE_PRECISION), expected_loss, "A 33 damage point-blank shot did not cost fifteen stamina exactly once.")

	TEST_ASSERT(attacker.Move(get_step(outside, NORTH), NORTH), "Could not place the attacker outside the dome's second segment.")
	TEST_ASSERT(patient.Move(get_step(other_edge, WEST), NORTHWEST), "An occupant could not move within the dome.")
	var/obj/projectile/beam/laser/return_shot = allocate(/obj/projectile/beam/laser, get_turf(patient))
	return_shot.firer = patient
	return_shot.wound_bonus = CANT_WOUND // The attacker must remain able to walk after this hit.
	return_shot.aim_projectile(attacker, patient)
	return_shot.fire(get_angle(patient, attacker))
	for(var/step_number in 1 to 3)
		if(QDELETED(return_shot) || return_shot.deletion_queued)
			break
		return_shot.process_movement(ICON_SIZE_X)
	var/turf/shot_tile = get_turf(return_shot)
	TEST_ASSERT(attacker.get_fire_loss() > 0, "An occupant's shot could not pass outward. Shot at ([shot_tile?.x], [shot_tile?.y]), target at ([attacker.x], [attacker.y]).")
	TEST_ASSERT_EQUAL(round(wielder.get_stamina_loss(), DAMAGE_PRECISION), expected_loss, "Outgoing fire spent the wielder's stamina.")

	wielder.adjust_stamina_loss(-5)
	var/exhaustion = wielder.maxHealth - wielder.crit_threshold
	barrier.take_damage(132, BRUTE, MELEE)
	TEST_ASSERT_EQUAL(round(wielder.get_stamina_loss(), DAMAGE_PRECISION), 95, "Hits to different segments did not draw on the same stamina pool after recovery.")
	TEST_ASSERT(!QDELETED(dome), "The dome broke with stamina remaining.")
	var/obj/projectile/beam/pulse/heavy/breaking_shot = allocate(/obj/projectile/beam/pulse/heavy, get_turf(attacker))
	breaking_shot.firer = attacker
	breaking_shot.damage = 20
	breaking_shot.aim_projectile(barrier, attacker)
	breaking_shot.fire(get_angle(attacker, barrier), barrier)
	TEST_ASSERT(QDELETED(breaking_shot), "The piercing shot that broke the dome continued into the protected area.")
	TEST_ASSERT(wielder.get_stamina_loss() >= exhaustion, "The breaking shot did not exhaust the wielder.")
	TEST_ASSERT(QDELETED(dome) && QDELETED(barrier), "The dome survived the wielder's exhaustion.")
	TEST_ASSERT_EQUAL(listener.ordinary_impacts, 1, "Shattering the dome did not play its breaking sound once.")
	TEST_ASSERT(!HAS_TRAIT_FROM(wielder, TRAIT_IMMOBILIZED, REF(dome)), "The broken dome left its immobilization on the wielder.")
	wielder.set_stamina_loss(0)
	wielder.get_up(instant = TRUE)
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not pick up the sword dropped by stamina exhaustion.")
	sword.attack_self(wielder)
	TEST_ASSERT(!ability.Trigger(wielder), "The wielder could immediately replace a broken dome.")
	TEST_ASSERT(attacker.Move(other_edge, WEST), "The broken dome still blocked movement.")
	TEST_ASSERT(do_teleport(attacker, inside, no_effects = TRUE), "The broken dome still blocked teleportation.")

	ability.ResetCooldown()
	TEST_ASSERT(ability.Trigger(wielder), "Could not raise the dome again after it broke.")
	dome = ability.active_dome
	// Isolate stamina depletion from the knockdown that ordinary stamcrit would cause.
	ADD_TRAIT(wielder, TRAIT_STUNIMMUNE, TRAIT_SOURCE_UNIT_TESTS)
	wielder.adjust_stamina_loss(exhaustion)
	TEST_ASSERT(QDELETED(dome), "External stamina depletion left the dome up.")
	TEST_ASSERT_EQUAL(listener.ordinary_impacts, 2, "External exhaustion did not shatter the dome exactly once.")
	ability.ResetCooldown()
	TEST_ASSERT(!ability.Trigger(wielder), "An exhausted wielder could raise a new dome.")
	TEST_ASSERT_EQUAL(length(listener.impact_origins), 2, "The rejected activation played an opening sound.")
	REMOVE_TRAIT(wielder, TRAIT_STUNIMMUNE, TRAIT_SOURCE_UNIT_TESTS)
	wielder.set_stamina_loss(0)
	TEST_ASSERT(ability.Trigger(wielder), "Stamina recovery did not let the wielder channel again.")
	dome = ability.active_dome
	TEST_ASSERT(ability.Trigger(wielder) && QDELETED(dome), "The wielder could not lower an active dome.")
	ability.ResetCooldown()
	TEST_ASSERT(ability.Trigger(wielder), "Could not raise the dome again after lowering it.")
	dome = ability.active_dome
	wielder.dropItemToGround(sword)
	TEST_ASSERT(QDELETED(dome), "Disarming the wielder left the dome active.")
	TEST_ASSERT_EQUAL(listener.ordinary_impacts, 2, "Lowering a dome played the shatter sound.")

/datum/unit_test/legendary_sword_sister/dome_capacity/Run()
	var/turf/center = run_loc_floor_bottom_left
	var/turf/edge = get_ranged_target_turf(center, EAST, 2)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, center)
	wielder.mind_initialize()
	wielder.mind.centcom_role = SISTER_TEST_OFFICER_ROLE
	var/obj/item/dualsaber/legendary_saber/sister/sword = EASY_ALLOCATE()
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Light Sister for the dome capacity test.")
	sword.attack_self(wielder)
	var/datum/action/cooldown/legendary_sword/sister_dome/ability = locate() in sword.actions
	// Keep the sword wielded between trials. The base test exercises the actual fall and disarm.
	ADD_TRAIT(wielder, TRAIT_STUNIMMUNE, TRAIT_SOURCE_UNIT_TESTS)
	var/list/cases = list(
		list("starting_loss" = 0, "unit_hits" = 219, "finisher" = 1),
		list("starting_loss" = 0, "unit_hits" = 0, "finisher" = 220),
		list("starting_loss" = 50, "unit_hits" = 109, "finisher" = 1),
	)
	for(var/list/trial as anything in cases)
		var/starting_loss = trial["starting_loss"]
		var/hits_before_finisher = trial["unit_hits"]
		var/final_damage = trial["finisher"]
		wielder.set_stamina_loss(starting_loss)
		ability.ResetCooldown()
		TEST_ASSERT(ability.Trigger(wielder), "Could not raise the dome with [starting_loss] stamina loss.")
		var/obj/effect/sister_light_dome/dome = ability.active_dome
		var/obj/structure/sister_dome_barrier/barrier = locate() in edge
		TEST_ASSERT_NOTNULL(barrier, "The dome's eastern barrier is missing.")
		for(var/hit in 1 to hits_before_finisher)
			barrier.take_damage(1, BRUTE, MELEE, sound_effect = FALSE)
		TEST_ASSERT(!QDELETED(dome), "The dome broke early after [hits_before_finisher] unit hits with [starting_loss] initial stamina loss.")
		barrier.take_damage(final_damage, BRUTE, MELEE, sound_effect = FALSE)
		TEST_ASSERT(QDELETED(dome), "The dome survived [hits_before_finisher + final_damage] total damage with [starting_loss] initial stamina loss.")
		TEST_ASSERT(wielder.get_stamina_loss() >= 100, "Reaching dome capacity did not exhaust the wielder.")
	REMOVE_TRAIT(wielder, TRAIT_STUNIMMUNE, TRAIT_SOURCE_UNIT_TESTS)

/datum/unit_test/legendary_sword_sister/dawn
	/// The same list that animate_attack() reads after all attack-animation handlers have run.
	var/list/swing_images

/datum/unit_test/legendary_sword_sister/dawn/Run()
	var/turf/center = get_step(run_loc_floor_bottom_left, EAST)
	var/mob/living/carbon/human/consistent/wielder = listen_from(center, 'modular_bandastation/weapon/sound/melee/sister_dawn.ogg')
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/dualsaber/legendary_saber/sister/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = SISTER_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Light Sister for Dawn.")
	sword.attack_self(wielder)
	var/datum/action/cooldown/legendary_sword/sister_dawn/dawn = locate() in sword.actions
	TEST_ASSERT_NOTNULL(dawn, "Light Sister did not grant Dawn.")
	var/full_bond = 45 SECONDS + 90 SECONDS + 3 MINUTES
	sword.bond_meditation_time = full_bond - 1
	TEST_ASSERT(!dawn.Trigger(wielder), "Dawn activated below 100% bond.")
	sword.bond_meditation_time = full_bond
	wielder.set_combat_mode(TRUE)
	sword.wound_bonus = CANT_WOUND
	RegisterSignal(sword, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(record_swing_images))
	check_dawn_strike(wielder, sword, patient, 35, 0.7 SECONDS)

	var/other_filter_name = "dawn_test_existing_outline"
	wielder.add_filter(other_filter_name, 1, outline_filter(size = 1, color = COLOR_RED))
	TEST_ASSERT_NULL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "The held blade glowed before Dawn.")
	TEST_ASSERT(dawn.Trigger(wielder), "Dawn did not activate with a full bond.")
	TEST_ASSERT_EQUAL(length(listener.impact_origins), 1, "Dawn did not play its activation sound exactly once.")
	TEST_ASSERT_EQUAL(listener.impact_origins[1], center, "The Dawn sound was heard from the wrong tile.")
	TEST_ASSERT_EQUAL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "blade_left", "Dawn did not light the left-hand blade.")
	var/obj/item/clothing/gloves/combat/normandy/gauntlets = EASY_ALLOCATE()
	TEST_ASSERT(wielder.equip_to_slot_if_possible(gauntlets, ITEM_SLOT_GLOVES), "Could not equip the Normandy gauntlets during Dawn.")
	TEST_ASSERT_EQUAL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "gauntlet_left", "The blade aura did not follow the left gauntlet grip.")
	var/datum/status_effect/sister_dawn/effect = wielder.has_status_effect(/datum/status_effect/sister_dawn)
	TEST_ASSERT_NOTNULL(effect, "The wielder did not receive the Dawn status.")
	TEST_ASSERT_EQUAL(effect.duration, 8 SECONDS, "Dawn started with the wrong duration.")
	TEST_ASSERT_EQUAL(dawn.next_use_time, world.time + 90 SECONDS, "The recovery did not start on activation.")
	var/obj/effect/dummy/lighting_obj/moblight/sister_dawn/aura = effect.aura
	TEST_ASSERT(aura && aura.loc == wielder && (aura in wielder.vis_contents) && aura.light_range > 0, "The wielder has no visible Dawn light.")
	var/outline_name = aura.outline_filter_name
	TEST_ASSERT_NOTNULL(wielder.get_filter(outline_name), "The wielder did not receive the Dawn outline.")
	TEST_ASSERT(!dawn.Trigger(wielder), "Dawn could be stacked before recovery.")
	TEST_ASSERT_EQUAL(length(listener.impact_origins), 1, "A rejected Dawn replayed its activation sound.")
	check_dawn_strike(wielder, sword, patient, 49, 0.5 SECONDS, expected_swing_aura = "swing")
	var/turf/new_turf = get_step(center, NORTH)
	TEST_ASSERT(wielder.Move(new_turf, NORTH), "The Dawn wielder could not walk.")
	TEST_ASSERT(get_turf(aura) == new_turf && wielder.get_filter(outline_name), "The light and outline did not follow the moving wielder.")

	effect.process(7)
	TEST_ASSERT(!QDELETED(effect) && !QDELETED(aura), "Dawn expired before the eighth second.")
	effect.process(1)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/sister_dawn), "Dawn remained active after eight seconds.")
	TEST_ASSERT(QDELETED(aura) && !(aura in wielder.vis_contents), "The Dawn light remained after expiry.")
	TEST_ASSERT(!wielder.get_filter(outline_name) && wielder.get_filter(other_filter_name), "Expiry did not remove exactly the Dawn outline.")
	TEST_ASSERT_NULL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "The blade still glowed when Dawn expired.")
	check_dawn_strike(wielder, sword, patient, 35, 0.7 SECONDS)
	TEST_ASSERT(!dawn.Trigger(wielder), "Expiry skipped the remaining Dawn cooldown.")

	dawn.ResetCooldown()
	TEST_ASSERT(wielder.dropItemToGround(sword) && wielder.swap_hand(2) && wielder.put_in_active_hand(sword), "Could not switch Light Sister to the right hand.")
	sword.attack_self(wielder)
	TEST_ASSERT(dawn.Trigger(wielder), "Dawn could not activate again after recovery.")
	TEST_ASSERT_EQUAL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "gauntlet_right", "The blade aura did not match the right gauntlet grip.")
	TEST_ASSERT(wielder.dropItemToGround(gauntlets), "Could not remove the Normandy gauntlets during Dawn.")
	TEST_ASSERT_EQUAL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "blade_right", "The blade aura did not follow the bare right-hand grip.")
	effect = wielder.has_status_effect(/datum/status_effect/sister_dawn)
	TEST_ASSERT_NOTNULL(effect?.aura, "Recasting Dawn did not restore its light.")
	aura = effect.aura
	outline_name = aura.outline_filter_name
	TEST_ASSERT_NOTNULL(wielder.get_filter(outline_name), "Recasting Dawn did not restore its outline.")
	wielder.dropItemToGround(sword)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/sister_dawn), "Disarming the wielder left Dawn active.")
	TEST_ASSERT(QDELETED(aura) && !(aura in wielder.vis_contents), "Disarming the wielder left the Dawn light visible.")
	TEST_ASSERT(!wielder.get_filter(outline_name) && wielder.get_filter(other_filter_name), "Disarming did not remove exactly the Dawn outline.")
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not pick Light Sister up after disarming Dawn.")
	sword.attack_self(wielder)
	TEST_ASSERT_NULL(get_blade_aura_state(wielder.overlays_standing[HANDS_LAYER]), "The blade aura returned after disarming and re-wielding.")
	check_dawn_strike(wielder, sword, patient, 35, 0.7 SECONDS)

	var/obj/item/dualsaber/standard_saber = EASY_ALLOCATE()
	TEST_ASSERT(wielder.dropItemToGround(sword) && wielder.put_in_active_hand(standard_saber), "Could not equip the standard dualsaber.")
	standard_saber.attack_self(wielder)
	TEST_ASSERT_EQUAL(standard_saber.attack_spin_chance, 50, "Standard dualsabers lost their usual spin chance.")
	standard_saber.attack_spin_chance = 100
	var/facing_before_spin = wielder.dir
	standard_saber.melee_attack_chain(wielder, patient)
	TEST_ASSERT(wielder.dir != facing_before_spin, "A guaranteed melee spin did not turn the standard dualsaber wielder.")

/datum/unit_test/legendary_sword_sister/dawn/proc/record_swing_images(datum/source, atom/movable/attacker, atom/target, animation_type, list/image_override)
	SIGNAL_HANDLER
	swing_images = image_override

/// Inspect the actual equipped hand cache or swing images, without forcing a redraw.
/datum/unit_test/legendary_sword_sister/dawn/proc/get_blade_aura_state(list/blades)
	for(var/image/blade as anything in blades)
		for(var/mutable_appearance/child as anything in blade.overlays)
			if(child.icon == 'modular_bandastation/weapon/icons/melee/sister_dawn_blade.dmi')
				return child.icon_state
	return null

/datum/unit_test/legendary_sword_sister/dawn/proc/check_dawn_strike(mob/living/carbon/human/wielder, obj/item/dualsaber/legendary_saber/sister/sword, mob/living/carbon/human/victim, expected_damage, expected_delay, expected_swing_aura = null)
	victim.fully_heal(HEAL_DAMAGE)
	swing_images = null
	wielder.face_atom(victim)
	var/facing_target = wielder.dir
	sword.melee_attack_chain(wielder, victim)
	TEST_ASSERT_EQUAL(wielder.dir, facing_target, "Light Sister turned its wielder away from the target during a melee strike.")
	TEST_ASSERT_NOTNULL(swing_images, "The strike did not animate the sword.")
	TEST_ASSERT_EQUAL(get_blade_aura_state(swing_images), expected_swing_aura, "The swing showed the wrong blade aura.")
	TEST_ASSERT_EQUAL(victim.get_total_damage(), expected_damage, "An ordinary Light Sister strike dealt the wrong damage.")
	TEST_ASSERT_EQUAL(wielder.next_move - world.time, expected_delay, "An ordinary Light Sister strike applied the wrong click delay.")


/datum/unit_test/legendary_sword_sister/sting
	var/datum/turf_reservation/throw_lane

/datum/unit_test/legendary_sword_sister/sting/Destroy()
	// Release the test mobs before returning their tiles to the reservation pool.
	if(listener)
		listener.clear_important_client_contents()
		listener = null
	QDEL_LIST(allocated)
	QDEL_NULL(throw_lane)
	return ..()

/datum/unit_test/legendary_sword_sister/sting/Run()
	// The shared test room is only five tiles wide.
	throw_lane = SSmapping.request_turf_block_reservation(9, 2, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(throw_lane, "Could not reserve the eight-tile throw lane.")
	var/turf/origin = throw_lane.bottom_left_turfs[1]
	var/turf/seven_tiles = get_ranged_target_turf(origin, EAST, 7)
	var/turf/eight_tiles = get_step(seven_tiles, EAST)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, origin)
	var/mob/living/carbon/human/consistent/defender = allocate(/mob/living/carbon/human/consistent, seven_tiles)
	var/obj/item/dualsaber/legendary_saber/sister/sword = allocate(/obj/item/dualsaber/legendary_saber/sister, origin)
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot, seven_tiles)
	var/obj/item/dualsaber/legendary_saber/other_saber = allocate(/obj/item/dualsaber/legendary_saber, seven_tiles)
	listen_from(get_step(get_ranged_target_turf(origin, EAST, 3), NORTH), 'modular_bandastation/weapon/sound/melee/sister_sting_hit.ogg', 'modular_bandastation/weapon/sound/melee/sister_sting_throw.ogg')
	for(var/mob/living/carbon/human/participant as anything in list(wielder, defender))
		participant.mind_initialize()
		participant.mind.centcom_role = SISTER_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "The thrower could not hold Light Sister.")
	sword.attack_self(wielder)
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS
	var/datum/action/cooldown/legendary_sword/sister_sting/sting = locate() in sword.actions
	TEST_ASSERT_NOTNULL(sting, "Light Sister did not grant Silver Sting.")
	TEST_ASSERT(!sting.Trigger(wielder, target = eight_tiles), "Silver Sting targeted an eighth tile.")
	TEST_ASSERT(wielder.is_holding(sword) && sting.IsAvailable(), "An out-of-range cast took the item or started recovery.")

	// Human defense reduces block chance according to incoming force. Make both real reactions deterministic.
	shield.block_chance = 150
	other_saber.block_chance = 150
	for(var/obj/item/defense as anything in list(shield, other_saber))
		TEST_ASSERT(defender.put_in_active_hand(defense), "Could not equip [defense] for the parry.")
		if(defense == other_saber)
			other_saber.attack_self(defender)
			TEST_ASSERT(HAS_TRAIT(other_saber, TRAIT_WIELDED), "The defender did not ignite the other saber.")
		var/sounds_before_throw = listener.ordinary_impacts
		TEST_ASSERT(sting.Trigger(wielder, target = defender), "The throw at [defense] did not start.")
		TEST_ASSERT_EQUAL(listener.ordinary_impacts, sounds_before_throw + 1, "The throw did not play exactly one launch sound.")
		var/deadline = world.time + 3 SECONDS
		UNTIL(!sword.throwing || world.time >= deadline)
		TEST_ASSERT(!sword.throwing && isturf(sword.loc) && get_dist(sword, defender) <= 1, "The parried sword did not stop on the floor by [defense].")
		TEST_ASSERT(!sword.get_embed()?.owner && !defender.has_embedded_objects(), "A block by [defense] left an embedded item.")
		TEST_ASSERT(!defender.has_movespeed_modifier(/datum/movespeed_modifier/sister_sting), "A block by [defense] slowed the defender.")
		TEST_ASSERT_EQUAL(defender.get_brute_loss(), 0, "A block by [defense] hurt the defender.")
		TEST_ASSERT_EQUAL(defender.get_bleed_rate(), 0, "A block by [defense] caused bleeding.")
		TEST_ASSERT_EQUAL(length(listener.impact_origins), 0, "A block by [defense] played the flesh-impact sound.")
		if(defense == shield)
			TEST_ASSERT(shield.get_integrity() < shield.max_integrity, "The standard thrown-weapon shield reaction did not run.")
		wielder.forceMove(get_turf(sword))
		TEST_ASSERT(wielder.put_in_active_hand(sword), "The caster could not recover the parried sword.")
		sword.attack_self(wielder)
		TEST_ASSERT(!sting.IsAvailable(), "Recovering the parried sword reset its cooldown.")
		sting.ResetCooldown()
		wielder.forceMove(origin)
		if(defense == other_saber)
			other_saber.attack_self(defender)
		else
			TEST_ASSERT(defender.dropItemToGround(defense), "Could not switch the defender's blocking item.")

	// The unlit legendary saber stays in hand for a negative control.
	TEST_ASSERT(!HAS_TRAIT(other_saber, TRAIT_WIELDED), "The defending saber did not deactivate.")
	// Isolate the embedded blade's bleeding from chance wounds on impact.
	sword.wound_bonus = CANT_WOUND
	TEST_ASSERT(sting.Trigger(wielder, target = defender), "The seventh-tile strike did not start.")
	var/deadline = world.time + 3 SECONDS
	UNTIL(!sword.throwing || world.time >= deadline)
	var/datum/embedding/sister_sting/embedded = sword.get_embed()
	TEST_ASSERT(embedded?.owner == defender && sword.loc == defender && (sword in embedded.owner_limb?.embedded_objects), "The real sword did not embed through the unlit saber's defense.")
	TEST_ASSERT(embedded.blade_visual in defender.vis_contents, "The impaled target did not display the through-blade.")
	TEST_ASSERT_EQUAL(embedded.rip_time * sword.w_class, 4 SECONDS, "The embedded sword's base self-extraction time is wrong.")
	TEST_ASSERT(defender.get_brute_loss() > 0 && defender.has_movespeed_modifier(/datum/movespeed_modifier/sister_sting), "Impaling the defender did not injure and slow them.")
	var/obj/item/bodypart/pierced_limb = embedded.owner_limb
	TEST_ASSERT(defender.get_bleed_rate() > BLEED_OVERLAY_GUSH, "Impaling a healthy defender did not cause heavy bleeding.")
	TEST_ASSERT_EQUAL(pierced_limb.bleed_overlay_icon, "[pierced_limb.body_zone]_3", "The pierced limb did not show the gushing blood overlay.")
	TEST_ASSERT_EQUAL(length(listener.impact_origins), 1, "A successful impalement did not play exactly one hit sound.")
	TEST_ASSERT_EQUAL(listener.impact_origins[1], seven_tiles, "The impalement sound did not come from the defender.")
	var/brute_before = defender.get_brute_loss()
	var/blood_before = defender.blood_volume
	deadline = world.time + 4 SECONDS
	UNTIL((defender.get_brute_loss() > brute_before && defender.blood_volume < blood_before) || world.time >= deadline)
	TEST_ASSERT(defender.get_brute_loss() > brute_before && defender.blood_volume < blood_before, "An embedded Sting did not deal periodic damage and bleed its victim.")
	TEST_ASSERT(pierced_limb.cached_bleed_rate > BLEED_OVERLAY_GUSH, "Heavy bleeding disappeared while the sword was still embedded.")
	embedded.rip_out(defender)
	TEST_ASSERT(!embedded.owner && !defender.has_embedded_objects() && !defender.has_movespeed_modifier(/datum/movespeed_modifier/sister_sting), "Pulling the sword out did not clear the embed and slow.")
	TEST_ASSERT_EQUAL(defender.get_bleed_rate(), 0, "Pulling the sword out left its bleeding on the defender.")
	TEST_ASSERT_NULL(pierced_limb.bleed_overlay_icon, "The bleeding overlay remained after the sword was removed.")
	TEST_ASSERT_NULL(embedded.blade_visual, "Extracting the sword left the through-blade visible.")
	TEST_ASSERT(get_turf(sword) == get_turf(defender), "Extraction lost or recalled the real sword.")
	if(defender.is_holding(sword))
		defender.dropItemToGround(sword)
	wielder.forceMove(get_turf(sword))
	TEST_ASSERT(wielder.put_in_active_hand(sword), "The thrower could not recover the extracted sword.")
	sword.attack_self(wielder)
	sting.ResetCooldown()
	wielder.forceMove(origin)
	sword.AddElement(/datum/element/forced_gravity, ZERO_GRAVITY, TRUE)
	TEST_ASSERT(sting.Trigger(wielder, target = defender), "The dodge scenario did not launch the sword.")
	TEST_ASSERT(!sword.has_gravity(get_turf(sword)), "The space throw should retain zero gravity during flight.")
	defender.forceMove(get_step(seven_tiles, NORTH))
	deadline = world.time + 3 SECONDS
	UNTIL(!sword.throwing || world.time >= deadline)
	TEST_ASSERT_EQUAL(sword.loc, seven_tiles, "The missed sword did not land at the aimed tile.")
	TEST_ASSERT(!embedded.owner && !defender.has_movespeed_modifier(/datum/movespeed_modifier/sister_sting), "The missed Sting tracked its dodging target.")
	TEST_ASSERT_EQUAL(length(listener.impact_origins), 1, "The missed throw played the flesh-impact sound.")

	wielder.forceMove(seven_tiles)
	TEST_ASSERT(wielder.put_in_active_hand(sword), "The missed Sting could not be picked up.")
	sword.attack_self(wielder)
	sting.ResetCooldown()
	ADD_TRAIT(defender, TRAIT_NOBLOOD, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(sting.Trigger(wielder, target = defender), "Could not relaunch the recovered sword.")
	deadline = world.time + 3 SECONDS
	UNTIL(!sword.throwing || world.time >= deadline)
	TEST_ASSERT_EQUAL(embedded.owner, defender, "The same recovered sword failed to embed a second time.")
	TEST_ASSERT_EQUAL(embedded.owner_limb.cached_bleed_rate, 0, "Sting caused bleeding in a bloodless target.")
	TEST_ASSERT_NULL(embedded.owner_limb.bleed_overlay_icon, "Sting showed blood on a bloodless target.")
	var/turf/final_target_turf = get_turf(defender)
	qdel(defender)
	TEST_ASSERT(!QDELETED(sword) && sword.loc == final_target_turf && !embedded.owner, "Deleting the impaled target destroyed or stranded Light Sister.")

#undef SISTER_TEST_OFFICER_ROLE
