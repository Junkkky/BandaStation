/**
 * # Jump points
 *
 * A charted system is jumped into and out of only at its jump points: bluespace eddies out at its edge, past its
 * planets and ruins. A hull starts a jump at one of them and arrives at the one of the destination that faces the
 * system it left, as they lie on the galaxy map.
 *
 * A system without jump points (a test fixture) is jumped from anywhere and arrived at its entry point, as before.
 */

/// Distance of the jump points from the star
#define ST_JUMP_POINT_RADIUS 2300
/// How close a hull has to be to a jump point to start a jump from it
#define ST_JUMP_POINT_RANGE ST_SPACE_DOCK_RANGE
/// Least angle between two jump points of one system, in degrees
#define ST_JUMP_POINT_SPREAD 60

/datum/stationtrauma_overmap_sector/space
	/// Jump points of this system, also charted among its sites
	var/list/datum/stationtrauma_overmap_site/space/jump_point/jump_points = list()

/// A jump point on the chart: always known, flown to like any destination, never docked at
/datum/stationtrauma_overmap_site/space/jump_point
	name = "Точка перехода"
	discovered = TRUE
	needs_scan = FALSE
	approach_scene = "jump"

/** Scatter two to four jump points round the edge of this system, well apart. */
/datum/stationtrauma_overmap_sector/space/proc/chart_jump_points()
	var/count = rand(2, 4)
	var/list/bearings = list()
	for(var/attempt in 1 to 60)
		if(length(bearings) >= count)
			break
		var/bearing = rand(0, 359)
		var/clear = TRUE
		for(var/other in bearings)
			var/apart = abs(bearing - other) % 360
			if(min(apart, 360 - apart) < ST_JUMP_POINT_SPREAD)
				clear = FALSE
				break
		if(clear)
			bearings += bearing
	for(var/bearing in bearings)
		var/datum/stationtrauma_overmap_site/space/jump_point/jump = new
		jump.id = "[id]_jump_[length(jump_points) + 1]"
		jump.pos_x = round(ST_JUMP_POINT_RADIUS * sin(bearing))
		jump.pos_y = round(ST_JUMP_POINT_RADIUS * cos(bearing))
		jump_points += jump
		sites[jump.id] = jump
		LAZYADD(taken_positions, list(list(jump.pos_x, jump.pos_y)))

/**
 * The jump point of this system facing [origin] on the galaxy map, as list(x, y): where a hull jumping in from there
 * arrives. Null if this system has none.
 */
/datum/stationtrauma_overmap_sector/space/proc/arrival_point(datum/stationtrauma_overmap_sector/space/origin)
	if(!length(jump_points))
		return null
	var/datum/stationtrauma_overmap_site/space/jump_point/first = jump_points[1]
	if(!origin)
		return list(first.pos_x, first.pos_y)
	// the galaxy map's y runs down, a system chart's up
	var/facing = arctan(galaxy_y - origin.galaxy_y, origin.galaxy_x - galaxy_x)
	var/datum/stationtrauma_overmap_site/space/jump_point/best
	var/best_apart = INFINITY
	for(var/datum/stationtrauma_overmap_site/space/jump_point/jump as anything in jump_points)
		var/apart = abs(arctan(jump.pos_y, jump.pos_x) - facing) % 360
		apart = min(apart, 360 - apart)
		if(apart < best_apart)
			best = jump
			best_apart = apart
	return list(best.pos_x, best.pos_y)

/// Whether this hull is at one of its system's jump points, or its system has none
/datum/stationtrauma_overmap/space/proc/at_jump_point()
	var/datum/stationtrauma_overmap_sector/space/here = sector
	if(!length(here?.jump_points))
		return TRUE
	for(var/datum/stationtrauma_overmap_site/space/jump_point/jump as anything in here.jump_points)
		if(distance_to(jump) <= ST_JUMP_POINT_RANGE)
			return TRUE
	return FALSE

/// Whether a jump to [id] can start here and now
/datum/stationtrauma_overmap/space/proc/jump_ready(id)
	return can_jump(id) && at_jump_point()

#undef ST_JUMP_POINT_RADIUS
#undef ST_JUMP_POINT_SPREAD
