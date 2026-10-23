/proc/stationtrauma_parse_flow(value)
	if(value == "max")
		return STATIONTRAUMA_WATER_MAX_FLOW
	var/rate = isnum(value) ? value : text2num("[value]")
	if(!isnum(rate) || !IS_FINITE(rate))
		return null
	return clamp(rate, 0, STATIONTRAUMA_WATER_MAX_FLOW)

/obj/machinery/stationtrauma_pump_controller
	name = "контроллер трюмных помп"
	desc = "Панель управления помпами обслуживаемой зоны. Каждая помпа имеет отдельные тумблеры питания, расхода и давления. Доступы не требуются."
	icon = 'modular_bandastation/underwater_machinery/icons/wall_controls.dmi'
	icon_state = "controller"
	density = FALSE
	use_power = NO_POWER_USE
	processing_flags = NONE
	light_color = LIGHT_COLOR_VIVID_GREEN
	light_power = 0.5
	light_range = 1.5
	var/control_group = "water"
	var/on = FALSE
	/// 0: empty case, 1: wired, 2: chip installed, 3: secured.
	var/build_stage = 3
	var/obj/item/electronics/stationtrauma_pump_controller/chip
	/// Open displays receive alarm changes without a polling loop.
	var/list/pump_windows = list()
	var/area/alarm_area
	/// Equipment events maintain the physical running lamp as well as open displays.
	var/list/watched_pumps = list()
	var/pump_refresh_timer

/obj/machinery/stationtrauma_pump_controller/Initialize(mapload)
	. = ..()
	if(build_stage >= 2)
		chip = new(src)
	if(mapload)
		setDir(dir)
		find_and_mount_on_atom()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(bind_alarm_area))
	RegisterSignal(SSdcs, COMSIG_GLOB_NEW_MACHINE, PROC_REF(pump_changed))
	bind_alarm_area()

/// Each opted-in compartment owns one sensor, regardless of the number of displays.
/obj/machinery/stationtrauma_pump_controller/proc/bind_alarm_area()
	SIGNAL_HANDLER
	var/area/zone = get_area(src)
	if(zone == alarm_area)
		return
	if(alarm_area)
		UnregisterSignal(alarm_area, list(COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED, COMSIG_AREA_ENTERED, COMSIG_AREA_EXITED))
	alarm_area = zone
	if(!zone.stationtrauma_flood_exempt && !istype(zone, /area/space))
		zone.LoadComponent(/datum/component/stationtrauma_flood_alarm)
		RegisterSignal(zone, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED, PROC_REF(alarm_changed))
	RegisterSignals(zone, list(COMSIG_AREA_ENTERED, COMSIG_AREA_EXITED), PROC_REF(pump_changed))
	alarm_changed()

/// Coalesce equipment events after initialization; the wall indicator also works without open windows.
/obj/machinery/stationtrauma_pump_controller/proc/pump_changed(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(pump_refresh_timer)
		return
	var/obj/machinery/device = istype(source, /obj/machinery) ? source : arrived
	if(!istype(device, /obj/machinery/bilge_pump) && !istype(device, /obj/machinery/stationtrauma_water_device/inline_pump/pressure))
		return
	if(!(device in watched_pumps) && (device.z != z || get_area(device) != alarm_area))
		return
	pump_refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh_pumps)), 0, TIMER_STOPPABLE)

/obj/machinery/stationtrauma_pump_controller/proc/refresh_pumps()
	pump_refresh_timer = null
	alarm_changed()

/// Append newly discovered equipment below the existing plates, preserving their positions.
/obj/machinery/stationtrauma_pump_controller/proc/watch_pumps()
	var/list/devices = controlled_devices()
	for(var/obj/machinery/device as anything in watched_pumps.Copy())
		if(device in devices)
			continue
		UnregisterSignal(device, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_UPDATED_ICON))
		watched_pumps -= device
	for(var/obj/machinery/device as anything in devices)
		if(device in watched_pumps)
			continue
		watched_pumps += device
		RegisterSignals(device, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_UPDATED_ICON), PROC_REF(pump_changed))

/obj/machinery/stationtrauma_pump_controller/proc/alarm_changed()
	SIGNAL_HANDLER
	if(pump_refresh_timer)
		deltimer(pump_refresh_timer)
		pump_refresh_timer = null
	watch_pumps()
	on = FALSE
	for(var/obj/machinery/device as anything in watched_pumps)
		if(istype(device, /obj/machinery/bilge_pump))
			var/obj/machinery/bilge_pump/pump = device
			on = on || pump.on
		else
			var/obj/machinery/stationtrauma_water_device/inline_pump/pressure/pump = device
			on = on || pump.on
	update_appearance()
	for(var/mob/viewer as anything in pump_windows.Copy())
		if(can_interact(viewer))
			ui_interact(viewer)
		else
			close_pumps(viewer)

/obj/machinery/stationtrauma_pump_controller/proc/close_pumps(mob/viewer)
	SIGNAL_HANDLER
	var/datum/browser/popup = pump_windows[viewer]
	pump_windows -= viewer
	UnregisterSignal(viewer, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT))
	if(popup)
		popup.close()
		qdel(popup)

/obj/machinery/stationtrauma_pump_controller/setDir(newdir)
	. = ..()
	pixel_x = newdir == EAST ? 24 : newdir == WEST ? -24 : 0
	pixel_y = newdir == NORTH ? 24 : newdir == SOUTH ? -24 : 0

/obj/machinery/stationtrauma_pump_controller/Destroy()
	if(pump_refresh_timer)
		deltimer(pump_refresh_timer)
		pump_refresh_timer = null
	for(var/obj/machinery/device as anything in watched_pumps)
		UnregisterSignal(device, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_UPDATED_ICON))
	watched_pumps.Cut()
	for(var/mob/viewer as anything in pump_windows.Copy())
		close_pumps(viewer)
	alarm_area = null
	QDEL_NULL(chip)
	return ..()

/obj/machinery/stationtrauma_pump_controller/unassembled
	build_stage = 0
	icon_state = "controller-open"

/obj/machinery/stationtrauma_pump_controller/update_icon_state()
	icon_state = build_stage != 3 ? "controller-open" : !is_operational ? "controller-nopower" : on ? "controller_on" : "controller"
	return ..()

/obj/machinery/stationtrauma_pump_controller/update_overlays()
	. = ..()
	var/ready = build_stage == 3 && is_operational
	set_light(l_on = ready)
	if(ready)
		. += emissive_appearance(icon, "[icon_state]-light-mask", src, alpha = src.alpha)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/stationtrauma_pump_controller, 24)
MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/stationtrauma_pump_controller/unassembled, 24)

/obj/machinery/stationtrauma_pump_controller/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	if(build_stage != 3)
		balloon_alert(user, "сначала собрать")
		return
	ui_interact(user)

/obj/machinery/stationtrauma_pump_controller/proc/controlled_devices()
	var/list/devices = list()
	var/area/zone = get_area(src)
	for(var/obj/machinery/bilge_pump/pump as anything in SSfloodwater.pumps)
		if(pump.z == z && get_area(pump) == zone && pump.control_group == control_group && pump.reagents && !istype(pump, /obj/machinery/bilge_pump/portable))
			devices += pump
	for(var/obj/machinery/stationtrauma_water_device/inline_pump/pressure/device as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/stationtrauma_water_device/inline_pump/pressure))
		if(device.z == z && get_area(device) == zone && device.control_group == control_group && device.reagents)
			devices += device
	return devices

/obj/machinery/stationtrauma_pump_controller/proc/set_device(obj/machinery/device, enabled, rate)
	if(istype(device, /obj/machinery/bilge_pump))
		var/obj/machinery/bilge_pump/pump = device
		pump.on = enabled
		pump.drain_rate = rate / FLOOD_WATER_LITRES_PER_CM
	else
		var/obj/machinery/stationtrauma_water_device/inline_pump/pressure/pump = device
		pump.on = enabled
		pump.flow_rate = rate
	if(enabled)
		device.begin_processing()
	else
		device.end_processing()
	device.update_appearance(UPDATE_ICON)

/obj/machinery/stationtrauma_pump_controller/proc/apply_settings()
	if(build_stage == 3)
		update_appearance()
		return
	on = FALSE
	for(var/obj/machinery/device as anything in controlled_devices())
		var/rate
		if(istype(device, /obj/machinery/bilge_pump))
			var/obj/machinery/bilge_pump/pump = device
			rate = pump.drain_rate * FLOOD_WATER_LITRES_PER_CM
		else
			var/obj/machinery/stationtrauma_water_device/inline_pump/pressure/pump = device
			rate = pump.flow_rate
		set_device(device, FALSE, rate)
	update_appearance()

/obj/machinery/stationtrauma_pump_controller/ui_data(mob/user)
	var/list/data = list("on" = on, "devices" = list())
	data["flood_alarm"] = !!alarm_area?.flood_alarm?.active
	data["alarm_muted"] = !!alarm_area?.flood_alarm?.muted
	data["alarm_reset"] = !!alarm_area?.flood_alarm?.reset_timer
	var/list/devices = controlled_devices()
	if(pump_windows.len)
		devices = watched_pumps & devices
	for(var/obj/machinery/device as anything in devices)
		var/enabled
		var/rate
		var/pressure
		if(istype(device, /obj/machinery/bilge_pump))
			var/obj/machinery/bilge_pump/pump = device
			enabled = pump.on
			rate = pump.drain_rate * FLOOD_WATER_LITRES_PER_CM
			pressure = pump.water_pressure
		else
			var/obj/machinery/stationtrauma_water_device/inline_pump/pressure/pump = device
			enabled = pump.on
			rate = pump.flow_rate
			pressure = pump.target_pressure
		var/datum/component/plumbing/stationtrauma_water/connection = device.GetComponent(/datum/component/plumbing/stationtrauma_water)
		var/status = !device.anchored ? "не закреплена" : !device.is_operational ? "нет питания / неисправна" : !enabled ? "выключена" : !length(connection?.ducts) ? "нет трубы" : device.reagents.holder_full() ? "буфер полон" : "включена"
		data["devices"] += list(list("ref" = REF(device), "name" = "[device.name] ([device.x], [device.y])", "on" = enabled, "rate" = rate, "pressure" = pressure, "rate_high" = rate >= STATIONTRAUMA_WATER_MAX_FLOW, "pressure_high" = pressure >= STATIONTRAUMA_PUMP_MAX_PRESSURE, "status" = status, "volume" = round(device.reagents.total_volume, 0.1), "capacity" = device.reagents.maximum_volume))
	return data

/obj/machinery/stationtrauma_pump_controller/ui_interact(mob/user, datum/tgui/ui)
	var/datum/browser/popup = pump_windows[user]
	if(!popup)
		popup = new(user, "stationtrauma_pumps_[REF(src)]", name, 760, 680, src)
		popup.add_stylesheet("stationtrauma_console", 'modular_bandastation/underwater_machinery/html/console.css')
		popup.add_stylesheet("stationtrauma_pumps", 'modular_bandastation/underwater_machinery/html/pumps.css')
		popup.add_script("stationtrauma_pumps", 'modular_bandastation/underwater_machinery/html/pumps.js')
		pump_windows[user] = popup
		RegisterSignals(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(close_pumps))
	watch_pumps()
	var/list/data = ui_data(user)
	var/area/zone = get_area(src)
	var/list/html = list("<div class='crt-screen'><div class='crt-label'>BILGE CONTROL / КОНТРОЛЬ ОТКАЧКИ</div><h2>[html_encode(zone.name)]</h2>")
	html += "<p class='[data["flood_alarm"] ? "crt-warning" : "crt-label"]'>[data["flood_alarm"] ? "ЗАТОПЛЕНИЕ / [data["alarm_muted"] ? "СИРЕНА ОТКЛЮЧЕНА" : "ТРЕВОГА"]" : data["alarm_reset"] ? "ТРЕВОГА СБРОШЕНА / ПОВТОРНОЕ ВКЛЮЧЕНИЕ ЧЕРЕЗ 10 С" : "OK / ТРЕВОГИ НЕТ"]</p>"
	var/enabled_count = 0
	var/total_volume = 0
	var/total_capacity = 0
	var/index = 0
	for(var/list/device as anything in data["devices"])
		enabled_count += !!device["on"]
		total_volume += device["volume"]
		total_capacity += device["capacity"]
		html += "<div class='pump-readout'>P[++index] / [device["status"]] / [device["rate"]] л/с / [device["pressure"]] бар</div>"
	html += "<div class='crt-label'>ВКЛЮЧЕНО: [enabled_count] / [length(data["devices"])] &nbsp; БУФЕР: [round(total_volume, 0.1)] / [total_capacity] л</div>"
	if(!length(data["devices"]))
		html += "<p>В этой зоне нет водяных устройств.</p>"
	html += "</div><div class='pump-rack'>"
	index = 0
	for(var/list/device as anything in data["devices"])
		var/device_ref = device["ref"]
		var/prefix = "byond://?src=[REF(src)];device=[device_ref]"
		html += "<div class='pump-panel'><span class='pump-bolt bolt-top' aria-hidden='true'></span><span class='pump-bolt bolt-bottom' aria-hidden='true'></span><div class='pump-name'><span class='pump-number'>P[++index]</span>[html_encode(device["name"])]</div>"
		html += "<div class='pump-control'><div class='pump-control-label'>ПИТАНИЕ <span class='pump-pilot [device["on"] ? "pilot-on" : ""]' aria-hidden='true'></span></div>"
		html += pump_switch("[prefix];toggle=1", device["on"], "ВЫКЛ", "ВКЛ", "Питание [device["name"]]")
		html += "</div><div class='pump-control'><div class='pump-control-label'>РАСХОД</div>"
		html += pump_switch("[prefix];setting=rate;preset=[device["rate_high"] ? "min" : "max"]", device["rate_high"], "MIN", "MAX", "Максимальный расход: [STATIONTRAUMA_PUMP_MIN_FLOW] / [STATIONTRAUMA_WATER_MAX_FLOW] л/с")
		html += "</div><div class='pump-control'><div class='pump-control-label'>ДАВЛЕНИЕ</div>"
		html += pump_switch("[prefix];setting=pressure;preset=[device["pressure_high"] ? "min" : "max"]", device["pressure_high"], "MIN", "MAX", "Максимальное давление: [STATIONTRAUMA_PUMP_MIN_PRESSURE] / [STATIONTRAUMA_PUMP_MAX_PRESSURE] бар")
		html += "</div></div>"
	html += "</div><p class='pump-refresh'><a class='pump-refresh-button' href='byond://?src=[REF(src)];refresh=1'>ОБНОВИТЬ ПОКАЗАНИЯ</a></p>"
	popup.set_head_content("")
	popup.set_content(html.Join())
	popup.open()

/// A native hyperlink is a two-position mechanical switch, with keyboard focus and spoken state.
/obj/machinery/stationtrauma_pump_controller/proc/pump_switch(href, high, low_label, high_label, label)
	var/safe_label = replacetext(html_encode(label), "'", "&#39;")
	return "<a class='pump-switch [high ? "switch-high" : ""]' href='[href]' role='switch' aria-checked='[high ? "true" : "false"]' aria-label='[safe_label]' title='[safe_label]'><span class='switch-low-label'>[low_label]</span><span class='switch-lever' aria-hidden='true'></span><span class='switch-high-label'>[high_label]</span></a>"

/obj/machinery/stationtrauma_pump_controller/proc/control_device(device_ref, action, value)
	if(build_stage != 3)
		return FALSE
	var/obj/machinery/device = locate(device_ref)
	if(!(device in controlled_devices()))
		return FALSE
	var/list/data = ui_data(null)
	for(var/list/entry as anything in data["devices"])
		if(entry["ref"] != device_ref)
			continue
		switch(action)
			if("power")
				set_device(device, !entry["on"], entry["rate"])
			if("rate")
				var/rate = value == "min" ? STATIONTRAUMA_PUMP_MIN_FLOW : stationtrauma_parse_flow(value)
				if(isnull(rate))
					return FALSE
				set_device(device, entry["on"], rate)
			if("pressure")
				var/pressure = value == "min" ? STATIONTRAUMA_PUMP_MIN_PRESSURE : stationtrauma_parse_pressure(value)
				if(isnull(pressure) || isnull(entry["pressure"]))
					return FALSE
				if(istype(device, /obj/machinery/bilge_pump))
					var/obj/machinery/bilge_pump/pump = device
					pump.water_pressure = pressure
				else
					var/obj/machinery/stationtrauma_water_device/inline_pump/pressure/pump = device
					pump.target_pressure = pressure
			else
				return FALSE
		return TRUE
	return FALSE

/obj/machinery/stationtrauma_pump_controller/Topic(href, list/href_list)
	if(href_list["close"])
		close_pumps(usr)
		return
	if(..() || build_stage != 3 || !pump_windows[usr])
		return
	var/device_ref = href_list["device"]
	if(href_list["toggle"])
		control_device(device_ref, "power")
	else if((href_list["setting"] in list("rate", "pressure")) && (href_list["preset"] in list("min", "max")))
		control_device(device_ref, href_list["setting"], href_list["preset"])
	alarm_changed()

/obj/machinery/stationtrauma_pump_controller/item_interaction(mob/living/user, obj/item/item, list/modifiers)
	if(build_stage == 0 && istype(item, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/cable = item
		if(!cable.use(5))
			balloon_alert(user, "нужно пять проводов")
			return ITEM_INTERACT_BLOCKING
		build_stage = 1
		update_appearance()
		balloon_alert(user, "провода установлены")
		return ITEM_INTERACT_SUCCESS
	if(build_stage == 1 && istype(item, /obj/item/electronics/stationtrauma_pump_controller))
		if(!user.transferItemToLoc(item, src))
			return ITEM_INTERACT_BLOCKING
		chip = item
		build_stage = 2
		update_appearance()
		balloon_alert(user, "чип установлен")
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/stationtrauma_pump_controller/screwdriver_act(mob/living/user, obj/item/tool)
	if(build_stage < 2)
		return NONE
	build_stage = build_stage == 3 ? 2 : 3
	apply_settings()
	balloon_alert(user, build_stage == 3 ? "собран" : "крышка открыта")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_pump_controller/crowbar_act(mob/living/user, obj/item/tool)
	if(build_stage != 2)
		return NONE
	chip.forceMove(drop_location())
	chip = null
	build_stage = 1
	update_appearance()
	balloon_alert(user, "чип извлечён")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_pump_controller/wirecutter_act(mob/living/user, obj/item/tool)
	if(build_stage != 1)
		return NONE
	new /obj/item/stack/cable_coil(drop_location(), 5)
	build_stage = 0
	update_appearance()
	balloon_alert(user, "провода извлечены")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_pump_controller/wrench_act(mob/living/user, obj/item/tool)
	if(build_stage)
		balloon_alert(user, "сначала разобрать")
		return ITEM_INTERACT_BLOCKING
	new /obj/item/wallframe/stationtrauma_pump_controller(drop_location())
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_pump_controller/examine(mob/user)
	. = ..()
	switch(build_stage)
		if(0)
			. += span_notice("Установите пять проводов. Ключом можно снять корпус.")
		if(1)
			. += span_notice("Установите чип контроллера помп. Кусачками можно снять провода.")
		if(2)
			. += span_notice("Закройте крышку отвёрткой. Ломом можно извлечь чип.")
		if(3)
			. += span_notice("ЛКМ — управление. Отвёртка — открыть крышку.")

/obj/item/wallframe/stationtrauma_pump_controller
	name = "корпус контроллера помп"
	desc = "Закрепите корпус на стене, добавьте пять проводов и чип контроллера, закройте крышку отвёрткой."
	icon_state = "apc"
	result_path = /obj/machinery/stationtrauma_pump_controller/unassembled
	pixel_shift = 24

/obj/item/electronics/stationtrauma_pump_controller
	name = "чип контроллера помп"
	desc = "Управляет трюмными помпами и водяными выпусками. Устанавливается в проводной настенный корпус."
	color = STATIONTRAUMA_WATER_COLOR

/datum/crafting_recipe/stationtrauma_pump_controller_case
	name = "Корпус контроллера помп"
	result = /obj/item/wallframe/stationtrauma_pump_controller
	reqs = list(/obj/item/stack/sheet/iron = 2)
	time = 2 SECONDS
	category = CAT_STRUCTURE

/datum/crafting_recipe/stationtrauma_pump_controller_chip
	name = "Чип контроллера помп"
	result = /obj/item/electronics/stationtrauma_pump_controller
	reqs = list(/obj/item/stack/sheet/iron = 1, /obj/item/stack/sheet/glass = 1, /obj/item/stack/cable_coil = 2)
	tool_behaviors = list(TOOL_SCREWDRIVER)
	time = 3 SECONDS
	category = CAT_STRUCTURE

/// Only the attached vessel's holder participates in the water network.
/datum/component/plumbing/stationtrauma_water/connector
	demand_connects = ALL_CARDINALS
	supply_connects = ALL_CARDINALS

/datum/component/plumbing/stationtrauma_water/connector/send_request(dir)
	var/obj/machinery/stationtrauma_water_device/connector/port = parent
	var/obj/machinery/stationtrauma_water_device/barrel/barrel = port.attached
	if(!istype(barrel) || !barrel.valve_open)
		return
	process_request(5000 * SSFLUIDS_DT / max(1, length(ducts)), /datum/reagent/water, dir)

/datum/component/plumbing/stationtrauma_water/connector/can_give(amount, reagent, datum/ductnet/net)
	var/obj/machinery/stationtrauma_water_device/connector/port = parent
	var/obj/machinery/stationtrauma_water_device/barrel/barrel = port.attached
	var/obj/machinery/bilge_pump/portable/pump = port.attached
	if(istype(barrel))
		return barrel.valve_open && ..()
	if(istype(pump))
		return pump.discharging && pump.is_operational && !pump.panel_open && pump.cell?.charge && ..()
	return FALSE

/datum/component/plumbing/stationtrauma_water/connector/create_overlays(atom/movable/source, list/overlays)
	return

/obj/machinery/stationtrauma_water_device/connector
	name = "универсальный водяной порт"
	desc = "Подведите водяную трубу с любой стороны. Поставьте сверху бочку или переносной насос и подключите ключом."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_controller.dmi'
	icon_state = "port"
	density = FALSE
	plumbing_type = /datum/component/plumbing/stationtrauma_water/connector
	var/obj/machinery/attached

/obj/machinery/stationtrauma_water_device/connector/proc/attach(obj/machinery/vessel)
	if(!anchored || attached || QDELETED(vessel) || vessel.loc != loc)
		return FALSE
	var/vessel_level
	if(istype(vessel, /obj/machinery/stationtrauma_water_device/barrel))
		var/obj/machinery/stationtrauma_water_device/barrel/barrel = vessel
		vessel_level = barrel.water_level
	else if(istype(vessel, /obj/machinery/bilge_pump/portable))
		var/obj/machinery/bilge_pump/portable/pump = vessel
		vessel_level = pump.water_level
	else
		return FALSE
	if(vessel_level != water_level)
		return FALSE
	attached = vessel
	var/datum/component/plumbing/stationtrauma_water/connector/connection = GetComponent(/datum/component/plumbing/stationtrauma_water/connector)
	connection.reagents = vessel.reagents
	return TRUE

/obj/machinery/stationtrauma_water_device/connector/proc/detach()
	var/datum/component/plumbing/stationtrauma_water/connector/connection = GetComponent(/datum/component/plumbing/stationtrauma_water/connector)
	if(connection)
		connection.reagents = reagents
	attached = null

/obj/machinery/stationtrauma_water_device/connector/Destroy()
	if(istype(attached, /obj/machinery/stationtrauma_water_device/barrel))
		var/obj/machinery/stationtrauma_water_device/barrel/barrel = attached
		barrel.disconnect_port()
	else if(istype(attached, /obj/machinery/bilge_pump/portable))
		var/obj/machinery/bilge_pump/portable/pump = attached
		pump.disconnect_port()
	return ..()

/obj/machinery/stationtrauma_water_device/connector/wrench_act(mob/living/user, obj/item/tool)
	if(attached)
		balloon_alert(user, "сначала отсоединить прибор")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/stationtrauma_water_device/barrel
	name = "водяная бочка"
	desc = "Переносной резервуар. Поставьте на водяной порт и прикрутите ключом. ЛКМ — клапан, объём и статус подключения. Направление бочки не имеет значения."
	anchored = FALSE
	plumbing_type = null
	var/valve_open = FALSE
	var/start_connected = FALSE
	var/obj/machinery/stationtrauma_water_device/connector/port

/obj/machinery/stationtrauma_water_device/barrel/post_machine_initialize()
	. = ..()
	if(start_connected)
		connect_port()

/obj/machinery/stationtrauma_water_device/barrel/Destroy()
	disconnect_port()
	return ..()

/obj/machinery/stationtrauma_water_device/barrel/proc/connect_port()
	for(var/obj/machinery/stationtrauma_water_device/connector/candidate in loc)
		if(candidate.attach(src))
			port = candidate
			set_anchored(TRUE)
			return TRUE
	return FALSE

/obj/machinery/stationtrauma_water_device/barrel/proc/disconnect_port()
	if(port)
		port.detach()
		port = null
	set_anchored(FALSE)

/obj/machinery/stationtrauma_water_device/barrel/wrench_act(mob/living/user, obj/item/tool)
	if(port)
		disconnect_port()
		balloon_alert(user, "отсоединена")
	else
		balloon_alert(user, connect_port() ? "подключена" : "нужен свободный порт")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_water_device/barrel/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	var/list/options = list(valve_open ? "Закрыть клапан" : "Открыть клапан", "Слить рядом")
	var/datum/component/plumbing/stationtrauma_water/connector/connection = port?.GetComponent(/datum/component/plumbing/stationtrauma_water/connector)
	var/choice = tgui_input_list(user, "[round(reagents.get_reagent_amount(/datum/reagent/water), 0.1)] / [capacity] л. Порт: [port ? "подключена" : "нет"]. Труба: [length(connection?.ducts) ? "подключена" : "нет"]. Клапан: [valve_open ? "открыт" : "закрыт"].", name, options)
	if(QDELETED(src) || !choice || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return
	if(choice == "Слить рядом")
		if(valve_open)
			prompt_stationtrauma_water_drain(src, user)
		else
			balloon_alert(user, "клапан закрыт")
	else
		valve_open = choice == "Открыть клапан"

/obj/machinery/stationtrauma_water_device/barrel/examine(mob/user)
	. = ..()
	. += span_notice("Клапан [valve_open ? "открыт" : "закрыт"]. Бочка [port ? "подключена к порту" : "не подключена"].")

/datum/component/plumbing/stationtrauma_water/inline_pump/send_request(dir)
	var/obj/machinery/stationtrauma_water_device/inline_pump/pump = parent
	if(!pump.on || !pump.is_operational || pump.flow_rate <= 0)
		return
	var/energy = 750 * SSFLUIDS_DT
	if(pump.use_energy(energy, force = FALSE) < energy)
		return
	process_request(pump.flow_rate * SSFLUIDS_DT, /datum/reagent/water, dir)

/datum/component/plumbing/stationtrauma_water/inline_pump/can_give(amount, reagent, datum/ductnet/net)
	var/obj/machinery/stationtrauma_water_device/inline_pump/pump = parent
	return pump.on && pump.is_operational && ..()

/obj/machinery/stationtrauma_water_device/inline_pump
	name = "насос водяного контура"
	desc = "Направленный насос: вход с запада, выход с востока. ЛКМ — питание и расход в л/с; ключ и Alt+ЛКМ — крепление и поворот."
	icon_state = "liquid_pump"
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/liquid_pump.dmi'
	density = FALSE
	capacity = 10000
	use_power = IDLE_POWER_USE
	idle_power_usage = 5
	plumbing_type = /datum/component/plumbing/stationtrauma_water/inline_pump
	var/on = FALSE
	var/flow_rate = 100

/obj/machinery/stationtrauma_water_device/inline_pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	ui_interact(user)

/obj/machinery/stationtrauma_water_device/inline_pump/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosPump", name)
		ui.open()

/obj/machinery/stationtrauma_water_device/inline_pump/ui_data(mob/user)
	return list("on" = on, "rate" = flow_rate, "max_rate" = 200)

/obj/machinery/stationtrauma_water_device/inline_pump/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	if(action == "power")
		on = !on
		return TRUE
	if(action == "rate")
		var/rate = stationtrauma_parse_flow(params["rate"])
		if(isnull(rate))
			return FALSE
		flow_rate = rate
		return TRUE
	return FALSE

/datum/component/plumbing/stationtrauma_water/universal_outlet
	parent_type = /datum/component/plumbing/stationtrauma_water/outlet
	demand_connects = SOUTH
	supply_connects = NONE

/obj/machinery/stationtrauma_water_device/outlet/universal
	name = "клапан выпуска воды"
	desc = "Постоянно открытый выпуск на своём полу: в отсек или в океан. Перекрывается вентилем на трубе. Для сброса в океан нужен напор выше наружного давления."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "active_output"
	color = null
	use_power = NO_POWER_USE
	capacity = 10000
	plumbing_type = /datum/component/plumbing/stationtrauma_water/universal_outlet

/obj/machinery/stationtrauma_water_device/outlet/universal/process(seconds_per_tick)
	if(!anchored || (machine_stat & BROKEN) || !isopenturf(loc) || !reagents.total_volume)
		return
	var/datum/component/plumbing/stationtrauma_water/connection = GetComponent(/datum/component/plumbing/stationtrauma_water)
	if(water_pressure <= connection.required_pressure())
		return
	var/turf/open/tile = loc
	var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
	if(water?.infinite_source)
		var/amount = stationtrauma_water_transfer_amount(reagents, flow_rate * seconds_per_tick, INFINITY)
		if(amount)
			reagents.remove_reagent(/datum/reagent/water, amount)
			discharged_volume += amount
	else
		discharged_volume += tile.receive_water(reagents, flow_rate * seconds_per_tick)

/obj/machinery/stationtrauma_water_device/outlet/universal/examine(mob/user)
	. = ..()
	. += span_notice("Сброшено: [round(discharged_volume, 0.1)] л. Давление: [round(water_pressure, 0.01)] бар. Расход: [flow_rate] л/с.")

// Keep old mapped paths while both discharge destinations use the same floor device.
/obj/machinery/stationtrauma_water_device/outlet/overboard
	parent_type = /obj/machinery/stationtrauma_water_device/outlet/universal

/proc/stationtrauma_parse_pressure(value)
	if(value == "max")
		return STATIONTRAUMA_PUMP_MAX_PRESSURE
	var/pressure = isnum(value) ? value : text2num("[value]")
	if(!isnum(pressure) || !IS_FINITE(pressure))
		return null
	return clamp(pressure / 100, 0, 100)

/datum/component/plumbing/stationtrauma_water/inline_pump/pressure
	demand_connects = NORTH
	supply_connects = SOUTH

/obj/machinery/stationtrauma_water_device/inline_pump/pressure
	name = "водяной насос давления"
	desc = "ЛКМ — питание и давление в штатном окне TG (100 кПа = 1 бар). Alt+ЛКМ на закреплённом насосе — предел расхода в л/с. Вход противоположен направлению стрелки; выход по стрелке."
	icon = 'icons/obj/machines/atmospherics/binary_devices.dmi'
	icon_state = "pump_map-3"
	color = STATIONTRAUMA_WATER_COLOR
	layer = GAS_PUMP_LAYER
	plumbing_type = /datum/component/plumbing/stationtrauma_water/inline_pump/pressure
	flow_rate = 1800
	var/target_pressure = 80

/obj/machinery/stationtrauma_water_device/inline_pump/pressure/update_icon_state()
	. = ..()
	color = null
	icon_state = "pump_[on && is_operational ? "on" : "off"]-[(water_level in list(2, 4)) ? 2 : 1]"

/obj/machinery/stationtrauma_water_device/inline_pump/pressure/ui_data(mob/user)
	return list("on" = on, "pressure" = target_pressure * 100, "max_pressure" = 10000)

/obj/machinery/stationtrauma_water_device/inline_pump/pressure/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "pressure")
		var/pressure = stationtrauma_parse_pressure(params["pressure"])
		if(isnull(pressure))
			return FALSE
		target_pressure = pressure
		return TRUE
	. = ..()
	if(.)
		update_appearance(UPDATE_ICON)

/obj/machinery/stationtrauma_water_device/inline_pump/pressure/click_alt(mob/user)
	if(!anchored)
		return ..()
	var/rate = tgui_input_number(user, "Предел расхода, л/с", name, flow_rate, STATIONTRAUMA_WATER_MAX_FLOW, 0)
	if(!QDELETED(src) && !isnull(rate) && user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS))
		flow_rate = stationtrauma_parse_flow(rate)
	return CLICK_ACTION_SUCCESS

/obj/machinery/stationtrauma_water_device/inline_pump/pressure/examine(mob/user)
	. = ..()
	. += span_notice("Выход: [target_pressure] бар. Предел расхода: [flow_rate] л/с.")

/obj/machinery/stationtrauma_water_device/valve/passive_gate
	name = "пассивный водяной клапан"
	desc = "Пропускает воду только по стрелке при положительном перепаде давления, без питания. ЛКМ — открыть или закрыть."
	icon = 'icons/obj/machines/atmospherics/binary_devices.dmi'
	icon_state = "passgate_map-3"
	color = STATIONTRAUMA_WATER_COLOR
	layer = GAS_PUMP_LAYER
	plumbing_type = /datum/component/plumbing/stationtrauma_water/directional
	valve_open = TRUE

/obj/machinery/stationtrauma_water_device/valve/passive_gate/update_icon_state()
	. = ..()
	color = null
	icon_state = "passgate_[valve_open ? "on" : "off"]-[(water_level in list(2, 4)) ? 2 : 1]"

/obj/machinery/stationtrauma_water_device/valve/pressure_gate
	parent_type = /obj/machinery/stationtrauma_water_device/valve/passive_gate
	name = "водяной клапан давления"
	desc = "Ограничивает выходное давление, не повышая его. Пропускает только по стрелке. ЛКМ — включение и настройка в кПа (100 кПа = 1 бар)."
	icon_state = "pvalve_map-3"
	var/target_pressure = 70

/obj/machinery/stationtrauma_water_device/valve/pressure_gate/update_icon_state()
	. = ..()
	icon_state = "pvalve_[valve_open ? "on" : "off"]-[(water_level in list(2, 4)) ? 2 : 1]"

/obj/machinery/stationtrauma_water_device/valve/pressure_gate/attack_hand(mob/living/user, list/modifiers)
	if(user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS))
		ui_interact(user)

/obj/machinery/stationtrauma_water_device/valve/pressure_gate/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosPump", name)
		ui.open()

/obj/machinery/stationtrauma_water_device/valve/pressure_gate/ui_data(mob/user)
	return list("on" = valve_open, "pressure" = target_pressure * 100, "max_pressure" = 10000)

/obj/machinery/stationtrauma_water_device/valve/pressure_gate/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	if(action == "power")
		valve_open = !valve_open
		update_appearance(UPDATE_ICON)
		return TRUE
	if(action == "pressure")
		var/pressure = stationtrauma_parse_pressure(params["pressure"])
		if(isnull(pressure))
			return FALSE
		target_pressure = pressure
		return TRUE
	return FALSE

/obj/machinery/stationtrauma_water_device/valve/pressure_gate/examine(mob/user)
	. = ..()
	. += span_notice("Предел выхода: [target_pressure] бар; вход: [round(water_pressure, 0.01)] бар.")
