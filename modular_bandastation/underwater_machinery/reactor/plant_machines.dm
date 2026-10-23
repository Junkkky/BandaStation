/** Shared physical housing and native lighting; only the reactor runs a processing loop. */
/obj/machinery/power/stationtrauma_plant_machine
	name = "агрегат реакторной установки"
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/plant_cooler.dmi'
	icon_state = "off"
	pixel_x = -32
	density = TRUE
	max_integrity = 400
	processing_flags = NONE
	var/plant_id = "main"
	var/piping_layer = PIPING_LAYER_DEFAULT
	var/plant_role = "part"
	var/enabled = TRUE
	var/plant_mode = "off"
	var/footprint_width = 3
	var/footprint_height = 2
	/// Port coordinates are offsets inside the housing plus the outward facing cardinal.
	var/list/plant_ports = list()

/obj/machinery/power/stationtrauma_plant_machine/Initialize(mapload)
	. = ..()
	bound_width = footprint_width * 32
	bound_height = footprint_height * 32
	bound_x = -round((footprint_width - 1) / 2) * 32
	bound_y = footprint_height == 3 ? -32 : 0
	pixel_x = bound_x
	pixel_y = bound_y
	GLOB.stationtrauma_plant_parts += src
	stationtrauma_plant_changed()
	refresh_port_pipes()

/obj/machinery/power/stationtrauma_plant_machine/Destroy()
	GLOB.stationtrauma_plant_parts -= src
	stationtrauma_plant_changed()
	refresh_port_pipes()
	return ..()

/obj/machinery/power/stationtrauma_plant_machine/setDir(newdir)
	return ..(SOUTH)

/obj/machinery/power/stationtrauma_plant_machine/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	stationtrauma_plant_changed()

/obj/machinery/power/stationtrauma_plant_machine/on_set_is_operational(old_value)
	. = ..()
	stationtrauma_plant_changed()

/** A pipe occupies the tile immediately outside its flush housing connection. */
/obj/machinery/power/stationtrauma_plant_machine/proc/port_turf(port)
	var/list/info = plant_ports[port]
	if(!info)
		return null
	var/turf/edge = locate(x + info[1], y + info[2], z)
	return get_step(edge, info[3])

/obj/machinery/power/stationtrauma_plant_machine/proc/port_facing(port)
	var/list/info = plant_ports[port]
	return info ? REVERSE_DIR(info[3]) : NONE

/** Only the correct medium, layer and reciprocal opening can enter this port. */
/obj/machinery/power/stationtrauma_plant_machine/proc/connected_pipe(port)
	var/list/info = plant_ports[port]
	for(var/obj/machinery/stationtrauma_reactor_pipe/pipe in port_turf(port))
		if(!QDELETED(pipe) && pipe.plant_id == plant_id && pipe.line == info[4] && pipe.piping_layer == piping_layer && pipe.accepts(port_facing(port)))
			return pipe
	return null

/** Refresh the native end caps when a housing appears or disappears. */
/obj/machinery/power/stationtrauma_plant_machine/proc/refresh_port_pipes()
	for(var/port in plant_ports)
		for(var/obj/machinery/stationtrauma_reactor_pipe/pipe in port_turf(port))
			pipe.update_appearance(UPDATE_ICON)

/** Animated icons/emissive masks are baked; changing state does not spawn runtime effects. */
/obj/machinery/power/stationtrauma_plant_machine/proc/set_plant_mode(new_mode)
	if(plant_mode == new_mode)
		return
	plant_mode = new_mode
	icon_state = new_mode
	var/is_core = plant_role == "reactor"
	var/light_colour = is_core ? "#58ff70" : "#d4e3e8"
	if(new_mode == "overload")
		light_colour = is_core ? "#a8ff42" : "#ffba54"
	if(new_mode == "emergency")
		light_colour = is_core ? "#48ff70" : "#ff4444"
	set_light(new_mode == "off" ? 0 : (is_core ? 6 : 2), is_core ? 2 : 0.7, light_colour)
	update_appearance(UPDATE_OVERLAYS)

/obj/machinery/power/stationtrauma_plant_machine/update_overlays()
	. = ..()
	for(var/port in plant_ports)
		var/obj/machinery/stationtrauma_reactor_pipe/pipe = connected_pipe(port)
		if(!pipe)
			continue
		var/list/info = plant_ports[port]
		var/mutable_appearance/branch = mutable_appearance('icons/obj/pipes_n_cables/pipe_underlays.dmi', "intact_[info[3]]_[piping_layer]", FLOAT_LAYER - 0.01, appearance_flags = RESET_COLOR|KEEP_APART)
		branch.color = stationtrauma_plant_line_color(info[4])
		branch.pixel_x = info[1] * 32 - pixel_x
		branch.pixel_y = info[2] * 32 - pixel_y
		. += branch
	if(plant_mode != "off")
		. += emissive_appearance(icon, "[plant_mode]_emissive", src)

/obj/machinery/power/stationtrauma_plant_machine/examine(mob/user)
	. = ..()
	. += span_notice("Установка: [plant_id]. Порты корпуса: [jointext(plant_ports, ", ")]. Трубы подключаются к соседней клетке у соответствующего порта.")

/obj/machinery/power/stationtrauma_plant_machine/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	enabled = !enabled
	stationtrauma_plant_changed()
	balloon_alert(user, enabled ? "включён" : "выключен")

/obj/machinery/power/stationtrauma_plant_machine/turbine
	name = "паровой турбогенератор"
	desc = "Пар входит слева, отработанный пар выходит справа. Кабель подключается под центральной клеткой."
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/plant_turbine.dmi'
	plant_role = "turbine"
	footprint_width = 5
	pixel_x = -64
	cable_layer = CABLE_LAYER_1
	can_change_cable_layer = TRUE
	plant_ports = list("пар слева" = list(-2, 0, WEST, ST_PLANT_STEAM), "выхлоп справа" = list(2, 0, EAST, ST_PLANT_EXHAUST))

/obj/machinery/power/stationtrauma_plant_machine/turbine/post_machine_initialize()
	. = ..()
	connect_to_network()

/obj/machinery/power/stationtrauma_plant_machine/turbine/should_have_node()
	return TRUE

/obj/machinery/power/stationtrauma_plant_machine/condenser
	name = "паровой конденсатор"
	desc = "Слева сверху — отработанный пар, слева снизу — питательная вода. Справа сверху — забор охлаждения, справа снизу — выпуск. Контуры не смешиваются."
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/plant_condenser.dmi'
	plant_role = "condenser"
	plant_ports = list("пар слева сверху" = list(-1, 1, WEST, ST_PLANT_EXHAUST), "вода слева снизу" = list(-1, 0, WEST, ST_PLANT_WATER), "охлаждение справа сверху" = list(1, 1, EAST, ST_PLANT_SEA), "выпуск справа снизу" = list(1, 0, EAST, ST_PLANT_SEA))

/obj/machinery/power/stationtrauma_plant_machine/cooler
	name = "охладительная установка реактора"
	desc = "Слева сверху — горячий аварийный контур, слева снизу — возврат. Справа сверху — забортная подача, справа снизу — выпуск. ЛКМ — включить или отключить аварийное охлаждение."
	plant_role = "cooler"
	enabled = FALSE
	plant_ports = list("горячий слева сверху" = list(-1, 1, WEST, ST_PLANT_COOLANT), "возврат слева снизу" = list(-1, 0, WEST, ST_PLANT_COOLANT), "охлаждение справа сверху" = list(1, 1, EAST, ST_PLANT_SEA), "выпуск справа снизу" = list(1, 0, EAST, ST_PLANT_SEA))

/obj/machinery/power/stationtrauma_plant_machine/reservoir
	name = "запасной бак реакторной установки"
	desc = "Изолированный запас теплоносителя и ёмкость для холодного дренажа. Выход питательной воды — справа."
	icon = 'icons/obj/medical/chemical_tanks.dmi'
	icon_state = "water"
	pixel_x = 0
	plant_role = "reservoir"
	footprint_width = 1
	footprint_height = 1
	plant_ports = list("вода справа" = list(0, 0, EAST, ST_PLANT_WATER))

/obj/machinery/power/stationtrauma_plant_machine/reservoir/set_plant_mode(new_mode)
	return

/** A deleted reactor retains its entire finite inventory in an inert, inspectable wreck. */
/obj/structure/stationtrauma_plant_wreck
	name = "разрушенная реакторная установка"
	desc = "Остатки установки с запертым теплоносителем."
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/plant_reactor.dmi'
	icon_state = "off"
	anchored = TRUE
	density = TRUE
	pixel_x = -32
	pixel_y = -32
	var/datum/stationtrauma_plant_state/contents_state

/obj/structure/stationtrauma_plant_wreck/examine(mob/user)
	. = ..()
	if(contents_state)
		. += span_warning("Заперто воды и пара: [round(contents_state.total_water(), 0.1)] л. Температура зоны: [round(contents_state.core_temperature - T0C)] °C.")

/obj/structure/stationtrauma_plant_wreck/Destroy()
	QDEL_NULL(contents_state)
	return ..()
