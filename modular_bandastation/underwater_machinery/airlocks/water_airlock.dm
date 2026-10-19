/** A separately mapped chamber keeps level checks local and belongs to its vessel. */
/area/shuttle/stationtrauma/water_airlock
	name = "StationTrauma: шлюзовая камера"

/** Route fixtures have power without a separate chamber APC; production chambers require their own supply. */
/area/shuttle/stationtrauma/water_airlock/test
	requires_power = FALSE

/** A wall button sequences two mechanical doors and existing piped pumps in a dedicated chamber area. */
/obj/machinery/button/stationtrauma_water_airlock
	name = "контроллер водяного шлюза"
	desc = "Управляет заполнением и осушением шлюзовой камеры. Вентиль на гермодвери отменяет автоматику и позволяет открыть её вручную."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "button-warning"
	skin = "-warning"
	processing_flags = NONE
	can_alter_skin = FALSE
	/// Object tags, rather than an area-wide pump group, isolate this one circuit.
	var/inner_tag
	var/outer_tag
	var/source_tag
	var/inlet_tag
	var/drain_tag
	var/discharge_tag
	/// Resolved once on map initialization; destroyed equipment cancels the cycle.
	var/obj/machinery/door/airlock/highsecurity/underwater/inner
	var/obj/machinery/door/airlock/highsecurity/underwater/outer
	var/obj/machinery/bilge_pump/ocean_intake/source_pump
	var/obj/machinery/stationtrauma_water_device/outlet/universal/inlet
	var/obj/machinery/bilge_pump/drain
	var/obj/machinery/stationtrauma_water_device/outlet/universal/discharge
	/// Only the small mapped chamber footprint is inspected during an active cycle.
	var/list/chamber = list()
	/// No processing or command queue exists between cycles.
	var/cycling = FALSE
	var/filling = FALSE
	var/closing = FALSE
	/// A cancelled sleeping door close cannot finish a newer cycle.
	var/cycle_revision = 0
	/// Stalled pipes or a missing wall must not leave an endless automatic job.
	var/deadline = 0
	var/cycle_timeout = 2 MINUTES
	/// Human-readable state also explains faults through examination.
	var/status = "Готово"

/obj/machinery/button/stationtrauma_water_airlock/Initialize(mapload)
	. = ..()
	RegisterSignals(src, list(COMSIG_MACHINERY_POWER_LOST, COMSIG_MACHINERY_BROKEN), PROC_REF(equipment_failed))

/obj/machinery/button/stationtrauma_water_airlock/post_machine_initialize()
	. = ..()
	if(!link_equipment())
		stop_cycle("Не подключено оборудование")

/** Resolve and validate explicit mapper links; unrelated pumps never receive commands. */
/obj/machinery/button/stationtrauma_water_airlock/proc/link_equipment()
	inner = GLOB.objects_by_id_tag[inner_tag]
	outer = GLOB.objects_by_id_tag[outer_tag]
	source_pump = GLOB.objects_by_id_tag[source_tag]
	inlet = GLOB.objects_by_id_tag[inlet_tag]
	drain = GLOB.objects_by_id_tag[drain_tag]
	discharge = GLOB.objects_by_id_tag[discharge_tag]
	if(!istype(inner) || !istype(outer) || inner == outer || !istype(source_pump) || !istype(inlet) || !istype(drain) || istype(drain, /obj/machinery/bilge_pump/ocean_intake) || !istype(discharge) || inlet == discharge)
		return FALSE
	if((inner.water_airlock && inner.water_airlock != src) || (outer.water_airlock && outer.water_airlock != src))
		return FALSE
	for(var/obj/machinery/device as anything in list(inner, outer, source_pump, inlet, drain, discharge))
		if(device.z != z)
			return FALSE
	if(!read_chamber())
		return FALSE
	inner.water_airlock = src
	outer.water_airlock = src
	for(var/obj/machinery/device as anything in list(inner, outer, source_pump, inlet, drain, discharge))
		RegisterSignals(device, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_MACHINERY_BROKEN), PROC_REF(equipment_failed), override = TRUE)
	return TRUE

/** Read the chamber's current small footprint once before each new cycle. */
/obj/machinery/button/stationtrauma_water_airlock/proc/read_chamber()
	chamber.Cut()
	if(QDELETED(inner) || QDELETED(outer) || QDELETED(inlet) || QDELETED(drain))
		return FALSE
	for(var/turf/open/floor as anything in get_area(src))
		if(isopenturf(floor) && !isspaceturf(floor) && !floor.closed_stationtrauma_water_door() && !floor.sealed_stationtrauma_water_window())
			chamber += floor
	if(!chamber.len || chamber.len > 64 || !(get_turf(src) in chamber) || !(get_turf(inlet) in chamber) || !(get_turf(drain) in chamber))
		return FALSE
	for(var/obj/machinery/door/airlock/highsecurity/underwater/door as anything in list(inner, outer))
		var/adjacent = FALSE
		for(var/direction in GLOB.cardinals)
			if(get_step(door, direction) in chamber)
				adjacent = TRUE
		if(!adjacent || door.z != z)
			return FALSE
	return TRUE

/obj/machinery/button/stationtrauma_water_airlock/Destroy()
	stop_cycle("Контроллер отключён")
	if(istype(inner) && inner.water_airlock == src)
		inner.water_airlock = null
	if(istype(outer) && outer.water_airlock == src)
		outer.water_airlock = null
	return ..()

/obj/machinery/button/stationtrauma_water_airlock/attempt_press(mob/user, require_id_check = TRUE)
	if(!cycle_available(user) || !..())
		return FALSE
	return request_cycle(null, user)

/obj/machinery/button/stationtrauma_water_airlock/examine(mob/user)
	. = ..()
	. += span_notice("[status].")

/// The parent button already registers native hover context and retains its maintenance hints.
/obj/machinery/button/stationtrauma_water_airlock/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!held_item && !panel_open)
		context[SCREENTIP_CONTEXT_LMB] = cycling ? "Идёт шлюзование" : "Заполнить / осушить камеру"
		return CONTEXTUAL_SCREENTIP_SET

/** Reject partial chambers and busy cycles before accepting button feedback or a remote command. */
/obj/machinery/button/stationtrauma_water_airlock/proc/cycle_available(mob/user)
	if(cycling)
		balloon_alert(user, "цикл уже выполняется")
		return FALSE
	if(!is_operational || !istype(inner) || !istype(outer) || QDELETED(inner) || QDELETED(outer) || inner.water_airlock != src || outer.water_airlock != src || !read_chamber())
		balloon_alert(user, "контроллер недоступен")
		return FALSE
	var/dry = TRUE
	var/full = TRUE
	for(var/turf/open/tile as anything in chamber)
		var/depth = tile.get_water_depth()
		dry = dry && !depth
		full = full && depth * FLOOD_WATER_LITRES_PER_CM >= FLOOD_WATER_MAX_DEPTH * FLOOD_WATER_LITRES_PER_CM - FLOOD_WATER_FULL_TOLERANCE
	if(!dry && !full)
		balloon_alert(user, "камера должна быть сухой или полной")
		return FALSE
	return TRUE

/** Start one explicit request; a second button press never reverses or queues an active cycle. */
/obj/machinery/button/stationtrauma_water_airlock/proc/request_cycle(fill, mob/user)
	if(!cycle_available(user))
		return FALSE
	var/turf/open/sensor = chamber[1]
	filling = isnull(fill) ? !sensor.get_water_depth() : fill
	cycling = TRUE
	cycle_revision++
	closing = TRUE
	deadline = world.time + cycle_timeout
	set_pumps(FALSE, FALSE)
	set_status("Закрытие дверей", LIGHT_COLOR_BRIGHT_YELLOW)
	begin_processing()
	INVOKE_ASYNC(src, PROC_REF(close_doors), cycle_revision)
	return TRUE

/** Native safe closing can sleep or fail on an obstruction; pumps stay off until both doors settle. */
/obj/machinery/button/stationtrauma_water_airlock/proc/close_doors(revision)
	for(var/obj/machinery/door/airlock/highsecurity/underwater/door as anything in list(inner, outer))
		if(!cycling || revision != cycle_revision)
			return
		if(!is_operational || QDELETED(door) || !door.close())
			if(revision == cycle_revision)
				stop_cycle("Не удалось закрыть двери")
			return
		if(!cycling || revision != cycle_revision)
			return
	for(var/obj/machinery/door/airlock/highsecurity/underwater/door as anything in list(inner, outer))
		if(!door.turn_handwheel(TRUE, src, revision))
			if(revision == cycle_revision)
				stop_cycle("Не удалось закрыть вентиль")
			return
	closing = FALSE

/** Mechanical dogs remain as they are on failure; only a successful cycle releases its destination. */
/obj/machinery/button/stationtrauma_water_airlock/proc/stop_cycle(reason)
	cycling = FALSE
	cycle_revision++
	closing = FALSE
	set_pumps(FALSE, FALSE)
	end_processing()
	set_status(reason, LIGHT_COLOR_INTENSE_RED)

/obj/machinery/button/stationtrauma_water_airlock/proc/equipment_failed()
	SIGNAL_HANDLER
	stop_cycle("Питание или оборудование недоступно")

/** The controller changes pump switches, never the permanent openness of floor/outboard outlets. */
/obj/machinery/button/stationtrauma_water_airlock/proc/set_pumps(fill_on, drain_on)
	if(!istype(inner) || !istype(outer) || inner.water_airlock != src || outer.water_airlock != src)
		return
	for(var/obj/machinery/bilge_pump/pump as anything in list(source_pump, drain))
		if(!istype(pump) || QDELETED(pump))
			continue
		var/enabled = pump == source_pump ? fill_on : drain_on
		if(pump.on == enabled)
			continue
		pump.on = enabled
		pump.update_appearance(UPDATE_ICON)

/** Redraw only state transitions, not every machinery tick. */
/obj/machinery/button/stationtrauma_water_airlock/proc/set_status(message, indicator)
	if(status == message && light_color == indicator)
		return
	status = message
	light_color = indicator
	update_appearance()

/** Locate the real ocean beyond the outer door; z is a deck index, never a pressure estimate. */
/obj/machinery/button/stationtrauma_water_airlock/proc/outside_water()
	RETURN_TYPE(/datum/component/floodwater)
	var/turf/open/door_floor = get_turf(outer)
	for(var/direction in GLOB.cardinals)
		var/turf/open/tile = get_step(door_floor, direction)
		var/datum/component/floodwater/water = tile?.GetComponent(/datum/component/floodwater)
		if(water?.infinite_source && door_floor.can_pass_stationtrauma_water(tile, outer))
			return water
	return null

/** A bounded chamber check rejects a breached hull or another open passage before pumping/unlocking. */
/obj/machinery/button/stationtrauma_water_airlock/proc/chamber_sealed()
	for(var/turf/open/tile as anything in chamber)
		if(!isopenturf(tile) || isspaceturf(tile) || tile.blocks_air)
			return FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(tile, direction)
			if(!(neighbor in chamber) && tile.can_pass_stationtrauma_water(neighbor))
				return FALSE
	return TRUE

/obj/machinery/button/stationtrauma_water_airlock/process(seconds_per_tick)
	if(!cycling)
		return PROCESS_KILL
	if(!is_operational || world.time >= deadline)
		stop_cycle("Цикл остановлен: питание или превышение времени")
		return PROCESS_KILL
	if(closing)
		return
	if(QDELETED(inner) || QDELETED(outer) || !inner.density || !outer.density || inner.operating || outer.operating || !inner.handwheel_locked || !outer.handwheel_locked || !chamber_sealed())
		stop_cycle("Нарушена герметичность камеры")
		return PROCESS_KILL
	if(QDELETED(source_pump) || QDELETED(inlet) || QDELETED(drain) || QDELETED(discharge) || !source_pump.anchored || !drain.anchored || !inlet.anchored || !discharge.anchored || !source_pump.is_operational || !drain.is_operational || (inlet.machine_stat & BROKEN) || (discharge.machine_stat & BROKEN))
		stop_cycle("Насосы или трубное оборудование недоступны")
		return PROCESS_KILL
	var/datum/component/floodwater/ocean = outside_water()
	var/datum/component/floodwater/supply = source_pump.loc.GetComponent(/datum/component/floodwater)
	var/datum/component/floodwater/sink = discharge.loc.GetComponent(/datum/component/floodwater)
	if(!ocean || !supply?.infinite_source || !sink?.infinite_source)
		stop_cycle("Забор или сброс не связан с океаном")
		return PROCESS_KILL
	if(filling)
		set_pumps(TRUE, FALSE)
		var/datum/floodwater_front_cell/contact = SSfloodwater.ensure_water_domain(get_turf(inlet))
		var/datum/floodwater_front_group/owner = contact.root()
		if(!owner?.is_full() || owner.members.len != chamber.len)
			set_status("Заполнение камеры", LIGHT_COLOR_BLUE)
			return
		set_status("Выравнивание напора", LIGHT_COLOR_BLUE)
		if(source_pump.water_pressure * 100 < ocean.reservoir_pressure || inlet.water_pressure * 100 < ocean.reservoir_pressure)
			return
		equalize_head(contact, ocean.reservoir_pressure, min(inlet.flow_rate, source_pump.drain_rate * FLOOD_WATER_LITRES_PER_CM) * seconds_per_tick)
		if(abs(contact.head_pressure() - ocean.reservoir_pressure) > FLOOD_WATER_HEAD_EPSILON)
			return
	else
		set_status("Осушение камеры", LIGHT_COLOR_BRIGHT_YELLOW)
		set_pumps(FALSE, TRUE)
		// The floor outlet stays open: its finite tail must drain too before admitting the dry side.
		if(inlet.reagents.get_reagent_amount(/datum/reagent/water) || drain.reagents.get_reagent_amount(/datum/reagent/water) || discharge.reagents.get_reagent_amount(/datum/reagent/water))
			return
		for(var/turf/open/tile as anything in chamber)
			if(tile.get_water_depth() > 0)
				return
		for(var/obj/machinery/door/airlock/highsecurity/underwater/door as anything in list(inner, outer))
			var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid.by_turf[get_turf(door)]
			if(cell?.displaced_volume > 0)
				return
	set_pumps(FALSE, FALSE)
	closing = TRUE
	INVOKE_ASYNC(src, PROC_REF(release_door), cycle_revision)

/** The cycle stays busy through the final wheel turn, so repeated presses cannot overlap it. */
/obj/machinery/button/stationtrauma_water_airlock/proc/release_door(revision)
	var/obj/machinery/door/airlock/highsecurity/underwater/destination = filling ? outer : inner
	if(!destination.turn_handwheel(FALSE, src, revision))
		if(revision == cycle_revision)
			stop_cycle("Не удалось открыть вентиль")
		return
	cycling = FALSE
	closing = FALSE
	end_processing()
	set_status(filling ? "Готово к выходу в океан" : "Готово к входу в лодку", LIGHT_COLOR_GREEN)

/** Exchange real pipe litres for the same amount of chamber water; pressure follows accepted work only. */
/obj/machinery/button/stationtrauma_water_airlock/proc/equalize_head(datum/floodwater_front_cell/contact, target, volume)
	var/datum/floodwater_front_group/owner = contact.root()
	var/before = contact.head_pressure()
	var/difference = target - before
	if(!owner?.is_full() || abs(difference) <= FLOOD_WATER_HEAD_EPSILON)
		return 0
	// A final sub-centilitre of head work must not strand a full chamber above the ready tolerance.
	var/amount = min(volume, owner.volume, CEILING(abs(difference) * owner.volume / FLOOD_WATER_HEAD_STIFFNESS, CHEMICAL_QUANTISATION_LEVEL))
	amount = stationtrauma_water_transfer_amount(inlet.reagents, amount, drain.reagents.maximum_volume - drain.reagents.total_volume)
	if(amount <= 0)
		return 0
	amount = store_stationtrauma_water(drain.reagents, amount)
	if(!amount)
		return 0
	inlet.reagents.remove_reagent(/datum/reagent/water, amount)
	owner.pressure_head = before
	owner.shift_head(min(abs(difference), FLOOD_WATER_HEAD_STIFFNESS * amount / owner.volume) * (difference > 0 ? 1 : -1))
	return amount

/** Fixed-purpose remote buttons summon a dry chamber from inside or a wet chamber from the ocean. */
/obj/machinery/button/stationtrauma_water_airlock_remote
	name = "кнопка осушения шлюза"
	desc = "Закрывает обе гермодвери и осушает камеру для входа из лодки."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "button-warning"
	skin = "-warning"
	can_alter_skin = FALSE
	/// Tag of the chamber's main wall button.
	var/controller_tag
	/// FALSE requests drainage; the ocean-side variant requests filling.
	var/fill = FALSE

/obj/machinery/button/stationtrauma_water_airlock_remote/attempt_press(mob/user, require_id_check = TRUE)
	var/obj/machinery/button/stationtrauma_water_airlock/controller = GLOB.objects_by_id_tag[controller_tag]
	if(!istype(controller) || QDELETED(controller) || controller.z != z)
		balloon_alert(user, "контроллер недоступен")
		return FALSE
	if(!controller.cycle_available(user) || !..())
		return FALSE
	return controller.request_cycle(fill, user)

/// Name the remote button's fixed action in the same hover HUD as the chamber controller.
/obj/machinery/button/stationtrauma_water_airlock_remote/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!held_item && !panel_open)
		context[SCREENTIP_CONTEXT_LMB] = fill ? "Заполнить шлюз" : "Осушить шлюз"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/button/stationtrauma_water_airlock_remote/fill
	name = "кнопка заполнения шлюза"
	desc = "Закрывает обе гермодвери и заполняет камеру для входа из океана."
	fill = TRUE

/** A flasher-style button uses the native airlock ID controller without overriding mechanical locks. */
/obj/machinery/button/door/stationtrauma
	name = "кнопка гермодвери"
	desc = "Открывает или закрывает гермодверь с соответствующим ID. Механический запор открывается вентилем на самой двери."
	icon_state = "button-warning"
	skin = "-warning"
	can_alter_skin = FALSE
	normaldoorcontrol = TRUE

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/button/door/stationtrauma, 24)
MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/button/stationtrauma_water_airlock, 24)
MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/button/stationtrauma_water_airlock_remote, 24)
MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/button/stationtrauma_water_airlock_remote/fill, 24)
