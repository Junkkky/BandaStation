/** A single known commodity keeps unrelated purchase and acceptance fixtures independent of weighted selection. */
/obj/machinery/trade_hub_core/industrial/trade_hub_test
	batch_credit_target = 400
	demand_multipliers = list("Сырьё" = 1)
	request_types = list(/datum/trade_hub_request/industrial_iron)

/** A fourth genuine commodity lets the history scenario exclude two recent goods without a random expectation. */
/datum/trade_hub_request/industrial_glass/trade_hub_test
	group = "Инструменты"

/** Real rods serve as another distinct commodity in the isolated selection pool. */
/datum/trade_hub_request/industrial_extra/trade_hub_test
	group = "Инструменты"

/** The history fixture retains production selection while isolating other groups and their active goods. */
/obj/machinery/trade_hub_core/industrial/trade_hub_test/history
	request_types = list(
		/datum/trade_hub_request/industrial_iron,
		/datum/trade_hub_request/industrial_power_tools,
		/datum/trade_hub_request/industrial_glass/trade_hub_test,
		/datum/trade_hub_request/industrial_extra/trade_hub_test,
	)

/** Only the commodity choice is fixed; production industrial pricing and its target remain in effect. */
/obj/machinery/trade_hub_core/industrial/trade_hub_credit_test
	request_types = list(/datum/trade_hub_request/industrial_iron)

/** A fixed glass selection exposes the medical profile's premium through an actual delivery. */
/obj/machinery/trade_hub_core/medical/trade_hub_credit_test
	request_types = list(/datum/trade_hub_request/medical_glass)

/** A fixed component selection exposes the larger corporate batch through an actual delivery. */
/obj/machinery/trade_hub_core/corporate/trade_hub_credit_test
	request_types = list(/datum/trade_hub_request/corporate_bluespace_bins)

/** Shared real machinery fixture; restores the economic globals even after an assertion returns. */
/datum/unit_test/trade_hub
	abstract_type = /datum/unit_test/trade_hub
	/// Cargo account used by production transactions.
	var/datum/bank_account/department/cargo_account
	/// Balance before this test changes the fixture account.
	var/original_balance
	/// Debt must not consume part of a delivery reward unrelated to this test.
	var/original_debt
	/// Preserve the original history list while transactions write to a private copy.
	var/list/original_history
	/// Generating a real supply order advances this global counter.
	var/original_order_number
	/// Departmental transactions may unlock the scrapheap shuttle as a side effect.
	var/list/original_purchase_requirements
	/// Live catalogue flags changed by unlock and wrapping scenarios.
	var/list/original_pack_flags = list()
	/// Real industrial core shared by each scenario's machinery.
	var/obj/machinery/trade_hub_core/industrial/core
	/// Goods offered through the production acceptance entry point.
	var/obj/machinery/trade_hub_pad/input/input_pad
	/// Actual purchased crates are generated here.
	var/obj/machinery/trade_hub_pad/output/output_pad
	/// A space tile outside the powered test room, for real area power transitions.
	var/turf/unpowered_tile

/datum/unit_test/trade_hub/New()
	..()
	cargo_account = SSeconomy.get_dep_account(ACCOUNT_CAR)
	original_order_number = SSshuttle.order_number
	original_purchase_requirements = SSshuttle.shuttle_purchase_requirements_met
	SSshuttle.shuttle_purchase_requirements_met = original_purchase_requirements.Copy()
	if(cargo_account)
		original_balance = cargo_account.account_balance
		original_debt = cargo_account.account_debt
		original_history = cargo_account.transaction_history
		cargo_account.account_debt = 0
		cargo_account.transaction_history = original_history?.Copy()
	core = allocate(/obj/machinery/trade_hub_core/industrial/trade_hub_test)
	core.hub_id = "unit_test_[REF(src)]"
	input_pad = allocate(/obj/machinery/trade_hub_pad/input, get_step(run_loc_floor_bottom_left, NORTH))
	input_pad.hub_id = core.hub_id
	output_pad = allocate(/obj/machinery/trade_hub_pad/output, get_step(run_loc_floor_bottom_left, EAST))
	output_pad.hub_id = core.hub_id
	unpowered_tile = locate(run_loc_floor_bottom_left.x + 20, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	core.power_change()
	input_pad.power_change()
	output_pad.power_change()

/datum/unit_test/trade_hub/Destroy()
	QDEL_LIST(allocated)
	for(var/datum/supply_pack/pack as anything in original_pack_flags)
		if(!QDELETED(pack))
			pack.order_flags = original_pack_flags[pack]
	original_pack_flags.Cut()
	if(cargo_account)
		cargo_account.account_balance = original_balance
		cargo_account.account_debt = original_debt
		cargo_account.transaction_history = original_history
	SSshuttle.order_number = original_order_number
	SSshuttle.shuttle_purchase_requirements_met = original_purchase_requirements
	cargo_account = null
	original_history = null
	original_purchase_requirements = null
	core = null
	input_pad = null
	output_pad = null
	unpowered_tile = null
	return ..()

/** Preserve a registry pack's flags before exercising a live availability transition. */
/datum/unit_test/trade_hub/proc/remember_pack_flags(datum/supply_pack/pack)
	if(!(pack in original_pack_flags))
		original_pack_flags[pack] = pack.order_flags

/** Read one offer through the real terminal's server-side UI data. */
/datum/unit_test/trade_hub/proc/find_offer(obj/machinery/computer/trade_hub/terminal, pack_id)
	var/list/data = terminal.ui_data(null)
	for(var/list/offer as anything in data["offers"])
		if(offer["id"] == "[pack_id]")
			return offer
	return null

/** Create an exact batch with owned stacks below their split limit, or individual real items. */
/datum/unit_test/trade_hub/proc/offer_request_goods(datum/trade_hub_request/request)
	var/amount = request.batch_size
	if(ispath(request.item_type, /obj/item/stack))
		var/obj/item/stack/stack_type = request.item_type
		while(amount > 0)
			var/portion = min(amount, initial(stack_type.max_amount))
			allocate(request.item_type, get_turf(input_pad), portion, FALSE)
			amount -= portion
	else
		for(var/index in 1 to amount)
			allocate(request.item_type, get_turf(input_pad))

/** The last stocked unit creates one complete pack and cannot be bought a second time. */
/datum/unit_test/trade_hub/purchase_last_unit

/datum/unit_test/trade_hub/purchase_last_unit/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/pack_type = /datum/supply_pack/engineering/tools
	var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_type]
	var/price = pack.get_cost()
	cargo_account.account_balance = price * 2
	core.stock[pack_type] = 1

	TEST_ASSERT(core.buy("[pack_type]"), "The last stocked unit could not be purchased.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 0, "Purchasing the last unit did not exhaust local stock.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "The purchase did not debit exactly its quoted price.")
	var/list/crates = list()
	for(var/obj/structure/closet/crate/crate in get_turf(output_pad))
		crates += crate
	TEST_ASSERT_EQUAL(length(crates), 1, "One purchase did not issue exactly one crate on the output pad.")
	var/obj/structure/closet/crate/delivered_crate = crates[1]
	var/electrical_toolboxes = 0
	var/mechanical_toolboxes = 0
	for(var/obj/item/storage/toolbox/toolbox in delivered_crate)
		if(istype(toolbox, /obj/item/storage/toolbox/electrical))
			electrical_toolboxes++
		if(istype(toolbox, /obj/item/storage/toolbox/mechanical))
			mechanical_toolboxes++
	TEST_ASSERT_EQUAL(electrical_toolboxes, 3, "The purchased pack did not contain its three electrical toolboxes.")
	TEST_ASSERT_EQUAL(mechanical_toolboxes, 3, "The purchased pack did not contain its three mechanical toolboxes.")
	// Clear the pad so the second purchase reaches the exhausted-stock validation.
	delivered_crate.forceMove(get_step(get_turf(output_pad), NORTH))
	TEST_ASSERT(!core.buy("[pack_type]"), "An exhausted offer could be purchased again.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "An exhausted offer charged cargo again.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 0, "An exhausted offer decremented below zero.")
	TEST_ASSERT_NULL(locate(/obj/structure/closet/crate) in get_turf(output_pad), "The rejected repeat purchase issued another crate.")

/** Blockage, insufficient funds and loss of either machine's power must leave the transaction untouched. */
/datum/unit_test/trade_hub/purchase_denials

/datum/unit_test/trade_hub/purchase_denials/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/pack_type = /datum/supply_pack/engineering/tools
	var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_type]
	var/price = pack.get_cost()
	cargo_account.account_balance = price
	var/obj/item/coin/blocker = allocate(/obj/item/coin, get_turf(output_pad))
	TEST_ASSERT(!core.buy("[pack_type]"), "An item on the output pad did not block purchase.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "An item-blocked purchase charged cargo.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 3, "An item-blocked purchase consumed stock.")
	qdel(blocker)
	var/mob/mob_blocker = allocate(/mob, get_turf(output_pad))
	TEST_ASSERT(!core.buy("[pack_type]"), "A mob on the output pad did not block purchase.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "A mob-blocked purchase charged cargo.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 3, "A mob-blocked purchase consumed stock.")
	qdel(mob_blocker)

	cargo_account.account_balance = price - 1
	TEST_ASSERT(!core.buy("[pack_type]"), "A purchase succeeded without enough cargo funds.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price - 1, "A rejected unaffordable purchase changed the balance.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 3, "A rejected unaffordable purchase consumed stock.")
	cargo_account.account_balance = price
	var/turf/output_tile = get_turf(output_pad)
	output_pad.forceMove(unpowered_tile)
	output_pad.power_change()
	TEST_ASSERT(!core.buy("[pack_type]"), "An unpowered output pad issued a purchase.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "An unpowered output pad charged cargo.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 3, "An unpowered output pad consumed stock.")
	output_pad.forceMove(output_tile)
	output_pad.power_change()
	core.forceMove(unpowered_tile)
	core.power_change()
	TEST_ASSERT(!core.buy("[pack_type]"), "An unpowered core issued a purchase.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "An unpowered core charged cargo.")
	TEST_ASSERT_EQUAL(core.stock[pack_type], 3, "An unpowered core consumed stock.")
	TEST_ASSERT_NULL(locate(/obj/structure/closet/crate) in output_tile, "A denied purchase issued a crate.")

/** Acceptance pays only for the current batch, preserving excess, wrong goods and a closed crate's contents. */
/datum/unit_test/trade_hub/accept_exact_goods

/datum/unit_test/trade_hub/accept_exact_goods/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	cargo_account.account_balance = 1000
	var/request_type = /datum/trade_hub_request/industrial_iron
	var/datum/trade_hub_request/request = core.requests[request_type]
	var/turf/input_tile = get_turf(input_pad)
	var/obj/item/stack/sheet/glass/wrong_goods = allocate(/obj/item/stack/sheet/glass, input_tile, 10, FALSE)
	var/obj/structure/closet/crate/closed_crate = allocate(/obj/structure/closet/crate, input_tile)
	var/obj/item/stack/sheet/iron/enclosed_goods = allocate(/obj/item/stack/sheet/iron, closed_crate, 20, FALSE)
	var/obj/item/stack/sheet/iron/cyborg_goods = allocate(/obj/item/stack/sheet/iron, input_tile, 20, FALSE)
	cyborg_goods.source = allocate(/datum/robot_energy_storage/material/iron)
	cyborg_goods.is_cyborg = TRUE
	var/obj/item/stack/sheet/iron/abstract_goods = allocate(/obj/item/stack/sheet/iron, input_tile, 20, FALSE)
	abstract_goods.item_flags |= ABSTRACT
	var/obj/item/stack/sheet/iron/hologram_goods = allocate(/obj/item/stack/sheet/iron, input_tile, 20, FALSE)
	hologram_goods.flags_1 |= HOLOGRAM_1
	TEST_ASSERT(!core.accept("[request_type]"), "Wrong, closed, cyborg, abstract or holographic goods were accepted.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1000, "Rejected goods generated a payment.")
	TEST_ASSERT_EQUAL(enclosed_goods.amount, 20, "Iron was consumed from a closed crate.")
	var/obj/structure/closet/crate/open_crate = allocate(/obj/structure/closet/crate, input_tile)
	open_crate.open(special_effects = FALSE)
	// Stacks inside an already open crate must use the same acceptance rules as loose cargo.
	var/obj/item/stack/sheet/iron/offered_goods = allocate(/obj/item/stack/sheet/iron, open_crate, 25, FALSE)
	TEST_ASSERT(core.accept("[request_type]"), "A batch inside an open crate could not be accepted.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1400, "The batch did not pay for exactly twenty iron sheets.")
	TEST_ASSERT_EQUAL(offered_goods.amount, 5, "Acceptance did not preserve excess stack units.")
	TEST_ASSERT_EQUAL(offered_goods.loc, open_crate, "Acceptance moved the unconsumed stack out of its crate.")
	TEST_ASSERT_EQUAL(wrong_goods.amount, 10, "Acceptance consumed a different requested commodity.")
	TEST_ASSERT_EQUAL(enclosed_goods.amount, 20, "Acceptance consumed the closed crate's contents.")
	TEST_ASSERT_EQUAL(cyborg_goods.source.energy, 60 * SHEET_MATERIAL_AMOUNT, "Acceptance consumed a cyborg synthesizer's resource.")
	TEST_ASSERT_EQUAL(abstract_goods.amount, 20, "Acceptance consumed an abstract item.")
	TEST_ASSERT_EQUAL(hologram_goods.amount, 20, "Acceptance consumed holographic sheets.")
	TEST_ASSERT_EQUAL(request.remaining, 40, "Acceptance did not deduct exactly one batch from finite demand.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 3, "Delivery replenished stock before its processing delay.")
	TEST_ASSERT(!core.accept("[request_type]"), "A pending batch accepted a duplicate submission.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1400, "A duplicate submission paid twice.")
	TEST_ASSERT_EQUAL(offered_goods.amount, 5, "A duplicate submission consumed excess goods.")

/** A real scheduled batch pauses without power, then replenishes only its local group up to capacity. */
/datum/unit_test/trade_hub/restock_timer

/datum/unit_test/trade_hub/restock_timer/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	cargo_account.account_balance = 1000
	var/obj/machinery/trade_hub_core/industrial/other_core = allocate(/obj/machinery/trade_hub_core/industrial, get_step(get_turf(input_pad), NORTH))
	other_core.hub_id = "other_[REF(src)]"
	var/request_type = /datum/trade_hub_request/industrial_iron
	var/datum/trade_hub_request/request = core.requests[request_type]
	request.restock_delay = 1 SECONDS
	core.stock[/datum/supply_pack/engineering/tools] = 8
	allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
	TEST_ASSERT(core.accept("[request_type]"), "The replenishment batch could not be delivered.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 8, "Stock replenished synchronously instead of through the timer.")
	var/turf/core_tile = get_turf(core)
	core.forceMove(unpowered_tile)
	core.power_change()
	// Allow the actual due callback to run while the core is unpowered.
	var/deadline = world.time + request.restock_delay + 2 SECONDS
	UNTIL(world.time >= deadline)
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 8, "The timer replenished an unpowered core.")
	core.forceMove(core_tile)
	core.power_change()
	deadline = world.time + 5 SECONDS
	UNTIL(core.stock[/datum/supply_pack/engineering/tools] == 9 || world.time >= deadline)
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 9, "The due batch did not replenish after power returned, or exceeded capacity.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/power], 1, "Iron replenished the unrelated electronics group.")
	TEST_ASSERT_EQUAL(other_core.stock[/datum/supply_pack/engineering/tools], 3, "A delivery replenished another core's inventory.")
	TEST_ASSERT_EQUAL(request.delivered, 0, "The completed batch did not reopen acceptance.")
	TEST_ASSERT_EQUAL(request.remaining, 40, "Replenishment restored exhausted demand.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1400, "Timer completion duplicated the delivery payment.")
	// The next batch must finish through its real timer while power remains uninterrupted.
	core.stock[/datum/supply_pack/engineering/tools] = 2
	allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
	TEST_ASSERT(core.accept("[request_type]"), "Acceptance did not reopen for the next batch.")
	deadline = world.time + 5 SECONDS
	UNTIL(core.stock[/datum/supply_pack/engineering/tools] == 4 || world.time >= deadline)
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 4, "The live timer did not replenish a continuously powered core exactly once.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/power], 1, "The live timer replenished an unrelated group.")
	TEST_ASSERT_EQUAL(other_core.stock[/datum/supply_pack/engineering/tools], 3, "The live timer replenished another core.")
	TEST_ASSERT_EQUAL(request.remaining, 20, "The next batch did not preserve the finite quota.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1800, "The next batch was not paid exactly once.")

/** Removing a core releases its owned demand and removes its pending callback from the real timer queue. */
/datum/unit_test/trade_hub/delete_pending_batch

/datum/unit_test/trade_hub/delete_pending_batch/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/request_type = /datum/trade_hub_request/industrial_iron
	var/datum/trade_hub_request/request = core.requests[request_type]
	allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
	TEST_ASSERT(core.accept("[request_type]"), "The batch could not be delivered before core deletion.")
	var/pending_timer = request.restock_timer
	TEST_ASSERT_NOTNULL(timeleft(pending_timer), "The accepted batch did not create a cancellable timer.")
	qdel(core)
	TEST_ASSERT(QDELETED(request), "Deleting the core did not release its owned request.")
	TEST_ASSERT_NULL(timeleft(pending_timer), "Deleting the core left its replenishment callback queued.")

/** Runtime cargo-console offers must be assigned without losing generated IDs or corporate ownership. */
/datum/unit_test/trade_hub/catalogue_coverage

/datum/unit_test/trade_hub/catalogue_coverage/Run()
	var/list/hubs = list()
	for(var/profile in list(
		/obj/machinery/trade_hub_core/industrial,
		/obj/machinery/trade_hub_core/medical,
		/obj/machinery/trade_hub_core/agricultural,
		/obj/machinery/trade_hub_core/research,
		/obj/machinery/trade_hub_core/security,
		/obj/machinery/trade_hub_core/service,
		/obj/machinery/trade_hub_core/corporate,
	))
		hubs += allocate(profile)
	var/list/assigned_ids = list()
	var/obj/machinery/trade_hub_core/corporate/corporate
	for(var/obj/machinery/trade_hub_core/hub as anything in hubs)
		hub.ensure_catalog()
		if(istype(hub, /obj/machinery/trade_hub_core/corporate))
			corporate = hub
		var/list/request_groups = list()
		var/list/request_items = list()
		for(var/request_type in hub.requests)
			var/datum/trade_hub_request/request = hub.requests[request_type]
			request_groups[request.group] = (request_groups[request.group] || 0) + 1
			TEST_ASSERT(request_groups[request.group] <= hub.requests_per_group, "[hub.type] exceeded its active demand limit for [request.group].")
			TEST_ASSERT(!(request.item_type in request_items), "[hub.type] selected the same commodity for concurrent demands.")
			request_items[request.item_type] = TRUE
		for(var/pack_id in hub.stock)
			assigned_ids[pack_id] = TRUE
			TEST_ASSERT(hub.groups[pack_id] in request_groups, "[hub.type] cannot replenish the assigned offer [pack_id].")

	// The normal cargo console, rather than the hub's classifier, supplies the visibility oracle.
	var/obj/machinery/computer/cargo/cargo_console = allocate(/obj/machinery/computer/cargo)
	var/datum/asset/json/cargo_catalogue/catalogue = get_asset_datum(/datum/asset/json/cargo_catalogue)
	var/list/console_groups = cargo_console.get_packs_data_by_group(catalogue.ensure_ready())
	var/list/visible_indices = list()
	for(var/group in console_groups)
		var/list/entries = console_groups[group]
		for(var/index = 1; index <= length(entries); index += 2)
			visible_indices["[entries[index]]"] = TRUE
	var/normal_count = 0
	var/gated_count = 0
	var/excluded_count = 0
	var/generated_count = 0
	var/list/missing = list()
	var/list/unexpected = list()
	for(var/pack_id, pack_data in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = pack_data
		// These paths require personal ordering, special transport or an adapter outside this feature.
		if((pack.order_flags & (ORDER_INVISIBLE | ORDER_EMAG_ONLY | ORDER_CONTRABAND | ORDER_GOODY | ORDER_POD_ONLY | ORDER_ADMIN_SPAWNED)) \
			|| istype(pack, /datum/supply_pack/custom) || istype(pack, /datum/supply_pack/imports/fan_upgrade) \
			|| !(pack.crate_type || pack.storage_override))
			excluded_count++
			if(pack_id in assigned_ids)
				unexpected += "[pack_id]"
			continue
		if((pack.order_flags & ORDER_SPECIAL) && !(pack.order_flags & ORDER_SPECIAL_ENABLED))
			gated_count++
		else
			var/catalogue_index = catalogue.pack_indices[pack]
			if(isnull(catalogue_index) || !visible_indices["[catalogue_index]"])
				continue
			normal_count++
		if(istext(pack_id))
			generated_count++
		if(!(pack_id in assigned_ids))
			missing += "[pack_id]"
	log_test("Trade hub catalogue: [normal_count] normal, [gated_count] gated, [excluded_count] excluded, [generated_count] generated IDs, [length(missing)] missing.")
	TEST_ASSERT(normal_count > 0 && generated_count > 0, "The cargo-console oracle contained no normal or generated offers.")
	var/list/sample = missing.Copy(1, min(length(missing) + 1, 11))
	var/missing_sample = sample.Join(", ")
	TEST_ASSERT_EQUAL(length(missing), 0, "Supported runtime cargo IDs were not assigned; first ten: [missing_sample]")
	TEST_ASSERT_EQUAL(length(unexpected), 0, "An unsupported cargo path was imported: [unexpected.Join(", ")]")
	var/list/corporate_ids = list(
		/datum/supply_pack/engineering/bsa,
		/datum/supply_pack/engineering/dna_vault,
		/datum/supply_pack/engineering/dna_probes,
		/datum/supply_pack/engineering/shield_sat,
		/datum/supply_pack/engineering/shield_sat_control,
	)
	TEST_ASSERT_EQUAL(length(corporate.stock), 5, "The corporate catalogue does not contain exactly the five station-project offers.")
	for(var/pack_id in corporate_ids)
		TEST_ASSERT(pack_id in corporate.stock, "The corporate supplier lost station-project offer [pack_id].")
		for(var/obj/machinery/trade_hub_core/hub as anything in hubs)
			if(hub == corporate)
				continue
			TEST_ASSERT(!(pack_id in hub.stock), "[hub.type] imported the corporate-only offer [pack_id].")

/** A generated registry string ID must purchase its actual gas canister rather than its prototype. */
/datum/unit_test/trade_hub/generated_pack_purchase

/datum/unit_test/trade_hub/generated_pack_purchase/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/gas_id
	var/datum/supply_pack/gas_pack
	for(var/pack_id, pack_data in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = pack_data
		if(istext(pack_id) && (/obj/machinery/portable_atmospherics/canister/oxygen in pack.contains))
			gas_id = pack_id
			gas_pack = pack
			break
	TEST_ASSERT_NOTNULL(gas_pack, "The runtime cargo registry contained no generated oxygen-canister pack.")
	core.ensure_catalog()
	var/stock_before = core.stock[gas_id]
	var/price = gas_pack.get_cost()
	cargo_account.account_balance = price * 2
	TEST_ASSERT(core.buy(gas_id), "The generated oxygen pack's registry string ID could not be purchased.")
	TEST_ASSERT_EQUAL(core.stock[gas_id], stock_before - 1, "The generated offer did not consume exactly one local unit.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "The generated offer did not charge exactly its quoted price.")
	var/obj/structure/closet/crate/crate = locate(/obj/structure/closet/crate) in get_turf(output_pad)
	TEST_ASSERT_NOTNULL(crate, "The generated gas order did not issue a crate.")
	TEST_ASSERT_NOTNULL(locate(/obj/machinery/portable_atmospherics/canister/oxygen) in crate, "The generated gas order issued something other than the selected oxygen canister.")

/** A late SPECIAL unlock must affect both display and purchase, and disabling it must close both paths again. */
/datum/unit_test/trade_hub/live_special_gate

/datum/unit_test/trade_hub/live_special_gate/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/engineering/rad_nebula_shielding_kit]
	remember_pack_flags(pack)
	pack.order_flags &= ~ORDER_SPECIAL_ENABLED
	core.ensure_catalog()
	var/obj/machinery/computer/trade_hub/terminal = allocate(/obj/machinery/computer/trade_hub, get_step(get_turf(output_pad), NORTH))
	terminal.hub_id = core.hub_id
	var/price = pack.get_cost()
	cargo_account.account_balance = price * 3
	var/stock_before = core.stock[pack.id]
	TEST_ASSERT_NULL(find_offer(terminal, pack.id), "A locked SPECIAL pack was displayed.")
	TEST_ASSERT(!core.buy("[pack.id]"), "A hostile direct ID purchased a locked SPECIAL pack.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price * 3, "A locked SPECIAL purchase changed the balance.")
	pack.order_flags |= ORDER_SPECIAL_ENABLED
	TEST_ASSERT_NOTNULL(find_offer(terminal, pack.id), "A late SPECIAL unlock was absent from terminal offers.")
	TEST_ASSERT(core.buy("[pack.id]"), "A late SPECIAL unlock remained unavailable for purchase.")
	TEST_ASSERT_EQUAL(core.stock[pack.id], stock_before - 1, "The late unlock purchase did not consume its seeded stock.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price * 2, "The late unlock purchase did not charge once.")
	var/obj/structure/closet/crate/crate = locate(/obj/structure/closet/crate) in get_turf(output_pad)
	TEST_ASSERT_NOTNULL(crate, "The unlocked SPECIAL pack did not produce a crate.")
	crate.forceMove(get_step(get_turf(output_pad), SOUTH))
	pack.order_flags &= ~ORDER_SPECIAL_ENABLED
	TEST_ASSERT_NULL(find_offer(terminal, pack.id), "A disabled SPECIAL pack remained displayed.")
	TEST_ASSERT(!core.buy("[pack.id]"), "A direct ID bypassed a SPECIAL pack's later relock.")
	TEST_ASSERT_EQUAL(core.stock[pack.id], stock_before - 1, "Relocking or reading the catalogue recreated local stock.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price * 2, "A later relocked purchase changed the balance.")
	// The same still-stocked offer must also reject each unsupported flag at the real purchase boundary.
	for(var/forbidden_flag in list(ORDER_INVISIBLE, ORDER_EMAG_ONLY, ORDER_CONTRABAND, ORDER_GOODY, ORDER_POD_ONLY, ORDER_ADMIN_SPAWNED))
		pack.order_flags = ORDER_SPECIAL | ORDER_SPECIAL_ENABLED | forbidden_flag
		TEST_ASSERT_NULL(find_offer(terminal, pack.id), "An unsupported flag [forbidden_flag] remained visible.")
		TEST_ASSERT(!core.buy("[pack.id]"), "A direct ID bypassed unsupported flag [forbidden_flag].")
		TEST_ASSERT_EQUAL(core.stock[pack.id], stock_before - 1, "Unsupported flag [forbidden_flag] consumed stock.")
		TEST_ASSERT_EQUAL(cargo_account.account_balance, price * 2, "Unsupported flag [forbidden_flag] charged cargo.")

/** Exhausting all three batches preserves the final restock, then a real cooldown replaces the commodity without reward. */
/datum/unit_test/trade_hub/renew_exhausted_quota

/datum/unit_test/trade_hub/renew_exhausted_quota/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	cargo_account.account_balance = 1000
	core.ensure_catalog()
	core.stock[/datum/supply_pack/engineering/tools] = 0
	var/request_type = /datum/trade_hub_request/industrial_iron
	var/datum/trade_hub_request/request = core.requests[request_type]
	core.request_types = core.request_types.Copy()
	core.request_types += /datum/trade_hub_request/industrial_power_tools
	request.restock_delay = 1 SECONDS
	request.renewal_delay = 2 SECONDS
	var/list/expected_stock = list(2, 4, 6)
	var/list/expected_remaining = list(40, 20, 0)
	var/list/expected_balance = list(1400, 1800, 2200)
	for(var/batch in 1 to 3)
		allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
		TEST_ASSERT(core.accept("[request_type]"), "Quota batch [batch] could not be delivered.")
		var/deadline = world.time + 5 SECONDS
		UNTIL(!request.ready_at || world.time >= deadline)
		TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], expected_stock[batch], "Quota batch [batch] did not complete its normal stock replenishment.")
		TEST_ASSERT_EQUAL(request.remaining, expected_remaining[batch], "Quota batch [batch] lost its finite demand boundary.")
		TEST_ASSERT_EQUAL(cargo_account.account_balance, expected_balance[batch], "Quota batch [batch] was not paid exactly once.")
	TEST_ASSERT(request.renew_at > world.time, "The exhausted quota did not enter a renewal cooldown after its final restock.")
	var/obj/item/stack/sheet/iron/next_batch = allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
	TEST_ASSERT(!core.accept("[request_type]"), "The exhausted request accepted goods during its renewal cooldown.")
	TEST_ASSERT_EQUAL(next_batch.amount, 20, "The cooldown consumed goods before demand renewed.")
	var/obj/machinery/computer/trade_hub/terminal = allocate(/obj/machinery/computer/trade_hub, get_step(get_turf(output_pad), NORTH))
	terminal.hub_id = core.hub_id
	var/list/data = terminal.ui_data(null)
	var/list/request_data
	for(var/list/entry as anything in data["requests"])
		if(entry["id"] == "[request_type]")
			request_data = entry
	TEST_ASSERT_NOTNULL(request_data, "The exhausted request disappeared from the terminal.")
	TEST_ASSERT(request_data["renew_in"] > 0, "The terminal did not expose the renewal cooldown.")
	var/deadline = world.time + request.renewal_delay + 5 SECONDS
	UNTIL(QDELETED(request) || world.time >= deadline)
	TEST_ASSERT(QDELETED(request), "The live renewal timer retained the closed commodity.")
	var/datum/trade_hub_request/replacement = core.requests[/datum/trade_hub_request/industrial_power_tools]
	TEST_ASSERT_NOTNULL(replacement, "The live renewal timer did not install the other available commodity.")
	TEST_ASSERT_NULL(core.requests[request_type], "The old request remained addressable after rotation.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 6, "Renewing demand granted another stock replenishment.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 2200, "Renewing demand granted another delivery payment.")
	TEST_ASSERT(!core.accept("[request_type]"), "A stale terminal ID accepted the old goods after rotation.")
	TEST_ASSERT_EQUAL(next_batch.amount, 20, "A stale terminal ID consumed goods after rotation.")
	TEST_ASSERT(!core.renew_request(request), "A replaced request accepted duplicate renewal.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 6, "Duplicate renewal replenished stock.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 2200, "Duplicate renewal paid cargo.")
	offer_request_goods(replacement)
	TEST_ASSERT(core.accept("[replacement.type]"), "The replacement demand did not accept its real commodity.")
	TEST_ASSERT_EQUAL(replacement.remaining, 2, "The first batch did not consume the replacement's fresh quota.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 2550, "The replacement batch was not paid exactly once.")

/** Different profile prices must change quantities while real batches pay approximately their target credits. */
/datum/unit_test/trade_hub/batch_credit_targets

/datum/unit_test/trade_hub/batch_credit_targets/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	cargo_account.account_balance = 1000
	var/obj/machinery/trade_hub_core/industrial/trade_hub_credit_test/industrial = allocate(/obj/machinery/trade_hub_core/industrial/trade_hub_credit_test)
	var/obj/machinery/trade_hub_core/medical/trade_hub_credit_test/medical = allocate(/obj/machinery/trade_hub_core/medical/trade_hub_credit_test)
	var/obj/machinery/trade_hub_core/corporate/trade_hub_credit_test/corporate = allocate(/obj/machinery/trade_hub_core/corporate/trade_hub_credit_test)
	var/datum/trade_hub_request/industrial_request = industrial.requests[/datum/trade_hub_request/industrial_iron]
	var/datum/trade_hub_request/medical_request = medical.requests[/datum/trade_hub_request/medical_glass]
	TEST_ASSERT_NOTNULL(industrial_request, "The fixed industrial commodity was not selected.")
	TEST_ASSERT_NOTNULL(medical_request, "The fixed medical commodity was not selected.")
	TEST_ASSERT(medical_request.unit_reward > industrial_request.unit_reward, "Medical raw materials did not receive the higher per-unit price.")
	TEST_ASSERT(medical_request.batch_size < industrial_request.batch_size, "The medical premium did not reduce the required bulk.")
	var/list/targets = list()
	targets[industrial] = 1000
	targets[medical] = 1000
	targets[corporate] = 2000
	for(var/obj/machinery/trade_hub_core/hub as anything in targets)
		hub.hub_id = "credits_[REF(hub)]"
		input_pad.hub_id = hub.hub_id
		var/request_type = hub.requests[1]
		var/datum/trade_hub_request/request = hub.requests[request_type]
		TEST_ASSERT_NOTNULL(request, "The credit-target supplier had no selected demand.")
		var/balance_before = cargo_account.account_balance
		offer_request_goods(request)
		TEST_ASSERT(hub.accept("[request_type]"), "The selected credit-target batch could not be delivered.")
		var/payment = cargo_account.account_balance - balance_before
		TEST_ASSERT(abs(payment - targets[hub]) <= 100, "[hub.type] paid [payment] for one batch instead of approximately [targets[hub]].")
		TEST_ASSERT(request.ready_at > world.time, "Completing the credit-target batch did not schedule replenishment.")
		TEST_ASSERT(!hub.accept("[request_type]"), "A pending credit-target batch could be submitted twice.")
		TEST_ASSERT_EQUAL(cargo_account.account_balance, balance_before + payment, "A repeated credit-target submission paid twice.")

/** Four distinct goods leave a fresh choice after excluding the last two, regardless of the RNG outcome. */
/datum/unit_test/trade_hub/rotation_history

/datum/unit_test/trade_hub/rotation_history/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/obj/machinery/trade_hub_core/industrial/trade_hub_test/history/hub = allocate(/obj/machinery/trade_hub_core/industrial/trade_hub_test/history)
	var/request_type = hub.requests[1]
	var/datum/trade_hub_request/request = hub.requests[request_type]
	TEST_ASSERT_NOTNULL(request, "The history fixture had no initial demand.")
	var/list/recent_types = list(request.type)
	var/balance_before = cargo_account.account_balance
	for(var/rotation in 1 to 6)
		var/previous_item_type = request.item_type
		var/datum/trade_hub_request/previous = request
		request = hub.replace_request("Инструменты", previous)
		TEST_ASSERT_NOTNULL(request, "A populated pool failed to select replacement demand.")
		TEST_ASSERT(QDELETED(previous), "Replacing a demand retained its old owned datum.")
		TEST_ASSERT(request.item_type != previous_item_type, "Rotation immediately repeated the same commodity.")
		TEST_ASSERT(!(request.type in recent_types), "Rotation repeated one of the last two choices despite fresh alternatives.")
		TEST_ASSERT_EQUAL(length(hub.requests), 1, "Rotation accumulated multiple active demands for one group.")
		recent_types += request.type
		if(length(recent_types) > 2)
			recent_types.Cut(1, 2)
	TEST_ASSERT_EQUAL(cargo_account.account_balance, balance_before, "Selecting future demand paid cargo without any delivery.")
	TEST_ASSERT_EQUAL(hub.stock[/datum/supply_pack/engineering/tools], 3, "Selecting future demand replenished stock without any delivery.")

/** One quota's real deliveries and repeated rotation must retain the identities and progress of parallel demands. */
/datum/unit_test/trade_hub/parallel_demand

/datum/unit_test/trade_hub/parallel_demand/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	cargo_account.account_balance = 1000
	var/obj/machinery/trade_hub_core/medical/medical = allocate(/obj/machinery/trade_hub_core/medical)
	TEST_ASSERT_EQUAL(length(medical.requests), 4, "The two-group medical hub did not open two quotas per group.")
	var/list/medical_groups = list()
	var/list/medical_items = list()
	for(var/request_type in medical.requests)
		var/datum/trade_hub_request/request = medical.requests[request_type]
		medical_groups[request.group] = (medical_groups[request.group] || 0) + 1
		TEST_ASSERT(!(request.item_type in medical_items), "The medical hub opened duplicate simultaneous commodities.")
		medical_items[request.item_type] = TRUE
	TEST_ASSERT_EQUAL(medical_groups["Медоборудование"], 2, "The medical equipment group did not have two independent quotas.")
	TEST_ASSERT_EQUAL(medical_groups["Медикаменты"], 2, "The medication group did not have two independent quotas.")
	var/obj/machinery/trade_hub_core/service/hub = allocate(/obj/machinery/trade_hub_core/service)
	hub.hub_id = "parallel_[REF(src)]"
	input_pad.hub_id = hub.hub_id
	hub.ensure_catalog()
	TEST_ASSERT_EQUAL(length(hub.requests), 3, "The one-group service hub did not open three independent quotas.")
	var/partial_type = hub.requests[1]
	var/untouched_type = hub.requests[2]
	var/rotating_type = hub.requests[3]
	var/datum/trade_hub_request/partial = hub.requests[partial_type]
	var/datum/trade_hub_request/untouched = hub.requests[untouched_type]
	var/datum/trade_hub_request/rotating = hub.requests[rotating_type]
	TEST_ASSERT(partial.item_type != untouched.item_type && partial.item_type != rotating.item_type && untouched.item_type != rotating.item_type, "The service hub opened duplicate simultaneous commodities.")
	TEST_ASSERT_NULL(hub.replace_request(partial.group), "Creating another quota bypassed the per-group limit.")
	TEST_ASSERT_EQUAL(length(hub.requests), 3, "A rejected fourth quota changed the active request count.")
	TEST_ASSERT(partial.batch_size > 1, "The service fixture could not offer an incomplete batch.")
	var/partial_remaining = partial.remaining - 1
	var/untouched_remaining = untouched.remaining
	allocate(partial.item_type, get_turf(input_pad))
	TEST_ASSERT(hub.accept("[partial_type]"), "The parallel quota could not receive its first real item.")
	TEST_ASSERT_EQUAL(partial.delivered, 1, "One item advanced the partial quota by more than one.")
	TEST_ASSERT_EQUAL(partial.remaining, partial_remaining, "One item consumed more than its own quota unit.")
	TEST_ASSERT_EQUAL(partial.ready_at, 0, "An incomplete parallel batch scheduled replenishment.")
	var/expected_balance = 1000 + partial.unit_reward
	TEST_ASSERT_EQUAL(cargo_account.account_balance, expected_balance, "The partial parallel delivery was not paid exactly once.")
	var/stock_type = hub.stock[1]
	hub.stock[stock_type] = 0
	var/expected_stock = 0
	var/first_expired_item = rotating.item_type
	for(var/rotation in 1 to 2)
		var/datum/trade_hub_request/expired = rotating
		var/expired_type = expired.type
		var/expired_item = expired.item_type
		// Start each rotation at its final batch; the full three-batch lifecycle has its own scenario.
		expired.remaining = expired.batch_size
		expired.restock_delay = 1 SECONDS
		expired.renewal_delay = 1 SECONDS
		var/payment = expired.batch_size * expired.unit_reward
		expected_stock += expired.restock_amount
		offer_request_goods(expired)
		TEST_ASSERT(hub.accept("[expired_type]"), "A parallel quota could not complete its last real batch.")
		expected_balance += payment
		TEST_ASSERT_EQUAL(cargo_account.account_balance, expected_balance, "Completing one parallel quota paid other deliveries again.")
		var/deadline = world.time + 5 SECONDS
		UNTIL(expired.renew_at || world.time >= deadline)
		TEST_ASSERT(expired.renew_at > world.time, "The last parallel batch did not reach its renewal cooldown.")
		TEST_ASSERT_EQUAL(hub.stock[stock_type], expected_stock, "The final parallel batch did not replenish its group exactly once.")
		deadline = expired.renew_at + 5 SECONDS
		UNTIL(QDELETED(expired) || world.time >= deadline)
		TEST_ASSERT(QDELETED(expired), "The exhausted parallel quota did not rotate through its real timer.")
		TEST_ASSERT_EQUAL(length(hub.requests), 3, "Rotating one slot changed the number of parallel quotas.")
		TEST_ASSERT_NULL(hub.requests[expired_type], "An expired parallel request remained addressable.")
		rotating = null
		for(var/request_type in hub.requests)
			var/datum/trade_hub_request/candidate = hub.requests[request_type]
			if(candidate != partial && candidate != untouched)
				rotating = candidate
		TEST_ASSERT_NOTNULL(rotating, "Rotating a quota failed to install its independent replacement.")
		TEST_ASSERT(rotating.item_type != expired_item && rotating.item_type != partial.item_type && rotating.item_type != untouched.item_type, "Rotation reused the expired or another active commodity.")
		if(rotation == 2)
			TEST_ASSERT_EQUAL(rotating.item_type, first_expired_item, "History fallback did not choose the sole unused commodity from the four-item pool.")
		TEST_ASSERT_EQUAL(hub.requests[partial_type], partial, "Rotating a quota overwrote the partially supplied sibling.")
		TEST_ASSERT_EQUAL(hub.requests[untouched_type], untouched, "Rotating a quota overwrote the untouched sibling.")
		TEST_ASSERT_EQUAL(partial.delivered, 1, "Rotation reset or advanced another quota's partial progress.")
		TEST_ASSERT_EQUAL(partial.remaining, partial_remaining, "Rotation changed another quota's remaining demand.")
		TEST_ASSERT_EQUAL(partial.ready_at, 0, "Rotation scheduled a sibling's incomplete batch.")
		TEST_ASSERT_NULL(partial.restock_timer, "Rotation scheduled a sibling's replenishment callback.")
		TEST_ASSERT_EQUAL(untouched.delivered, 0, "Rotation advanced an untouched quota.")
		TEST_ASSERT_EQUAL(untouched.remaining, untouched_remaining, "Rotation changed an untouched quota.")
		TEST_ASSERT_EQUAL(hub.stock[stock_type], expected_stock, "Rotating a parallel quota replenished stock without a delivery.")
		TEST_ASSERT_EQUAL(cargo_account.account_balance, expected_balance, "Rotating a parallel quota added another payment.")
		var/obj/item/stale_goods = allocate(expired_item, get_turf(input_pad))
		TEST_ASSERT(!hub.accept("[expired_type]"), "A stale terminal ID submitted the expired parallel quota.")
		TEST_ASSERT(!QDELETED(stale_goods), "A stale terminal ID consumed a real item.")
		TEST_ASSERT_EQUAL(cargo_account.account_balance, expected_balance, "A stale parallel ID generated another payment.")
		qdel(stale_goods)

/** A due rotation waits through loss of power, then installs its replacement only once on restoration. */
/datum/unit_test/trade_hub/rotation_power_recovery

/datum/unit_test/trade_hub/rotation_power_recovery/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	cargo_account.account_balance = 1000
	core.stock[/datum/supply_pack/engineering/tools] = 0
	core.request_types = core.request_types.Copy()
	core.request_types += /datum/trade_hub_request/industrial_power_tools
	var/request_type = /datum/trade_hub_request/industrial_iron
	var/datum/trade_hub_request/request = core.requests[request_type]
	request.remaining = 20
	request.restock_delay = 1 SECONDS
	request.renewal_delay = 1 SECONDS
	allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
	TEST_ASSERT(core.accept("[request_type]"), "The final batch could not be submitted before power loss.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(request.renew_at || world.time >= deadline)
	TEST_ASSERT(request.renew_at > world.time, "The final restock did not schedule a future rotation.")
	var/turf/core_tile = get_turf(core)
	core.forceMove(unpowered_tile)
	core.power_change()
	deadline = request.renew_at + 1 SECONDS
	UNTIL(world.time >= deadline)
	TEST_ASSERT_EQUAL(core.requests[request_type], request, "An unpowered core rotated its expired demand.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 2, "The final batch did not replenish exactly once before rotation.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1400, "Waiting without power changed the delivery payment.")
	core.forceMove(core_tile)
	core.power_change()
	var/datum/trade_hub_request/replacement = core.requests[/datum/trade_hub_request/industrial_power_tools]
	TEST_ASSERT_NOTNULL(replacement, "Restoring power did not apply the due commodity rotation.")
	TEST_ASSERT(QDELETED(request), "Power restoration retained the expired request.")
	TEST_ASSERT(!core.renew_request(request), "An old callback could rotate the replacement demand again.")
	deadline = world.time + 1 SECONDS
	UNTIL(world.time >= deadline)
	TEST_ASSERT_EQUAL(core.requests[/datum/trade_hub_request/industrial_power_tools], replacement, "The expired timer replaced demand again after recovery.")
	TEST_ASSERT_EQUAL(core.stock[/datum/supply_pack/engineering/tools], 2, "Power recovery produced an extra stock replenishment.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, 1400, "Power recovery produced an extra payment.")

/** Deleting a core during renewal must remove its second-phase callback as well as its request. */
/datum/unit_test/trade_hub/delete_pending_renewal

/datum/unit_test/trade_hub/delete_pending_renewal/Run()
	var/request_type = /datum/trade_hub_request/industrial_iron
	var/datum/trade_hub_request/request = core.requests[request_type]
	// Start at the last batch; the complete three-batch lifecycle is covered by renew_exhausted_quota.
	request.remaining = 20
	request.restock_delay = 1 SECONDS
	allocate(/obj/item/stack/sheet/iron, get_turf(input_pad), 20, FALSE)
	TEST_ASSERT(core.accept("[request_type]"), "The last batch could not be delivered before deletion.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(request.renewal_timer || world.time >= deadline)
	var/pending_timer = request.renewal_timer
	TEST_ASSERT_NOTNULL(timeleft(pending_timer), "The final batch did not schedule a cancellable renewal timer.")
	qdel(core)
	TEST_ASSERT(QDELETED(request), "Deleting the core retained a request waiting for renewal.")
	TEST_ASSERT_NULL(timeleft(pending_timer), "Deleting the core left its renewal callback queued.")

/** Existing pack generation may put the crate inside a parcel; delivery must retain that outer package. */
/datum/unit_test/trade_hub/wrapped_pack_purchase

/datum/unit_test/trade_hub/wrapped_pack_purchase/Run()
	TEST_ASSERT_NOTNULL(cargo_account, "Cargo account was unavailable.")
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/costumes_toys/christmas]
	remember_pack_flags(pack)
	pack.order_flags |= ORDER_SPECIAL_ENABLED
	var/obj/machinery/trade_hub_core/service/supplier = allocate(/obj/machinery/trade_hub_core/service)
	supplier.hub_id = "wrapped_[REF(src)]"
	output_pad.hub_id = supplier.hub_id
	supplier.ensure_catalog()
	var/price = pack.get_cost()
	cargo_account.account_balance = price * 2
	TEST_ASSERT(supplier.buy("[pack.id]"), "The unlocked wrapped-gift pack could not be purchased.")
	TEST_ASSERT_EQUAL(cargo_account.account_balance, price, "The wrapped-gift purchase did not charge exactly once.")
	var/obj/item/delivery/big/parcel = locate(/obj/item/delivery/big) in get_turf(output_pad)
	TEST_ASSERT_NOTNULL(parcel, "Delivery discarded the gift pack's outer parcel.")
	TEST_ASSERT(parcel.giftwrapped, "Delivery lost the pack's gift wrapping.")
	TEST_ASSERT_NOTNULL(locate(/obj/structure/closet/crate/mail) in parcel, "Delivery separated the gift crate from its parcel.")
	TEST_ASSERT_NULL(locate(/obj/structure/closet/crate) in get_turf(output_pad), "Delivery also issued an unwrapped crate beside the parcel.")
