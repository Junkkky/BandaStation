/// One reusable snapshot and flat transfer buffer per simulation, never one datum per cell.
/datum/floodwater_step
	/// Queues for the current step; momentum buffers persist between steps.
	var/list/currentrun = list()
	var/list/sources = list()
	/// Captured cell values and conservative transfer accounting.
	var/list/indices = list()
	var/list/tiles = list()
	var/list/waters = list()
	var/list/depths = list()
	var/list/pressures = list()
	var/list/outgoing = list()
	var/list/incoming = list()
	var/list/changes = list()
	var/list/heat = list()
	var/list/flows = list()
	var/list/processed = list()
	var/list/speeds = list()
	var/list/next_speeds = list()
	var/list/suction = list()
	/// Resumable planning and application cursors.
	var/phase = FLOOD_WATER_STEP_PREPARE
	var/cursor = 0
	var/flow_cursor = 1
	var/list/changed = list()
	var/list/pumps = list()
	var/list/air_run = list()
	var/list/pressure_reset = list()
	var/list/pressure_run = list()
	var/recheck_geometry = TRUE

/datum/floodwater_step/proc/reset()
	indices.Cut()
	tiles.Cut()
	waters.Cut()
	depths.Cut()
	pressures.Cut()
	outgoing.Cut()
	incoming.Cut()
	changes.Cut()
	heat.Cut()
	flows.Cut()
	processed.Cut()
	changed.Cut()
	pumps.Cut()
	air_run.Cut()
	pressure_reset.Cut()
	pressure_run.Cut()
	recheck_geometry = TRUE
	next_speeds.Cut()
	suction.Cut()
	phase = FLOOD_WATER_STEP_PREPARE
	cursor = 0
	flow_cursor = 1

/datum/floodwater_step/proc/capture(turf/open/tile)
	var/index = indices[tile]
	if(index)
		return index
	index = length(tiles) + 1
	indices[tile] = index
	var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
	tiles += tile
	waters += water
	depths += water?.depth || 0
	// Keep the head separate from depth to avoid cancellation at ocean pressures.
	pressures += max(tile.stationtrauma_air_pressure(water), (water?.ocean_pressure || 0) - FLOOD_WATER_MAX_DEPTH * FLOOD_WATER_KPA_PER_CM)
	outgoing += 0
	incoming += 0
	changes += 0
	heat += 0
	return index

/datum/floodwater_step/proc/capture_neighbours(turf/open/tile)
	if(!indices[tile])
		capture(tile)
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(tile, direction)
		if(isopenturf(neighbor) && !indices[neighbor])
			capture(neighbor)

/// Complete transfers stay paired inside a bounded commit; a paused step never exposes half a transfer.
/datum/floodwater_step/proc/commit_batch()
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	var/end = min(length(flows), flow_cursor + 3 * 32 - 1)
	while(flow_cursor <= end)
		var/from = flows[flow_cursor]
		var/receiver_index = flows[flow_cursor + 1]
		var/amount = flows[flow_cursor + 2]
		amount *= min(1, 0.9 * depths[from] / outgoing[from], 0.9 * (FLOOD_WATER_MAX_DEPTH - depths[receiver_index]) / incoming[receiver_index])
		var/turf/open/source = tiles[from]
		var/turf/open/destination = tiles[receiver_index]
		flow_cursor += 3
		// Doors and plumbing may change while planning is paused.
		if(!isopenturf(source) || !isopenturf(destination) || (recheck_geometry && !source.can_pass_stationtrauma_water(destination)))
			continue
		var/datum/component/floodwater/from_water = waters[from]
		var/datum/component/floodwater/to_water = waters[receiver_index]
		if(!from_water || QDELETED(from_water))
			from_water = source.GetComponent(/datum/component/floodwater)
		if(!to_water || QDELETED(to_water))
			to_water = destination.GetComponent(/datum/component/floodwater)
		if(!from_water || from_water.infinite_source || to_water?.infinite_source)
			continue
		amount = min(amount, max(0, from_water.depth + changes[from]), max(0, FLOOD_WATER_MAX_DEPTH - (to_water?.depth || 0) - changes[receiver_index]))
		if(amount <= 0)
			continue
		var/temperature = from_water.temperature
		if(!changes[from] && !heat[from])
			changed |= from
		if(!changes[receiver_index] && !heat[receiver_index])
			changed |= receiver_index
		changes[from] -= amount
		heat[from] -= amount * temperature
		changes[receiver_index] += amount
		heat[receiver_index] += amount * temperature
		if(debug.enabled)
			debug.transfers++
	for(var/index in changed)
		var/turf/open/tile = tiles[index]
		var/datum/component/floodwater/water = waters[index]
		if(!water || QDELETED(water))
			water = tile.GetComponent(/datum/component/floodwater)
		var/new_depth = (water?.depth || 0) + changes[index]
		var/new_heat = (water?.depth || 0) * (water?.temperature || 0) + heat[index]
		var/new_temperature = new_depth > 0 ? new_heat / new_depth : FLOOD_WATER_TEMPERATURE
		if(water && new_depth == water.depth && new_temperature == water.temperature)
			water.wake()
		else if(water && new_depth > 0)
			water.temperature = new_temperature
			water.set_depth(new_depth, FALSE)
		else
			water = tile.set_water_depth(new_depth, FALSE, new_temperature, FALSE)
		waters[index] = new_depth > 0 ? water : null
		if(changes[index] < 0)
			for(var/direction in GLOB.cardinals)
				var/neighbor_index = indices[get_step(tile, direction)]
				var/datum/component/floodwater/neighbor = neighbor_index ? waters[neighbor_index] : null
				if(!QDELETED(neighbor) && neighbor.infinite_source)
					neighbor.wake()
		changes[index] = 0
		heat[index] = 0
	changed.Cut()

/// Direct component calls in fixtures use the same conservative planner without MC scheduling.
/datum/floodwater_step/proc/commit()
	while(flow_cursor <= length(flows))
		commit_batch()

/datum/controller/subsystem/floodwater/proc/simulate_step(resumed = FALSE)
	step_running = TRUE
	if(resumed)
		step.recheck_geometry = TRUE
	if(!resumed)
		step.currentrun = active
		active = list()
		step.sources.Cut()
		for(var/datum/component/floodwater/water as anything in step.currentrun)
			if(!QDELETED(water) && water.infinite_source)
				step.sources += water
		step.reset()
		step.recheck_geometry = FALSE
		pressure.prepare_step(step, step_seconds)
		for(var/obj/machinery/bilge_pump/pump as anything in pumps)
			if(!length(step.currentrun) || !pump.can_collect_water())
				continue
			var/list/distances = pump.get_water_geometry(7)
			for(var/turf/open/tile as anything in distances)
				var/distance = distances[tile]
				step.suction[tile] = max(step.suction[tile] || 0, (8 - distance) * min(1, pump.drain_rate / 180))
	while(length(step.air_run))
		var/datum/component/floodwater/water = step.air_run[length(step.air_run)]
		step.air_run.len--
		if(!QDELETED(water))
			water.process_air()
		if(MC_TICK_CHECK)
			return
	while(length(step.pressure_reset))
		var/datum/component/floodwater/water = step.pressure_reset[length(step.pressure_reset)]
		step.pressure_reset.len--
		if(!QDELETED(water) && water.ocean_pressure)
			water.ocean_pressure = 0
			water.wake()
			water.wake_neighbours()
		if(MC_TICK_CHECK)
			return
	while(length(step.sources))
		var/datum/component/floodwater/source = step.sources[length(step.sources)]
		step.sources.len--
		if(!QDELETED(source) && source.infinite_source)
			source.feed_ocean()
		if(MC_TICK_CHECK)
			return
	// Inflow can fill the throat this very step; compute its head from the same state we snapshot.
	if(step.phase == FLOOD_WATER_STEP_PREPARE && length(pressure.pending))
		step.pressure_run |= pressure.pending
		pressure.pending.Cut()
	while(length(step.pressure_run))
		var/datum/component/floodwater/water = step.pressure_run[length(step.pressure_run)]
		step.pressure_run.len--
		if(!QDELETED(water))
			water.update_ocean_pressure(step.pressure_run)
		if(MC_TICK_CHECK)
			return
	if(step.phase == FLOOD_WATER_STEP_PREPARE)
		step.currentrun |= active
		step.cursor = length(step.currentrun)
		step.phase = FLOOD_WATER_STEP_CAPTURE
	if(step.phase == FLOOD_WATER_STEP_CAPTURE)
		while(step.cursor)
			var/datum/component/floodwater/water = step.currentrun[step.cursor--]
			if(!QDELETED(water))
				step.capture_neighbours(water.parent)
			if(MC_TICK_CHECK)
				return
		step.cursor = length(step.currentrun)
		step.phase = FLOOD_WATER_STEP_SPREAD
	if(step.phase == FLOOD_WATER_STEP_SPREAD)
		while(step.cursor)
			var/datum/component/floodwater/water = step.currentrun[step.cursor--]
			if(!QDELETED(water) && !water.infinite_source)
				if(debug.enabled)
					debug.tiles++
				water.spread(step)
			if(MC_TICK_CHECK)
				return
		step.phase = FLOOD_WATER_STEP_COMMIT
	if(step.phase == FLOOD_WATER_STEP_COMMIT)
		while(step.flow_cursor <= length(step.flows))
			step.commit_batch()
			if(MC_TICK_CHECK)
				return
		var/list/old_speeds = step.speeds
		step.speeds = step.next_speeds
		step.next_speeds = old_speeds
		step.currentrun.Cut()
		step.pumps = pumps.Copy()
		step.cursor = length(step.pumps)
		step.phase = FLOOD_WATER_STEP_PUMPS
	while(step.cursor)
		var/obj/machinery/bilge_pump/pump = step.pumps[step.cursor--]
		if(!QDELETED(pump))
			pump.collect_water(step_seconds)
			// A paused cold traversal has not collected yet; resume it before advancing physics time.
			if(state == SS_PAUSED && pump.drain_building)
				step.cursor++
		if(MC_TICK_CHECK)
			return
	step_running = FALSE
	return TRUE
