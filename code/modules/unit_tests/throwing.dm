/datum/unit_test/throw_into_nullspace

/datum/unit_test/throw_into_nullspace/Run()
	var/obj/item/sticker/clown/sticker = allocate(/obj/item/sticker/clown)
	TEST_ASSERT(sticker.throw_at(run_loc_floor_top_right, range = 3, speed = 1, spin = FALSE, quickstart = FALSE), "The sticker could not be thrown.")
	var/datum/thrownthing/flight = sticker.throwing
	sticker.moveToNullspace()
	flight.tick()
	TEST_ASSERT(QDELETED(flight), "The throw did not end when the sticker left the map.")
	TEST_ASSERT(!(sticker in SSthrowing.processing), "The sticker remained registered for throwing after leaving the map.")
