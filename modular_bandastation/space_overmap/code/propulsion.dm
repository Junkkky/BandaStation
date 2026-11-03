/** Native engine registration stays nominal; the overmap reads delivered gas power separately. */
/obj/machinery/power/shuttle_engine
	/// Ordinary shuttle engines retain their original unlimited propellant behaviour.
	var/requires_combustion = FALSE
	/// Gas receiver supplying this nozzle, without retaining a dismantled machine.
	var/datum/weakref/combustion_feed
	/// Exhaust plume shown while the nozzle delivers commanded thrust.
	var/obj/effect/abstract/particle_holder/exhaust
	/// Plume colours from the nozzle outward; bluespace drives by default.
	var/list/exhaust_gradient = list("#FFFFFF", "#9FF4FF", "#2F8CFF")

/obj/machinery/power/shuttle_engine/Destroy(force)
	QDEL_NULL(exhaust)
	return ..()

/**
 * Start or stop the exhaust plume, only on a change of state.
 *
 * Arguments:
 * * active - Whether the nozzle is producing thrust
 */
/obj/machinery/power/shuttle_engine/proc/set_exhaust(active)
	if(!!exhaust == !!active)
		return
	if(!active)
		QDEL_NULL(exhaust)
		set_light(0)
		return
	exhaust = new(src, /particles/ship_exhaust)
	var/list/offset = dir2offset(dir)
	// Emit across the whole outer edge of the real footprint, including rotated large nozzles.
	var/edge_x = (bound_width - ICON_SIZE_X) / 2 + offset[1] * bound_width / 2
	var/edge_y = (bound_height - ICON_SIZE_Y) / 2 + offset[2] * bound_height / 2
	var/spread_x = offset[1] ? 0 : bound_width / 2 - 6
	var/spread_y = offset[2] ? 0 : bound_height / 2 - 6
	exhaust.particles.position = generator(GEN_BOX, list(edge_x - spread_x, edge_y - spread_y, 0), list(edge_x + spread_x, edge_y + spread_y, 0), UNIFORM_RAND)
	exhaust.particles.velocity = list(offset[1] * 6, offset[2] * 6)
	exhaust.particles.gradient = exhaust_gradient
	set_light(2, 1, exhaust_gradient[2])

/** Flame jet and fading tail behind a firing nozzle. */
/particles/ship_exhaust
	icon = 'icons/effects/particles/bonfire.dmi'
	icon_state = "bonfire"
	width = 192
	height = 192
	count = 300
	spawning = 8
	lifespan = 0.8 SECONDS
	fade = 0.5 SECONDS
	grow = 0.08
	color = 0
	color_change = 0.12
	friction = 0.05
	drift = generator(GEN_VECTOR, list(-0.6, -0.6), list(0.6, 0.6), NORMAL_RAND)
	scale = generator(GEN_VECTOR, list(0.9, 0.9), list(1.5, 1.5), NORMAL_RAND)
	spin = generator(GEN_NUM, -20, 20)

/** Small nozzle supplied by a combustion chamber. */
/obj/machinery/power/shuttle_engine/propulsion/tritium
	name = "тритиевый двигатель"
	desc = "Сопло двигательной установки с подачей горячего газа от приёмного блока."
	requires_combustion = TRUE
	circuit = /obj/item/circuitboard/machine/engine/propulsion/tritium
	// Tritium combustion is the strongest drive per nozzle.
	engine_power = 2
	exhaust_gradient = list("#FFFFFF", "#FCE6B6", "#FD481C")

/** Large nozzle retaining the native two-by-two footprint. */
/obj/machinery/power/shuttle_engine/large/tritium
	name = "большой тритиевый двигатель"
	desc = "Тяжёлое сопло двигательной установки с подачей горячего газа."
	requires_combustion = TRUE
	// Four small nozzles' footprint.
	engine_power = 8
	exhaust_gradient = list("#FFFFFF", "#FCE6B6", "#FD481C")

/**
 * Fuel gauges of real supply networks; each mixture and canister is counted once, including those behind inlet pumps.
 *
 * Arguments:
 * * networks - Pipelines feeding the drive; the list is extended while walking
 * * gases - Gas type to crew-facing name
 *
 * Returns a list of gauges: name, amount in moles and the nominal fill of the connected canisters of that gas.
 */
/proc/stationtrauma_fuel_gauges(list/networks, list/gases)
	var/list/mixtures = list()
	var/list/canisters = list()
	for(var/index = 1; index <= length(networks); index++)
		var/datum/pipeline/network = networks[index]
		if(!network)
			continue
		mixtures |= network.return_air()
		for(var/obj/machinery/atmospherics/components/component as anything in network.other_atmos_machines)
			mixtures |= component.return_airs_for_reconcilation(network)
			networks |= component.return_pipenets_for_reconcilation(network)
			if(istype(component, /obj/machinery/atmospherics/components/binary/pump))
				if(component.parents[2] == network && component.parents[1])
					networks |= component.parents[1]
			else if(istype(component, /obj/machinery/atmospherics/components/unary/portables_connector))
				var/obj/machinery/atmospherics/components/unary/portables_connector/connector = component
				if(istype(connector.connected_device, /obj/machinery/portable_atmospherics/canister))
					canisters |= connector.connected_device
	var/list/gauges = list()
	for(var/gas in gases)
		var/amount = 0
		for(var/datum/gas_mixture/mixture as anything in mixtures)
			amount += mixture.moles[gas]
		// A standard filled canister is the full mark, as TG fills them in create_gas().
		var/capacity = 0
		for(var/obj/machinery/portable_atmospherics/canister/canister as anything in canisters)
			if(canister.gas_type == gas)
				capacity += canister.maximum_pressure * canister.filled * canister.air_contents.volume / (R_IDEAL_GAS_EQUATION * T20C)
		gauges += list(list("name" = gases[gas], "amount" = round(amount, 0.1), "capacity" = round(capacity, 0.1)))
	return gauges

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
	/// Moles per second one nozzle draws at full load; thrust comes from engine_power, not from more gas.
	var/propellant_flow = 0.52

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

/** Receiver and nozzle hardware faults shared by every feed type. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/hardware_fault()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
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
	return null

/** The same interlocks explain lost thrust to the engineer and prevent gas consumption. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/unavailable_reason()
	. = hardware_fault()
	if(.)
		return
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/machinery/computer/ship_combustion/control = chamber?.resolve()
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
	var/load = map?.ascending() ? 1 : map?.helm_engaged ? max(abs(map.throttle) / 100, !!map.braking, !!map.maneuver_direction) : 0
	// The tritium value is calibrated for roughly twenty minutes at half thrust on Raven's standard canister pair.
	var/requested = propellant_flow * max(0.15, load) * seconds_per_tick
	var/datum/gas_mixture/air = airs[1]
	var/datum/gas_mixture/exhausted = air.remove(requested)
	if(!exhausted)
		return
	delivered_fraction = exhaust_fraction(exhausted, requested, seconds_per_tick)
	var/turf/exhaust = exhaust_turf()
	// Large nozzles may exhaust beyond the template into uninitialized map-loader space.
	if(istype(exhaust, /turf/open/space/basic) && !(exhaust.flags_1 & INITIALIZED_1))
		exhaust = exhaust.ChangeTurf(/turf/open/space)
	exhaust.assume_air(exhausted)
	update_parents()

/**
 * Share of nominal thrust carried by one exhausted parcel.
 *
 * Arguments:
 * * exhausted - Gas removed from the inlet this atmos tick
 * * requested - Moles a full-power parcel would contain
 * * seconds_per_tick - Atmos tick length
 */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/exhaust_fraction(datum/gas_mixture/exhausted, requested, seconds_per_tick)
	return min(1, exhausted.total_moles() / requested) * min(1, exhausted.temperature / SHIP_ENGINE_OPERATING_TEMPERATURE)

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

/** Small nozzle exhausting electrically heated plasma; no combustion chamber is involved. */
/obj/machinery/power/shuttle_engine/propulsion/plasma
	name = "плазменный двигатель"
	desc = "Сопло, выбрасывающее плазму, разогретую электрическим нагревателем."
	requires_combustion = TRUE
	circuit = /obj/item/circuitboard/machine/engine/propulsion/plasma
	exhaust_gradient = list("#FFFFFF", "#F2B8FF", "#9B3DFF")

/** Rebuilding a plasma nozzle preserves its propellant requirement. */
/obj/item/circuitboard/machine/engine/propulsion/plasma
	name = "плазменный двигатель"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/plasma

/** Buildable electric plasma heater. */
/obj/item/circuitboard/machine/engine/heater/plasma
	name = "плазменный нагреватель"
	build_path = /obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma

/**
 * Heats plasma taken straight from its inlet pipe with the area's electricity.
 *
 * The heating cap is below what full thrust needs, so hard burns exhaust cooler plasma and give less thrust.
 */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma
	name = "плазменный нагреватель"
	desc = "Разогревает поступающую плазму электричеством и подаёт её к соплу."
	circuit = /obj/item/circuitboard/machine/engine/heater/plasma
	// Three times the tritium mass flow: a cheap but hungry drive.
	propellant_flow = 1.56
	/// Maximum electric heating rate.
	var/heating_power = 50 KILO WATTS
	/// Exhaust temperature for full thrust; plasma relies on mass flow rather than heat.
	var/exhaust_temperature = 500

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/unavailable_reason()
	. = hardware_fault()
	if(.)
		return
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	if(!istype(engine.connected_ship, /obj/docking_port/mobile/stationtrauma_space))
		return "Нет связи с кораблём"
	if(engine.dir != dir || !(get_step(src, dir) in engine.locs))
		return "Нарушено соединение с соплом"
	var/turf/open/exhaust = exhaust_turf()
	if(!istype(exhaust))
		return "Выпуск сопла перекрыт"
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	if(ship.engines_running && delivered_fraction > 0)
		return null
	var/datum/gas_mixture/air = airs[1]
	if(!air.moles[/datum/gas/plasma])
		return "Нет подачи плазмы"
	var/datum/gas_mixture/environment = exhaust.return_air()
	if(air.return_pressure() <= (environment?.return_pressure() || 0))
		return "Недостаточный напор"
	return null

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/ready_fraction()
	if(unavailable_reason())
		return 0
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	return ship.engines_running && delivered_fraction > 0 ? delivered_fraction : 1

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/exhaust_fraction(datum/gas_mixture/exhausted, requested, seconds_per_tick)
	var/capacity = exhausted.heat_capacity()
	var/heat = min((exhaust_temperature - exhausted.temperature) * capacity, heating_power * seconds_per_tick)
	if(heat > 0)
		exhausted.temperature += use_energy(heat) / capacity
	// Only electrical heating above room temperature produces thrust, so an unpowered heater gives none.
	return min(1, exhausted.moles[/datum/gas/plasma] / requested) * clamp((exhausted.temperature - T20C) / (exhaust_temperature - T20C), 0, 1)
