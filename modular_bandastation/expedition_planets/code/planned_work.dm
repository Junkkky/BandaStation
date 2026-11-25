/**
 * # Planned work
 *
 * Everything placed on a level is first chosen against what lies there, then built as work over the rectangle it
 * touches. The choice reads the level's plan, so a whole level is decorated on paper before its ground is laid, and
 * each piece of work can wait for the chunks under it.
 */
/datum/map_generator/expedition_barren
	/// South-west turf of the level being decorated: see begin_decoration()
	var/turf/level_bottom
	/// Cells of the level being decorated already taken by something planned on them; later plans keep off them
	var/list/plan_taken
	/// Work waiting for its ground, in planning order: each list(west, south, east, north, callback, critical, life)
	var/list/planned_work = list()
	/// Where the fauna packs of the level being decorated stand, so packs settled a chunk at a time keep apart
	var/list/pack_anchors

/// Starts choosing places on the level whose south-west turf is [bottom]
/datum/map_generator/expedition_barren/proc/begin_decoration(turf/bottom)
	level_bottom = bottom
	plan_taken = new /list(width * width)
	dig_anchors = null
	pack_anchors = list()

/// The index in the plan of the cell at relative [x], [y]
/datum/map_generator/expedition_barren/proc/plan_cell(x, y)
	return (y - 1) * width + x

/// The turf at relative [x], [y] of the level being decorated
/datum/map_generator/expedition_barren/proc/level_turf(x, y)
	return locate(level_bottom.x + x - 1, level_bottom.y + y - 1, level_bottom.z)

/// The planned terrain at relative [x], [y] of the level being decorated. Null outside the square.
/datum/map_generator/expedition_barren/proc/terrain_at(x, y)
	if(x < 1 || y < 1 || x > width || y > width)
		return null
	var/list/planned = cave_level ? cave_terrain : surface_terrain
	return planned[plan_cell(x, y)]

/// Whether nothing is planned yet at relative [x], [y]
/datum/map_generator/expedition_barren/proc/plan_free(x, y)
	return x >= 1 && y >= 1 && x <= width && y <= width && !plan_taken[plan_cell(x, y)]

/// Marks relative [x], [y] as taken by something planned there
/datum/map_generator/expedition_barren/proc/plan_take(x, y)
	if(x >= 1 && y >= 1 && x <= width && y <= width)
		plan_taken[plan_cell(x, y)] = TRUE

/// Walkable ground at relative [x], [y] free for something to be set on: not reserved for the camp, its routes or a ruin, and not taken
/datum/map_generator/expedition_barren/proc/plan_ground(x, y)
	return dry_surface_type(terrain_at(x, y)) && !is_reserved(x, y) && plan_free(x, y)

/// How many cells within [radius] of relative [x], [y] a creature could stand on, as standing_ground() counts turfs
/datum/map_generator/expedition_barren/proc/plan_standing_ground(x, y, radius)
	. = 0
	for(var/near_y in y - radius to y + radius)
		for(var/near_x in x - radius to x + radius)
			var/terrain = terrain_at(near_x, near_y)
			if(ispath(terrain, /turf/open) && !ispath(terrain, /turf/open/chasm) && !ispath(terrain, /turf/open/openspace) && !ispath(terrain, /turf/open/lava) && plan_free(near_x, near_y))
				.++

/**
 * Plans [work] over relative [west], [south] to [east], [north]: it runs once the ground there is laid. Critical work that
 * fails fails the whole level, as a ruin that does not load does. [life] is how many creatures and dens it sets, for the
 * survey to show before they exist.
 */
/datum/map_generator/expedition_barren/proc/plan_work(west, south, east, north, datum/callback/work, critical = FALSE, life = 0)
	planned_work += list(list(west, south, east, north, work, critical, life))
