/** A local ocean seam; native zMove retains occupants, pulling and immersion without moving the vessel. */
/datum/component/stationtrauma_ocean_passage
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// A real ocean tile just beyond the reverse seam, preventing immediate bounce-back.
	var/turf/open/landing
	/// Cardinal direction towards the destination.
	var/direction

/datum/component/stationtrauma_ocean_passage/Initialize(turf/open/destination, facing)
	if(!isspaceturf(parent) || !isspaceturf(destination) || !(facing in GLOB.cardinals))
		return COMPONENT_INCOMPATIBLE
	landing = destination
	direction = facing

/datum/component/stationtrauma_ocean_passage/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_ENTERED, PROC_REF(on_entered))
	RegisterSignal(parent, COMSIG_TURF_CHANGE, PROC_REF(remove_passage))

/datum/component/stationtrauma_ocean_passage/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_ENTERED, COMSIG_TURF_CHANGE))

/datum/component/stationtrauma_ocean_passage/proc/remove_passage()
	SIGNAL_HANDLER
	qdel(src)

/datum/component/stationtrauma_ocean_passage/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(istype(arrived, /obj/effect/abstract/stationtrauma_ocean_projection))
		return
	// Finish the original area's Entered/Moved signals before entering another area.
	addtimer(CALLBACK(src, PROC_REF(cross), arrived), 0, TIMER_UNIQUE)

/** Recheck the live exit instead of using space transit's search for another landing inside the map. */
/datum/component/stationtrauma_ocean_passage/proc/cross(atom/movable/arrived)
	if(QDELETED(src) || QDELETED(arrived) || arrived.loc != parent || arrived.anchored || arrived.currently_z_moving || arrived.pulledby)
		return FALSE
	if(istype(arrived, /atom/movable/mirage_holder) || istype(arrived, /obj/effect/overlay) || istype(arrived, /atom/movable/lighting_object) || istype(arrived, /obj/effect/abstract/z_holder))
		return FALSE
	if(SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD || QDELETED(landing) || !isspaceturf(landing) || landing.density)
		return FALSE
	var/datum/component/floodwater/water = landing.GetComponent(/datum/component/floodwater)
	if(!water?.infinite_source)
		return FALSE
	for(var/atom/movable/obstacle as anything in landing)
		if(obstacle.density)
			return FALSE
	var/list/backgrounds = list()
	for(var/atom/movable/moving as anything in arrived.get_z_move_affected(ZMOVE_INCLUDE_PULLED))
		for(var/mob/viewer as anything in moving.important_recursive_contents?[RECURSIVE_CONTENTS_CLIENT_MOBS])
			for(var/atom/movable/screen/parallax_home/home as anything in viewer.client?.parallax_instances)
				if(!home.ocean_parallax || get_turf(home.perspective) != get_turf(moving))
					continue
				for(var/atom/movable/screen/parallax_layer/ocean/seafloor/background in home.parallax_layers)
					backgrounds[background] = list(background.passage_offset_x + background.offset_x, background.passage_offset_y + background.offset_y)
	if(!arrived.zMove(null, landing, ZMOVE_ALLOW_BUCKLED|ZMOVE_INCLUDE_PULLED))
		return FALSE
	for(var/atom/movable/screen/parallax_layer/ocean/seafloor/background as anything in backgrounds)
		if(QDELETED(background) || get_turf(background.home?.perspective) != landing)
			continue
		var/list/position = backgrounds[background]
		background.preserve_ocean_position(position[1], position[2])
	return TRUE
