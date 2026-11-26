/** Buildable station dispatch console board. */
/obj/item/circuitboard/computer/stationtrauma_dispatch
	name = "терминал вызова кораблей"
	build_path = /obj/machinery/computer/stationtrauma_dispatch

/datum/design/board/shuttle/stationtrauma_dispatch
	name = "Плата терминала вызова кораблей"
	desc = "Плата для заказа кораблей к станционным причалам."
	build_path = /obj/item/circuitboard/computer/stationtrauma_dispatch

/** Station terminal for ordering a hull to a compatible berth. */
/obj/machinery/computer/stationtrauma_dispatch
	name = "терминал вызова кораблей"
	desc = "Принимает заказы на корабли и показывает состояние станционных причалов."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/stationtrauma_dispatch")
	icon_screen = "shuttle"
	circuit = /obj/item/circuitboard/computer/stationtrauma_dispatch
	req_one_access = list(ACCESS_COMMAND, ACCESS_EXPLORER)
	/// Optional mapped berth shown first in the list.
	var/site_id

/obj/machinery/computer/stationtrauma_dispatch/proc/can_operate(mob/user, allow_observer = FALSE)
	return !QDELETED(src) && !QDELETED(user) && anchored && is_operational && !panel_open && is_station_level(z) \
		&& !istype(get_area(src), /area/shuttle) && ((allow_observer && isobserver(user)) || (can_interact(user) && allowed(user)))

/obj/machinery/computer/stationtrauma_dispatch/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "StationShuttleDispatch")

/obj/machinery/computer/stationtrauma_dispatch/ui_status(mob/user, datum/ui_state/state)
	if(!can_operate(user, allow_observer = TRUE))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_dispatch/ui_data(mob/user)
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(!can_operate(user, allow_observer = TRUE) || !sector?.ready)
		return list("available" = FALSE)
	var/datum/bank_account/department/account = user.uses_patrol_budget() ? null : SSeconomy.get_dep_account(ACCOUNT_CAR)
	var/list/catalog = sector.shuttle_offers()
	var/list/offers = list()
	for(var/offer_id in catalog)
		var/list/offer = catalog[offer_id]
		offers += list(list("id" = offer_id, "name" = offer["name"], "ship_class" = offer["class"] == ST_SHIP_SMALL ? "S" : "M", "price" = sector.shuttle_price(offer_id, offer)))
	var/list/docks = list()
	for(var/dock_id in sector.sites)
		var/datum/stationtrauma_overmap_site/space/site = sector.sites[dock_id]
		if(!sector.is_shuttle_order_dock(site))
			continue
		var/list/compatible_offers = list()
		for(var/offer_id in catalog)
			if(site.fits_shuttle_offer(catalog[offer_id]))
				compatible_offers += offer_id
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		var/is_standard = istype(slot)
		var/obj/docking_port/mobile/moored = is_standard ? slot.active_berth?.get_docked() : site.berth.get_docked()
		var/datum/stationtrauma_shuttle_order/order = site.shuttle_order
		var/list/dock = list(
			"id" = dock_id,
			"name" = site.name,
			"dock_class" = is_standard ? (slot.hangar ? "M" : slot.dock_class) : null,
			"status" = site.shuttle_order_dock_status(),
			"ship" = moored?.name || order?.offer["name"] || site.docking_owner?.vessel?.name,
			"seconds_left" = order ? ceil(max(0, order.delivery_at - world.time) / (1 SECONDS)) : null,
			"compatible_offers" = compatible_offers,
		)
		if(dock_id == site_id)
			docks.Insert(1, list(dock))
		else
			docks += list(dock)
	return list("available" = TRUE, "balance" = account?.account_balance, "delivery_seconds" = ST_SHUTTLE_DELIVERY_TIME / (1 SECONDS), "offers" = offers, "docks" = docks)

/obj/machinery/computer/stationtrauma_dispatch/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "order" || !can_operate(ui.user))
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(!sector?.ready)
		return FALSE
	var/error = sector.order_shuttle(ui.user, params["offer_id"], params["dock_id"], params["expected_price"])
	var/message = error || "Заказ принят. Причал зарезервирован до прибытия корабля."
	to_chat(ui.user, error ? span_warning(message) : span_notice(message))
	var/request_id = params["request_id"]
	if(IS_FINITE(request_id))
		ui.send_update(list("order_result" = list("id" = request_id, "message" = message, "failed" = !!error)))
	return TRUE


/** Buildable inter-sector jump terminal board. */
/obj/item/circuitboard/computer/stationtrauma_bluespace
	name = "терминал блюспейс-переходов"
	build_path = /obj/machinery/computer/stationtrauma_bluespace

/** Hull-local terminal selecting charted bluespace jump routes. */
/obj/machinery/computer/stationtrauma_bluespace
	name = "терминал блюспейс-переходов"
	desc = "Расчёт межзвёздного маршрута и управление блюспейс-приводом."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/stationtrauma_dispatch")
	icon_screen = "shuttle"
	circuit = /obj/item/circuitboard/computer/stationtrauma_bluespace
	use_power = NO_POWER_USE

/** Resolve the overmap of the physical hull containing this terminal. */
/obj/machinery/computer/stationtrauma_bluespace/proc/navigation()
	RETURN_TYPE(/datum/stationtrauma_overmap/space)
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	return istype(ship) && ship.is_in_shuttle_bounds(src) ? ship.overmap : null

/obj/machinery/computer/stationtrauma_bluespace/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "BluespaceTerminal")

/obj/machinery/computer/stationtrauma_bluespace/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(navigation()) || (!isobserver(user) && !can_interact(user)))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/// The galaxy map's fixed geography, read once from its CSV files: see stationtrauma_load_galaxy_map()
GLOBAL_LIST_INIT(stationtrauma_galaxy_map, stationtrauma_load_galaxy_map())

/**
 * Reads the galaxy map from modular_bandastation/space_overmap/data: the charted stars as list(name, x, y), the outline of
 * the populated systems as list(x, y) and the rings about Sol as list(radius, name), in map units with Sol at 512, 512.
 */
/proc/stationtrauma_load_galaxy_map()
	. = list("stars" = list(), "populated" = list(), "rings" = list())
	for(var/list/row as anything in stationtrauma_read_csv("modular_bandastation/space_overmap/data/galaxy_stars.csv", 3))
		.["stars"] += list(list(row[1], text2num(row[2]), text2num(row[3])))
	for(var/list/row as anything in stationtrauma_read_csv("modular_bandastation/space_overmap/data/galaxy_populated.csv", 2))
		.["populated"] += list(list(text2num(row[1]), text2num(row[2])))
	for(var/list/row as anything in stationtrauma_read_csv("modular_bandastation/space_overmap/data/galaxy_rings.csv", 2))
		.["rings"] += list(list(text2num(row[1]), row[2]))

/// The rows of a CSV file below its header, each a list of its [fields] fields; a row with too few fields is reported and left out
/proc/stationtrauma_read_csv(path, fields)
	. = list()
	if(!fexists(path))
		stack_trace("Missing data file [path]")
		return
	var/list/lines = splittext(file2text(path), "\n")
	for(var/index in 2 to length(lines))
		var/line = trim(lines[index])
		if(!line)
			continue
		var/list/row = splittext(line, ",")
		if(length(row) < fields)
			stack_trace("[path], line [index]: expected [fields] fields, got [length(row)]")
			continue
		. += list(row)

/obj/machinery/computer/stationtrauma_bluespace/ui_static_data(mob/user)
	return list("galaxy" = GLOB.stationtrauma_galaxy_map)

/obj/machinery/computer/stationtrauma_bluespace/ui_data(mob/user)
	var/datum/stationtrauma_overmap/space/map = navigation()
	if(!map)
		return list()
	var/datum/stationtrauma_overmap_sector/space/here = map.sector
	var/datum/stationtrauma_overmap_sector/space/target = map.jump_target ? SSstationtrauma_space_voyage.sectors[map.jump_target] : null
	// every charted system on the galaxy map; those a jump from here can be flown to
	var/list/systems = list()
	for(var/id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/system = SSstationtrauma_space_voyage.sectors[id]
		if(!system.ready)
			continue
		systems += list(list(
			"id" = id,
			"name" = system.name,
			"x" = system.galaxy_x,
			"y" = system.galaxy_y,
			"size" = istype(system, /datum/stationtrauma_overmap_sector/space/home) ? null : system.size_name,
			"planets" = istype(system, /datum/stationtrauma_overmap_sector/space/home) ? null : system.planet_count,
			"route" = (id in here?.jump_routes),
			"available" = !map.jump_target && map.jump_ready(id),
		))
	return list(
		"vessel_name" = map.vessel.name,
		"sector" = here?.id,
		"sector_name" = here?.name,
		"systems" = systems,
		"target" = target?.id,
		"target_name" = target?.name,
		"progress" = map.jump_progress(),
		"drive" = !!map.jump_drive(),
		"at_jump_point" = map.at_jump_point(),
	)

/** The terminal's keys press as the navigation console's do. */
/obj/machinery/computer/stationtrauma_bluespace/play_ui_sound(action, list/params)
	playsound(src, 'modular_bandastation/space_overmap/sound/navigation_button.wav', ST_CONSOLE_BUTTON_VOLUME, FALSE, FALSE)

/obj/machinery/computer/stationtrauma_bluespace/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return
	var/datum/stationtrauma_overmap/space/map = navigation()
	if(QDELETED(map))
		return
	switch(action)
		if("cancel")
			if(!map.jump_target)
				return
			map.request_brake()
			return TRUE
		if("jump")
			var/id = params["id"]
			if(!istext(id) || map.jump_target)
				return
			if(!map.request_jump(id))
				to_chat(ui.user, span_warning(map.jump_drive() ? "Переход недоступен. Освободите причал и дождитесь завершения текущего манёвра." : "Переход недоступен: блюспейс-привод не заряжен или обесточен."))
				return
			return TRUE
