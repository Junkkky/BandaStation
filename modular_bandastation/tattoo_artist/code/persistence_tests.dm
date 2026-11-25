/datum/unit_test/drawn_tattoo_persistence/proc/drop_running_machine(mob/living/artist)
	SIGNAL_HANDLER
	var/obj/item/tattoo_machine/machine = artist.is_holding_item_of_type(/obj/item/tattoo_machine)
	if(machine?.session?.motor_sound)
		artist.dropItemToGround(machine)

/// Submit the same review and approval actions as the two studio windows.
/datum/unit_test/drawn_tattoo_persistence/proc/check_approval(mob/living/carbon/human/artist, mob/living/carbon/human/wearer, obj/item/tattoo_machine/machine, obj/item/bodypart/limb, save, expected_default, interrupt = FALSE)
	artist.zone_selected = limb.body_zone
	var/obj/item/tattoo_needle/needle = allocate(/obj/item/tattoo_needle)
	var/obj/item/tattoo_wipe/wipe = allocate(/obj/item/tattoo_wipe)
	machine.item_interaction(artist, needle, list())
	wipe.attack(wearer, artist)
	var/datum/tattoo_session/session = allocate(/datum/tattoo_session, machine, artist, wearer, limb)
	machine.session = session
	TEST_ASSERT(session.can_continue() && session.set_view(SOUTH), "The prepared limb could not be tattooed.")
	var/list/wearer_window = session.ui_data(wearer)
	var/list/artist_window = session.ui_data(artist)
	TEST_ASSERT(wearer_window["canSave"] && !artist_window["canSave"], "The studio offered the save choice to the wrong participant.")
	TEST_ASSERT_EQUAL(wearer_window["saveByDefault"], expected_default, "The studio used a different character's default.")
	TEST_ASSERT(!artist_window["saveByDefault"], "The studio showed the customer's default to the artist.")
	var/pixel = findtextEx(session.mask_bits, "11")
	var/stroke = splicetext(session.bitmap, pixel, pixel + 2, "12")
	session.handle_action(artist, "draw", list("pixels" = stroke, "revision" = session.revision))
	session.handle_action(artist, "review", list())
	var/list/approval = list("revision" = session.revision)
	if(!isnull(save))
		approval["save"] = save
	if(interrupt)
		RegisterSignal(artist, COMSIG_DO_AFTER_BEGAN, PROC_REF(drop_running_machine))
	TEST_ASSERT(session.handle_action(wearer, "approve", approval), "The wearer could not approve the drawing.")
	var/deadline = world.time + 12 SECONDS
	UNTIL(QDELETED(session) || world.time >= deadline)
	if(interrupt)
		UnregisterSignal(artist, COMSIG_DO_AFTER_BEGAN)
		TEST_ASSERT(!artist.is_holding(machine), "Needle contact did not trigger the interruption.")
		TEST_ASSERT(QDELETED(session) && !limb.has_drawn_tattoo(SOUTH), "An interrupted session completed its drawing.")
		return
	var/datum/bodypart_overlay/drawn_tattoo/tattoo = locate() in limb.bodypart_overlays
	TEST_ASSERT_NOTNULL(tattoo, "The completed procedure did not put ink on the body.")
	TEST_ASSERT_EQUAL(wearer.is_tattoo_persistent(limb, tattoo.design), isnull(save) ? expected_default : save, "The completed tattoo did not honor the wearer's approval choice.")

/// The wearer chooses the saved drawings for the character slot they joined as.
/datum/unit_test/drawn_tattoo_persistence/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/player = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/character_portrait_test, player)
	wearer.mock_client = player
	player.prefs = preferences
	player.mob = wearer
	wearer.mind_initialize()
	wearer.mind.set_original_character(wearer)
	wearer.mind.original_character_slot_index = 1
	wearer.bind_tattoo_character(preferences, 1)

	// The player has opened another slot in preferences since joining.
	var/list/first_slot = preferences.savefile.get_entry("character1")
	var/datum/preference/preference = GLOB.preference_entries_by_key["persistent_tattoos"]
	TEST_ASSERT_NOTNULL(preference, "The character menu has no tattoo preference.")
	first_slot -= preference.savefile_key
	TEST_ASSERT(preferences.load_character(1) && !preferences.read_preference(preference.type), "A legacy character opted in without choosing a default.")
	preferences.max_save_slots = max(preferences.max_save_slots, 2)
	preferences.savefile.set_entry("character2", list("version" = first_slot["version"]))
	TEST_ASSERT(preferences.load_character(2), "The second character slot could not be selected.")
	other.mock_client = allocate(/datum/client_interface)
	other.forceMove(get_step(wearer, EAST))
	other.set_combat_mode(FALSE)
	var/obj/item/tattoo_machine/machine = allocate(/obj/item/tattoo_machine)
	other.put_in_hands(machine)
	var/obj/item/bodypart/right_arm = wearer.get_bodypart(BODY_ZONE_R_ARM)
	check_approval(other, wearer, machine, right_arm, TRUE, FALSE)
	var/datum/bodypart_overlay/drawn_tattoo/approved = locate() in right_arm.bodypart_overlays
	TEST_ASSERT_NOTNULL(approved, "The opt-in session did not finish.")
	TEST_ASSERT(wearer.set_visible_tattoo_saved(wearer, REF(approved), FALSE), "The wearer could not undo the opt-in for the right arm.")
	TEST_ASSERT(preferences.load_character(1) && preferences.update_preference(preference, TRUE) && preferences.save_character(), "The character menu could not enable the new default.")
	preferences.savefile.save()
	TEST_ASSERT(preferences.savefile.load() && preferences.load_character(1) && preferences.read_preference(preference.type), "The owner's default did not survive a disk reload.")
	TEST_ASSERT(preferences.load_character(2) && !preferences.read_preference(preference.type), "The second character inherited the owner's saved default.")
	var/obj/item/bodypart/left_leg = wearer.get_bodypart(BODY_ZONE_L_LEG)
	check_approval(other, wearer, machine, left_leg, null, TRUE)
	var/datum/bodypart_overlay/drawn_tattoo/inherited = locate() in left_leg.bodypart_overlays
	TEST_ASSERT_NOTNULL(inherited, "Approval without an override did not finish.")
	TEST_ASSERT(wearer.set_visible_tattoo_saved(wearer, REF(inherited), FALSE), "The wearer could not forget the drawing saved by default.")
	var/obj/item/bodypart/arm = wearer.get_bodypart(BODY_ZONE_L_ARM)
	check_approval(other, wearer, machine, arm, FALSE, TRUE)
	check_approval(other, wearer, machine, wearer.get_bodypart(BODY_ZONE_R_LEG), TRUE, TRUE, interrupt = TRUE)
	first_slot = preferences.savefile.get_entry("character1")
	TEST_ASSERT(!length(first_slot["drawn_tattoos"]), "An interrupted opt-in wrote a drawing to the character file.")
	var/datum/bodypart_overlay/drawn_tattoo/tattoo = locate() in arm.bodypart_overlays
	TEST_ASSERT_NOTNULL(tattoo, "The completed drawing was missing from the limb.")
	var/datum/tattoo_design/design = tattoo.design
	TEST_ASSERT(!wearer.is_tattoo_persistent(arm, design), "A new drawing was saved before the wearer chose it.")
	TEST_ASSERT(!wearer.set_visible_tattoo_saved(other, REF(tattoo), TRUE), "Another viewer could save the wearer's drawing.")
	TEST_ASSERT(!preferences.has_saved_tattoo(1, arm, design), "The refused request wrote to the character slot.")
	TEST_ASSERT(wearer.set_visible_tattoo_saved(wearer, REF(tattoo), TRUE), "The wearer could not save their own drawing.")
	TEST_ASSERT(wearer.is_tattoo_persistent(arm, design), "The wearer still sees their saved drawing as temporary.")
	var/list/wearer_gallery = wearer.get_visible_drawn_tattoos(wearer)
	TEST_ASSERT_EQUAL(length(wearer_gallery), 3, "The wearer could not inspect their completed tattoos.")
	for(var/list/entry as anything in wearer_gallery)
		TEST_ASSERT_EQUAL(entry["saved"], entry["id"] == REF(tattoo), "The gallery did not show the wearer's choice for each drawing.")
	var/list/public_gallery = wearer.get_visible_drawn_tattoos(other)
	TEST_ASSERT_EQUAL(length(public_gallery), 3, "The nearby artist could not inspect the visible tattoos.")
	for(var/list/entry as anything in public_gallery)
		TEST_ASSERT(!("saved" in entry), "Another viewer received the wearer's private save choice.")
	TEST_ASSERT(!preferences.has_saved_tattoo(2, arm, design), "The drawing was also saved to the open preferences slot.")
	TEST_ASSERT_EQUAL(preferences.default_slot, 2, "Saving a tattoo switched the active preferences slot.")

	// Re-read the actual JSON file before simulating a new round.
	TEST_ASSERT(preferences.savefile.load(), "The opt-in did not write a preferences file.")
	TEST_ASSERT(preferences.has_saved_tattoo(1, arm, design), "Reloading the file lost the originating character's drawing.")
	TEST_ASSERT_EQUAL(other.restore_saved_tattoos(preferences, 2), 0, "The second character spawned with the first character's drawing.")
	var/obj/item/bodypart/new_arm = other.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(other.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING) && !new_arm.tattoo_is_exposed(), "The round-start uniform did not cover the new arm.")
	var/slot_side = "[arm.body_zone]:[design.side]"
	for(var/invalid_field in list("skin", "bitmap", "palette"))
		first_slot = preferences.savefile.get_entry("character1")
		var/list/records = first_slot["drawn_tattoos"]
		var/list/record = records[slot_side]
		TEST_ASSERT(islist(record), "The saved file has no drawing on the expected limb and side.")
		record[invalid_field] = "invalid"
		TEST_ASSERT_EQUAL(other.restore_saved_tattoos(preferences, 1), 0, "A drawing with an incompatible or malformed [invalid_field] was restored.")
		TEST_ASSERT(!new_arm.has_drawn_tattoo(SOUTH), "Rejecting an invalid record left a tattoo behind.")
		TEST_ASSERT(preferences.savefile.load(), "The valid drawing could not be reloaded.")
	TEST_ASSERT_EQUAL(other.restore_saved_tattoos(preferences, 1), 1, "A compatible limb under round-start clothing lost its drawing.")
	TEST_ASSERT_EQUAL(other.restore_saved_tattoos(preferences, 1), 0, "Running the spawn hook twice duplicated the drawing.")
	var/datum/bodypart_overlay/drawn_tattoo/restored = locate() in new_arm.bodypart_overlays
	TEST_ASSERT_NOTNULL(restored, "No overlay was attached to the restored limb.")
	TEST_ASSERT_EQUAL(restored.design.render_key, design.render_key, "The bitmap, side or palette changed between rounds.")
	TEST_ASSERT(!new_arm.generic_bleedstacks && !new_arm.GetComponent(/datum/component/tattoo_care), "An old tattoo spawned as a fresh puncture.")
	TEST_ASSERT(wearer.set_visible_tattoo_saved(wearer, REF(tattoo), FALSE), "The wearer could not forget their drawing.")
	TEST_ASSERT(arm.has_drawn_tattoo(SOUTH), "Forgetting a saved drawing erased the current body's ink.")
	TEST_ASSERT(preferences.savefile.load(), "The updated preferences file could not be read.")
	TEST_ASSERT(!preferences.has_saved_tattoo(1, arm, design), "The forgotten drawing was still in the file.")
