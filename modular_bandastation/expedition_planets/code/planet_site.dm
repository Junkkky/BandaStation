// Barren environment profile adapted from SierraBay, AGPL-3.0; terrain generation uses local TG/rust-g.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm
/** Shared planetary surface area with native gravity and locally generated terrain. */
/area/expedition_planet/barren
	name = "Каменистая поверхность экзопланеты"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags_mapping = UNIQUE_AREA
	ambientsounds = list(null)

/** Generated surface destination with a persistent landing berth and environmental survey. */
/datum/stationtrauma_overmap_site/space/planet
	name = "Каменистая экзопланета"
	landing = TRUE
	needs_scan = FALSE
	discovered = TRUE
	/// Retained for admin diagnostics; navigation never publishes the generation seed.
	var/seed
	/// Modifier budget/difficulty used when charting, retained after the generator is released.
	var/modifier_level = 1
	/// Square generated surface side length in turfs.
	var/surface_width = 128
	/// Measured time spent preparing the physical surface, in seconds.
	var/generation_seconds
	/// Terrain generator type for this planetary environment profile.
	var/generator_type = /datum/map_generator/expedition_barren
	/// Native-size orbital artwork for this environment profile.
	var/parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet
	/// Crew-facing summary of the surface environment.
	var/biome = "Безжизненные равнины, базальтовые поля и рудные горы"
	/// Crew-facing gas and pressure summary, rolled when charted.
	var/atmosphere = "Вакуум, 0 кПа"
	/// Ambient surface temperature in kelvin, set by the environment profile.
	var/surface_temperature = TCMB
	/// Whether the profile has an atmosphere at all; which gases it holds is rolled per planet, not fixed by the profile.
	var/has_atmosphere = FALSE
	/// Whether the rolled atmosphere supports unprotected human breathing.
	var/breathable = FALSE
	/// Gas string every natural turf of this planet's levels breathes, whatever its own type defines.
	var/gas_mix = AIRLESS_ATMOS
	/// Survey lines of the modifiers rolled for this planet.
	var/list/modifier_names = list()
	/// Names of the modifiers rolled for this planet, for admin logs.
	var/list/modifier_log = list()
	/// Charted generator awaiting the first landing; null once the surface is built or has failed.
	var/datum/map_generator/expedition_barren/generator
	/// Survey lines on the caves and the ore, read off the generator when charted
	var/cave_survey = "Не обнаружены"
	var/ore_survey = "Низкая"
	/// The survey's schematic of the built surface; see survey_schematic()
	var/list/survey_map

/** Serialize environment observations without exposing the planet generation seed. */
/datum/stationtrauma_overmap_site/space/planet/proc/survey_data()
	return list("biome" = biome, "atmosphere" = atmosphere, "temperature" = surface_temperature, "breathable" = breathable, "modifiers" = modifier_names, "caves" = cave_survey, "ore" = ore_survey)

/// The look of this planet on the consoles' displays
/datum/stationtrauma_overmap_site/space/planet/proc/glyph_kind()
	switch(parallax_layer)
		if(/atom/movable/screen/parallax_layer/expedition_planet/lava)
			return "lava"
		if(/atom/movable/screen/parallax_layer/expedition_planet/arid)
			return "arid"
		if(/atom/movable/screen/parallax_layer/expedition_planet/frozen)
			return "frozen"
		if(/atom/movable/screen/parallax_layer/expedition_planet/lush)
			return "lush"
	return "barren"

/// Reads the caves and the ore off the charted generator, for the survey to report before the surface exists
/datum/stationtrauma_overmap_site/space/planet/proc/read_survey_facts()
	var/list/systems = list()
	if(generator.underground)
		systems += "глубинный пещерный ярус"
	if(!isnull(generator.surface_open_percent))
		systems += "туннели по всей поверхности"
	else if(generator.mountain_height < 1)
		systems += "полости в горных массивах"
	if(length(systems))
		cave_survey = capitalize(jointext(systems, ", "))
	ore_survey = generator.mineral_chance >= 12 ? "Высокая" : generator.mineral_chance >= 7 ? "Средняя" : "Низкая"

/**
 * Chart a planet without building it; the first landing generates its surface.
 *
 * Modifiers are rolled here so orbital surveys report them before anyone lands.
 * `modifier_level` sets the planet modifier budgets; sectors derive it from the distance to their arrival point.
 * Optional selected_modifiers selects exact compatible traits for admin generation; null preserves random rolls.
 * Optional required_modifiers are applied on top of the random rolls, outside the budget, wherever the profile allows them.
 */
/proc/create_stationtrauma_planet(seed = rand(1, 1000000), planet_id = "moon", planet_name = "Каменистая экзопланета", planet_type = /datum/stationtrauma_overmap_site/space/planet, modifier_level = 1, list/selected_modifiers = null, list/required_modifiers = null)
	if(!ispath(planet_type, /datum/stationtrauma_overmap_site/space/planet))
		CRASH("Invalid expedition planet profile [planet_type]")
	var/datum/stationtrauma_overmap_site/space/planet/site = new planet_type
	site.id = planet_id
	site.name = planet_name
	site.seed = seed
	site.modifier_level = modifier_level
	site.roll_atmosphere()
	site.generator = new site.generator_type(seed)
	// A large town or complex widens the surface around it; the template itself is chosen when the surface is built.
	if(prob(site.generator.large_ruin_chance))
		site.generator.width = site.generator.large_surface_width
		site.generator.large_slot = TRUE
	site.surface_width = site.generator.width
	site.modifier_names = site.generator.apply_modifiers(modifier_level, selected_modifiers, required_modifiers)
	if(isnull(site.modifier_names))
		QDEL_NULL(site.generator)
		qdel(site)
		return null
	site.modifier_log = site.generator.modifier_log.Copy()
	site.read_survey_facts()
	return site

/**
 * Pick this planet's air from its seed: oxygen is as likely on a frozen or arid world as on a lush one.
 * The profile only says whether there is an atmosphere and how hot it is.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/roll_atmosphere()
	if(!has_atmosphere)
		return
	// Gases with moles per tile, survey name and breathability; the first is the oxygen one, rolled for half of the planets.
	var/static/list/compositions = list(
		list(list(GAS_O2 = 22, GAS_N2 = 82), "Кислород и азот", TRUE),
		list(list(GAS_N2 = 82, GAS_CO2 = 22), "Азот и углекислый газ; кислорода нет", FALSE),
		list(list(GAS_CO2 = 60, GAS_N2 = 30), "Углекислый газ и азот; кислорода нет", FALSE),
	)
	var/list/composition = compositions[seed % 2 ? 1 : 2 + round(seed / 2) % 2]
	var/list/gases = composition[1]
	var/list/parts = list()
	var/moles = 0
	for(var/gas in gases)
		parts += "[gas]=[gases[gas]]"
		moles += gases[gas]
	gas_mix = "[jointext(parts, ";")];TEMP=[surface_temperature]"
	breathable = composition[3]
	atmosphere = "[composition[2]], [round(moles * R_IDEAL_GAS_EQUATION * surface_temperature / CELL_VOLUME)] кПа"

/datum/stationtrauma_overmap_site/space/planet/awaits_map()
	return !!generator

/** Build the surface once; subsequent landings only move the vessel onto the retained native berth. */
/datum/stationtrauma_overmap_site/space/planet/load_map()
	if(!generator || loading_map)
		return
	loading_map = TRUE
	failed = !build_surface()
	QDEL_NULL(generator)
	loading_map = FALSE
	if(!failed)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_SITE_LOADED, src)

/** Generate every level of the surface, yielding between work slices; returns whether the planet is ready for landing. */
/datum/stationtrauma_overmap_site/space/planet/proc/build_surface()
	var/start_time = REALTIMEOFDAY
	var/datum/stationtrauma_work_budget/budget = new
	// Landings generate beside live gameplay; a quarter of each tick builds the surface within the descent.
	budget.allowance = 25
	generator.budget = budget
	// The plan fits every allowed hull before reserving an actual z-level.
	var/list/dims = landing_dims()
	var/hull_width = dims[1]
	var/hull_height = dims[2]
	if(!generator.plan_surface(hull_width, hull_height, length(pads)))
		return FALSE
	var/list/ruins = prepare_ruins(generator)
	if(!ruins)
		return FALSE
	if(generator.underground)
		generator.reserve_cave_connectors()
	// Whatever is stripped down to the bottom (ruin plating, scraped ground) shows this planet's ground, not space.
	var/list/traits = ZTRAITS_AWAY + list(ZTRAIT_BASETURF = generator.floor_type)
	// The storm trait also drives weather sounds, so the endless storm keeps it.
	if(generator.storms || generator.endless_storm)
		traits[generator.storm_trait] = TRUE
	var/datum/space_level/caves
	// Multi-z links adjacent z values, so the cave level is created immediately below the surface.
	if(length(generator.connector_points))
		caves = SSmapping.add_new_zlevel("[name]: пещеры", ZTRAITS_AWAY + list(ZTRAIT_UP = TRUE, ZTRAIT_BASETURF = generator.floor_type))
		traits[ZTRAIT_DOWN] = TRUE
	var/datum/space_level/level = SSmapping.add_new_zlevel(name, traits)
	stationtrauma_planet_level_air(level.z_value, gas_mix)
	if(caves)
		stationtrauma_planet_level_air(caves.z_value, gas_mix)
	generator.origin_x = round((world.maxx - generator.width) / 2) + 1
	generator.origin_y = round((world.maxy - generator.width) / 2) + 1
	var/turf/bottom = locate(generator.origin_x, generator.origin_y, level.z_value)
	var/list/turfs = block(bottom, locate(bottom.x + generator.width - 1, bottom.y + generator.width - 1, bottom.z))
	var/area/expedition_planet/barren/surface = new
	surface.name = "[name]: поверхность"
	// Storms only reach outdoor areas, the landing clearing included; ruins and landed vessels keep their own sheltered areas.
	surface.outdoors = generator.storms || generator.endless_storm
	// Only the open surface is lit; ruins, landed vessels and the cave level keep their own areas and lighting.
	if(generator.light_alpha)
		surface.set_base_lighting(generator.sky_color, generator.light_alpha)
	generator.generate_terrain(turfs, surface)
	var/list/ports = list()
	for(var/list/rect as anything in generator.landing_pads)
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/planet_pad/pad = new(locate(bottom.x + rect[1] - 1, bottom.y + rect[2] - 1, bottom.z))
		pad.width = hull_width
		pad.height = hull_height
		if(length(ports))
			pad.name = "Посадочная площадка экспедиции [length(ports) + 1]"
		ports += pad
	berth = ports[1]
	for(var/index in 1 to length(pads))
		var/datum/stationtrauma_overmap_site/space/pad_site = pads[index]
		if(index < length(ports))
			pad_site.berth = ports[index + 1]
		else
			pad_site.failed = TRUE
	budget.yield()
	if(!load_ruins(ruins, bottom, surface, budget))
		return FALSE
	generator.build_hive(bottom, surface)
	var/features = generator.place_features(bottom, surface)
	generator.place_nests(bottom)
	generator.place_megafauna(bottom)
	generator.place_craters(bottom)
	generator.populate_terrain(turfs, surface)
	generator.place_ruin_patrols(ruins, bottom, surface)
	generator.place_dig_sites(turfs, surface, src, budget)
	generator.place_anomaly_fields(turfs, surface, src, budget)
	generator.place_planetary_anomalies(turfs, surface, src, budget)
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(berth))
	marker.site_id = id
	marker.name = name
	budget.yield()
	if(caves)
		generator.generate_underground(bottom, caves, src)
		// Specimens resolve their site per level, so the caves carry the surface's site marker too.
		var/obj/effect/landmark/stationtrauma_research_site/cave_marker = new(locate(bottom.x, bottom.y, caves.z_value))
		cave_marker.site_id = id
		cave_marker.name = name
	SSmapping.reg_in_areas_in_z(list(surface))
	smooth_zlevel(level.z_value)
	survey_map = survey_schematic(bottom, ruins, budget)
	// Storm traits are registered only once the surface is complete; SSweather then alternates storms with calm periods.
	// The endless storm starts once and is never scheduled, so periodic storms never stack on top of it.
	if(generator.endless_storm)
		SSweather.run_weather(generator.endless_storm_type, level.z_value)
	else
		SSweather.update_z_level(level)
	generation_seconds = ((REALTIMEOFDAY - start_time + MIDNIGHT_ROLLOVER) % MIDNIGHT_ROLLOVER) / 10
	log_mapping("Expedition planet ready: seed [seed], [generator.width]x[generator.width], z [level.z_value], [generation_seconds]s, features: [features], modifiers: [jointext(modifier_log, ", ")]")
	return TRUE

/// Most cells a side of the survey schematic has: finer is more to send and nothing more to see
#define SURVEY_SCHEMATIC_CELLS 80
/// Side of the squares life is counted in, in tiles, and how many creatures or dens make one show
#define SURVEY_LIFE_CELL 16
#define SURVEY_LIFE_COUNT 2
/// How near a pad a ruin or a cave entrance has to lie to be named in the pad's label, in tiles
#define SURVEY_PAD_NEAR_RUIN 30
#define SURVEY_PAD_NEAR_CAVE 25

/**
 * The survey's schematic of the built surface. Places are shares of the generated square from its south-west corner (0-1).
 * * rows - terrain codes, north row first: "#" rock, "." ground, "~" lava, water, chasms and drops, " " nothing
 * * pads - each list(west, south, east, north, near a ruin, near a cave entrance), in the order of the planet's berths
 * * caves - cave entrances, each list(x, y)
 * * structures - ruins, each list(west, south, east, north)
 * * organic - where creatures and their dens gather, each list(x, y, radius)
 */
/datum/stationtrauma_overmap_site/space/planet/proc/survey_schematic(turf/bottom, list/ruins, datum/stationtrauma_work_budget/budget)
	var/side = generator.width
	var/grain = CEILING(side / SURVEY_SCHEMATIC_CELLS, 1)
	var/cells = CEILING(side / grain, 1)
	var/list/rows = list()
	for(var/cell_y = cells, cell_y >= 1, cell_y--)
		var/list/row = list()
		for(var/cell_x in 1 to cells)
			var/list/counts = list()
			for(var/y in (cell_y - 1) * grain + 1 to min(side, cell_y * grain))
				for(var/x in (cell_x - 1) * grain + 1 to min(side, cell_x * grain))
					var/code = survey_terrain_code(locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z))
					counts[code] = (counts[code] || 0) + 1
			var/best = " "
			for(var/code in counts)
				if(counts[code] > (counts[best] || 0))
					best = code
			row += best
		rows += row.Join("")
		budget.yield()
	var/list/structures = list()
	var/list/ruin_centres = list()
	for(var/list/placement as anything in ruins)
		var/datum/map_template/template = placement[1]
		structures += list(list((placement[2] - 1) / side, (placement[3] - 1) / side, (placement[2] - 1 + template.width) / side, (placement[3] - 1 + template.height) / side))
		ruin_centres += list(list(placement[2] + template.width / 2, placement[3] + template.height / 2))
	var/list/caves = list()
	for(var/list/point as anything in generator.connector_points)
		caves += list(list((point[1] - 0.5) / side, (point[2] - 0.5) / side))
	var/list/pads = list()
	for(var/list/rect as anything in generator.landing_pads)
		var/middle_x = (rect[1] + rect[3]) / 2
		var/middle_y = (rect[2] + rect[4]) / 2
		var/near_ruin = FALSE
		for(var/list/centre as anything in ruin_centres)
			if(max(abs(centre[1] - middle_x), abs(centre[2] - middle_y)) <= SURVEY_PAD_NEAR_RUIN)
				near_ruin = TRUE
				break
		var/near_cave = FALSE
		for(var/list/point as anything in generator.connector_points)
			if(max(abs(point[1] - middle_x), abs(point[2] - middle_y)) <= SURVEY_PAD_NEAR_CAVE)
				near_cave = TRUE
				break
		pads += list(list((rect[1] - 1) / side, (rect[2] - 1) / side, rect[3] / side, rect[4] / side, near_ruin, near_cave))
	// creatures and dens by square of the surface
	var/squares = CEILING(side / SURVEY_LIFE_CELL, 1)
	var/list/life = new /list(squares * squares)
	for(var/y in 1 to side)
		for(var/x in 1 to side)
			var/turf/tile = locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z)
			for(var/atom/movable/thing as anything in tile)
				var/mob/living/creature = thing
				if(istype(creature) ? !!creature.client : !istype(thing, /obj/structure/spawner))
					continue
				var/square = round((y - 1) / SURVEY_LIFE_CELL) * squares + round((x - 1) / SURVEY_LIFE_CELL) + 1
				life[square] = (life[square] || 0) + 1
		budget.yield()
	var/list/organic = list()
	for(var/square in 1 to length(life))
		if(life[square] < SURVEY_LIFE_COUNT)
			continue
		var/square_x = (square - 1) % squares
		var/square_y = round((square - 1) / squares)
		organic += list(list((square_x + 0.5) * SURVEY_LIFE_CELL / side, (square_y + 0.5) * SURVEY_LIFE_CELL / side, SURVEY_LIFE_CELL * 0.75 / side))
	return list("rows" = rows, "pads" = pads, "caves" = caves, "structures" = structures, "organic" = organic)

/// The schematic's code for [tile]; see survey_schematic()
/proc/survey_terrain_code(turf/tile)
	if(!tile || isspaceturf(tile) || istype(tile, /turf/cordon))
		return " "
	if(isclosedturf(tile))
		return "#"
	if(islava(tile) || istype(tile, /turf/open/water) || istype(tile, /turf/open/chasm) || istype(tile, /turf/open/openspace))
		return "~"
	return "."

#undef SURVEY_SCHEMATIC_CELLS
#undef SURVEY_LIFE_CELL
#undef SURVEY_LIFE_COUNT
#undef SURVEY_PAD_NEAR_RUIN
#undef SURVEY_PAD_NEAR_CAVE

/**
 * Fits an M hull even if the planet is generated before that ship is commissioned.
 * The result is the longest short side and longest long side of the allowed hulls.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/landing_dims()
	var/short_side = ST_STANDARD_M_WIDTH
	var/long_side = ST_STANDARD_M_HEIGHT
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			if(!istype(navigation) || QDELETED(navigation.vessel) || !navigation.vessel.permits_docking(src))
				continue
			var/obj/docking_port/mobile/stationtrauma_space/vessel = navigation.vessel
			short_side = max(short_side, min(vessel.width, vessel.height))
			long_side = max(long_side, max(vessel.width, vessel.height))
	return list(short_side, long_side)

/// Gas string of each expedition planet level, by z; null elsewhere.
GLOBAL_LIST_EMPTY(stationtrauma_planet_air)

/** Mark a level as part of an expedition planet breathing `gas_mix`. */
/proc/stationtrauma_planet_level_air(z, gas_mix)
	if(length(GLOB.stationtrauma_planet_air) < z)
		GLOB.stationtrauma_planet_air.len = z
	GLOB.stationtrauma_planet_air[z] = gas_mix

/** The gas string of the expedition planet level `z` lies on, or null. */
/proc/stationtrauma_planet_air(z)
	return z && z <= length(GLOB.stationtrauma_planet_air) ? GLOB.stationtrauma_planet_air[z] : null

// Natural ground breathes the planet's own air, whatever its type brought from elsewhere: snow from a feature map
// on a warm world must not be an endless cold source, and digging or blasting keeps the planet's air.
// Built floors keep their own air, so sealed ruin rooms stay as they were mapped.
/turf/open/Initialize(mapload)
	if(planetary_atmos || istype(src, /turf/open/misc))
		var/planet_air = stationtrauma_planet_air(z)
		if(planet_air)
			initial_gas_mix = planet_air
			planetary_atmos = TRUE
	return ..()

// Everything living on a planet is at home in its air and climate, ruin garrisons and nest spawn included.
/mob/living/basic/apply_atmos_requirements(mapload)
	var/turf/here = get_turf(src)
	if(here && stationtrauma_planet_air(here.z))
		return
	return ..()

/mob/living/basic/apply_temperature_requirements(mapload)
	var/turf/here = get_turf(src)
	if(here && stationtrauma_planet_air(here.z))
		return
	return ..()
