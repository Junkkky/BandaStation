/** Only reviewed local templates participate; native blacklists and round duplicate limits still apply. */
/datum/stationtrauma_overmap_sector/space/proc/load_ruin_sector()
	var/list/approved = list(
		/datum/map_template/ruin/space/oldstation = "Древняя космическая станция",
		/datum/map_template/ruin/space/deep_storage = "Автономный бункер",
		/datum/map_template/ruin/space/anomaly_research = "Аномальная исследовательская станция",
		/datum/map_template/ruin/space/stationtrauma_icarus = "Исследовательский корабль SEV Icarus",
		/datum/map_template/ruin/space/stationtrauma_scav_mining = "Заброшенная шахтёрская база",
	)
	var/list/candidates = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/template = SSmapping.ruins_templates[key]
		if(approved[template.type] && !template.unpickable && (!template.loaded || template.allow_duplicates))
			candidates[key] = template
	if(!length(candidates))
		stack_trace("Raven has no eligible expedition ruins; check space ruin blacklists and already loaded templates")
		return FALSE
	var/list/positions = list(list(1100, 400), list(-1100, 600))
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
			stack_trace("Raven expedition ruin generation failed on z [level.z_value]")
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
		sites[site.id] = site
	return TRUE

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
	navigation_notice("Сканирование завершено: новых точек [found]. Дальность [reach] м.")
	return TRUE
