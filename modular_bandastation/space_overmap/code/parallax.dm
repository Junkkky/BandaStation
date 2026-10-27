/// Raven keeps native stars and motion; its station trait must not add the stationary planet.
/atom/movable/screen/parallax_layer/planet/on_z_change(atom/source)
	// SIGNAL_HANDLER is inherited from the original definition; redeclaring it breaks DreamChecker.
	. = ..()
	var/area/viewing_area = get_area(home?.perspective)
	if(istype(viewing_area, /area/shuttle/stationtrauma_space) || istype(viewing_area, /area/space/stationtrauma_space_home))
		SetInvisibility(INVISIBILITY_ABSTRACT, id = type)
