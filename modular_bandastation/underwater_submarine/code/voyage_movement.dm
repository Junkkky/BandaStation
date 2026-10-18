/** One mobile port owns all three decks; ordinary TG shuttles keep their original behavior. */
/obj/docking_port/mobile/stationtrauma
	name = "подлодка «Нырок»"
	shuttle_id = "stationtrauma_prototype"
	area_type = /area/shuttle/stationtrauma
	width = 17
	height = 11
	movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)
	/// Fixed three-deck prototype, translated without rotation between mapped berths.
	var/decks = 3
	/// Explicit destinations supplied by the prototype loader.
	var/list/berths = list()
	/// Persistent private ocean stack, shared by successive trips of this vessel.
	var/obj/docking_port/stationary/stationtrauma/transit/transit_berth
	/// Route distances retain their departure reference while the vessel occupies transit.
	var/obj/docking_port/stationary/stationtrauma/departure_berth
	/// Native partial loads cannot safely be retried on the same running prototype.
	var/transit_attempted = FALSE
	/// Destinations become persistent berths on their first visit.
	var/list/unloaded_destinations = list(
		"Исследовательский пост" = /datum/map_template/stationtrauma_route/voyage_outpost,
		"Затопленные руины" = /datum/map_template/stationtrauma_route/voyage_ruins,
	)
	/// Departure animation and transfer share one command lock.
	var/travelling = FALSE
	/// Visible state on the navigation console.
	var/voyage_status = "На стоянке"
	/// Prototype route distances are metres; speed is metres per second.
	var/cruise_speed = 50
	var/voyage_distance = 0
	var/voyage_target
	var/voyage_started = 0
	var/voyage_duration = 0
	var/voyage_progress = 0
	var/loading_fraction = 0
	var/datum/stationtrauma_work_budget/transfer_budget

/** Distance is route metadata, independent of the z coordinates used to store a location. */
/obj/docking_port/mobile/stationtrauma/proc/distance_to(destination)
	if(!istext(destination) && !istype(destination, /obj/docking_port/stationary/stationtrauma))
		return null
	var/obj/docking_port/stationary/stationtrauma/origin = fixed_location || get_docked()
	if(origin == transit_berth)
		origin = departure_berth
	if(!origin)
		return null
	var/position
	if(istype(destination, /obj/docking_port/stationary/stationtrauma))
		var/obj/docking_port/stationary/stationtrauma/berth = destination
		position = berth.route_position
	else
		for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
			if(berth.name == destination)
				return abs(berth.route_position - origin.route_position)
		var/datum/map_template/stationtrauma_route/template_type = unloaded_destinations[destination]
		if(!template_type)
			return null
		var/obj/docking_port/stationary/stationtrauma/berth_type = initial(template_type.destination_berth_type)
		position = initial(berth_type.route_position)
	return abs(position - origin.route_position)

/** Arrival readiness bounds the approach; reaching the timer alone never reports a completed trip. */
/obj/docking_port/mobile/stationtrauma/proc/path_progress()
	if(travelling)
		var/time_fraction = voyage_duration ? (world.time - voyage_started) / voyage_duration : 1
		voyage_progress = max(voyage_progress, min(0.98, time_fraction, 0.1 + 0.88 * loading_fraction))
	return voyage_progress

/obj/docking_port/mobile/stationtrauma/proc/update_loading_progress(fraction)
	loading_fraction = max(loading_fraction, fraction)

/** Native move callbacks remain paired; only our port yields between small units of work. */
/obj/docking_port/mobile/stationtrauma/proc/yield_transfer()
	if(transfer_budget)
		transfer_budget.yield()
	else
		CHECK_TICK

/obj/docking_port/mobile/stationtrauma/Initialize(mapload, list/areas)
	. = ..()
	register()

/** Finish ownership after the entire multi-z TGM has loaded, including areas created after the port. */
/obj/docking_port/mobile/stationtrauma/proc/configure_berths(list/ports)
	berths = ports.Copy()
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
		unloaded_destinations -= berth.name
	shuttle_areas.Cut()
	var/list/tiles = return_ordered_turfs(x, y, z, dir)
	for(var/turf/tile as anything in tiles)
		var/area/ship_area = get_area(tile)
		if(!istype(ship_area, area_type))
			return FALSE
		shuttle_areas[ship_area] = TRUE
		for(var/obj/machinery/computer/stationtrauma_navigation/console in tile)
			console.vessel = src
	for(var/turf/tile as anything in tiles)
		SSfloodwater.ensure_water_domain(tile)
	return TRUE

/** Stable deck-major ordering pairs every source tile with the same local destination coordinate. */
/obj/docking_port/mobile/stationtrauma/return_ordered_turfs(_x, _y, _z, _dir)
	. = list()
	for(var/deck in 0 to decks - 1)
		. += ..(_x, _y, _z + deck, _dir)

/obj/docking_port/mobile/stationtrauma/is_in_shuttle_bounds(atom/target)
	var/turf/tile = get_turf(target)
	return tile && tile.z >= z && tile.z < z + decks && tile.x >= x && tile.x < x + width && tile.y >= y && tile.y < y + height && shuttle_areas[get_area(tile)]

/** Reject obstacles without calling TG's destructive landing/crushing callback. */
/obj/docking_port/mobile/stationtrauma/proc/arrival_clear(obj/docking_port/stationary/stationtrauma/berth)
	if(!istype(berth) || berth.dir != dir || berth.z == z || !check_dock(berth, silent = TRUE))
		return FALSE
	var/list/target = return_ordered_turfs(berth.x, berth.y, berth.z, berth.dir)
	if(target.len != width * height * decks)
		return FALSE
	for(var/turf/tile as anything in target)
		if(!berth.contains_berth_tile(tile) || !isspaceturf(tile) || !tile.GetComponent(/datum/component/floodwater) || SSfloodwater.hybrid.by_turf[tile])
			return FALSE
		for(var/atom/movable/obstacle as anything in tile)
			if(QDELETED(obstacle))
				continue
			if(istype(obstacle, /obj/docking_port/stationary/stationtrauma) || isobserver(obstacle) || istype(obstacle, /obj/effect/overlay) || istype(obstacle, /atom/movable/lighting_object) || istype(obstacle, /obj/effect/abstract/z_holder))
				continue
			return FALSE
	return TRUE

/** Use native object preparation, but never gib or delete occupants of a destination berth. */
/obj/docking_port/mobile/stationtrauma/preflight_check(list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, rotation)
	for(var/index in 1 to old_turfs.len)
		var/turf/old_tile = old_turfs[index]
		var/turf/new_tile = new_turfs[index]
		if(!old_tile || !new_tile || !shuttle_areas[get_area(old_tile)])
			return DOCKING_NULL_SOURCE
		var/area/ship_area = old_tile.loc
		var/move_mode = MOVE_AREA | MOVE_TURF | MOVE_CONTENTS
		var/datum/component/floodwater/old_water = old_tile.GetComponent(/datum/component/floodwater)
		var/datum/component/floodwater/new_water = new_tile.GetComponent(/datum/component/floodwater)
		// Identical infinite ocean stays in place; mounted equipment and area ownership still move.
		if(old_tile.type == new_tile.type && old_water?.infinite_source && new_water?.infinite_source)
			move_mode &= ~MOVE_TURF
		for(var/atom/movable/passenger as anything in old_tile)
			move_mode = passenger.beforeShuttleMove(new_tile, rotation, move_mode, src)
		if((move_mode & MOVE_TURF) && !isshuttleturf(old_tile))
			var/ocean = old_tile.z == z ? /turf/open/space/ocean : /turf/open/space/openspace/ocean
			var/list/stack = islist(old_tile.baseturfs) ? old_tile.baseturfs.Copy() : list(old_tile.baseturfs)
			stack.Insert(2, /turf/baseturf_skipover/shuttle)
			stack[1] = ocean
			old_tile.baseturfs = stack
		areas_to_move[ship_area] = TRUE
		var/area/underlying = underlying_areas_by_turf[old_tile]
		if(underlying)
			underlying_areas[underlying] = TRUE
		old_turfs[old_tile] = move_mode
		yield_transfer()

/** TG's cleanup also manufactures single-deck roofs; this local variant keeps our actual deck openings. */
/obj/docking_port/mobile/stationtrauma/cleanup_runway(obj/docking_port/stationary/new_dock, list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, list/moved_atoms, rotation, movement_direction, area/fallback_area)
	fallback_area.afterShuttleMove(initial(fallback_area.parallax_movedir))
	for(var/area/underlying as anything in underlying_areas)
		underlying.afterShuttleMove(initial(underlying.parallax_movedir))
	for(var/area/ship_area as anything in areas_to_move)
		ship_area.afterShuttleMove(new_dock == transit_berth ? EAST : NONE)
	for(var/index in 1 to old_turfs.len)
		var/turf/old_tile = old_turfs[index]
		var/turf/new_tile = new_turfs[index]
		if(old_turfs[old_tile] & MOVE_TURF)
			new_tile.afterShuttleMove(old_tile, rotation)
		yield_transfer()
	for(var/atom/movable/passenger as anything in moved_atoms)
		if(!QDELETED(passenger))
			passenger.afterShuttleMove(moved_atoms[passenger], movement_force, dir, preferred_direction, movement_direction, rotation)
		yield_transfer()
	fallback_area.lateShuttleMove()
	for(var/area/ship_area as anything in areas_to_move)
		ship_area.lateShuttleMove()
	for(var/area/underlying as anything in underlying_areas)
		underlying.lateShuttleMove()
	for(var/index in 1 to old_turfs.len)
		var/turf/new_tile = new_turfs[index]
		new_tile.lateShuttleMove(old_turfs[index])
		yield_transfer()
	for(var/atom/movable/passenger as anything in moved_atoms)
		if(!QDELETED(passenger))
			passenger.lateShuttleMove(moved_atoms[passenger], movement_force, movement_direction)
		yield_transfer()

/** Native wall turf copying omits dents and D-6 damage; retain both across the translation. */
/obj/docking_port/mobile/stationtrauma/takeoff(list/old_turfs, list/new_turfs, list/moved_atoms, rotation, movement_direction, old_dock, area/fallback_area)
	var/list/damage = list()
	for(var/turf/closed/wall/wall as anything in old_turfs)
		if(!iswallturf(wall))
			continue
		var/datum/component/torn_wall/tear = wall.GetComponent(/datum/component/torn_wall)
		if(!length(wall.dent_decals) && !tear)
			continue
		damage[wall] = list(wall.dent_decals?.Copy(), tear?.current_stage)
	// Keep TG's paired callbacks, yielding between small blocks instead of copying all decks in one tick.
	for(var/start = 1; start <= old_turfs.len; start += 4)
		yield_transfer()
		var/end = min(start + 4, old_turfs.len + 1)
		..(old_turfs.Copy(start, end), new_turfs.Copy(start, end), moved_atoms, rotation, movement_direction, old_dock, fallback_area)
		yield_transfer()
	for(var/index in 1 to old_turfs.len)
		var/list/saved = damage[old_turfs[index]]
		if(!saved)
			continue
		var/turf/closed/wall/wall = new_turfs[index]
		wall.dent_decals = saved[1]
		if(!isnull(saved[2]))
			wall.AddComponent(/datum/component/torn_wall, saved[2])
		wall.update_appearance(UPDATE_OVERLAYS)

/** Leave the location for a real ocean stack before loading the destination and cruising. */
/obj/docking_port/mobile/stationtrauma/proc/travel_to(destination, animate_trip = TRUE)
	if(fixed_location)
		return travel_fixed(destination, animate_trip)
	if(travelling || SSfloodwater.loading_ocean_levels.len || SSfloodwater.relocating_turfs.len)
		return FALSE
	// Console links identify points by name; validate an already loaded berth before departure too.
	if(istext(destination))
		for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
			if(berth.name == destination)
				destination = berth
				break
	var/distance = distance_to(destination)
	if(isnull(distance) || distance < 0 || (!distance && get_docked() != transit_berth))
		return FALSE
	if(!istext(destination) && (!(destination in berths) || !arrival_clear(destination)))
		voyage_status = "Переход невозможен: стоянка занята или недоступна"
		return FALSE
	travelling = TRUE
	transfer_budget = new
	if(get_docked() != transit_berth)
		departure_berth = get_docked()
	var/obj/docking_port/stationary/stationtrauma/selected_berth = istext(destination) ? null : destination
	voyage_target = selected_berth ? selected_berth.name : destination
	voyage_status = "В пути: [voyage_target]"
	voyage_distance = distance
	voyage_started = world.time
	voyage_duration = animate_trip ? max(5 SECONDS, distance / max(1, cruise_speed) * 1 SECONDS) : 0
	voyage_progress = 0
	loading_fraction = istext(destination) ? 0 : 1
	var/success = FALSE
	var/exception/voyage_error
	try
		if(prepare_transit() && (get_docked() == transit_berth || relocate_to(transit_berth)))
			voyage_status = "В пути: [voyage_target]"
			voyage_started = world.time
			for(var/area/ship_area as anything in shuttle_areas)
				ship_area.set_parallax_movedir(EAST)
			// Send the transit view before starting destination allocation and map parsing.
			sleep(world.tick_lag)
			var/obj/docking_port/stationary/stationtrauma/berth = istext(destination) ? load_destination(destination) : destination
			if(berth)
				loading_fraction = 1
				while(world.time < voyage_started + voyage_duration)
					sleep(world.tick_lag)
				success = relocate_to(berth)
		else
			voyage_status = "Не удалось выйти в транзитный океан"
	catch(var/exception/failure)
		voyage_error = failure
		voyage_status = "Переход прерван"
	for(var/area/ship_area as anything in shuttle_areas)
		ship_area.set_parallax_movedir(NONE)
	if(success)
		voyage_progress = 1
	travelling = FALSE
	if(voyage_error)
		stack_trace("StationTrauma voyage failed: [voyage_error]")
	return success

/** Transfer only to an initialized, still-clear berth after cruising and map preparation finish. */
/obj/docking_port/mobile/stationtrauma/proc/relocate_to(obj/docking_port/stationary/stationtrauma/berth)
	// A resumed hydraulic step must finish before any of its turf bindings are replaced.
	var/deadline = world.time + 10 SECONDS
	while(SSfloodwater.step_running && world.time < deadline)
		sleep(world.tick_lag)
	var/list/old_tiles = return_ordered_turfs(x, y, z, dir)
	if(SSfloodwater.step_running || SSfloodwater.relocating_turfs.len || SSfloodwater.loading_ocean_levels.len || !arrival_clear(berth) || !connections_contained(old_tiles))
		voyage_status = "Переход отменён: стоянка занята, шлюз работает, есть внешние соединения или загружается карта"
		return FALSE
	voyage_status = "Швартовка: [berth.name]"
	var/list/new_tiles = return_ordered_turfs(berth.x, berth.y, berth.z, berth.dir)
	var/list/mapping = list()
	var/list/crew = list()
	for(var/index in 1 to old_tiles.len)
		var/turf/tile = old_tiles[index]
		mapping[tile] = new_tiles[index]
		SSfloodwater.relocating_turfs[tile] = TRUE
		SSfloodwater.relocating_turfs[new_tiles[index]] = TRUE
		for(var/mob/living/passenger in tile)
			ADD_TRAIT(passenger, TRAIT_IMMOBILIZED, REF(src))
			crew += passenger
	SSfloodwater.hybrid.relocate_vessel(mapping, budget = transfer_budget)
	var/result = DOCKING_BLOCKED
	var/exception/transfer_error
	try
		result = initiate_docking(berth)
	catch(var/exception/failure)
		transfer_error = failure
	if(result == DOCKING_SUCCESS)
		SSfloodwater.hybrid.relocate_vessel(mapping, finish = TRUE, budget = transfer_budget)
	else
		for(var/turf/tile as anything in old_tiles)
			var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid.by_turf[tile]
			cell?.watch_turf()
	SSfloodwater.relocating_turfs.Cut()
	for(var/turf/tile as anything in return_ordered_turfs(x, y, z, dir))
		restore_stationtrauma_hull(tile)
		for(var/obj/machinery/bilge_pump/pump in tile)
			pump.invalidate_water_geometry()
		for(var/obj/machinery/button/stationtrauma_water_airlock/controller in tile)
			controller.link_equipment()
		for(var/obj/structure/window/window in tile)
			var/datum/component/floodwater_leak/leak = window.GetComponent(/datum/component/floodwater_leak)
			leak?.refresh()
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		water?.wake_neighbours()
		yield_transfer()
	for(var/mob/living/passenger as anything in crew)
		if(!QDELETED(passenger))
			REMOVE_TRAIT(passenger, TRAIT_IMMOBILIZED, REF(src))
	voyage_status = result == DOCKING_SUCCESS ? "Стоянка: [berth.name]" : "Ошибка перехода: [result]"
	if(transfer_error)
		stack_trace("StationTrauma transfer failed; inspect the vessel before another trip: [transfer_error]")
	return result == DOCKING_SUCCESS
