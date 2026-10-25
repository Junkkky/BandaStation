/// Keep pipe sections below grates; fixtures retain their normal operating height.
/obj/machinery/proc/stationtrauma_pipe_floor_layer(datum/source)
	SIGNAL_HANDLER
	if(!isturf(loc))
		return
	var/physical_layer
	var/surface_layer
	if(istype(src, /obj/machinery/stationtrauma_reactor_pipe))
		var/obj/machinery/stationtrauma_reactor_pipe/pipe = src
		physical_layer = pipe.piping_layer
		surface_layer = (!pipe.hide && isclosedturf(loc) ? ABOVE_OBJ_LAYER : initial(layer)) + physical_layer / 1000
		if(!pipe.tint_body)
			layer = surface_layer
			return
	else
		var/obj/machinery/duct/stationtrauma/pipe = src
		physical_layer = pipe.water_level
		surface_layer = initial(layer) + pipe.duct_layer * 0.0003
	var/under_floor = istype(loc, /turf/open/floor/catwalk_floor) || HAS_TRAIT(src, TRAIT_UNDERFLOOR) || HAS_TRAIT(loc, TRAIT_UNCOVERED_TURF)
	SET_PLANE_IMPLICIT(src, under_floor ? FLOOR_PLANE : initial(plane))
	layer = under_floor ? BELOW_CATWALK_LAYER + physical_layer / 1000 : surface_layer

/// Separate water geometry and layer; reuse TG's liquid network splitting instead of mixing water into gas mixtures.
/obj/machinery/duct/stationtrauma
	name = "водяная труба"
	desc = "Труба водяного контура. Ключ — снять, водяной RPD — проложить. Не соединяется с газовыми трубами или химическими duct."
	icon = 'icons/obj/pipes_n_cables/simple.dmi'
	icon_state = "manifold4w-3"
	layer = GAS_PIPE_HIDDEN_LAYER
	color = STATIONTRAUMA_WATER_COLOR
	duct_color = STATIONTRAUMA_WATER_COLOR
	duct_layer = STATIONTRAUMA_WATER_LAYER
	var/pipe_shape = "smart"
	var/connection_mask = ALL_CARDINALS
	var/water_level = 3
	var/bridges_levels = FALSE
	var/hide = TRUE

/obj/machinery/duct/stationtrauma/manifold
	name = "водяной адаптер уровней"
	desc = "Объединяет соседние водяные линии всех пяти уровней. Занимает все уровни на своей клетке. Ключ — снять."
	bridges_levels = TRUE
	pipe_shape = "straight"
	icon = 'icons/obj/pipes_n_cables/manifold.dmi'
	icon_state = MAP_SWITCH("manifoldlayer_center", "manifoldlayer")
	color = STATIONTRAUMA_WATER_COLOR

/obj/machinery/duct/stationtrauma/manifold/update_icon_state()
	. = ..()
	icon_state = "manifoldlayer_center"

/obj/machinery/duct/stationtrauma/manifold/update_overlays()
	. = ..()
	for(var/atom/movable/neighbor as anything in neighbours)
		var/level
		if(istype(neighbor, /obj/machinery/duct/stationtrauma))
			var/obj/machinery/duct/stationtrauma/pipe = neighbor
			level = pipe.water_level
		else
			var/datum/component/plumbing/stationtrauma_water/component = neighbor.GetComponent(/datum/component/plumbing/stationtrauma_water)
			level = stationtrauma_water_level(component?.ducting_layer)
		var/mutable_appearance/branch = mutable_appearance('icons/obj/pipes_n_cables/layer_manifold_underlays.dmi', "intact_[get_dir(src, neighbor)]_[level]", FLOAT_LAYER)
		branch.color = STATIONTRAUMA_WATER_COLOR
		. += branch

/obj/machinery/duct/stationtrauma/straight
	pipe_shape = "straight"
	icon_state = "pipe11-3"

/obj/machinery/duct/stationtrauma/simple
	pipe_shape = "simple"
	icon_state = "pipe11-3"

/obj/machinery/duct/stationtrauma/elbow
	pipe_shape = "elbow"
	icon_state = "pipe11-3"

/obj/machinery/duct/stationtrauma/tee
	pipe_shape = "tee"
	icon_state = "manifold-3"

/obj/machinery/duct/stationtrauma/cross
	pipe_shape = "cross"
	icon_state = "manifold4w-3"

// Match the native atmos mapper helpers: each layer has its own directional preview.
#define WATER_PIPE_MAPPING_LAYERS(path, shape) \
	##path/layer1 { water_level = 1; icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_pipe_mapping.dmi'; icon_state = MAP_SWITCH("48_1", shape + "-1"); } \
	##path/layer2 { water_level = 2; icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_pipe_mapping.dmi'; icon_state = MAP_SWITCH("48_2", shape + "-2"); } \
	##path/layer4 { water_level = 4; icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_pipe_mapping.dmi'; icon_state = MAP_SWITCH("48_4", shape + "-4"); } \
	##path/layer5 { water_level = 5; icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_pipe_mapping.dmi'; icon_state = MAP_SWITCH("48_5", shape + "-5"); }

WATER_PIPE_MAPPING_LAYERS(/obj/machinery/duct/stationtrauma, "smart")
WATER_PIPE_MAPPING_LAYERS(/obj/machinery/duct/stationtrauma/straight, "straight")
WATER_PIPE_MAPPING_LAYERS(/obj/machinery/duct/stationtrauma/elbow, "elbow")
WATER_PIPE_MAPPING_LAYERS(/obj/machinery/duct/stationtrauma/tee, "tee")
WATER_PIPE_MAPPING_LAYERS(/obj/machinery/duct/stationtrauma/cross, "cross")

#undef WATER_PIPE_MAPPING_LAYERS

/obj/machinery/duct/stationtrauma/Initialize(mapload, new_shape, new_direction, new_level)
	if(new_level in 1 to 5)
		water_level = new_level
	if(new_shape)
		pipe_shape = new_shape
	if(new_direction)
		dir = new_direction
	configure_water_pipe()
	. = ..(mapload)
	if(!hide)
		RemoveElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)
	RegisterSignal(src, hide ? COMSIG_UNDERTILE_UPDATED : COMSIG_OBJ_HIDE, PROC_REF(stationtrauma_pipe_floor_layer))
	stationtrauma_pipe_floor_layer()

/obj/machinery/duct/stationtrauma/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	stationtrauma_pipe_floor_layer()

/** Shared geometry setup for gameplay and the editor's prepare pass. */
/obj/machinery/duct/stationtrauma/proc/configure_water_pipe()
	duct_layer = bridges_levels ? (31 << 5) : STATIONTRAUMA_WATER_LAYER_BIT(water_level)
	if(pipe_shape == "simple")
		connection_mask = ISDIAGONALDIR(dir) ? dir : ((dir in list(NORTH, SOUTH)) ? NORTH|SOUTH : EAST|WEST)
		return
	switch(pipe_shape)
		if("straight")
			connection_mask = NORTH | SOUTH
		if("elbow")
			connection_mask = NORTH | EAST
		if("tee")
			connection_mask = NORTH | EAST | WEST
		else
			connection_mask = ALL_CARDINALS
	var/rotated_mask = NONE
	for(var/direction in GLOB.cardinals)
		if(connection_mask & direction)
			rotated_mask |= turn(direction, 180 - dir2angle(dir))
	connection_mask = rotated_mask

/obj/machinery/duct/stationtrauma/proc/accepts(direction)
	return !!(connection_mask & direction)

/obj/machinery/duct/stationtrauma/post_machine_initialize()
	// The native duct pass must not join ends outside this water section's geometry.
	var/water_layer = duct_layer
	duct_layer = NONE
	. = ..()
	duct_layer = water_layer
	rebuild_water_connections()

/obj/machinery/duct/stationtrauma/proc/rebuild_water_connections()
	if(!net)
		net = new(src)
	LAZYINITLIST(neighbours)
	for(var/direction in GLOB.cardinals)
		if(!accepts(direction))
			continue
		var/opposite = REVERSE_DIR(direction)
		for(var/atom/movable/neighbor in get_step(src, direction))
			var/obj/machinery/duct/stationtrauma/pipe = neighbor
			if(istype(pipe))
				if(!(pipe.duct_layer & duct_layer) || !pipe.accepts(opposite))
					continue
				if(!pipe.net)
					pipe.net = net
					net.ducts |= pipe
				else if(pipe.net != net)
					var/datum/ductnet/other = pipe.net
					for(var/datum/component/plumbing/component as anything in other.suppliers + other.demanders)
						for(var/key in component.ducts)
							if(component.ducts[key] == other)
								component.ducts[key] = net
						if(component in other.suppliers)
							net.suppliers |= component
						if(component in other.demanders)
							net.demanders |= component
					for(var/obj/machinery/duct/member as anything in other.ducts)
						member.net = net
						net.ducts |= member
					other.suppliers.Cut()
					other.demanders.Cut()
					qdel(other)
				neighbours[pipe] = direction
				LAZYINITLIST(pipe.neighbours)
				pipe.neighbours[src] = opposite
				pipe.update_appearance(UPDATE_ICON)
				continue
			for(var/datum/component/plumbing/stationtrauma_water/component as anything in neighbor.GetComponents(/datum/component/plumbing/stationtrauma_water))
				if(!component.active() || !(component.ducting_layer & duct_layer) || !(opposite & (component.demand_connects | component.supply_connects)))
					continue
				if(component.ducts["[opposite]"] != net)
					net.add_plumber(component, opposite)
					neighbor.update_appearance(UPDATE_OVERLAYS)
				neighbours[neighbor] = direction
	update_appearance(UPDATE_ICON)

/obj/machinery/duct/stationtrauma/Destroy()
	var/list/old_neighbors = neighbours?.Copy()
	. = ..()
	for(var/atom/movable/neighbor as anything in old_neighbors)
		if(!QDELETED(neighbor))
			neighbor.update_appearance(UPDATE_OVERLAYS)

/obj/machinery/duct/stationtrauma/update_icon_state()
	. = ..()
	icon = bridges_levels ? 'icons/obj/pipes_n_cables/manifold.dmi' : 'icons/obj/pipes_n_cables/!pipes_bitmask.dmi'
	var/connections = NONE
	for(var/neighbor in neighbours)
		connections |= neighbours[neighbor]
	icon_state = "[stationtrauma_pipe_bitfield(connections, connection_mask)]_[water_level]"
	stationtrauma_pipe_floor_layer()

/obj/machinery/duct/stationtrauma/examine(mob/user)
	. = list(desc, span_notice("Секция: [pipe_shape], уровень [water_level]. Сеть водяная; газ и химические duct не подключаются."))

/obj/machinery/duct/stationtrauma/on_deconstruction()
	var/obj/item/stationtrauma_water_pipe_fitting/fitting = new(drop_location())
	fitting.pipe_shape = pipe_shape
	fitting.dir = dir
	fitting.water_level = water_level
	fitting.bridges_levels = bridges_levels
	fitting.update_appearance(UPDATE_ICON)

/obj/item/stationtrauma_water_pipe_fitting
	name = "секция водяной трубы"
	desc = "Положите на свободную клетку и прикрутите ключом. Alt+ЛКМ — поворот."
	icon = 'icons/obj/pipes_n_cables/!pipes_bitmask.dmi'
	icon_state = "48_3"
	color = STATIONTRAUMA_WATER_COLOR
	var/pipe_shape = "smart"
	var/water_level = 3
	var/bridges_levels = FALSE

/obj/item/stationtrauma_water_pipe_fitting/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_rotation)

/obj/item/stationtrauma_water_pipe_fitting/update_icon_state()
	. = ..()
	icon = bridges_levels ? 'icons/obj/pipes_n_cables/pipe_item.dmi' : 'icons/obj/pipes_n_cables/!pipes_bitmask.dmi'
	icon_state = bridges_levels ? "manifoldlayer" : "48_[water_level]"

/obj/item/stationtrauma_water_pipe_fitting/examine(mob/user)
	. = ..()
	. += span_notice(bridges_levels ? "Межуровневый коллектор: соединяет все пять уровней." : "Уровень водяной трубы: [water_level].")

/obj/item/stationtrauma_water_pipe_fitting/wrench_act(mob/living/user, obj/item/tool)
	var/turf/tile = get_turf(src)
	if((!isopenturf(tile) && !isclosedturf(tile)) || ducting_layer_check(tile, bridges_levels ? (31 << 5) : STATIONTRAUMA_WATER_LAYER_BIT(water_level)))
		balloon_alert(user, "место занято")
		return ITEM_INTERACT_BLOCKING
	var/path = bridges_levels ? /obj/machinery/duct/stationtrauma/manifold : /obj/machinery/duct/stationtrauma
	var/obj/machinery/duct/stationtrauma/pipe = new path(tile, pipe_shape, dir, water_level)
	pipe.rebuild_water_connections()
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/datum/component/plumbing/stationtrauma_water/enable()
	if(demand_connects)
		START_PROCESSING(SSplumbing, src)
	for(var/direction in GLOB.cardinals)
		if(!(direction & (demand_connects | supply_connects)))
			continue
		var/opposite = REVERSE_DIR(direction)
		for(var/atom/movable/neighbor in get_step(parent, direction))
			var/obj/machinery/duct/stationtrauma/pipe = neighbor
			if(istype(pipe))
				if(!(pipe.duct_layer & ducting_layer) || !pipe.accepts(opposite))
					continue
				if(!pipe.net)
					pipe.rebuild_water_connections()
				pipe.neighbours[parent] = opposite
				pipe.net.add_plumber(src, direction)
				pipe.update_appearance(UPDATE_ICON)
				continue
			for(var/datum/component/plumbing/stationtrauma_water/other as anything in neighbor.GetComponents(/datum/component/plumbing/stationtrauma_water))
				if(other.active() && (other.ducting_layer & ducting_layer) && ((other.demand_connects & opposite) && (supply_connects & direction) || (other.supply_connects & opposite) && (demand_connects & direction)))
					if(other.ducts["[opposite]"] == ducts["[direction]"] && ducts["[direction]"])
						continue
					var/datum/ductnet/network = new
					network.add_plumber(src, direction)
					network.add_plumber(other, opposite)
					neighbor.update_appearance(UPDATE_OVERLAYS)
	var/atom/movable/device = parent
	device.update_appearance(UPDATE_ICON)

/datum/component/plumbing/stationtrauma_water/disable()
	// Native plumbing disconnects both ends without refreshing the devices' pipe branches.
	var/list/atom/movable/changed = list(parent)
	for(var/key in ducts)
		var/datum/ductnet/network = ducts[key]
		if(!length(network.ducts))
			for(var/datum/component/plumbing/component as anything in network.suppliers + network.demanders)
				changed |= component.parent
	. = ..()
	for(var/atom/movable/device as anything in changed)
		if(!QDELETED(device))
			device.update_appearance(UPDATE_OVERLAYS)

/// Pipe branches reach the fitting's actual connected edge.
/datum/component/plumbing/stationtrauma_water/create_overlays(atom/movable/source, list/overlays)
	if(tile_covered || !active())
		return
	for(var/direction in GLOB.cardinals)
		if(direction & (supply_connects | demand_connects))
			var/state = ducts["[direction]"] ? "intact" : "exposed"
			var/mutable_appearance/branch = mutable_appearance('icons/obj/pipes_n_cables/pipe_underlays.dmi', "[state]_[direction]_[stationtrauma_water_level(ducting_layer)]", FLOAT_LAYER - 0.01, appearance_flags = RESET_COLOR|KEEP_APART)
			branch.color = STATIONTRAUMA_WATER_COLOR
			source.stationtrauma_position_water_branch(branch, direction)
			overlays += branch

/** Edge-mounted grilles cover the inner pipe end; the visible tail projects outwards. */
/atom/movable/proc/stationtrauma_position_water_branch(mutable_appearance/branch, direction)
	branch.pixel_x = -pixel_x
	branch.pixel_y = -pixel_y
	if(!istype(src, /obj/machinery/bilge_pump/ocean_intake) && !istype(src, /obj/machinery/stationtrauma_water_device/outlet/universal) && !istype(src, /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet) && !istype(src, /obj/machinery/stationtrauma_reactor_pipe/sea_outlet))
		return
	branch.pixel_x += direction == EAST ? 8 : direction == WEST ? -8 : 0
	branch.pixel_y += direction == NORTH ? 8 : direction == SOUTH ? -8 : 0

/proc/stationtrauma_water_level(layer_bit)
	for(var/level in 1 to 5)
		if(layer_bit == STATIONTRAUMA_WATER_LAYER_BIT(level))
			return level
	return 3

/datum/component/plumbing/stationtrauma_water/Initialize(new_layer)
	for(var/level in 1 to 5)
		if(new_layer == STATIONTRAUMA_WATER_LAYER_BIT(level))
			ducting_layer = new_layer
	return ..()
