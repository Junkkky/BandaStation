/** Authored surface sites use the native ruin loader; the generator reserves their footprints first. */
/datum/map_template/ruin/expedition
	prefix = "_maps/map_files/overmap_ruins/planet/"
	ruin_type = "expedition_surface"
	allow_duplicates = FALSE
	/// Surface biome keys compatible with this ruin template.
	var/list/planet_biomes = list("barren", "frozen", "arid", "lush", "lava")

/datum/stationtrauma_overmap_site/space/planet
	/// Surface biome key used to select compatible ruin templates.
	var/ruin_biome = "barren"
	/// Loaded ruin IDs retained for this physical surface.
	var/list/ruin_ids = list()

/datum/stationtrauma_overmap_site/space/planet/frozen
	ruin_biome = "frozen"

/datum/stationtrauma_overmap_site/space/planet/arid
	ruin_biome = "arid"

/datum/stationtrauma_overmap_site/space/planet/lush
	ruin_biome = "lush"

/**
 * One large complex and one to four smaller finds at random free spots, all retained on the planet's existing level.
 *
 * Each template appears on one planet per round, so planets surveyed later may get fewer ruins, or none, once their biome's pool runs dry.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/prepare_ruins(datum/map_generator/expedition_barren/generator)
	var/list/large = list()
	var/list/small = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/expedition/template = SSmapping.ruins_templates[key]
		if(!istype(template) || template.unpickable || (template.loaded && !template.allow_duplicates) || !(ruin_biome in template.planet_biomes))
			continue
		if(template.width > 54 || template.height > 54)
			continue
		if(max(template.width, template.height) >= 25)
			large += template
		else
			small += template
	var/list/chosen = list()
	if(length(large))
		chosen += pick(large)
	for(var/index in 1 to min(rand(1, 4), length(small)))
		chosen += pick_n_take(small)
	var/list/placements = list()
	for(var/datum/map_template/ruin/expedition/template as anything in chosen)
		var/list/spot = generator.reserve_ruin(template.width, template.height)
		if(!spot)
			continue
		// Claimed on reservation, so surfaces generating side by side never take the same template.
		template.loaded++
		placements += list(list(template, spot[1], spot[2]))
	return placements

/**
 * Reserve a random spot for a ruin in a quadrant away from the camp; returns its relative southwest corner, or null when none fits.
 *
 * Ruins stay off the open cross, and ruins on one side of it never share rows, so each access corridor reaches the cross unobstructed.
 */
/datum/map_generator/expedition_barren/proc/reserve_ruin(ruin_width, ruin_height)
	var/middle = round(width / 2)
	for(var/attempt in 1 to 20)
		// The camp holds the southwest quadrant.
		var/list/quadrant = pick(list(list(FALSE, TRUE), list(TRUE, TRUE), list(TRUE, FALSE)))
		var/east = quadrant[1]
		var/x = east ? rand(middle + 3, width - 3 - ruin_width) : rand(4, middle - 2 - ruin_width)
		var/y = quadrant[2] ? rand(middle + 3, width - 3 - ruin_height) : rand(4, middle - 2 - ruin_height)
		var/top = y + ruin_height - 1
		var/clear = TRUE
		for(var/list/bounds as anything in ruin_bounds)
			if((bounds[1] > middle) == east && y <= bounds[4] + 2 && top >= bounds[2] - 2)
				clear = FALSE
				break
		if(clear)
			ruin_bounds += list(list(x, y, x + ruin_width - 1, top))
			return list(x, y)
	return null

/**
 * Load reserved ruins and retain their IDs, yielding to `budget` between templates.
 *
 * Placeholder ground and rock inside a ruin take the planet's own types, as they do in surface features.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/load_ruins(list/placements, turf/origin, area/surface, datum/stationtrauma_work_budget/budget)
	for(var/list/placement as anything in placements)
		var/datum/map_template/ruin/expedition/template = placement[1]
		var/turf/bottom = locate(origin.x + placement[2] - 1, origin.y + placement[3] - 1, origin.z)
		var/turf/center = locate(bottom.x + round(template.width / 2), bottom.y + round(template.height / 2), origin.z)
		if(!template.load(bottom))
			return FALSE
		var/list/covered = template.get_affected_turfs(bottom)
		generator.adapt_template_turfs(covered, surface)
		stationtrauma_fuel_cache(covered, ST_FUEL_CACHE_PLANET_CHANCE)
		new /obj/effect/landmark/ruin(center, template)
		ruin_ids += template.id
		budget?.yield()
	return TRUE
