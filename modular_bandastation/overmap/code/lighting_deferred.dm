// Map loading may create and replace a light before its Initialize publishes the turf owner.
/atom/movable/lighting_object
	needs_update = TRUE

/atom/movable/lighting_object/Initialize(mapload)
	var/turf/owner = isturf(loc) ? loc : null
	if(owner?.lighting_object == src)
		owner.lighting_object = null
	return ..()

/atom/movable/lighting_object/Destroy(force)
	if(!force && !isnull(affected_turf))
		return ..()
	var/turf/owner = affected_turf || (isturf(loc) ? loc : null)
	if(owner?.lighting_object == src)
		owner.lighting_object = null
		owner.luminosity = 1
	// The native destructor must not clear a replacement light's turf ownership.
	affected_turf = null
	return ..()

/turf/lighting_build_overlay()
	if(lighting_object)
		qdel(lighting_object, force = TRUE)
	lighting_object = new /atom/movable/lighting_object(src)

/turf/ChangeTurf(path, list/new_baseturfs, flags)
	. = ..()
	if(SSatoms.initialized != INITIALIZATION_INSSATOMS)
		return
	var/turf/replacement = .
	if(!replacement || replacement.lighting_object)
		return
	// ChangeTurf creates its own deferred light rather than using lighting_build_overlay.
	for(var/atom/movable/lighting_object/light in replacement)
		if(!QDELETED(light))
			replacement.lighting_object = light
			break
