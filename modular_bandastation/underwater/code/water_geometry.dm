/// Check objects directly: the asynchronous atmos cache can still describe an airlock that has just closed.
/turf/open/proc/can_pass_stationtrauma_water(turf/open/other, obj/ignored_obstacle = null)
	if(!isopenturf(other) || other.z != z || blocks_air || other.blocks_air || get_dist(src, other) != 1 || !(get_dir(src, other) in GLOB.cardinals))
		return FALSE
	for(var/obj/obstacle in contents)
		if(obstacle != ignored_obstacle && !CANATMOSPASS(obstacle, other, FALSE))
			return FALSE
	for(var/obj/obstacle in other.contents)
		if(obstacle != ignored_obstacle && !CANATMOSPASS(obstacle, src, FALSE))
			return FALSE
	return TRUE

/** Full-tile closed doors displace water; directional windoors still leave their floor usable. */
/turf/open/proc/closed_stationtrauma_water_door()
	RETURN_TYPE(/obj/machinery/door)
	for(var/obj/machinery/door/door in contents)
		if(!QDELETED(door) && door.density && door.can_atmos_pass == ATMOS_PASS_DENSITY)
			return door
	return null

/** A secured full-tile window occupies its floor; directional panes leave a wet side usable. */
/turf/open/proc/sealed_stationtrauma_water_window()
	RETURN_TYPE(/obj/structure/window)
	for(var/obj/structure/window/window in contents)
		if(!QDELETED(window) && window.fulltile && window.anchored && window.density)
			return window
	return null

/** Resume the pump's cached connected footprint; water depths are tracked separately. */
/turf/open/proc/stationtrauma_water_room(obj/machinery/bilge_pump/observer)
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	if(debug.enabled && !observer.drain_building)
		debug.bfs++
	var/list/room = observer.drain_queue || list(src)
	var/list/visited = observer.drain_building || list()
	visited[src] = TRUE
	var/index = observer.drain_cursor
	observer.drain_queue = room
	observer.drain_building = visited
	while(index <= length(room))
		var/turf/open/tile = room[index++]
		if(debug.enabled)
			debug.bfs_tiles++
		observer.watch_water_geometry(tile)
		var/datum/component/floodwater/tile_water = tile.GetComponent(/datum/component/floodwater)
		if(tile_water && !tile_water.infinite_source)
			observer.drain_water[tile] = tile_water
		for(var/direction in GLOB.cardinals)
			var/turf/open/neighbor = get_step(tile, direction)
			observer.watch_water_geometry(neighbor)
			if(!isopenturf(neighbor) || !isnull(visited[neighbor]) || istype(neighbor, /turf/open/water) || !tile.can_pass_stationtrauma_water(neighbor))
				continue
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water?.infinite_source || (isspaceturf(neighbor) && !water))
				continue
			visited[neighbor] = TRUE
			room += neighbor
		// A cold full-compartment cache must yield too; warm pumps never enter this traversal.
		if(index <= length(room) && SSfloodwater.step_running && (TICK_USAGE > Master.current_ticklimit || SSfloodwater.state != SS_RUNNING))
			observer.drain_cursor = index
			SSfloodwater.pause()
			return null
	observer.drain_queue = null
	observer.drain_building = null
	observer.drain_cursor = 1
	return visited

/turf/open/proc/stationtrauma_water_intake()
	var/list/intake = list(src)
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(src, direction)
		if(isopenturf(neighbor) && can_pass_stationtrauma_water(neighbor))
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water && !water.infinite_source)
				intake += neighbor
	return intake
