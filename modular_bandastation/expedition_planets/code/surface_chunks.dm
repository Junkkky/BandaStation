/**
 * # Expedition surface
 *
 * A planet's surface, planned whole and built a chunk at a time. Before the first landing only the ground around the
 * landing pads is built; after it the chunks around the living crew are built as they walk, then the ruins, then the
 * cave level, then the rest of the surface outwards from the pads, until the whole planet stands.
 *
 * A chunk goes through three stages: its ground and rock are laid; its ore is seeded; then whatever was planned over
 * it is built once every chunk under that is seeded, and its flora and fauna settle. A vein stops at ground not laid
 * yet rather than waiting for it, as anything else would have the chunks around wait in turn and the whole planet be
 * laid for the first one; a vein from ground laid later may still grow into it. Laid ground next to unbuilt chunks is
 * walled off from the empty level beyond until they are built.
 */

/// A chunk's ground and rock are laid
#define SURFACE_CHUNK_LAID 1
/// A chunk's ore veins are seeded
#define SURFACE_CHUNK_VEINED 2
/// Everything planned over a chunk is built and its wildlife settled
#define SURFACE_CHUNK_DONE 3
/// Tiles around a landing pad built before the first landing: what the crew sees stepping out of the hull
#define SURFACE_LANDING_MARGIN 8
/// Chunks each way around a living player built as they walk
#define SURFACE_PLAYER_REACH 2
/// Share of a tick the builder takes, in percent: catching up with someone at or next to unbuilt ground, and otherwise
#define SURFACE_ALLOWANCE_URGENT 50
#define SURFACE_ALLOWANCE_USUAL 25
/// What walls laid ground off from unbuilt chunks until they are built
#define SURFACE_UNBUILT_WALL /turf/closed/indestructible/rock

/// Expedition surfaces still being built, by the z-level of their surface as text
GLOBAL_LIST_EMPTY(expedition_surfaces)

/datum/expedition_surface
	var/datum/stationtrauma_overmap_site/space/planet/planet
	var/datum/map_generator/expedition_barren/generator
	/// The planet's surface area
	var/area/surface
	/// South-west turf of the generated square
	var/turf/bottom
	/// Chunks along a side of the square
	var/side
	/// Stage of each chunk, by index
	var/list/stages
	/// Rock each laid chunk left for its veins, by index
	var/list/chunk_rocks
	/// Biome turfs each laid chunk left for its wildlife, by index
	var/list/chunk_biomes
	/// Planned work over each chunk, by index; a piece over several chunks is shared by their lists
	var/list/chunk_work
	/// Chunks under the ruins, built once the ground around the crew is
	var/list/ruin_chunks = list()
	/// Whether ruins are still to be built; the destination counts as loaded once they stand
	var/ruins_pending = TRUE
	/// Cave level still to be built, if the planet has one
	var/datum/space_level/caves
	/// Work slice shared with the generator
	var/datum/stationtrauma_work_budget/budget
	/// Whether the background build is running
	var/building = FALSE
	/// Chunks in the order the rest of the planet is built in: outwards from the first landing pad
	var/list/rest_order = list()
	/// Biome of each unbuilt cell, worked out when a picture first needs it
	var/list/planned_biomes

/datum/expedition_surface/New(datum/stationtrauma_overmap_site/space/planet/planet, area/surface, turf/bottom, datum/space_level/caves, list/ruins)
	src.planet = planet
	generator = planet.generator
	budget = generator.budget
	src.surface = surface
	src.bottom = bottom
	src.caves = caves
	side = CEILING(generator.width / EXPEDITION_CHUNK_SIZE, 1)
	var/count = side * side
	stages = new /list(count)
	for(var/index in 1 to count)
		stages[index] = 0
	chunk_rocks = new /list(count)
	chunk_biomes = new /list(count)
	chunk_work = new /list(count)
	for(var/list/work as anything in generator.planned_work)
		// the last field marks the work done
		work += FALSE
		for(var/chunk in chunks_in(work[1], work[2], work[3], work[4]))
			LAZYADD(chunk_work[chunk], list(work))
	generator.planned_work = list()
	for(var/list/placement as anything in ruins)
		var/datum/map_template/template = placement[1]
		ruin_chunks |= chunks_in(placement[2], placement[3], placement[2] + template.width - 1, placement[3] + template.height - 1)
	var/list/pad = LAZYACCESS(generator.landing_pads, 1)
	var/first = pad ? chunk_at(round((pad[1] + pad[3]) / 2), round((pad[2] + pad[4]) / 2)) : 1
	for(var/reach in 0 to side)
		for(var/chunk in chunks_around(first, reach))
			rest_order |= chunk
	GLOB.expedition_surfaces["[bottom.z]"] = src

/datum/expedition_surface/Destroy()
	if(GLOB.expedition_surfaces["[bottom?.z]"] == src)
		GLOB.expedition_surfaces -= "[bottom.z]"
	if(planet?.surface_chunks == src)
		planet.surface_chunks = null
	if(planet?.generator == generator)
		generator = null
	else
		QDEL_NULL(generator)
	planet = null
	surface = null
	bottom = null
	caves = null
	chunk_rocks = null
	chunk_biomes = null
	chunk_work = null
	return ..()

/// The chunk holding relative [x], [y]
/datum/expedition_surface/proc/chunk_at(x, y)
	return 1 + round((x - 1) / EXPEDITION_CHUNK_SIZE) + round((y - 1) / EXPEDITION_CHUNK_SIZE) * side

/// Chunks touching the relative rectangle [west], [south] to [east], [north], clipped to the square
/datum/expedition_surface/proc/chunks_in(west, south, east, north)
	. = list()
	var/width = generator.width
	for(var/y in round((clamp(south, 1, width) - 1) / EXPEDITION_CHUNK_SIZE) to round((clamp(north, 1, width) - 1) / EXPEDITION_CHUNK_SIZE))
		for(var/x in round((clamp(west, 1, width) - 1) / EXPEDITION_CHUNK_SIZE) to round((clamp(east, 1, width) - 1) / EXPEDITION_CHUNK_SIZE))
			. += 1 + x + y * side

/// The chunk [chunk] and those around it within [reach] chunks
/datum/expedition_surface/proc/chunks_around(chunk, reach)
	. = list()
	var/column = (chunk - 1) % side
	var/row = round((chunk - 1) / side)
	for(var/y in max(0, row - reach) to min(side - 1, row + reach))
		for(var/x in max(0, column - reach) to min(side - 1, column + reach))
			. += 1 + x + y * side

/// The relative bounds of [chunk]: west, south, east, north
/datum/expedition_surface/proc/chunk_bounds(chunk)
	var/west = ((chunk - 1) % side) * EXPEDITION_CHUNK_SIZE + 1
	var/south = round((chunk - 1) / side) * EXPEDITION_CHUNK_SIZE + 1
	return list(west, south, min(generator.width, west + EXPEDITION_CHUNK_SIZE - 1), min(generator.width, south + EXPEDITION_CHUNK_SIZE - 1))

/// Whether the tile at relative [x], [y] is laid
/datum/expedition_surface/proc/laid(x, y)
	return x < 1 || y < 1 || x > generator.width || y > generator.width || stages[chunk_at(x, y)] >= SURFACE_CHUNK_LAID

/// Every piece of planned work still held, once each
/datum/expedition_surface/proc/all_work()
	. = list()
	for(var/list/work_list as anything in chunk_work)
		for(var/list/work as anything in work_list)
			. |= list(work)

/**
 * How the tile at relative [x], [y] will look once built, for pictures of the planet from above while it is not:
 * list(icon, icon_state, colour, flora type or null). Null once its chunk is laid. The flora is a likely one rather than
 * the one that will grow there; nobody looks that closely from a descending hull.
 */
/datum/expedition_surface/proc/planned_look(x, y)
	if(x < 1 || y < 1 || x > generator.width || y > generator.width || stages[chunk_at(x, y)])
		return null
	var/cell = generator.plan_cell(x, y)
	var/turf/terrain = generator.surface_terrain[cell]
	var/state = initial(terrain.icon_state)
	if(initial(terrain.smoothing_flags) & SMOOTH_BITMASK)
		state = "[initial(terrain.base_icon_state)]-255"
	var/colour = (ispath(terrain, /turf/closed/mineral) && generator.rock_color) || initial(terrain.color)
	var/flora
	if(generator.dry_surface_type(terrain) && !generator.is_reserved(x, y))
		planned_biomes ||= new /list(generator.width * generator.width)
		var/datum/biome/biome = planned_biomes[cell]
		if(!biome)
			biome = generator.biome_at(x, y, FALSE)
			planned_biomes[cell] = biome
		// the same ground draws the same likely plant every time
		var/roll = (x * 7919 + y * 104729 + generator.seed % 9973) % 10007
		if(length(biome.flora_types) && roll * 100 < biome.flora_density * 10007)
			flora = biome.flora_types[(roll * 31 + 17) % length(biome.flora_types) + 1]
	return list(initial(terrain.icon), state, colour, flora)

/// How an unbuilt expedition surface tile at [x], [y], [z] will look; see /datum/expedition_surface/proc/planned_look()
/proc/expedition_planned_look(x, y, z)
	var/datum/expedition_surface/surface = GLOB.expedition_surfaces["[z]"]
	return surface?.planned_look(x - surface.bottom.x + 1, y - surface.bottom.y + 1)

/// Lays [chunk]'s ground and rock, and walls it off from the unbuilt chunks around it
/datum/expedition_surface/proc/lay(chunk)
	if(stages[chunk])
		return
	stages[chunk] = SURFACE_CHUNK_LAID
	var/list/bounds = chunk_bounds(chunk)
	chunk_rocks[chunk] = generator.lay_terrain(block(bottom.x + bounds[1] - 1, bottom.y + bounds[2] - 1, bottom.z, bottom.x + bounds[3] - 1, bottom.y + bounds[4] - 1, bottom.z), surface)
	chunk_biomes[chunk] = generator.biome_turfs
	generator.biome_turfs = null
	// the empty level would take the air and show the stars, so the ground stops at a wall until the next chunk is built
	for(var/y in bounds[2] - 1 to bounds[4] + 1)
		for(var/x in bounds[1] - 1 to bounds[3] + 1)
			if(laid(x, y))
				continue
			var/turf/edge = locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z)
			if(isspaceturf(edge))
				edge.ChangeTurf(SURFACE_UNBUILT_WALL, null, CHANGETURF_IGNORE_AIR)
		budget.yield()

/// Seeds [chunk]'s ore; its veins grow into the rock laid around it so far
/datum/expedition_surface/proc/seed(chunk)
	if(stages[chunk] >= SURFACE_CHUNK_VEINED)
		return
	lay(chunk)
	stages[chunk] = SURFACE_CHUNK_VEINED
	generator.seed_veins(chunk_rocks[chunk])
	chunk_rocks[chunk] = null

/**
 * Builds [chunk] through: whatever was planned over it, then its flora and fauna. Returns FALSE if a piece of critical
 * work failed, as a ruin that does not load.
 */
/datum/expedition_surface/proc/finish(chunk)
	if(stages[chunk] >= SURFACE_CHUNK_DONE)
		return TRUE
	. = TRUE
	seed(chunk)
	for(var/list/work as anything in chunk_work[chunk])
		if(work[8])
			continue
		for(var/under in chunks_in(work[1], work[2], work[3], work[4]))
			seed(under)
		if(work[8])
			continue
		work[8] = TRUE
		var/datum/callback/callback = work[5]
		if(!callback.Invoke() && work[6])
			stack_trace("Planned work [callback.delegate] on [planet.name] failed")
			. = FALSE
		budget.yield()
	chunk_work[chunk] = null
	stages[chunk] = SURFACE_CHUNK_DONE
	generator.biome_turfs = chunk_biomes[chunk]
	chunk_biomes[chunk] = null
	generator.populate_biomes()

/// Builds the chunks under and around the landing pads, before anyone lands; returns FALSE if critical work there failed
/datum/expedition_surface/proc/prepare_landing()
	. = TRUE
	for(var/list/pad as anything in generator.landing_pads)
		for(var/chunk in chunks_in(pad[1] - SURFACE_LANDING_MARGIN, pad[2] - SURFACE_LANDING_MARGIN, pad[3] + SURFACE_LANDING_MARGIN, pad[4] + SURFACE_LANDING_MARGIN))
			if(!finish(chunk))
				. = FALSE

/// The next chunk to build: nearest a living player, then under a ruin. Null when none waits. Sets the share of a tick for it.
/datum/expedition_surface/proc/next_chunk()
	var/best
	var/best_distance = INFINITY
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		if(player.z != bottom.z)
			continue
		var/x = player.x - bottom.x + 1
		var/y = player.y - bottom.y + 1
		if(x < 1 || y < 1 || x > generator.width || y > generator.width)
			continue
		var/here = chunk_at(x, y)
		for(var/chunk in chunks_around(here, SURFACE_PLAYER_REACH))
			if(stages[chunk] >= SURFACE_CHUNK_DONE)
				continue
			var/distance = max(abs((chunk - 1) % side - (here - 1) % side), abs(round((chunk - 1) / side) - round((here - 1) / side)))
			if(distance < best_distance)
				best = chunk
				best_distance = distance
	if(best)
		// someone at or next to unbuilt ground waits at its wall: catch up
		budget.allowance = best_distance <= 1 ? SURFACE_ALLOWANCE_URGENT : SURFACE_ALLOWANCE_USUAL
		return best
	budget.allowance = SURFACE_ALLOWANCE_USUAL
	if(ruins_pending)
		for(var/chunk in ruin_chunks)
			if(stages[chunk] < SURFACE_CHUNK_DONE)
				return chunk
		ruins_pending = FALSE
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_SITE_LOADED, planet)
	return null

/// The next chunk of the rest of the planet, outwards from the first pad, or null once it all stands
/datum/expedition_surface/proc/next_rest_chunk()
	budget.allowance = SURFACE_ALLOWANCE_USUAL
	for(var/chunk in rest_order)
		if(stages[chunk] < SURFACE_CHUNK_DONE)
			return chunk
	return null

/// Builds the cave level, once the surface it opens onto is built
/datum/expedition_surface/proc/build_caves()
	var/datum/space_level/level = caves
	caves = null
	for(var/list/point as anything in generator.connector_points)
		finish(chunk_at(point[1], point[2]))
	// the cave pass decorates its own level and breeds denser caves; the surface keeps its own when it goes on after
	var/turf/surface_bottom = generator.level_bottom
	var/list/surface_taken = generator.plan_taken
	var/list/surface_anchors = generator.dig_anchors
	var/list/surface_packs = generator.pack_anchors
	var/list/densities = list()
	for(var/biome_type in generator.biomes)
		var/datum/biome/biome = generator.biomes[biome_type]
		densities[biome] = biome.fauna_density
	generator.generate_underground(bottom, level, planet)
	generator.cave_level = FALSE
	generator.level_bottom = surface_bottom
	generator.plan_taken = surface_taken
	generator.dig_anchors = surface_anchors
	generator.pack_anchors = surface_packs
	for(var/datum/biome/biome as anything in densities)
		biome.fauna_density = densities[biome]
	// Specimens resolve their site per level, so the caves carry the surface's site marker too.
	var/obj/effect/landmark/stationtrauma_research_site/cave_marker = new(locate(bottom.x, bottom.y, level.z_value))
	cave_marker.site_id = planet.id
	cave_marker.name = planet.name

/// Builds on behind the crew until the whole planet stands or the planet goes
/datum/expedition_surface/proc/build_on()
	set waitfor = FALSE
	if(building)
		return
	building = TRUE
	while(!QDELETED(src) && !QDELETED(planet))
		var/chunk = next_chunk()
		if(!chunk && caves)
			build_caves()
			continue
		chunk ||= next_rest_chunk()
		if(!chunk)
			qdel(src)
			return
		finish(chunk)
	building = FALSE

#undef SURFACE_CHUNK_LAID
#undef SURFACE_CHUNK_VEINED
#undef SURFACE_CHUNK_DONE
#undef SURFACE_LANDING_MARGIN
#undef SURFACE_PLAYER_REACH
#undef SURFACE_ALLOWANCE_URGENT
#undef SURFACE_ALLOWANCE_USUAL
#undef SURFACE_UNBUILT_WALL
