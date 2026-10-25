/** Hydraulic masks extend the shared event-driven scene preview. */
/datum/stationtrauma_ocean_preview
	parent_type = /datum/stationtrauma_map_preview
	projection_type = /obj/effect/abstract/stationtrauma_ocean_projection

/datum/stationtrauma_ocean_preview/local_tile_available(turf/tile)
	return ..() && tile.GetComponent(/datum/component/floodwater)?.infinite_source

/datum/stationtrauma_ocean_preview/watch_remote(turf/tile)
	..()
	RegisterSignal(tile, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED, PROC_REF(water_changed))

/datum/stationtrauma_ocean_preview/unwatch(turf/tile)
	UnregisterSignal(tile, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED)
	return ..()

/datum/stationtrauma_ocean_preview/proc/water_changed(turf/source)
	SIGNAL_HANDLER
	for(var/atom/movable/actor as anything in source)
		if(actor in projections)
			queue_refresh(actor)

/** Existing ocean preview type retains its mapping and interaction identity. */
/obj/effect/abstract/stationtrauma_ocean_projection
	parent_type = /obj/effect/abstract/stationtrauma_map_projection
