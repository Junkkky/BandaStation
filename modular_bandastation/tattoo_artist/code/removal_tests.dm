/datum/unit_test/tattoo_removal
	var/opened_removal_session = FALSE

/datum/unit_test/tattoo_removal/proc/on_session_started(mob/living/customer, trait)
	SIGNAL_HANDLER
	var/list/sources = GET_TRAIT_SOURCES(customer, trait)
	var/datum/session = locate(sources[1])
	opened_removal_session = istype(session, /datum/tattoo_session/removal)

/datum/unit_test/tattoo_removal/proc/drop_machine(mob/living/artist)
	SIGNAL_HANDLER
	artist.dropItemToGround(artist.is_holding_item_of_type(/obj/item/tattoo_machine))

/// Select one of two saved drawings on the same limb and interrupt before trying again.
/datum/unit_test/tattoo_removal/Run()
	var/mob/living/carbon/human/customer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent, get_step(customer, EAST))
	var/datum/client_interface/player = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/character_portrait_test, player)
	customer.mock_client = player
	player.mob = customer
	player.prefs = preferences
	customer.mind_initialize()
	customer.mind.set_original_character(customer)
	customer.mind.original_character_slot_index = 1
	customer.bind_tattoo_character(preferences, 1)
	artist.mock_client = allocate(/datum/client_interface)
	artist.set_combat_mode(FALSE)
	artist.zone_selected = BODY_ZONE_L_ARM
	var/obj/item/bodypart/arm = customer.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/tattoo_machine/machine = allocate(/obj/item/tattoo_machine)
	artist.put_in_hands(machine)
	var/datum/tattoo_session/editor = allocate(/datum/tattoo_session, machine, artist, customer, arm)
	for(var/side in list(SOUTH, NORTH))
		TEST_ASSERT(editor.set_view(side), "The arm has no tattooable surface on the chosen side.")
		var/index = findtextEx(editor.mask_bits, "1")
		var/stroke = splicetext(editor.bitmap, index, index + 1, "1")
		var/datum/tattoo_design/design = allocate(/datum/tattoo_design)
		TEST_ASSERT(design.prepare(arm, side, stroke, list("#c62b87")) && arm.apply_drawn_tattoo(design), "A fixture drawing did not reach the arm.")
		TEST_ASSERT(customer.set_tattoo_persistent(arm, design, TRUE), "A fixture drawing did not reach the character file.")
	qdel(editor)
	var/datum/bodypart_overlay/drawn_tattoo/front
	var/datum/bodypart_overlay/drawn_tattoo/back
	for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in arm.bodypart_overlays)
		if(tattoo.design.side == SOUTH)
			front = tattoo
		else if(tattoo.design.side == NORTH)
			back = tattoo
	TEST_ASSERT(front && back, "The two drawings must occupy opposite sides of the same arm.")
	machine.ink_doses.Cut()
	machine.attack_self(artist)
	TEST_ASSERT(machine.removal_mode, "Activating the held machine did not switch to removal.")
	var/session_signal = SIGNAL_ADDTRAIT("in_tattoo_session")
	RegisterSignal(customer, session_signal, PROC_REF(on_session_started))
	machine.attack(customer, artist)
	UnregisterSignal(customer, session_signal)
	TEST_ASSERT(opened_removal_session, "Using the machine on a tattooed arm did not open the removal session.")

	// Headless clients cannot keep a TGUI window open. Submit the same actions to its server session.
	for(var/interrupt in list(TRUE, FALSE))
		if(!artist.is_holding(machine))
			artist.put_in_hands(machine)
		var/datum/tattoo_session/removal/session = allocate(/datum/tattoo_session/removal, machine, artist, customer, arm)
		machine.session = session
		var/list/window = session.ui_data(artist)
		TEST_ASSERT(window["mode"] == "removal" && length(window["tattoos"]) == 2, "The removal window did not offer both drawings on the selected limb.")
		TEST_ASSERT(session.handle_action(artist, "select", list("id" = REF(front), "revision" = session.revision)), "The artist could not select the front drawing.")
		var/list/approval = list("revision" = session.revision)
		TEST_ASSERT(!session.handle_action(artist, "approve", approval) && !session.finish_application(), "The artist removed the drawing without the customer's approval.")
		if(interrupt)
			RegisterSignal(artist, COMSIG_DO_AFTER_BEGAN, PROC_REF(drop_machine))
		TEST_ASSERT(session.handle_action(customer, "approve", approval), "The customer could not approve the selected drawing.")
		var/deadline = world.time + 12 SECONDS
		UNTIL(QDELETED(session) || world.time >= deadline)
		TEST_ASSERT(QDELETED(session), "The removal procedure did not end.")
		if(interrupt)
			UnregisterSignal(artist, COMSIG_DO_AFTER_BEGAN)
			TEST_ASSERT(!artist.is_holding(machine) && arm.has_drawn_tattoo(SOUTH, front.design), "Dropping the machine did not preserve the selected tattoo.")
			TEST_ASSERT(preferences.savefile.load() && customer.is_tattoo_persistent(arm, front.design), "The interrupted removal erased the selected drawing from disk.")
	TEST_ASSERT(!arm.has_drawn_tattoo(SOUTH) && arm.has_drawn_tattoo(NORTH, back.design), "Completed removal affected the wrong drawing.")
	TEST_ASSERT(preferences.savefile.load(), "The updated character file could not be reopened.")
	TEST_ASSERT_EQUAL(artist.restore_saved_tattoos(preferences, 1), 1, "The character file did not retain exactly one drawing.")
	var/obj/item/bodypart/new_arm = artist.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(new_arm.has_drawn_tattoo(NORTH) && !new_arm.has_drawn_tattoo(SOUTH), "The deleted drawing returned on a new body.")
