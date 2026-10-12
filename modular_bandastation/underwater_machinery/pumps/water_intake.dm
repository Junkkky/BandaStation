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
		var/datum/component/floodwater/water = istype(room[tile], /datum/component/floodwater) ? room[tile] : tile.GetComponent(/datum/component/floodwater)
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
		var/datum/component/floodwater/water = istype(room[tile], /datum/component/floodwater) ? room[tile] : tile.GetComponent(/datum/component/floodwater)
		if(!water || water.depth <= residual_depth)
			continue
		if(fraction == 1 && residual_depth == 0)
			if(water.show_puddle && !isspaceturf(tile))
				tile.MakeSlippery(TURF_WET_WATER, 1 MINUTES, 0, 1 MINUTES)
		water.set_depth(max(residual_depth, water.depth - (water.depth - residual_depth) * fraction))
	return accepted
