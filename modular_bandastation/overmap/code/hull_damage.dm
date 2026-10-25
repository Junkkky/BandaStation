/** Find the first real hull barrier on the impact ray; this runs only on contact, not every helm tick. */
/proc/stationtrauma_navigation_hull_target(obj/docking_port/mobile/vessel, heading, decks, dx, dy)
	if(QDELETED(vessel))
		return null
	var/local_x = dx * sin(heading) + dy * cos(heading)
	var/local_y = -dx * cos(heading) + dy * sin(heading)
	var/list/bounds = vessel.return_coords()
	var/hull_width = abs(bounds[3] - bounds[1]) + 1
	var/hull_height = abs(bounds[4] - bounds[2]) + 1
	var/extent = max(abs(local_x) / max(1, hull_width / 2), abs(local_y) / max(1, hull_height / 2))
	if(!extent)
		return null
	local_x /= extent
	local_y /= extent
	var/turf/center = locate(round((bounds[1] + bounds[3]) / 2), round((bounds[2] + bounds[4]) / 2), vessel.z + min(1, decks - 1))
	if(!center)
		return null
	for(var/step in 0 to max(hull_width, hull_height))
		var/fraction = 1 - step / max(hull_width, hull_height)
		var/turf/tile = locate(round(center.x + local_x * fraction), round(center.y + local_y * fraction), center.z)
		if(!tile || !vessel.shuttle_areas[get_area(tile)])
			continue
		if(iswallturf(tile))
			return tile
		for(var/obj/barrier in tile)
			if(barrier.density && (istype(barrier, /obj/structure/window) || istype(barrier, /obj/machinery/door)))
				return barrier
	return null

/** Native repairable wall tears and object integrity work in either vacuum or a planetary environment. */
/proc/stationtrauma_damage_hull(obj/docking_port/mobile/vessel, atom/target, impact_speed)
	if(QDELETED(vessel) || !target || impact_speed < 5)
		return
	if(iswallturf(target))
		target.AddComponent(/datum/component/torn_wall, impact_speed >= 35 ? 1 : 0)
		if(impact_speed >= 60 && iswallturf(target))
			target.AddComponent(/datum/component/torn_wall)
	else if(isobj(target))
		var/obj/barrier = target
		barrier.take_damage(impact_speed * 5, BRUTE, MELEE)
	playsound(target, 'sound/effects/meteorimpact.ogg', 70, TRUE)
	for(var/mob/viewer as anything in GLOB.player_list)
		if(vessel.is_in_shuttle_bounds(viewer))
			to_chat(viewer, span_danger("Корпус сотрясается от внешнего удара!"))
