/** Keep route editable as one multi-z TGM, allocating its whole stack before any atoms initialize. */
/datum/map_template/stationtrauma_route
	name = "StationTrauma route"
	mappath = 'modular_bandastation/underwater/maps/stationtrauma_route.dmm'
	should_place_on_top = FALSE
	/// Optional progress recipient for a submarine travelling during this load.
	var/datum/callback/loading_progress
	/// Cooperative work budget, independent of the global master controller limits.
	var/datum/stationtrauma_work_budget/loading_budget
	var/loading_first_z
	var/loading_decks
	/// Optional exterior area shared by every deck outside the mapped structure.
	var/exterior_ocean_area
	/// Destination oceans retain full-width passages but need no empty water beyond their view margin.
	var/compact_ocean = FALSE
	/// Optional compact-site padding; zero retains the distant transition corridor's margin.
	var/ocean_margin = 0
	/// Inclusive Y bounds, shared by native placement and initialization; X always spans the level.
	var/loading_min_y = 1
	/// Null outside load_new_z() preserves the primary-map ocean fill.
	var/loading_max_y

/** Callbacks report completed work only; the console does not poll the loaded world. */
/datum/map_template/stationtrauma_route/proc/report_loading(fraction)
	// Work shares: template 10%, exterior 20%, atom initialization 65%, final boundaries 5%.
	loading_progress?.Invoke(clamp(fraction, 0, 1))

/** Defer ocean boundary notifications until the new stack has its final geometry and lighting. */
/datum/controller/subsystem/floodwater
	/// Only the fresh levels currently owned by the route loader; string z keys.
	var/list/loading_ocean_levels = list()

/datum/map_template/stationtrauma_route/load_new_z(secret = FALSE)
	if(SSfloodwater.loading_ocean_levels.len || SSfloodwater.loading_structure_turfs.len)
		return FALSE
	var/load_started = REALTIMEOFDAY
	log_mapping("StationTrauma [name]: loading [mappath]")
	var/datum/parsed_map/parsed = new(file(mappath))
	if(!parsed.bounds)
		return FALSE
	var/deck_count = parsed.bounds[MAP_MAXZ]
	loading_decks = deck_count
	if(parsed.bounds[MAP_MINZ] != 1 || deck_count < 2 || width > world.maxx || height > world.maxy)
		stack_trace("StationTrauma route requires at least two decks beginning at z=1 and fitting the world")
		return FALSE
	var/deadline = world.time + 10 SECONDS
	while(SSfloodwater.step_running && world.time < deadline)
		sleep(world.tick_lag)
	if(SSfloodwater.step_running || SSfloodwater.loading_ocean_levels.len || SSfloodwater.loading_structure_turfs.len)
		return FALSE
	var/datum/space_level/first_level
	var/list/levels = list()
	var/loaded = FALSE
	var/exception/load_error
	loading_budget = new
	SSfloodwater.loading_ocean_levels["pending"] = TRUE
	try
		var/phase_started = REALTIMEOFDAY
		for(var/deck in 1 to deck_count)
			loading_budget.yield()
			var/list/traits = secret ? ZTRAITS_AWAY_SECRET : ZTRAITS_AWAY
			traits[ZTRAIT_BASETURF] = deck > 1 ? /turf/open/openspace : /turf/open/space/ocean
			if(deck > 1)
				traits[ZTRAIT_DOWN] = TRUE
			if(deck < deck_count)
				traits[ZTRAIT_UP] = TRUE
			var/datum/space_level/level = SSmapping.add_new_zlevel("[name]: deck [deck]", traits, contain_turfs = FALSE)
			first_level ||= level
			loading_first_z = first_level.z_value
			levels += level.z_value
			SSfloodwater.loading_ocean_levels["[level.z_value]"] = TRUE
			if(level.z_value != first_level.z_value + deck - 1)
				throw EXCEPTION("Another loader interrupted the contiguous StationTrauma deck allocation")
			// LINDA can reach a new placeholder before its ocean marker has initialized.
			for(var/turf/open/space/basic/placeholder in Z_TURFS(level.z_value))
				if(!placeholder.air)
					placeholder.air = placeholder.space_gas
				loading_budget.yield()
			report_loading(0.05 * deck / deck_count)
		log_mapping("StationTrauma [name]: allocated [deck_count] decks in [(REALTIMEOFDAY - phase_started) / 10]s")
		// The old space area cached its lighting before this stack introduced another plane offset.
		var/area/space/placeholders = GLOB.areas_by_type[/area/space]
		if(placeholders?.lighting_effects)
			for(var/offset in placeholders.lighting_effects.len to SSmapping.max_plane_offset)
				var/mutable_appearance/light = new(placeholders.lighting_effects[1])
				SET_PLANE_W_SCALAR(light, LIGHTING_PLANE, offset)
				placeholders.lighting_effects += light
		var/x_start = round((world.maxx - width) * 0.5) + 1
		var/y_start = round((world.maxy - height) * 0.5) + 1
		// Both passes use fresh, uninitialized turfs; the native loader owns batching and mapload state.
		phase_started = REALTIMEOFDAY
		loaded = parsed.load(x_start, y_start, first_level.z_value, no_changeturf = TRUE, place_on_top = should_place_on_top, new_z = TRUE)
		log_mapping("StationTrauma [name]: placed structure in [(REALTIMEOFDAY - phase_started) / 10]s")
		report_loading(0.1)
		if(loaded)
			var/view_margin = CEILING(maxviewdist() / 2, 1) + 2
			var/margin = max(view_margin, ocean_margin || (max(30, maxviewdist()) + view_margin))
			loading_min_y = compact_ocean ? max(1, parsed.bounds[MAP_MINY] - margin) : 1
			loading_max_y = compact_ocean ? min(world.maxy, parsed.bounds[MAP_MAXY] + margin) : world.maxy
			log_mapping("StationTrauma [name]: ocean [world.maxx]x[loading_max_y - loading_min_y + 1] per deck, full-width passage")
			for(var/level in levels)
				phase_started = REALTIMEOFDAY
				if(!fill_ocean(level))
					loaded = FALSE
					break
				log_mapping("StationTrauma [name]: filled ocean z=[level] in [(REALTIMEOFDAY - phase_started) / 10]s")
		if(loaded)
			require_area_resort()
			initTemplateBounds(parsed.bounds)
			for(var/level in levels)
				phase_started = REALTIMEOFDAY
				initialize_ocean(level)
				log_mapping("StationTrauma [name]: initialized atoms and lighting z=[level] in [(REALTIMEOFDAY - phase_started) / 10]s")
	catch(var/exception/failure)
		load_error = failure
		loaded = FALSE
	for(var/level in levels)
		SSfloodwater.loading_ocean_levels -= "[level]"
	SSfloodwater.loading_ocean_levels -= "pending"
	if(load_error)
		stack_trace("StationTrauma ocean load failed: [load_error]")
	if(!loaded)
		return FALSE
	finish_ocean(parsed.bounds)
	log_mapping("StationTrauma [name]: load complete in [(REALTIMEOFDAY - load_started) / 10]s")
	report_loading(1)
	return first_level

/** Load only untouched exterior space through the native maploader, before any template initialization. */
/datum/map_template/stationtrauma_route/proc/fill_ocean(level)
	var/turf/origin = locate(1, 1, level)
	var/upper_deck = !!GET_TURF_BELOW(origin)
	var/ocean_path = upper_deck ? /turf/open/space/openspace/ocean : /turf/open/space/ocean
	var/area_path = exterior_ocean_area || (upper_deck ? /area/space/ocean/openspace : /area/space/ocean)
	// A small reusable native map bounds each call instead of filling an entire level in one call.
	var/chunk_side = 8
	var/max_y = loading_max_y || world.maxy
	// The template pass already registered area membership for this level.
	var/deck_index = level - loading_first_z
	for(var/start_y = loading_min_y; start_y <= max_y; start_y += chunk_side)
		var/list/rows = list()
		for(var/row_y = min(max_y, start_y + chunk_side - 1); row_y >= start_y; row_y--)
			// Solid canyon edges keep the unused part of the Z-level inaccessible, without a vacuum boundary.
			rows += compact_ocean && (row_y == loading_min_y || row_y == max_y) ? "b\n" : "a\n"
		var/column = rows.Join()
		var/list/map_text = list("\"a\" = (\n[ocean_path],\n[area_path])\n\"b\" = (\n/turf/closed/indestructible/rock,\n[area_path])\n")
		for(var/column_x in 1 to chunk_side)
			map_text += "([column_x],1,1) = {\"\n[column]\"}\n"
		var/datum/parsed_map/ocean = new(map_text.Join())
		ocean.turf_blacklist = list()
		for(var/start_x = 1; start_x <= world.maxx; start_x += chunk_side)
			loading_budget.yield()
			ocean.turf_blacklist.Cut()
			// Recheck the live small block; a later chunk must not overwrite construction made during a yield.
			for(var/turf/tile as anything in block(start_x, start_y, level, min(world.maxx, start_x + chunk_side - 1), min(max_y, start_y + chunk_side - 1), level))
				if((tile.type != /turf/open/space/basic && tile.type != /turf/open/space && tile.type != /turf/open/space/openspace) || tile.loc.type != /area/space)
					ocean.turf_blacklist[tile] = TRUE
			if(!ocean.load(start_x, start_y, level, crop_map = TRUE, no_changeturf = TRUE))
				return FALSE
		report_loading(0.1 + 0.2 * (deck_index + min(1, (start_y + chunk_side - loading_min_y) / (max_y - loading_min_y + 1))) / loading_decks)
	return TRUE

/** Empty exterior needs native atom/lighting initialization, without template machinery or air activation. */
/datum/map_template/stationtrauma_route/proc/initialize_ocean(level)
	if(SSatoms.initialized == INITIALIZATION_INSSATOMS)
		return
	var/list/areas = list()
	var/list/turfs = list()
	var/list/edges = list()
	var/list/movables = list()
	for(var/turf/tile as anything in block(1, loading_min_y, level, world.maxx, loading_max_y || world.maxy, level))
		if((tile.flags_1 & INITIALIZED_1) || (!istype(tile, /turf/open/space/ocean) && !istype(tile, /turf/open/space/openspace/ocean) && !istype(tile, /turf/closed/indestructible/rock)))
			continue
		areas |= get_area(tile)
		if(istype(tile, /turf/closed/indestructible/rock))
			edges += tile
		else
			turfs += tile
		for(var/atom/movable/occupant as anything in tile)
			movables += occupant
		loading_budget.yield()
	SSmapping.reg_in_areas_in_z(areas)
	SSatoms.InitializeAtoms(areas)
	// Native initialization holds smoothing until every adjacent rock has parsed its groups.
	SSatoms.InitializeAtoms(edges)
	SSlighting.setup_static_lighting_if_needed(edges)
	var/deck_index = level - loading_first_z
	for(var/start = 1; start <= turfs.len; start += 32)
		loading_budget.yield()
		var/list/batch = turfs.Copy(start, min(start + 32, turfs.len + 1))
		SSatoms.InitializeAtoms(batch)
		SSlighting.setup_static_lighting_if_needed(batch)
		report_loading(0.3 + 0.65 * (deck_index + min(1, (start + 31) / turfs.len)) / loading_decks)
	SSatoms.InitializeAtoms(movables)

/** Only the mapped structure and its immediate border need boundary notifications and smoothing. */
/datum/map_template/stationtrauma_route/proc/finish_ocean(list/bounds)
	for(var/turf/tile as anything in block(max(1, bounds[MAP_MINX] - 1), max(1, bounds[MAP_MINY] - 1), bounds[MAP_MINZ], min(world.maxx, bounds[MAP_MAXX] + 1), min(world.maxy, bounds[MAP_MAXY] + 1), bounds[MAP_MAXZ]))
		SSfloodwater.ensure_water_domain(tile)
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		if(water?.infinite_source)
			for(var/direction in GLOB.cardinals)
				restore_stationtrauma_hull(get_step(tile, direction))
			water.on_atmos_update()
		QUEUE_SMOOTH(tile)
		for(var/atom/movable/occupant as anything in tile)
			QUEUE_SMOOTH(occupant)
		loading_budget.yield()
	require_area_resort()

ADMIN_VERB(stationtrauma_load_route, R_DEBUG, "StationTrauma - Load Route", "Load route as a connected multi-deck ocean map.", ADMIN_CATEGORY_DEBUG)
	var/datum/map_template/stationtrauma_route/template = new
	var/datum/space_level/lower = template.load_new_z()
	if(lower)
		to_chat(user, span_notice("Route loaded on connected z-levels starting at [lower.z_value]."), confidential = TRUE)
		message_admins("[key_name_admin(user)] loaded the StationTrauma route deck stack.")
	else
		to_chat(user, span_warning("Route could not be loaded."), confidential = TRUE)
	qdel(template)
