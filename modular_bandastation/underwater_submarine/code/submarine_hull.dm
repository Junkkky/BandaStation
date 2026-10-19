/area/shuttle/stationtrauma
	name = "StationTrauma: подлодка"
	requires_power = TRUE

/turf/open/floor/iron/stationtrauma_hull/Initialize(mapload)
	. = ..()
	restore_stationtrauma_hull(src)

/turf/open/floor/plating/stationtrauma_hull/Initialize(mapload)
	. = ..()
	restore_stationtrauma_hull(src)

/turf/closed/wall/stationtrauma_hull/Initialize(mapload)
	. = ..()
	restore_stationtrauma_hull(src)

/// Hooks only our hull, including dry cells whose destination may have been external ocean.
/datum/element/stationtrauma_hull
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/stationtrauma_hull/Attach(turf/target)
	. = ..()
	if(!isturf(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(hull_changed), override = TRUE)
	RegisterSignals(target, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(watch_window), override = TRUE)
	if(iswallturf(target))
		target.LoadComponent(/datum/component/floodwater_leak)
	for(var/obj/structure/window/window in target)
		window.LoadComponent(/datum/component/floodwater_leak)

/datum/element/stationtrauma_hull/Detach(turf/source)
	UnregisterSignal(source, list(COMSIG_TURF_CHANGE, COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON))
	return ..()

/** Preserve hull hooks across replacement and distinguish repairing an ocean breach from opening one. */
/datum/element/stationtrauma_hull/proc/hull_changed(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(restore_stationtrauma_hull))
	var/datum/component/floodwater/water = source.GetComponent(/datum/component/floodwater)
	if(water?.infinite_source && ispath(path, /turf/open/floor))
		post_change_callbacks += CALLBACK(SSfloodwater, TYPE_PROC_REF(/datum/controller/subsystem/floodwater, mark_repaired_inlet))

/proc/restore_stationtrauma_hull(turf/tile)
	if(!isturf(tile) || isspaceturf(tile) || istype(tile, /turf/open/water))
		return
	tile.AddElement(/datum/element/stationtrauma_hull)
