/// Ordinary shuttle-computer appearance, with no emergency-shuttle controller or sonar.
/obj/machinery/computer/stationtrauma_space_navigation
	name = "навигационная консоль"
	desc = "Орбитальная карта, управление тягой и стыковкой корабля."
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	use_power = NO_POWER_USE
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	var/list/navigation_windows = list()

/obj/machinery/computer/stationtrauma_space_navigation/Destroy()
	for(var/mob/viewer as anything in navigation_windows.Copy())
		close_navigation(viewer)
	vessel = null
	return ..()

/obj/machinery/computer/stationtrauma_space_navigation/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!vessel?.overmap || !can_interact(user))
		return
	var/datum/browser/popup = navigation_windows[user]
	if(!popup)
		popup = new(user, "stationtrauma_space_[REF(src)]", name, 940, 540, src)
		popup.add_stylesheet("stationtrauma_space", 'modular_bandastation/space_overmap/html/navigation.css')
		popup.add_stylesheet("stationtrauma_helm", 'modular_bandastation/overmap/html/helm_controls.css')
		popup.add_script("stationtrauma_helm", 'modular_bandastation/overmap/html/helm_controls.js')
		popup.add_script("stationtrauma_space", 'modular_bandastation/space_overmap/html/navigation.js')
		navigation_windows[user] = popup
		RegisterSignals(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(close_navigation))
	var/html = file2text('modular_bandastation/space_overmap/html/navigation.html')
	html = replacetext(html, "@CONSOLE@", REF(src))
	html = replacetext(html, "@STATE@", replacetext(json_encode(ui_data(user)), "<", "\\u003c"))
	popup.set_head_content("")
	popup.set_content(html)
	popup.open()

/obj/machinery/computer/stationtrauma_space_navigation/ui_data(mob/user)
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(!map)
		return list()
	var/datum/stationtrauma_overmap_sector/space/sector = map.sector
	var/datum/stationtrauma_overmap_site/space/target = map.sites[map.selected_destination]
	var/distance = target ? map.distance_to(target) : 0
	var/list/data = list(
		"au_scale" = ST_SPACE_AU_SCALE,
		"status" = map.status,
		"sector" = sector?.id, "sector_name" = sector?.name,
		"jumping" = !!map.jump_target,
		"star" = list("name" = sector?.name, "x" = 0, "y" = 0),
		"x" = map.pos_x, "y" = map.pos_y,
		"vx" = map.velocity_x, "vy" = map.velocity_y,
		"course" = map.course, "ordered_course" = map.ordered_course,
		"speed" = map.speed, "throttle" = map.throttle,
		"braking" = map.braking, "braking_distance" = map.get_braking_distance(),
		"engines" = round(map.engine_fraction() * 100),
		"engines_running" = vessel.engines_running,
		"helm" = map.helm_engaged, "autopilot" = map.autopilot,
		"preparing" = map.preparing, "planning" = map.planning,
		"relocating" = map.relocating, "landed" = !!map.docked?.landing,
		"selected" = map.selected_destination, "docked" = map.docked?.id,
		"coupled" = !!map.ship_docking,
		"docking_request" = map.ship_docking_request_data(),
		"can_request_ship_dock" = map.available_for_ship_docking(),
		"landing" = target?.landing, "distance" = distance,
		"eta" = target && map.get_target_speed() > 0 ? max(0, distance - map.radius - target.radius) / map.get_target_speed() : null,
		"scan_ready" = !map.preparing && !map.relocating && map.is_operational() && world.time >= map.next_scan && !panel_open && !(machine_stat & (NOPOWER|BROKEN)),
		"can_dock" = !map.preparing && !map.docked && !map.helm_engaged && map.speed <= 0.05 && map.can_dock(target, map.control_revision),
		"routes" = map.known_sites(), "path" = map.autopilot_path,
		"zones" = map.encounter_data(), "terrain" = map.terrain_data(),
		"ship_contacts" = map.ship_echo_data(),
		"encounter" = map.encounter_status, "sensor_range" = map.sensor_range,
	)
	if(istype(target, /datum/stationtrauma_overmap_site/space/planet) && map.knows_site(target))
		var/datum/stationtrauma_overmap_site/space/planet/planet = target
		data["planet"] = planet.survey_data()
	return data

/** Validate every control server-side, including stale windows and hand-written hrefs. */
/obj/machinery/computer/stationtrauma_space_navigation/proc/navigation_command(action, value)
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(!map || map.relocating || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	if((map.jump_target || map.dispatch_target) && action != "stop")
		return FALSE
	map.advance()
	switch(action)
		if("ship_dock")
			return map.request_ship_docking(text2num(value))
		if("accept_ship_dock", "decline_ship_dock")
			return map.respond_ship_docking(text2num(value), action == "accept_ship_dock")
		if("engine")
			if(!(value in list("0", "1")))
				return FALSE
			return map.set_engines_running(value == "1")
		if("maneuver")
			var/direction = text2num(value)
			return IS_FINITE(direction) && map.command_maneuver(direction)
		if("scan")
			return map.scan_sector()
		if("stop")
			map.request_brake()
		if("select")
			return map.select_site(value)
		if("turn", "throttle")
			var/number = text2num(value)
			if(!IS_FINITE(number) || !vessel.engines_running || map.ship_docking)
				return FALSE
			if(action == "turn")
				if(!(number in list(-15, 15)))
					return FALSE
				map.command_course(map.ordered_course + number)
			else
				return map.command_throttle(number)
		if("depart")
			map.command_course(map.ordered_course)
			return map.sail()
		if("autopilot")
			if(map.preparing || map.ship_docking || map.planning || map.throttle <= 0 || map.docked?.id == map.selected_destination)
				return FALSE
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap, engage_autopilot))
		if("dock")
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, dock))
		else
			return FALSE
	return TRUE

/obj/machinery/computer/stationtrauma_space_navigation/proc/close_navigation(mob/user)
	SIGNAL_HANDLER
	var/datum/browser/popup = navigation_windows[user]
	navigation_windows -= user
	UnregisterSignal(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT))
	if(popup)
		popup.close()
		qdel(popup)

/obj/machinery/computer/stationtrauma_space_navigation/Topic(href, list/href_list)
	if(href_list["close"])
		close_navigation(usr)
		return
	var/datum/browser/popup = navigation_windows[usr]
	// Native movement relocates console and pilot at different points within the same manoeuvre.
	if(vessel?.overmap?.relocating)
		return
	if(..() || !can_interact(usr))
		close_navigation(usr)
		return
	if(!popup || !vessel?.overmap)
		return
	if(href_list["action"])
		navigation_command(href_list["action"], href_list["value"])
	usr << output(url_encode(json_encode(ui_data(usr))), "[popup.window_id].browser:updateSpace")
