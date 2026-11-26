/obj/machinery/computer/stationtrauma_drop_pod_console
	name = "консоль запуска дроп-подов"
	desc = "Управляет сборкой капсул в отсеке ВКД и высадкой на корабли, станции и торговые узлы."
	icon = 'modular_bandastation/space_combat/icons/patrol_consoles.dmi'
	icon_state = MAP_SWITCH("computer", "descent_map")
	icon_screen = "descent"
	icon_keyboard = "tech_key"
	generate_map_preview = FALSE
	circuit = /obj/item/circuitboard/computer/stationtrauma_drop_pod_console
	var/datum/weakref/vessel_ref

/obj/item/circuitboard/computer/stationtrauma_drop_pod_console
	name = "консоль запуска дроп-подов"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/stationtrauma_drop_pod_console

/obj/machinery/computer/stationtrauma_drop_pod_console/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/computer/stationtrauma_drop_pod_console/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	vessel_ref = null
	if(istype(port, /obj/docking_port/mobile/stationtrauma_space) && port.is_in_shuttle_bounds(src))
		vessel_ref = WEAKREF(port)

/obj/machinery/computer/stationtrauma_drop_pod_console/proc/current_vessel()
	var/obj/docking_port/mobile/stationtrauma_space/vessel = vessel_ref?.resolve()
	if(!QDELETED(vessel?.overmap) && vessel.is_in_shuttle_bounds(src) && vessel.shuttle_areas[get_area(src)])
		return vessel

/obj/machinery/computer/stationtrauma_drop_pod_console/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "ShipDropPods")

/obj/machinery/computer/stationtrauma_drop_pod_console/ui_status(mob/user, datum/ui_state/state)
	if(!current_vessel())
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_drop_pod_console/ui_data(mob/user)
	var/obj/docking_port/mobile/stationtrauma_space/vessel = current_vessel()
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(QDELETED(map))
		return list()
	var/list/data = map.navigation_chart_data()
	data["launch_ready"] = map.kinetic_flight_ready()
	data["launch_range"] = ST_DROP_POD_RANGE
	var/list/drop_sites = list()
	var/datum/stationtrauma_overmap_sector/space/sector = map.sector
	for(var/datum/stationtrauma_overmap_site/space/docking_target/site as anything in sector?.fixed_combat_sites)
		if(map.knows_site(site) && site.combat_berth(sector))
			drop_sites += site.id
	data["drop_sites"] = drop_sites
	data["scan_ready"] = map.kinetic_flight_ready() && world.time >= map.next_scan
	data["iron_cost"] = ST_DROP_POD_IRON_COST
	var/list/launchers = list()
	for(var/obj/machinery/stationtrauma_drop_launcher/launcher as anything in vessel.drop_launchers)
		if(!launcher.is_mounted(vessel))
			continue
		var/obj/structure/closet/stationtrauma_drop_pod/pod = launcher.mounted_pod()
		var/passengers = 0
		for(var/mob/living/passenger in pod)
			passengers++
		launchers += list(list(
			"id" = REF(launcher),
			"number" = launcher.launcher_number,
			"iron" = launcher.iron,
			"operational" = launcher.can_operate(),
			"can_assemble" = launcher.can_assemble(),
			"assembly_seconds" = launcher.assembly_seconds_left(),
			"has_pod" = !!pod,
			"open" = pod?.opened,
			"passengers" = passengers,
			"loaded" = !!length(pod?.contents),
		))
	data["launchers"] = launchers
	var/list/reports = list()
	for(var/datum/stationtrauma_drop_flight/flight as anything in vessel.drop_pod_reports)
		reports += list(list("id" = REF(flight), "name" = flight.capsule_name, "target" = flight.contact_name, "section" = flight.section, "result" = flight.result, "eta" = max(0, flight.arrives_at - world.time) / (1 SECONDS)))
	data["flights"] = reports
	return data

/obj/machinery/computer/stationtrauma_drop_pod_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!isliving(ui.user) || !Adjacent(ui.user) || !can_interact(ui.user) || !anchored || panel_open || !is_operational || ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/vessel = current_vessel()
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(QDELETED(map))
		return FALSE
	switch(action)
		if("scan")
			map.advance()
			if(map.kinetic_flight_ready() && map.scan_sector())
				playsound(src, 'sound/machines/radar-ping.ogg', 50, FALSE)
				return TRUE
		if("assemble", "launch")
			var/launcher_id = params["launcher"]
			if(!istext(launcher_id))
				return FALSE
			var/obj/machinery/stationtrauma_drop_launcher/launcher = locate(launcher_id) in vessel.drop_launchers
			if(QDELETED(launcher) || !launcher.is_mounted(vessel) || !launcher.can_operate())
				return FALSE
			if(action == "assemble")
				if(launcher.assemble_pod())
					return TRUE
				balloon_alert(ui.user, "установка не готова к сборке")
				return FALSE
			var/section = params["section"]
			var/contact = params["contact"]
			if(!map.kinetic_flight_ready())
				return FALSE
			var/obj/structure/closet/stationtrauma_drop_pod/pod = launcher.mounted_pod()
			if(QDELETED(pod) || pod.opened || !length(pod.contents))
				balloon_alert(ui.user, "загрузите капсулу и закройте люк")
				return FALSE
			if(launch_pod(map, pod, contact, section, ui.user))
				launcher.pod_ref = null
				return TRUE
			balloon_alert(ui.user, "цель вне досягаемости или потеряна")
	return FALSE

/obj/machinery/computer/stationtrauma_drop_pod_console/proc/launch_pod(datum/stationtrauma_overmap/space/source, obj/structure/closet/stationtrauma_drop_pod/pod, contact, section, mob/user)
	var/datum/stationtrauma_overmap_sector/space/here = source.sector
	var/datum/stationtrauma_overmap/space/target
	var/datum/stationtrauma_overmap_site/space/docking_target/site
	var/contact_label
	var/target_x
	var/target_y
	if(istext(contact))
		site = here.sites[contact]
		if(!istype(site) || section != "site" || !source.knows_site(site) || !site.combat_berth(here))
			return FALSE
		contact_label = site.name
		target_x = site.pos_x
		target_y = site.pos_y
	else
		if(!ISINTEGER(contact) || !(section in list("bow", "midship", "stern")))
			return FALSE
		for(var/id in source.ship_observations)
			var/list/record = source.ship_observations[id]
			if(record["id"] == contact && source.ship_sensor_observation(id))
				target = here.ships[id]
				contact_label = record["identity"]?["callsign"] || "Контакт [contact]"
				break
		if(QDELETED(target) || target == source || !target.kinetic_exposed())
			return FALSE
		target_x = target.pos_x
		target_y = target.pos_y
	if((target_x - source.pos_x) ** 2 + (target_y - source.pos_y) ** 2 > ST_DROP_POD_RANGE ** 2)
		return FALSE
	var/area/holding = GLOB.areas_by_type[/area/centcom/central_command_areas/supplypod/supplypod_temp_holding]
	var/turf/open/transit = locate(/turf/open) in holding
	if(!transit)
		return FALSE
	playsound(get_turf(pod), 'sound/effects/bang.ogg', 55, TRUE)
	pod.launched = TRUE
	pod.resistance_flags |= INDESTRUCTIBLE
	pod.flight = new(pod, source, target, contact_label, section, site)
	pod.forceMove(transit)
	pod.refresh_passenger_views()
	user.log_message("launched a drop pod at [contact_label] ([section])", LOG_GAME)
	for(var/mob/living/passenger in pod)
		to_chat(passenger, span_notice("Дроп-под в полёте. Люк заблокирован до посадки."))
	return TRUE
