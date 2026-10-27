/** Mapper-declared scenario: extra hull templates are loaded before the shared destinations. */
/obj/effect/landmark/stationtrauma_space_sector
	name = "space overmap sector"
	var/list/ship_templates = list()

/datum/stationtrauma_overmap_sector/space
	var/list/zones = list()

/datum/stationtrauma_overmap_sector/space/Destroy()
	. = ..()
	QDEL_LIST(zones)

/** The native template loader supplies unique areas and shuttle IDs for each physical hull. */
/proc/load_stationtrauma_space_ship(map_path)
	var/datum/map_template/stationtrauma_space/template = new(map_path, "Overmap ship")
	var/datum/space_level/home = template.load_new_z()
	if(!home)
		qdel(template)
		return null
	var/min_x = round((world.maxx - template.width) / 2) + 1
	var/min_y = round((world.maxy - template.height) / 2) + 1
	for(var/turf/tile as anything in block(locate(min_x, min_y, home.z_value), locate(min_x + template.width - 1, min_y + template.height - 1, home.z_value)))
		var/obj/docking_port/mobile/stationtrauma_space/vessel = locate() in tile
		if(vessel)
			SSatoms.InitializeAtoms(list(vessel))
			qdel(template)
			return vessel
	qdel(template)
	return null

/** Attach a hull without copying sector geography or another crew's observations. */
/datum/stationtrauma_overmap_sector/space/proc/attach(obj/docking_port/mobile/stationtrauma_space/vessel)
	if(QDELETED(vessel) || vessel.width < 1 || vessel.height < 1 || !length(vessel.shuttle_areas))
		return FALSE
	if(vessel.overmap)
		return vessel.overmap.sector == src
	// The current seam spans the entire flight level; two hulls cannot share that level.
	for(var/id in ships)
		var/datum/stationtrauma_overmap/space/other = ships[id]
		if(other.flight_berth.z == vessel.z)
			stack_trace("Overmap hull [vessel.shuttle_id] shares a flight level with [other.vessel.shuttle_id]")
			return FALSE
	if(!vessel.registered)
		vessel.register()
	vessel.linkup(null)
	var/datum/stationtrauma_overmap/space/navigation = new(vessel)
	if(!register(vessel.shuttle_id, navigation))
		qdel(navigation)
		return FALSE
	vessel.overmap = navigation
	navigation.zones = zones
	navigation.pos_x = vessel.overmap_x
	navigation.pos_y = vessel.overmap_y
	navigation.course = vessel.overmap_course
	navigation.ordered_course = vessel.overmap_course
	var/area/space/stationtrauma_space_home/exterior = new
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/open/space/tile in block(locate(1, 1, vessel.z), locate(world.maxx, world.maxy, vessel.z)))
		var/area/old_area = get_area(tile)
		if(old_area.type == /area/space)
			tile.change_area(old_area, exterior)
		budget.yield()
		if(QDELETED(vessel) || QDELETED(navigation) || QDELETED(src))
			return FALSE
	navigation.exterior = exterior
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/console in ship_area)
			if(vessel.is_in_shuttle_bounds(console))
				console.vessel = vessel
	navigation.encounter_x = navigation.pos_x
	navigation.encounter_y = navigation.pos_y
	navigation.preparing = FALSE
	if(vessel.starting_dock)
		if(!navigation.select_site(vessel.starting_dock) || !navigation.dock())
			qdel(navigation)
			return FALSE
	return TRUE

/** Physical destinations belong to the sector and are loaded exactly once. */
/datum/stationtrauma_overmap_sector/space/proc/load_locations()
	var/datum/map_template/stationtrauma_space/template
	// The first entry is the copied CC. Coordinates are navigation metres, never turf coordinates.
	var/list/locations = list(
		list("centcom_dock", "Центральное командование", 0, 0, 'modular_bandastation/space_overmap/maps/centcom_dock.dmm'),
		list("asteroid_field", "Астероидное поле", 1250, -450, 'modular_bandastation/space_overmap/maps/asteroid_field.dmm'),
		list("drift_cargo", "Дрейфующий груз", rand(700, 900), rand(-160, -40), 'modular_bandastation/space_overmap/maps/drift_cargo.dmm'),
	)
	for(var/list/location as anything in locations)
		template = new(location[5], location[2])
		var/datum/space_level/level = template.load_new_z()
		if(!level)
			qdel(template)
			return null
		var/right_edge = round((world.maxx - template.width) / 2) + template.width
		var/datum/stationtrauma_overmap_site/space/site = new
		site.id = location[1]
		site.name = location[2]
		site.pos_x = location[3]
		site.pos_y = location[4]
		site.discovered = site.id == "centcom_dock"
		site.needs_scan = site.id != "centcom_dock" && site.id != "drift_cargo"
		site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 2, round(world.maxy / 2), level.z_value))
		sites[site.id] = site
		qdel(template)
	var/datum/stationtrauma_overmap_site/space/planet/planet = load_stationtrauma_rocky_planet()
	if(!planet)
		return null
	sites[planet.id] = planet
	if(!load_ruin_sector())
		return null
	build_encounters()
	return TRUE
