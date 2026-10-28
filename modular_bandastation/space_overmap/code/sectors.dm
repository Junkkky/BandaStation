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
	for(var/index in 1 to count)
		var/datum/space_level/level = SSmapping.add_new_zlevel("Экспедиционный сектор [index]", ZTRAITS_AWAY)
		seedRuins(list(level.z_value), 1, list(/area/space), candidates, mineral_budget = 0, ruins_type = ZTRAIT_SPACE_RUINS, immediate_load = TRUE)
		var/turf/origin
		var/datum/map_template/ruin/placed
		for(var/turf/anchor as anything in SSmapping.active_ruins)
			if(anchor.z == level.z_value)
				origin = anchor
				placed = SSmapping.active_ruins[anchor]
				break
		if(!placed || !placed.loaded)
			stack_trace("Expedition ruin generation failed on z [level.z_value]")
			return FALSE
		candidates -= placed.name
		stationtrauma_space_vacuum(level.z_value)
		var/right_edge = origin.x + placed.width - 1
		var/approach_y = origin.y + round(placed.height / 2)
		var/closest_door = origin.x - 1
		for(var/turf/tile as anything in block(origin, locate(right_edge, origin.y + placed.height - 1, origin.z)))
			for(var/obj/machinery/door/airlock/door in tile)
				if(door.x > closest_door && isspaceturf(get_step(door, EAST)))
					closest_door = door.x
					approach_y = door.y
		var/datum/stationtrauma_overmap_site/space/site = new
		site.id = "expedition_[index]"
		site.name = approved[placed.type]
		site.pos_x = positions[index][1]
		site.pos_y = positions[index][2]
		site.discovered = FALSE
		site.needs_scan = TRUE
		site.ruin_id = placed.id
		site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 2, approach_y, origin.z))
		var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(site.berth))
		marker.site_id = site.id
		marker.name = site.name
		sites[site.id] = site
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
