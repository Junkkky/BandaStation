/** A moving hull can cross the shot between processing steps even when both sampled endpoints miss. */
/datum/unit_test/stationtrauma_kinetic_crossing/Run()
	var/datum/stationtrauma_kinetic_shot/shot = allocate(/datum/stationtrauma_kinetic_shot)
	shot.pos_x = 0
	shot.pos_y = 0
	var/fraction = shot.contact_fraction(10, 0, 5, 5, 0, -10, 2)
	TEST_ASSERT_NOTNULL(fraction, "The swept path missed a moving hull crossing the middle of the shot.")
	TEST_ASSERT(abs(fraction - 0.3586) < 0.001, "The contact must be the entry, before the paths cross in the middle.")
	TEST_ASSERT_NULL(shot.contact_fraction(10, 0, 5, 5, 0, 0, 2), "A stationary hull clear of the trajectory must not be hit.")

/datum/unit_test/stationtrauma_kinetic_sprite/Run()
	var/obj/projectile/bullet/stationtrauma_kinetic/round = allocate(/obj/projectile/bullet/stationtrauma_kinetic)
	TEST_ASSERT(round.icon_state in icon_states(round.icon), "The native projectile's actual icon resource must contain its sprite.")

/datum/unit_test/stationtrauma_autocannon_loading/Run()
	var/obj/machinery/stationtrauma_autocannon_loader/tray = allocate(/obj/machinery/stationtrauma_autocannon_loader)
	var/mob/living/carbon/human/gunner = allocate(/mob/living/carbon/human/consistent)
	// Keep each action open for the ordinary crew duration, including the interrupted second shell.
	gunner.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	var/obj/item/stack/stationtrauma_autocannon_shell/ammo = allocate(/obj/item/stack/stationtrauma_autocannon_shell, null, 3)
	TEST_ASSERT(gunner.put_in_active_hand(ammo), "The gunner needs the stack in hand.")
	ASYNC
		tray.item_interaction(gunner, ammo, list())
	TEST_ASSERT(DOING_INTERACTION(gunner, tray) && !tray.reserve_shells, "The first shell must wait for a loading action.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(tray.reserve_shells || world.time >= deadline)
	TEST_ASSERT_EQUAL(tray.reserve_shells, 1, "Exactly one round should enter the tray when its first loading action completes.")
	TEST_ASSERT(DOING_INTERACTION(gunner, tray), "Loading the second shell from the stack must start a new action.")
	gunner.dropItemToGround(ammo)
	UNTIL(!DOING_INTERACTION(gunner, tray) || world.time >= deadline)
	TEST_ASSERT(!DOING_INTERACTION(gunner, tray) && tray.reserve_shells == 1 && ammo.get_amount() == 2, "Dropping the stack must interrupt the next shell while preserving the first.")

	var/mob/living/carbon/human/helper = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/stack/stationtrauma_autocannon_shell/last_shell = allocate(/obj/item/stack/stationtrauma_autocannon_shell, helper)
	TEST_ASSERT(helper.put_in_active_hand(last_shell) && gunner.put_in_active_hand(ammo), "Both loaders need their own ammunition.")
	tray.reserve_shells = tray.reserve_capacity - 1
	ASYNC
		tray.item_interaction(gunner, ammo, list())
	TEST_ASSERT(DOING_INTERACTION(gunner, tray), "The gunner must be mid-load when the helper fills the last slot.")
	tray.item_interaction(helper, last_shell, list())
	deadline = world.time + 5 SECONDS
	UNTIL(!DOING_INTERACTION(gunner, tray) || world.time >= deadline)
	TEST_ASSERT_EQUAL(tray.reserve_shells, tray.reserve_capacity, "Two loaders must not overfill the last slot.")
	TEST_ASSERT(QDELETED(last_shell) && ammo.get_amount() == 2 && !DOING_INTERACTION(gunner, tray), "Only the helper who filled the slot may spend a round.")

	tray.reserve_shells--
	tray.item_interaction(gunner, ammo, list())
	var/turf/hand = get_turf(gunner)
	var/shell_visible = FALSE
	for(var/atom/movable/flick_visual/transfer in hand.vis_contents)
		if(transfer.icon == ammo.icon && transfer.icon_state == "shell")
			shell_visible = TRUE
			break
	TEST_ASSERT(shell_visible, "Loading from a cassette must animate a single round moving from the gunner to the tray.")
