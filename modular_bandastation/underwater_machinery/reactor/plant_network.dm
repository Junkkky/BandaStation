/** Isolated connections use ordinary pipe art without atmos or reagent components. */
/obj/machinery/stationtrauma_reactor_pipe
	name = "труба реакторной установки"
	desc = "Изолированная линия установки. Ключ — снять секцию. Не соединяется с трюмными и атмосферными трубами."
	icon = 'icons/obj/pipes_n_cables/simple.dmi'
	icon_state = "manifold4w-3"
	layer = GAS_PIPE_HIDDEN_LAYER
	anchored = TRUE
	density = FALSE
	use_power = NO_POWER_USE
	processing_flags = NONE
	interaction_flags_machine = INTERACT_MACHINE_OFFLINE | INTERACT_MACHINE_ALLOW_SILICON
	var/plant_id = "main"
	var/line = ST_PLANT_WATER
	/// Native physical pipe layer, independent of the medium.
	var/piping_layer = PIPING_LAYER_DEFAULT
	var/hide = TRUE
	/// Native binary bodies stay unpainted; only their pipe branches are coloured.
	var/tint_body = TRUE
	/// Native straight/bend poses used by the mapper's node tool.
	var/simple_pipe = FALSE
	var/connections = ALL_CARDINALS
	var/open = TRUE
	var/pumping = FALSE
	var/on = FALSE
	var/flow_rate = 20

/obj/machinery/stationtrauma_reactor_pipe/Initialize(mapload)
	. = ..()
	GLOB.stationtrauma_plant_pipes += src
	color = tint_body ? stationtrauma_plant_line_color(line) : null
	if(hide)
		AddElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)
	if(pumping)
		update_use_power(on ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	AddElement(/datum/element/simple_rotation)
	refresh_connections()

/obj/machinery/stationtrauma_reactor_pipe/Destroy()
	GLOB.stationtrauma_plant_pipes -= src
	refresh_connections()
	return ..()

/obj/machinery/stationtrauma_reactor_pipe/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	refresh_connections()

/obj/machinery/stationtrauma_reactor_pipe/setDir(newdir)
	. = ..(newdir in (simple_pipe ? GLOB.alldirs : GLOB.cardinals) ? newdir : SOUTH)
	refresh_connections()

/obj/machinery/stationtrauma_reactor_pipe/on_set_is_operational(old_value)
	. = ..()
	stationtrauma_plant_changed()
	update_appearance()

/** Topology changes invalidate scalar path capacities, never start per-pipe processing. */
/obj/machinery/stationtrauma_reactor_pipe/proc/refresh_connections()
	stationtrauma_plant_changed()
	layer = initial(layer) + piping_layer / 1000
	update_appearance()
	for(var/direction in GLOB.cardinals)
		for(var/obj/machinery/stationtrauma_reactor_pipe/neighbor in get_step(src, direction))
			neighbor.update_appearance()
	for(var/obj/machinery/power/stationtrauma_plant_machine/machine as anything in GLOB.stationtrauma_plant_parts)
		for(var/port in machine.plant_ports)
			if(machine.port_turf(port) == get_turf(src))
				machine.update_appearance(UPDATE_OVERLAYS)

/obj/machinery/stationtrauma_reactor_pipe/proc/accepts(direction)
	if(simple_pipe)
		var/openings = ISDIAGONALDIR(dir) ? dir : ((dir in list(NORTH, SOUTH)) ? NORTH|SOUTH : EAST|WEST)
		return !!(openings & direction)
	for(var/base_direction in GLOB.cardinals)
		if((connections & base_direction) && turn(base_direction, 180 - dir2angle(dir)) == direction)
			return TRUE
	return FALSE

/obj/machinery/stationtrauma_reactor_pipe/proc/available()
	return anchored && !QDELETED(src) && !(machine_stat & BROKEN) && open && (!pumping || (on && is_operational))

/obj/machinery/stationtrauma_reactor_pipe/update_icon_state()
	. = ..()
	icon = 'icons/obj/pipes_n_cables/!pipes_bitmask.dmi'
	color = tint_body ? stationtrauma_plant_line_color(line) : null
	icon_state = "[stationtrauma_pipe_bitfield(connected_directions(), allowed_directions())]_[piping_layer]"

/** Use the same short end caps as native smart pipes. */
/proc/stationtrauma_pipe_bitfield(connected, allowed)
	var/bitfield = CARDINAL_TO_FULLPIPES(connected)
	if(!ISSTUB(connected))
		return bitfield
	var/short_ends = connected ? REVERSE_DIR(connected) & allowed : NONE
	var/shift = 0
	while(ISSTUB(connected | short_ends) && (allowed >> shift))
		var/candidate = allowed & (1 << shift++)
		if(!(candidate & connected))
			short_ends |= candidate
	return bitfield | CARDINAL_TO_SHORTPIPES(short_ends)

/** Rotated physical openings, also used by the editor's native route tool. */
/obj/machinery/stationtrauma_reactor_pipe/proc/allowed_directions()
	var/allowed = NONE
	for(var/direction in GLOB.cardinals)
		if(accepts(direction))
			allowed |= direction
	return allowed

/** Device ports count as connections even though their centres span several tiles. */
/obj/machinery/stationtrauma_reactor_pipe/proc/connected_directions()
	var/connected = NONE
	for(var/direction in GLOB.cardinals)
		if(!accepts(direction))
			continue
		for(var/obj/machinery/stationtrauma_reactor_pipe/neighbor in get_step(src, direction))
			if(!QDELETED(neighbor) && neighbor.plant_id == plant_id && neighbor.line == line && neighbor.piping_layer == piping_layer && neighbor.accepts(REVERSE_DIR(direction)))
				connected |= direction
	for(var/obj/machinery/power/stationtrauma_plant_machine/machine as anything in GLOB.stationtrauma_plant_parts)
		for(var/port in machine.plant_ports)
			if(machine.connected_pipe(port) == src)
				connected |= machine.port_facing(port)
	return connected

/** Stock binary pipe underlays; custom intake and outlet bodies cover their inner ends. */
/obj/machinery/stationtrauma_reactor_pipe/update_overlays()
	. = ..()
	if(tint_body)
		return
	var/connected = connected_directions()
	for(var/direction in GLOB.cardinals)
		if(!accepts(direction))
			continue
		var/mutable_appearance/branch = mutable_appearance('icons/obj/pipes_n_cables/pipe_underlays.dmi', "[connected & direction ? "intact" : "exposed"]_[direction]_[piping_layer]", FLOAT_LAYER - 0.01, appearance_flags = RESET_COLOR|KEEP_APART)
		branch.color = stationtrauma_plant_line_color(line)
		stationtrauma_position_water_branch(branch, direction)
		. += branch

/obj/machinery/stationtrauma_reactor_pipe/examine(mob/user)
	. = ..()
	. += span_notice("Установка: [plant_id]. Линия: [stationtrauma_plant_line_name(line)].")
	if(pumping)
		. += span_notice("Насос: [on ? "включён" : "выключен"]. Подача: [flow_rate] л/с.")

/obj/machinery/stationtrauma_reactor_pipe/wrench_act(mob/living/user, obj/item/tool)
	if(!tool.use_tool(src, user, 1 SECONDS, volume = 30))
		return ITEM_INTERACT_BLOCKING
	var/obj/item/stationtrauma_reactor_fitting/fitting = new(drop_location())
	fitting.fixture_type = type
	fitting.line = line
	fitting.plant_id = plant_id
	fitting.connection_mask = connections
	fitting.piping_layer = piping_layer
	fitting.hide = hide
	fitting.dir = dir
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_reactor_pipe/straight
	connections = NORTH | SOUTH
	icon_state = "pipe11-3"

/obj/machinery/stationtrauma_reactor_pipe/simple
	simple_pipe = TRUE
	icon_state = "pipe11-3"

/obj/machinery/stationtrauma_reactor_pipe/elbow
	connections = NORTH | EAST

/obj/machinery/stationtrauma_reactor_pipe/tee
	connections = NORTH | EAST | WEST
	icon_state = "manifold-3"

/obj/machinery/stationtrauma_reactor_pipe/valve
	name = "вентиль реакторной установки"
	icon = 'icons/obj/machines/atmospherics/binary_devices.dmi'
	icon_state = "mvalve_map-3"
	connections = NORTH | SOUTH
	layer = GAS_PUMP_LAYER
	tint_body = FALSE
	hide = FALSE

/obj/machinery/stationtrauma_reactor_pipe/valve/update_icon_state()
	. = ..()
	icon = 'icons/obj/machines/atmospherics/binary_devices.dmi'
	dir = (dir in list(NORTH, SOUTH)) ? NORTH : EAST
	pixel_x = 0
	pixel_y = 0
	PIPING_LAYER_SHIFT(src, piping_layer)
	icon_state = "mvalve_[open ? "on" : "off"]-[(piping_layer in list(2, 4)) ? 2 : 1]"

/obj/machinery/stationtrauma_reactor_pipe/valve/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	open = !open
	stationtrauma_plant_changed()
	update_appearance()
	balloon_alert(user, open ? "открыт" : "закрыт")

/obj/machinery/stationtrauma_reactor_pipe/pump
	name = "насос реакторной установки"
	icon = 'icons/obj/machines/atmospherics/binary_devices.dmi'
	icon_state = "pump_map-3"
	connections = NORTH | SOUTH
	pumping = TRUE
	layer = GAS_PUMP_LAYER
	tint_body = FALSE
	hide = FALSE
	use_power = IDLE_POWER_USE
	idle_power_usage = 25
	active_power_usage = 1500

/obj/machinery/stationtrauma_reactor_pipe/pump/update_icon_state()
	. = ..()
	icon = 'icons/obj/machines/atmospherics/binary_devices.dmi'
	pixel_x = 0
	pixel_y = 0
	PIPING_LAYER_SHIFT(src, piping_layer)
	icon_state = "pump_[on && is_operational ? "on" : "off"]-[(piping_layer in list(2, 4)) ? 2 : 1]"

/obj/machinery/stationtrauma_reactor_pipe/pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	on = !on
	update_use_power(on ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	stationtrauma_plant_changed()
	update_appearance()
	balloon_alert(user, on ? "включён" : "выключен")

/** An ocean boundary is a condition, not a floodwater withdrawal or a heat exchange. */
/obj/machinery/stationtrauma_reactor_pipe/proc/at_ocean()
	for(var/direction in GLOB.cardinals)
		var/turf/nearby = get_step(src, direction)
		if(istype(get_area(nearby), /area/space/ocean) || istype(nearby, /turf/open/space/ocean) || istype(nearby, /turf/open/space/openspace/ocean))
			return TRUE
	return FALSE

/obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet
	name = "забортный насос реакторной установки"
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "hull_intake"
	line = ST_PLANT_SEA
	flow_rate = 200
	connections = SOUTH

/obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet/update_icon_state()
	. = ..()
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	pixel_x = 0
	pixel_y = 0
	icon_state = "hull_intake"

/obj/machinery/stationtrauma_reactor_pipe/sea_outlet
	name = "выпуск охлаждения реакторной установки"
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "active_output"
	line = ST_PLANT_SEA
	connections = SOUTH
	tint_body = FALSE
	hide = FALSE

/obj/machinery/stationtrauma_reactor_pipe/sea_outlet/update_icon_state()
	. = ..()
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "active_output"

/** Find a capacity once per topology change; ordinary ticks never walk the pipes. */
/proc/stationtrauma_plant_path(turf/start, start_direction, turf/finish, finish_direction, plant_id, line, require_pump = FALSE, start_layer, finish_layer)
	if(!start || !finish)
		return 0
	var/list/queue = list()
	var/list/capacities = list()
	var/list/pumped = list()
	var/list/seen_pumped = list()
	var/list/seen_unpumped = list()
	for(var/obj/machinery/stationtrauma_reactor_pipe/pipe in start)
		if(pipe.plant_id != plant_id || pipe.line != line || (!isnull(start_layer) && pipe.piping_layer != start_layer) || (start_direction && !pipe.accepts(start_direction)) || !pipe.available())
			continue
		if(start_direction && pipe.pumping && !istype(pipe, /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet) && pipe.dir != REVERSE_DIR(start_direction))
			continue
		queue += pipe
		capacities += pipe.pumping ? pipe.flow_rate : 1000000
		pumped += pipe.pumping
		var/list/seen = pipe.pumping ? seen_pumped : seen_unpumped
		seen[pipe] = TRUE
	var/index = 1
	while(index <= length(queue))
		var/obj/machinery/stationtrauma_reactor_pipe/pipe = queue[index]
		var/capacity = capacities[index]
		var/has_pump = pumped[index++]
		if(get_turf(pipe) == finish && (isnull(finish_layer) || pipe.piping_layer == finish_layer) && (!finish_direction || pipe.accepts(finish_direction)) && (!require_pump || has_pump))
			if(!finish_direction || !pipe.pumping || istype(pipe, /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet) || pipe.dir == finish_direction)
				return capacity
		for(var/direction in GLOB.cardinals)
			if(!pipe.accepts(direction) || (pipe.pumping && !istype(pipe, /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet) && direction != pipe.dir))
				continue
			for(var/obj/machinery/stationtrauma_reactor_pipe/neighbor in get_step(pipe, direction))
				if(neighbor.plant_id != plant_id || neighbor.line != line || neighbor.piping_layer != pipe.piping_layer || !neighbor.available() || !neighbor.accepts(REVERSE_DIR(direction)))
					continue
				if(neighbor.pumping && !istype(neighbor, /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet) && neighbor.dir != direction)
					continue
				var/next_pumped = has_pump || neighbor.pumping
				var/list/seen = next_pumped ? seen_pumped : seen_unpumped
				if(seen[neighbor])
					continue
				seen[neighbor] = TRUE
				queue += neighbor
				capacities += min(capacity, neighbor.pumping ? neighbor.flow_rate : 1000000)
				pumped += next_pumped
	return 0
