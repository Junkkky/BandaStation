/** The existing local RPD builds isolated devices without altering its water recipes. */
/obj/item/pipe_dispenser/stationtrauma
	/// One recipe list, shared with previews and server-side construction validation.
	var/static/list/plant_recipes = list(
		"Реакторная мультитруба" = /obj/machinery/stationtrauma_reactor_pipe,
		"Прямая труба" = /obj/machinery/stationtrauma_reactor_pipe/straight,
		"Угол трубы" = /obj/machinery/stationtrauma_reactor_pipe/elbow,
		"Тройник" = /obj/machinery/stationtrauma_reactor_pipe/tee,
		"Вентиль" = /obj/machinery/stationtrauma_reactor_pipe/valve,
		"Направленный насос" = /obj/machinery/stationtrauma_reactor_pipe/pump,
		"Забортный насос" = /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet,
		"Забортный выпуск" = /obj/machinery/stationtrauma_reactor_pipe/sea_outlet,
	)
	var/static/list/plant_recipe_info
	/// Installation identifier copied into new sections; default matches mapped machinery.
	var/plant_id = "main"
	/// Medium and physical pipe level are independent, as in the native RPD.
	var/plant_line = ST_PLANT_WATER
	var/static/list/plant_catalogues = list("Реактор: питательная вода", "Реактор: свежий пар", "Реактор: отработанный пар", "Реактор: охлаждение", "Реактор: забортное охлаждение")

/** Use native RPD directional previews; layer buttons select the five isolated media. */
/obj/item/pipe_dispenser/stationtrauma/proc/initialize_plant_catalogue()
	if(plant_recipe_info)
		return
	plant_recipe_info = list()
	var/list/states = list("manifold4w", "simple", "simple", "manifold", "mvalve", "pump", "scrubber", "pvent")
	var/list/directions = list(PIPE_ONEDIR, PIPE_STRAIGHT, PIPE_BENDABLE, PIPE_TRINARY, PIPE_STRAIGHT, PIPE_UNARY, PIPE_UNARY, PIPE_UNARY)
	for(var/index in 1 to length(plant_recipes))
		var/datum/pipe_info/info = new
		info.name = plant_recipes[index]
		info.id = plant_recipes[info.name]
		info.icon_state = states[index]
		info.dirtype = directions[index]
		info.desc = "Изолированный реакторный контур. Назначение воды или пара выбирается разделом, уровень трубы — штатными кнопками RPD. Насос подаёт по стрелке. Забор и выпуск работают с забортным охлаждением."
		plant_recipe_info += info

/** Append a catalogue using the stock RPD interface and its existing selection controls. */
/obj/item/pipe_dispenser/stationtrauma/proc/plant_catalogue_data(list/data)
	if(category != 0)
		return
	for(var/medium in 1 to length(plant_catalogues))
		var/list/choices = list()
		for(var/index in 1 to length(plant_recipes))
			var/datum/pipe_info/info = plant_recipe_info[index]
			var/list/previews = info.get_preview(p_dir, plant_recipe == index && plant_line == medium)
			if(index == 3)
				previews.Cut(1, 3)
			choices += list(list("pipe_name" = info.name, "pipe_desc" = info.desc, "pipe_index" = index, "previews" = previews))
		data["categories"] += list(list("cat_name" = plant_catalogues[medium], "recipes" = choices))
	if(plant_recipe)
		data["selected_category"] = plant_catalogues[plant_line]
		data["selected_recipe"] = plant_recipes[plant_recipe]

/** Validate the recipe and channel, then invalidate the topology after configuration. */
/obj/item/pipe_dispenser/stationtrauma/proc/build_plant_fixture(turf/tile, index, direction, line, connection_mask = ALL_CARDINALS, pipe_layer = PIPING_LAYER_DEFAULT)
	if(!isnum(index) || index != round(index) || index < 1 || index > length(plant_recipes) || !isnum(line) || line != round(line) || !(line in 1 to 5))
		return null
	direction = plant_fixture_direction(index, direction)
	if(!(direction in GLOB.cardinals))
		return null
	if(!isnum(pipe_layer) || pipe_layer != round(pipe_layer) || !(pipe_layer in 1 to 5))
		return null
	if(index == 1 && (!isnum(connection_mask) || connection_mask != round(connection_mask) || connection_mask < 1 || connection_mask > ALL_CARDINALS || ISSTUB(connection_mask)))
		return null
	var/path = plant_recipes[plant_recipes[index]]
	if(!isopenturf(tile) && !(isclosedturf(tile) && index <= 4))
		return null
	if(index >= 7)
		line = ST_PLANT_SEA
	for(var/obj/machinery/stationtrauma_reactor_pipe/existing in tile)
		if(existing.line == line && existing.piping_layer == pipe_layer)
			return null
	var/obj/machinery/stationtrauma_reactor_pipe/pipe = new path(tile)
	pipe.line = line
	pipe.plant_id = plant_id
	pipe.piping_layer = pipe_layer
	if(index == 1)
		pipe.connections = connection_mask
	pipe.setDir(direction)
	pipe.refresh_connections()
	return pipe

/** Native elbow previews use diagonal poses; the fixed elbow housing uses cardinals. */
/obj/item/pipe_dispenser/stationtrauma/proc/plant_fixture_direction(index, direction)
	if(index != 3)
		return direction
	switch(direction)
		if(NORTHEAST)
			return SOUTH
		if(SOUTHWEST)
			return NORTH
		if(NORTHWEST)
			return EAST
		if(SOUTHEAST)
			return WEST
	return NONE

/** Respect native placement/removal modes and revalidate after the placement delay. */
/obj/item/pipe_dispenser/stationtrauma/proc/dispense_plant_selection(atom/target, mob/living/user)
	if((mode & (1<<2)) && istype(target, /obj/machinery/stationtrauma_reactor_pipe))
		qdel(target)
		return ITEM_INTERACT_SUCCESS
	if((mode & (1<<2)) && istype(target, /obj/item/stationtrauma_reactor_fitting))
		qdel(target)
		return ITEM_INTERACT_SUCCESS
	if(!(mode & (1<<0)))
		return ITEM_INTERACT_BLOCKING
	var/turf/tile = get_turf(target)
	var/index = plant_recipe
	var/direction = p_dir
	var/channels = pipe_layers
	var/connection_mask = p_init_dir
	var/medium = plant_line
	if(!(plant_fixture_direction(index, direction) in GLOB.cardinals))
		return ITEM_INTERACT_BLOCKING
	if(!tile || !user.Adjacent(tile) || !do_after(user, 0.4 SECONDS, target = tile))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || !user.is_holding(src) || !user.Adjacent(tile) || !user.can_perform_action(tile, NEED_DEXTERITY | NEED_HANDS))
		return ITEM_INTERACT_BLOCKING
	var/built = 0
	for(var/pipe_layer in 1 to 5)
		if(!(channels & (1 << (pipe_layer - 1))))
			continue
		if(!(mode & (1<<1)))
			var/obj/item/stationtrauma_reactor_fitting/fitting = new(tile)
			fitting.fixture_type = plant_recipes[plant_recipes[index]]
			fitting.line = index >= 7 ? ST_PLANT_SEA : medium
			fitting.piping_layer = pipe_layer
			fitting.plant_id = plant_id
			fitting.connection_mask = index == 1 ? connection_mask : null
			fitting.setDir(plant_fixture_direction(index, direction))
			built++
		else if(build_plant_fixture(tile, index, direction, medium, connection_mask, pipe_layer))
			built++
	balloon_alert(user, built ? "установлено: [built]" : "место занято")
	return built ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

/** A dismantled section preserves its type, medium, facing and installation identifier. */
/obj/item/stationtrauma_reactor_fitting
	name = "секция реакторного контура"
	desc = "Ключ — установить секцию. ПКМ — повернуть."
	icon = 'icons/obj/pipes_n_cables/!pipes_bitmask.dmi'
	icon_state = "12_3"
	/// Validated machinery subtype to restore.
	var/fixture_type = /obj/machinery/stationtrauma_reactor_pipe
	var/line = ST_PLANT_WATER
	var/plant_id = "main"
	/// Preserve mapper-defined branch masks when a section is dismantled.
	var/connection_mask
	var/piping_layer = PIPING_LAYER_DEFAULT
	var/hide = FALSE

/obj/item/stationtrauma_reactor_fitting/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_rotation)

/obj/item/stationtrauma_reactor_fitting/examine(mob/user)
	. = ..()
	. += span_notice("Линия: [stationtrauma_plant_line_name(line)]. Установка: [plant_id].")

/obj/item/stationtrauma_reactor_fitting/wrench_act(mob/living/user, obj/item/tool)
	var/turf/tile = get_turf(src)
	if(!isturf(loc) || !ispath(fixture_type, /obj/machinery/stationtrauma_reactor_pipe) || !(line in 1 to 5) || !(dir in GLOB.cardinals))
		return ITEM_INTERACT_BLOCKING
	var/is_device = ispath(fixture_type, /obj/machinery/stationtrauma_reactor_pipe/pump) || ispath(fixture_type, /obj/machinery/stationtrauma_reactor_pipe/valve) || ispath(fixture_type, /obj/machinery/stationtrauma_reactor_pipe/sea_outlet)
	if(!isopenturf(tile) && !(isclosedturf(tile) && !is_device))
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 0.4 SECONDS, volume = 30) || QDELETED(src) || loc != tile)
		return ITEM_INTERACT_BLOCKING
	for(var/obj/machinery/stationtrauma_reactor_pipe/existing in tile)
		if(existing.line == line && existing.piping_layer == piping_layer)
			return ITEM_INTERACT_BLOCKING
	var/obj/machinery/stationtrauma_reactor_pipe/pipe = new fixture_type(tile)
	pipe.line = line
	pipe.plant_id = plant_id
	pipe.piping_layer = piping_layer
	pipe.hide = hide
	if(!isnull(connection_mask))
		pipe.connections = connection_mask
	pipe.setDir(dir)
	pipe.refresh_connections()
	qdel(src)
	return ITEM_INTERACT_SUCCESS
