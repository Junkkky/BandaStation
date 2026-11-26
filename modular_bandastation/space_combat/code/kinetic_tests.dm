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

/datum/unit_test/stationtrauma_kinetic_projection/Run()
	var/datum/stationtrauma_kinetic_shot/shot = allocate(/datum/stationtrauma_kinetic_shot)
	shot.direction_x = 0
	shot.direction_y = 1
	var/x = round(world.maxx / 2)
	var/y = round(world.maxy / 2)
	var/z = run_loc_floor_bottom_left.z
	var/list/bounds = list(x - 4, y - 10, z, x + 4, y + 10, z)
	TEST_ASSERT_EQUAL(shot.deck_entry(bounds, 0, 0, -20, 20), locate(x, y - 12, z), "A head-on round must enter along the centre line.")
	TEST_ASSERT_EQUAL(shot.deck_entry(bounds, 0, -10, -sqrt(300), 20), locate(x - 2, y - 12, z), "A port offset must be preserved on the narrow face.")
	TEST_ASSERT_EQUAL(shot.deck_entry(bounds, 0, 10, -sqrt(300), 20), locate(x + 2, y - 12, z), "A starboard offset must be preserved on the narrow face.")
	TEST_ASSERT_EQUAL(shot.deck_entry(bounds, 90, 10, -sqrt(300), 20), locate(x - 6, y - 5, z), "Turning the hull must map the same contact halfway across the long face.")
	TEST_ASSERT_EQUAL(shot.deck_entry(bounds, 0, 20, 0, 20), locate(x + 4, y - 12, z), "A tangential hit must run along the edge of the physical hull.")

/datum/unit_test/torn_wall/ship_plasma
	var/turf/flank_wall
	var/turf/open/floor/flank_floor

/datum/unit_test/torn_wall/ship_plasma/Destroy()
	flank_wall?.ChangeTurf(/turf/open/indestructible)
	flank_floor?.ChangeTurf(/turf/open/indestructible)
	flank_wall = flank_floor = null
	return ..()

/// A real impact bursts one tile outward; the shield weakens the direct hit and its splash together.
/datum/unit_test/torn_wall/ship_plasma/Run()
	var/turf/entry = get_step(run_loc_floor_bottom_left, NORTH)
	test_wall = get_step(get_step(entry, EAST), EAST)
	flank_wall = get_step(test_wall, NORTHWEST).ChangeTurf(/turf/closed/wall)
	flank_floor = get_step(test_wall, SOUTHWEST).ChangeTurf(/turf/open/floor/iron)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, flank_floor)
	var/obj/structure/closet/nearby = allocate(__IMPLIED_TYPE__, get_step(test_wall, EAST))
	var/obj/structure/closet/distant = allocate(__IMPLIED_TYPE__, get_step(nearby, EAST))
	var/datum/stationtrauma_kinetic_shot/shot = allocate(/datum/stationtrauma_kinetic_shot)
	for(var/strength in list(1, 0.5))
		test_wall = test_wall.ChangeTurf(/turf/closed/wall)
		var/integrity = nearby.get_integrity()
		var/obj/projectile/bullet/stationtrauma_kinetic/energy/plasma/bolt = allocate(__IMPLIED_TYPE__, entry)
		shot.fire_incoming(bolt, 90, strength, 3)
		var/deadline = world.time + 2 SECONDS
		UNTIL(QDELETED(bolt) || world.time >= deadline)
		TEST_ASSERT(QDELETED(bolt), "The plasma bolt must complete its physical trajectory.")
		if(strength == 1)
			TEST_ASSERT(!iswallturf(test_wall), "A direct plasma hit must breach fresh plating.")
		else
			TEST_ASSERT(iswallturf(test_wall) && test_wall.GetComponent(/datum/component/torn_wall), "A half-absorbed plasma bolt must leave a repairable tear.")
		TEST_ASSERT_EQUAL(integrity - nearby.get_integrity(), 60 * strength, "Adjacent equipment must take one quarter of the remaining bolt damage.")
	TEST_ASSERT(iswallturf(flank_wall) && flank_wall.GetComponent(/datum/component/torn_wall), "The wave must crack adjacent plating diagonally.")
	TEST_ASSERT(flank_floor.burnt && bystander.get_fire_loss() > 0, "Exposed crew and flooring must be scorched diagonally.")
	TEST_ASSERT_EQUAL(distant.get_integrity(), distant.max_integrity, "The wave must stop after one tile.")

	var/obj/structure/closet/direct = allocate(__IMPLIED_TYPE__, entry)
	var/obj/projectile/bullet/stationtrauma_kinetic/energy/plasma/bolt = allocate(__IMPLIED_TYPE__, entry)
	bolt.damage = 40
	direct.bullet_act(bolt)
	TEST_ASSERT_EQUAL(direct.max_integrity - direct.get_integrity(), 40, "The primary target must take the direct hit exactly once.")
	TEST_ASSERT(locate(/obj/effect/temp_visual/circle_wave) in entry, "A hit on equipment must emit the shockwave at the impact point.")

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
