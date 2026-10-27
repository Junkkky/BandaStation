/// Late map loading must retain one light even when it is rebuilt before initialization.
/datum/unit_test/lighting_deferred/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/source = "lighting test [REF(src)]"
	SSatoms.map_loader_begin(source)
	tile.lighting_build_overlay()
	var/atom/movable/lighting_object/first = tile.lighting_object
	tile.lighting_build_overlay()
	var/atom/movable/lighting_object/second = tile.lighting_object
	var/replaced = QDELETED(first) && !QDELETED(second) && first != second
	tile.lighting_clear_overlay()
	var/cleared = !tile.lighting_object && QDELETED(second)
	tile.lighting_build_overlay()
	qdel(tile.lighting_object, force = TRUE)
	var/directly_released = !tile.lighting_object
	tile.lighting_build_overlay()
	var/atom/movable/lighting_object/current = tile.lighting_object
	var/pending = current && current.needs_update && !current.affected_turf && !(current in SSlighting.objects_queue)
	tile.ChangeTurf(tile.type, flags = CHANGETURF_FORCEOP | CHANGETURF_IGNORE_AIR)
	var/transferred = tile.lighting_object == current
	SSatoms.map_loader_stop(source)
	if(current)
		SSatoms.InitializeAtoms(list(current))
	var/count = 0
	for(var/atom/movable/lighting_object/light in tile)
		if(!QDELETED(light))
			count++
		if(light != tile.lighting_object)
			qdel(light, force = TRUE)
	if(!tile.lighting_object)
		tile.lighting_build_overlay()
	if(!replaced || !cleared || !directly_released)
		Fail("Deferred lights must release ownership on replacement, clear and direct deletion", __FILE__, __LINE__)
	if(!pending || !transferred)
		Fail("A pending light must stay outside the rendering queue and survive ChangeTurf", __FILE__, __LINE__)
	if(current?.affected_turf != tile || tile.lighting_object != current || count != 1)
		Fail("Initialization must retain exactly one live light and its turf owner", __FILE__, __LINE__)
