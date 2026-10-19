/** Module-owned browser and controls; the sonar is a display mockup, not a world scanner. */
/obj/machinery/computer/stationtrauma_navigation
	var/list/navigation_windows = list()
	var/active_sonar = FALSE
	var/datum/looping_sound/stationtrauma_sonar/sonar_loop

/datum/looping_sound/stationtrauma_sonar
	mid_sounds = 'modular_bandastation/underwater_submarine/sounds/sonar.wav'
	volume = 35
	use_sound_tokens = TRUE
	pressure_affected = FALSE

/obj/machinery/computer/stationtrauma_navigation/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	update_use_power(NO_POWER_USE)
	if(!vessel || !can_interact(user))
		return
	var/datum/browser/popup = navigation_windows[user]
	if(!popup)
		popup = new(user, "stationtrauma_nav_[REF(src)]", name, 1060, 790, src)
		popup.add_stylesheet("stationtrauma_console", 'modular_bandastation/underwater_machinery/html/console.css')
		popup.add_stylesheet("stationtrauma_navigation", 'modular_bandastation/underwater_submarine/html/navigation.css')
		navigation_windows[user] = popup
		RegisterSignals(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(close_navigation))
	var/html = file2text('modular_bandastation/underwater_submarine/html/navigation.html')
	html = replacetext(html, "@CONSOLE@", REF(src))
	html = replacetext(html, "@STATE@", replacetext(json_encode(ui_data(user)), "<", "\\u003c"))
	popup.add_script("stationtrauma_navigation", 'modular_bandastation/underwater_submarine/html/navigation.js')
	popup.set_head_content("")
	popup.set_content(html)
	popup.open()

/obj/machinery/computer/stationtrauma_navigation/ui_data(mob/user)
	if(!vessel)
		return list()
	var/obj/docking_port/stationary/stationtrauma/origin = vessel.fixed_location
	var/list/routes = list()
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in vessel.berths)
		if(berth != origin)
			routes += list(list("name" = berth.name, "distance" = vessel.distance_to(berth), "position" = berth.route_position))
	for(var/destination in vessel.unloaded_destinations)
		var/datum/map_template/stationtrauma_route/template_type = vessel.unloaded_destinations[destination]
		var/obj/docking_port/stationary/stationtrauma/berth_type = initial(template_type.destination_berth_type)
		routes += list(list("name" = destination, "distance" = vessel.distance_to(destination), "position" = initial(berth_type.route_position)))
	var/progress = vessel.path_progress()
	var/duration = SSsounds.get_sound_length('modular_bandastation/underwater_submarine/sounds/sonar.wav')
	var/elapsed = sonar_loop?.sound_token_instance ? max(0, REALTIMEOFDAY - sonar_loop.sound_token_instance.start_time) : 0
	return list(
		"status" = vessel.voyage_status,
		"travelling" = vessel.travelling,
		"engines" = vessel.engines_running,
		"selected" = vessel.selected_destination,
		"target" = vessel.voyage_target,
		"progress" = progress,
		"distance" = vessel.voyage_distance,
		"travelled" = round(vessel.voyage_distance * progress, 1),
		"routes" = routes,
		"origin" = origin?.name,
		"position" = origin?.route_position,
		"sonar" = active_sonar,
		"sonar_period" = duration / 10,
		"sonar_phase" = duration ? (elapsed % duration) / duration : 0,
	)

/** The server validates every switch and departure, including forged browser hrefs. */
/obj/machinery/computer/stationtrauma_navigation/proc/navigation_command(action, value)
	if(!vessel || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	if(action == "sonar")
		if(value != "active" && value != "passive")
			return FALSE
		active_sonar = (value == "active")
		if(active_sonar)
			sonar_loop.start()
		else
			sonar_loop.stop()
		refresh_hardware()
		return TRUE
	if(vessel.travelling)
		return FALSE
	switch(action)
		if("select")
			var/distance = vessel.distance_to(value)
			if(isnull(distance) || distance <= 0)
				return FALSE
			vessel.selected_destination = value
		if("engine")
			vessel.engines_running = !vessel.engines_running
		if("depart")
			var/distance = vessel.distance_to(vessel.selected_destination)
			if(!vessel.engines_running || isnull(distance) || distance <= 0)
				return FALSE
			INVOKE_ASYNC(vessel, TYPE_PROC_REF(/obj/docking_port/mobile/stationtrauma, travel_to), vessel.selected_destination)
		else
			return FALSE
	SEND_SIGNAL(vessel, COMSIG_STATIONTRAUMA_NAVIGATION_CHANGED)
	return TRUE

/** Closing or disconnecting releases the browser, but does not stop the physical sonar. */
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
	if(..())
		close_navigation(usr)
		return
	if(!popup || !vessel)
		return
	if(href_list["action"])
		navigation_command(href_list["action"], href_list["value"])
	usr << output(url_encode(json_encode(ui_data(usr))), "[popup.window_id].browser:updateVoyage")
