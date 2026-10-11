SUBSYSTEM_DEF(floodwater)
	name = "Floodwater"
	wait = 0.1 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	ss_flags = SS_NO_INIT | SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/active = list()
	var/list/currentrun = list()
	var/list/depths = list()
	var/list/sources = list()
	var/list/edge_speeds = list()
	var/list/next_speeds = list()
	var/list/processed_edges = list()
	var/snapshot_ready = FALSE
	var/list/pumps = list()
	var/list/suction_heads = list()
	var/last_update
	var/pending_time = 0
	var/step_seconds = 0.02
	var/steps_completed = 0
	var/step_running = FALSE
	var/list/debug_viewers = list()
	var/next_debug_update = 0

/datum/controller/subsystem/floodwater/fire(resumed = FALSE)
	if(world.time >= next_debug_update)
		update_debug_viewers()
		next_debug_update = world.time + 0.5 SECONDS
	if(!resumed)
		// Accumulate real elapsed time; MC pauses must not slow the hydraulic clock.
		pending_time += isnull(last_update) ? wait / (1 SECONDS) : max(0, (world.time - last_update) / (1 SECONDS))
		last_update = world.time
	while(pending_time + FLOOD_WATER_FLOW_EPSILON >= step_seconds)
		if(!simulate_step(step_running))
			return
		pending_time = max(0, pending_time - step_seconds)
		steps_completed++
		resumed = FALSE
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/floodwater/proc/simulate_step(resumed = FALSE)
	step_running = TRUE
	if(!resumed)
		currentrun = active.Copy()
		active = list()
		sources = currentrun.Copy()
		depths = list()
		next_speeds = list()
		processed_edges = list()
		snapshot_ready = FALSE
		suction_heads = list()
		for(var/obj/machinery/bilge_pump/pump as anything in pumps)
			if(!pump.on || !pump.is_operational || pump.drain_rate <= 0 || pump.reagents.holder_full() || !isopenturf(pump.loc))
				continue
			var/datum/component/floodwater/intake_water = pump.loc.GetComponent(/datum/component/floodwater)
			if(intake_water?.infinite_source)
				continue
			if(istype(pump, /obj/machinery/bilge_pump/portable))
				var/obj/machinery/bilge_pump/portable/portable = pump
				if(portable.port || portable.panel_open || !portable.cell?.charge)
					continue
			else if(!pump.anchored)
				continue
			var/list/frontier = list(pump.loc)
			var/list/distances = list()
			distances[pump.loc] = 0
			var/index = 1
			while(index <= length(frontier))
				var/turf/open/tile = frontier[index++]
				var/distance = distances[tile]
				suction_heads[tile] = max(suction_heads[tile] || 0, (8 - distance) * min(1, pump.drain_rate / 180))
				if(distance == 7)
					continue
				for(var/direction in GLOB.cardinals)
					var/turf/open/neighbor = get_step(tile, direction)
					if(!isopenturf(neighbor) || !isnull(distances[neighbor]) || !tile.can_pass_stationtrauma_water(neighbor))
						continue
					var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
					if(water?.infinite_source || istype(neighbor, /turf/open/water) || (isspaceturf(neighbor) && !water))
						continue
					distances[neighbor] = distance + 1
					frontier += neighbor
	while(length(sources))
		var/datum/component/floodwater/source = sources[length(sources)]
		sources.len--
		if(!QDELETED(source) && source.infinite_source)
			source.spread()
		if(MC_TICK_CHECK)
			return
	if(!snapshot_ready)
		currentrun |= active
		for(var/datum/component/floodwater/water as anything in currentrun)
			if(QDELETED(water))
				continue
			var/turf/open/tile = water.parent
			depths[tile] = water.depth
			for(var/direction in GLOB.cardinals)
				var/turf/open/neighbor = get_step(tile, direction)
				if(isopenturf(neighbor))
					depths[neighbor] = neighbor.get_water_depth()
		snapshot_ready = TRUE
	var/list/changes = list()
	var/list/flows = list()
	while(length(currentrun))
		var/datum/component/floodwater/water = currentrun[length(currentrun)]
		currentrun.len--
		if(!QDELETED(water) && !water.infinite_source)
			water.spread(depths, edge_speeds, next_speeds, processed_edges, suction_heads, changes, flows)
	apply_water_flows(flows, changes, depths)
	edge_speeds = next_speeds
	for(var/obj/machinery/bilge_pump/pump as anything in pumps)
		pump.collect_water(step_seconds)
	step_running = FALSE
	return TRUE

/datum/controller/subsystem/floodwater/proc/apply_water_flows(list/flows, list/changes, list/depths)
	for(var/list/flow as anything in flows)
		var/turf/open/upstream = flow[1]
		var/turf/open/downstream = flow[2]
		var/list/outgoing = changes[upstream]
		var/list/incoming = changes[downstream]
		// Share each cell's budget among its actual currents, including a one-cell breach throat.
		var/amount = flow[3] * min(1, 0.9 * depths[upstream] / outgoing[3], 0.9 * (FLOOD_WATER_MAX_DEPTH - depths[downstream]) / incoming[4])
		outgoing[1] -= amount
		outgoing[2] -= amount * flow[4]
		incoming[1] += amount
		incoming[2] += amount * flow[4]
	// Commit one conservative update per cell before yielding to doors, plumbing or another subsystem.
	for(var/turf/open/tile as anything in changes)
		var/list/change = changes[tile]
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		var/new_depth = tile.get_water_depth() + change[1]
		var/heat = tile.get_water_depth() * (water?.temperature || 0) + change[2]
		var/new_temperature = new_depth > 0 ? heat / new_depth : FLOOD_WATER_TEMPERATURE
		if(water && new_depth == water.depth && new_temperature == water.temperature)
			continue
		tile.set_water_depth(new_depth, FALSE, new_temperature)

/datum/controller/subsystem/floodwater/stat_entry(msg)
	return ..("Active:[length(active)] Steps:[steps_completed] Behind:[round(pending_time, 0.1)]s")

/datum/component/floodwater/proc/wake(datum/source)
	SIGNAL_HANDLER
	if(infinite_source)
		var/turf/open/tile = parent
		var/feeds_floor = FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/open/neighbor = get_step(tile, direction)
			if(!isopenturf(neighbor) || isspaceturf(neighbor) || istype(neighbor, /turf/open/water) || neighbor.get_water_depth() >= depth)
				continue
			if(tile.can_pass_stationtrauma_water(neighbor))
				feeds_floor = TRUE
				break
		if(!feeds_floor)
			return
	SSfloodwater.active[src] = TRUE

/datum/component/floodwater/proc/wake_neighbours()
	var/turf/tile = parent
	for(var/direction in GLOB.cardinals)
		var/turf/next_tile = get_step(tile, direction)
		var/datum/component/floodwater/next_water = next_tile?.GetComponent(/datum/component/floodwater)
		next_water?.wake()

/// Check objects directly: the asynchronous atmos cache can still describe an airlock that has just closed.
/turf/open/proc/can_pass_stationtrauma_water(turf/open/other)
	if(!isopenturf(other) || other.z != z || blocks_air || other.blocks_air || get_dist(src, other) != 1 || !(get_dir(src, other) in GLOB.cardinals))
		return FALSE
	for(var/obj/obstacle in contents + other.contents)
		var/turf/target = obstacle.loc == src ? other : src
		if(!CANATMOSPASS(obstacle, target, FALSE))
			return FALSE
	return TRUE

/turf/open/proc/stationtrauma_water_room()
	var/list/room = list(src)
	var/list/visited = list()
	visited[src] = TRUE
	var/index = 1
	while(index <= length(room))
		var/turf/open/tile = room[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/open/neighbor = get_step(tile, direction)
			if(!isopenturf(neighbor) || visited[neighbor] || istype(neighbor, /turf/open/water) || !tile.can_pass_stationtrauma_water(neighbor))
				continue
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water?.infinite_source || (isspaceturf(neighbor) && !water))
				continue
			visited[neighbor] = TRUE
			room += neighbor
	return room

/datum/component/floodwater/proc/spread(list/depths, list/speeds, list/next_speeds, list/processed, list/suction, list/changes, list/flows)
	var/standalone = !flows
	flows ||= list()
	changes ||= list()
	depths ||= list()
	var/turf/open/tile = parent
	var/source_depth = isnull(depths?[tile]) ? depth : depths[tile]
	depths[tile] = source_depth
	var/dt = SSfloodwater.step_seconds
	if(!speeds)
		speeds = SSfloodwater.edge_speeds
	if(!next_speeds)
		next_speeds = speeds
	for(var/direction in GLOB.cardinals)
		var/turf/open/next_tile = get_step(tile, direction)
		if(!isopenturf(next_tile) || istype(next_tile, /turf/open/water))
			continue
		var/datum/component/floodwater/next_water = next_tile.GetComponent(/datum/component/floodwater)
		if(next_water?.infinite_source || !tile.can_pass_stationtrauma_water(next_tile))
			continue
		var/next_depth = isnull(depths?[next_tile]) ? (next_water?.depth || 0) : depths[next_tile]
		depths[next_tile] = next_depth
		var/difference = source_depth - next_depth
		if(infinite_source)
			if(difference > FLOOD_WATER_FLOW_EPSILON && next_tile.add_water(min(FLOOD_WATER_OCEAN_FLOW * dt, difference) * FLOOD_WATER_LITRES_PER_CM, temperature))
				wake()
			continue
		difference += (suction?[next_tile] || 0) - (suction?[tile] || 0)
		// Store one signed velocity per edge; the snapshot limits a wave to one new tile per step.
		var/forward = direction == NORTH || direction == EAST
		var/turf/open/edge_origin = forward ? tile : next_tile
		var/edge_direction = forward ? direction : REVERSE_DIR(direction)
		var/key = "[edge_origin.x],[edge_origin.y],[edge_origin.z]:[edge_direction]"
		if(processed?[key])
			continue
		if(processed)
			processed[key] = TRUE
		var/velocity = (speeds[key] || 0) * (forward ? 1 : -1)
		velocity = (velocity + difference * dt) / (1 + 3 * dt)
		// Single-precision ripples below a micrometre must settle instead of keeping an entire deck awake.
		if((abs(velocity) < 0.0001 && abs(difference) < 0.0001) || (source_depth == FLOOD_WATER_MAX_DEPTH && next_depth == FLOOD_WATER_MAX_DEPTH))
			next_speeds[key] = 0
			continue
		next_speeds[key] = velocity * (forward ? 1 : -1)
		var/turf/open/upstream_tile = velocity > 0 ? tile : next_tile
		var/turf/open/downstream_tile = velocity > 0 ? next_tile : tile
		var/datum/component/floodwater/from_water = upstream_tile.GetComponent(/datum/component/floodwater)
		var/upstream_depth = velocity > 0 ? source_depth : next_depth
		if(upstream_depth <= 0 || !from_water)
			continue
		var/flow = abs(velocity) * max(upstream_depth, 20) * dt
		changes[upstream_tile] ||= list(0, 0, 0, 0)
		changes[downstream_tile] ||= list(0, 0, 0, 0)
		var/list/outgoing = changes[upstream_tile]
		var/list/incoming = changes[downstream_tile]
		outgoing[3] += flow
		incoming[4] += flow
		flows += list(list(upstream_tile, downstream_tile, flow, from_water.temperature))
	if(standalone)
		SSfloodwater.apply_water_flows(flows, changes, depths)

/turf/open/proc/stationtrauma_water_intake()
	var/list/intake = list(src)
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(src, direction)
		if(isopenturf(neighbor) && can_pass_stationtrauma_water(neighbor))
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water && !water.infinite_source)
				intake += neighbor
	return intake

/// Collect the local intake proportionally without losing fractional water to holder rounding.
/proc/drain_stationtrauma_water_room(turf/open/intake, volume, datum/reagents/receiver, residual_depth = 0, list/room)
	if(!isopenturf(intake) || QDELETED(receiver) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0)
		return 0
	var/datum/component/floodwater/source_water = intake.GetComponent(/datum/component/floodwater)
	if(source_water?.infinite_source)
		return 0
	room ||= intake.stationtrauma_water_intake()
	var/available = 0
	var/thermal_total = 0
	for(var/turf/open/tile as anything in room)
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		var/litres = max(0, (water?.depth || 0) - residual_depth) * FLOOD_WATER_LITRES_PER_CM
		available += litres
		thermal_total += litres * (water?.temperature || 0)
	if(available <= 0 || volume <= 0)
		return 0
	var/free_space = receiver.maximum_volume
	for(var/datum/reagent/reagent as anything in receiver.reagent_list)
		free_space -= reagent.volume
	var/amount = min(available, volume, max(0, free_space))
	if(amount <= 0)
		return 0
	var/mixed_temperature = thermal_total / available
	var/accepted = store_stationtrauma_water(receiver, amount, mixed_temperature)
	if(accepted <= 0)
		return 0
	var/fraction = min(1, accepted / available)
	for(var/turf/open/tile as anything in room)
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		if(!water || water.depth <= residual_depth)
			continue
		if(fraction == 1 && residual_depth == 0)
			if(water.show_puddle && !isspaceturf(tile))
				tile.MakeSlippery(TURF_WET_WATER, 1 MINUTES, 0, 1 MINUTES)
		water.set_depth(max(residual_depth, water.depth - (water.depth - residual_depth) * fraction))
	return accepted

ADMIN_VERB(stationtrauma_water_debug, R_DEBUG, "Water Depth Debug", "Toggle live water depths in centimetres on nearby turfs.", ADMIN_CATEGORY_DEBUG)
	if(SSfloodwater.debug_viewers[user])
		user.images -= SSfloodwater.debug_viewers[user]
		SSfloodwater.debug_viewers -= user
		to_chat(user, span_notice("Отображение глубины воды выключено."))
	else
		SSfloodwater.debug_viewers[user] = list()
		SSfloodwater.update_debug_viewers()
		to_chat(user, span_notice("Отображение глубины воды включено: см; ∞ — океан. Обновление дважды в секунду."))
	BLACKBOX_LOG_ADMIN_VERB("Water Depth Debug")

/datum/controller/subsystem/floodwater/proc/update_debug_viewers()
	for(var/client/viewer as anything in debug_viewers)
		if(QDELETED(viewer) || !viewer.mob)
			debug_viewers -= viewer
			continue
		viewer.images -= debug_viewers[viewer]
		var/list/images = list()
		for(var/turf/open/tile in range(12, viewer.mob))
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			var/image/label = image(loc = tile)
			SET_PLANE_EXPLICIT(label, BALLOON_CHAT_PLANE, tile)
			label.maptext = MAPTEXT("<span style='color:[water?.infinite_source ? "#37c7b7" : water?.depth ? "#ffffff" : "#aaaaaa"];text-align:center'>[water?.infinite_source ? "∞" : round(water?.depth || 0, 0.1)]</span>")
			label.maptext_y = 8
			images += label
		debug_viewers[viewer] = images
		viewer.images += images
