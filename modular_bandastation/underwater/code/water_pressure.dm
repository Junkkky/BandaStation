/// Cached reservoir connectivity and the polling schedule for native air pressure.
/datum/floodwater_pressure
	var/list/wet_air = list()
	var/list/cells = list()
	var/list/pending = list()
	var/dirty = FALSE
	var/air_time = 0

/datum/floodwater_pressure/proc/prepare_step(datum/floodwater_step/step, seconds)
	if(dirty)
		step.pressure_reset = cells.Copy()
		step.pressure_run = cells.Copy()
		pending.Cut()
		dirty = FALSE
	else if(length(pending))
		step.pressure_run = pending.Copy()
		pending.Cut()
	air_time += seconds
	if(air_time + FLOOD_WATER_FLOW_EPSILON >= 0.5)
		air_time = 0
		step.air_run = wet_air.Copy()

/// Read native atmos without changing its volume, gas contents or LINDA adjacency.
/turf/open/proc/stationtrauma_air_pressure(datum/component/floodwater/water)
	return water ? water.last_air_pressure : (air?.return_pressure() || 0)

/turf/open/proc/stationtrauma_water_pressure(datum/component/floodwater/water)
	if(water?.infinite_source)
		return water.reservoir_pressure
	return max(stationtrauma_air_pressure(water), (water?.ocean_pressure || 0) - FLOOD_WATER_MAX_DEPTH * FLOOD_WATER_KPA_PER_CM) + (water?.depth || 0) * FLOOD_WATER_KPA_PER_CM

/// The simplified model vents displaced air; only the water column can stop a reservoir inflow.
/proc/limit_stationtrauma_boundary_flow(turf/open/tile, datum/component/floodwater/water, pressure, signed_volume)
	var/depth = water?.depth || 0
	var/balance = clamp((pressure - tile.stationtrauma_air_pressure(water)) / FLOOD_WATER_KPA_PER_CM, 0, FLOOD_WATER_MAX_DEPTH)
	var/available = signed_volume > 0 ? max(0, balance - depth) : max(0, depth - balance)
	return min(abs(signed_volume), available * FLOOD_WATER_LITRES_PER_CM)

/datum/component/floodwater
	/// The water plumbing's configured ocean pressure is in bar; hydraulic calculations use kPa.
	var/reservoir_pressure = STATIONTRAUMA_WATER_OCEAN_PRESSURE * 100
	var/last_air_pressure = 0
	var/ocean_pressure = 0
	var/pressure_boundary = FALSE

/datum/component/floodwater/proc/on_atmos_update()
	SIGNAL_HANDLER
	flow_geometry_known = NONE
	var/turf/tile = parent
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(tile, direction)
		var/datum/component/floodwater/water = neighbor?.GetComponent(/datum/component/floodwater)
		if(water)
			water.flow_geometry_known &= ~REVERSE_DIR(direction)
	if((infinite_source && pressure_boundary) || SSfloodwater.pressure.cells[src])
		SSfloodwater.pressure.dirty = TRUE
	wake()

/// Native gas pressure is sampled twice a second, including water that has gone to sleep.
/datum/component/floodwater/proc/process_air()
	var/turf/open/tile = parent
	var/pressure = tile.air?.return_pressure() || 0
	if(abs(pressure - last_air_pressure) > FLOOD_WATER_PRESSURE_EPSILON)
		last_air_pressure = pressure
		wake()
		wake_neighbours()

/datum/component/floodwater/proc/update_pressure_connection()
	if(infinite_source)
		return
	// Only filled paths transmit reservoir head; a free surface uses native air pressure and gravity.
	if(depth >= FLOOD_WATER_SUBMERGED && !SSfloodwater.pressure.cells[src])
		SSfloodwater.pressure.cells[src] = TRUE
		SSfloodwater.pressure.pending[src] = TRUE
	else if(depth < FLOOD_WATER_SUBMERGED && SSfloodwater.pressure.cells[src])
		SSfloodwater.pressure.cells -= src
		SSfloodwater.pressure.dirty |= !!ocean_pressure
		ocean_pressure = 0

/// Propagate a cached reservoir head through filled water, without creating any reservoir volume.
/datum/component/floodwater/proc/update_ocean_pressure(list/queue)
	var/list/cells = SSfloodwater.pressure.cells
	if(!cells[src])
		return
	var/turf/open/tile = parent
	var/pressure = ocean_pressure
	var/list/neighbors = list()
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(tile, direction)
		if(!isopenturf(neighbor))
			continue
		var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
		if(!water || (!water.infinite_source && !cells[water]))
			continue
		if(flow_geometry_known & direction)
			if(!(flow_geometry_open & direction))
				continue
		else if(!tile.can_pass_stationtrauma_water(neighbor))
			continue
		pressure = max(pressure, water.infinite_source ? water.reservoir_pressure : water.ocean_pressure)
		if(!water.infinite_source)
			neighbors += water
	if(pressure <= ocean_pressure)
		return
	ocean_pressure = pressure
	wake()
	wake_neighbours()
	for(var/datum/component/floodwater/water as anything in neighbors)
		if(water.ocean_pressure < pressure)
			queue[water] = TRUE
