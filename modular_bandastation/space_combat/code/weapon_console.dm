/** A local gunnery station on the same hull as its physical mounts. */
/obj/machinery/computer/stationtrauma_weapon_console
	name = "оружейная консоль"
	desc = "Карта сектора и ручное наведение корабельных орудий."
	icon = 'modular_bandastation/space_combat/icons/patrol_consoles.dmi'
	icon_state = MAP_SWITCH("computer", "gunnery_map")
	generate_map_preview = FALSE
	icon_screen = "gunnery"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_weapon_console
	/// Physical hull supplying the chart and weapon roster.
	var/datum/weakref/vessel_ref

/obj/item/circuitboard/computer/stationtrauma_weapon_console
	name = "оружейная консоль"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/stationtrauma_weapon_console

/obj/machinery/computer/stationtrauma_weapon_console/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/computer/stationtrauma_weapon_console/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	vessel_ref = null
	if(istype(port, /obj/docking_port/mobile/stationtrauma_space) && port.is_in_shuttle_bounds(src))
		vessel_ref = WEAKREF(port)

/obj/machinery/computer/stationtrauma_weapon_console/Destroy()
	vessel_ref = null
	return ..()

/obj/machinery/computer/stationtrauma_weapon_console/proc/current_vessel()
	var/obj/docking_port/mobile/stationtrauma_space/vessel = vessel_ref?.resolve()
	if(!QDELETED(vessel?.overmap) && vessel.is_in_shuttle_bounds(src) && vessel.shuttle_areas[get_area(src)])
		return vessel
	return null

/obj/machinery/computer/stationtrauma_weapon_console/proc/can_control_weapons(mob/user)
	return !QDELETED(src) && !QDELETED(user) && isliving(user) && Adjacent(user) && can_interact(user) \
		&& anchored && !panel_open && !(machine_stat & (NOPOWER|BROKEN|MAINT))

/obj/machinery/computer/stationtrauma_weapon_console/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "ShipWeapons")

/obj/machinery/computer/stationtrauma_weapon_console/ui_status(mob/user, datum/ui_state/state)
	if(!current_vessel())
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_weapon_console/ui_data(mob/user)
	var/obj/docking_port/mobile/stationtrauma_space/vessel = current_vessel()
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(QDELETED(map))
		return list()
	var/list/data = map.navigation_chart_data()
	var/can_control = can_control_weapons(user)
	data["can_control"] = can_control
	data["power_ready"] = vessel.combat_power_managed || available_energy() >= ST_AUTOCANNON_SHOT_ENERGY
	data["scan_ready"] = can_control && !map.preparing && !map.relocating && !map.jump_target && world.time >= map.next_scan
	var/list/weapons = list()
	for(var/obj/machinery/stationtrauma_autocannon/gun as anything in vessel.ship_autocannons)
		var/obj/machinery/stationtrauma_autocannon_loader/loader = gun.interior_loader()
		weapons += list(list(
			"id" = REF(gun),
			"name" = gun.name,
			"shells" = gun.shells,
			"capacity" = gun.feed_capacity,
			"loader" = loader ? list(
				"shells" = loader.reserve_shells,
				"capacity" = loader.reserve_capacity,
				"online" = loader.feeder_available(gun),
			) : null,
			"status" = gun.readiness(map),
			"reload" = COOLDOWN_TIMELEFT(gun, burst_cooldown) / (1 SECONDS),
			"reload_duration" = gun.reload_time / (1 SECONDS),
			"heading" = gun.firing_heading(map),
			"arc" = ST_AUTOCANNON_ARC,
			"range" = ST_AUTOCANNON_RANGE,
			"min_range" = map.kinetic_launch_offset(),
		))
	data["weapons"] = weapons
	return data

/obj/machinery/computer/stationtrauma_weapon_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!can_control_weapons(ui.user) || ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/vessel = current_vessel()
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(QDELETED(map))
		return FALSE
	switch(action)
		if("scan")
			map.advance()
			if(map.jump_target || !map.scan_sector())
				return FALSE
			playsound(src, 'sound/machines/radar-ping.ogg', 50, FALSE)
			return TRUE
		if("fire")
			var/mount = params["weapon"]
			var/aim_x = params["x"]
			var/aim_y = params["y"]
			if(!istext(mount) || !IS_FINITE(aim_x) || !IS_FINITE(aim_y) || (!vessel.combat_power_managed && available_energy() < ST_AUTOCANNON_SHOT_ENERGY))
				return FALSE
			var/obj/machinery/stationtrauma_autocannon/gun = locate(mount) in vessel.ship_autocannons
			if(QDELETED(gun))
				return FALSE
			if(gun.start_burst(src, ui.user, map, aim_x, aim_y))
				return TRUE
			balloon_alert(ui.user, "выстрел недоступен")
	return FALSE

/** Nearby acquired contacts remain on the radar while the ship can power fire control. */
/datum/stationtrauma_overmap/space/proc/fire_control_sensor_range()
	return length(vessel.ship_autocannons) && vessel.has_power() ? min(sensor_range, ST_AUTOCANNON_RANGE) : 0

/** A ship still in sector space can be tracked while it prepares to dock or land. */
/datum/stationtrauma_overmap/space/sensor_observable()
	return ..() || kinetic_exposed()
