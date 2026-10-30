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

/** Serialize environment observations without exposing the planet generation seed. */
/datum/stationtrauma_overmap_site/space/planet/proc/survey_data()
	return list("biome" = biome, "atmosphere" = atmosphere, "temperature" = surface_temperature, "breathable" = breathable)

/**
 * Sierra's airless, lifeless, mineral-rich profile, using TG's seeded rust-g noise.
 *
 * Height, heat and humidity noise choose Celadon biomes: mountains above [/datum/map_generator/expedition_barren/var/mountain_height]
 * use the cave table and keep ore-bearing rock between cave pockets. Terrain follows the seed; flora and fauna use TG biome population.
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
	/// Rock left where a mountain tile carries no ore.
	var/rock_type = /turf/closed/mineral
	/// Ore wall types with cumulative per-mille upper bounds, checked in order.
	var/list/ore_types = list(
		/turf/closed/mineral/diamond = 5,
		/turf/closed/mineral/gold = 20,
		/turf/closed/mineral/silver = 40,
		/turf/closed/mineral/uranium = 60,
		/turf/closed/mineral/titanium = 90,
		/turf/closed/mineral/iron = 240,
	)
	/// Generated open turfs of each biome, populated after the camp and ruins are placed.
	var/list/biome_turfs
	/// Distance in turfs around the camp where flora still grows but hostile fauna never starts.
	var/fauna_clearance = 15
	/// Generated square side length in turfs.
	var/width = 128
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
		return SSmapping.biomes[table]
	// Seed offsets keep consecutive planet seeds from sharing noise fields.
	var/heat = text2num(rustg_noise_get_at_coordinates("[seed + 1000000]", "[x / biome_zoom]", "[y / biome_zoom]"))
	var/humidity = text2num(rustg_noise_get_at_coordinates("[seed + 2000000]", "[x / biome_zoom]", "[y / biome_zoom]"))
	var/list/row = table[noise_band(heat, mountain ? cave_heat_bands : heat_bands)]
	return SSmapping.biomes[row[noise_band(humidity, humidity_bands)]]

/** One-based band of a noise value among ascending inclusive upper thresholds. */
/datum/map_generator/expedition_barren/proc/noise_band(value, list/thresholds)
	var/band = 1
	for(var/threshold in thresholds)
		if(value > threshold)
			band++
	return band

/** Ore wall for a mountain tile, or the plain rock of this profile. */
/datum/map_generator/expedition_barren/proc/ore_at(x, y)
	var/roll = text2num(copytext(md5("[seed]:[x]:[y]"), 1, 5), 16) % 1000
	for(var/ore_type in ore_types)
		if(roll < ore_types[ore_type])
			return ore_type
	return rock_type

/datum/map_generator/expedition_barren/generate_terrain(list/turfs, area/generate_in)
	var/datum/stationtrauma_work_budget/budget = new
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
		else if(!is_reserved(x, y))
			var/mountain = text2num(rustg_noise_get_at_coordinates("[seed]", "[x / biome_zoom]", "[y / biome_zoom]")) > mountain_height
			biome = biome_at(x, y, mountain)
			terrain = biome.open_turf_type
			// Rock between cave pockets keeps the mountain mineable.
			if(mountain && text2num(rustg_noise_get_at_coordinates("[seed + 3000000]", "[x / 8]", "[y / 8]")) > 0.5)
				terrain = ore_at(x, y)
		var/turf/generated = tile.ChangeTurf(terrain, floor_type, CHANGETURF_IGNORE_AIR)
		if(ismineralturf(generated))
			// Native ore variants must expose this planet's ground and atmosphere when mined.
			var/turf/closed/mineral/rock = generated
			rock.turf_type = floor_type
			rock.initial_gas_mix = initial(floor_type.initial_gas_mix)
			if(rock_color)
				rock.color = rock_color
		else if(biome)
			LAZYADDASSOCLIST(biome_turfs, biome, generated)

/datum/map_generator/expedition_barren/populate_terrain(list/turfs, area/generate_in)
	for(var/datum/biome/biome as anything in biome_turfs)
		var/list/near_camp = list()
		var/list/wild = list()
		for(var/turf/tile as anything in biome_turfs[biome])
			var/x = tile.x - origin_x + 1
			var/y = tile.y - origin_y + 1
			if(x >= camp_x - fauna_clearance && x < camp_x + camp_width + fauna_clearance && y >= camp_y - fauna_clearance && y < camp_y + camp_height + fauna_clearance)
				near_camp += tile
			else
				wild += tile
		biome.populate_turfs(near_camp, flora_allowed = TRUE, features_allowed = TRUE, fauna_allowed = FALSE)
		biome.populate_turfs(wild, flora_allowed = TRUE, features_allowed = TRUE, fauna_allowed = TRUE)
	biome_turfs = null
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

/** Preload once; subsequent landings only move the vessel onto the retained native berth. */
/proc/load_stationtrauma_planet(seed = rand(1, 1000000), planet_id = "moon", planet_name = "Каменистая экзопланета", planet_type = /datum/stationtrauma_overmap_site/space/planet)
	if(!ispath(planet_type, /datum/stationtrauma_overmap_site/space/planet))
		CRASH("Invalid expedition planet profile [planet_type]")
	var/start_time = REALTIMEOFDAY
	var/datum/stationtrauma_overmap_site/space/planet/site = new planet_type
	site.id = planet_id
	var/datum/map_generator/expedition_barren/generator = new site.generator_type(seed)
	var/datum/map_template/camp = new('modular_bandastation/space_overmap/maps/moon.dmm', "Экспедиционная лаборатория")
	if(camp.width + 8 > generator.width || camp.height + 8 > generator.width)
		CRASH("Expedition camp does not fit the reserved planetary surface")
	var/datum/space_level/level = SSmapping.add_new_zlevel(planet_name, ZTRAITS_AWAY)
	generator.origin_x = round((world.maxx - generator.width) / 2) + 1
	generator.origin_y = round((world.maxy - generator.width) / 2) + 1
	generator.camp_x = 5
	generator.camp_y = 5
	generator.camp_width = camp.width
	generator.camp_height = camp.height
	var/list/ruins = site.prepare_ruins(generator)
	if(!ruins)
		qdel(camp)
		qdel(generator)
		qdel(site)
		return null
	var/turf/bottom = locate(generator.origin_x, generator.origin_y, level.z_value)
	var/list/turfs = block(bottom, locate(bottom.x + generator.width - 1, bottom.y + generator.width - 1, bottom.z))
	var/area/expedition_planet/barren/surface = new
	surface.name = "[planet_name]: поверхность"
	generator.generate_terrain(turfs, surface)
	var/turf/camp_origin = locate(bottom.x + generator.camp_x - 1, bottom.y + generator.camp_y - 1, bottom.z)
	if(!camp.load(camp_origin))
		qdel(camp)
		qdel(generator)
		qdel(site)
		return null
	// The shared camp template retains its rooms, but exposed ground follows the planet's atmosphere.
	for(var/turf/tile as anything in camp.get_affected_turfs(camp_origin))
		if(tile.type == /turf/open/misc/asteroid/airless && generator.floor_type != tile.type)
			tile.ChangeTurf(generator.floor_type, generator.floor_type, CHANGETURF_IGNORE_AIR)
	if(!site.load_ruins(ruins, bottom))
		qdel(camp)
		qdel(generator)
		qdel(site)
		return null
	site.name = planet_name
	site.pos_x = -100
	site.pos_y = -1250
	site.seed = seed
	site.surface_width = generator.width
	for(var/obj/docking_port/stationary/stationtrauma_space_surface/pad in SSshuttle.stationary_docking_ports)
		if(pad.z == level.z_value)
			site.berth = pad
			pad.name = "Посадочная площадка экспедиции"
			break
	if(!site.berth || generator.populate_terrain(turfs, surface) != 3)
		CRASH("Expedition planet [seed] lacks its landing berth or research sources")
	var/obj/structure/closet/crate/expedition_planet_supplies/supplies
	for(var/turf/open/floor/tile in camp.get_affected_turfs(camp_origin))
		if(!tile.is_blocked_turf(TRUE))
			supplies = new(tile)
			break
	if(!supplies)
		CRASH("Expedition planet [seed] has no free laboratory floor for field equipment")
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(supplies))
	marker.site_id = site.id
	marker.name = site.name
	SSmapping.reg_in_areas_in_z(list(surface))
	smooth_zlevel(level.z_value)
	site.generation_seconds = ((REALTIMEOFDAY - start_time + MIDNIGHT_ROLLOVER) % MIDNIGHT_ROLLOVER) / 10
	log_mapping("Expedition planet ready: seed [seed], [generator.width]x[generator.width], z [level.z_value], [site.generation_seconds]s")
	qdel(camp)
	qdel(generator)
	return site
// AI EDIT END
