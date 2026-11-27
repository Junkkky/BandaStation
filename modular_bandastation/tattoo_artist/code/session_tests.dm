/// Capture the game data at the transport boundary; a headless mob has no browser client.
/datum/tgui/tattoo_studio/test_peer
	var/list/received

/datum/tgui/tattoo_studio/test_peer/send_update(custom_data, force)
	if(initialized && !closing && (force || status >= UI_UPDATE))
		received = src_object.ui_data(user)

/datum/unit_test/tattoo_studio_session/proc/register_peer(mob/user, datum/tattoo_session/session, ready)
	var/datum/tgui/tattoo_studio/test_peer/ui = allocate(/datum/tgui/tattoo_studio/test_peer, user, session, "TattooStudio")
	ui.window = allocate(/datum/tgui_window/spacepod_unit_test)
	ui.window.acquire_lock(ui)
	ui.opened_at = world.time
	ui.initialized = ready
	ui.set_autoupdate(FALSE)
	SStgui.on_open(ui)
	return ui

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
	machine.ink_doses["#dc962d"] = 1
	machine.item_interaction(artist, needle, list())
	wipe.attack(customer, artist)
	TEST_ASSERT(machine.needle_loaded && customer.tattoo_prepared && QDELETED(wipe), "Session supplies failed to prepare the client and machine.")
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
	// Sg and Sh encode neighboring detail cells (43,36) and (44,36). 00 is outside this arm.
	var/base_revision = session.revision
	TEST_ASSERT(!session.handle_action(customer, "draw_patch", list("patch" = "Sg0", "revision" = base_revision)) && session.bitmap == art, "The customer could patch the artist's draft.")
	for(var/invalid_patch in list("Sg0!h1", "Sg0001"))
		var/rejections = session.draw_rejected
		session.handle_action(artist, "draw_patch", list("patch" = invalid_patch, "revision" = base_revision))
		TEST_ASSERT(session.draw_rejected == rejections + 1 && session.bitmap == art && session.revision == base_revision, "An invalid patch was accepted in part.")
	session.handle_action(artist, "draw_patch", list("patch" = "Sg0", "revision" = base_revision - 1))
	TEST_ASSERT(session.bitmap == art && session.revision == base_revision, "A stale patch erased a newer stroke.")
	artist.mock_client = allocate(/datum/client_interface)
	customer.mock_client = allocate(/datum/client_interface)
	artist.put_in_hands(machine)
	var/datum/tgui/tattoo_studio/test_peer/artist_ui = register_peer(artist, session, TRUE)
	var/datum/tgui/tattoo_studio/test_peer/customer_ui = register_peer(customer, session, FALSE)
	artist_ui.on_act_message("review", list(), artist_ui.state)
	TEST_ASSERT_EQUAL(session.phase, "review", "The artist could not submit a sketch.")
	var/original_revision = session.revision
	TEST_ASSERT(isnull(customer_ui.received) && artist_ui.received?["phase"] == "review", "Only the initialized peer should receive the initial review update.")
	customer_ui.window.on_message("ready", list(), list())
	TEST_ASSERT(customer_ui.received?["role"] == "client" && customer_ui.received["phase"] == "review" && customer_ui.received["draft"] == art, "A late-opening customer missed the pending approval.")
	var/list/preview_directions = list()
	for(var/list/preview as anything in customer_ui.received["tattooViews"])
		if(preview["image"])
			preview_directions |= preview["direction"]
	TEST_ASSERT_EQUAL(length(preview_directions & GLOB.cardinals), 4, "The late-opening customer missed a view of the tattoo to approve.")
	customer_ui.received = null
	customer_ui.on_act_message("sync", list(), customer_ui.state)
	TEST_ASSERT(customer_ui.received?["revision"] == original_revision && session.revision == original_revision, "Resynchronizing did not return the pending revision unchanged.")
	customer_ui.close(can_be_suspended = FALSE)
	TEST_ASSERT(!QDELETED(session) && !QDELETED(artist_ui), "Closing the customer's review discarded the artist's session.")
	customer_ui = register_peer(customer, session, FALSE)
	customer_ui.window.on_message("ping/reply", list(), list())
	TEST_ASSERT(customer_ui.received?["phase"] == "review" && customer_ui.received["revision"] == original_revision, "Returning to the session did not recover the pending approval.")
	session.handle_action(artist, "approve", list("revision" = original_revision, "save" = TRUE))
	TEST_ASSERT_EQUAL(session.phase, "review", "The artist approved for the customer.")
	TEST_ASSERT(!session.finish_application(), "A draft was committed before customer approval.")
	customer_ui.on_act_message("revise", list("revision" = original_revision), customer_ui.state)
	TEST_ASSERT_EQUAL(session.phase, "draft", "The client could not return the sketch to the artist.")
	base_revision = session.revision
	artist_ui.on_act_message("draw_patch", list("patch" = "Sg0Sh0", "revision" = base_revision), artist_ui.state)
	TEST_ASSERT(customer_ui.received?["draft"] == blank && customer_ui.received["revision"] == base_revision + 1, "The customer did not see both erased pixels as one edit.")
	var/list/repaint = list("patch" = "Sg4Shf", "revision" = session.revision)
	artist_ui.on_act_message("draw_patch", repaint, artist_ui.state)
	TEST_ASSERT(customer_ui.received?["draft"] == art && artist_ui.received?["draft"] == art, "The two studio windows did not receive the same restored colors.")
	var/rejections_before_retry = session.draw_rejected
	artist_ui.on_act_message("draw_patch", repaint, artist_ui.state)
	TEST_ASSERT(session.revision == repaint["revision"] + 1 && session.draw_rejected == rejections_before_retry, "Retrying an acknowledged stroke changed or rejected the same revision.")
	artist_ui.on_act_message("review", list(), artist_ui.state)
	TEST_ASSERT(customer_ui.received?["phase"] == "review" && customer_ui.received["revision"] == session.revision, "The connected customer did not receive the revised approval.")
	session.handle_action(customer, "approve", list("revision" = original_revision))
	TEST_ASSERT_EQUAL(session.phase, "review", "An outdated approval accepted a newer review.")
	TEST_ASSERT(!session.start_application() && !session.blood_bead && !arm.generic_bleedstacks, "The needle touched the client before an approved procedure.")
	TEST_ASSERT_NULL(session.motor_sound, "The machine played while the sketch was still under review.")
	TEST_ASSERT(!machine.supply_customer && customer.tattoo_prepared, "Review consumed the client's visit supplies before needle contact.")
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
	TEST_ASSERT(session.start_application() && machine.needle_loaded && machine.supply_customer?.resolve() == customer && !customer.tattoo_prepared, "Needle contact did not bind the cartridge and preparation to this customer.")
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
	TEST_ASSERT(arm.has_drawn_tattoo(SOUTH), "The approved design did not reach the limb.")
	TEST_ASSERT(!machine.ink_doses["#dc962d"], "The first stroke color should spend its last dose.")
	TEST_ASSERT_EQUAL(machine.ink_doses[last_color], 3, "The fifteenth pigment should render and spend one dose.")
	TEST_ASSERT_EQUAL(machine.ink_doses["#262638"], 4, "An unused pigment was consumed.")
	TEST_ASSERT(!session.finish_application(), "Repeated completion consumed more supplies.")
	qdel(session)
	artist.dropItemToGround(machine)
	TEST_ASSERT(QDELETED(motor), "The motor kept playing after the procedure ended.")
	var/icon/finished = getFlatIcon(customer, defdir = SOUTH, no_anim = TRUE)
	TEST_ASSERT_EQUAL(LOWER_TEXT(finished.GetPixel(22, 18)), "#dc962d", "The blood bead obscured the completed tattoo after the session closed.")
	var/datum/bodypart_overlay/drawn_tattoo/applied = locate() in arm.bodypart_overlays
	TEST_ASSERT(applied?.design.all_views && length(customer.get_visible_drawn_tattoos(customer)) == 1, "One design must yield one tattoo in the gallery.")
	for(var/direction in GLOB.cardinals)
		customer.setDir(direction)
		var/icon/rotated = getFlatIcon(customer, no_anim = TRUE)
		var/icon/skin = arm.tattoo_skin_icon(direction)
		var/visible_ink = FALSE
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/ink = applied.design.world_icon.GetPixel(x, y, "", direction)
				if(!ink)
					continue
				TEST_ASSERT(skin?.GetPixel(x, y), "A projected pixel lies outside the arm when facing [dir2text(direction)].")
				if(LOWER_TEXT(rotated.GetPixel(x, y)) == LOWER_TEXT(ink))
					visible_ink = TRUE
		TEST_ASSERT(visible_ink && arm.has_drawn_tattoo(direction, applied.design), "Turning [dir2text(direction)] hid the tattoo on the character.")
	customer.setDir(SOUTH)

	// A new editor on another limb uses the first application's cartridge, preparation and pigment.
	TEST_ASSERT_NULL(machine.tattoo_supply_error(customer), "The same customer needed new supplies for a second tattoo.")
	artist.put_in_hands(machine)
	var/obj/item/bodypart/other_arm = customer.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/tattoo_session/followup = allocate(/datum/tattoo_session, machine, artist, customer, other_arm)
	machine.session = followup
	TEST_ASSERT(followup.set_view(SOUTH), "The second limb had no editable surface.")
	var/first_pixel = findtextEx(followup.mask_bits, "1")
	var/second_pixel = findtextEx(followup.mask_bits, "1", first_pixel + 2)
	var/stencil_pixels = splicetext(followup.bitmap, first_pixel, first_pixel + 1, "1")
	stencil_pixels = splicetext(stencil_pixels, second_pixel, second_pixel + 1, "2")
	TEST_ASSERT_NULL(followup.apply_stencil(list("bitmap" = stencil_pixels, "palette" = list("#dc962d", last_color))), "The last dose of a pigment was unavailable to a follow-up stencil for the same customer.")
	followup.handle_action(artist, "review", list())
	followup.phase = "applying"
	TEST_ASSERT(followup.start_application() && followup.finish_application() && other_arm.has_drawn_tattoo(SOUTH), "The artist could not apply a second tattoo with the existing supplies.")
	TEST_ASSERT_EQUAL(machine.ink_doses[last_color], 3, "The follow-up charged a second dose of the same pigment to one client.")
	qdel(followup)
	artist.dropItemToGround(machine)
	var/datum/component/tattoo_care/care = arm.GetComponent(/datum/component/tattoo_care)
	var/datum/component/tattoo_care/other_care = other_arm.GetComponent(/datum/component/tattoo_care)
	film.attack(customer, artist)
	TEST_ASSERT(QDELETED(film) && care?.covered_with_film && !care.fresh && other_care?.covered_with_film && !other_care.fresh, "One film did not dress the same customer's exposed fresh tattoos.")

	// An organic client with no blood can still receive a tattoo.
	ADD_TRAIT(artist, TRAIT_NOBLOOD, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/bodypart/bloodless_arm = artist.get_bodypart(BODY_ZONE_L_ARM)
	customer.zone_selected = BODY_ZONE_L_ARM
	customer.set_combat_mode(FALSE)
	var/obj/item/tattoo_wipe/next_wipe = allocate(/obj/item/tattoo_wipe)
	next_wipe.attack(artist, customer)
	TEST_ASSERT(artist.tattoo_prepared && machine.tattoo_supply_error(artist), "Another prepared customer was accepted with the used cartridge.")
	var/obj/item/tattoo_needle/replacement = allocate(/obj/item/tattoo_needle)
	machine.item_interaction(customer, replacement, list())
	TEST_ASSERT(QDELETED(replacement) && machine.needle_loaded && !machine.supply_customer && !length(machine.used_inks), "Installing a new cartridge did not reset the visit supplies.")
	TEST_ASSERT_NULL(machine.tattoo_supply_error(artist), "The next customer was still blocked after replacing the cartridge.")
	TEST_ASSERT_NOTNULL(machine.tattoo_supply_error(customer), "The original customer's wipe also counted toward a new visit.")
	TEST_ASSERT(!("#dc962d" in machine.tattoo_palette(artist)), "A depleted ink carried over to a new customer.")
	for(var/interrupt in list(TRUE, FALSE))
		customer.put_in_hands(machine)
		var/datum/tattoo_session/bloodless_session = allocate(/datum/tattoo_session, machine, customer, artist, bloodless_arm)
		machine.session = bloodless_session
		TEST_ASSERT(bloodless_session.set_view(SOUTH), "An organic bloodless limb had no editable surface.")
		var/pixel = findtextEx(bloodless_session.mask_bits, "1")
		var/stroke = splicetext(bloodless_session.bitmap, pixel, pixel + 1, "1")
		bloodless_session.handle_action(customer, "draw", list("pixels" = stroke, "revision" = bloodless_session.revision))
		bloodless_session.handle_action(customer, "review", list())
		bloodless_session.phase = "applying"
		TEST_ASSERT(bloodless_session.start_application(), "The needle could not tattoo a bloodless client's skin.")
		TEST_ASSERT(!bloodless_session.blood_bead && !bloodless_arm.generic_bleedstacks, "A bloodless client's limb bled.")
		if(interrupt)
			var/datum/sound_token/interrupted_motor = bloodless_session.motor_sound
			TEST_ASSERT(!QDELETED(interrupted_motor), "The motor never started on the interrupted procedure.")
			customer.dropItemToGround(machine)
			TEST_ASSERT(QDELETED(interrupted_motor) && !machine.session, "Dropping the machine did not stop the session and its motor.")
			TEST_ASSERT(machine.supply_customer?.resolve() == artist && !artist.tattoo_prepared && machine.ink_doses["#262638"] == 4, "Interrupting contact reset the cartridge or spent ink before the transfer.")
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
	TEST_ASSERT(arm.has_drawn_tattoo(SOUTH) && machine.needle_loaded && machine.supply_customer?.resolve() == model && machine.ink_doses["#262638"] == 3, "Solo approval did not complete the tattoo with supplies bound to the mannequin.")
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
	TEST_ASSERT_NULL(machine.tattoo_supply_error(stock_dummy), "The stock Test Dummy required preparation before drawing.")
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
