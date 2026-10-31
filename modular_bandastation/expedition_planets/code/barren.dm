// AI EDIT START - expedition planets module integration
// Barren environment profile adapted from SierraBay, AGPL-3.0; terrain generation uses local TG/rust-g.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm
// Biome selection, tables and densities adapted from CeladonSS13/Shiptest, AGPL-3.0; contents use local TG types.
// https://github.com/CeladonSS13/Shiptest/tree/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary
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
	/// Square generated surface side length in turfs.
	var/surface_width = 128
	/// Measured time spent preparing the physical surface, in seconds.
	var/generation_seconds
	/// Terrain generator type for this planetary environment profile.
	var/generator_type = /datum/map_generator/expedition_barren
	/// Crew-facing summary of the surface environment.
	var/biome = "Безжизненные равнины, базальтовые поля и рудные горы"
	/// Crew-facing gas and pressure summary from the environment profile.
	var/atmosphere = "Вакуум, 0 кПа"
	/// Ambient surface temperature in kelvin.
	var/surface_temperature = TCMB
	/// Whether the environment profile supports unprotected human breathing.
	var/breathable = FALSE
	/// Survey names of the modifiers rolled for this planet.
	var/list/modifier_names = list()
	/// Charted generator awaiting the first landing; null once the surface is built or has failed.
	var/datum/map_generator/expedition_barren/generator
	/// Set while the first descent builds the surface.
	var/generating = FALSE

/** Serialize environment observations without exposing the planet generation seed. */
/datum/stationtrauma_overmap_site/space/planet/proc/survey_data()
	return list("biome" = biome, "atmosphere" = atmosphere, "temperature" = surface_temperature, "breathable" = breathable, "modifiers" = modifier_names)

/**
 * Sierra's airless, lifeless, mineral-rich profile, using TG's seeded rust-g noise.
 *
 * Height, heat and humidity noise choose Celadon biomes: mountains above [/datum/map_generator/expedition_barren/var/mountain_height]
 * use the cave table and keep ore-bearing rock between cave pockets. Terrain follows the seed; ore veins, flora and fauna use TG's random
 * vein growth and biome population.
 */
/datum/map_generator/expedition_barren
	/// Deterministic terrain seed, between 1 and 1000000.
	var/seed
	/// Height, heat and humidity noise scale in turfs; larger values give wider biomes.
	var/biome_zoom = 65
	/// Height noise above which terrain becomes mountain rock with cave pockets. Celadon's moon uses 0.8; Sierra's barren profile stays mineral-rich.
	var/mountain_height = 0.5
	/// Surface biomes by heat band (coldest first), then humidity band (driest first).
	var/list/biome_table = list(
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar),
	)
	/// Mountain cave biomes by cave heat band, then humidity band; a single biome type fills every cave.
	var/cave_biome_table = /datum/biome/expedition/lunar
	/// Mountain rock; ore veins are grown inside it after the terrain pass.
	var/rock_type = /turf/closed/mineral
	/// Percent chance that a mountain rock tile seeds an ore vein.
	var/mineral_chance = 11
	/// Weighted ore stacks for vein seeds; each ore's own vein type and size shape the deposit.
	var/list/ore_types = list(
		/obj/item/stack/ore/diamond = 5,
		/obj/item/stack/ore/gold = 15,
		/obj/item/stack/ore/silver = 20,
		/obj/item/stack/ore/uranium = 20,
		/obj/item/stack/ore/titanium = 30,
		/obj/item/stack/ore/iron = 150,
	)
	/// Generated open turfs of each biome, populated after the camp and ruins are placed.
	var/list/biome_turfs
	/// Distance in turfs around the camp where flora still grows but hostile fauna never starts.
	var/fauna_clearance = 15
	/// Whether this profile's biomes spawn fauna that modifiers can thin out or multiply.
	var/wildlife = FALSE
	/// Fauna density multiplier from modifiers, applied to this planet's own biome copies.
	var/fauna_multiplier = 1
	/// This planet's biome copies by type, so modifier densities never reach other planets.
	var/list/biomes
	/// Z-level trait of the profile's periodic storm weather, if it has one.
	var/storm_trait
	/// Whether a modifier enabled the periodic storm weather.
	var/storms = FALSE
	/// Whether a modifier added a cave level beneath the surface.
	var/underground = FALSE
	/// Set while [/datum/map_generator/expedition_barren/proc/generate_terrain] fills the cave level instead of the surface.
	var/cave_level = FALSE
	/// Open space carrying this profile's atmosphere, used for drops into the cave level.
	var/turf/open/openspace/hole_type = /turf/open/openspace/airless/planetary
	/// Relative coordinates of surface ladders and drops; the cave level keeps a clearing beneath each.
	var/list/connector_points = list()
	/// Generated square side length in turfs.
	var/width = 128
	/// Greatest depth of the mineable cliff band inside the rim, as a fraction of half the width.
	var/edge_roughness = 0.25
	/// World X of the generated square southwest corner.
	var/origin_x
	/// World Y of the generated square southwest corner.
	var/origin_y
	/// Base camp southwest X relative to the generated square.
	var/camp_x
	/// Base camp southwest Y relative to the generated square.
	var/camp_y
	/// Reserved base camp width in turfs.
	var/camp_width
	/// Reserved base camp height in turfs.
	var/camp_height
	/// Reserved ruin rectangles excluded from terrain and flora placement.
	var/list/ruin_bounds = list()
	/// Default walkable ground type for this environment profile.
	var/turf/open/floor_type = /turf/open/misc/asteroid/airless
	/// Research source type placed on accessible surface terrain.
	var/source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_barren
	/// Optional tint applied to generated mineral terrain.
	var/rock_color
	/// Small surface feature maps with pick weights; placeholders adapt to this profile's ground and rock.
	var/list/feature_maps = list(
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater1.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater2.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater3.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater4.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater5.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater6.dmm" = 1,
	)
	/// Surface features placed on each planet when free space allows.
	var/feature_count = 6
	/// Turfs covered by placed features; flora and fauna never start on them.
	var/list/feature_turfs
	/// Work slice shared by every generation step of this surface.
	var/datum/stationtrauma_work_budget/budget

/datum/map_generator/expedition_barren/New(chosen_seed)
	. = ..()
	if(!ISINTEGER(chosen_seed) || chosen_seed < 1 || chosen_seed > 1000000)
		CRASH("Invalid expedition planet seed [chosen_seed]")
	seed = chosen_seed

/** Whether relative generator coordinates lie inside the reserved base camp. */
/datum/map_generator/expedition_barren/proc/in_camp(x, y)
	return x >= camp_x && x < camp_x + camp_width && y >= camp_y && y < camp_y + camp_height

/** Whether relative coordinates are reserved for a camp, access corridor or ruin. */
/datum/map_generator/expedition_barren/proc/is_reserved(x, y)
	if(in_camp(x, y) || abs(x - round(width / 2)) <= 1 || abs(y - round(width / 2)) <= 1)
		return TRUE
	for(var/list/bounds as anything in ruin_bounds)
		if(x >= bounds[1] - 1 && x <= bounds[3] + 1 && y >= bounds[2] - 1 && y <= bounds[4] + 1)
			return TRUE
		if(y == round((bounds[2] + bounds[4]) / 2) && x >= min(round(width / 2), bounds[1]) && x <= max(round(width / 2), bounds[3]))
			return TRUE
	return FALSE

/** Celadon biome for relative coordinates, from the surface or mountain cave table. */
/datum/map_generator/expedition_barren/proc/biome_at(x, y, mountain)
	var/static/list/heat_bands = list(0.2, 0.4, 0.6, 0.65, 0.8)
	var/static/list/cave_heat_bands = list(0.25, 0.5, 0.75)
	var/static/list/humidity_bands = list(0.2, 0.4, 0.6, 0.8)
	var/table = mountain ? cave_biome_table : biome_table
	if(!islist(table))
		return local_biome(table)
	// Seed offsets keep consecutive planet seeds from sharing noise fields.
	var/heat = text2num(rustg_noise_get_at_coordinates("[seed + 1000000]", "[x / biome_zoom]", "[y / biome_zoom]"))
	var/humidity = text2num(rustg_noise_get_at_coordinates("[seed + 2000000]", "[x / biome_zoom]", "[y / biome_zoom]"))
	var/list/row = table[noise_band(heat, mountain ? cave_heat_bands : heat_bands)]
	return local_biome(row[noise_band(humidity, humidity_bands)])

/** This planet's own biome instance, with the modifier fauna density applied once. */
/datum/map_generator/expedition_barren/proc/local_biome(biome_type)
	var/datum/biome/biome = LAZYACCESS(biomes, biome_type)
	if(!biome)
		biome = new biome_type
		biome.fauna_density *= fauna_multiplier
		LAZYSET(biomes, biome_type, biome)
	return biome

/** One-based band of a noise value among ascending inclusive upper thresholds. */
/datum/map_generator/expedition_barren/proc/noise_band(value, list/thresholds)
	var/band = 1
	for(var/threshold in thresholds)
		if(value > threshold)
			band++
	return band

/datum/map_generator/expedition_barren/generate_terrain(list/turfs, area/generate_in)
	budget ||= new
	var/list/turf/closed/mineral/rocks = list()
	for(var/turf/tile as anything in turfs)
		budget.yield()
		tile.change_area(get_area(tile), generate_in)
		var/x = tile.x - origin_x + 1
		var/y = tile.y - origin_y + 1
		var/datum/biome/biome
		var/terrain = floor_type
		// The opaque rim bounds this surface within its otherwise empty z-level.
		if(x <= 2 || y <= 2 || x > width - 2 || y > width - 2)
			terrain = /turf/closed/indestructible/rock
		// The reservation and open cross keep landing, the laboratory and the field connected.
		else if(cave_level ? !in_clearing(x, y) : !is_reserved(x, y))
			// The cave level is one mountain; its own pocket noise keeps it from mirroring surface caves.
			var/mountain = cave_level || text2num(rustg_noise_get_at_coordinates("[seed]", "[x / biome_zoom]", "[y / biome_zoom]")) > mountain_height
			biome = biome_at(x, y, mountain)
			terrain = biome.open_turf_type
			// Noisy cliffs inside the rim replace its straight edge; the camp, ruins and cross stay reserved.
			var/edge = max(abs(x - width / 2), abs(y - width / 2)) / (width / 2) + text2num(rustg_noise_get_at_coordinates("[seed + 4000000]", "[x / 16]", "[y / 16]")) * edge_roughness
			// Rock between cave pockets keeps the mountain mineable.
			if(edge > 1 || (mountain && text2num(rustg_noise_get_at_coordinates("[seed + (cave_level ? 6000000 : 3000000)]", "[x / 8]", "[y / 8]")) > 0.5))
				terrain = rock_type
		// Clearings under ladders and drops are cave floor kept free of flora and fauna.
		else if(cave_level)
			var/datum/biome/clearing_biome = biome_at(x, y, TRUE)
			terrain = clearing_biome.open_turf_type
		var/turf/generated = tile.ChangeTurf(terrain, floor_type, CHANGETURF_IGNORE_AIR)
		if(ismineralturf(generated))
			prepare_rock(generated)
			rocks += generated
		else if(biome)
			LAZYADDASSOCLIST(biome_turfs, biome, generated)
	// Veins spread into neighbouring rock, so they start only once the whole mountain exists.
	// The deeper cave level seeds half again as many veins.
	var/vein_chance = cave_level ? mineral_chance * 1.5 : mineral_chance
	// The typed loop skips tiles changed while the budget slept.
	for(var/turf/closed/mineral/rock in rocks)
		budget.yield()
		if(rock.mineral_type || !prob(vein_chance))
			continue
		var/obj/item/stack/ore/ore_type = pick_weight(ore_types)
		rock.change_ore(ore_type)
		if(prob(ore_type::spread_chance))
			rock.spread_vein(ore_type)

/** Native rock must expose this planet's ground, atmosphere and tint when mined. */
/datum/map_generator/expedition_barren/proc/prepare_rock(turf/closed/mineral/rock)
	rock.turf_type = floor_type
	rock.initial_gas_mix = initial(floor_type.initial_gas_mix)
	if(rock_color)
		rock.color = rock_color

/** Swap template placeholder ground and rock for this profile's types and move carrier tiles into the planet surface area. */
/datum/map_generator/expedition_barren/proc/adapt_template_turfs(list/turfs, area/surface)
	for(var/turf/tile as anything in turfs)
		var/area/tile_area = tile.loc
		if(tile_area.type == /area/expedition_planet/barren && tile_area != surface)
			tile.change_area(tile_area, surface)
		if(tile.type == /turf/open/misc/asteroid/airless && floor_type != tile.type)
			tile.ChangeTurf(floor_type, floor_type, CHANGETURF_IGNORE_AIR)
		else if(tile.type == /turf/closed/mineral)
			prepare_rock(rock_type == tile.type ? tile : tile.ChangeTurf(rock_type, floor_type, CHANGETURF_IGNORE_AIR))

/**
 * Whether a feature fits at relative coordinates: clear of reserved terrain, the camp's fauna clearance
 * and earlier features, and mostly open so it does not vanish inside a mountain.
 */
/datum/map_generator/expedition_barren/proc/feature_fits(x, y, datum/map_template/template, list/placed, z)
	var/right = x + template.width - 1
	var/top = y + template.height - 1
	// Features may carry hostile fauna, so they stay outside the camp's fauna clearance.
	if(x < camp_x + camp_width + fauna_clearance && y < camp_y + camp_height + fauna_clearance)
		return FALSE
	for(var/list/bounds as anything in placed)
		if(x <= bounds[3] + 1 && right >= bounds[1] - 1 && y <= bounds[4] + 1 && top >= bounds[2] - 1)
			return FALSE
	var/open = 0
	for(var/tile_x in x to right)
		for(var/tile_y in y to top)
			if(is_reserved(tile_x, tile_y))
				return FALSE
			if(isopenturf(locate(origin_x + tile_x - 1, origin_y + tile_y - 1, z)))
				open++
	return open * 4 >= template.width * template.height * 3

/** Load this profile's small surface features at random free spots after the camp and ruins; returns how many were placed. */
/datum/map_generator/expedition_barren/proc/place_features(turf/bottom, area/surface)
	var/static/list/templates = list()
	var/list/placed = list()
	for(var/attempt in 1 to feature_count * 5)
		if(length(placed) >= feature_count)
			break
		var/map = pick_weight(feature_maps)
		var/datum/map_template/template = templates[map]
		if(!template)
			template = new(map)
			templates[map] = template
		var/x = rand(4, width - 3 - template.width)
		var/y = rand(4, width - 3 - template.height)
		if(!feature_fits(x, y, template, placed, bottom.z))
			continue
		var/turf/origin = locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z)
		if(!template.load(origin))
			continue
		var/list/covered = template.get_affected_turfs(origin)
		adapt_template_turfs(covered, surface)
		for(var/turf/tile as anything in covered)
			LAZYSET(feature_turfs, tile, TRUE)
		placed += list(list(x, y, x + template.width - 1, y + template.height - 1))
		budget?.yield()
	return length(placed)

/** Whether relative cave-level coordinates lie in the clearing beneath a surface ladder or drop. */
/datum/map_generator/expedition_barren/proc/in_clearing(x, y)
	for(var/list/point as anything in connector_points)
		if(abs(x - point[1]) <= 2 && abs(y - point[2]) <= 2)
			return TRUE
	return FALSE

/**
 * Fill the cave level beneath a finished surface and link the two with ladders and drops.
 *
 * Connectors sit on free open surface ground, apart from each other, the reservation and features.
 * Unbreakable ladders guarantee a way back up; drops are one-way open space into a cave clearing.
 * Returns the number of connectors.
 */
/datum/map_generator/expedition_barren/proc/generate_underground(turf/surface_bottom, datum/space_level/caves, area/surface, planet_name)
	var/ladders = 3
	var/drops = 2
	for(var/attempt in 1 to 200)
		if(length(connector_points) >= ladders + drops)
			break
		var/x = rand(8, width - 8)
		var/y = rand(8, width - 8)
		var/turf/tile = locate(origin_x + x - 1, origin_y + y - 1, surface_bottom.z)
		if(!isopenturf(tile) || tile.loc != surface || is_reserved(x, y) || LAZYACCESS(feature_turfs, tile) || tile.is_blocked_turf(TRUE))
			continue
		var/near = FALSE
		for(var/list/point as anything in connector_points)
			if(max(abs(x - point[1]), abs(y - point[2])) < 16)
				near = TRUE
				break
		if(!near)
			connector_points += list(list(x, y))
	if(length(connector_points) <= drops)
		return 0
	var/turf/bottom = locate(surface_bottom.x, surface_bottom.y, caves.z_value)
	var/area/expedition_planet/barren/caves_area = new
	caves_area.name = "[planet_name]: пещеры"
	cave_level = TRUE
	generate_terrain(block(bottom, locate(bottom.x + width - 1, bottom.y + width - 1, bottom.z)), caves_area)
	populate_biomes()
	for(var/index in 1 to length(connector_points))
		var/list/point = connector_points[index]
		var/turf/upper = locate(origin_x + point[1] - 1, origin_y + point[2] - 1, surface_bottom.z)
		if(index <= length(connector_points) - drops)
			var/obj/structure/ladder/unbreakable/lower_ladder = new(locate(upper.x, upper.y, caves.z_value))
			new /obj/structure/ladder/unbreakable(upper, null, lower_ladder)
		else
			upper.ChangeTurf(hole_type, hole_type, CHANGETURF_IGNORE_AIR)
	SSmapping.reg_in_areas_in_z(list(caves_area))
	smooth_zlevel(caves.z_value)
	return length(connector_points)

/** Populate the generated biomes; fauna never starts near the camp or on placed features. */
/datum/map_generator/expedition_barren/proc/populate_biomes()
	for(var/datum/biome/biome as anything in biome_turfs)
		var/list/near_camp = list()
		var/list/wild = list()
		for(var/turf/tile as anything in biome_turfs[biome])
			if(LAZYACCESS(feature_turfs, tile))
				continue
			var/x = tile.x - origin_x + 1
			var/y = tile.y - origin_y + 1
			if(x >= camp_x - fauna_clearance && x < camp_x + camp_width + fauna_clearance && y >= camp_y - fauna_clearance && y < camp_y + camp_height + fauna_clearance)
				near_camp += tile
			else
				wild += tile
		biome.populate_turfs(near_camp, flora_allowed = TRUE, features_allowed = TRUE, fauna_allowed = FALSE)
		biome.populate_turfs(wild, flora_allowed = TRUE, features_allowed = TRUE, fauna_allowed = TRUE)
	biome_turfs = null

/datum/map_generator/expedition_barren/populate_terrain(list/turfs, area/generate_in)
	populate_biomes()
	var/sources = 0
	var/turf/origin = turfs[1]
	var/offset = 8 + seed % 6
	var/middle = round(width / 2)
	for(var/list/position as anything in list(list(offset, middle), list(middle, offset), list(width - offset, middle)))
		var/turf/tile = locate(origin_x + position[1] - 1, origin_y + position[2] - 1, origin.z)
		if(!istype(tile, floor_type) || get_area(tile) != generate_in)
			continue
		new source_type(tile)
		sources++
	return sources

/** Celadon planetary biome; its open turf must carry the atmosphere of every planet that uses it. */
/datum/biome/expedition

/** Celadon lunar plains: bare airless regolith. */
/datum/biome/expedition/lunar
	open_turf_type = /turf/open/misc/asteroid/airless

/** Celadon coarse lunar ground: airless basalt fields. */
/datum/biome/expedition/lunar/rocky
	open_turf_type = /turf/open/misc/asteroid/basalt/airless

/** Finite research source: кристаллический нарост экзопланеты, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_barren
	name = "кристаллический нарост экзопланеты"
	desc = "Минеральные включения на безвоздушной поверхности. Их можно обследовать и отобрать пробы."
	field_notes = "В трещинах породы видны неоднородные кристаллические включения с острыми гранями. Следов растительности нет."
	laboratory_notes = "Включения образуют несколько минеральных фракций. Состав и возможное применение требуют дальнейших испытаний."

/** Mapped surface camp supplies kept across repeat visits. */
/obj/structure/closet/crate/expedition_planet_supplies
	name = "ящик полевого исследователя"

/obj/structure/closet/crate/expedition_planet_supplies/PopulateContents()
	..()
	new /obj/item/stationtrauma_field_scanner(src)
	new /obj/item/pickaxe(src)
	new /obj/item/flashlight(src)
	for(var/index in 1 to 6)
		new /obj/item/stationtrauma_sample(src)

/**
 * Chart a planet without building it; the first landing generates its surface.
 *
 * Modifiers are rolled here so orbital surveys report them before anyone lands.
 * `modifier_level` sets the planet modifier budgets; sectors derive it from the distance to their arrival point.
 */
/proc/create_stationtrauma_planet(seed = rand(1, 1000000), planet_id = "moon", planet_name = "Каменистая экзопланета", planet_type = /datum/stationtrauma_overmap_site/space/planet, modifier_level = 1)
	if(!ispath(planet_type, /datum/stationtrauma_overmap_site/space/planet))
		CRASH("Invalid expedition planet profile [planet_type]")
	var/datum/stationtrauma_overmap_site/space/planet/site = new planet_type
	site.id = planet_id
	site.name = planet_name
	site.seed = seed
	site.generator = new site.generator_type(seed)
	site.surface_width = site.generator.width
	site.modifier_names = site.generator.apply_modifiers(modifier_level)
	return site

/datum/stationtrauma_overmap_site/space/planet/awaits_surface()
	return !!generator

/**
 * Build the surface once beside live gameplay; subsequent landings only move the vessel onto the retained native berth.
 *
 * Descents wait on [/datum/stationtrauma_overmap_site/space/planet/var/generating]. A crash inside the build only aborts that call,
 * so the planet is still released as failed instead of waiting for another attempt. No try block here: it would turn any
 * runtime from a single generated atom's Initialize into a failed planet.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/generate_surface()
	if(!generator || generating)
		return
	generating = TRUE
	failed = !build_surface()
	QDEL_NULL(generator)
	generating = FALSE

/** Generate every level of the surface, yielding between work slices; returns whether the planet is ready for landing. */
/datum/stationtrauma_overmap_site/space/planet/proc/build_surface()
	var/start_time = REALTIMEOFDAY
	var/datum/stationtrauma_work_budget/budget = new
	// Landings generate beside live gameplay; a quarter of each tick builds the surface within the descent.
	budget.allowance = 25
	generator.budget = budget
	var/datum/map_template/camp = new('modular_bandastation/space_overmap/maps/moon.dmm', "Посадочная площадка экспедиции")
	if(camp.width + 8 > generator.width || camp.height + 8 > generator.width)
		CRASH("Expedition camp does not fit the reserved planetary surface")
	var/list/traits = ZTRAITS_AWAY
	if(generator.storms)
		traits[generator.storm_trait] = TRUE
	var/datum/space_level/caves
	// Multi-z links adjacent z values, so the cave level is created immediately below the surface.
	if(generator.underground)
		caves = SSmapping.add_new_zlevel("[name]: пещеры", ZTRAITS_AWAY + list(ZTRAIT_UP = TRUE))
		traits[ZTRAIT_DOWN] = TRUE
	var/datum/space_level/level = SSmapping.add_new_zlevel(name, traits)
	generator.origin_x = round((world.maxx - generator.width) / 2) + 1
	generator.origin_y = round((world.maxy - generator.width) / 2) + 1
	generator.camp_x = 5
	generator.camp_y = 5
	generator.camp_width = camp.width
	generator.camp_height = camp.height
	var/list/ruins = prepare_ruins(generator)
	if(!ruins)
		qdel(camp)
		return FALSE
	var/turf/bottom = locate(generator.origin_x, generator.origin_y, level.z_value)
	var/list/turfs = block(bottom, locate(bottom.x + generator.width - 1, bottom.y + generator.width - 1, bottom.z))
	var/area/expedition_planet/barren/surface = new
	surface.name = "[name]: поверхность"
	// Storms only reach outdoor areas; the camp, ruins and landed vessels keep their own sheltered areas.
	surface.outdoors = generator.storms
	generator.generate_terrain(turfs, surface)
	budget.yield()
	var/turf/camp_origin = locate(bottom.x + generator.camp_x - 1, bottom.y + generator.camp_y - 1, bottom.z)
	if(!camp.load(camp_origin))
		qdel(camp)
		return FALSE
	// The shared landing clearing follows the planet's ground and atmosphere.
	generator.adapt_template_turfs(camp.get_affected_turfs(camp_origin), surface)
	budget.yield()
	if(!load_ruins(ruins, bottom, budget))
		qdel(camp)
		return FALSE
	var/features = generator.place_features(bottom, surface)
	for(var/obj/docking_port/stationary/stationtrauma_space_surface/pad in SSshuttle.stationary_docking_ports)
		if(pad.z == level.z_value)
			berth = pad
			pad.name = "Посадочная площадка экспедиции"
			break
	if(!berth || generator.populate_terrain(turfs, surface) != 3)
		CRASH("Expedition planet [seed] lacks its landing berth or research sources")
	// Field equipment waits beside the vessel footprint, where landing never needs to trample it.
	var/list/pad_bounds = berth.return_coords()
	var/turf/supplies_turf = locate(min(pad_bounds[1], pad_bounds[3]) - 2, berth.y, berth.z)
	if(!isopenturf(supplies_turf) || supplies_turf.is_blocked_turf(TRUE))
		CRASH("Expedition planet [seed] has no free ground beside its landing berth for field equipment")
	new /obj/structure/closet/crate/expedition_planet_supplies(supplies_turf)
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(supplies_turf)
	marker.site_id = id
	marker.name = name
	budget.yield()
	if(caves && !generator.generate_underground(bottom, caves, surface, name))
		CRASH("Expedition planet [seed] has no free surface for cave connectors")
	SSmapping.reg_in_areas_in_z(list(surface))
	smooth_zlevel(level.z_value)
	// Storm traits are registered only once the surface is complete; SSweather then alternates storms with calm periods.
	SSweather.update_z_level(level)
	generation_seconds = ((REALTIMEOFDAY - start_time + MIDNIGHT_ROLLOVER) % MIDNIGHT_ROLLOVER) / 10
	log_mapping("Expedition planet ready: seed [seed], [generator.width]x[generator.width], z [level.z_value], [generation_seconds]s, features: [features], modifiers: [jointext(modifier_names, ", ")]")
	qdel(camp)
	return TRUE
// AI EDIT END
