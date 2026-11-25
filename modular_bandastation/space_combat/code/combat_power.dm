/** Shipboard distributor, fed by the equipment grid after the SMES. */
/obj/machinery/stationtrauma_combat_power
	name = "распределитель боевого питания"
	desc = "Распределяет мощность бортовой сети между щитом, маршевыми двигателями и накопителями орудий."
	icon = 'modular_bandastation/space_combat/icons/patrol_machines.dmi'
	icon_state = "distributor"
	anchored = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	/// Physical hull supplied by this distributor.
	var/datum/weakref/vessel_ref
	var/shield_share = 30
	var/engine_share = 40
	var/weapon_share = 30
	/// Revision prevents a stale console draft from overwriting a second operator's changes.
	var/allocation_revision = 0
	/// Thrust ceiling paid for by the drive regulators in the last power interval.
	var/engine_limit = 0
	var/available_watts = 0
	var/shield_watts = 0
	var/engine_watts = 0
	var/weapon_watts = 0

/obj/docking_port/mobile/stationtrauma_space
	/// Equipped hulls retain their managed power circuit even if the distributor is destroyed.
	var/combat_power_managed = FALSE
	var/datum/weakref/combat_power_ref
	var/datum/weakref/combat_shield_ref

/obj/machinery/stationtrauma_combat_power/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/stationtrauma_combat_power/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(ship?.combat_power_ref?.resolve() == src)
		ship.combat_power_ref = null
		var/obj/machinery/stationtrauma_ship_shield/old_shield = ship.combat_shield_ref?.resolve()
		old_shield?.update_appearance(UPDATE_ICON_STATE)
	vessel_ref = null
	if(!istype(port, /obj/docking_port/mobile/stationtrauma_space))
		return
	ship = port
	if(ship.is_in_shuttle_bounds(src) && ship.shuttle_areas[get_area(src)] && !ship.combat_power_ref?.resolve())
		ship.combat_power_managed = TRUE
		ship.combat_power_ref = WEAKREF(src)
		vessel_ref = WEAKREF(ship)
		var/obj/machinery/stationtrauma_ship_shield/new_shield = ship.combat_shield_ref?.resolve()
		new_shield?.update_appearance(UPDATE_ICON_STATE)

/obj/machinery/stationtrauma_combat_power/Destroy()
	connect_to_shuttle(FALSE, null)
	return ..()

/obj/machinery/stationtrauma_combat_power/proc/can_route(obj/docking_port/mobile/stationtrauma_space/ship)
	if(QDELETED(ship) || !anchored || panel_open || !is_operational || vessel_ref?.resolve() != ship || !ship.is_in_shuttle_bounds(src) || !ship.shuttle_areas[get_area(src)])
		return FALSE
	var/area/home = get_area(src)
	return home.apc?.operating && !!home.apc.terminal?.powernet

/** Apply an entire allocation as one operation. A circuit can be set to zero. */
/obj/machinery/stationtrauma_combat_power/proc/set_allocation(shields, engines, weapons, revision)
	if(!IS_FINITE(shields) || !IS_FINITE(engines) || !IS_FINITE(weapons) || !IS_FINITE(revision) || revision != allocation_revision)
		return FALSE
	if(shields < 0 || engines < 0 || weapons < 0 || shields + engines + weapons != 100)
		return FALSE
	if(shields != round(shields) || engines != round(engines) || weapons != round(weapons))
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	ship?.overmap?.advance()
	shield_share = shields
	engine_share = engines
	weapon_share = weapons
	allocation_revision++
	engine_limit = min(engine_limit, available_watts * engine_share / 100 / ST_COMBAT_ENGINE_POWER)
	var/obj/machinery/stationtrauma_ship_shield/shield = ship?.combat_shield_ref?.resolve()
	if(shield && available_watts * shields / 100 < ST_SHIP_SHIELD_HOLD_POWER)
		shield.set_raised(FALSE)
	return TRUE

/obj/machinery/stationtrauma_combat_power/process(seconds_per_tick)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	var/obj/machinery/stationtrauma_ship_shield/shield = ship?.combat_shield_ref?.resolve()
	available_watts = shield_watts = engine_watts = weapon_watts = 0
	if(seconds_per_tick <= 0 || !can_route(ship))
		engine_limit = 0
		shield?.receive_power(0, seconds_per_tick)
		return

	var/budget = min(ST_COMBAT_BUS_POWER * seconds_per_tick, available_energy(consider_cell = FALSE))
	var/shield_energy = min(budget * shield_share / 100, shield?.power_demand(ship, seconds_per_tick) || 0)
	var/engine_capacity = min(budget * engine_share / 100, ST_COMBAT_ENGINE_POWER * seconds_per_tick)
	// Switched-on drive regulators draw their electrical share even when the throttle is idle.
	var/engine_demand = ship.engines_running ? (ship.overmap?.engine_fraction(regulated = FALSE) || 0) : 0
	var/engine_energy = engine_capacity * engine_demand
	var/weapon_demand = 0
	for(var/obj/machinery/stationtrauma_autocannon/gun as anything in ship.ship_autocannons)
		weapon_demand += gun.charge_demand(ship)
	var/weapon_energy = min(budget * weapon_share / 100, weapon_demand)
	var/requested = shield_energy + engine_energy + weapon_energy
	var/delivered = requested ? use_energy(requested, ignore_apc = TRUE) / requested : 1

	engine_limit = engine_energy > 0 ? engine_capacity * delivered / (ST_COMBAT_ENGINE_POWER * seconds_per_tick) : 0
	available_watts = budget / seconds_per_tick
	engine_watts = engine_energy * delivered / seconds_per_tick
	shield_watts = shield_energy * delivered / seconds_per_tick
	weapon_watts = weapon_energy * delivered / seconds_per_tick
	shield?.receive_power(shield_energy * delivered, seconds_per_tick)
	if(weapon_energy > 0 && delivered > 0)
		for(var/obj/machinery/stationtrauma_autocannon/gun as anything in ship.ship_autocannons)
			gun.capacitor_charge += gun.charge_demand(ship) * weapon_energy * delivered / weapon_demand

/obj/docking_port/mobile/stationtrauma_space/proc/combat_engine_limit(available = FALSE)
	if(!combat_power_managed)
		return 1
	var/obj/machinery/stationtrauma_combat_power/distributor = combat_power_ref?.resolve()
	if(!distributor?.can_route(src))
		return 0
	if(available)
		return min(1, distributor.available_watts * distributor.engine_share / 100 / ST_COMBAT_ENGINE_POWER)
	return distributor.engine_limit

/obj/docking_port/mobile/stationtrauma_space/proc/combat_shield_active()
	var/obj/machinery/stationtrauma_ship_shield/shield = combat_shield_ref?.resolve()
	var/obj/machinery/stationtrauma_combat_power/distributor = combat_power_ref?.resolve()
	return shield?.raised && shield.can_project(src) && distributor?.can_route(src)

/** A console changes priorities, while the separate distributor continues to operate on its own. */
/obj/machinery/computer/stationtrauma_combat_power_console
	name = "консоль боевого питания"
	desc = "Выставляет доли питания щита, маршевых двигателей и орудий."
	icon = 'modular_bandastation/space_combat/icons/patrol_consoles.dmi'
	icon_state = MAP_SWITCH("computer", "power_map")
	icon_screen = "power"
	icon_keyboard = "tech_key"
	generate_map_preview = FALSE
	circuit = /obj/item/circuitboard/computer/stationtrauma_combat_power

/obj/item/circuitboard/computer/stationtrauma_combat_power
	name = "консоль боевого питания"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/computer/stationtrauma_combat_power_console

/obj/machinery/computer/stationtrauma_combat_power_console/proc/distributor()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	if(istype(ship) && ship.shuttle_areas[get_area(src)])
		return ship.combat_power_ref?.resolve()

/obj/machinery/computer/stationtrauma_combat_power_console/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "ShipCombatPower")

/obj/machinery/computer/stationtrauma_combat_power_console/ui_status(mob/user, datum/ui_state/state)
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_combat_power_console/ui_data(mob/user)
	var/obj/machinery/stationtrauma_combat_power/bus = distributor()
	if(QDELETED(bus))
		return list("missing" = TRUE)
	var/obj/docking_port/mobile/stationtrauma_space/ship = bus.vessel_ref?.resolve()
	var/obj/machinery/stationtrauma_ship_shield/shield = ship?.combat_shield_ref?.resolve()
	var/gun_charge = 0
	var/gun_capacity = 0
	for(var/obj/machinery/stationtrauma_autocannon/gun as anything in ship?.ship_autocannons)
		if(gun.is_mounted(ship))
			gun_charge += gun.capacitor_charge
			gun_capacity += ST_AUTOCANNON_CAPACITY
	var/online = bus.can_route(ship)
	return list(
		"vessel" = ship?.name,
		"online" = online,
		"revision" = bus.allocation_revision,
		"shares" = list("shields" = bus.shield_share, "engines" = bus.engine_share, "weapons" = bus.weapon_share),
		"watts" = list("shields" = online ? bus.shield_watts : 0, "engines" = online ? bus.engine_watts : 0, "weapons" = online ? bus.weapon_watts : 0),
		"available_watts" = online ? bus.available_watts : 0,
		"max_watts" = ST_COMBAT_BUS_POWER,
		"thrust_limit" = round(ship?.combat_engine_limit(available = !ship.engines_running) * 100),
		"shield_present" = !!shield,
		"shield_working" = shield?.hardware_ready(ship),
		"shield_enabled" = shield?.enabled,
		"shield_raised" = ship?.combat_shield_active(),
		"shield_charge" = shield?.charge || 0,
		"shield_capacity" = ST_SHIP_SHIELD_CAPACITY,
		"shield_sustained" = online && bus.shield_watts >= ST_SHIP_SHIELD_HOLD_POWER,
		"shield_recovery" = shield ? max(0, shield.recover_at - world.time) / (1 SECONDS) : 0,
		"gun_charge" = gun_charge,
		"gun_capacity" = gun_capacity,
	)

/obj/machinery/computer/stationtrauma_combat_power_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!isliving(ui.user) || !Adjacent(ui.user) || !can_interact(ui.user) || panel_open || !is_operational || ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	var/obj/machinery/stationtrauma_combat_power/bus = distributor()
	if(QDELETED(bus))
		return FALSE
	switch(action)
		if("allocate")
			return bus.set_allocation(params["shields"], params["engines"], params["weapons"], params["revision"])
		if("toggle_shield")
			var/obj/docking_port/mobile/stationtrauma_space/ship = bus.vessel_ref?.resolve()
			var/obj/machinery/stationtrauma_ship_shield/shield = ship?.combat_shield_ref?.resolve()
			if(!shield?.hardware_ready(ship))
				return FALSE
			shield.enabled = !shield.enabled
			if(!shield.enabled)
				shield.set_raised(FALSE)
			return TRUE
	return FALSE
