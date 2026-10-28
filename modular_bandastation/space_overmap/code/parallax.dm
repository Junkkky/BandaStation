/area
	/// Null retains the native background; expedition areas choose a native layer explicitly.
	var/space_parallax_background

/area/shuttle/stationtrauma_space
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/space/stationtrauma_space_home
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/stationtrauma_space_site
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/stationtrauma_space_site/asteroid
	space_parallax_background = /atom/movable/screen/parallax_layer/random/asteroids

/datum/space_level
	var/space_parallax_background

/area/proc/set_space_parallax_background(background)
	SHOULD_CALL_PARENT(TRUE)
	if(space_parallax_background == background)
		return
	space_parallax_background = background
	SEND_SIGNAL(src, COMSIG_AREA_SPACE_PARALLAX_CHANGED)

/** Explicit area profiles take precedence over the ship level's station trait. */
/proc/stationtrauma_space_parallax(atom/viewpoint)
	var/turf/tile = get_turf(viewpoint)
	if(!tile)
		return null
	var/area/location = get_area(tile)
	if(location.space_parallax_background)
		return location.space_parallax_background
	var/datum/space_level/level = SSmapping.get_level(tile.z)
	if(level?.space_parallax_background)
		return level.space_parallax_background
	if(!SSmapping.current_map?.space_overmap && !length(SSstationtrauma_space_voyage.sectors))
		return null
	return is_station_level(tile.z) ? /atom/movable/screen/parallax_layer/planet : /atom/movable/screen/parallax_layer/layer_3

/atom/movable/screen/parallax_home
	var/space_background

/atom/movable/screen/parallax_home/set_perspective_area(area/new_area)
	if(perspective_area == new_area)
		return ..()
	if(perspective_area)
		UnregisterSignal(perspective_area, COMSIG_AREA_SPACE_PARALLAX_CHANGED)
	. = ..()
	RegisterSignal(new_area, COMSIG_AREA_SPACE_PARALLAX_CHANGED, PROC_REF(space_background_changed))

/atom/movable/screen/parallax_home/proc/space_background_changed(datum/source)
	SIGNAL_HANDLER
	update_parallax()

/atom/movable/screen/parallax_home/update_parallax()
	var/background = stationtrauma_space_parallax(perspective)
	if(background != space_background)
		space_background = background
		// Cancel old layer timers before replacement, then let the native update restore motion.
		set_parallax_movedir(NONE, TRUE)
		regenerate_layers()
	return ..()

/** Preserve native quality settings without inheriting the round-wide random asteroid/gas layer. */
/atom/movable/screen/parallax_home/generate_space_layer(index)
	var/background = stationtrauma_space_parallax(perspective)
	if(background)
		if(index == 4)
			var/layer_type = background == /atom/movable/screen/parallax_layer/planet ? /atom/movable/screen/parallax_layer/layer_3 : background
			return new layer_type(null, null, src)
		if(index == 5)
			return background == /atom/movable/screen/parallax_layer/random/asteroids ? new /atom/movable/screen/parallax_layer/layer_3(null, null, src) : null
	return ..()

/atom/movable/screen/parallax_layer/planet/on_z_change(atom/source)
	// SIGNAL_HANDLER is inherited from the original definition; redeclaring it breaks DreamChecker.
	. = ..()
	var/background = stationtrauma_space_parallax(home?.perspective)
	if(background)
		SetInvisibility(background == /atom/movable/screen/parallax_layer/planet ? INVISIBILITY_NONE : INVISIBILITY_ABSTRACT, id = type)

/datum/stationtrauma_overmap/space
	var/space_background

/datum/stationtrauma_overmap/space/proc/parallax_background()
	if(docked?.physical_docking)
		return /atom/movable/screen/parallax_layer/planet
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		if(zone.kind == "asteroids" && (pos_x - zone.pos_x) ** 2 + (pos_y - zone.pos_y) ** 2 <= zone.radius ** 2)
			return /atom/movable/screen/parallax_layer/random/asteroids
	return /atom/movable/screen/parallax_layer/layer_3
