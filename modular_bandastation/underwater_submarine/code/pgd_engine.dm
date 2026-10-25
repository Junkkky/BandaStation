/** A first-generation plasma-hydrodynamic drive consumes grid energy, without simulating ocean reagents. */
/obj/machinery/power/stationtrauma_pgd
	name = "плазмогидродинамический двигатель"
	desc = "ПГД первого поколения. Забортная вода ионизируется и ускоряется магнитными катушками. ЛКМ — местный выключатель и сброс защиты; остановленный и остывший двигатель ремонтируется кабелем и сваркой."
	icon = 'modular_bandastation/underwater_submarine/icons/pgd_nozzle.dmi'
	icon_state = "pgd_nozzle"
	bound_width = 96
	bound_height = 96
	density = TRUE
	opacity = TRUE
	max_integrity = 800
	integrity_failure = 0.25
	processing_flags = START_PROCESSING_ON_INIT
	/// Initial balance: six drives draw 180 MW at full thrust, 360 MW on boost.
	var/rated_power = 30 MEGA WATTS
	var/enabled = TRUE
	var/temperature = 20
	var/coil_condition = 100
	var/thermal_trip = FALSE
	var/actual_power = 0
	var/actual_thrust = 0
	/// Relative acoustic signature, exposed to navigation independently of the mock sonar.
	var/acoustic_signature = 0
	var/obj/docking_port/mobile/stationtrauma/vessel
	var/obj/machinery/stationtrauma_pgd_control/control
	var/obj/effect/stationtrauma_pgd_exhaust/exhaust
	var/datum/looping_sound/stationtrauma_pgd/engine_loop
	var/last_visual_level = -1

/datum/looping_sound/stationtrauma_pgd
	mid_sounds = 'sound/machines/generator/generator_mid1.ogg'
	volume = 25
	use_sound_tokens = TRUE
	pressure_affected = FALSE

/obj/effect/stationtrauma_pgd_exhaust
	name = "струя ПГД"
	icon = 'icons/effects/fire.dmi'
	icon_state = "light"
	color = "#79d9ff"
	alpha = 180
	layer = ABOVE_OBJ_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/machinery/power/stationtrauma_pgd/Initialize(mapload)
	. = ..()
	engine_loop = new(src)
	exhaust = new(get_turf(src))
	exhaust.add_overlay(emissive_appearance(exhaust.icon, exhaust.icon_state, exhaust))
	exhaust.pixel_x = 32 + (dir == WEST ? -48 : dir == EAST ? 48 : 0)
	exhaust.pixel_y = 32 + (dir == SOUTH ? -48 : dir == NORTH ? 48 : 0)
	exhaust.alpha = 0

/obj/machinery/power/stationtrauma_pgd/post_machine_initialize()
	. = ..()
	connect_to_network()
	for(var/obj/docking_port/mobile/stationtrauma/ship in SSshuttle.mobile_docking_ports)
		if(ship.requires_pgd && z >= ship.z && z < ship.z + ship.decks && x >= ship.x && x < ship.x + ship.width && y >= ship.y && y < ship.y + ship.height)
			vessel = ship
			ship.drive_engines |= src
			break

/obj/machinery/power/stationtrauma_pgd/should_have_node()
	return TRUE

/obj/machinery/power/stationtrauma_pgd/Destroy()
	vessel?.update_voyage_distance()
	vessel?.drive_engines.Remove(src)
	if(control)
		control.engine = null
	vessel = null
	QDEL_NULL(engine_loop)
	QDEL_NULL(exhaust)
	return ..()

/obj/machinery/power/stationtrauma_pgd/proc/has_seawater()
	return istype(loc, /turf/open/space/ocean) || istype(loc, /turf/open/space/openspace/ocean)

/obj/machinery/power/stationtrauma_pgd/proc/available_thrust()
	if(!enabled || !vessel?.engines_running || thermal_trip || machine_stat & BROKEN || !control || control.machine_stat & BROKEN || !has_seawater())
		return 0
	return actual_thrust

/obj/machinery/power/stationtrauma_pgd/proc/drive_status()
	if(machine_stat & BROKEN)
		return "Повреждён корпус"
	if(!control || control.machine_stat & BROKEN)
		return "Нет исправного блока управления"
	if(thermal_trip)
		return temperature <= 80 ? "Защита: готов к сбросу" : "Защита: охлаждение"
	if(!enabled || !vessel?.engines_running)
		return "Остановлен"
	if(!has_seawater())
		return "Нет забортной воды"
	if(coil_condition <= 0)
		return "Повреждены катушки"
	if(!actual_power)
		return "Нет питания"
	if(temperature >= 120)
		return "Перегрев: снизьте ход"
	return actual_power < rated_power * vessel.drive_power_fraction() * 0.95 ? "Недостаточно питания" : "Работает"

/obj/machinery/power/stationtrauma_pgd/process(seconds_per_tick)
	vessel?.update_voyage_distance()
	actual_power = 0
	actual_thrust = 0
	if(enabled && vessel?.engines_running && !thermal_trip && !(machine_stat & BROKEN) && control && !(control.machine_stat & BROKEN) && has_seawater() && coil_condition > 0)
		var/demand = rated_power * vessel.drive_power_fraction()
		var/energy = demand * seconds_per_tick
		// Test power belongs to the interior room, never to the ocean around the nozzle.
		var/area/engine_room = get_area(control)
		if(!engine_room || engine_room.requires_power)
			energy = min(energy, surplus())
			add_load(energy)
		actual_power = energy / seconds_per_tick
		actual_thrust = vessel.drive_thrust_fraction() * actual_power / demand * min(coil_condition / 100, get_integrity_percentage())
	// At full power the equilibrium is 95 C; boost deliberately exceeds the 145 C trip point.
	var/cooling = NUM_E ** (-0.04 * seconds_per_tick)
	var/previous_temperature = temperature
	temperature = 20 + (temperature - 20) * cooling + 75 * actual_power / rated_power * (1 - cooling)
	if(temperature >= 120 && previous_temperature < 120)
		playsound(src, 'sound/machines/warning-buzzer.ogg', 45, FALSE)
		visible_message(span_warning("[src]: перегрев ускорительной камеры, снизьте ход!"))
	if(temperature > 125)
		coil_condition = max(0, coil_condition - (temperature - 125) * 0.02 * seconds_per_tick)
	if(temperature >= 145 && !thermal_trip)
		thermal_trip = TRUE
		actual_thrust = 0
		playsound(src, 'sound/machines/warning-buzzer.ogg', 70, FALSE)
		visible_message(span_danger("[src]: аварийная защита отключила ускорительную камеру!"))
	acoustic_signature = actual_power / rated_power * 100
	update_drive_effects()
	if(vessel?.travelling)
		vessel.refresh_drive_motion()

/obj/machinery/power/stationtrauma_pgd/proc/update_drive_effects()
	var/level = 0
	if(actual_power > 0 && !thermal_trip)
		level = actual_power <= rated_power * 0.15 ? 1 : actual_power <= rated_power * 0.5 ? 2 : actual_power <= rated_power ? 3 : 4
	if(level == last_visual_level)
		return
	last_visual_level = level
	exhaust.alpha = level ? 100 + level * 35 : 0
	exhaust.color = level == 4 ? "#ffd39c" : "#79d9ff"
	exhaust.set_light(level ? 2 + level : 0, level ? 0.5 + level * 0.4 : 0, level == 4 ? "#ffd39c" : "#79d9ff")
	engine_loop.volume = level ? 10 + level * 20 : 0
	if(level)
		engine_loop.start()
		engine_loop.sound_token_instance?.set_volume(engine_loop.volume)
	else
		engine_loop.stop()

/** Resetting protection is explicit; a cooling drive never restarts itself. */
/obj/machinery/power/stationtrauma_pgd/proc/toggle_drive()
	vessel?.update_voyage_distance()
	if(thermal_trip)
		if(temperature > 80)
			return FALSE
		thermal_trip = FALSE
		enabled = TRUE
	else
		enabled = !enabled
	actual_power = 0
	actual_thrust = 0
	acoustic_signature = 0
	update_drive_effects()
	return TRUE

/obj/machinery/power/stationtrauma_pgd/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	balloon_alert(user, toggle_drive() ? "[enabled ? "включён" : "выключен"]" : "сначала остудите до 80 °C!")

/obj/machinery/power/stationtrauma_pgd/examine(mob/user)
	. = ..()
	. += span_notice("[drive_status()]. Камера: [round(temperature, 0.1)] °C; катушки: [round(coil_condition)]%; потребление: [display_power(actual_power)].")
	. += span_notice("Для ремонта отключите местный выключатель и остудите камеру до 80 °C. Катушки — 5 отрезков кабеля; корпус — сварка.")

/obj/machinery/power/stationtrauma_pgd/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/cable_coil))
		return ..()
	return repair_coils(user, tool, src)

/obj/machinery/power/stationtrauma_pgd/proc/repair_coils(mob/living/user, obj/item/stack/cable_coil/cable, atom/service_point)
	if(enabled || temperature > 80 || coil_condition >= 100)
		balloon_alert(user, "остановите и остудите двигатель!")
		return ITEM_INTERACT_BLOCKING
	if(cable.get_amount() < 5)
		balloon_alert(user, "нужно 5 отрезков кабеля!")
		return ITEM_INTERACT_BLOCKING
	if(do_after(user, 5 SECONDS, service_point) && !QDELETED(src) && !QDELETED(cable) && !enabled && temperature <= 80 && coil_condition < 100 && cable.use(5))
		coil_condition = 100
		balloon_alert(user, "катушки восстановлены")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/stationtrauma_pgd/welder_act(mob/living/user, obj/item/tool)
	return repair_housing(user, tool, src)

/obj/machinery/power/stationtrauma_pgd/proc/repair_housing(mob/living/user, obj/item/tool, atom/service_point)
	if(enabled || temperature > 80)
		balloon_alert(user, "остановите и остудите двигатель!")
		return ITEM_INTERACT_BLOCKING
	if(tool.use_tool(service_point, user, 5 SECONDS, amount = 1, volume = 50) && !QDELETED(src) && !enabled && temperature <= 80)
		repair_damage(max_integrity)
		control?.repair_damage(control.max_integrity)
	return ITEM_INTERACT_SUCCESS

/** An interior service module connects across an intact hull wall; neither module changes turfs or water geometry. */
/obj/machinery/stationtrauma_pgd_control
	name = "ускорительный блок ПГД"
	desc = "Внутренний блок катушек и управления. Соединён с наружным соплом через герметичный ввод в корпусе. ЛКМ — местный выключатель; кабель и сварка — ремонт остановленного двигателя."
	icon = 'modular_bandastation/underwater_submarine/icons/pgd_control.dmi'
	icon_state = "pgd_control"
	bound_width = 96
	bound_height = 32
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	processing_flags = NONE
	max_integrity = 400
	integrity_failure = 0.25
	var/obj/machinery/power/stationtrauma_pgd/engine

/obj/machinery/stationtrauma_pgd_control/post_machine_initialize()
	. = ..()
	var/nozzle_x = x
	var/nozzle_y = y
	switch(dir)
		if(WEST)
			nozzle_x -= 4
			nozzle_y--
		if(EAST)
			nozzle_x += 4
			nozzle_y--
		if(NORTH)
			nozzle_y += 2
		if(SOUTH)
			nozzle_y -= 4
	engine = locate() in locate(nozzle_x, nozzle_y, z)
	if(engine && engine.dir == dir && !engine.control)
		engine.control = src
	else
		engine = null

/obj/machinery/stationtrauma_pgd_control/Destroy()
	engine?.vessel?.update_voyage_distance()
	if(engine)
		engine.control = null
	engine = null
	return ..()

/obj/machinery/stationtrauma_pgd_control/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	balloon_alert(user, engine?.toggle_drive() ? "[engine.enabled ? "включён" : "выключен"]" : "нет связи или камера горячая!")

/obj/machinery/stationtrauma_pgd_control/examine(mob/user)
	. = ..()
	if(engine)
		. += span_notice("[engine.drive_status()]. Камера: [round(engine.temperature, 0.1)] °C; катушки: [round(engine.coil_condition)]%; потребление: [display_power(engine.actual_power)].")
	else
		. += span_warning("Нет связи с соплом. Разместите блок 3×1 напротив центра сопла 3×3, оставив между модулями стену корпуса.")

/obj/machinery/stationtrauma_pgd_control/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(engine && istype(tool, /obj/item/stack/cable_coil))
		return engine.repair_coils(user, tool, src)
	return ..()

/obj/machinery/stationtrauma_pgd_control/welder_act(mob/living/user, obj/item/tool)
	return engine ? engine.repair_housing(user, tool, src) : ITEM_INTERACT_BLOCKING
