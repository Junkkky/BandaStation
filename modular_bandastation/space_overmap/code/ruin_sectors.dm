/** Imported space templates excluded from ordinary station space ruin selection. */
/datum/map_template/ruin/space/expedition
	prefix = "_maps/map_files/overmap_ruins/space/"
	ruin_type = "expedition_space"
	/// Crew-facing chart name for this imported ruin.
	var/overmap_name

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
