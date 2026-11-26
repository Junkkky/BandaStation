/** Navigation and helm console. */
/obj/machinery/computer/stationtrauma_space_navigation
	name = "навигационная консоль"
	desc = "Орбитальная карта, управление тягой и стыковкой корабля."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/shuttle")
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/computer/stationtrauma_space_navigation
	/// Physical hull controlled by this navigation instance or console.
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	/// Site looked up on the chart while the autopilot flies elsewhere; the autopilot takes it as its destination when engaged again
	var/inspected_site

/** Circuit board kept when the helm console is dismantled or wrecked. */
/obj/item/circuitboard/computer/stationtrauma_space_navigation
	name = "навигационная консоль"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/stationtrauma_space_navigation

/datum/design/board/shuttle/stationtrauma_space_navigation
	name = "Плата навигационной консоли"
	desc = "Плата консоли, управляющей полётом корабля, в котором она установлена."
	build_path = /obj/item/circuitboard/computer/stationtrauma_space_navigation

/datum/techweb_node/shuttle_engineering/New()
	. = ..()
	unlocked_designs += list(
		/datum/design/board/shuttle/stationtrauma_space_navigation,
		/datum/design/board/stationtrauma_bluespace_drive,
		/datum/design/board/stationtrauma_engine,
		/datum/design/board/stationtrauma_engine/left,
		/datum/design/board/stationtrauma_engine/right,
		/datum/design/board/stationtrauma_engine/burst,
		/datum/design/board/stationtrauma_engine/burst_left,
		/datum/design/board/stationtrauma_engine/burst_right,
		/datum/design/board/stationtrauma_engine/huge,
		/datum/design/board/stationtrauma_large_engine,
		/datum/design/board/stationtrauma_large_converter,
		/datum/design/board/stationtrauma_ship_generator,
		/datum/design/board/stationtrauma_plasma_core,
		/datum/design/board/stationtrauma_plasma_converter,
		/datum/design/board/stationtrauma_compact_core,
	)

/obj/machinery/computer/stationtrauma_space_navigation/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/// A console rebuilt aboard takes over the helm of the hull it stands in.
/obj/machinery/computer/stationtrauma_space_navigation/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/ship = port
	if(istype(ship) && ship.is_in_shuttle_bounds(src))
		vessel = ship

/obj/machinery/computer/stationtrauma_space_navigation/Destroy()
	vessel = null
	return ..()

/obj/machinery/computer/stationtrauma_space_navigation/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "SpaceNavigation")

/obj/machinery/computer/stationtrauma_space_navigation/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(vessel?.overmap) || (!isobserver(user) && !can_interact(user)))
		return UI_CLOSE
	if(state == GLOB.relay_board_state && istype(user, /mob/living/basic/relay_operator))
		return ..()
	return overmap_console_status(user, ..())

/** The ship's sensor chart, shared by the helm and fire-control stations. */
/datum/stationtrauma_overmap/space/proc/navigation_chart_data()
	var/datum/stationtrauma_overmap_sector/space/chart_sector = sector
	return list(
		"vessel_name" = vessel.name,
		"au_scale" = ST_SPACE_AU_SCALE,
		"sector" = chart_sector?.id, "sector_name" = chart_sector?.name,
		"star" = list("x" = 0, "y" = 0, "name" = chart_sector?.star_name, "radius" = chart_sector?.star_radius || 10),
		"celestial_bodies" = chart_sector?.celestial_bodies,
		"x" = pos_x, "y" = pos_y,
		"vx" = velocity_x, "vy" = velocity_y, "trajectory" = predict_trajectory(),
		"course" = course,
		"preparing" = preparing, "relocating" = relocating,
		"routes" = known_sites(helm = TRUE), "path" = autopilot_path,
		"zones" = encounter_data(), "terrain" = terrain_data(),
		"ship_contacts" = ship_echo_data(),
		"kinetic_shots" = kinetic_echo_data(),
		"drop_pods" = drop_pod_echo_data(),
		"impact_waves" = kinetic_impact_data(),
		"shield_up" = vessel.combat_shield_active(),
		"sensor_range" = sensor_range, "dock_range" = ST_SPACE_DOCK_RANGE, "jump_point_range" = ST_JUMP_POINT_RANGE,
		"interference" = round(interference, 0.05),
		"scan_age" = isnull(last_ping) ? null : (world.time - last_ping) / (1 SECONDS),
	)

/obj/machinery/computer/stationtrauma_space_navigation/ui_data(mob/user)
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(!map)
		return list()
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = vessel.fusion_core?.resolve()
	var/engine_fraction = map.engine_fraction()
	var/hardware_fraction = map.engine_fraction(regulated = FALSE)
	var/engine_fault = reactor ? reactor.tripped : hardware_fraction <= 0
	if(reactor?.output && !engine_fault)
		engine_fault = hardware_fraction <= 0 || vessel.current_engine_power < vessel.initial_engine_power
		for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list)
			if(engine_fault)
				break
			if(!engine.requires_combustion)
				continue
			var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
			engine_fault = !feed || !!feed.unavailable_reason()
	var/datum/stationtrauma_overmap_site/space/target = map.sites[map.selected_destination]
	if(!map.knows_site(target))
		target = null
	var/datum/stationtrauma_overmap_site/space/dock_target = map.selected_docking_site()
	var/distance = target ? map.distance_to(target) : 0
	var/datum/stationtrauma_ship_docking/boarding/capture = map.ship_docking
	if(!istype(capture))
		capture = null
	var/list/data = map.navigation_chart_data()
	data += list(
		"status" = map.status,
		"jumping" = !!map.jump_target,
		"ordered_course" = map.ordered_course,
		"speed" = map.speed, "throttle" = map.approach_started ? round(100 * map.commanded_thrust()) * vessel.engines_running : map.throttle, "speed_scale" = ST_SPACE_MAX_SPEED,
		"maneuver_direction" = map.maneuver_direction,
		"braking" = map.braking, "braking_distance" = map.get_braking_distance(),
		"emergency_braking" = map.emergency_braking && vessel.has_power(),
		"ship_power" = vessel.has_power(),
		"engines" = round(engine_fraction * 100),
		"engines_running" = vessel.engines_running,
		"core_overdrive" = !!reactor?.overdrive_active(),
		"afterburner" = !!reactor?.overdrive,
		"can_afterburner" = !!reactor && reactor.active && !reactor.tripped,
		"core_heat" = reactor ? round(reactor.heat) : null,
		"fuel" = vessel.fuel_gauges(),
		"engine_fault" = engine_fault,
		"can_start_engines" = engine_fraction > 0,
		"helm" = map.helm_engaged, "autopilot" = map.autopilot,
		"planning" = map.planning,
		"landed" = !!map.docked?.landing,
		"selected" = target?.docking_target?.id || target?.id, "docked" = map.docked?.docking_target?.id || map.docked?.pad_parent?.id || map.docked?.id,
		"coupled" = !!map.ship_docking,
		"docking_request" = map.ship_docking_request_data(),
		"station_docking" = map.station_docking_data(target),
		"can_request_ship_dock" = map.available_for_ship_docking(),
		"dockable_contacts" = map.dockable_ship_contacts(),
		"boardable_contacts" = map.boardable_contacts(),
		"can_board_site" = istype(target, /datum/stationtrauma_overmap_site/space/docking_target) && !target.host ? !!map.station_boarding_berth(target) : null,
		"boarding" = map.boarding_attempt?.display_data(map),
		"boarding_connected" = !!capture,
		"boarding_release_ready" = capture?.can_start_release(map),
		"boarding_release_eta" = capture?.release_helm ? max(0, capture.release_at - world.time) / (1 SECONDS) : null,
		"can_cancel_release" = capture && !capture.closing && capture.release_helm == map,
		"landing" = target?.landing, "distance" = distance,
		"eta" = target && map.get_target_speed() > 0 ? max(0, distance - map.radius - target.radius) / map.get_target_speed() : null,
		"scan_ready" = !map.preparing && !map.relocating && map.is_operational() && world.time >= map.next_scan && !panel_open && !(machine_stat & (NOPOWER|BROKEN)),
		"can_dock" = !map.preparing && !map.docked && !map.helm_engaged && map.speed <= ST_NAV_STOPPED_SPEED \
			&& (!map.station_clearance_required(dock_target) || map.has_station_clearance(dock_target)) && map.can_dock(dock_target, map.control_revision),
		"encounter" = map.encounter_status,
		"approach" = null,
	)
	var/list/hull = vessel.compartment_report()
	data["compartments"] = hull["rooms"]
	data["hull"] = hull["rows"]
	var/datum/stationtrauma_overmap_site/space/approach_site = map.approach_site
	var/datum/stationtrauma_ship_docking/pair = map.ship_docking
	var/datum/stationtrauma_overmap/space/peer = pair ? (pair.first == map ? pair.second : pair.first) : null
	if(map.approach_started && (!QDELETED(approach_site) || !QDELETED(peer)))
		var/datum/stationtrauma_overmap_site/space/planet/approach_planet = approach_site?.pad_parent || approach_site
		data["approach"] = list(
			"elapsed" = (world.time - map.approach_started) / (1 SECONDS),
			"duration" = map.approach_duration / (1 SECONDS),
			"departing" = map.approach_departing,
			"site" = !QDELETED(approach_site) ? map.site_label(approach_site) : peer.vessel?.name || "Корабль",
			"scene" = istype(approach_planet) ? "planet" : approach_site?.approach_scene || "station",
			"biome" = istype(approach_planet) ? approach_planet.ruin_biome : null,
			"loading" = !!(approach_site?.loading_map || (istype(approach_planet) && approach_planet.loading_map)),
		)
		if(istype(approach_planet) && map.planet_flight)
			var/touchdown = map.planet_flight.descent?.touchdown_time
			var/liftoff = map.planet_ascent?.liftoff
			data["approach"]["planet_timing"] = list(
				"orbit_duration" = map.planet_flight.orbit_duration / (1 SECONDS),
				"descent_start" = touchdown ? (touchdown - ST_PLANET_DESCENT_TIME - map.approach_started) / (1 SECONDS) : null,
				"entry_start" = touchdown ? (touchdown - LANDING_ENTRY_LEAD - map.approach_started) / (1 SECONDS) : null,
				"entry_end" = touchdown ? (touchdown - LANDING_ENTRY_END - map.approach_started) / (1 SECONDS) : null,
				"liftoff" = liftoff ? (liftoff - map.approach_started) / (1 SECONDS) : null,
				"ascent_cloud" = liftoff ? (liftoff + ST_PLANET_ASCENT_CLOUD - map.approach_started) / (1 SECONDS) : null,
				"ascent_orbit" = liftoff ? (liftoff + ST_PLANET_ASCENT_ORBIT - map.approach_started) / (1 SECONDS) : null,
			)
	// A planet is unknown ground until this ship's probes have covered it; its pads appear once it is mapped.
	data["planet"] = null
	data["planet_look"] = null
	var/datum/stationtrauma_overmap_site/space/planet/planet = target
	if(istype(planet))
		var/datum/stationtrauma_planet_survey/survey = map.planet_survey(planet)
		data["survey"] = list(
			"covered" = !!survey?.covered_at,
			"mapping" = survey ? survey.mapping_progress() : 0,
			"mapped" = !!survey?.mapped(),
			"failed" = !!planet.failed,
			"pads" = map.landing_pad_data(planet),
		)
	// the scanner reads out the site looked up, else the destination; fields are sent even empty, as one left out would keep the last site's
	var/datum/stationtrauma_overmap_site/space/inspected = inspected_site && map.autopilot ? map.sites[inspected_site] : null
	if(inspected && !map.knows_site(inspected))
		inspected = null
	data["inspected"] = inspected?.docking_target?.id || inspected?.id
	var/datum/stationtrauma_overmap_site/space/planet/read_planet = inspected || target
	if(istype(read_planet))
		var/datum/stationtrauma_planet_survey/survey = map.planet_survey(read_planet)
		var/list/facts = survey?.facts()
		data["planet"] = length(facts) ? facts : null
		data["planet_look"] = read_planet.orbit_look
	data["jump_progress"] = map.jump_progress()
	return data

/** Validate and dispatch a helm command. */
/obj/machinery/computer/stationtrauma_space_navigation/proc/navigation_command(action, value)
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(!map || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	// The pilot may relinquish clearance until the physical move consumes it.
	if(action == "cancel_station_dock")
		return istext(value) && value == map.selected_destination && map.cancel_station_docking()
	if(map.relocating || map.approach_started)
		return FALSE
	if(map.jump_target && action != "stop")
		return FALSE
	map.advance()
	switch(action)
		if("board_ship")
			return map.request_boarding(value)
		if("board_site")
			return map.request_station_boarding(value)
		if("cancel_boarding")
			if(map.boarding_attempt?.attacker != map || map.preparing)
				return FALSE
			qdel(map.boarding_attempt)
			return TRUE
		if("release_boarding")
			var/datum/stationtrauma_ship_docking/boarding/boarding_link = map.ship_docking
			if(!istype(boarding_link) || !boarding_link.can_start_release(map))
				return FALSE
			INVOKE_ASYNC(boarding_link, TYPE_PROC_REF(/datum/stationtrauma_ship_docking, release), map)
			return TRUE
		if("cancel_boarding_release")
			var/datum/stationtrauma_ship_docking/boarding/boarding_link = map.ship_docking
			return istype(boarding_link) && boarding_link.cancel_release(map)
		if("ship_dock")
			return map.request_ship_docking(value)
		if("accept_ship_dock", "decline_ship_dock")
			return map.respond_ship_docking(value, action == "accept_ship_dock")
		if("request_station_dock")
			return istext(value) && value == map.selected_destination && map.request_station_docking(value)
		if("engine")
			if(!(value in list(0, 1)))
				return FALSE
			return map.set_engines_running(value == 1)
		if("afterburner")
			var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = vessel.fusion_core?.resolve()
			return reactor?.toggle_overdrive()
		if("maneuver")
			var/direction = value
			return IS_FINITE(direction) && map.command_maneuver(direction)
		if("scan")
			if(!map.scan_sector())
				return FALSE
			playsound(src, 'sound/machines/radar-ping.ogg', 50, FALSE)
			return TRUE
		if("stop")
			map.request_brake()
		if("emergency_brake")
			return map.command_emergency_brake()
		if("select")
			if(!istext(value))
				return FALSE
			var/datum/stationtrauma_overmap_site/space/site = map.sites[value]
			if(!istype(site, /datum/stationtrauma_overmap_site/space/docking_target) && map.station_clearance_required(site))
				return FALSE
			// looking a site up must not throw the autopilot off its course: the next autopilot order takes it as the destination
			if(map.autopilot && value != map.selected_destination)
				if(!map.knows_site(site))
					return FALSE
				inspected_site = value
				return TRUE
			inspected_site = null
			return map.select_site(value)
		if("turn", "throttle")
			var/number = value
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
			if(map.preparing || map.ship_docking || map.planning || map.throttle <= 0 || map.docked?.id == map.selected_destination || map.docked?.docking_target?.id == map.selected_destination || map.docked?.pad_parent?.id == map.selected_destination)
				return FALSE
			if(inspected_site)
				var/next = inspected_site
				inspected_site = null
				if(!map.select_site(next))
					return FALSE
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap, engage_autopilot))
		if("dock")
			if(!isnull(value) && (!istext(value) || value != map.selected_destination))
				return FALSE
			var/datum/stationtrauma_overmap_site/space/target = map.sites[map.selected_destination]
			if(map.station_clearance_required(target) && (isnull(value) || !map.assigned_station_berth(target)))
				return FALSE
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, dock))
		if("landing_pad")
			return map.choose_landing_pad(value)
		else
			return FALSE
	return TRUE

/** TGUI permissions and machine interaction checks precede every helm command. */
/obj/machinery/computer/stationtrauma_space_navigation/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!can_interact(ui.user))
		return FALSE
	if(action == "interface_click")
		return TRUE
	return navigation_command(action, params["value"])

/** Navigation buttons use the supplied tone; the throttle lever keeps the native mechanical click. */
/obj/machinery/computer/stationtrauma_space_navigation/play_ui_sound(action, list/params)
	if(action == "throttle" && params?["button"] != TRUE)
		return ..()
	playsound(src, 'modular_bandastation/space_overmap/sound/navigation_button.wav', ST_CONSOLE_BUTTON_VOLUME, FALSE, FALSE)
