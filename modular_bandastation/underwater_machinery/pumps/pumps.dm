/// Water reaches the intake through the existing floodwater flow, never through sealed walls.
/obj/machinery/bilge_pump
	name = "трюмная помпа"
	desc = "Собирает воду в трубный буфер. Включается контроллером помп; ЛКМ открывает контроллер своей зоны и группы. Требует АПЦ; осушает связанный отсек до нуля. Выход водяной трубы — на юге."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "active_input"
	density = FALSE
	idle_power_usage = 5
	processing_flags = NONE
	/// One cm/s corresponds to ten litres per second across the local intake.
	var/drain_rate = 180
	var/water_pressure = 80
	var/on = FALSE
	var/residual_depth = 0
	var/buffer_capacity = 10000
	var/control_group = "water"
	var/water_level = 3
	var/plumbing_type = /datum/component/plumbing/stationtrauma_water/supply
	var/turf/water_geometry_location
	var/list/suction_geometry
	var/list/drain_geometry
	var/list/drain_building
	var/list/drain_queue
	var/drain_cursor = 1
	var/list/drain_water = list()
	var/list/water_geometry_watchers = list()

/obj/machinery/bilge_pump/Initialize(mapload, new_level)
	if(new_level in 1 to 5)
		water_level = new_level
	. = ..()
	create_reagents(buffer_capacity, NO_REACT)
	SSfloodwater.pumps += src
	if(plumbing_type)
		AddComponent(plumbing_type, STATIONTRAUMA_WATER_LAYER_BIT(water_level))
	if(!istype(src, /obj/machinery/bilge_pump/portable))
		AddElement(/datum/element/simple_rotation)

/obj/machinery/bilge_pump/Destroy()
	invalidate_water_geometry()
	SSfloodwater.pumps -= src
	release_stationtrauma_water(src)
	return ..()

/obj/machinery/bilge_pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	control_pump(user)

/obj/machinery/bilge_pump/proc/control_pump(mob/living/user)
	for(var/obj/machinery/stationtrauma_pump_controller/controller as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/stationtrauma_pump_controller))
		if(get_area(controller) == get_area(src) && controller.control_group == control_group)
			controller.ui_interact(user)
			return
	balloon_alert(user, "нужен контроллер")

/obj/machinery/bilge_pump/proc/toggle_pump(mob/living/user)
	on = !on
	if(on)
		begin_processing()
	else
		end_processing()
	balloon_alert(user, on ? "включена" : "выключена")
	update_appearance()

/obj/machinery/bilge_pump/examine(mob/user)
	. = ..()
	. += span_notice("Помпа [on ? "включена" : "выключена"]. Расход: [drain_rate * FLOOD_WATER_LITRES_PER_CM] л/с; уровень труб [water_level].")
	. += span_notice("Буфер: [round(reagents.total_volume, 0.1)] / [reagents.maximum_volume] л; [round(reagents.chem_temp - T0C, 0.1)] °C. Выход подключается к водяным трубам.")

/obj/machinery/bilge_pump/proc/draw_pump_energy(seconds_per_tick)
	if(!is_operational)
		return FALSE
	var/required_energy = 1200 * seconds_per_tick
	return use_energy(required_energy, force = FALSE) >= required_energy

/obj/machinery/bilge_pump/process(seconds_per_tick)
	return PROCESS_KILL

/// The water subsystem meters intake alongside flow, avoiding multi-second machinery bursts.
/obj/machinery/bilge_pump/proc/collect_water(seconds_per_tick)
	if(!can_collect_water())
		return
	var/turf/open/intake = loc
	var/list/room = intake.stationtrauma_water_intake()
	var/has_water = FALSE
	var/deepest = 0
	for(var/turf/open/tile as anything in room)
		var/depth = tile.get_water_depth()
		if(depth > residual_depth)
			has_water = TRUE
		deepest = max(deepest, depth)
	if(!residual_depth && deepest < 1)
		if(!get_water_geometry())
			return
		var/only_tail = TRUE
		for(var/turf/open/tile as anything in drain_water)
			var/datum/component/floodwater/water = drain_water[tile]
			if(!QDELETED(water) && water.depth >= 1)
				only_tail = FALSE
				break
		if(only_tail)
			// Bound component updates too: deleting a whole wet compartment in one call stalls the MC.
			room = drain_water.Copy(1, min(length(drain_water) + 1, 65))
			if(!length(room) || !draw_pump_energy(seconds_per_tick))
				return
			var/remaining = drain_rate * seconds_per_tick * FLOOD_WATER_LITRES_PER_CM
			// Empty complete films first; proportional withdrawal keeps recreating the same thin components.
			for(var/turf/open/tile as anything in room)
				remaining -= drain_stationtrauma_water_room(intake, remaining, reagents, 0, list(tile))
				if(remaining <= 0 || reagents.holder_full())
					break
			return
	if(has_water && draw_pump_energy(seconds_per_tick))
		drain_stationtrauma_water_room(intake, drain_rate * seconds_per_tick * FLOOD_WATER_LITRES_PER_CM, reagents, residual_depth, room)

/obj/machinery/bilge_pump/proc/can_collect_water()
	if(!on || !is_operational || drain_rate <= 0 || !isopenturf(loc) || reagents.holder_full())
		return FALSE
	var/datum/component/floodwater/water = loc.GetComponent(/datum/component/floodwater)
	if(water?.infinite_source)
		return FALSE
	if(istype(src, /obj/machinery/bilge_pump/portable))
		var/obj/machinery/bilge_pump/portable/portable = src
		return !portable.port && !portable.discharging && !portable.panel_open && portable.cell?.charge > 0
	return anchored

/// Cache only connectivity and distances; depths are read anew for every collection.
/obj/machinery/bilge_pump/proc/get_water_geometry(max_distance = null)
	if(water_geometry_location != loc)
		invalidate_water_geometry()
		water_geometry_location = loc
	if(isnull(max_distance))
		if(!drain_geometry)
			var/turf/open/intake = loc
			drain_geometry = intake.stationtrauma_water_room(null, src)
		return drain_geometry
	if(!suction_geometry)
		var/turf/open/intake = loc
		suction_geometry = intake.stationtrauma_water_room(max_distance, src)
	return suction_geometry

/obj/machinery/bilge_pump/proc/watch_water_geometry(turf/tile)
	if(!tile || water_geometry_watchers[tile])
		return
	water_geometry_watchers[tile] = TRUE
	RegisterSignals(tile, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_TURF_CHANGE, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED, COMSIG_ATOM_DENSITY_CHANGED), PROC_REF(invalidate_water_geometry))
	RegisterSignals(tile, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(on_water_geometry_obstacle))
	RegisterSignal(tile, COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED, PROC_REF(on_water_presence))
	for(var/obj/obstacle in tile)
		if(obstacle.can_atmos_pass == ATMOS_PASS_YES || water_geometry_watchers[obstacle])
			continue
		water_geometry_watchers[obstacle] = TRUE
		RegisterSignals(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING), PROC_REF(invalidate_water_geometry))

/obj/machinery/bilge_pump/proc/on_water_geometry_obstacle(datum/source, atom/movable/obstacle)
	SIGNAL_HANDLER
	if(isobj(obstacle) && obstacle.can_atmos_pass != ATMOS_PASS_YES)
		invalidate_water_geometry()

/obj/machinery/bilge_pump/proc/on_water_presence(turf/tile, datum/component/floodwater/water, present)
	SIGNAL_HANDLER
	var/list/geometry = drain_geometry || drain_building
	if(!geometry || isnull(geometry[tile]))
		return
	if(present && !water.infinite_source)
		drain_water[tile] = water
	else
		drain_water -= tile

/obj/machinery/bilge_pump/proc/invalidate_water_geometry(datum/source)
	SIGNAL_HANDLER
	suction_geometry = null
	drain_geometry = null
	drain_building = null
	drain_queue = null
	drain_cursor = 1
	drain_water.Cut()
	water_geometry_location = null
	for(var/datum/watched as anything in water_geometry_watchers)
		UnregisterSignal(watched, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_TURF_CHANGE, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED, COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED, COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_QDELETING))
	water_geometry_watchers.Cut()

/obj/machinery/bilge_pump/plumbed
	name = "трюмная помпа с трубным выходом"

/obj/machinery/bilge_pump/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/machinery/bilge_pump/portable
	name = "аварийный насос"
	desc = "Переносной насос с баком 200 л и аккумулятором. Собирает воду без крепления и направления. Для сброса в трубы поставьте на водяной порт и подключите ключом. ЛКМ — сбор или сброс; отвёртка — отсек батареи."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/liquid_pump.dmi'
	icon_state = "liquid_pump"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	drain_rate = 8
	residual_depth = 0
	buffer_capacity = 200
	control_group = "portable"
	plumbing_type = null
	var/obj/item/stock_parts/power_store/cell/cell
	var/obj/machinery/stationtrauma_water_device/connector/port
	var/discharging = FALSE

/obj/machinery/bilge_pump/portable/Initialize(mapload, new_level)
	. = ..()
	cell = new /obj/item/stock_parts/power_store/cell/high(src)

/obj/machinery/bilge_pump/portable/Destroy()
	disconnect_port()
	QDEL_NULL(cell)
	return ..()

/obj/machinery/bilge_pump/portable/get_cell()
	return cell

/obj/machinery/bilge_pump/portable/control_pump(mob/living/user)
	var/status = discharging ? "сброс в порт" : !on ? "выключен" : reagents.holder_full() ? "бак заполнен" : panel_open ? "отсек батареи открыт" : !is_operational ? "неисправен" : !cell?.charge ? "нет заряда" : "сбор"
	var/choice = tgui_input_list(user, "Режим: [status]. Бак: [round(reagents.total_volume, 0.1)] / 200 л, [round(reagents.chem_temp - T0C, 0.1)] °C. Заряд: [cell ? round(cell.percent()) : 0]%. Порт: [port ? "подключён" : "нет"].", name, list("Сбор воды", "Сброс в порт", "Выключить", "Слить рядом"))
	if(QDELETED(src) || !choice || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return
	if(choice == "Слить рядом")
		prompt_stationtrauma_water_drain(src, user)
	else
		set_mode(choice == "Сбор воды", choice == "Сброс в порт")

/obj/machinery/bilge_pump/portable/proc/set_mode(collecting, discharge)
	discharging = discharge && !QDELETED(port)
	on = collecting && !port
	if(on || discharging)
		begin_processing()
	else
		end_processing()
	update_appearance()

/obj/machinery/bilge_pump/portable/process(seconds_per_tick)
	if(discharging)
		if(!port || !reagents.total_volume || !draw_pump_energy(seconds_per_tick))
			set_mode(FALSE, FALSE)
		return
	if(port)
		return
	return ..()

/obj/machinery/bilge_pump/portable/collect_water(seconds_per_tick)
	if(port || discharging)
		return
	return ..()

/obj/machinery/bilge_pump/portable/proc/connect_port()
	for(var/obj/machinery/stationtrauma_water_device/connector/candidate in loc)
		if(candidate.attach(src))
			port = candidate
			set_mode(FALSE, FALSE)
			set_anchored(TRUE)
			return TRUE
	return FALSE

/obj/machinery/bilge_pump/portable/proc/disconnect_port()
	port?.detach()
	port = null
	set_mode(FALSE, FALSE)
	set_anchored(FALSE)

/obj/machinery/bilge_pump/portable/wrench_act(mob/living/user, obj/item/tool)
	if(port)
		disconnect_port()
		balloon_alert(user, "отсоединён")
	else
		balloon_alert(user, connect_port() ? "подключён" : "нужен свободный порт")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/bilge_pump/portable/plumbed
	name = "аварийный насос с трубным выходом"

/obj/machinery/bilge_pump/portable/draw_pump_energy(seconds_per_tick)
	if(!is_operational || panel_open)
		return FALSE
	var/required_energy = 50 * seconds_per_tick
	return cell?.use(required_energy, force = FALSE) >= required_energy

/obj/machinery/bilge_pump/portable/examine(mob/user)
	. = ..()
	. += span_notice("Заряд: [cell ? "[round(cell.percent())]%" : "нет аккумулятора"]. Порт: [port ? "подключён" : "нет"].")

/obj/machinery/bilge_pump/portable/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/bilge_pump/portable/crowbar_act(mob/living/user, obj/item/tool)
	if(!panel_open || !cell)
		return NONE
	cell.forceMove(drop_location())
	cell = null
	return ITEM_INTERACT_SUCCESS

/obj/machinery/bilge_pump/portable/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stock_parts/power_store/cell))
		return ..()
	if(!panel_open || cell || !user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	cell = tool
	return ITEM_INTERACT_SUCCESS
