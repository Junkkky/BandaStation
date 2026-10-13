/datum/component/floodwater/proc/wake(datum/source)
	SIGNAL_HANDLER
	if(!infinite_source)
		return
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	if(debug.enabled)
		debug.wake_requests++
	var/turf/open/tile = parent
	var/feeds_floor = FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(tile, direction)
		if(!isopenturf(neighbor) || isspaceturf(neighbor) || istype(neighbor, /turf/open/water))
			continue
		var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
		if(water?.infinite_source)
			continue
		var/difference = reservoir_pressure - neighbor.stationtrauma_air_pressure(water) - neighbor.get_water_depth() * FLOOD_WATER_KPA_PER_CM
		if((difference > FLOOD_WATER_PRESSURE_EPSILON && neighbor.get_water_depth() >= FLOOD_WATER_MAX_DEPTH) || abs(difference) <= FLOOD_WATER_PRESSURE_EPSILON || (difference < 0 && !water))
			continue
		if(tile.can_pass_stationtrauma_water(neighbor))
			feeds_floor = TRUE
			break
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
		var/datum/floodwater_front_cell/contact = SSfloodwater.hybrid?.by_turf[next_tile]
		if(contact)
			SSfloodwater.hybrid.ocean_contacts[contact] = TRUE
		var/difference = reservoir_pressure - next_tile.stationtrauma_air_pressure(next_water) - next_tile.get_water_depth() * FLOOD_WATER_KPA_PER_CM
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
