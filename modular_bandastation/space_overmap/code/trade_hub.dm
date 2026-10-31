/** Physical owner of a trade hub's independent inventory, demand and replenishment jobs. */
/obj/machinery/trade_hub_core
	name = "ядро торгового узла"
	desc = "Хранит запасы и заявки торгового узла."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "processor"
	density = TRUE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.1
	/// Mapper key shared with this hub's terminal and pads on the same level.
	var/hub_id
	/// Crew-facing profile name.
	var/specialization = "Торговый узел"
	/// Supply pack type to remaining crates; each core owns its copy.
	var/list/stock = list()
	/// Supply pack type to the group replenished by local deliveries.
	var/list/groups = list()
	/// Maximum crates of each listed pack.
	var/capacity = 9
	/// Candidate request types for independently rotating quotas.
	var/list/request_types = list()
	/// Request type to owned request instance.
	var/list/requests = list()
	/// Maximum simultaneous requests in each replenishment group.
	var/requests_per_group = 1
	/// Approximate cargo payment for one complete replenishment batch.
	var/batch_credit_target = 1000
	/// Commodity category to purchase price coefficient; missing categories use one.
	var/list/demand_multipliers = list()
	/// Commodity category to selection frequency coefficient, independent of price.
	var/list/demand_weights = list()
	/// Replenishment group to the last two selected request types, owned by this core.
	var/list/request_history = list()
	/// Source cargo category to local replenishment group.
	var/list/catalogue_groups = list()
	/// Initial crates for imported catalogue entries without an explicit stock override.
	var/default_stock = 3
	/// The runtime cargo registry is imported once, after SSshuttle initialization.
	var/catalogue_initialized = FALSE
	/// Goal construction packs routed exclusively to the corporate supplier.
	var/static/list/corporate_pack_types = list(
		/datum/supply_pack/engineering/bsa,
		/datum/supply_pack/engineering/dna_vault,
		/datum/supply_pack/engineering/dna_probes,
		/datum/supply_pack/engineering/shield_sat,
		/datum/supply_pack/engineering/shield_sat_control,
	)
	/// Weak links never keep removed pads alive.
	var/datum/weakref/input_pad
	/// Cached outbound pad, revalidated at use.
	var/datum/weakref/output_pad
	/// Prevent generation or item callbacks from reentering a transaction.
	var/busy = FALSE
	/// Last result shared by this hub's terminals.
	var/status = "Готов к торговле."

/obj/machinery/trade_hub_core/Initialize(mapload)
	. = ..()
	stock = stock.Copy()
	request_types = request_types.Copy()
	requests = list()
	request_history = list()
	var/list/request_groups = list()
	for(var/datum/trade_hub_request/request_type as anything in request_types)
		request_groups[initial(request_type.group)] = TRUE
	for(var/group in request_groups)
		for(var/index in 1 to requests_per_group)
			if(!replace_request(group))
				break

/obj/machinery/trade_hub_core/Destroy()
	QDEL_LIST_ASSOC_VAL(requests)
	request_history.Cut()
	input_pad = null
	output_pad = null
	return ..()

/** Select a local replenishment group without duplicating the cargo catalogue. */
/obj/machinery/trade_hub_core/proc/get_pack_group(datum/supply_pack/pack)
	if(pack.type in corporate_pack_types)
		return null
	return catalogue_groups[pack.group]

/** Packs whose ordinary crate delivery is supported by a local cargo-budget purchase. */
/obj/machinery/trade_hub_core/proc/supports_pack(datum/supply_pack/pack)
	if(!pack || istype(pack, /datum/supply_pack/custom) || istype(pack, /datum/supply_pack/imports/fan_upgrade))
		return FALSE
	if(pack.order_flags & (ORDER_INVISIBLE | ORDER_EMAG_ONLY | ORDER_CONTRABAND | ORDER_GOODY | ORDER_POD_ONLY | ORDER_ADMIN_SPAWNED))
		return FALSE
	return !!(pack.crate_type || pack.storage_override)

/** Read live unlock flags both when presenting an offer and when committing a purchase. */
/obj/machinery/trade_hub_core/proc/can_trade_pack(datum/supply_pack/pack)
	return supports_pack(pack) && (!(pack.order_flags & ORDER_SPECIAL) || (pack.order_flags & ORDER_SPECIAL_ENABLED))

/** Import runtime-generated IDs only after the owning cargo registry is ready. */
/obj/machinery/trade_hub_core/proc/ensure_catalog()
	if(catalogue_initialized)
		return TRUE
	if(!SSshuttle.initialized)
		return FALSE
	for(var/pack_id, pack_data in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = pack_data
		if(!supports_pack(pack))
			continue
		var/group = get_pack_group(pack)
		if(!group)
			continue
		if(!(pack_id in stock))
			stock[pack_id] = clamp(default_stock, 0, capacity)
		if(!(pack_id in groups))
			groups[pack_id] = group
	catalogue_initialized = TRUE
	return TRUE

/** Select and install one specialized request, preferring fresh and locally distinct commodities. */
/obj/machinery/trade_hub_core/proc/replace_request(group, datum/trade_hub_request/previous)
	if(previous && (QDELETED(previous) || requests[previous.type] != previous || previous.group != group))
		return null
	var/list/active_items = list()
	var/active_group_count = 0
	for(var/active_type in requests)
		var/datum/trade_hub_request/active = requests[active_type]
		if(active == previous)
			continue
		if(active.group == group)
			active_group_count++
		active_items[active.item_type] = TRUE
	if(!previous && active_group_count >= requests_per_group)
		return null
	var/list/recent = request_history[group]
	var/list/all_candidates = list()
	var/list/alternatives = list()
	var/list/fresh = list()
	for(var/datum/trade_hub_request/request_type as anything in request_types)
		if(initial(request_type.group) != group)
			continue
		var/item_type = initial(request_type.item_type)
		if(active_items[item_type] || (requests[request_type] && requests[request_type] != previous))
			continue
		var/category = initial(request_type.category)
		var/category_weight = (category in demand_weights) ? demand_weights[category] : 1
		var/weight = initial(request_type.selection_weight) * category_weight
		if(weight <= 0)
			continue
		// pick_weight requires integers; scaling preserves fractional category frequencies.
		weight = max(1, round(weight * 100))
		all_candidates[request_type] = weight
		if(previous && item_type == previous.item_type)
			continue
		alternatives[request_type] = weight
		if(request_type in recent)
			continue
		fresh[request_type] = weight
	var/list/selection = fresh
	if(!length(selection))
		selection = alternatives
	if(!length(selection))
		selection = all_candidates
	var/datum/trade_hub_request/selected_type = pick_weight(selection)
	if(!selected_type)
		return null
	var/category = initial(selected_type.category)
	var/coefficient = (category in demand_multipliers) ? demand_multipliers[category] : 1
	var/datum/trade_hub_request/next_request = new selected_type(batch_credit_target, coefficient)
	if(previous)
		requests -= previous.type
	requests[next_request.type] = next_request
	if(previous)
		qdel(previous)
	if(!recent)
		recent = list()
		request_history[group] = recent
	recent += selected_type
	if(length(recent) > 2)
		recent.Cut(1, length(recent) - 1)
	return next_request

/** Replace an exhausted request with a different commodity after its configured cooldown. */
/obj/machinery/trade_hub_core/proc/renew_request(datum/trade_hub_request/request)
	if(QDELETED(request) || requests[request.type] != request || !request.renew_at || world.time < request.renew_at || request.remaining > 0 || request.ready_at || !is_operational)
		return FALSE
	var/datum/trade_hub_request/next_request = replace_request(request.group, request)
	if(!next_request)
		return FALSE
	status = "Новый спрос: [next_request.name], квота [next_request.remaining] ед."
	return TRUE

/** Resolve a unique same-level pad and retain only a weak cache. */
/obj/machinery/trade_hub_core/proc/get_pad(pad_type)
	var/obj/machinery/trade_hub_pad/pad = (pad_type == /obj/machinery/trade_hub_pad/input ? input_pad : output_pad)?.resolve()
	if(!pad || pad.hub_id != hub_id || pad.z != z)
		pad = null
		if(!hub_id)
			return null
		for(var/obj/machinery/trade_hub_pad/candidate as anything in SSmachines.get_machines_by_type_and_subtypes(pad_type))
			if(candidate.hub_id != hub_id || candidate.z != z)
				continue
			if(pad)
				return null
			pad = candidate
		if(pad_type == /obj/machinery/trade_hub_pad/input)
			input_pad = WEAKREF(pad)
		else
			output_pad = WEAKREF(pad)
	return pad?.is_operational && !pad.panel_open ? pad : null

/** A pad may issue one crate only when its tile contains no other object or mob. */
/obj/machinery/trade_hub_core/proc/output_clear()
	var/obj/machinery/trade_hub_pad/pad = get_pad(/obj/machinery/trade_hub_pad/output)
	var/turf/tile = get_turf(pad)
	if(!isopenturf(tile) || tile.density)
		return FALSE
	for(var/atom/movable/occupant as anything in tile)
		if(ismob(occupant) || (isobj(occupant) && !iseffect(occupant) && occupant != pad))
			return FALSE
	return TRUE

/** Buy one locally stocked supply pack using the cargo account. */
/obj/machinery/trade_hub_core/proc/buy(pack_id, mob/user)
	if(!istext(pack_id) || busy || !is_operational || panel_open || !ensure_catalog())
		return FALSE
	var/pack_type = text2path(pack_id) || pack_id
	var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_type]
	if(!(pack_type in stock) || stock[pack_type] <= 0 || !can_trade_pack(pack))
		status = "Этот товар отсутствует в запасах узла."
		return FALSE
	if(!output_clear())
		status = "Выдача недоступна. Освободите площадку."
		return FALSE
	var/obj/machinery/trade_hub_pad/pad = get_pad(/obj/machinery/trade_hub_pad/output)
	var/turf/delivery_tile = get_turf(pad)
	var/datum/bank_account/account = SSeconomy.get_dep_account(ACCOUNT_CAR)
	var/price = pack.get_cost()
	if(!account || !isnum(price) || price <= 0 || !account.has_money(price))
		status = "В бюджете карго недостаточно средств."
		return FALSE
	busy = TRUE
	if(!account.adjust_money(-price, "Торговый узел [hub_id]: [pack.name]"))
		busy = FALSE
		return FALSE
	stock[pack_type]--
	// Contain partial generation off-map so a failed issuance cannot leave free goods on the pad.
	var/obj/structure/closet/crate/staging = new(null)
	var/datum/supply_order/order = new(pack, manifest_can_fail = FALSE)
	var/atom/movable/product
	try
		product = order.generate(staging)
	catch(var/exception/failure)
		stack_trace("Trade hub [hub_id] could not generate [pack_type]: [failure]")
	// Some packs wrap the returned crate in a parcel; preserve that outer delivery as well.
	var/atom/movable/shipment = product
	while(shipment && shipment.loc != staging)
		if(!ismovable(shipment.loc))
			shipment = null
			break
		shipment = shipment.loc
	var/success = !QDELETED(shipment) && shipment.loc == staging && !QDELETED(src) && is_operational && !panel_open && can_trade_pack(pack) && get_pad(/obj/machinery/trade_hub_pad/output) == pad && get_turf(pad) == delivery_tile && output_clear()
	if(success)
		shipment.forceMove(delivery_tile)
		success = !QDELETED(shipment) && shipment.loc == delivery_tile
	if(success)
		status = "Выдан [pack.name]. Списано [price] кредитов."
		investigate_log("Trade hub [hub_id] issued [pack_type] for [price] credits from cargo.", INVESTIGATE_CARGO)
		if(pack.order_flags & ORDER_DANGEROUS)
			message_admins("\A [pack.name] purchased at trade hub [hub_id] by [user ? ADMIN_LOOKUPFLW(user) : "server"] using the cargo budget.")
	else
		if(!QDELETED(shipment))
			qdel(shipment)
		account.adjust_money(price, "Торговый узел [hub_id]: возврат за невыданный товар")
		if(!QDELETED(src))
			stock[pack_type] = min(capacity, stock[pack_type] + 1)
			status = "Выдача отменена. Оплата возвращена."
	qdel(staging)
	qdel(order)
	busy = FALSE
	return success

/** Consume only the requested items offered on this hub's input pad. */
/obj/machinery/trade_hub_core/proc/accept(request_id)
	if(!istext(request_id) || busy || !is_operational || panel_open || !ensure_catalog())
		return FALSE
	var/datum/trade_hub_request/request = requests[text2path(request_id)]
	var/obj/machinery/trade_hub_pad/pad = get_pad(/obj/machinery/trade_hub_pad/input)
	var/datum/bank_account/account = SSeconomy.get_dep_account(ACCOUNT_CAR)
	if(!request || request.ready_at || request.renew_at || request.remaining <= 0 || !pad || !account)
		status = "Заявка или площадка приёма недоступна."
		return FALSE
	var/turf/input_tile = get_turf(pad)
	var/list/candidates = list()
	for(var/obj/item/item in input_tile)
		candidates += item
	for(var/obj/structure/closet/crate/crate in input_tile)
		if(crate.opened)
			for(var/obj/item/item in crate)
				candidates += item
	var/accepted = 0
	busy = TRUE
	for(var/obj/item/item as anything in candidates)
		if(request.delivered >= request.batch_size || request.remaining <= 0)
			break
		if(QDELETED(item) || !istype(item, request.item_type) || item.anchored || (item.item_flags & ABSTRACT) || (item.flags_1 & HOLOGRAM_1))
			continue
		var/obj/item/stack/stack = astype(item)
		if(stack?.is_cyborg)
			continue
		var/amount = min(request.remaining, request.batch_size - request.delivered, stack ? stack.amount : 1)
		if(amount <= 0)
			continue
		if(stack)
			if(!stack.use(amount))
				continue
		else
			qdel(item)
		request.delivered += amount
		request.remaining -= amount
		accepted += amount
	if(accepted)
		account.adjust_money(accepted * request.unit_reward, "Торговый узел [hub_id]: [request.name]")
		status = "Принято [accepted] ед. товара. Начислено [accepted * request.unit_reward] кредитов."
		investigate_log("Trade hub [hub_id] accepted [accepted] units of [request.item_type] for cargo, [request.remaining] demand remaining.", INVESTIGATE_CARGO)
		if(request.delivered == request.batch_size)
			request.ready_at = world.time + request.restock_delay
			request.restock_timer = addtimer(CALLBACK(src, PROC_REF(complete_restock), request), request.restock_delay, TIMER_STOPPABLE)
			status += " Пополнение группы «[request.group]» через [request.restock_delay / (1 SECONDS)] с."
	else
		status = "На приёмке нет подходящего товара. Закрытые ящики и излишки остаются на месте."
	busy = FALSE
	return accepted > 0

/** Commit one due replenishment; loss of power retains the pending batch. */
/obj/machinery/trade_hub_core/proc/complete_restock(datum/trade_hub_request/request)
	if(QDELETED(request) || requests[request.type] != request || !request.ready_at || world.time < request.ready_at || !is_operational)
		return FALSE
	if(request.restock_timer)
		deltimer(request.restock_timer)
		request.restock_timer = null
	request.ready_at = 0
	request.delivered = 0
	for(var/pack_type in stock)
		if(groups[pack_type] == request.group)
			stock[pack_type] = min(capacity, stock[pack_type] + request.restock_amount)
	status = "Пополнены запасы группы «[request.group]»."
	if(request.remaining <= 0)
		request.renew_at = world.time + request.renewal_delay
		request.renewal_timer = addtimer(CALLBACK(src, PROC_REF(renew_request), request), request.renewal_delay, TIMER_STOPPABLE)
		status += " Другой товар группы «[request.group]» через [request.renewal_delay / (1 SECONDS)] с."
	return TRUE

/obj/machinery/trade_hub_core/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		return
	for(var/request_type in requests.Copy())
		var/datum/trade_hub_request/request = requests[request_type]
		if(request.ready_at && world.time >= request.ready_at)
			complete_restock(request)
		if(request.renew_at && world.time >= request.renew_at)
			renew_request(request)

/** Cargo transfer tile linked to a hub core by its mapper key. */
/obj/machinery/trade_hub_pad
	name = "площадка торгового узла"
	icon = 'icons/obj/machines/floor.dmi'
	icon_state = "floor_beacon"
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.01
	/// Same-level core key.
	var/hub_id

/** Input pad exposes loose cargo and open crate contents to local requests. */
/obj/machinery/trade_hub_pad/input
	name = "точка приёма груза"
	desc = "Принимает подходящие предметы с площадки и из открытых ящиков на ней."
	color = "#e6aa47"

/** Output pad reserves one clear tile for a purchased crate. */
/obj/machinery/trade_hub_pad/output
	name = "точка выдачи груза"
	desc = "Оставьте площадку свободной для купленного ящика."
	color = "#66b3e6"

/** Powered, breathable station area for the standalone trade-hub test hall. */
/area/station/trade_hub_test
	name = "Зал проверки торговых узлов"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	static_lighting = FALSE
	base_lighting_alpha = 255

/** Local cargo terminal; all transaction permissions and amounts are checked on the server. */
/obj/machinery/computer/trade_hub
	name = "терминал грузов торгового узла"
	desc = "Покупка местных запасов и сдача товаров по заявкам узла. Расчёты через бюджет карго."
	icon_screen = "supply"
	icon_keyboard = "tech_key"
	req_access = list(ACCESS_CARGO)
	/// Same-level core key.
	var/hub_id
	/// Rebuilt terminals bind lazily; deleted cores are never retained.
	var/datum/weakref/core_ref

/obj/machinery/computer/trade_hub/Destroy()
	core_ref = null
	return ..()

/** Bind to one mapped core; a missing or ambiguous mapping cannot trade. */
/obj/machinery/computer/trade_hub/proc/get_core()
	var/obj/machinery/trade_hub_core/core = core_ref?.resolve()
	if(core && core.hub_id == hub_id && core.z == z)
		return core
	if(!hub_id)
		return null
	core = null
	for(var/obj/machinery/trade_hub_core/candidate as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/trade_hub_core))
		if(candidate.hub_id != hub_id || candidate.z != z)
			continue
		if(core)
			return null
		core = candidate
	core_ref = WEAKREF(core)
	return core

/obj/machinery/computer/trade_hub/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TradeHub", name)
		ui.open()

/obj/machinery/computer/trade_hub/ui_data(mob/user)
	var/obj/machinery/trade_hub_core/core = get_core()
	var/catalogue_ready = core?.ensure_catalog()
	var/datum/bank_account/account = SSeconomy.get_dep_account(ACCOUNT_CAR)
	var/list/data = list(
		"name" = core?.name || name,
		"specialization" = core?.specialization,
		"connected" = !!core,
		"operational" = catalogue_ready && core.is_operational && !core.panel_open && is_operational && !panel_open && allowed(user),
		"balance" = account?.account_balance || 0,
		"status" = core?.status || "Ядро не найдено. Проверьте идентификаторы устройств.",
		"input_ready" = !!core?.get_pad(/obj/machinery/trade_hub_pad/input),
		"output_ready" = core?.output_clear(),
		"offers" = list(),
		"requests" = list(),
	)
	if(!catalogue_ready)
		return data
	for(var/pack_type in core.stock)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_type]
		if(!core.can_trade_pack(pack))
			continue
		data["offers"] += list(list(
			"id" = "[pack_type]", "name" = pack.name, "description" = pack.desc,
			"group" = core.groups[pack_type], "price" = pack.get_cost(),
			"stock" = core.stock[pack_type], "capacity" = core.capacity,
		))
	for(var/request_type in core.requests)
		var/datum/trade_hub_request/request = core.requests[request_type]
		data["requests"] += list(list(
			"id" = "[request_type]", "name" = request.name, "group" = request.group,
			"icon" = request.icon_base64,
			"category" = request.category, "base_unit_reward" = request.base_unit_reward,
			"price_multiplier" = request.price_multiplier,
			"delivered" = request.delivered, "required" = request.batch_size,
			"remaining" = request.remaining, "unit_reward" = request.unit_reward,
			"restock_amount" = request.restock_amount,
			"ready_in" = request.ready_at ? max(1, ceil((request.ready_at - world.time) / (1 SECONDS))) : 0,
			"renew_in" = request.renew_at ? max(1, ceil((request.renew_at - world.time) / (1 SECONDS))) : 0,
		))
	return data

/obj/machinery/computer/trade_hub/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE
	if(!is_operational || panel_open || !allowed(usr) || !can_interact(usr))
		return FALSE
	var/obj/machinery/trade_hub_core/core = get_core()
	if(!core || !istext(params["id"]))
		return FALSE
	switch(action)
		if("buy")
			return core.buy(params["id"], usr)
		if("accept")
			return core.accept(params["id"])
	return FALSE
