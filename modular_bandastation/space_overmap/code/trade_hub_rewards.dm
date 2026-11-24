/// Duration of each price window for reward buybacks.
#define TRADE_HUB_REWARD_INTERVAL (15 MINUTES)
/// Lowest percentage of the ordinary export value offered by a hub.
#define TRADE_HUB_REWARD_MIN_RATE 50
/// Highest percentage of the ordinary export value offered by a hub.
#define TRADE_HUB_REWARD_MAX_RATE 150

/obj/machinery/trade_hub_core
	/// Current buyback window. An unquoted hub rolls on its first use.
	var/reward_market_cycle = -1
	/// Current independent price percentages, keyed by reward kind.
	var/list/reward_market_rates = list()
	/// Reward types traded through the dedicated buyback action.
	var/static/list/reward_market_names = list(
		"bounty_cube" = "Баунти-кубы",
		"decrypted_cache" = "Расшифрованные кэши",
	)
	/// Same base valuation and report key as regular bounty-cube exports.
	var/static/datum/export/bounty_box/reward_cube_export = new

/** Keep a hub's prices fixed for the window and change both when the window expires. */
/obj/machinery/trade_hub_core/proc/refresh_reward_market()
	var/current_cycle = floor(world.time / TRADE_HUB_REWARD_INTERVAL)
	if(reward_market_cycle == current_cycle)
		return
	for(var/id in reward_market_names)
		var/previous_rate = reward_market_rates[id]
		var/rate = rand(TRADE_HUB_REWARD_MIN_RATE, TRADE_HUB_REWARD_MAX_RATE - !!previous_rate)
		if(previous_rate && rate >= previous_rate)
			rate++
		reward_market_rates[id] = rate
	reward_market_cycle = current_cycle

/** Get the rates alone for a sector report, or add a live estimate for goods on an input pad. */
/obj/machinery/trade_hub_core/proc/reward_market_data(turf/input_tile)
	refresh_reward_market()
	var/list/quotes = list()
	for(var/id in reward_market_names)
		var/list/sale = input_tile ? get_reward_buyback(input_tile, id) : null
		quotes += list(list(
			"id" = id,
			"name" = reward_market_names[id],
			"rate" = reward_market_rates[id],
			"count" = length(sale),
			"gross" = reward_buyback_total(sale),
		))
	return list(
		"cycle" = reward_market_cycle,
		"seconds_left" = ceil(((reward_market_cycle + 1) * TRADE_HUB_REWARD_INTERVAL - world.time) / (1 SECONDS)),
		"quotes" = quotes,
	)

/** Price only genuine goods placed directly on the input pad. */
/obj/machinery/trade_hub_core/proc/get_reward_buyback(turf/input_tile, id)
	var/list/sale = list()
	for(var/obj/offered in input_tile)
		if(QDELETED(offered) || offered.anchored || (offered.flags_1 & HOLOGRAM_1))
			continue
		var/base_price = 0
		if(id == "bounty_cube" && istype(offered, /obj/item/bounty_cube))
			var/obj/item/bounty_cube/cube = offered
			if(!(cube.item_flags & ABSTRACT))
				base_price = reward_cube_export.get_base_cost(cube)
		else if(id == "decrypted_cache" && istype(offered, /obj/structure/closet/crate/secure/bitrunning/decrypted))
			var/obj/structure/closet/crate/secure/bitrunning/decrypted/cache = offered
			if(cache.trade_reward_intact && !cache.opened && !length(cache.get_all_contents_type(/mob)))
				var/datum/export_report/estimate = export_item_and_contents(cache, apply_elastic = FALSE, dry_run = TRUE)
				for(var/datum/export/export as anything in estimate.total_value)
					base_price += estimate.total_value[export]
				qdel(estimate)
		if(base_price > 0)
			sale[offered] = ROUND_UP(base_price * reward_market_rates[id] / 100)
	return sale

/** Total a quote before any bounty holder shares are deducted. */
/obj/machinery/trade_hub_core/proc/reward_buyback_total(list/sale)
	var/gross = 0
	for(var/obj/reward as anything in sale)
		gross += sale[reward]
	return gross

/** Revalidate the quote and make one local payout for the accepted rewards. */
/obj/machinery/trade_hub_core/proc/sell_rewards(id, list/quote, list/result, mob/user, obj/machinery/computer/trade_hub/cash_terminal)
	if(!(id in reward_market_names))
		return trade_result(result, FALSE, "Этот товар не участвует в выкупе.")
	var/reason = get_trade_reason() || get_input_reason()
	if(reason)
		return trade_result(result, FALSE, reason)

	var/datum/bank_account/account
	var/turf/counter
	if(cash_terminal)
		if(QDELETED(cash_terminal) || cash_terminal.cash_operator_reason(user))
			return trade_result(result, FALSE, "Для выплаты подойдите к терминалу.")
		counter = get_turf(cash_terminal)
	else
		account = SSeconomy.get_dep_account(ACCOUNT_CAR)
		if(!account)
			return trade_result(result, FALSE, "Счёт карго недоступен.")

	refresh_reward_market()
	if(!isnum(quote["cycle"]) || quote["cycle"] != reward_market_cycle)
		return trade_result(result, FALSE, "Курс сменился. Проверьте новую цену и повторите продажу.")
	var/obj/machinery/trade_hub_pad/pad = get_pad(/obj/machinery/trade_hub_pad/input)
	var/turf/input_tile = get_turf(pad)
	var/list/sale = get_reward_buyback(input_tile, id)
	if(length(sale) != quote["count"] || reward_buyback_total(sale) != quote["gross"])
		return trade_result(result, FALSE, "Состав или оценка груза изменились. Проверьте сумму и повторите продажу.")
	if(!length(sale))
		return trade_result(result, FALSE, "На площадке нет подходящих наград.")

	busy = TRUE
	var/net_payment = 0
	var/accepted = 0
	var/datum/export_report/cube_report = new
	for(var/obj/reward as anything in sale)
		if(QDELETED(reward) || reward.loc != input_tile || (SEND_SIGNAL(reward, COMSIG_ITEM_PRE_EXPORT) & COMPONENT_STOP_EXPORT))
			continue
		var/price = sale[reward]
		// Use the ordinary payout signal so cube contributors keep their shares of the new price.
		if(!(id == "bounty_cube" && (SEND_SIGNAL(reward, COMSIG_ITEM_EXPORTED, reward_cube_export, cube_report, price) & COMPONENT_STOP_EXPORT_REPORT)))
			net_payment += price
		qdel(reward)
		accepted++
	net_payment += cube_report.total_value[reward_cube_export]
	qdel(cube_report)
	if(net_payment > 0)
		if(cash_terminal)
			trade_hub_give_cash(user, counter, net_payment)
		else
			account.adjust_money(net_payment, "Торговый узел [hub_id]: [reward_market_names[id]]")
	busy = FALSE
	if(!accepted)
		return trade_result(result, FALSE, "Узел не смог принять награды.")
	investigate_log("Trade hub [hub_id] bought [accepted] [id] at [reward_market_rates[id]]% for a net [net_payment] credits to [cash_terminal ? key_name(user) : "cargo"].", INVESTIGATE_CARGO)
	return trade_result(result, TRUE, "Принято [accepted] ед. Выплата [cash_terminal ? "оператору" : "в бюджет карго"]: [net_payment] кр.")

#undef TRADE_HUB_REWARD_INTERVAL
#undef TRADE_HUB_REWARD_MIN_RATE
#undef TRADE_HUB_REWARD_MAX_RATE
