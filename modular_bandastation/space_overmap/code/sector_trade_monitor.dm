/// Delay between requests for a fresh station-sector trade report.
#define SECTOR_TRADE_REPORT_INTERVAL (5 MINUTES)

/datum/stationtrauma_overmap_sector/space
	/// Last collected trade report, shared by the station's consoles.
	var/list/trade_report
	/// World time at which the last report was collected.
	var/trade_report_at

/** Snapshot requests on trade levels owned by this sector. */
/datum/stationtrauma_overmap_sector/space/proc/refresh_trade_report()
	if(!isnull(trade_report_at) && world.time < trade_report_at + SECTOR_TRADE_REPORT_INTERVAL)
		return FALSE

	var/list/hubs = list()
	for(var/obj/machinery/trade_hub_core/core as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/trade_hub_core))
		if(QDELETED(core))
			continue
		var/turf/location = get_turf(core)
		var/outpost_name = trade_outpost_names?["[location?.z]"]
		if(!outpost_name)
			continue

		var/list/requests = list()
		for(var/request_type in core.requests)
			var/datum/trade_hub_request/request = core.requests[request_type]
			var/status = "open"
			if(request.renew_at || (!isnull(request.remaining) && request.remaining <= 0))
				status = "renewing"
			else if(request.ready_at)
				status = "restocking"
			requests += list(list(
				"id" = "[request_type]",
				"name" = request.name,
				"status" = status,
				"quantity" = isnull(request.remaining) ? null : min(request.remaining, request.batch_size - request.delivered),
				"unit_reward" = request.unit_reward,
				"high_demand" = request.high_demand,
			))
		var/list/reward_market = core.reward_market_data()
		for(var/list/quote as anything in reward_market["quotes"])
			requests += list(list(
				"id" = quote["id"],
				"name" = quote["name"],
				"status" = "open",
				"quantity" = null,
				"rate_percent" = quote["rate"],
				"rate_seconds_left" = reward_market["seconds_left"],
			))
		hubs += list(list(
			"id" = REF(core),
			"name" = outpost_name,
			"problem" = trade_hub_machine_reason(core, "Ядро узла") || core.get_input_reason(),
			"requests" = requests,
		))
	trade_report = hubs
	trade_report_at = world.time
	return TRUE

/** Board used to repair or rebuild the station's trade monitor. */
/obj/item/circuitboard/computer/sector_trade_monitor
	name = "консоль торговых заявок"
	build_path = /obj/machinery/computer/sector_trade_monitor

/** Read-only access to the trade report of the sector containing the mapped station. */
/obj/machinery/computer/sector_trade_monitor
	name = "консоль торговых заявок"
	desc = "Принимает сводки о спросе торговых узлов в секторе станции."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/cargo")
	icon_screen = "supply"
	circuit = /obj/item/circuitboard/computer/sector_trade_monitor
	req_access = list(ACCESS_COMMAND)

/** Match the configured station site to its actual native station berth. */
/obj/machinery/computer/sector_trade_monitor/proc/resolve_station_sector()
	var/station_id = SSmapping.current_map.space_overmap?["station_id"]
	if(!station_id)
		return null
	var/list/sectors = SSstationtrauma_space_voyage.sectors
	for(var/sector_id in sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = sectors[sector_id]
		if(!sector.ready)
			continue
		var/datum/stationtrauma_overmap_site/space/site = sector.sites[station_id]
		if(!QDELETED(site?.berth) && is_station_level(site.berth.z))
			return sector
	return null

/** Apply the installation and ID checks when reading or requesting a report. */
/obj/machinery/computer/sector_trade_monitor/proc/can_operate(mob/user)
	return !QDELETED(user) && anchored && is_operational && !panel_open && is_station_level(z) \
		&& !istype(get_area(src), /area/shuttle) && can_interact(user) && allowed(user)

/obj/machinery/computer/sector_trade_monitor/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!ui && !allowed(user))
		to_chat(user, span_warning("Для работы с консолью нужен доступ командования."))
		return
	open_overmap_console(user, ui, "SectorTradeMonitor")

/obj/machinery/computer/sector_trade_monitor/ui_status(mob/user, datum/ui_state/state)
	if(!can_operate(user))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/sector_trade_monitor/ui_data(mob/user)
	if(!can_operate(user))
		return list()
	var/datum/stationtrauma_overmap_sector/space/sector = resolve_station_sector()
	var/report_at = sector?.trade_report_at
	return list(
		"sector" = sector?.name,
		"hubs" = sector?.trade_report,
		"age_seconds" = isnull(report_at) ? null : floor((world.time - report_at) / (1 SECONDS)),
		"refresh_seconds" = isnull(report_at) ? 0 : max(0, ceil((report_at + SECTOR_TRADE_REPORT_INTERVAL - world.time) / (1 SECONDS))),
	)

/obj/machinery/computer/sector_trade_monitor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE
	if(action != "refresh" || ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/sector = resolve_station_sector()
	return sector?.refresh_trade_report()

#undef SECTOR_TRADE_REPORT_INTERVAL
