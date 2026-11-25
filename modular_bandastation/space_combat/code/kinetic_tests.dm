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
