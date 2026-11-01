/** Find the first real hull barrier on the impact ray; this runs only on contact, not every helm tick. */
/proc/stationtrauma_navigation_hull_target(obj/docking_port/mobile/vessel, heading, decks, dx, dy, bow_direction = EAST)
	if(QDELETED(vessel))
		return null
	var/rotation = heading - dir2angle(bow_direction)
	var/local_x = dx * cos(rotation) - dy * sin(rotation)
	var/local_y = dx * sin(rotation) + dy * cos(rotation)
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

/**
 * The single entry for external hits on a ship hull: the impact ray finds the struck plating, native TG effects apply the damage.
 *
 * Arguments:
 * * vessel - struck hull
 * * heading - hull course, degrees clockwise from north
 * * dx, dy - overmap direction from the hull towards the hit source, east and north
 * * kind - SHIP_HIT_* effect
 * * power - effect strength, see the SHIP_HIT_* defines
 *
 * Returns the struck wall or barrier, or null when the ray found no plating.
 */
/proc/stationtrauma_hull_hit(obj/docking_port/mobile/vessel, heading, dx, dy, kind, power)
	if(QDELETED(vessel) || power <= 0)
		return null
	var/atom/target = stationtrauma_navigation_hull_target(vessel, heading, 1, dx, dy, vessel.preferred_direction)
	if(!target)
		return null
	switch(kind)
		if(SHIP_HIT_IMPACT)
			if(power < 5)
				return null
			if(iswallturf(target))
				target.AddComponent(/datum/component/torn_wall, power >= 35 ? 1 : 0)
				if(power >= 60 && iswallturf(target))
					target.AddComponent(/datum/component/torn_wall)
			else if(isobj(target))
				var/obj/barrier = target
				barrier.take_damage(power * 5, BRUTE, MELEE)
			playsound(target, 'sound/effects/meteorimpact.ogg', 70, TRUE)
		if(SHIP_HIT_KINETIC)
			explosion(get_turf(target), heavy_impact_range = power, light_impact_range = power + 1, flame_range = 0, flash_range = 0, explosion_cause = vessel)
		if(SHIP_HIT_EMP)
			empulse(get_turf(target), heavy_range = power, light_range = power * 2, emp_source = vessel)
		else
			CRASH("Unknown hull hit kind [kind]")
	for(var/mob/viewer as anything in GLOB.player_list)
		if(vessel.is_in_shuttle_bounds(viewer))
			to_chat(viewer, span_danger("Корпус сотрясается от внешнего удара!"))
	return target

/datum/stationtrauma_overmap/space/on_collision(datum/stationtrauma_overmap_terrain/obstacle, impact_speed)
	var/list/nearest = obstacle.nearest(pos_x, pos_y)
	// A full-speed impact (5 sector units/s) reaches the severe, repairable hull tear tier.
	stationtrauma_hull_hit(vessel, course, nearest[1] - pos_x, nearest[2] - pos_y, SHIP_HIT_IMPACT, impact_speed * 12)
