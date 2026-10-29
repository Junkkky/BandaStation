// AI EDIT START - gas-fed shuttle receivers and nozzles
/** Native engine registration stays nominal; the overmap reads delivered gas power separately. */
/obj/machinery/power/shuttle_engine
	/// Ordinary shuttle engines retain their original unlimited propellant behaviour.
	var/requires_combustion = FALSE
	/// Gas receiver supplying this nozzle, without retaining a dismantled machine.
	var/datum/weakref/combustion_feed

/** Small nozzle supplied by a combustion chamber. */
/obj/machinery/power/shuttle_engine/propulsion/tritium
	name = "тритиевый двигатель"
	desc = "Сопло двигательной установки с подачей горячего газа от приёмного блока."
	requires_combustion = TRUE
	circuit = /obj/item/circuitboard/machine/engine/propulsion/tritium

/** Large nozzle retaining the native two-by-two footprint. */
/obj/machinery/power/shuttle_engine/large/tritium
	name = "большой тритиевый двигатель"
	desc = "Тяжёлое сопло двигательной установки с подачей горячего газа."
	requires_combustion = TRUE

/** Buildable receiver using the existing heater appearance. */
/obj/item/circuitboard/machine/engine/heater/combustion
	name = "приёмный блок двигателя"
	build_path = /obj/machinery/atmospherics/components/unary/ship_engine_heater

/** Rebuilding a small fuelled nozzle preserves its propellant requirement. */
/obj/item/circuitboard/machine/engine/propulsion/tritium
	name = "тритиевый двигатель"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/tritium

/** One native pipe inlet, directed toward a separately installed physical nozzle. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater
	name = "приёмный блок двигателя"
	desc = "Подаёт горячий газ из магистрали к соплу двигательной установки."
	icon = 'icons/turf/shuttle.dmi'
	icon_state = "heater"
	dir = SOUTH
	layer = OBJ_LAYER
	density = TRUE
	max_integrity = 300
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.25
	circuit = /obj/item/circuitboard/machine/engine/heater/combustion
	/// Physical nozzle; its footprint may contain several turfs.
	var/datum/weakref/nozzle
	/// Controller discovered through the actual supply pipeline.
	var/datum/weakref/chamber
	/// Delivered power remains available between native atmosphere ticks.
	var/delivered_fraction = 0

/obj/machinery/atmospherics/components/unary/ship_engine_heater/Initialize(mapload)
	. = ..()
	var/datum/gas_mixture/air = airs[1]
	air.volume = UNARY_PIPE_VOLUME

/obj/machinery/atmospherics/components/unary/ship_engine_heater/Destroy()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	if(engine?.combustion_feed?.resolve() == src)
		engine.combustion_feed = null
	nozzle = null
	chamber = null
	return ..()

/obj/machinery/atmospherics/components/unary/ship_engine_heater/set_init_directions()
	// The pipe enters behind the receiver; dir points toward its nozzle.
	initialize_directions = REVERSE_DIR(dir)

/obj/machinery/atmospherics/components/unary/ship_engine_heater/update_icon_nopipes()
	icon_state = "heater"

/** Bind once per start/reconnection; no world or range scans in atmosphere processing. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/bind_nozzle(obj/docking_port/mobile/ship)
	var/obj/machinery/power/shuttle_engine/previous = nozzle?.resolve()
	if(previous?.combustion_feed?.resolve() == src)
		previous.combustion_feed = null
	nozzle = null
	var/turf/nozzle_tile = get_step(src, dir)
	for(var/obj/machinery/power/shuttle_engine/engine as anything in ship.engine_list)
		if(!engine.requires_combustion || engine.dir != dir || !(nozzle_tile in engine.locs))
			continue
		if(engine.combustion_feed?.resolve())
			continue
		nozzle = WEAKREF(engine)
		engine.combustion_feed = WEAKREF(src)
		return TRUE
	return FALSE

/** Find the first turf outside the nozzle's actual bounds, including rotated large engines. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/exhaust_turf()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	if(!engine)
		return null
	var/turf/exhaust = get_step(engine, engine.dir)
	while(exhaust && (exhaust in engine.locs))
		exhaust = get_step(exhaust, engine.dir)
	return exhaust

/** The same interlocks explain lost thrust to the engineer and prevent gas consumption. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/unavailable_reason()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	var/obj/machinery/computer/ship_combustion/control = chamber?.resolve()
	if(machine_stat & BROKEN)
		return "Приёмник повреждён"
	if(!is_operational)
		return "Приёмник обесточен или отключён"
	if(panel_open || !anchored)
		return "Приёмник не собран"
	if(!nodes[1] || !parents[1])
		return "Нет подключения к трубе"
	if(!engine)
		return "Сопло не подключено"
	if(!engine.anchored || engine.engine_state != initial(engine.engine_state))
		return "Сопло не собрано"
	if((engine.machine_stat & BROKEN) || engine.get_integrity() <= 0)
		return "Сопло повреждено"
	if(!engine.connected_ship || !control?.is_operational)
		return "Нет связи с контроллером"
	if(control.vessel_ref?.resolve() != engine.connected_ship || engine.dir != dir || !(get_step(src, dir) in engine.locs))
		return "Нарушено соединение с соплом"
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = control.device("outlet")
	if(outlet?.parents[1] != parents[1])
		return "Разрыв выпускной магистрали"
	var/turf/open/exhaust = exhaust_turf()
	if(!istype(exhaust))
		return "Выпуск сопла перекрыт"
	switch(control.phase)
		if(SHIP_CHAMBER_OFF)
			return "Выключен"
		if(SHIP_CHAMBER_STARTING)
			return "Прогрев"
		if(SHIP_CHAMBER_PURGING)
			return "Продувка"
		if(SHIP_CHAMBER_LOCKED)
			return "Блокировка"
	if(control.phase != SHIP_CHAMBER_RUNNING)
		return "Камера не готова"
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	// A delivered parcel powers its interval even if it emptied the inlet.
	if(ship.engines_running && delivered_fraction > 0)
		return null
	var/datum/gas_mixture/air = airs[1]
	if(air.total_moles() <= 0)
		return "Нет подачи газа"
	if(air.temperature < TRITIUM_MINIMUM_BURN_TEMPERATURE)
		return "Газ остыл"
	var/datum/gas_mixture/environment = exhaust.return_air()
	if(air.return_pressure() <= (environment?.return_pressure() || 0))
		return "Недостаточный напор"
	return null

/** Hot gas, an intact installation and an unobstructed exhaust are required for thrust. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/ready_fraction()
	if(unavailable_reason())
		return 0
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	if(ship.engines_running && delivered_fraction > 0)
		return delivered_fraction
	var/datum/gas_mixture/air = airs[1]
	return min(1, air.temperature / SHIP_ENGINE_OPERATING_TEMPERATURE)

/** The cold/off preview permits ignition; powered flight uses only gas already delivered. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/propulsion_fraction()
	var/ready = ready_fraction()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine?.connected_ship
	return ship?.engines_running ? min(ready, delivered_fraction) : ready

/obj/machinery/atmospherics/components/unary/ship_engine_heater/process_atmos(seconds_per_tick)
	delivered_fraction = 0
	if(seconds_per_tick <= 0 || !ready_fraction())
		return
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	if(!ship.engines_running)
		return
	var/datum/stationtrauma_overmap/space/map = ship.overmap
	var/load = map?.helm_engaged ? max(abs(map.throttle) / 100, !!map.braking, !!map.maneuver_direction) : 0
	// Calibrated for roughly twenty minutes at half thrust on the draft's standard canister pair.
	var/requested = 0.52 * engine.engine_power * max(0.15, load) * seconds_per_tick
	var/datum/gas_mixture/air = airs[1]
	var/datum/gas_mixture/exhausted = air.remove(requested)
	if(!exhausted)
		return
	delivered_fraction = min(1, exhausted.total_moles() / requested) * min(1, exhausted.temperature / SHIP_ENGINE_OPERATING_TEMPERATURE)
	var/turf/exhaust = exhaust_turf()
	// Large nozzles may exhaust beyond the template into uninitialized map-loader space.
	if(istype(exhaust, /turf/open/space/basic) && !(exhaust.flags_1 & INITIALIZED_1))
		exhaust = exhaust.ChangeTurf(/turf/open/space)
	exhaust.assume_air(exhausted)
	update_parents()

/obj/machinery/atmospherics/components/unary/ship_engine_heater/screwdriver_act(mob/living/user, obj/item/tool)
	var/obj/machinery/computer/ship_combustion/control = chamber?.resolve()
	if(control?.phase == SHIP_CHAMBER_RUNNING || control?.phase == SHIP_CHAMBER_STARTING)
		balloon_alert(user, "выключите установку!")
		return ITEM_INTERACT_BLOCKING
	if(get_integrity() < max_integrity)
		if(do_after(user, 5 SECONDS, src))
			control = chamber?.resolve()
			if(control?.phase != SHIP_CHAMBER_RUNNING && control?.phase != SHIP_CHAMBER_STARTING)
				repair_damage(max_integrity)
		return ITEM_INTERACT_SUCCESS
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/atmospherics/components/unary/ship_engine_heater/crowbar_act(mob/living/user, obj/item/tool)
	return crowbar_deconstruction_act(user, tool)
// AI EDIT END
