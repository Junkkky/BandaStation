/** Module-owned CRT navigation, with shared server-authoritative movement and sonar. */
/obj/machinery/computer/stationtrauma_navigation
	var/list/navigation_windows = list()
	/// Cached only for the physical console's existing illuminated sprite.
	var/active_sonar = FALSE

/obj/machinery/computer/stationtrauma_navigation/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	update_use_power(NO_POWER_USE)
	if(!vessel?.overmap || !can_interact(user))
		return
	var/datum/browser/popup = navigation_windows[user]
	if(!popup)
		popup = new(user, "stationtrauma_nav_[REF(src)]", name, 1060, 860, src)
		popup.add_stylesheet("stationtrauma_console", 'modular_bandastation/underwater_machinery/html/console.css')
		popup.add_stylesheet("stationtrauma_navigation", 'modular_bandastation/underwater_submarine/html/navigation.css')
		popup.add_stylesheet("stationtrauma_helm", 'modular_bandastation/overmap/html/helm_controls.css')
		popup.add_script("stationtrauma_helm", 'modular_bandastation/overmap/html/helm_controls.js')
		navigation_windows[user] = popup
		RegisterSignals(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(close_navigation))
	var/html = file2text('modular_bandastation/underwater_submarine/html/navigation.html')
	html = replacetext(html, "@VESSEL@", html_encode(vessel.name))
	html = replacetext(html, "@CONSOLE@", REF(src))
	html = replacetext(html, "@STATE@", replacetext(json_encode(ui_data(user)), "<", "\\u003c"))
	popup.add_script("stationtrauma_navigation", 'modular_bandastation/underwater_submarine/html/navigation.js')
	popup.set_head_content("")
	popup.set_content(html)
	popup.open()

/obj/machinery/computer/stationtrauma_navigation/ui_data(mob/user)
	var/datum/stationtrauma_overmap/map = vessel?.overmap
	if(!map)
		return list()
	var/list/routes = map.known_sites()
	var/list/drives = list()
	var/list/chart = list()
	for(var/contact in map.charted_terrain)
		chart += list(map.charted_terrain[contact])
	var/drive_power = 0
	for(var/obj/machinery/power/stationtrauma_pgd/engine as anything in vessel.drive_engines)
		drives += list(list("enabled" = engine.enabled, "tripped" = engine.thermal_trip, "status" = engine.drive_status(), "temperature" = round(engine.temperature, 0.1), "coils" = round(engine.coil_condition), "power" = round(engine.actual_power / (1 MEGA WATTS), 0.1), "thrust" = round(engine.available_thrust() * 100)))
		drive_power += engine.actual_power
	return list(
		"status" = map.status,
		"travelling" = vessel.travelling,
		"engines" = vessel.engines_running,
		"physical_drives" = vessel.requires_pgd,
		"drive_mode" = vessel.drive_mode,
		"drives" = drives,
		"power" = round(drive_power / (1 MEGA WATTS), 0.1),
		"noise" = round(map.acoustic_noise()),
		"speed" = round(map.speed, 0.1),
		"throttle" = map.throttle, "braking" = map.braking,
		"braking_distance" = round(map.get_braking_distance()),
		"loading" = min(map.prepared_site ? 100 : 99, round(vessel.loading_fraction * 100)),
		"preparing" = map.preparing,
		"helm" = map.helm_engaged,
		"autopilot" = map.autopilot,
		"planning" = map.planning,
		"path" = map.autopilot_path,
		"chart" = chart,
		"arrival_pending" = map.arrival_pending,
		"x" = map.pos_x,
		"y" = map.pos_y,
		"course" = map.course,
		"drift" = map.speed > 0.05 ? delta_to_angle(map.velocity_x, map.velocity_y) : map.course,
		"ordered_course" = map.ordered_course,
		"length" = vessel.width,
		"beam" = vessel.height,
		"radius" = map.radius,
		"selected" = map.selected_destination,
		"progress" = vessel.path_progress(),
		"distance" = map.trip_distance,
		"travelled" = round(map.travelled),
		"remaining" = vessel.distance_to(map.selected_destination),
		"routes" = routes,
		"origin" = vessel.fixed_location?.shuttle_id,
		"sonar" = map.active_sonar,
		"sonar_range" = map.active_sonar ? ST_NAV_ACTIVE_RANGE : ST_NAV_PASSIVE_RANGE,
		"sonar_period" = ST_NAV_PING_INTERVAL / (1 SECONDS),
		"sonar_age" = map.last_ping ? (world.time - map.last_ping) / (1 SECONDS) : -1,
		"contacts" = map.echoes,
	)

/** Validate every forged href; a map-loading hold never blocks stop or helm controls. */
/obj/machinery/computer/stationtrauma_navigation/proc/navigation_command(action, value)
	var/datum/stationtrauma_overmap/map = vessel?.overmap
	if(!map || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	vessel.update_voyage_distance()
	switch(action)
		if("stop")
			map.request_brake()
		if("throttle")
			if(!map.command_throttle(text2num(value)))
				return FALSE
		if("sonar")
			if(value != "active" && value != "passive")
				return FALSE
			map.active_sonar = value == "active"
			map.echoes = list()
			if(map.active_sonar)
				map.ping()
			else
				map.listen()
		if("course", "turn")
			var/number = text2num(value)
			if(!IS_FINITE(number) || (action == "course" && (number < 0 || number >= 360)) || (action == "turn" && !(number in list(-15, 15))))
				return FALSE
			map.command_course(action == "course" ? number : map.course + number)
		if("engine")
			if(vessel.engines_running)
				map.command_throttle(0)
				vessel.engines_running = FALSE
			else
				vessel.engines_running = TRUE
		if("drive_mode")
			var/mode = text2num(value)
			if(!vessel.requires_pgd || !(mode in list(1, 2, 3, 4)))
				return FALSE
			vessel.drive_mode = mode
			vessel.stop_drive_output()
		if("drive")
			var/index = text2num(value)
			if(!vessel.requires_pgd || !ISINTEGER(index) || index < 1 || index > length(vessel.drive_engines))
				return FALSE
			var/obj/machinery/power/stationtrauma_pgd/engine = vessel.drive_engines[index]
			if(!engine.toggle_drive())
				return FALSE
		if("select")
			if(!map.select_site(value))
				return FALSE
		if("depart")
			map.command_course(map.ordered_course)
			if(!map.sail())
				return FALSE
		if("autopilot")
			if(map.planning || !map.sites[map.selected_destination] || !vessel.engines_running || map.throttle <= 0)
				return FALSE
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap, engage_autopilot))
		else
			return FALSE
	vessel.refresh_drive_motion()
	SEND_SIGNAL(vessel, COMSIG_STATIONTRAUMA_NAVIGATION_CHANGED)
	return TRUE

/** Closing the display releases only the viewer; movement and sonar belong to the vessel. */
/obj/machinery/computer/stationtrauma_navigation/proc/close_navigation(mob/user)
	SIGNAL_HANDLER
	var/datum/browser/popup = navigation_windows[user]
	navigation_windows -= user
	UnregisterSignal(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT))
	if(popup)
		popup.close()
		qdel(popup)

/obj/machinery/computer/stationtrauma_navigation/Topic(href, list/href_list)
	if(href_list["close"])
		close_navigation(usr)
		return
	var/datum/browser/popup = navigation_windows[usr]
	if(..() || !can_interact(usr))
		close_navigation(usr)
		return
	if(!popup || !vessel?.overmap)
		return
	if(href_list["action"])
		navigation_command(href_list["action"], href_list["value"])
	usr << output(url_encode(json_encode(ui_data(usr))), "[popup.window_id].browser:updateVoyage")
