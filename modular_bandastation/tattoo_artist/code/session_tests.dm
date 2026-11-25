/// Exercise the two roles and the supply transaction without requiring two connected clients.
/datum/unit_test/tattoo_studio_session/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/customer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/tattoo_machine/machine = allocate(/obj/item/tattoo_machine)
	var/obj/item/tattoo_needle/needle = allocate(/obj/item/tattoo_needle)
	var/obj/item/tattoo_wipe/wipe = allocate(/obj/item/tattoo_wipe)
	var/obj/item/tattoo_dressing/film = allocate(/obj/item/tattoo_dressing)
	var/obj/item/tattoo_ink/ochre/vial = allocate(/obj/item/tattoo_ink/ochre)
	artist.zone_selected = BODY_ZONE_L_ARM
	artist.set_combat_mode(FALSE)
	var/obj/item/bodypart/arm = customer.get_bodypart(artist.zone_selected)
	machine.item_interaction(artist, vial, list())
	TEST_ASSERT_EQUAL(machine.ink_doses["#dc962d"], 4, "A new pigment should add four doses.")
	var/obj/item/storage/box/tattoo_studio/kit = allocate(/obj/item/storage/box/tattoo_studio)
	for(var/obj/item/tattoo_ink/extra in kit.contents.Copy())
		if(!(extra.pigment_color in machine.ink_doses))
			machine.item_interaction(artist, extra, list())
	machine.item_interaction(artist, needle, list())
	wipe.attack(customer, artist)
	var/datum/component/tattoo_care/care = arm.GetComponent(/datum/component/tattoo_care)
	TEST_ASSERT(machine.needle_loaded && care?.prepared, "Session supplies failed to prepare the client and machine.")
	var/datum/tattoo_session/session = allocate(/datum/tattoo_session, machine, artist, customer, arm)
	machine.session = session
	TEST_ASSERT(session.set_view(SOUTH), "The initial view should contain exposed skin.")
	var/blank = session.bitmap
	var/ink_pixel = (64 - 36) * 64 + 43
	TEST_ASSERT_EQUAL(length(session.palette), 15, "All fifteen loaded pigments must appear in the editor.")
	var/last_color = session.palette[15]
	var/art = splicetext(blank, ink_pixel, ink_pixel + 2, "4f")
	session.handle_action(customer, "draw", list("pixels" = art, "revision" = session.revision))
	TEST_ASSERT_EQUAL(session.bitmap, blank, "Only the artist can edit a sketch.")
	session.handle_action(artist, "draw", list("pixels" = splicetext(blank, 1, 2, "1"), "revision" = session.revision))
	TEST_ASSERT_EQUAL(session.bitmap, blank, "A draft escaped its limb mask.")
	session.handle_action(artist, "draw", list("pixels" = art, "revision" = session.revision))
	TEST_ASSERT_EQUAL(session.bitmap, art, "The real editor's packed stroke was rejected.")
	session.handle_action(artist, "draw", list("pixels" = blank, "revision" = session.revision - 1))
	TEST_ASSERT_EQUAL(session.bitmap, art, "An older edit replaced the drawing.")
	session.handle_action(artist, "review", list())
	TEST_ASSERT_EQUAL(session.phase, "review", "The artist could not submit a sketch.")
	var/original_revision = session.revision
	session.handle_action(artist, "approve", list("revision" = original_revision, "save" = TRUE))
	TEST_ASSERT_EQUAL(session.phase, "review", "The artist approved for the customer.")
	TEST_ASSERT(!session.finish_application(), "A draft was committed before customer approval.")
	session.handle_action(customer, "revise", list("revision" = original_revision))
	TEST_ASSERT_EQUAL(session.phase, "draft", "The client could not return the sketch to the artist.")
	session.handle_action(artist, "review", list())
	session.handle_action(customer, "approve", list("revision" = original_revision))
	TEST_ASSERT_EQUAL(session.phase, "review", "An outdated approval accepted a newer review.")
	TEST_ASSERT(!session.start_application() && !session.blood_bead && !arm.generic_bleedstacks, "The needle touched the client before an approved procedure.")
	TEST_ASSERT_NULL(session.motor_sound, "The machine played while the sketch was still under review.")
	customer.setDir(SOUTH)
	var/blood_color = customer.get_bloodtype().get_wound_color(customer)
	var/list/expected_views = list()
	for(var/direction in GLOB.cardinals)
		var/icon/view = getFlatIcon(customer, defdir = direction, no_anim = TRUE)
		if(direction == SOUTH)
			view.DrawBox(blood_color, 22, 18)
		expected_views["[direction]"] = icon2base64(view)
	// The timed do_after needs real clients. Exercise the same final transfer after that boundary.
	session.phase = "applying"
	TEST_ASSERT(session.start_application() && !machine.needle_loaded && !care.prepared, "A used cartridge or wipe could be reused after contact.")
	var/datum/sound_token/motor = session.motor_sound
	TEST_ASSERT(motor?.source == machine && motor.sound?.repeat, "Needle contact did not start a spatial, looping motor on the machine.")
	TEST_ASSERT_EQUAL(motor.sound.file, 'modular_bandastation/tattoo_artist/sound/tattoo_machine.ogg', "The motor played a different sample.")
	TEST_ASSERT(motor.range == 4 && motor.volume == 38, "The motor did not use the studio's local playback settings.")
	TEST_ASSERT(!session.start_application(), "Repeated contact punctured the limb twice.")
	TEST_ASSERT_EQUAL(session.motor_sound, motor, "Repeated needle contact started a second motor.")
	TEST_ASSERT_EQUAL(arm.generic_bleedstacks, 2, "One puncture should cause exactly two bleeding ticks.")
	TEST_ASSERT(!arm.get_damage() && !length(arm.wounds), "A tattoo puncture damaged or wounded the limb.")
	for(var/direction in GLOB.cardinals)
		var/icon/view = getFlatIcon(customer, defdir = direction, no_anim = TRUE)
		TEST_ASSERT(icon2base64(view) == expected_views["[direction]"], "The blood bead was missing or affected an extra pixel on [dir2text(direction)].")
	// Isolate blood loss from nutrition-based regeneration while advancing ordinary blood processing.
	ADD_TRAIT(customer, TRAIT_NOHUNGER, TRAIT_SOURCE_UNIT_TESTS)
	var/initial_volume = customer.get_blood_volume()
	for(var/tick in 1 to 2)
		customer.handle_blood(1)
		TEST_ASSERT_EQUAL(customer.get_blood_volume(), initial_volume - 0.5 * tick, "The puncture should lose half a unit per second while bleeding.")
	customer.handle_blood(1)
	TEST_ASSERT_EQUAL(customer.get_blood_volume(), initial_volume - 1, "Bleeding continued after the second tick.")
	TEST_ASSERT(!arm.generic_bleedstacks && !arm.cached_bleed_rate, "The needle puncture did not clot on its own.")
	TEST_ASSERT(session.finish_application(), "The approved tattoo could not be applied.")
	TEST_ASSERT(arm.has_drawn_tattoo(SOUTH) && !machine.needle_loaded && !care.prepared, "The transfer did not consume the single-use supplies.")
	TEST_ASSERT_EQUAL(machine.ink_doses["#dc962d"], 3, "The first stroke color should spend one dose.")
	TEST_ASSERT_EQUAL(machine.ink_doses[last_color], 3, "The fifteenth pigment should render and spend one dose.")
	TEST_ASSERT_EQUAL(machine.ink_doses["#262638"], 4, "An unused pigment was consumed.")
	TEST_ASSERT(!session.finish_application(), "Repeated completion consumed more supplies.")
	qdel(session)
	TEST_ASSERT(QDELETED(motor), "The motor kept playing after the procedure ended.")
	var/icon/finished = getFlatIcon(customer, defdir = SOUTH, no_anim = TRUE)
	TEST_ASSERT_EQUAL(lowertext(finished.GetPixel(22, 18)), "#dc962d", "The blood bead obscured the completed tattoo after the session closed.")
	film.attack(customer, artist)
	TEST_ASSERT(care.covered_with_film && !care.fresh, "The fresh tattoo could not be dressed.")

	// An organic client with no blood can still receive a tattoo.
	ADD_TRAIT(artist, TRAIT_NOBLOOD, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/bodypart/bloodless_arm = artist.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/component/tattoo_care/bloodless_care = bloodless_arm.AddComponent(/datum/component/tattoo_care)
	for(var/interrupt in list(TRUE, FALSE))
		bloodless_care.prepared = TRUE
		machine.needle_loaded = TRUE
		customer.put_in_hands(machine)
		var/datum/tattoo_session/bloodless_session = allocate(/datum/tattoo_session, machine, customer, artist, bloodless_arm)
		machine.session = bloodless_session
		TEST_ASSERT(bloodless_session.set_view(SOUTH), "An organic bloodless limb had no editable surface.")
		bloodless_session.handle_action(customer, "draw", list("pixels" = art, "revision" = bloodless_session.revision))
		bloodless_session.handle_action(customer, "review", list())
		bloodless_session.phase = "applying"
		TEST_ASSERT(bloodless_session.start_application(), "The needle could not tattoo a bloodless client's skin.")
		TEST_ASSERT(!bloodless_session.blood_bead && !bloodless_arm.generic_bleedstacks, "A bloodless client's limb bled.")
		if(interrupt)
			var/datum/sound_token/interrupted_motor = bloodless_session.motor_sound
			TEST_ASSERT(!QDELETED(interrupted_motor), "The motor never started on the interrupted procedure.")
			customer.dropItemToGround(machine)
			TEST_ASSERT(QDELETED(interrupted_motor) && !machine.session, "Dropping the machine did not stop the session and its motor.")
			continue
		TEST_ASSERT(bloodless_session.finish_application() && bloodless_arm.has_drawn_tattoo(SOUTH), "The bloodless client lost the tattoo.")

/// The starter case carries twelve complete sessions and still has room for the artist's machine.
/datum/unit_test/tattoo_artist_outfit/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	artist.equipOutfit(/datum/outfit/job/tattoo_artist)
	TEST_ASSERT(istype(artist.l_store, /obj/item/tattoo_machine), "The artist started without their machine.")
	TEST_ASSERT(istype(artist.gloves, /obj/item/clothing/gloves/latex/nitrile), "The artist started without their work gloves.")
	var/obj/item/storage/box/tattoo_studio/kit = locate() in artist.back.contents
	TEST_ASSERT(kit, "The supply case was not packed.")
	for(var/supply_type in list(/obj/item/tattoo_wipe, /obj/item/tattoo_needle, /obj/item/tattoo_dressing))
		var/count = 0
		for(var/obj/item/item in kit)
			if(istype(item, supply_type))
				count++
		TEST_ASSERT_EQUAL(count, 12, "Incomplete sets of [supply_type].")
	var/list/colors = list()
	for(var/obj/item/tattoo_ink/vial in kit)
		colors |= vial.pigment_color
	TEST_ASSERT_EQUAL(length(colors), 15, "The set should include fifteen different inks.")
	TEST_ASSERT(kit.atom_storage.can_insert(artist.l_store, artist, messages = FALSE), "The fully stocked case should also fit the machine.")

/// Exercise solo approval, the timed procedure, and the boundary between a mannequin and an ordinary body.
/datum/unit_test/tattoo_mannequin_session/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	artist.mock_client = allocate(/datum/client_interface)
	artist.set_combat_mode(FALSE)
	artist.setDir(EAST)
	artist.zone_selected = BODY_ZONE_L_ARM
	artist.equipOutfit(/datum/outfit/job/tattoo_artist)
	var/obj/item/tattoo_mannequin/packed = locate() in artist.back.contents
	TEST_ASSERT(packed, "The artist arrived without a practice mannequin.")
	artist.put_in_hands(packed)
	packed.attack_self(artist)
	var/mob/living/carbon/human/tattoo_mannequin/model = locate() in range(1, artist)
	TEST_ASSERT(is_tattoo_practice_target(model), "Deploying the mannequin did not create an empty practice target.")
	allocated += model
	var/datum/component/examine_panel/panel = model.GetComponent(/datum/component/examine_panel)
	TEST_ASSERT_NOTNULL(panel, "A mannequin deployed from the starter kit has no examine panel.")
	panel.examine_panel_screen = allocate(/atom/movable/screen/map_view/examine_panel_screen)
	var/list/panel_data = panel.ui_data(artist)
	TEST_ASSERT(islist(panel_data["tattoos"]) && !length(panel_data["tattoos"]), "A fresh mannequin did not offer an empty tattoo tab.")
	TEST_ASSERT(!is_tattoo_practice_target(artist), "An ordinary human was accepted as a practice target.")
	var/obj/item/tattoo_machine/machine = artist.l_store
	artist.put_in_hands(machine)
	var/obj/item/tattoo_needle/needle = allocate(/obj/item/tattoo_needle)
	machine.item_interaction(artist, needle, list())
	var/obj/item/tattoo_wipe/wipe = allocate(/obj/item/tattoo_wipe)
	wipe.attack(model, artist)
	var/obj/item/bodypart/arm = model.get_bodypart(BODY_ZONE_L_ARM)
	// Native TGUI windows require a connected Dream Seeker. Use the same actions that window submits.
	var/datum/tattoo_session/session = allocate(/datum/tattoo_session, machine, artist, model, arm)
	machine.session = session
	TEST_ASSERT(session.practice && session.can_continue() && session.set_view(SOUTH), "A solo sketch could not be opened on a prepared mannequin.")
	var/pixel = findtextEx(session.mask_bits, "1")
	var/stroke = splicetext(session.bitmap, pixel, pixel + 1, "1")
	session.handle_action(artist, "draw", list("pixels" = stroke, "revision" = session.revision))
	session.handle_action(artist, "review", list())
	TEST_ASSERT_EQUAL(session.phase, "review", "The solo artist could not preview the sketch.")
	session.handle_action(model, "approve", list("revision" = session.revision))
	TEST_ASSERT_EQUAL(session.phase, "review", "Practice approval came from the mannequin.")
	session.handle_action(artist, "approve", list("revision" = session.revision))
	var/deadline = world.time + 12 SECONDS
	UNTIL(QDELETED(session) || world.time >= deadline)
	TEST_ASSERT(arm.has_drawn_tattoo(SOUTH) && !machine.needle_loaded && machine.ink_doses["#262638"] == 3, "Solo approval did not complete the tattoo using the loaded cartridge and pigment.")
	panel_data = panel.ui_data(artist)
	TEST_ASSERT_EQUAL(length(panel_data["tattoos"]), 1, "The finished practice tattoo was missing from the examine panel.")
	panel.examine_panel_screen = null
	var/datum/tattoo_session/interrupted = allocate(/datum/tattoo_session, machine, artist, model, arm)
	machine.session = interrupted
	model.mind_initialize()
	TEST_ASSERT(!is_tattoo_practice_target(model), "A mannequin with a mind was accepted for practice.")
	TEST_ASSERT(!interrupted.can_continue(), "An occupied mannequin remained available to the artist.")

/// Clicking an ordinary empty humanoid from Spawn should work with a fresh machine.
/datum/unit_test/tattoo_spawned_dummy
	var/editor_opened = FALSE

/datum/unit_test/tattoo_spawned_dummy/proc/on_session_started()
	SIGNAL_HANDLER
	editor_opened = TRUE

/datum/unit_test/tattoo_spawned_dummy/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	artist.mock_client = allocate(/datum/client_interface)
	artist.set_combat_mode(FALSE)
	artist.zone_selected = BODY_ZONE_L_ARM
	var/mob/living/carbon/human/species/lizard/model = allocate(/mob/living/carbon/human/species/lizard, get_step(artist, EAST))
	var/obj/item/tattoo_machine/machine = allocate(/obj/item/tattoo_machine)
	artist.put_in_hands(machine)
	var/mob/living/carbon/human/dummy/stock_dummy = allocate(/mob/living/carbon/human/dummy)
	stock_dummy.flags_1 |= ADMIN_SPAWNED_1
	var/obj/item/bodypart/dummy_arm = stock_dummy.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(is_tattoo_practice_target(stock_dummy) && dummy_arm.tattoo_skin_icon(SOUTH), "The stock Test Dummy from admin Spawn has no editable training surface.")
	TEST_ASSERT_NULL(machine.tattoo_supply_error(stock_dummy, dummy_arm), "The stock Test Dummy required preparation before drawing.")
	var/session_started_signal = SIGNAL_ADDTRAIT("in_tattoo_session")
	RegisterSignal(model, session_started_signal, PROC_REF(on_session_started))
	machine.attack(model, artist)
	TEST_ASSERT(!editor_opened, "A regular uncontrolled station mob was treated as a spawned dummy.")
	model.flags_1 |= ADMIN_SPAWNED_1
	machine.attack(model, artist)
	UnregisterSignal(model, session_started_signal)
	TEST_ASSERT(editor_opened, "A fresh machine could not open the editor on an empty lizard from admin Spawn.")

	// A headless client cannot keep a TGUI window open. Submit the normal editor actions to the same target.
	var/obj/item/bodypart/arm = model.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/tattoo_session/session = allocate(/datum/tattoo_session, machine, artist, model, arm)
	machine.session = session
	TEST_ASSERT(session.practice && session.can_continue() && session.set_view(SOUTH), "A spawned lizard's arm was not editable.")
	var/pixel = findtextEx(session.mask_bits, "1")
	var/stroke = splicetext(session.bitmap, pixel, pixel + 1, "1")
	session.handle_action(artist, "draw", list("pixels" = stroke, "revision" = session.revision))
	session.handle_action(artist, "review", list())
	session.handle_action(artist, "approve", list("revision" = session.revision))
	var/deadline = world.time + 12 SECONDS
	UNTIL(QDELETED(session) || world.time >= deadline)
	TEST_ASSERT(arm.has_drawn_tattoo(SOUTH), "The approved tattoo was never applied to the spawned lizard.")
	TEST_ASSERT_EQUAL(machine.ink_doses["#262638"], 3, "Practice should use exactly one dose of the chosen pigment.")
	model.last_mind = allocate(/datum/mind)
	TEST_ASSERT(!is_tattoo_practice_target(model), "A formerly inhabited body was treated as a practice dummy.")
	model.last_mind = null
	model.mind_initialize()
	TEST_ASSERT(!is_tattoo_practice_target(model), "A spawned player character was treated as a practice dummy.")
