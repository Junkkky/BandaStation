/** The shared hull ray uses this vessel's actual course and deck count. */
/obj/docking_port/mobile/stationtrauma/proc/navigation_hull_target(dx, dy)
	return stationtrauma_navigation_hull_target(src, overmap.course, decks, dx, dy)

/** Install ocean leak tracking before shared damage can tear or replace the hull. */
/obj/docking_port/mobile/stationtrauma/proc/damage_navigation_hull(dx, dy, impact_speed, atom/target)
	target ||= navigation_hull_target(dx, dy)
	if(iswallturf(target) && impact_speed >= 5)
		restore_stationtrauma_hull(target)
	stationtrauma_damage_hull(src, target, impact_speed)
