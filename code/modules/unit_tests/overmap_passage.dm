/// Exercises landing collisions through a fired projectile's real seam subscription.
/datum/unit_test/overmap_passage
	abstract_type = /datum/unit_test/overmap_passage
	/// Original turf definitions restored even when an assertion stops the test.
	var/list/original_turfs = list()
	/// Border that the projectile must resolve before scanning the landing's occupants.
	var/window_direction = WEST
	/// A pass-through projectile must retain its normal glass exemption at a seam.
	var/projectile_pass_flags = NONE
	/// Whether the landing window should intercept the shot.
	var/expect_window_hit = TRUE
	/// An empty landing also must not manufacture an impact against tangential glass.
	var/occupied = TRUE
	/// Non-border cover created first must not take away the window's native impact priority.
	var/other_cover = FALSE

/datum/unit_test/overmap_passage/Destroy()
	QDEL_LIST(allocated)
	for(var/turf/tile as anything in original_turfs)
		var/list/original = original_turfs[tile]
		tile.ChangeTurf(original[1], original[2])
	return ..()

/datum/unit_test/overmap_passage/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/destination = locate(origin.x + 30, origin.y, origin.z)
	for(var/turf/tile as anything in list(origin, destination))
		original_turfs[tile] = list(tile.type, tile.baseturfs)
		tile.ChangeTurf(/turf/open/space)
	var/datum/component/stationtrauma_map_passage/passage = origin.AddComponent(/datum/component/stationtrauma_map_passage, destination, EAST)
	allocated += passage
	if(other_cover)
		allocate(/obj/structure/closet, destination)
	var/obj/structure/window/window = allocate(/obj/structure/window, destination, window_direction)
	var/mob/living/carbon/human/victim
	if(occupied)
		victim = allocate(/mob/living/carbon/human/consistent, destination)
		ADD_TRAIT(victim, TRAIT_PIERCEIMMUNE, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, origin)
	shot.pass_flags = projectile_pass_flags
	shot.ricochets_max = 0
	shot.aim_projectile(victim || destination, origin)
	var/window_integrity = window.get_integrity()
	shot.fire(90)
	if(!occupied)
		TEST_ASSERT(!QDELETED(shot) && !shot.deletion_queued, "A tangential window stopped a projectile on an empty landing.")
		TEST_ASSERT_EQUAL(window.get_integrity(), window_integrity, "An empty tangential window received an impact.")
		return
	if(expect_window_hit)
		TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "The landing's border window did not intercept the shot before its occupant.")
		TEST_ASSERT(window.get_integrity() < window_integrity, "The blocking border did not receive projectile impact.")
	else
		TEST_ASSERT(victim.get_brute_loss() > 0, "An eligible projectile was stopped by a window it should pass.")
		TEST_ASSERT_EQUAL(window.get_integrity(), window_integrity, "A tangential or pass-through window received an impact.")

/// Crossing a window's blocked edge must hit the border before its occupant.
/datum/unit_test/overmap_passage/border_window

/// Native border priority also applies when another blocker was created first on the landing.
/datum/unit_test/overmap_passage/crowded_border_window
	other_cover = TRUE

/// Tangential borders on the landing do not obstruct the incoming projectile.
/datum/unit_test/overmap_passage/tangential_window
	window_direction = NORTH
	expect_window_hit = FALSE

/// Native pass flags still allow a projectile through the landing's glass.
/datum/unit_test/overmap_passage/passglass
	projectile_pass_flags = PASSGLASS
	expect_window_hit = FALSE

/// An empty tangential window must not become an artificial projectile target.
/datum/unit_test/overmap_passage/empty_tangential_window
	window_direction = NORTH
	occupied = FALSE
