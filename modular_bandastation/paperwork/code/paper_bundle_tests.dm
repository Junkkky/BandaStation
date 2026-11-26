/// A two-page bundle must release both original sheets even if the user has no free hand.
/datum/unit_test/paper_bundle_round_trip/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/paper/cover = allocate(/obj/item/paper)
	var/obj/item/paper/second_page = allocate(/obj/item/paper)
	cover.name = "Report"
	cover.add_raw_text("Original report", PEN_FONT, COLOR_BLACK)
	second_page.add_stamp("paper_stamp-ok", 10, 20, 0, "paper_stamp-ok")
	var/datum/paper_stamp/original_stamp = second_page.raw_stamp_data[1]
	TEST_ASSERT(user.put_in_inactive_hand(cover), "Could not hold the cover sheet.")
	TEST_ASSERT(user.put_in_active_hand(second_page), "Could not hold the second sheet.")
	click_wrapper(user, cover)
	var/obj/item/paper_bundle/bundle = user.get_inactive_held_item()
	TEST_ASSERT(istype(bundle), "Clipping two held sheets must replace the cover with a bundle.")
	allocated += bundle
	TEST_ASSERT_EQUAL(length(bundle.contents), 2, "The bundle must contain two pages.")
	TEST_ASSERT_EQUAL(bundle.contents[1], cover, "The clicked sheet must remain the original cover.")
	TEST_ASSERT_EQUAL(bundle.contents[2], second_page, "The held sheet must remain the original second page.")
	TEST_ASSERT_EQUAL(bundle.name, cover.name, "The bundle must inherit the cover's label.")

	var/obj/item/pen/pen = allocate(/obj/item/pen)
	TEST_ASSERT(user.put_in_active_hand(pen), "Could not fill the free hand before extraction.")
	bundle.remove_page(second_page, user)
	TEST_ASSERT(QDELETED(bundle), "Removing a page from a two-page bundle must unclip it.")
	TEST_ASSERT_EQUAL(second_page.loc, get_turf(user), "The extracted sheet must drop if both hands are full.")
	TEST_ASSERT_EQUAL(user.get_inactive_held_item(), cover, "The cover must remain in the hand freed by the bundle.")
	TEST_ASSERT_EQUAL(cover.get_raw_text(), "Original report/", "Unclipping must preserve the cover text.")
	TEST_ASSERT_EQUAL(second_page.raw_stamp_data[1], original_stamp, "Unclipping must preserve the original stamp.")

/// Add a photo, merge two bundles in order, then undo the clips with the in-game shortcut.
/datum/unit_test/paper_bundle_merge/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/paper/cover = allocate(/obj/item/paper)
	var/obj/item/paper/second_page = allocate(/obj/item/paper)
	TEST_ASSERT(user.put_in_inactive_hand(cover), "Could not hold the first cover.")
	TEST_ASSERT(user.put_in_active_hand(second_page), "Could not hold the second sheet.")
	click_wrapper(user, cover)
	var/obj/item/paper_bundle/bundle = user.get_inactive_held_item()
	TEST_ASSERT(istype(bundle), "The first bundle was not created.")
	allocated += bundle

	var/obj/item/photo/photo = allocate(/obj/item/photo)
	TEST_ASSERT(user.put_in_active_hand(photo), "Could not hold the photo.")
	click_wrapper(user, bundle)
	TEST_ASSERT_EQUAL(length(bundle.contents), 3, "Adding a photo must extend the bundle.")
	TEST_ASSERT_EQUAL(bundle.contents[3], photo, "The photo must be appended without copying it.")

	var/obj/item/paper/donor_cover = allocate(/obj/item/paper)
	var/obj/item/paper/donor_page = allocate(/obj/item/paper)
	TEST_ASSERT(user.put_in_active_hand(donor_page), "Could not hold the donor sheet.")
	click_wrapper(user, donor_cover)
	var/obj/item/paper_bundle/donor = locate() in get_turf(user)
	TEST_ASSERT(istype(donor), "Clipping a sheet on the floor must create a bundle there.")
	allocated += donor
	TEST_ASSERT(user.put_in_active_hand(donor), "Could not hold the second bundle.")
	click_wrapper(user, bundle)
	TEST_ASSERT(QDELETED(donor), "Merging must consume the donor bundle.")
	TEST_ASSERT_EQUAL(length(bundle.contents), 5, "Merging must preserve all five pages.")
	TEST_ASSERT_EQUAL(bundle.contents[4], donor_cover, "The donor cover must follow the receiver's pages.")
	TEST_ASSERT_EQUAL(bundle.contents[5], donor_page, "The donor's second sheet must retain its order.")

	click_wrapper(user, bundle, list(ALT_CLICK = 1, RIGHT_CLICK = 1, BUTTON = RIGHT_CLICK))
	TEST_ASSERT(QDELETED(bundle), "Alt-right-click must disassemble the bundle.")
	for(var/obj/item/page as anything in list(cover, second_page, photo, donor_cover, donor_page))
		TEST_ASSERT_EQUAL(page.loc, get_turf(user), "Disassembling must release every original page.")

/// Failed clipping cannot move either original or leave an empty bundle.
/datum/unit_test/paper_bundle_rollback/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/paper/cover = allocate(/obj/item/paper)
	var/obj/item/paper/carbon/carbon_paper = allocate(/obj/item/paper/carbon)
	TEST_ASSERT(user.put_in_inactive_hand(cover), "Could not hold the cover.")
	TEST_ASSERT(user.put_in_active_hand(carbon_paper), "Could not hold the carbon paper.")
	click_wrapper(user, cover)
	TEST_ASSERT_EQUAL(user.get_inactive_held_item(), cover, "An attached carbon copy must prevent clipping.")
	TEST_ASSERT_EQUAL(user.get_active_held_item(), carbon_paper, "Rejected carbon paper must stay in the active hand.")

	carbon_paper.copied = TRUE
	ADD_TRAIT(carbon_paper, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	click_wrapper(user, cover)
	TEST_ASSERT_EQUAL(user.get_inactive_held_item(), cover, "A failed transfer must restore the cover to its original hand.")
	TEST_ASSERT_EQUAL(user.get_active_held_item(), carbon_paper, "A no-drop sheet must stay equipped.")
	TEST_ASSERT_NULL(locate(/obj/item/paper_bundle) in get_turf(user), "A failed transfer must not leave a bundle on the floor.")
