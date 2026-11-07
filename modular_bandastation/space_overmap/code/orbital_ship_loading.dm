/** Ship templates reserve every deck before native loading initializes the map. */
/datum/map_template/stationtrauma_space/ship
	/// Number of contiguous decks declared by the source map.
	var/depth = 0
	/// Source coordinates must start at one and fit the existing world dimensions.
	var/valid_source_bounds = FALSE
	/// Exact managed levels reserved for this load, including an empty deck.
	var/list/loaded_levels = list()
	/// Native centered footprint captured before loading can yield or expand the world.
	var/loaded_min_x
	var/loaded_min_y

/datum/map_template/stationtrauma_space/ship/Destroy()
	loaded_levels?.Cut()
	loaded_levels = null
	return ..()

/datum/map_template/stationtrauma_space/ship/preload_size(path, cache = FALSE)
	var/list/bounds = ..()
	if(!bounds)
		return
	depth = bounds[MAP_MAXZ]
	valid_source_bounds = bounds[MAP_MINX] == 1 && bounds[MAP_MINY] == 1 && bounds[MAP_MINZ] == 1 \
		&& ISINTEGER(width) && width > 0 && width <= world.maxx \
		&& ISINTEGER(height) && height > 0 && height <= world.maxy && ISINTEGER(depth) && depth > 0
	return bounds

/datum/map_template/stationtrauma_space/ship/load_new_z(secret = FALSE)
	if(!valid_source_bounds)
		log_mapping("Overmap ship template [mappath] requires valid bounds starting at 1,1,1 within the world dimensions")
		return null
	loaded_levels = list()
	loaded_min_x = round((world.maxx - width) / 2) + 1
	loaded_min_y = round((world.maxy - height) / 2) + 1
	var/datum/space_level/first_level
	for(var/deck in 1 to depth)
		var/list/traits = secret ? ZTRAITS_AWAY_SECRET : ZTRAITS_AWAY
		if(deck > 1)
			traits[ZTRAIT_DOWN] = TRUE
		if(deck < depth)
			traits[ZTRAIT_UP] = TRUE
		var/level_name = depth == 1 ? name : "[name] — палуба [deck]"
		var/datum/space_level/level = SSmapping.add_new_zlevel(level_name, traits, contain_turfs = FALSE)
		loaded_levels += level.z_value
		if(!first_level)
			first_level = level
		if(level.z_value != first_level.z_value + deck - 1)
			log_mapping("Overmap ship [mappath] could not reserve contiguous managed decks")
			discard_loaded_ship()
			return null
	var/datum/parsed_map/parsed = load_map(
		file(mappath),
		loaded_min_x,
		loaded_min_y,
		first_level.z_value,
		no_changeturf = (SSatoms.initialized == INITIALIZATION_INSSATOMS),
		place_on_top = should_place_on_top,
		new_z = TRUE,
	)
	if(!parsed?.bounds)
		discard_loaded_ship()
		return null
	require_area_resort()
	initTemplateBounds(parsed.bounds)
	for(var/z_level in loaded_levels)
		smooth_zlevel(z_level)
	log_game("Overmap ship [name] loaded on [depth] managed decks starting at [loaded_min_x],[loaded_min_y],[first_level.z_value]")
	return first_level

/** Remove a rejected load only from this template's reserved levels and original footprint. */
/datum/map_template/stationtrauma_space/ship/proc/discard_loaded_ship()
	if(!length(loaded_levels))
		return
	var/list/levels = loaded_levels.Copy()
	loaded_levels.Cut()
	var/area/space/exterior = GLOB.areas_by_type[/area/space]
	if(QDELETED(exterior))
		exterior = new /area/space
	var/list/areas = list()
	var/datum/stationtrauma_work_budget/budget = new
	for(var/z_level in levels)
		for(var/turf/tile as anything in block(locate(loaded_min_x, loaded_min_y, z_level), locate(loaded_min_x + width - 1, loaded_min_y + height - 1, z_level)))
			budget.yield()
			areas |= get_area(tile)
			tile.empty(/turf/open/space, /turf/open/space, flags = CHANGETURF_FORCEOP | CHANGETURF_NO_AREA_CHANGE | CHANGETURF_IGNORE_AIR)
			// Native empty() preserves ports, landmarks and observers. They also belong to this rejected load.
			for(var/atom/movable/remaining in tile.get_all_contents())
				if(!QDELETED(remaining))
					qdel(remaining, force = TRUE)
			tile.change_area(get_area(tile), exterior)
			var/turf/open/space/vacuum = tile
			vacuum.air ||= vacuum.space_gas
	for(var/area/old_area as anything in areas)
		if(old_area != exterior && !QDELETED(old_area) && !old_area.has_contained_turfs())
			qdel(old_area)
	exterior.reg_in_areas_in_z()
	require_area_resort()

/** Keep one cleanup boundary around map loading, ownership discovery and native initialization. */
/proc/load_stationtrauma_space_ship(map_path)
	var/datum/map_template/stationtrauma_space/ship/template = new(map_path, "Overmap ship")
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	try
		vessel = template.load_ship()
	catch(var/exception/failure)
		template.discard_loaded_ship()
		qdel(template)
		throw failure
	if(!vessel)
		template.discard_loaded_ship()
	qdel(template)
	return vessel

/** Collect the whole ship before its one native mobile port is initialized. */
/datum/map_template/stationtrauma_space/ship/proc/load_ship()
	var/datum/space_level/first_level = load_new_z()
	if(!first_level)
		return null
	var/list/areas = list()
	var/list/obj/docking_port/mobile/mobiles = list()
	var/datum/stationtrauma_work_budget/budget = new
	for(var/z_level in loaded_levels)
		for(var/turf/tile as anything in block(locate(loaded_min_x, loaded_min_y, z_level), locate(loaded_min_x + width - 1, loaded_min_y + height - 1, z_level)))
			budget.yield()
			areas |= get_area(tile)
			for(var/obj/docking_port/mobile/mobile in tile)
				mobiles += mobile
	if(length(mobiles) != 1 || QDELETED(mobiles[1]) || !istype(mobiles[1], /obj/docking_port/mobile/stationtrauma_space))
		log_mapping("Overmap ship [mappath] requires exactly one overmap mobile docking port across all decks")
		return null
	var/obj/docking_port/mobile/stationtrauma_space/vessel = mobiles[1]
	vessel.owned_z_levels = loaded_levels.Copy()
	for(var/area/ship_area as anything in areas)
		if(istype(ship_area, vessel.area_type))
			vessel.shuttle_areas[ship_area] = TRUE
	if(!length(vessel.shuttle_areas))
		log_mapping("Overmap ship [mappath] has no areas matching its declared hull area type")
		return null
	vessel.calculate_docking_port_information()
	SSatoms.InitializeAtoms(list(vessel))
	return vessel
