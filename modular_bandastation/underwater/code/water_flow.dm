/datum/component/floodwater/proc/wake(datum/source)
	SIGNAL_HANDLER
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	if(debug.enabled)
		debug.wake_requests++
	if(infinite_source)
		var/turf/open/tile = parent
		var/feeds_floor = FALSE
		var/has_boundary = FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/open/neighbor = get_step(tile, direction)
			if(!isopenturf(neighbor) || isspaceturf(neighbor) || istype(neighbor, /turf/open/water))
				continue
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water?.infinite_source)
				continue
			has_boundary = TRUE
			var/difference = reservoir_pressure - neighbor.stationtrauma_air_pressure(water) - (water?.depth || 0) * FLOOD_WATER_KPA_PER_CM
			if((difference > FLOOD_WATER_PRESSURE_EPSILON && (water?.depth || 0) >= FLOOD_WATER_MAX_DEPTH) || abs(difference) <= FLOOD_WATER_PRESSURE_EPSILON || (difference < 0 && !water))
				continue
			if(tile.can_pass_stationtrauma_water(neighbor))
				feeds_floor = TRUE
				break
		if(pressure_boundary != has_boundary)
			pressure_boundary = has_boundary
			SSfloodwater.pressure.dirty = TRUE
		if(!feeds_floor)
			return
	if(debug.enabled && !SSfloodwater.active[src])
		debug.wakes++
	SSfloodwater.active[src] = TRUE

/datum/component/floodwater/proc/wake_neighbours()
	var/turf/tile = parent
	for(var/direction in GLOB.cardinals)
		var/turf/next_tile = get_step(tile, direction)
		var/datum/component/floodwater/next_water = next_tile?.GetComponent(/datum/component/floodwater)
		next_water?.wake()

/// A reservoir fills against vented air, while its hydraulic head drives finite-water transfers.
/datum/component/floodwater/proc/feed_ocean()
	var/turf/open/tile = parent
	for(var/direction in GLOB.cardinals)
		var/turf/open/next_tile = get_step(tile, direction)
		if(!isopenturf(next_tile) || isspaceturf(next_tile) || istype(next_tile, /turf/open/water))
			continue
		var/datum/component/floodwater/next_water = next_tile.GetComponent(/datum/component/floodwater)
		var/difference = reservoir_pressure - next_tile.stationtrauma_air_pressure(next_water) - (next_water?.depth || 0) * FLOOD_WATER_KPA_PER_CM
		if(next_water?.infinite_source || abs(difference) <= FLOOD_WATER_PRESSURE_EPSILON || !tile.can_pass_stationtrauma_water(next_tile))
			continue
		// Cd=0.6, effective opening=0.3 m²; Q=Cd*A*sqrt(2*deltaP/rho), converted to litres.
		var/volume = 180 * sqrt(2 * abs(difference)) * SSfloodwater.step_seconds
		volume = limit_stationtrauma_boundary_flow(next_tile, next_water, reservoir_pressure, difference > 0 ? volume : -volume)
		if(!volume)
			continue
		var/transferred = difference > 0 ? next_tile.add_water(volume, temperature) : next_water?.remove_water(volume)
		if(transferred)
			wake()

/datum/component/floodwater/proc/spread(datum/floodwater_step/step)
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	if(infinite_source)
		return feed_ocean()
	var/standalone = !step
	var/turf/open/tile = parent
	if(standalone)
		step = new
		step.speeds = SSfloodwater.step.speeds
		step.next_speeds = SSfloodwater.step.speeds
		step.capture_neighbours(tile)
	var/list/indices = step.indices
	var/list/depths = step.depths
	var/list/waters = step.waters
	var/list/pressures = step.pressures
	var/list/outgoing = step.outgoing
	var/list/incoming = step.incoming
	var/list/suction = step.suction
	var/list/flows = step.flows
	var/source = indices[tile]
	var/source_depth = depths[source]
	var/list/speeds = step.speeds
	var/list/next_speeds = step.next_speeds
	var/list/processed = step.processed
	var/dt = SSfloodwater.step_seconds
	for(var/direction in GLOB.cardinals)
		if(processed[source] & direction)
			continue
		var/turf/open/next_tile = get_step(tile, direction)
		var/next = indices[next_tile]
		if(!next || isspaceturf(next_tile) || istype(next_tile, /turf/open/water))
			continue
		var/datum/component/floodwater/next_water = waters[next]
		var/next_depth = depths[next]
		if(next_water?.infinite_source || (source_depth == FLOOD_WATER_MAX_DEPTH && next_depth == FLOOD_WATER_MAX_DEPTH))
			continue
		var/reverse = REVERSE_DIR(direction)
		processed[source] |= direction
		processed[next] |= reverse
		if(debug.enabled)
			debug.edges++
		if(next_water && (flow_geometry_known & direction) && !(flow_geometry_open & direction))
			continue
		var/forward = direction == NORTH || direction == EAST
		var/turf/open/edge_origin = forward ? tile : next_tile
		var/axis = direction & (NORTH|SOUTH) ? 1 : 2
		var/list/edge_speeds = speeds[axis]
		var/pressure_difference = pressures[source] - pressures[next]
		var/difference = source_depth - next_depth + pressure_difference / FLOOD_WATER_KPA_PER_CM + (suction[next_tile] || 0) - (suction[tile] || 0)
		var/momentum = (edge_speeds[edge_origin] || 0) * (forward ? 1 : -1) + difference * dt
		var/velocity = momentum / (1 + 3 * dt)
		if(abs(velocity) < 0.0001 && abs(difference) < 0.0001)
			continue
		// Dry fronts have no component watching their barriers, so they must still be checked directly.
		if(!next_water || !(flow_geometry_known & direction))
			var/passable = tile.can_pass_stationtrauma_water(next_tile)
			if(next_water)
				flow_geometry_known |= direction
				next_water.flow_geometry_known |= reverse
				if(passable)
					flow_geometry_open |= direction
					next_water.flow_geometry_open |= reverse
				else
					flow_geometry_open &= ~direction
					next_water.flow_geometry_open &= ~reverse
			if(!passable)
				continue
		var/from = velocity > 0 ? source : next
		var/receiver_index = velocity > 0 ? next : source
		var/upstream_depth = depths[from]
		if(upstream_depth <= 0 || !waters[from])
			continue
		// Limit the stored velocity too: otherwise a vanished pressure head leaves an enormous fictitious momentum.
		if(abs(pressure_difference) > FLOOD_WATER_PRESSURE_EPSILON)
			var/limit = 18 * sqrt(2 * abs(difference) * FLOOD_WATER_KPA_PER_CM) / max(upstream_depth, 20)
			velocity = clamp(velocity, -limit, limit)
		var/amount = abs(velocity) * max(upstream_depth, 20) * dt
		if(amount <= 0)
			continue
		var/list/next_edge_speeds = next_speeds[axis]
		next_edge_speeds[edge_origin] = velocity * (forward ? 1 : -1)
		outgoing[from] += amount
		incoming[receiver_index] += amount
		flows.Add(from, receiver_index, amount)
	if(standalone)
		step.commit()
		qdel(step)
