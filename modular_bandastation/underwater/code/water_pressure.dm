/** Read current native air pressure; stable interiors need no polling queue. */
/turf/open/proc/stationtrauma_air_pressure(datum/component/floodwater/water)
	return air?.return_pressure() || 0

/** External reservoirs supply their configured head; free interior water adds its own column. */
/turf/open/proc/stationtrauma_water_pressure(datum/component/floodwater/water)
	if(water?.infinite_source)
		return water.reservoir_pressure
	var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid?.by_turf[src]
	return cell ? cell.head_pressure() : stationtrauma_air_pressure(water) + get_water_depth() * FLOOD_WATER_KPA_PER_CM

/** The simplified model vents displaced air; the water column limits reservoir inflow. */
/proc/limit_stationtrauma_boundary_flow(turf/open/tile, datum/component/floodwater/water, pressure, signed_volume)
	var/depth = tile.get_water_depth()
	var/balance = clamp((pressure - tile.stationtrauma_air_pressure(water)) / FLOOD_WATER_KPA_PER_CM, 0, FLOOD_WATER_MAX_DEPTH)
	var/volume = depth * FLOOD_WATER_LITRES_PER_CM
	var/target = balance * FLOOD_WATER_LITRES_PER_CM
	var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid?.by_turf[tile]
	var/datum/floodwater_front_group/owner = cell?.root()
	if(owner && !owner.dirty && !cell.local)
		// A bulk cell changes the shared stock; its final per-cell deficit can be smaller than that stock's precision.
		volume = owner.volume
		target *= owner.members.len
	var/available = signed_volume > 0 ? max(0, target - volume) : max(0, volume - target)
	return min(abs(signed_volume), available)

/datum/component/floodwater
	/// The configured ocean pressure is in bar; hydraulic calculations use kPa.
	var/reservoir_pressure = STATIONTRAUMA_WATER_OCEAN_PRESSURE * 100

/** Explicit depth/head changes wake contacts; z is a deck coordinate, not ocean depth. */
/datum/component/floodwater/proc/set_reservoir_pressure(pressure)
	if(!infinite_source || !isnum(pressure) || !IS_FINITE(pressure) || pressure < 0 || pressure == reservoir_pressure)
		return FALSE
	reservoir_pressure = pressure
	wake()
	for(var/datum/component/floodwater_leak/leak as anything in SSfloodwater.leaks)
		if(leak.ports[parent])
			leak.wake()
	return TRUE

/** Finite geometry belongs to C; source components only wake their local boundaries. */
/datum/component/floodwater/proc/on_atmos_update()
	SIGNAL_HANDLER
	wake()
	wake_neighbours()
