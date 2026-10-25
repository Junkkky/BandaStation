/// Raven keeps native stars and motion; its station trait must not add the stationary planet.
/atom/movable/screen/parallax_layer/planet/on_z_change(atom/source)
	SIGNAL_HANDLER
	var/turf/viewing_from = get_turf(home?.perspective)
	if(!viewing_from)
		return
	var/area/viewing_area = get_area(viewing_from)
	var/on_ship = istype(viewing_area, /area/shuttle/stationtrauma_space) || istype(viewing_area, /area/space/stationtrauma_space_home)
	SetInvisibility(is_station_level(viewing_from.z) && !on_ship ? INVISIBILITY_NONE : INVISIBILITY_ABSTRACT, id = type)
