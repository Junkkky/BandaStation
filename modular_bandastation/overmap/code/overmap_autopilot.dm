/**
 * Adapted from voidcrew/Voidcrew 0c87384b55294dc7348f83bbd3fddd9427d136de,
 * voidcrew/modules/overmap/code/modules/overmap/ship_autopilot.dm (AGPL-3.0).
 * Keep bounded eight-way A*, bucket frontier, retained paths and final clearance checks;
 * use metre coordinates and hull clearance instead of the wrapping space grid and legal zones.
 */
#define ST_NAV_GRID 160
#define ST_NAV_PATH_MARGIN 25
#define ST_NAV_MAX_EXPANSIONS 2000

/** The same terrain geometry gates both planning and actual movement. */
/datum/stationtrauma_overmap/proc/path_clear(ax, ay, bx, by)
	for(var/datum/stationtrauma_overmap_terrain/terrain in contacts)
		if(!terrain.blocking)
			continue
		if(!isnull(stationtrauma_terrain_hit(ax, ay, bx - ax, by - ay, terrain.pos_x, terrain.pos_y, terrain.end_x, terrain.end_y, radius + ST_NAV_PATH_MARGIN)))
			return FALSE
	return TRUE

/** A retained path is computed once per request, not by UI refreshes or every steering tick. */
/datum/stationtrauma_overmap/proc/plan_course(dest_x, dest_y)
	var/start_x = round(pos_x / ST_NAV_GRID)
	var/start_y = round(pos_y / ST_NAV_GRID)
	var/goal_x = round(dest_x / ST_NAV_GRID)
	var/goal_y = round(dest_y / ST_NAV_GRID)
	var/start_key = "[start_x],[start_y]"
	var/dest_key = "[goal_x],[goal_y]"
	var/list/came_from = list()
	var/list/cost_so_far = list()
	var/list/buckets = list()
	var/frontier = max(abs(goal_x - start_x), abs(goal_y - start_y))
	buckets["[frontier]"] = list(start_key)
	cost_so_far[start_key] = 0
	var/queued = 1
	var/expansions = 0
	var/found = FALSE
	var/min_x = min(start_x, goal_x) - 6
	var/max_x = max(start_x, goal_x) + 6
	var/min_y = min(start_y, goal_y) - 6
	var/max_y = max(start_y, goal_y) + 6
	while(queued > 0 && expansions < ST_NAV_MAX_EXPANSIONS)
		var/list/bucket = buckets["[frontier]"]
		if(!length(bucket))
			frontier++
			if(frontier > ST_NAV_MAX_EXPANSIONS)
				break
			continue
		var/current = bucket[length(bucket)]
		bucket.len--
		queued--
		if(current == dest_key)
			found = TRUE
			break
		var/list/parts = splittext(current, ",")
		var/current_x = text2num(parts[1])
		var/current_y = text2num(parts[2])
		var/current_cost = cost_so_far[current]
		if(current_cost + max(abs(goal_x - current_x), abs(goal_y - current_y)) < frontier)
			continue
		expansions++
		if(expansions % 16 == 0)
			CHECK_TICK
		var/bearing_x = sign(goal_x - current_x)
		var/bearing_y = sign(goal_y - current_y)
		var/list/steps_x = bearing_x ? list(-bearing_x, 0, bearing_x) : list(-1, 1, 0)
		var/list/steps_y = bearing_y ? list(-bearing_y, 0, bearing_y) : list(-1, 1, 0)
		for(var/step_x in steps_x)
			for(var/step_y in steps_y)
				if(!step_x && !step_y)
					continue
				var/nx = current_x + step_x
				var/ny = current_y + step_y
				if(nx < min_x || nx > max_x || ny < min_y || ny > max_y)
					continue
				var/next_key = "[nx],[ny]"
				var/new_cost = current_cost + 1
				if(!isnull(cost_so_far[next_key]) && cost_so_far[next_key] <= new_cost)
					continue
				if(!path_clear(current_x * ST_NAV_GRID, current_y * ST_NAV_GRID, nx * ST_NAV_GRID, ny * ST_NAV_GRID))
					continue
				cost_so_far[next_key] = new_cost
				came_from[next_key] = current
				var/priority = new_cost + max(abs(goal_x - nx), abs(goal_y - ny))
				var/list/target_bucket = buckets["[priority]"]
				if(!target_bucket)
					target_bucket = list()
					buckets["[priority]"] = target_bucket
				target_bucket += next_key
				queued++
	if(!found)
		return null
	var/list/reversed = list()
	var/cursor = dest_key
	var/remaining = ST_NAV_MAX_EXPANSIONS
	while(cursor != start_key && remaining-- > 0)
		var/list/parts = splittext(cursor, ",")
		reversed += list(list(text2num(parts[1]) * ST_NAV_GRID, text2num(parts[2]) * ST_NAV_GRID))
		cursor = came_from[cursor]
		if(!cursor)
			return null
	if(cursor != start_key)
		return null
	var/list/path = list()
	for(var/index in length(reversed) to 1 step -1)
		path += list(reversed[index])
	path += list(list(dest_x, dest_y))
	// Keep only visible corners; straight legs need no stop at every grid centre.
	var/list/simplified = list()
	var/anchor_x = pos_x
	var/anchor_y = pos_y
	var/list/previous = list(pos_x, pos_y)
	for(var/list/node as anything in path)
		if(!path_clear(anchor_x, anchor_y, node[1], node[2]))
			if(!path_clear(previous[1], previous[2], node[1], node[2]))
				return null
			simplified += list(previous)
			anchor_x = previous[1]
			anchor_y = previous[2]
		previous = node
	simplified += list(previous)
	return simplified

/** A yielded plan cannot revive a manually stopped or retargeted vessel. */
/datum/stationtrauma_overmap/proc/engage_autopilot()
	var/datum/stationtrauma_overmap_site/site = sites[selected_destination]
	if(!site || !knows_site(site) || site.failed || planning || arrival_pending || throttle <= 0 || !propulsion_available())
		return FALSE
	planning = TRUE
	var/revision = control_revision
	var/list/path = plan_course(site.pos_x, site.pos_y)
	planning = FALSE
	if(QDELETED(src) || !is_operational() || revision != control_revision || site != sites[selected_destination])
		return FALSE
	if(!length(path) || !path_clear(pos_x, pos_y, path[1][1], path[1][2]))
		stop("Автопилот: безопасный маршрут не найден")
		return FALSE
	autopilot_path = path
	autopilot = TRUE
	braking = speed > 0.05
	return sail()

/** Manual steering always takes control back from the autopilot. */
/datum/stationtrauma_overmap/proc/command_course(heading)
	control_revision++
	autopilot = FALSE
	autopilot_path = null
	ordered_course = WRAP(heading, 0, 360)

/** Follow saved waypoints with ordinary helm and propulsion; a newly blocked leg stops the vessel. */
/datum/stationtrauma_overmap/proc/steer_autopilot()
	if(!length(autopilot_path))
		return
	if(braking && speed > 0.05)
		return
	braking = FALSE
	var/list/node = autopilot_path[1]
	if((node[1] - pos_x) ** 2 + (node[2] - pos_y) ** 2 <= 20 ** 2 && length(autopilot_path) > 1 && speed <= 0.05)
		autopilot_path.Cut(1, 2)
		node = autopilot_path[1]
	if(!path_clear(pos_x, pos_y, node[1], node[2]))
		request_brake()
		status = "Автопилот: путь перекрыт, торможение"
		return
	ordered_course = delta_to_angle(node[1] - pos_x, node[2] - pos_y)
	if(abs(WRAP(ordered_course - course + 180, 0, 360) - 180) > 5 && speed > 0.05)
		braking = TRUE
