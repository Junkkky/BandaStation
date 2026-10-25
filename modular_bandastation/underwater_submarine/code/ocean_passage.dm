/** Ocean seams add hydraulic readiness and background continuity to the shared map transfer. */
/datum/component/stationtrauma_ocean_passage
	parent_type = /datum/component/stationtrauma_map_passage

/datum/component/stationtrauma_ocean_passage/landing_available()
	return ..() && landing.GetComponent(/datum/component/floodwater)?.infinite_source

/datum/component/stationtrauma_ocean_passage/move_actor(atom/movable/arrived)
	var/list/backgrounds = list()
	for(var/atom/movable/moving as anything in arrived.get_z_move_affected(ZMOVE_INCLUDE_PULLED))
		for(var/mob/viewer as anything in moving.important_recursive_contents?[RECURSIVE_CONTENTS_CLIENT_MOBS])
			for(var/atom/movable/screen/parallax_home/home as anything in viewer.client?.parallax_instances)
				if(!home.ocean_parallax || get_turf(home.perspective) != get_turf(moving))
					continue
				for(var/atom/movable/screen/parallax_layer/ocean/seafloor/background in home.parallax_layers)
					backgrounds[background] = list(background.passage_offset_x + background.offset_x, background.passage_offset_y + background.offset_y)
	if(!..())
		return FALSE
	for(var/atom/movable/screen/parallax_layer/ocean/seafloor/background as anything in backgrounds)
		if(QDELETED(background) || get_turf(background.home?.perspective) != landing)
			continue
		var/list/position = backgrounds[background]
		background.preserve_ocean_position(position[1], position[2])
	return TRUE
