/datum/unit_test/punpun_name

/datum/unit_test/punpun_name/Run()
	var/mob/living/carbon/human/species/monkey/punpun/punpun = EASY_ALLOCATE()
	TEST_ASSERT_EQUAL(punpun.name, /mob/living/carbon/human/species/monkey/punpun::name, "Pun Pun did not have [punpun.p_their()] name set")

/datum/unit_test/punpun_donor_spawn
	var/mob/living/original_pun_pun
	var/mob/living/carbon/human/species/monkey/punpun/test_pun_pun
	var/datum/station_trait/job/pun_pun/monkey_day

/datum/unit_test/punpun_donor_spawn/Run()
	original_pun_pun = GLOB.the_one_and_only_punpun
	GLOB.the_one_and_only_punpun = null
	test_pun_pun = allocate(/mob/living/carbon/human/species/monkey/punpun, run_loc_floor_bottom_left)
	GLOB.the_one_and_only_punpun = test_pun_pun
	var/datum/job/pun_pun/job = allocate(/datum/job/pun_pun)
	var/datum/client_interface/player = allocate(/datum/client_interface)
	player.donator_level = DONATOR_TIER_1
	TEST_ASSERT_NULL(job.get_spawn_mob(player, test_pun_pun), "Tier 1 claimed Pun Pun.")

	player.donator_level = DONATOR_TIER_2
	TEST_ASSERT_EQUAL(job.get_roundstart_spawn_point(), test_pun_pun, "Roundstart did not use the bar monkey.")
	TEST_ASSERT_EQUAL(job.get_spawn_mob(player, job.get_latejoin_spawn_point()), test_pun_pun, "Tier 2 did not get the existing bar monkey.")
	TEST_ASSERT_EQUAL(job.get_outfit(FALSE), /datum/outfit/job/pun_pun, "A normal round used the Monkey Day outfit.")

	test_pun_pun.mind = allocate(/datum/mind, "testpunpun")
	TEST_ASSERT_NULL(job.get_spawn_mob(player, test_pun_pun), "An already claimed Pun Pun could be taken over.")
	test_pun_pun.mind = null

	monkey_day = allocate(/datum/station_trait/job/pun_pun)
	SSstation.station_traits += monkey_day
	player.donator_level = BASIC_DONATOR_LEVEL
	TEST_ASSERT_EQUAL(job.get_spawn_mob(player, test_pun_pun), test_pun_pun, "Monkey Day did not unlock Pun Pun for everyone.")
	TEST_ASSERT_EQUAL(job.get_outfit(FALSE), /datum/outfit/job/pun_pun/monkey_day, "Monkey Day lost its original outfit.")

/datum/unit_test/punpun_donor_spawn/Destroy()
	SSstation.station_traits -= monkey_day
	monkey_day = null
	if(test_pun_pun)
		test_pun_pun.mind = null
	test_pun_pun = null
	GLOB.the_one_and_only_punpun = original_pun_pun
	original_pun_pun = null
	return ..()
