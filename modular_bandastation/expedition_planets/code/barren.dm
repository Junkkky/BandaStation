// Barren environment profile adapted from SierraBay, AGPL-3.0; terrain generation uses local TG/rust-g.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm
/area/expedition_planet/barren
	name = "Каменистая поверхность экзопланеты"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags_mapping = UNIQUE_AREA
	ambientsounds = list(null)

/datum/stationtrauma_overmap_site/space/planet
	name = "Каменистая экзопланета"
	landing = TRUE
	needs_scan = FALSE
	discovered = TRUE
	/// Retained for admin diagnostics; navigation never publishes the generation seed.
	var/seed
	var/surface_width = 128
	var/generation_seconds
	var/generator_type = /datum/map_generator/expedition_barren
	var/biome = "Безжизненный каменистый"
	var/atmosphere = "Вакуум, 0 кПа"
	var/surface_temperature = TCMB
	var/breathable = FALSE

/datum/stationtrauma_overmap_site/space/planet/proc/survey_data()
	return list("biome" = biome, "atmosphere" = atmosphere, "temperature" = surface_temperature, "breathable" = breathable)

/** Sierra's airless, lifeless, mineral-rich profile, using TG's seeded rust-g noise. */
/datum/map_generator/expedition_barren
	var/seed
	var/width = 128
	var/origin_x
	var/origin_y
	var/camp_x
	var/camp_y
	var/camp_width
	var/camp_height
	var/list/ruin_bounds = list()
	var/turf/open/floor_type = /turf/open/misc/asteroid/airless
	var/source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_barren
	var/rock_color

/datum/map_generator/expedition_barren/New(chosen_seed)
	. = ..()
	if(!ISINTEGER(chosen_seed) || chosen_seed < 1 || chosen_seed > 1000000)
		CRASH("Invalid expedition planet seed [chosen_seed]")
	seed = chosen_seed

/datum/map_generator/expedition_barren/proc/in_camp(x, y)
	return x >= camp_x && x < camp_x + camp_width && y >= camp_y && y < camp_y + camp_height

/datum/map_generator/expedition_barren/proc/is_reserved(x, y)
	if(in_camp(x, y) || abs(x - round(width / 2)) <= 1 || abs(y - round(width / 2)) <= 1)
		return TRUE
	for(var/list/bounds as anything in ruin_bounds)
		if(x >= bounds[1] - 1 && x <= bounds[3] + 1 && y >= bounds[2] - 1 && y <= bounds[4] + 1)
			return TRUE
		if(y == round((bounds[2] + bounds[4]) / 2) && x >= min(round(width / 2), bounds[1]) && x <= max(round(width / 2), bounds[3]))
			return TRUE
	return FALSE

/** The reservation and open cross keep landing, the laboratory and the field connected. */
/datum/map_generator/expedition_barren/proc/terrain_at(x, y)
	// The opaque rim bounds this surface within its otherwise empty z-level.
	if(x <= 2 || y <= 2 || x > width - 2 || y > width - 2)
		return /turf/closed/indestructible/rock
	if(is_reserved(x, y))
		return floor_type
	var/height = text2num(rustg_noise_get_at_coordinates("[seed]", "[x / 12]", "[y / 12]"))
	if(height < 0.58)
		return floor_type
	var/ore = text2num(copytext(md5("[seed]:[x]:[y]"), 1, 5), 16) % 1000
	switch(ore)
		if(0 to 4)
			return /turf/closed/mineral/diamond
		if(5 to 19)
			return /turf/closed/mineral/gold
		if(20 to 39)
			return /turf/closed/mineral/silver
		if(40 to 59)
			return /turf/closed/mineral/uranium
		if(60 to 89)
			return /turf/closed/mineral/titanium
		if(90 to 239)
			return /turf/closed/mineral/iron
	return /turf/closed/mineral

/datum/map_generator/expedition_barren/generate_terrain(list/turfs, area/generate_in)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/tile as anything in turfs)
		budget.yield()
		tile.change_area(get_area(tile), generate_in)
		var/turf/generated = tile.ChangeTurf(terrain_at(tile.x - origin_x + 1, tile.y - origin_y + 1), floor_type, CHANGETURF_IGNORE_AIR)
		if(ismineralturf(generated))
			// Native ore variants must expose this planet's ground and atmosphere when mined.
			var/turf/closed/mineral/rock = generated
			rock.turf_type = floor_type
			rock.initial_gas_mix = initial(floor_type.initial_gas_mix)
			if(rock_color)
				rock.color = rock_color

/datum/map_generator/expedition_barren/populate_terrain(list/turfs, area/generate_in)
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

/obj/structure/stationtrauma_research_source/mineral/expedition_barren
	name = "кристаллический нарост экзопланеты"
	desc = "Минеральные включения на безвоздушной поверхности. Их можно обследовать и отобрать пробы."
	field_notes = "В трещинах породы видны неоднородные кристаллические включения с острыми гранями. Следов растительности нет."
	laboratory_notes = "Включения образуют несколько минеральных фракций. Состав и возможное применение требуют дальнейших испытаний."

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
