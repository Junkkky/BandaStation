// AI EDIT START - space overmap module integration
/datum/stationtrauma_overmap_site/space
	/// Deferred map load run by the first approach; null once the destination exists or has failed.
	var/datum/callback/map_loader
	/// Set while the first approach loads the destination.
	var/loading_map = FALSE
	/// Approach schematic on the navigation console: "ruin", "cargo" or "asteroids".
	var/approach_scene = "ruin"
	/// Outer airlock of a loaded ruin that the docking pinpointer leads to beyond the seam; null without one.
	var/turf/entrance

/** Whether docking may begin before the berth exists because the approach loads the destination. */
/datum/stationtrauma_overmap_site/space/proc/awaits_map()
	return !!map_loader

/**
 * Load the charted destination once, beside live gameplay.
 *
 * Approaches wait on [/datum/stationtrauma_overmap_site/space/var/loading_map]. A crash inside the load only aborts that call,
 * so the site is still released as failed instead of waiting for another attempt. No try block here: it would turn any
 * runtime from a single loaded atom's Initialize into a failed destination.
 */
/datum/stationtrauma_overmap_site/space/proc/load_map()
	if(!map_loader || loading_map)
		return
	loading_map = TRUE
	failed = !map_loader.Invoke()
	map_loader = null
	loading_map = FALSE

/** Only reviewed local templates participate; native blacklists and round duplicate limits still apply. */
/datum/stationtrauma_overmap_sector/space/proc/load_ruin_sector()
	var/list/approved = list(
		/datum/map_template/ruin/space/oldstation = "Древняя космическая станция",
		/datum/map_template/ruin/space/deep_storage = "Автономный бункер",
		/datum/map_template/ruin/space/anomaly_research = "Аномальная исследовательская станция",
		/datum/map_template/ruin/space/zoo = "Биологическое хранилище",
		/datum/map_template/ruin/space/bigderelict1 = "Заброшенный торговый узел",
		/datum/map_template/ruin/space/derelict_sulaco = "Обломки военного корабля",
		/datum/map_template/ruin/space/mech_transport = "Транспорт CF Corsair",
		/datum/map_template/ruin/space/turreted_outpost = "Укреплённый аванпост",
		/datum/map_template/ruin/space/listeningstation = "Станция радиоперехвата",
		/datum/map_template/ruin/space/old_ai_sat = "Заброшенный ретранслятор",
		/datum/map_template/ruin/space/forgottenship = "Затерянный корабль",
		/datum/map_template/ruin/space/stationtrauma_icarus = "Исследовательский корабль SEV Icarus",
		/datum/map_template/ruin/space/stationtrauma_scav_mining = "Заброшенная шахтёрская база",
	)
	var/list/candidates = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/template = SSmapping.ruins_templates[key]
		if(istype(template, /datum/map_template/ruin/space/expedition))
			var/datum/map_template/ruin/space/expedition/imported = template
			approved[template.type] = imported.overmap_name
		if(approved[template.type] && !template.unpickable && (!template.loaded || template.allow_duplicates))
			candidates[key] = template
	if(!length(candidates))
		stack_trace("No eligible expedition ruins; check space ruin blacklists and already loaded templates")
		return FALSE
	var/list/positions = list(list(1100, 400), list(-1100, 600), list(1400, -1100), list(-1400, -450), list(450, 1350), list(-650, -1400))
	var/count = min(length(positions), length(candidates))
	// Templates are chosen now so the chart can name each signal; the first approach loads it.
	for(var/index in 1 to count)
		var/key = pick(candidates)
		var/datum/map_template/ruin/template = candidates[key]
		candidates -= key
		var/datum/stationtrauma_overmap_site/space/site = new
		site.id = "expedition_[index]"
		site.name = approved[template.type]
		site.pos_x = positions[index][1]
		site.pos_y = positions[index][2]
		site.discovered = FALSE
		site.needs_scan = TRUE
		site.map_loader = CALLBACK(src, PROC_REF(load_ruin_site), site, index, key, template)
		sites[site.id] = site
	return TRUE

/** Load one charted ruin on its own level, berthing the approach right beside it, level with its entrance airlock. */
/datum/stationtrauma_overmap_sector/space/proc/load_ruin_site(datum/stationtrauma_overmap_site/space/site, index, key, datum/map_template/ruin/template)
	var/datum/space_level/level = SSmapping.add_new_zlevel("Экспедиционный сектор [index]", ZTRAITS_AWAY)
	seedRuins(list(level.z_value), 1, list(/area/space), list((key) = template), mineral_budget = 0, ruins_type = ZTRAIT_SPACE_RUINS, immediate_load = TRUE)
	var/turf/origin
	var/datum/map_template/ruin/placed
	for(var/turf/anchor as anything in SSmapping.active_ruins)
		if(anchor.z == level.z_value)
			origin = anchor
			placed = SSmapping.active_ruins[anchor]
			break
	if(!placed || !placed.loaded)
		stack_trace("Expedition ruin [key] failed to load on z [level.z_value]")
		return FALSE
	stationtrauma_space_vacuum(level.z_value)
	var/right_edge = origin.x + placed.width - 1
	var/approach_y = origin.y + round(placed.height / 2)
	var/best_score = -INFINITY
	for(var/turf/tile as anything in block(origin, locate(right_edge, origin.y + placed.height - 1, origin.z)))
		for(var/obj/machinery/door/airlock/door in tile)
			for(var/direction in GLOB.cardinals)
				if(!isspaceturf(get_step(door, direction)))
					continue
				// The seam opens east of the ruin: east-facing airlocks are straight across, others rank by how far east they stand.
				var/score = door.x + (direction == EAST ? world.maxx : 0)
				if(score > best_score)
					best_score = score
					site.entrance = tile
					approach_y = door.y
				break
	site.ruin_id = placed.id
	// The seam lands crews on the column just outside the ruin, level with that airlock.
	site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 1, approach_y, origin.z))
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(site.berth))
	marker.site_id = site.id
	marker.name = site.name
	return TRUE

/** Known planets carry their chart symbol without disclosing hidden signals. */
/datum/stationtrauma_overmap/space/known_sites()
	. = ..()
	for(var/list/record as anything in .)
		var/datum/stationtrauma_overmap_site/space/site = sites[record["id"]]
		record["kind"] = istype(site, /datum/stationtrauma_overmap_site/space/planet) ? "planet" : site.physical_docking ? "station" : "signal"

/** A bounded metadata pulse, independent of loading and never exposing contacts outside detection range. */
/datum/stationtrauma_overmap/space/proc/scan_sector()
	if(relocating || preparing || !is_operational() || world.time < next_scan)
		return FALSE
	next_scan = world.time + 20 SECONDS
	last_ping = world.time
	var/found = 0
	var/reach = sensor_range
	found += observe_ships(reach)
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/site = sites[id]
		if(!knows_site(site) && !site.failed && distance_to(site) <= reach)
			discover_site(site)
			found++
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		if(!charted_zones[zone] && (pos_x - zone.pos_x) ** 2 + (pos_y - zone.pos_y) ** 2 <= (reach + zone.radius) ** 2)
			charted_zones[zone] = TRUE
			found++
	navigation_notice("Сканирование завершено: новых точек [found]. Дальность [reach * ST_SPACE_AU_SCALE] а.е.")
	return TRUE

/**
 * Handheld guide to the airlock of the destination a vessel holds through a remote seam.
 *
 * Aboard, it points at the seam exit level with the berth, since the seam keeps the crossing row; beyond the seam it points
 * at the entrance airlock itself, or at the berth when the destination has none.
 */
/obj/item/pinpointer/stationtrauma_docking
	name = "стыковочный пеленгатор"
	desc = "Указывает путь к входному шлюзу объекта, у которого стоит корабль. На борту ведёт к точке выхода напротив шлюза."
	/// Turf to head for on the holder's level; null without a seam-docked destination there.
	var/turf/beacon

/obj/item/pinpointer/stationtrauma_docking/Destroy()
	beacon = null
	return ..()

/obj/item/pinpointer/stationtrauma_docking/scan_for_target()
	beacon = null
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			var/datum/stationtrauma_overmap_site/space/site = navigation?.docked
			if(!istype(navigation) || !istype(site) || site.landing || site.physical_docking || QDELETED(site.berth) || !navigation.connection.active)
				continue
			if(here.z == site.berth.z)
				beacon = site.entrance || get_turf(site.berth)
				return
			if(here.z != navigation.vessel.z)
				continue
			var/datum/stationtrauma_map_connection/connection = navigation.connection
			var/edge = connection.get_ship_edge(navigation.vessel.return_coords(), 1, connection.direction)
			if(isnull(edge))
				continue
			beacon = connection.direction & (EAST|WEST) ? locate(edge, site.berth.y, here.z) : locate(site.berth.x, edge, here.z)
			return

/obj/item/pinpointer/stationtrauma_docking/update_overlays()
	. = ..()
	var/turf/here = get_turf(src)
	if(!active || !beacon || here?.z != beacon.z)
		return
	// The base pinpointer tracks movables only; a turf beacon replaces its idle overlay.
	. -= "pinonnull"
	. += get_direction_icon(here, beacon)
// AI EDIT END
