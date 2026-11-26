/** Standard slot. Local +X points to the wall; the marker is the first corner of the hull rectangle. */
/obj/docking_port/stationary/stationtrauma_space_station/standard
	name = "Стыковочный слот S"
	station_name = "Стыковочный слот S"
	shuttle_id = "overmap_standard_s"
	site_id = "overmap_standard_s"
	width = ST_STANDARD_S_WIDTH
	height = ST_STANDARD_S_HEIGHT
	area_type = /area/space
	/// Display label of this slot's standard.
	var/dock_class = "S"
	/// Largest standard hull class admitted by the slot.
	var/accepted_ship_class = ST_SHIP_SMALL
	/// Land directly on a solid pad without a wall or gangway.
	var/hangar = FALSE
	/// Moor anywhere inside the slot over open space, like a hangar without its deck, shutters or glow.
	var/open_space = FALSE
	/// An open slot that also takes natural ground, for landing clearings on a planet.
	var/ground = FALSE
	/// The technical berth exists only for the current approach or occupant.
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/active_berth

/obj/docking_port/stationary/stationtrauma_space_station/standard_s
	parent_type = /obj/docking_port/stationary/stationtrauma_space_station/standard

/obj/docking_port/stationary/stationtrauma_space_station/standard_m
	parent_type = /obj/docking_port/stationary/stationtrauma_space_station/standard
	name = "Стыковочный слот M"
	station_name = "Стыковочный слот M"
	shuttle_id = "overmap_standard_m"
	site_id = "overmap_standard_m"
	width = ST_STANDARD_M_WIDTH
	height = ST_STANDARD_M_HEIGHT
	dock_class = "M"
	accepted_ship_class = ST_SHIP_MEDIUM

/** Landing pad on the highest deck of its linked stack. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/hangar
	name = "Ангар"
	station_name = "Ангар"
	shuttle_id = "overmap_hangar"
	site_id = "overmap_hangar"
	width = ST_STANDARD_M_WIDTH
	height = ST_STANDARD_M_HEIGHT
	dock_class = "Ангар"
	accepted_ship_class = ST_SHIP_MEDIUM
	hangar = TRUE

/// Open-space mooring beside a ruin, on its own level.
/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad
	name = "Стоянка у объекта"
	station_name = "Стоянка у объекта"
	shuttle_id = "overmap_ruin_pad"
	site_id = "overmap_ruin_pad"
	width = ST_STANDARD_M_WIDTH
	height = ST_STANDARD_M_HEIGHT
	dock_class = "M"
	accepted_ship_class = ST_SHIP_MEDIUM
	open_space = TRUE

/// Landing clearing on a planet: S and M hulls set down on bare ground in whichever orientation fits.
/obj/docking_port/stationary/stationtrauma_space_station/standard/planet_pad
	name = "Посадочная площадка экспедиции"
	station_name = "Посадочная площадка экспедиции"
	shuttle_id = "overmap_planet_pad"
	site_id = "overmap_planet_pad"
	width = ST_STANDARD_M_WIDTH
	height = ST_STANDARD_M_HEIGHT
	dock_class = "M"
	accepted_ship_class = ST_SHIP_MEDIUM
	open_space = TRUE
	ground = TRUE

/obj/docking_port/stationary/stationtrauma_space_station/standard/Destroy(force)
	if(force)
		clear_berth()
	return ..()

/** Cheap compatibility check for navigation displays. Obstructions are checked on demand. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/accepts(obj/docking_port/mobile/stationtrauma_space/ship)
	if(QDELETED(ship) || (host_ship_id && (QDELETED(host) || host.sector?.sites[site_id] != carrier_site)))
		return FALSE
	if(hangar && !stationtrauma_hangar_top_level(get_turf(src), host))
		return FALSE
	var/compatible_class = ship.ship_class == accepted_ship_class || (ship.ship_class == ST_SHIP_SMALL && accepted_ship_class == ST_SHIP_MEDIUM)
	return compatible_class && ship.width > 0 && ship.height > 0 \
		&& min(ship.width, ship.height) <= width && max(ship.width, ship.height) <= height \
		&& (dir in GLOB.cardinals) && (ship.dir in GLOB.cardinals)

/** Fit the landing or gangways, optionally recording the reason no berth is available. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/prepare_berth(obj/docking_port/mobile/stationtrauma_space/ship, list/diagnostic)
	if(active_berth || !accepts(ship))
		if(diagnostic)
			diagnostic["reason"] = "причал недоступен или занят"
		return null
	ship.initialize_docking_layers()
	host?.vessel.initialize_docking_layers()
	var/list/slot = return_turfs()
	if(length(slot) != width * height)
		if(diagnostic)
			diagnostic["reason"] = "разметка причала выходит за пределы площадки"
		return null
	if(hangar || open_space)
		var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = fit_hangar_berth(ship, slot)
		if(!berth && diagnostic)
			diagnostic["reason"] = "площадка перекрыта или не вмещает корабль"
		return berth
	var/list/rotation = stationtrauma_port_rotation(dir)
	var/wall_direction = turn(dir, 90)
	var/toward_wall = REVERSE_DIR(wall_direction)
	var/wall_column = width + 1
	var/list/source = ship.return_ordered_turfs(ship.x, ship.y, ship.z, ship.dir)
	var/list/hatches = list()
	var/hatch_failure
	for(var/turf/tile as anything in source)
		if(!ship.shuttle_areas[get_area(tile)])
			continue
		for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch in tile)
			var/problem = hatch_problem(ship, hatch)
			if(problem)
				hatch_failure ||= problem
			else
				hatches += hatch
	if(!length(hatches))
		if(diagnostic)
			diagnostic["reason"] = hatch_failure || "на корабле нет стыковочного шлюза"
		return null
	var/list/slot_bounds = return_coords()
	var/fits_bounds = FALSE
	var/hull_clear = FALSE
	var/wall_failure
	var/path_failure
	for(var/facing in list(ship.dir, REVERSE_DIR(ship.dir), turn(ship.dir, 90), turn(ship.dir, -90)))
		var/list/offsets = list()
		for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch as anything in hatches)
			if(turn(hatch.dir, dir2angle(ship.dir) - dir2angle(facing)) == toward_wall)
				offsets[hatch] = ship.rotated_offset(get_turf(hatch), facing)
		if(!length(offsets))
			continue
		var/turf/best_anchor
		var/list/best_routes
		var/best_total_length = 0
		for(var/turf/anchor as anything in slot)
			if(!contains_projection(slot_bounds, ship.return_coords(anchor.x, anchor.y, facing)))
				continue
			fits_bounds = TRUE
			var/list/hull = project_hull(ship, anchor, facing)
			if(!length(hull))
				continue
			hull_clear = TRUE
			var/list/routes_by_wall = list()
			var/total_length = 0
			for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch as anything in offsets)
				var/list/offset = offsets[hatch]
				var/turf/projected_hatch = locate(anchor.x + offset[1], anchor.y + offset[2], z)
				var/row = (projected_hatch.y - y) * rotation[1] - (projected_hatch.x - x) * rotation[2]
				var/turf/wall_tile = locate(x + wall_column * rotation[1] - row * rotation[2], y + wall_column * rotation[2] + row * rotation[1], z)
				var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = locate() in wall_tile
				var/problem = wall_problem(wall, wall_tile, wall_direction)
				if(problem)
					wall_failure ||= problem
					continue
				if(routes_by_wall[wall])
					continue
				var/list/path = gangway_path(wall, projected_hatch, hull)
				if(!length(path))
					path_failure ||= "полоса трапа перекрыта перед секцией ([wall.x], [wall.y])"
					continue
				routes_by_wall[wall] = list(hatch, path)
				total_length += length(path)
			var/route_count = length(routes_by_wall)
			var/best_count = length(best_routes)
			if(route_count > best_count || (route_count && route_count == best_count && total_length < best_total_length))
				best_anchor = anchor
				best_routes = routes_by_wall
				best_total_length = total_length
		if(best_anchor)
			var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = create_berth(ship, best_anchor, facing)
			for(var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall as anything in best_routes)
				var/list/entry = best_routes[wall]
				var/datum/stationtrauma_dock_route/route = new
				route.hatch = entry[1]
				route.wall = wall
				route.path = entry[2]
				berth.routes += route
			return berth
	// Report the check reached furthest by a valid candidate, even when other rows fail earlier.
	if(diagnostic)
		if(!fits_bounds)
			diagnostic["reason"] = "корпус не помещается на площадке при развороте шлюзом к стене"
		else if(!hull_clear)
			diagnostic["reason"] = "площадка причала перекрыта на пути корпуса"
		else
			diagnostic["reason"] = path_failure || wall_failure
	return null

/** Preserve the incoming heading when possible and land as close to the center of the pad as the hull permits. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/fit_hangar_berth(obj/docking_port/mobile/stationtrauma_space/ship, list/pad_tiles)
	var/list/pad_bounds = return_coords()
	var/pad_center_x = (pad_bounds[1] + pad_bounds[3]) / 2
	var/pad_center_y = (pad_bounds[2] + pad_bounds[4]) / 2
	for(var/facing in list(ship.dir, REVERSE_DIR(ship.dir), turn(ship.dir, 90), turn(ship.dir, -90)))
		var/turf/best_anchor
		var/best_distance = INFINITY
		for(var/turf/anchor as anything in pad_tiles)
			var/list/hull_bounds = ship.return_coords(anchor.x, anchor.y, facing)
			if(!contains_projection(pad_bounds, hull_bounds))
				continue
			var/hull_center_x = (hull_bounds[1] + hull_bounds[3]) / 2
			var/hull_center_y = (hull_bounds[2] + hull_bounds[4]) / 2
			var/distance = abs(hull_center_x - pad_center_x) + abs(hull_center_y - pad_center_y)
			if(distance >= best_distance || !length(project_hull(ship, anchor, facing)))
				continue
			best_distance = distance
			best_anchor = anchor
		if(best_anchor)
			return create_berth(ship, best_anchor, facing)
	return null

/** Attach a native port to the current reservation using the incoming hull's actual dimensions. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/create_berth(obj/docking_port/mobile/stationtrauma_space/ship, turf/anchor, facing)
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = new(anchor)
	berth.width = ship.width
	berth.height = ship.height
	berth.dwidth = ship.dwidth
	berth.dheight = ship.dheight
	berth.setDir(facing)
	berth.slot = src
	berth.ship = ship
	berth.order_revision = ship.overmap.control_revision
	active_berth = berth
	return berth

/** Forget the technical berth after an aborted approach, departure or forced teardown. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/clear_berth()
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/old_berth = active_berth
	active_berth = null
	if(old_berth)
		qdel(old_berth, force = TRUE)

/** Check both projected corners against the full slot rectangle. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/contains_projection(list/slot_bounds, list/hull_bounds)
	return min(hull_bounds[1], hull_bounds[3]) >= min(slot_bounds[1], slot_bounds[3]) && max(hull_bounds[1], hull_bounds[3]) <= max(slot_bounds[1], slot_bounds[3]) \
		&& min(hull_bounds[2], hull_bounds[4]) >= min(slot_bounds[2], slot_bounds[4]) && max(hull_bounds[2], hull_bounds[4]) <= max(slot_bounds[2], slot_bounds[4])

/** Project occupied hull cells onto clear ground or space belonging to the receiving dock. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/project_hull(obj/docking_port/mobile/stationtrauma_space/ship, turf/anchor, facing)
	var/list/source = ship.return_ordered_turfs(ship.x, ship.y, ship.z, ship.dir)
	var/list/target = ship.return_ordered_turfs(anchor.x, anchor.y, anchor.z, facing)
	if(length(source) != length(target))
		return null
	var/list/projected = list()
	for(var/index in 1 to length(source))
		if(!ship.has_docking_layer(source[index]))
			continue
		var/turf/tile = target[index]
		if((hangar && !isfloorturf(tile)) || !stationtrauma_standard_dock_clear_space(tile, host, ground))
			return null
		projected[tile] = TRUE
	return projected

/** Unrelated world levels do not obstruct the top of a station or carrier stack. */
/proc/stationtrauma_hangar_top_level(turf/anchor, datum/stationtrauma_overmap/space/host)
	if(!anchor || GET_TURF_ABOVE(anchor))
		return FALSE
	if(!host)
		return TRUE
	var/obj/docking_port/mobile/stationtrauma_space/carrier = host.vessel
	return !QDELETED(carrier) && carrier.contains_deck(anchor.z) \
		&& (length(carrier.owned_z_levels) <= 1 || anchor.z == max(carrier.owned_z_levels))

/** Solid ground and ordinary space can support a pad; transit edges cannot. */
/proc/stationtrauma_standard_dock_surface(turf/tile, allow_ground = FALSE)
	if(!tile || tile.density || !(isspaceturf(tile) || isfloorturf(tile) || (allow_ground && isopenturf(tile) && !isgroundlessturf(tile))))
		return FALSE
	if(isspaceturf(tile))
		var/turf/open/space/space_tile = tile
		if(space_tile.destination_z)
			return FALSE
	return TRUE

/** Keep fixtures, loose objects and unrelated ships out of the hull and gangway. */
/proc/stationtrauma_standard_dock_clear_space(turf/tile, datum/stationtrauma_overmap/space/host, allow_ground = FALSE)
	if(!stationtrauma_standard_dock_surface(tile, allow_ground))
		return FALSE
	var/obj/docking_port/mobile/owner = SSshuttle.get_containing_shuttle(tile)
	if((owner && owner != host?.vessel) || (host && isfloorturf(tile) && owner != host.vessel))
		return FALSE
	for(var/atom/movable/occupant as anything in tile)
		if(istype(occupant, /obj/docking_port/mobile))
			return FALSE
		if(istype(occupant, /obj/docking_port))
			continue
		if(occupant.density || isliving(occupant) || (isobj(occupant) && !iseffect(occupant)))
			return FALSE
	return TRUE

/** Describe the first unusable part of the selected dock row. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/wall_problem(obj/machinery/door/airlock/stationtrauma_docking/wall/wall, turf/tile, facing)
	if(!tile)
		return "стыковочная стена выходит за пределы площадки"
	if(!isfloorturf(tile))
		return "повреждён пол под секцией стыковочной стены ([tile.x], [tile.y])"
	if(QDELETED(wall))
		return "нет секции стыковочной стены на ([tile.x], [tile.y])"
	if(wall.dir != facing)
		return "секция стыковочной стены развёрнута неверно ([tile.x], [tile.y])"
	if(wall.gangway)
		return "секция стыковочной стены уже соединена с трапом ([tile.x], [tile.y])"
	if(!wall.density || wall.operating)
		return "секция стыковочной стены должна быть закрыта ([tile.x], [tile.y])"
	var/turf/inside = get_step(wall, REVERSE_DIR(facing))
	if(!isfloorturf(inside) || inside.is_blocked_turf(exclude_mobs = TRUE))
		return "коридор за секцией стыковочной стены перекрыт ([tile.x], [tile.y])"
	return null

/** Describe why a ship hatch cannot be used before arrival. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/hatch_problem(obj/docking_port/mobile/stationtrauma_space/ship, obj/machinery/door/airlock/stationtrauma_docking/ship/hatch)
	if(QDELETED(hatch))
		return "корабельный стыковочный шлюз недоступен"
	var/turf/tile = get_turf(hatch)
	if(!isfloorturf(tile) || !ship.is_in_shuttle_bounds(hatch) || !ship.has_docking_layer(tile))
		return "стыковочный шлюз должен стоять на полу в составе корпуса"
	if(hatch.gangway)
		return "корабельный стыковочный шлюз уже соединён с трапом"
	if(!hatch.density || hatch.operating)
		return "корабельный стыковочный шлюз должен быть закрыт"
	if(!(hatch.dir in GLOB.cardinals))
		return "корабельный стыковочный шлюз направлен неверно"
	var/turf/inside = get_step(hatch, REVERSE_DIR(hatch.dir))
	var/turf/outside = get_step(hatch, hatch.dir)
	if(!isfloorturf(inside) || !ship.shuttle_areas[get_area(inside)])
		return "стыковочный шлюз должен смотреть наружу, а за ним нужен пол корабля"
	if(inside.is_blocked_turf(exclude_mobs = TRUE))
		return "проход из корабля к стыковочному шлюзу перекрыт"
	if(ship.shuttle_areas[get_area(outside)])
		return "стыковочный шлюз должен выходить за пределы корпуса"
	if(!stationtrauma_standard_dock_clear_space(outside, ship.overmap?.carrier_host()))
		return "снаружи корабельного стыковочного шлюза есть препятствие"
	return null

/** Walk from the wall to the projected hatch, excluding both endpoint turfs. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/proc/gangway_path(obj/machinery/door/airlock/stationtrauma_docking/wall/wall, turf/projected_hatch, list/hull)
	var/list/path = list()
	var/turf/step = get_step(wall, wall.dir)
	while(step && step != projected_hatch && length(path) < width)
		if(hull[step] || !stationtrauma_standard_dock_clear_space(step, host))
			return null
		path += step
		step = get_step(step, wall.dir)
	return step == projected_hatch ? path : null

/** One reserved pair of endpoints and the clear cells between them. */
/datum/stationtrauma_dock_route
	/// The physical hatch that travels with the ship.
	var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch
	/// The selected addressable section.
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall
	/// Clear ground or space from the wall to the hatch.
	var/list/path

/** The native anchor and selected routes for one reserved standard slot approach. */
/obj/docking_port/stationary/stationtrauma_space_site/standard
	name = "Технический причал"
	shuttle_id = "overmap_standard_berth"
	area_type = /area/space
	hidden = TRUE
	/// Stable slot owning this technical port.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot
	/// The only ship permitted to use this temporary port.
	var/obj/docking_port/mobile/stationtrauma_space/ship
	/// Helm order captured before any part of the approach can yield.
	var/order_revision
	/// Failure from the latest native docking validation, read before this reservation is cleared.
	var/preflight_problem
	/// Routes chosen for this orientation and anchor.
	var/list/datum/stationtrauma_dock_route/routes = list()
	/// Physical corridors owned by this berth after arrival.
	var/list/datum/stationtrauma_dock_gangway/gangways = list()

/obj/docking_port/stationary/stationtrauma_space_site/standard/Destroy(force)
	if(force)
		QDEL_LIST(gangways)
		QDEL_LIST(routes)
		if(slot?.active_berth == src)
			slot.active_berth = null
		slot = null
		ship = null
	return ..()

/** Return the first failing condition of the reserved route before native movement commits. */
/obj/docking_port/stationary/stationtrauma_space_site/standard/proc/route_problem(obj/docking_port/mobile/stationtrauma_space/arriving)
	if(arriving != ship || QDELETED(slot) || slot.active_berth != src || !slot.accepts(arriving) || (!slot.hangar && !slot.open_space && !length(routes)))
		return "причал или разрешённый маршрут стали недоступны"
	if(width != arriving.width || height != arriving.height || dwidth != arriving.dwidth || dheight != arriving.dheight \
		|| z != slot.z || !slot.contains_projection(slot.return_coords(), return_coords()))
		return "габариты корпуса или положение причала изменились"
	var/datum/stationtrauma_overmap/space/navigation = arriving.overmap
	var/datum/stationtrauma_overmap_site/space/site = navigation?.selected_docking_site()
	if(QDELETED(site) || site.berth != slot || site.docking_owner != navigation || navigation.control_revision != order_revision || !arriving.permits_docking(site))
		return "условия захода на причал изменились"
	var/list/hull = slot.project_hull(arriving, get_turf(src), dir)
	if(!length(hull))
		return "площадка причала перекрыта на пути корпуса"
	if(slot.hangar || slot.open_space)
		return null
	var/wall_direction = turn(slot.dir, 90)
	var/ship_rotation = dir2angle(arriving.dir) - dir2angle(dir)
	for(var/datum/stationtrauma_dock_route/route as anything in routes)
		var/problem = slot.hatch_problem(arriving, route.hatch)
		if(problem)
			return problem
		if(!arriving.shuttle_areas[get_area(route.hatch)] || turn(route.hatch.dir, ship_rotation) != REVERSE_DIR(wall_direction))
			return "корабельный шлюз изменил положение или направление"
		var/turf/wall_tile = get_step(route.path[1], REVERSE_DIR(wall_direction))
		problem = slot.wall_problem(route.wall, wall_tile, wall_direction)
		if(problem)
			return problem
		var/list/offset = arriving.rotated_offset(get_turf(route.hatch), dir)
		var/turf/projected_hatch = locate(x + offset[1], y + offset[2], z)
		if(get_turf(route.wall) != wall_tile || get_step(route.path[length(route.path)], wall_direction) != projected_hatch)
			return "корабельный шлюз или секция стены изменили положение"
		var/list/current_path = slot.gangway_path(route.wall, projected_hatch, hull)
		if(!length(current_path) || length(current_path) != length(route.path))
			return "полоса трапа перекрыта перед секцией ([wall_tile.x], [wall_tile.y])"
		for(var/index in 1 to length(current_path))
			if(route.path[index] != current_path[index])
				return "полоса трапа изменилась во время захода"
	return null

/** Install the still-valid corridors. Record the first failure if any route could not deploy. */
/obj/docking_port/stationary/stationtrauma_space_site/standard/proc/deploy_gangways(list/diagnostic)
	if(length(gangways) || QDELETED(slot) || slot.active_berth != src || QDELETED(ship) || get_docked() != ship)
		diagnostic["reason"] = "швартовочное место недоступно"
		return FALSE
	for(var/datum/stationtrauma_dock_route/route as anything in routes)
		var/datum/stationtrauma_dock_gangway/gangway = new
		var/problem = gangway.deploy(route.hatch, route.wall, route.path, route.wall?.dir)
		if(problem)
			diagnostic["reason"] ||= problem
			qdel(gangway)
			continue
		gangways += gangway
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		INVOKE_ASYNC(gangway, TYPE_PROC_REF(/datum/stationtrauma_dock_gangway, open_passage))
	return length(gangways)
