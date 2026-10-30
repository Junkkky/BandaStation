// AI EDIT START - native atmos combustion chamber control

/** Mapped glow plug; the controller heats through any linked igniter, so a crafted replacement works too. */
/obj/machinery/igniter/ship_engine
	name = "калильный воспламенитель"
	desc = "Электрический подогреватель для начального розжига бедной тритиевой смеси."

/** Stock multitool use sets the button ID, so the secondary action stores the igniter for console linking. */
/obj/machinery/igniter/multitool_act_secondary(mob/living/user, obj/item/multitool/multi_tool)
	balloon_alert(user, "сохранён в буфер")
	multi_tool.set_buffer(src)
	return ITEM_INTERACT_SUCCESS

/** Store the mixer for console linking, as stock injectors and vents already do. */
/obj/machinery/atmospherics/components/trinary/mixer/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	balloon_alert(user, "сохранён в буфер")
	multi_tool.set_buffer(src)
	return ITEM_INTERACT_SUCCESS

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
	/// Mixer output pressure setpoint, in kPa.
	var/mix_pressure = 2000
	/// Exhaust line pressure the siphon holds while the burner runs, in kPa.
	var/line_pressure = 1000
	/// Purge injector volume per native atmos cycle, in litres.
	var/purge_rate = MAX_TRANSFER_RATE
	/// Equipment roles and the device type each accepts.
	var/static/list/equipment_roles = list(
		"mixer" = /obj/machinery/atmospherics/components/trinary/mixer,
		"inlet" = /obj/machinery/atmospherics/components/unary/outlet_injector,
		"outlet" = /obj/machinery/atmospherics/components/unary/vent_pump,
		"purge" = /obj/machinery/atmospherics/components/unary/outlet_injector,
		"igniter" = /obj/machinery/igniter,
	)
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

/**
 * Fill missing roles from mapped id tags; never search the world during processing.
 *
 * Live links on this level are kept, so multitool replacements survive a reconnect.
 */
/obj/machinery/computer/ship_combustion/proc/bind_equipment()
	stop_chamber()
	if(length(chamber_id))
		for(var/role in equipment_roles)
			var/obj/machinery/current = device(role)
			if(current?.z == z)
				continue
			equipment -= role
			var/obj/machinery/machine = GLOB.objects_by_id_tag["[chamber_id]_[role]"]
			if(istype(machine, equipment_roles[role]) && machine.z == z)
				equipment[role] = WEAKREF(machine)
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	outlet?.disconnect_from_area()
	bind_propulsion()
	apply_settings()

/**
 * Link a multitool-buffered device to one role.
 *
 * The device must match the role, stand aboard this hull and not already serve another role.
 * Arguments:
 * * role - Key of [/obj/machinery/computer/ship_combustion/var/equipment_roles]
 * * machine - Device taken from the engineer's multitool buffer
 */
/obj/machinery/computer/ship_combustion/proc/link_device(role, obj/machinery/machine)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(QDELETED(machine) || !istype(machine, equipment_roles[role]) || machine.z != z || !ship?.shuttle_areas[get_area(machine)] || !ship.is_in_shuttle_bounds(machine))
		return FALSE
	for(var/other in equipment)
		if(other != role && device(other) == machine)
			return FALSE
	stop_chamber()
	equipment[role] = WEAKREF(machine)
	if(role == "outlet")
		var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = machine
		outlet.disconnect_from_area()
		bind_propulsion()
	apply_settings()
	return TRUE

/** Push engineer setpoints to the linked devices; called on link and change, not every tick. */
/obj/machinery/computer/ship_combustion/proc/apply_settings()
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	if(mixer)
		mixer.target_pressure = mix_pressure
	if(inlet)
		inlet.volume_rate = feed_rate
	if(phase == SHIP_CHAMBER_STARTING || phase == SHIP_CHAMBER_RUNNING || phase == SHIP_CHAMBER_PURGING)
		set_exhaust(phase == SHIP_CHAMBER_PURGING)

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
		if(!machine?.is_operational || machine.z != z)
			return "Оборудование отключено или повреждено"
	if(!mixer || !inlet || !outlet || !purge || !igniter)
		return "Оборудование не подключено"
	var/turf/open/inlet_tile = get_turf(inlet)
	if(!isopenturf(inlet_tile) || !isopenturf(outlet.loc) || !isopenturf(purge.loc) || get_dist(inlet, outlet) > 1)
		return "Нарушена компоновка камеры"
	// Checked directly: the cached atmos adjacency is empty until SSair rebuilds it after a hull move.
	var/turf/igniter_tile = igniter.loc
	if(igniter_tile != inlet_tile && (!isopenturf(igniter_tile) || !(get_dir(inlet_tile, igniter_tile) in GLOB.cardinals) || get_dist(inlet_tile, igniter_tile) != 1 \
		|| !CANATMOSPASS(inlet_tile, igniter_tile, FALSE) || !CANATMOSPASS(igniter_tile, inlet_tile, FALSE)))
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
	// A new prefix names a different installation, so drop every previous link.
	equipment.Cut()
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
	if(phase == SHIP_CHAMBER_STARTING || phase == SHIP_CHAMBER_RUNNING || (reason && phase == SHIP_CHAMBER_OFF))
		if(reason)
			phase = SHIP_CHAMBER_PURGING
			deadline = world.time + 90 SECONDS
			set_exhaust(TRUE)
		else
			phase = SHIP_CHAMBER_OFF
			var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
			var/obj/machinery/atmospherics/components/unary/outlet_injector/purge = device("purge")
			outlet?.set_on(FALSE)
			purge?.set_on(FALSE)
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
		outlet.internal_pressure_bound = purging ? 2000 : line_pressure
		outlet.external_pressure_bound = purging ? 0 : 20
		outlet.set_on(TRUE)
	if(purge)
		purge.volume_rate = purge_rate
		// A running burner needs a continuous exhaust even at idle or with a full nozzle manifold.
		purge.set_on(purging || phase == SHIP_CHAMBER_STARTING || phase == SHIP_CHAMBER_RUNNING)

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
	if(air.return_pressure() > 1500 || air.temperature > 30000)
		fault = "Камера не готова к запуску; требуется продувка"
		phase = SHIP_CHAMBER_LOCKED
		return FALSE
	flame_confirmed = FALSE
	ignition_air = WEAKREF(air)
	RegisterSignal(air, COMSIG_GASMIX_REACTED, PROC_REF(on_chamber_reacted))
	ready_at = world.time + (air.temperature >= TRITIUM_MINIMUM_BURN_TEMPERATURE ? 5 SECONDS : 10 SECONDS)
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
	if(phase == SHIP_CHAMBER_LOCKED)
		return
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	// Native hull movement yields while the equipment is split between levels.
	if(ship?.overmap?.relocating)
		return
	// Entering the purge already isolated the feed and opened the exhaust.
	if(phase == SHIP_CHAMBER_PURGING)
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
	if(reason || (!supply_enabled && phase != SHIP_CHAMBER_OFF))
		if(phase != SHIP_CHAMBER_OFF)
			stop_chamber(reason)
		return
	var/obj/machinery/atmospherics/components/unary/outlet_injector/inlet = device("inlet")
	var/datum/gas_mixture/air = inlet.loc.return_air()
	var/obj/machinery/atmospherics/components/unary/vent_pump/outlet = device("outlet")
	var/datum/gas_mixture/line = outlet.airs[1]
	if(air.return_pressure() > 1500)
		stop_chamber("Избыточное давление камеры: [round(air.return_pressure())] кПа")
		return
	if(line.return_pressure() > 4000)
		stop_chamber("Избыточное давление магистрали: [round(line.return_pressure())] кПа")
		return
	if(air.temperature > 30000)
		stop_chamber("Перегрев камеры: [round(air.temperature)] K")
		return
	if(phase == SHIP_CHAMBER_OFF)
		return
	if(phase == SHIP_CHAMBER_STARTING)
		heat_chamber(seconds_per_tick)
		if(flame_confirmed && world.time >= ready_at && air.temperature >= SHIP_ENGINE_OPERATING_TEMPERATURE)
			phase = SHIP_CHAMBER_RUNNING
			set_exhaust(FALSE)
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
	var/feeding = air.return_pressure() < 400 && air.temperature < 20000 && line.return_pressure() < outlet.internal_pressure_bound - 10
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	mixer.set_on(feeding)
	inlet.set_on(feeding)

/** Glow-plug heating through the linked igniter's own power supply; stock spark alone cannot light a lean mixture. */
/obj/machinery/computer/ship_combustion/proc/heat_chamber(seconds_per_tick)
	var/obj/machinery/igniter/igniter = device("igniter")
	if(!igniter?.on || !igniter.is_operational || seconds_per_tick <= 0 || !isopenturf(igniter.loc))
		return
	var/turf/open/chamber = igniter.loc
	var/datum/gas_mixture/air = chamber.return_air()
	if(!air?.total_moles() || air.temperature >= SHIP_ENGINE_OPERATING_TEMPERATURE)
		return
	var/capacity = air.heat_capacity()
	var/heat = min((SHIP_ENGINE_OPERATING_TEMPERATURE - air.temperature) * capacity, 100 KILO WATTS * seconds_per_tick)
	heat = igniter.use_energy(heat, force = FALSE)
	if(heat > 0)
		air.set_temperature(air.temperature + heat / capacity)
		chamber.air_update_turf()

/obj/machinery/computer/ship_combustion/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCombustion", name)
		ui.open()

/** Count each real supply mixture once, including canisters behind inlet pumps. */
/obj/machinery/computer/ship_combustion/proc/fuel_reserve()
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
	var/list/networks = list()
	var/list/mixtures = list()
	for(var/input in 1 to 2)
		var/datum/pipeline/network = mixer?.parents[input]
		if(network)
			networks |= network
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
	var/tritium = 0
	var/oxygen = 0
	for(var/datum/gas_mixture/mixture as anything in mixtures)
		tritium += mixture.moles[/datum/gas/tritium]
		oxygen += mixture.moles[/datum/gas/oxygen]
	return list("tritium" = round(tritium, 0.1), "oxygen" = round(oxygen, 0.1))

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
		var/output = round((feed?.propulsion_fraction() || 0) * 100, 0.1)
		var/reason = feed ? feed.unavailable_reason() : "Приёмник не подключён"
		engines += list(list(
			"id" = REF(engine), "number" = length(engines) + 1,
			"position" = "[engine.x - ship.x] / [engine.y - ship.y]",
			"status" = reason || (ship.engines_running ? (output >= 100 ? "Работает" : "Ограниченная тяга") : "Готов"),
			"output" = output,
			"temperature" = supply ? round(supply.temperature, 0.1) : null,
			"pressure" = supply ? round(supply.return_pressure(), 0.1) : null,
		))
	var/list/settings = list(
		"mixer" = list(mix_pressure, MAX_OUTPUT_PRESSURE, "кПа"),
		"inlet" = list(feed_rate, MAX_TRANSFER_RATE, "л/цикл"),
		"outlet" = list(line_pressure, ATMOS_PUMP_MAX_PRESSURE, "кПа"),
		"purge" = list(purge_rate, MAX_TRANSFER_RATE, "л/цикл"),
	)
	var/list/devices = list()
	for(var/role in equipment_roles)
		var/obj/machinery/machine = device(role)
		var/obj/machinery/igniter/igniter = machine
		var/obj/machinery/atmospherics/atmos_device = machine
		var/status = "Не подключено"
		if(machine)
			if(machine.z != z)
				status = "Нет связи"
			else if(machine.machine_stat & BROKEN)
				status = "Повреждено"
			else if(!machine.is_operational)
				status = "Нет питания"
			else
				status = (istype(igniter) ? igniter.on : atmos_device.on) ? "Включено" : "Выключено"
		var/list/setting = settings[role]
		devices += list(list(
			"role" = role, "name" = machine?.name, "status" = status,
			"value" = setting?[1], "max" = setting?[2], "unit" = setting?[3],
		))
	return list(
		"phase" = phase, "fault" = fault,
		"equipment_fault" = equipment_fault(),
		"pressure" = air ? round(air.return_pressure(), 0.1) : null,
		"temperature" = air ? round(air.temperature, 0.1) : null,
		"line_pressure" = line ? round(line.return_pressure(), 0.1) : null,
		"supply" = supply_enabled, "feeding" = inlet?.on,
		"ratio" = mixer ? mixer.node2_concentration * 100 : null,
		"fuel" = fuel_reserve(),
		"engines" = engines,
		"devices" = devices,
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
		if("link")
			var/role = params["role"]
			if(!istext(role) || !equipment_roles[role] || (phase != SHIP_CHAMBER_OFF && phase != SHIP_CHAMBER_LOCKED))
				return
			var/obj/item/multitool/tool = ui.user.get_active_held_item()
			if(!istype(tool))
				balloon_alert(ui.user, "нужен мультитул в руке!")
				return
			if(!link_device(role, tool.buffer))
				balloon_alert(ui.user, "устройство не подходит!")
				return
			balloon_alert(ui.user, "подключено")
		if("setting")
			var/value = params["value"]
			if(!IS_FINITE(value))
				return
			switch(params["role"])
				if("mixer")
					mix_pressure = clamp(value, 0, MAX_OUTPUT_PRESSURE)
				if("inlet")
					feed_rate = clamp(value, 0, MAX_TRANSFER_RATE)
				if("outlet")
					line_pressure = clamp(value, 0, ATMOS_PUMP_MAX_PRESSURE)
				if("purge")
					purge_rate = clamp(value, 0, MAX_TRANSFER_RATE)
				else
					return
			apply_settings()
		if("ratio", "oxygen_ratio")
			var/value = params["value"]
			if(!IS_FINITE(value))
				return
			var/obj/machinery/atmospherics/components/trinary/mixer/mixer = device("mixer")
			mixer?.adjust_node1_value(action == "oxygen_ratio" ? clamp(value, 50, 99) : 100 - clamp(value, 1, 50))
		else
			return
	return TRUE

// AI EDIT END
