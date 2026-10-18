/** A module-owned live browser: navigation requires no shared frontend or TG changes. */
/obj/machinery/computer/stationtrauma_navigation
	var/list/navigation_windows = list()

/obj/machinery/computer/stationtrauma_navigation/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!vessel || !can_interact(user))
		return
	var/datum/browser/popup = navigation_windows[user]
	if(!popup)
		popup = new(user, "stationtrauma_nav_[REF(src)]", name, 650, 520, src)
		navigation_windows[user] = popup
		RegisterSignals(user, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(close_navigation))
	var/html = file2text('modular_bandastation/underwater_submarine/html/navigation.html')
	html = replacetext(html, "@CONSOLE@", REF(src))
	html = replacetext(html, "@STATE@", replacetext(json_encode(ui_data(user)), "<", "\\u003c"))
	popup.set_head_content("")
	popup.set_content(html)
	popup.open()

/obj/machinery/computer/stationtrauma_navigation/ui_data(mob/user)
	if(!vessel)
		return list()
	var/list/routes = list()
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in vessel.berths)
		if(berth != (vessel.fixed_location || vessel.get_docked()))
			routes += list(list("name" = berth.name, "distance" = vessel.distance_to(berth)))
	for(var/destination in vessel.unloaded_destinations)
		routes += list(list("name" = destination, "distance" = vessel.distance_to(destination)))
	var/progress = vessel.path_progress()
	return list("status" = vessel.voyage_status, "travelling" = vessel.travelling, "target" = vessel.voyage_target, "progress" = progress, "distance" = vessel.voyage_distance, "travelled" = round(vessel.voyage_distance * progress, 1), "routes" = routes, "passage" = vessel.fixed_location ? "К локации плывите на север от лодки. Обратно — на юг от локации. В рейсе проход отключён." : "")

/** Closing, leaving the console and disconnecting release the browser and its user signals. */
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
	// The native copy can briefly put the passenger and console on different decks; keep read-only progress visible.
	if(href_list["refresh"] && !href_list["travel"] && popup && vessel?.travelling && SSfloodwater.relocating_turfs.len)
		usr << output(url_encode(json_encode(ui_data(usr))), "[popup.window_id].browser:updateVoyage")
		return
	if(..())
		close_navigation(usr)
		return
	if(!popup || !vessel)
		return
	if(href_list["travel"] && !vessel.travelling)
		var/destination = href_list["travel"]
		if(!isnull(vessel.distance_to(destination)))
			INVOKE_ASYNC(vessel, TYPE_PROC_REF(/obj/docking_port/mobile/stationtrauma, travel_to), destination)
	usr << output(url_encode(json_encode(ui_data(usr))), "[popup.window_id].browser:updateVoyage")

/obj/machinery/computer/stationtrauma_navigation/Destroy()
	for(var/mob/viewer as anything in navigation_windows.Copy())
		close_navigation(viewer)
	return ..()
