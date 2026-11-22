/datum/unit_test/detomatix
	var/list/blast

/datum/unit_test/detomatix/proc/record_blast(datum/source, list/arguments)
	SIGNAL_HANDLER
	blast = arguments
	return COMSIG_CANCEL_EXPLOSION

/datum/unit_test/detomatix/Run()
	var/mob/living/carbon/human/consistent/user = EASY_ALLOCATE()
	var/obj/item/modular_computer/pda/nukeops/source = EASY_ALLOCATE()
	var/obj/item/modular_computer/pda/target = EASY_ALLOCATE()
	source.imprint_id("Operative", "Agent")
	target.imprint_id("Recipient", "Assistant")
	var/datum/computer_file/program/messenger/sender = locate() in source.stored_files
	var/datum/computer_file/program/messenger/receiver = locate() in target.stored_files
	var/datum/tgui/ui = allocate(/datum/tgui, user, source, "NtosMessenger")
	ui.status = UI_INTERACTIVE
	var/list/params = list("ref" = REF(receiver))
	var/datum/uplink_handler/handler = allocate(/datum/uplink_handler)
	handler.uplink_flag = UPLINK_NUKE_OPS
	handler.telecrystals = 6
	var/datum/uplink_item/entry = SStraitor.uplink_items_by_type[/datum/uplink_item/explosives/detomatix]
	TEST_ASSERT(handler.purchase_item(user, entry, user), "The operative uplink should sell Detomatix for 6 TC.")
	TEST_ASSERT_EQUAL(handler.telecrystals, 0, "Detomatix should cost exactly 6 TC.")
	var/obj/item/disk/computer/virus/detomatix/disk = user.get_active_held_item()
	TEST_ASSERT(istype(disk), "The uplink should issue the usable cartridge.")
	TEST_ASSERT_EQUAL(source.computer_disk_act(user, disk), ITEM_INTERACT_SUCCESS, "An operative could not insert the cartridge.")

	var/obj/item/modular_computer/pda/nukeops/ally = EASY_ALLOCATE()
	ally.imprint_id("Second operative", "Agent")
	var/datum/computer_file/program/messenger/ally_app = locate() in ally.stored_files
	TEST_ASSERT(!sender.ui_act("PDA_detonate", list("ref" = REF(ally_app)), ui, ui.state), "An operative PDA accepted a hostile command.")
	TEST_ASSERT(!QDELETED(ally), "An ally's PDA was destroyed.")
	TEST_ASSERT_EQUAL(disk.charges, 4, "An ally consumed a charge.")

	receiver.sending_and_receiving = FALSE
	TEST_ASSERT(!sender.ui_act("PDA_detonate", params, ui, ui.state), "A disabled messenger accepted the command.")
	TEST_ASSERT_EQUAL(disk.charges, 4, "Disabled receiving consumed a charge.")
	receiver.sending_and_receiving = TRUE
	disk.charges = 0
	TEST_ASSERT(!sender.ui_act("PDA_detonate", params, ui, ui.state), "An exhausted cartridge accepted the command.")
	TEST_ASSERT(!QDELETED(target), "A spent cartridge destroyed the target.")
	disk.charges = 1
	disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!sender.ui_act("PDA_detonate", params, ui, ui.state), "An ejected cartridge still worked.")
	user.put_in_hands(disk)
	source.computer_disk_act(user, disk)

	RegisterSignal(target, COMSIG_ATOM_EXPLODE, PROC_REF(record_blast))
	var/datum/pda_chat/chat = sender.create_chat(REF(receiver))
	TEST_ASSERT(sender.ui_act("PDA_detonate", list("ref" = REF(chat)), ui, ui.state), "A contact with an existing chat could not be targeted.")
	TEST_ASSERT(QDELETED(target), "The command did not immediately destroy the recipient's PDA.")
	TEST_ASSERT_EQUAL(disk.charges, 0, "A successful detonation should cost one charge.")
	TEST_ASSERT_NOTNULL(blast, "The PDA was deleted without an explosion.")
	TEST_ASSERT_EQUAL(blast[EXARG_KEY_DEV_RANGE], -1, "The explosion had a devastation range.")
	TEST_ASSERT_EQUAL(blast[EXARG_KEY_HEAVY_RANGE], -1, "The explosion had a heavy damage range.")
	TEST_ASSERT_EQUAL(blast[EXARG_KEY_LIGHT_RANGE], 2, "The light damage range should be two tiles.")

	var/obj/item/modular_computer/pda/resistant = EASY_ALLOCATE()
	resistant.imprint_id("Protected contact", "Assistant")
	var/datum/computer_file/program/messenger/resistant_app = locate() in resistant.stored_files
	resistant_app.detomatix_resistance = 7 // Seven points always resist the command.
	disk.charges = 2
	TEST_ASSERT(disk.send_virus(source, resistant, user, "test"), "A resisted forged message did not finish its attempt.")
	TEST_ASSERT_EQUAL(disk.charges, 1, "A software block should spend one charge.")
	TEST_ASSERT(!QDELETED(source) && !QDELETED(resistant), "A blocked forged message exploded a device.")
	blast = null
	RegisterSignal(source, COMSIG_ATOM_EXPLODE, PROC_REF(record_blast))
	TEST_ASSERT(sender.ui_act("PDA_detonate", list("ref" = REF(resistant_app)), ui, ui.state), "A resisted direct command did not finish its attempt.")
	TEST_ASSERT(!QDELETED(resistant), "The direct command destroyed a fully resistant target.")
	TEST_ASSERT_EQUAL(disk.charges, 0, "A resisted command should spend one charge.")
	TEST_ASSERT_EQUAL(!!blast, !!QDELETED(source), "Only a backfire should explode the sender's PDA.")
