// AI EDIT START - Cover Normandy kit cleanup and invalidated dressing cycles
/datum/unit_test/normandy_suit_storage
	abstract_type = /datum/unit_test/normandy_suit_storage

/datum/unit_test/normandy_suit_storage/return_kit/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y

	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	if(!storage.is_kit_worn_by(wearer))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return
	if(wearer.pixel_y == original_pixel_y)
		TEST_FAIL("Dressing did not apply the character offset")
		return

	if(!storage.store_kit_from(wearer))
		TEST_FAIL("The kit could not be returned to its storage unit")
		return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Returning the kit did not restore the character offset ([wearer.pixel_y], expected [original_pixel_y])")
		return
	qdel(storage)
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Deleting the empty unit applied the character offset a second time")

/datum/unit_test/normandy_suit_storage/delete_storage/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y

	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	if(!storage.is_kit_worn_by(wearer))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return
	if(wearer.pixel_y == original_pixel_y)
		TEST_FAIL("Dressing did not apply the character offset")
		return

	qdel(storage)
	for(var/slot in list(ITEM_SLOT_HEAD, ITEM_SLOT_OCLOTHING, ITEM_SLOT_GLOVES, ITEM_SLOT_FEET, ITEM_SLOT_NECK))
		var/obj/item/worn_item = wearer.get_item_by_slot(slot)
		if(worn_item && !wearer.dropItemToGround(worn_item))
			TEST_FAIL("The kit could not be removed after deleting its storage unit")
			return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Deleting the unit and removing its kit left a permanent character offset ([wearer.pixel_y], expected [original_pixel_y])")

/datum/unit_test/normandy_suit_storage/delete_wearer/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/list/deleted_refs = dress_and_delete_wearer(storage)
	if(isnull(deleted_refs))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return

	// Stop waiting once collected, while staying well before the hard-delete queue.
	var/collection_deadline = world.time + 30 SECONDS
	for(var/deleted_part in deleted_refs)
		UNTIL(!locate(deleted_refs[deleted_part]) || world.time >= collection_deadline)
		if(locate(deleted_refs[deleted_part]))
			TEST_FAIL("The surviving storage unit kept its deleted [deleted_part] alive")

/datum/unit_test/normandy_suit_storage/delete_wearer/proc/dress_and_delete_wearer(obj/machinery/normandy_suit_storage/storage)
	// allocate() would itself retain the wearer until the test ends.
	var/mob/living/carbon/human/wearer = new /mob/living/carbon/human/consistent(run_loc_floor_bottom_left)
	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	var/was_dressed = storage.is_kit_worn_by(wearer)
	var/list/deleted_refs = list(
		"wearer" = text_ref(wearer),
		"armor" = text_ref(storage.stored_armor),
		"gloves" = text_ref(storage.stored_gloves),
		"boots" = text_ref(storage.stored_boots),
		"helmet" = text_ref(storage.stored_helmet),
		"cloak" = text_ref(storage.stored_cloak),
	)
	qdel(wearer)
	wearer = null
	return was_dressed ? deleted_refs : null

/datum/unit_test/normandy_suit_storage/delete_kit_piece/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	if(!storage.is_kit_stored())
		TEST_FAIL("The unit did not start with its complete kit stored")
		return

	var/boots_ref = text_ref(storage.stored_boots)
	qdel(storage.stored_boots)
	if(!isnull(storage.stored_boots))
		TEST_FAIL("The unit kept a reference to its deleted boots")
	if(locate(boots_ref) in storage.kit_items)
		TEST_FAIL("The unit kept its deleted boots in the kit list")
	if(storage.is_kit_stored())
		TEST_FAIL("The unit considered its four remaining pieces a complete stored kit")

	storage.close_machine(wearer)
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("The unit started closing with an incomplete kit")

/// Losing a kit piece during the real dressing action must not strip the wearer's own clothes.
/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing
	/// The storage-owned piece deleted when the wearer's dressing action begins.
	var/obj/item/clothing/shoes/combat/normandy/kit_piece_to_delete

/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing/Destroy()
	kit_piece_to_delete = null
	return ..()

/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent/slow)
	var/obj/item/clothing/gloves/combat/original_gloves = allocate(/obj/item/clothing/gloves/combat)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y
	if(!wearer.equip_to_slot_if_possible(original_gloves, ITEM_SLOT_GLOVES))
		TEST_FAIL("Could not equip the wearer's original gloves")
		return
	storage.close_machine(wearer)
	if(storage.state_open || wearer.loc != storage)
		TEST_FAIL("The complete unit could not close for dressing")
		return
	storage.cancel_dressing_start_timer()
	kit_piece_to_delete = storage.stored_boots
	RegisterSignal(wearer, COMSIG_DO_AFTER_BEGAN, PROC_REF(delete_pending_kit_piece))

	storage.begin_dressing()
	UnregisterSignal(wearer, COMSIG_DO_AFTER_BEGAN)
	kit_piece_to_delete = null
	if(!isnull(storage.stored_boots))
		TEST_FAIL("The kit piece was not deleted during the dressing action")
		return
	if(wearer.gloves != original_gloves)
		TEST_FAIL("An invalidated dressing cycle stripped the wearer's original gloves")
		return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("An invalidated dressing cycle changed the character offset")
		return
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("An invalidated dressing cycle did not release its occupant")

/// Invalidate the kit at the action boundary without replacing do_after or its validation.
/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing/proc/delete_pending_kit_piece(mob/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_DO_AFTER_BEGAN)
	// Wait one tick so the real dressing action has yielded before the kit changes.
	QDEL_IN(kit_piece_to_delete, world.tick_lag)
	kit_piece_to_delete = null

/// Destroyed armor must release its visual offset and still allow the remaining kit to be returned.
/datum/unit_test/normandy_suit_storage/return_incomplete_kit/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y

	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	if(!storage.is_kit_worn_by(wearer))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return
	if(wearer.pixel_y == original_pixel_y)
		TEST_FAIL("Dressing did not apply the character offset")
		return

	var/obj/item/clothing/shoes/combat/normandy/boots = storage.stored_boots
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent)
	if(!wearer.transferItemToLoc(boots, get_turf(wearer), force = TRUE, animated = FALSE))
		TEST_FAIL("Could not remove the kit boots before giving them to another holder")
		return
	if(!holder.put_in_hands(boots))
		TEST_FAIL("The other holder could not pick up the kit boots")
		return

	qdel(storage.stored_armor)
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Deleting worn armor left its character offset active")
		return
	storage.close_machine(wearer)
	if(storage.state_open || wearer.loc != storage)
		TEST_FAIL("The wearer could not return the remaining pieces of an incomplete kit")
		return
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	for(var/obj/item/remaining_item as anything in list(storage.stored_gloves, storage.stored_boots, storage.stored_cloak))
		if(remaining_item?.loc != storage)
			TEST_FAIL("Returning an incomplete kit did not store every surviving piece")
			return
	if(holder.is_holding(boots))
		TEST_FAIL("Returning the kit left its boots in the other holder's inventory")
		return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Returning the remaining kit changed the restored character offset")
		return
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("Returning an incomplete kit did not release its wearer")
		return
	storage.close_machine(wearer)
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("The unit started another dressing cycle with an incomplete kit")
// AI EDIT END

/// Exercise the suit seal, breathing connection and fire protection through the retractable helmet.
/datum/unit_test/normandy_suit_storage/environment/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.equipOutfit(/datum/outfit/centcom/normandy)
	var/datum/component/toggle_attached_clothing/helmet = wearer.wear_suit.GetComponent(/datum/component/toggle_attached_clothing)
	var/obj/item/tank/internals/oxygen/tank = allocate(/obj/item/tank/internals/oxygen)
	if(!wearer.equip_to_slot_if_possible(tank, ITEM_SLOT_SUITSTORE) || !wearer.try_open_internals(tank))
		return TEST_FAIL("The deployed helmet could not connect the oxygen tank in suit storage")
	var/datum/gas_mixture/breath = wearer.get_breath_from_internal(BREATH_VOLUME)
	if(!breath || !wearer.check_breath(breath))
		return TEST_FAIL("The wearer could not breathe oxygen through the deployed helmet")

	var/datum/gas_mixture/vacuum = allocate(/datum/gas_mixture)
	var/initial_brute_loss = wearer.get_brute_loss()
	wearer.dna.species.handle_environment_pressure(wearer, vacuum, SSMOBS_DT)
	if(wearer.get_brute_loss() != initial_brute_loss || wearer.get_cold_protection(TCMB) != 1)
		return TEST_FAIL("The complete kit did not protect the wearer from decompression and space cold")
	var/datum/status_effect/fire_handler/fire_stacks/flames = wearer.apply_status_effect(/datum/status_effect/fire_handler/fire_stacks, 5)
	var/initial_temperature = wearer.bodytemperature
	flames.harm_human(SSMOBS_DT)
	if(wearer.bodytemperature != initial_temperature || wearer.get_heat_protection(FIRE_SUIT_MAX_TEMP_PROTECT) != 1)
		return TEST_FAIL("The complete kit did not protect the wearer from fire and extreme heat")

	helmet.toggle_deployable()
	wearer.dna.species.handle_environment_pressure(wearer, vacuum, SSMOBS_DT)
	flames.harm_human(SSMOBS_DT)
	if(wearer.head || wearer.get_brute_loss() <= initial_brute_loss || wearer.get_cold_protection(TCMB) >= 1 || wearer.bodytemperature <= initial_temperature)
		return TEST_FAIL("Retracting the helmet did not expose the wearer to vacuum, cold and fire")
	if(wearer.get_breath_from_internal(BREATH_VOLUME) || wearer.internal)
		return TEST_FAIL("The tank still supplied a breath with the helmet off")

	helmet.toggle_deployable()
	if(wearer.calculate_affecting_pressure(0) != ONE_ATMOSPHERE || !wearer.try_open_internals(tank))
		return TEST_FAIL("Redeploying the helmet did not restore the seal and breathing connection")
	if(!wearer.dropItemToGround(wearer.wear_suit, force = TRUE) || wearer.calculate_affecting_pressure(0) != 0)
		TEST_FAIL("The wearer retained pressure protection after taking the suit off")

/// A neck lift changes into a head grip before the gauntlet crushes the original head.
/datum/unit_test/normandy_iron_grip
	/// Count the distinct poses exposed to the player during the timed action.
	var/phases_started = 0
	/// Phase in which the test interrupts the grip or protects the head.
	var/intervention_phase = 0

/datum/unit_test/normandy_iron_grip/release
	intervention_phase = 1

/datum/unit_test/normandy_iron_grip/release/at_head
	intervention_phase = 2

/datum/unit_test/normandy_iron_grip/reequip_gloves
	intervention_phase = 1

/datum/unit_test/normandy_iron_grip/protected
	intervention_phase = 2

/datum/unit_test/normandy_iron_grip/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent/slow)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(wearer, EAST))
	// Leave enough time to interrupt the half-second head grip after its first tick.
	wearer.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	wearer.equipOutfit(/datum/outfit/centcom/normandy)
	wearer.set_combat_mode(TRUE)
	var/datum/action/cooldown/normandy_iron_grip/grip = locate() in wearer.actions
	if(!grip)
		TEST_FAIL("Equipping the Wolf's Doom outfit did not grant Iron Grip")
		return

	var/obj/item/bodypart/head/original_head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/brain/original_brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/clothing/gloves/gauntlets = wearer.gloves
	var/resting_state = gauntlets.worn_icon_state
	var/resting_layer = gauntlets.alternate_worn_layer
	victim.add_offsets(REF(src), z_add = 3, animate = FALSE)
	RegisterSignal(wearer, COMSIG_DO_AFTER_BEGAN, PROC_REF(observe_lift))
	var/started_at = world.time
	grip.Trigger(target = victim)
	UnregisterSignal(wearer, COMSIG_DO_AFTER_BEGAN)

	var/expected_phases = intervention_phase == 1 ? 1 : 2
	if(phases_started != expected_phases)
		TEST_FAIL("Expected [expected_phases] grip poses, observed [phases_started]")
	if(wearer.pulling || victim.pulledby || victim.has_offset(pixel = PIXEL_Z_OFFSET) != 3 || glove_overlay_state(victim))
		TEST_FAIL("Iron Grip failed to release the victim and restore its original appearance")
	if(gauntlets.worn_icon_state != resting_state || gauntlets.alternate_worn_layer != resting_layer)
		TEST_FAIL("The wearer's gauntlets did not return to their resting pose and layer")
	wearer.setDir(NORTH)
	victim.setDir(NORTH)
	if(wearer.dir != NORTH || victim.dir != NORTH)
		TEST_FAIL("Iron Grip continued blocking turns after release")
	if(intervention_phase)
		if(victim.get_bodypart(BODY_ZONE_HEAD) != original_head || victim.stat == DEAD)
			TEST_FAIL("The victim should have survived Iron Grip with their original head")
		return
	if(world.time - started_at < 3 SECONDS * wearer.cached_multiplicative_actions_slowdown)
		TEST_FAIL("The head was crushed before the three-second attack finished")
	if(QDELETED(victim) || victim.stat != DEAD || victim.get_bodypart(BODY_ZONE_HEAD))
		TEST_FAIL("Iron Grip did not leave a dead, headless victim")
	if(!QDELETED(original_head))
		TEST_FAIL("The gauntlet left the original head intact")
	if(QDELETED(original_brain) || !isturf(original_brain.loc))
		TEST_FAIL("The victim's brain did not drop out of the crushed head")

/datum/unit_test/normandy_iron_grip/proc/observe_lift(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/victim = source.pulling
	if(!istype(victim) || source.grab_state < GRAB_AGGRESSIVE)
		return
	source.setDir(NORTH)
	victim.setDir(NORTH)
	if(source.dir != EAST || victim.dir != WEST)
		TEST_FAIL("The two people could turn away from the grip while the arm was raised")
	var/armor_height = source.has_offset(pixel = PIXEL_Y_OFFSET)
	if(armor_height <= 0 || victim.has_offset(pixel = PIXEL_Z_OFFSET) != 3 + armor_height)
		TEST_FAIL("The victim did not reach the height of the armor")
	phases_started++
	var/at_neck = phases_started == 1
	if(source.gloves.worn_icon_state != (at_neck ? "raised_gloves" : "crushing_gloves") || glove_overlay_state(victim) != (at_neck ? "grip" : "crush"))
		TEST_FAIL("The raised gauntlet and fingers were not in the expected pose during phase [phases_started]")
	if(phases_started == intervention_phase)
		addtimer(CALLBACK(src, PROC_REF(during_lift), source, victim), world.tick_lag)

/// Read the same fingers appearance the client draws over the victim.
/datum/unit_test/normandy_iron_grip/proc/glove_overlay_state(mob/living/carbon/human/victim)
	for(var/mutable_appearance/overlay as anything in victim.overlays)
		if(overlay.icon == 'modular_bandastation/prime_only/icons/centcom/normandy_iron_grip.dmi')
			return overlay.icon_state

/// Change the real grip while its timed action is in progress.
/datum/unit_test/normandy_iron_grip/proc/during_lift(mob/living/carbon/human/wearer, mob/living/carbon/human/victim)
	return

/datum/unit_test/normandy_iron_grip/release/during_lift(mob/living/carbon/human/wearer, mob/living/carbon/human/victim)
	wearer.stop_pulling()

/datum/unit_test/normandy_iron_grip/reequip_gloves/during_lift(mob/living/carbon/human/wearer, mob/living/carbon/human/victim)
	var/obj/item/clothing/gloves/gauntlets = wearer.gloves
	if(!wearer.dropItemToGround(gauntlets, force = TRUE))
		TEST_FAIL("Could not remove the gauntlets during the lift")
		return
	if(wearer.pulling == victim)
		TEST_FAIL("Removing a gauntlet did not immediately release Iron Grip")
	if(!wearer.equip_to_slot_if_possible(gauntlets, ITEM_SLOT_GLOVES))
		TEST_FAIL("Could not immediately restore the same gauntlets during the lift")

/datum/unit_test/normandy_iron_grip/protected/during_lift(mob/living/carbon/human/wearer, mob/living/carbon/human/victim)
	ADD_TRAIT(victim, TRAIT_NODISMEMBER, REF(src))

/// Exercise a free punch across five tiles and a diagonal punch into the corner of the test room.
/datum/unit_test/normandy_power_punch
	var/outfit = /datum/outfit/centcom/normandy
	var/list/opened_walls

/datum/unit_test/normandy_power_punch/wall
	outfit = /datum/outfit/centcom/normandy/wolf

/datum/unit_test/normandy_power_punch/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/stance = get_step(start, WEST)
	var/turf/landing = get_ranged_target_turf(start, EAST, 5)
	if(outfit == /datum/outfit/centcom/normandy/wolf)
		landing = run_loc_floor_top_right
		start = get_step(landing, SOUTHWEST)
		stance = get_step(start, SOUTHWEST)
	else
		// A five-tile throw plus two characters needs the entire seven-tile test room.
		if(!istype(stance, /turf/closed/indestructible) || !istype(landing, /turf/closed/indestructible))
			TEST_FAIL("Expected the test room's indestructible walls at either end of the punch lane")
			return
		opened_walls = list(stance, landing)
		for(var/turf/wall as anything in opened_walls)
			wall.ChangeTurf(/turf/open/indestructible)

	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, stance)
	wearer.equipOutfit(outfit)
	var/datum/action/cooldown/normandy_power_punch/punch = locate() in wearer.actions
	if(!punch)
		TEST_FAIL("[outfit] did not grant the punch action")
		return
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, landing)
	if(punch.Trigger(target = wearer) || punch.Trigger(target = victim) || !punch.IsAvailable() || victim.loc != landing)
		TEST_FAIL("An invalid punch moved the target or spent the action")
		return
	victim.forceMove(start)
	if(!punch.Trigger(target = victim) || punch.IsAvailable())
		TEST_FAIL("Punching a neighboring character did not spend the action")
		return
	var/deadline = world.time + 5 SECONDS
	UNTIL(!victim.throwing || world.time >= deadline)
	if(victim.throwing || victim.loc != landing || wearer.loc != stance)
		TEST_FAIL("Punch landed at [victim.x],[victim.y] instead of [landing.x],[landing.y], or moved the wearer")

/datum/unit_test/normandy_power_punch/Destroy()
	for(var/turf/tile as anything in opened_walls)
		tile.ChangeTurf(/turf/closed/indestructible)
	opened_walls = null
	return ..()

/datum/unit_test/normandy_power_punch/gauntlet/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/turf/start = get_step(wearer, EAST)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, start)
	wearer.equipOutfit(/datum/outfit/centcom/normandy)
	var/datum/action/cooldown/normandy_power_punch/punch = locate() in wearer.actions
	if(!punch)
		TEST_FAIL("Equipping the armor did not grant the powered punch")
		return
	var/obj/item/held_item = allocate(/obj/item/crowbar)
	if(!wearer.put_in_active_hand(held_item))
		TEST_FAIL("Could not place a crowbar in the punching hand")
		return
	var/original_damage = victim.get_brute_loss()
	if(punch.Trigger(target = victim) || victim.get_brute_loss() != original_damage || victim.loc != start)
		TEST_FAIL("A powered punch with an occupied hand struck the target")
	if(!wearer.dropItemToGround(held_item, force = TRUE) || !wearer.dropItemToGround(wearer.gloves, force = TRUE))
		TEST_FAIL("Could not clear the active hand and remove the powered gauntlets")
		return
	if(punch.Trigger(target = victim) || victim.get_brute_loss() != original_damage || victim.loc != start || punch.next_use_time > world.time)
		TEST_FAIL("A powered punch without its gauntlets struck the target or spent its cooldown")

/// A ground pulse reaches nearby characters but does not cross its range or an opaque wall.
/datum/unit_test/normandy_stomp/Run()
	var/turf/center = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, center)
	wearer.equipOutfit(/datum/outfit/centcom/normandy)
	var/datum/action/cooldown/normandy_stomp/stomp = locate() in wearer.actions
	if(!stomp)
		TEST_FAIL("The standard Wolf's Doom outfit did not grant Stomp")
		return
	var/mob/living/carbon/human/same_tile = allocate(/mob/living/carbon/human/consistent, center)
	var/mob/living/carbon/human/near = allocate(/mob/living/carbon/human/consistent, get_step(center, SOUTH))
	var/mob/living/carbon/human/edge = allocate(/mob/living/carbon/human/consistent, get_ranged_target_turf(center, NORTHEAST, 2))
	var/mob/living/carbon/human/distant = allocate(/mob/living/carbon/human/consistent, get_step(edge, EAST))
	var/mob/living/carbon/human/sheltered = allocate(/mob/living/carbon/human/consistent, get_ranged_target_turf(center, NORTH, 2))
	var/mob/living/carbon/human/immune = allocate(/mob/living/carbon/human/consistent, get_step(center, WEST))
	ADD_TRAIT(immune, TRAIT_STUNIMMUNE, REF(src))
	var/turf/barrier = get_step(center, NORTH)
	var/original_type = barrier.type
	barrier = barrier.ChangeTurf(/turf/closed/wall)
	var/activated = stomp.Trigger()
	var/deadline = world.time + 2 SECONDS
	UNTIL(edge.IsParalyzed() || world.time >= deadline)
	barrier.ChangeTurf(original_type)
	if(!activated || !same_tile.IsParalyzed() || !near.IsParalyzed() || !edge.IsParalyzed())
		TEST_FAIL("Stomp did not stun its targets at the origin and on both rings")
	if(near.get_brute_loss() || edge.get_brute_loss())
		TEST_FAIL("The stun wave damaged a character")
	if(wearer.IsParalyzed() || immune.IsParalyzed() || distant.IsParalyzed() || sheltered.IsParalyzed())
		TEST_FAIL("Stomp reached the wearer, an immune target, a distant target, or a target behind a wall")
	if(stomp.Trigger())
		TEST_FAIL("Stomp could be repeated during its cooldown")

/datum/unit_test/normandy_stomp/boots/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.equipOutfit(/datum/outfit/centcom/normandy/wolf)
	var/datum/action/cooldown/normandy_stomp/stomp = locate() in wearer.actions
	var/obj/item/clothing/shoes/boots = wearer.shoes
	if(!stomp || !wearer.dropItemToGround(boots, force = TRUE))
		TEST_FAIL("Could not test Stomp with the wolf cloak outfit and its boots removed")
		return
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(wearer, EAST))
	if(stomp.Trigger() || victim.IsParalyzed() || stomp.next_use_time > world.time)
		TEST_FAIL("Stomping without the armored boots affected a target or spent the cooldown")
	if(!wearer.equip_to_slot_if_possible(boots, ITEM_SLOT_FEET))
		TEST_FAIL("Could not put the armored boots back on")
		return
	// Give the wearer normal action speed so the boots come off during the windup.
	wearer.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	addtimer(CALLBACK(wearer, TYPE_PROC_REF(/mob, dropItemToGround), boots, TRUE), world.tick_lag)
	stomp.Trigger()
	var/deadline = world.time + 0.5 SECONDS
	UNTIL(victim.IsParalyzed() || world.time >= deadline)
	if(wearer.shoes == boots || victim.IsParalyzed())
		TEST_FAIL("Removing the boots before landing failed to interrupt Stomp")
