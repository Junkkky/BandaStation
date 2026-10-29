// AI EDIT START - native atmos combustion chamber control

/** A powered glow plug starts lean mixtures below the stock spark's minimum fuel quantity. */
/obj/machinery/igniter/ship_engine
	name = "калильный воспламенитель"
	desc = "Электрический подогреватель для начального розжига бедной тритиевой смеси."

/obj/machinery/igniter/ship_engine/process(seconds_per_tick)
	. = ..()
	if(!on || !is_operational || seconds_per_tick <= 0 || !isopenturf(loc))
		return
	var/turf/open/chamber = loc
	var/datum/gas_mixture/air = chamber.return_air()
	if(!air?.total_moles() || air.temperature >= SHIP_ENGINE_OPERATING_TEMPERATURE)
		return
	var/capacity = air.heat_capacity()
	var/heat = min((SHIP_ENGINE_OPERATING_TEMPERATURE - air.temperature) * capacity, 20 KILO WATTS * seconds_per_tick)
	heat = use_energy(heat, force = FALSE)
	if(heat > 0)
		air.set_temperature(air.temperature + heat / capacity)
		chamber.air_update_turf()

/** Circuit board for a combustion chamber control console. */
/obj/item/circuitboard/computer/ship_combustion
	name = "контроллер камеры сгорания"
	build_path = /obj/machinery/computer/ship_combustion

/** Coordinates stock atmos devices tagged <chamber_id>_<mixer|inlet|outlet|purge|igniter>. */
/obj/machinery/computer/ship_combustion
	name = "контроллер камеры сгорания"
	desc = "Управление подачей трития и кислорода, зажиганием и продувкой двигательной установки."
	icon_screen = "tank"
	circuit = /obj/item/circuitboard/computer/ship_combustion
	/// Unique installation prefix, shared with the mapped devices' id_tag values.
	var/chamber_id
	/// Weak references prevent dismantled equipment being retained by the controller.
	var/list/equipment = list()
	/// Current start, operating or shutdown phase.
	var/phase = SHIP_CHAMBER_OFF
	/// Latched trip reason; cleared only by an engineer after a safe purge.
	var/fault
	/// Deadline for the single ignition attempt or purge.
	var/deadline = 0
	/// Minimum warm-up time before an established flame is accepted.
	var/ready_at = 0
	/// Whether native tritium combustion has been observed during this start.
	var/flame_confirmed = FALSE
	/// Observed chamber mixture; released when ignition or operation stops.
	var/datum/weakref/ignition_air
	/// Engineer's manual fuel isolation switch.
	var/supply_enabled = TRUE
	/// Maximum injector volume per native atmos cycle, in litres.
	var/feed_rate = 5
	/// Native hull association is independent of global equipment IDs.
	var/datum/weakref/vessel_ref

/obj/machinery/computer/ship_combustion/post_machine_initialize()
	. = ..()
	connect_to_shuttle(port = SSshuttle.get_containing_shuttle(src))
	bind_equipment()

/obj/machinery/computer/ship_combustion/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/previous = vessel_ref?.resolve()
	if(previous && previous != port)
		stop_chamber("Изменено подключение установки")
		if(previous.combustion_controller?.resolve() == src)
			previous.combustion_controller = null
		vessel_ref = null
	if(!istype(port, /obj/docking_port/mobile/stationtrauma_space))
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/ship = port
	if(ship.combustion_controller?.resolve() && ship.combustion_controller.resolve() != src)
		return FALSE
	vessel_ref = WEAKREF(ship)
	ship.combustion_controller = WEAKREF(src)
	return TRUE

/obj/machinery/computer/ship_combustion/Destroy()
	// Isolate the feed even when the control console itself is dismantled.
	stop_chamber()
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(ship?.combustion_controller?.resolve() == src)
		ship.combustion_controller = null
	vessel_ref = null
	equipment.Cut()
	return ..()

/** Resolve only previously linked equipment, including after shuttle movement. */
/obj/machinery/computer/ship_combustion/proc/device(role)
	var/datum/weakref/reference = equipment[role]
	return reference?.resolve()

/** Link through the existing id registry; never search the world during processing. */
/obj/machinery/computer/ship_combustion/proc/bind_equipment()
	stop_chamber()
	equipment.Cut()
	if(!length(chamber_id))
		return
	var/static/list/roles = list(
		"mixer" = /obj/machinery/atmospherics/components/trinary/mixer,
		"inlet" = /obj/machinery/atmospherics/components/unary/outlet_injector,
		"outlet" = /obj/machinery/atmospherics/components/unary/vent_pump,
		"purge" = /obj/machinery/atmospherics/components/unary/outlet_injector,
		"igniter" = /obj/machinery/igniter,
	)
	for(var/role in roles)
		var/obj/machinery/machine = GLOB.objects_by_id_tag["[chamber_id]_[role]"]
		if(istype(machine, roles[role]) && machine.z == z)
			equipment[role] = WEAKREF(machine)
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	outlet?.disconnect_from_area()
	stop_chamber()
	bind_propulsion()

/** Resolve receivers through the real pipe network and use native engine bounds for pairing. */
/obj/machinery/computer/ship_combustion/proc/bind_propulsion()
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	if(!ship || !outlet?.parents[1])
		return
	var/datum/pipeline/line = outlet.parents[1]
	for(var/obj/machinery/atmospherics/components/unary/ship_engine_heater/heater in line.other_atmos_machines)
		if(!ship.shuttle_areas[get_area(heater)] || !ship.is_in_shuttle_bounds(heater))
			continue
		heater.chamber = WEAKREF(src)
		heater.bind_nozzle(ship)

/** Check power, physical placement, and both sides of the native pipe networks. */
/obj/machinery/computer/ship_combustion/proc/equipment_fault()
	if(!is_operational)
		return "Нет питания контроллера"
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	var/obj/machinery/atmospherics/components/unary/outlet_injector/purge = device("purge")
	var/obj/machinery/igniter/igniter = device("igniter")
	for(var/role in equipment)
		var/obj/machinery/machine = device(role)
		if(!machine?.is_operational || machine.z != z || machine.id_tag != "[chamber_id]_[role]")
			return "Оборудование отключено или повреждено"
	if(!mixer || !inlet || !outlet || !purge || !igniter)
		return "Оборудование не подключено"
	if(!isopenturf(inlet.loc) || !isopenturf(outlet.loc) || !isopenturf(purge.loc) || get_turf(igniter) != get_turf(inlet) || get_dist(inlet, outlet) > 1)
		return "Нарушена компоновка камеры"
	if(!mixer.nodes[1] || !mixer.nodes[2] || !mixer.parents[3] || mixer.parents[3] != inlet.parents[1])
		return "Нарушена подача смеси"
	if(outlet.welded || !outlet.parents[1] || outlet.parents[1] != purge.parents[1] || purge.loc == inlet.loc)
		return "Нарушена выпускная магистраль"
	return null

/obj/machinery/computer/ship_combustion/multitool_act(mob/living/user, obj/item/tool)
	if(phase != SHIP_CHAMBER_OFF && phase != SHIP_CHAMBER_LOCKED)
		return ITEM_INTERACT_BLOCKING
	var/prefix = tgui_input_text(user, "Идентификатор установки", name, chamber_id, max_length = 64)
	if(!length(prefix) || QDELETED(src) || QDELETED(user) || !user.is_holding(tool) || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return ITEM_INTERACT_BLOCKING
	if(!is_operational || (phase != SHIP_CHAMBER_OFF && phase != SHIP_CHAMBER_LOCKED))
		return ITEM_INTERACT_BLOCKING
	stop_chamber()
	chamber_id = prefix
	bind_equipment()
	return ITEM_INTERACT_SUCCESS

/** Stop chemical input and sparks; retain a trip until the chamber has been cleared. */
/obj/machinery/computer/ship_combustion/proc/stop_chamber(reason)
	var/datum/gas_mixture/air = ignition_air?.resolve()
	if(air)
		UnregisterSignal(air, COMSIG_GASMIX_REACTED)
	ignition_air = null
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/obj/machinery/igniter/igniter = device("igniter")
	mixer?.set_on(FALSE)
	inlet?.set_on(FALSE)
	if(igniter?.on)
		igniter.toggle()
	if(reason && !fault)
		fault = reason
	if(phase == SHIP_CHAMBER_STARTING || phase == SHIP_CHAMBER_RUNNING)
		phase = SHIP_CHAMBER_PURGING
		deadline = world.time + 90 SECONDS
		set_exhaust(TRUE)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(ship?.engines_running)
		ship.overmap?.set_engines_running(FALSE)

/** Switch the stock siphon between working pressure and complete evacuation. */
/obj/machinery/computer/ship_combustion/proc/set_exhaust(purging)
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	var/obj/machinery/atmospherics/components/unary/outlet_injector/purge = device("purge")
	if(outlet)
		outlet.pump_direction = ATMOS_DIRECTION_SIPHONING
		outlet.pressure_checks = ATMOS_INTERNAL_BOUND | ATMOS_EXTERNAL_BOUND
		outlet.internal_pressure_bound = purging ? 2000 : 300
		outlet.external_pressure_bound = purging ? 0 : 20
		outlet.set_on(TRUE)
	if(purge)
		purge.volume_rate = MAX_TRANSFER_RATE
		// Warm-up needs an open exhaust before the nozzles are allowed to produce thrust.
		purge.set_on(purging || phase == SHIP_CHAMBER_STARTING)

/** Confirm the real chamber and exhaust line are depressurized before accepting a reset. */
/obj/machinery/computer/ship_combustion/proc/purge_complete()
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	if(!isopenturf(inlet?.loc) || !outlet?.parents[1])
		return FALSE
	var/datum/gas_mixture/air = inlet.loc.return_air()
	var/datum/gas_mixture/line = outlet.airs[1]
	return air.return_pressure() < 5 && line.return_pressure() < 5

/** One ignition attempt, with warm-up and a separate timeout for failure. */
/obj/machinery/computer/ship_combustion/proc/start_chamber()
	if(phase != SHIP_CHAMBER_OFF || fault || !supply_enabled)
		return FALSE
	var/reason = equipment_fault()
	if(reason)
		fault = reason
		phase = SHIP_CHAMBER_LOCKED
		return FALSE
	bind_propulsion()
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/datum/gas_mixture/air = inlet.loc.return_air()
	if(air.return_pressure() > 200 || air.temperature > 4000)
		fault = "Камера не готова к запуску; требуется продувка"
		phase = SHIP_CHAMBER_LOCKED
		return FALSE
	flame_confirmed = FALSE
	ignition_air = WEAKREF(air)
	RegisterSignal(air, COMSIG_GASMIX_REACTED, PROC_REF(on_chamber_reacted))
	ready_at = world.time + (air.temperature >= TRITIUM_MINIMUM_BURN_TEMPERATURE ? 5 SECONDS : 30 SECONDS)
	deadline = ready_at + (air.temperature >= TRITIUM_MINIMUM_BURN_TEMPERATURE ? 15 SECONDS : 45 SECONDS)
	phase = SHIP_CHAMBER_STARTING
	set_exhaust(FALSE)
	var/obj/machinery/igniter/igniter = device("igniter")
	if(!igniter.on)
		igniter.toggle()
	process(0)
	return TRUE

/** A hot chamber or burning substitute fuel is not proof of tritium ignition. */
/obj/machinery/computer/ship_combustion/proc/on_chamber_reacted(datum/gas_mixture/air)
	SIGNAL_HANDLER
	if(air.reaction_results[/datum/gas_reaction/standard/tritfire] > 0)
		flame_confirmed = TRUE

/obj/machinery/computer/ship_combustion/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational && (phase == SHIP_CHAMBER_STARTING || phase == SHIP_CHAMBER_RUNNING))
		stop_chamber("Потеря питания или повреждение контроллера")

/obj/machinery/computer/ship_combustion/process(seconds_per_tick)
	if(phase == SHIP_CHAMBER_OFF || phase == SHIP_CHAMBER_LOCKED)
		return
	if(phase == SHIP_CHAMBER_PURGING)
		stop_chamber()
		set_exhaust(TRUE)
		if(purge_complete() || world.time >= deadline)
			if(!purge_complete() && !fault)
				fault = "Продувка не завершена"
			phase = fault ? SHIP_CHAMBER_LOCKED : SHIP_CHAMBER_OFF
			var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
			var/obj/machinery/atmospherics/components/unary/outlet_injector/purge = device("purge")
			outlet?.set_on(FALSE)
			purge?.set_on(FALSE)
		return
	var/reason = equipment_fault()
	if(reason || !supply_enabled)
		stop_chamber(reason)
		return
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/datum/gas_mixture/air = inlet.loc.return_air()
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	var/datum/gas_mixture/line = outlet.airs[1]
	if(air.return_pressure() > 500 || line.return_pressure() > 1900 || air.temperature > 4000)
		stop_chamber("Превышены давление или температура")
		return
	if(phase == SHIP_CHAMBER_STARTING)
		if(flame_confirmed && world.time >= ready_at && air.temperature >= SHIP_ENGINE_OPERATING_TEMPERATURE)
			phase = SHIP_CHAMBER_RUNNING
			var/obj/machinery/atmospherics/components/unary/outlet_injector/purge = device("purge")
			purge.set_on(FALSE)
			var/obj/machinery/igniter/igniter = device("igniter")
			if(igniter.on)
				igniter.toggle()
		else if(world.time >= deadline)
			stop_chamber("Неудачный розжиг")
			return
	else if(air.temperature < TRITIUM_MINIMUM_BURN_TEMPERATURE)
		stop_chamber("Пламя погасло")
		return
	// Refill a narrow pressure band before low demand lets the chamber cool between feeds.
	var/feeding = air.return_pressure() < 150 && air.temperature < 2000 && line.return_pressure() < outlet.internal_pressure_bound - 10
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	mixer.set_on(feeding)
	inlet.volume_rate = feed_rate
	inlet.set_on(feeding)

/obj/machinery/computer/ship_combustion/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCombustion", name)
		ui.open()

/obj/machinery/computer/ship_combustion/ui_data(mob/user)
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	var/datum/gas_mixture/air = isopenturf(inlet?.loc) ? inlet.loc.return_air() : null
	var/datum/gas_mixture/line = outlet?.airs[1]
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	var/list/engines = list()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in ship?.engine_list)
		if(!engine.requires_combustion)
			continue
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
		var/datum/gas_mixture/supply = feed?.airs[1]
		var/output = feed?.propulsion_fraction() || 0
		var/reason = feed ? feed.unavailable_reason() : "Приёмник не подключён"
		engines += list(list(
			"id" = REF(engine), "number" = length(engines) + 1,
			"position" = "[engine.x - ship.x] / [engine.y - ship.y]",
			"status" = reason || (ship.engines_running ? (output >= 1 ? "Работает" : "Ограниченная тяга") : "Готов"),
			"output" = round(output * 100, 0.1),
			"temperature" = supply ? round(supply.temperature, 0.1) : null,
			"pressure" = supply ? round(supply.return_pressure(), 0.1) : null,
		))
	return list(
		"phase" = phase, "fault" = fault,
		"equipment_fault" = equipment_fault(),
		"pressure" = air ? round(air.return_pressure(), 0.1) : null,
		"temperature" = air ? round(air.temperature, 0.1) : null,
		"line_pressure" = line ? round(line.return_pressure(), 0.1) : null,
		"supply" = supply_enabled, "feeding" = inlet?.on,
		"feed_rate" = feed_rate, "ratio" = mixer ? mixer.node2_concentration * 100 : null,
		"engines" = engines,
	)

/obj/machinery/computer/ship_combustion/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !is_operational || panel_open)
		return
	switch(action)
		if("start")
			var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
			if(ship?.overmap)
				ship.overmap.set_engines_running(TRUE)
			else
				start_chamber()
		if("stop")
			stop_chamber()
		if("supply")
			supply_enabled = !supply_enabled
			if(!supply_enabled)
				stop_chamber()
		if("purge")
			if(phase != SHIP_CHAMBER_OFF && phase != SHIP_CHAMBER_LOCKED)
				return
			phase = SHIP_CHAMBER_PURGING
			deadline = world.time + 90 SECONDS
			stop_chamber()
			set_exhaust(TRUE)
		if("reset")
			if(phase != SHIP_CHAMBER_LOCKED || equipment_fault() || !purge_complete())
				return
			fault = null
			phase = SHIP_CHAMBER_OFF
		if("reconnect")
			if(phase != SHIP_CHAMBER_OFF && phase != SHIP_CHAMBER_LOCKED)
				return
			bind_equipment()
		if("ratio", "rate")
			var/value = params["value"]
			if(!IS_FINITE(value))
				return
			if(action == "rate")
				feed_rate = clamp(value, 0.1, 5)
			else
				var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
				mixer?.adjust_node1_value(100 - clamp(value, 1, 50))
		else
			return
	return TRUE

// AI EDIT END
