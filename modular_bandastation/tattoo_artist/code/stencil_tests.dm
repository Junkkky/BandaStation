/// Reopen a saved artist stencil on another body with a different machine palette.
/datum/unit_test/tattoo_stencils/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/customer = allocate(/mob/living/carbon/human/consistent, get_step(artist, EAST))
	for(var/mob/living/person as anything in list(artist, customer))
		var/datum/client_interface/player = allocate(/datum/client_interface)
		person.mock_client = player
		player.mob = person
		player.prefs = allocate(/datum/preferences/character_portrait_test, player)
	var/datum/preferences/preferences = artist.mock_client.prefs
	var/obj/item/tattoo_machine/machine = allocate(/obj/item/tattoo_machine)
	artist.put_in_hands(machine)
	var/datum/tattoo_session/first = allocate(/datum/tattoo_session, machine, artist, customer, customer.get_bodypart(BODY_ZONE_L_ARM))
	machine.session = first
	TEST_ASSERT(first.set_view(SOUTH), "The customer's arm could not be drawn on.")
	// The front left upper arm includes both detail samples of this world pixel.
	var/pixel = (64 - 36) * 64 + 43
	var/blank = first.bitmap
	var/original = splicetext(blank, pixel, pixel + 2, "13")
	first.handle_action(artist, "draw", list("pixels" = original, "revision" = first.revision))
	var/list/save = list("name" = "Два цвета", "revision" = first.revision)
	TEST_ASSERT(!first.handle_action(customer, "save_stencil", save), "The customer saved a stencil into the artist's library.")
	TEST_ASSERT(first.handle_action(artist, "save_stencil", save), "The artist's save request was rejected.")
	var/list/window = first.ui_data(artist)
	var/list/entries = window["stencils"]
	TEST_ASSERT_EQUAL(length(entries), 1, "One saved stencil should appear in the artist's list.")
	var/list/entry = entries[1]
	TEST_ASSERT_EQUAL(entry["name"], save["name"], "The library lost the stencil's name.")
	var/id = entry["id"]
	window = first.ui_data(customer)
	TEST_ASSERT_NULL(window["stencils"], "The customer's window exposed the artist's library.")
	qdel(first)
	artist.dropItemToGround(machine)
	TEST_ASSERT(preferences.savefile.load(), "The saved stencil file could not be reopened.")

	var/mob/living/carbon/human/model = allocate(/mob/living/carbon/human/consistent)
	model.flags_1 |= ADMIN_SPAWNED_1
	for(var/scenario in list("other artist", "back of arm", "missing ink", "compatible"))
		var/mob/living/carbon/human/operator = scenario == "other artist" ? customer : artist
		operator.put_in_hands(machine)
		// Load only used pigments, in reverse order from the original palette.
		machine.ink_doses = list("#176b78" = 4, "#262638" = 4)
		if(scenario == "missing ink")
			machine.ink_doses -= "#262638"
		var/datum/tattoo_session/session = allocate(/datum/tattoo_session, machine, operator, model, model.get_bodypart(BODY_ZONE_L_ARM))
		machine.session = session
		TEST_ASSERT(session.practice && session.set_view(scenario == "back of arm" ? NORTH : SOUTH), "The second session did not expose the requested practice surface.")
		var/revision = session.revision
		TEST_ASSERT(session.handle_action(operator, "apply_stencil", list("id" = id, "revision" = revision)), "Applying the stencil was not handled.")
		if(scenario != "compatible")
			TEST_ASSERT(session.stencil_error && session.bitmap == blank && session.revision == revision, "An invalid transfer ([scenario]) changed the draft or returned no explanation.")
		else
			var/mapped = splicetext(blank, pixel, pixel + 2, "21")
			TEST_ASSERT(!session.stencil_error && session.bitmap == mapped && session.revision > revision, "The drawing did not retain its original pigments in the new palette.")
			var/edited = splicetext(mapped, pixel, pixel + 1, "1")
			session.handle_action(operator, "draw", list("pixels" = edited, "revision" = session.revision))
			TEST_ASSERT(session.bitmap == edited, "The transferred stencil could not be edited.")
			session.handle_action(operator, "delete_stencil", list("id" = id, "revision" = session.revision))
			TEST_ASSERT(preferences.savefile.load() && !length(session.get_stencil_library()), "Deleting the stencil left it in the saved library.")
			TEST_ASSERT(session.handle_action(operator, "review", list()) && session.reviewed?.bitmap == edited, "The edited stencil did not reach ordinary customer review.")
		qdel(session)
		operator.dropItemToGround(machine)
