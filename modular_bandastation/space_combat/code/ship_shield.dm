/** One physical field generator and charge reservoir for the entire ship. */
/obj/machinery/stationtrauma_ship_shield
	name = "генератор корабельного щита"
	desc = "Поддерживает защитное поле вокруг корабля и накапливает энергию для поглощения попаданий."
	icon = 'modular_bandastation/space_combat/icons/patrol_machines.dmi'
	icon_state = "shield"
	anchored = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	processing_flags = NONE
	var/datum/weakref/vessel_ref
	var/enabled = TRUE
	var/raised = FALSE
	var/charge = 0
	var/recover_at = 0

/obj/machinery/stationtrauma_ship_shield/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/stationtrauma_ship_shield/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(ship?.combat_shield_ref?.resolve() == src)
		ship.combat_shield_ref = null
	vessel_ref = null
	set_raised(FALSE)
	if(!istype(port, /obj/docking_port/mobile/stationtrauma_space))
		return
	ship = port
	if(ship.is_in_shuttle_bounds(src) && ship.shuttle_areas[get_area(src)] && !ship.combat_shield_ref?.resolve())
		ship.combat_shield_ref = WEAKREF(src)
		vessel_ref = WEAKREF(ship)

/obj/machinery/stationtrauma_ship_shield/Destroy()
	connect_to_shuttle(FALSE, null)
	return ..()

/obj/machinery/stationtrauma_ship_shield/proc/hardware_ready(obj/docking_port/mobile/stationtrauma_space/ship)
	return !QDELETED(ship) && anchored && !panel_open && is_operational && vessel_ref?.resolve() == ship && ship.is_in_shuttle_bounds(src) && ship.shuttle_areas[get_area(src)]

/obj/machinery/stationtrauma_ship_shield/proc/can_project(obj/docking_port/mobile/stationtrauma_space/ship)
	return enabled && hardware_ready(ship)

/obj/machinery/stationtrauma_ship_shield/proc/power_demand(obj/docking_port/mobile/stationtrauma_space/ship, seconds_per_tick)
	if(!can_project(ship))
		return 0
	return ST_SHIP_SHIELD_HOLD_POWER * seconds_per_tick + ST_SHIP_SHIELD_CAPACITY - charge

/obj/machinery/stationtrauma_ship_shield/proc/receive_power(joules, seconds_per_tick)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	var/maintenance = ST_SHIP_SHIELD_HOLD_POWER * seconds_per_tick
	if(seconds_per_tick <= 0 || !can_project(ship) || joules < maintenance)
		set_raised(FALSE)
		return
	charge = min(ST_SHIP_SHIELD_CAPACITY, charge + joules - maintenance)
	if(charge >= ST_SHIP_SHIELD_START_CHARGE && world.time >= recover_at)
		set_raised(TRUE)

/obj/machinery/stationtrauma_ship_shield/proc/set_raised(new_value)
	if(raised == new_value)
		return
	raised = new_value
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/stationtrauma_ship_shield/update_icon_state()
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	icon_state = ship?.combat_shield_active() ? "shield_active" : "shield"
	return ..()

/** Return the energy intercepted by the field. The remainder reaches the hull. */
/obj/machinery/stationtrauma_ship_shield/proc/absorb(joules)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(!ship?.combat_shield_active() || joules <= 0)
		return 0
	var/absorbed = min(charge, joules)
	charge -= absorbed
	if(charge <= 0)
		set_raised(FALSE)
		recover_at = world.time + ST_SHIP_SHIELD_RECOVERY
	return absorbed
