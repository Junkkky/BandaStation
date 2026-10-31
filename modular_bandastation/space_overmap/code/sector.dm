// AI EDIT START - space overmap module integration
/** Mapper-declared scenario: extra hull templates are loaded before the shared destinations. */
/obj/effect/landmark/stationtrauma_space_sector
	name = "space overmap sector"
	/// Additional hull template paths loaded for this mapped sector scenario.
	var/list/ship_templates = list()

/** Resident star system with shared destinations and separate per-crew charts. */
/datum/stationtrauma_overmap_sector/space
	/// Stable sector key used by jump routes and mapped hulls.
	var/id = "frontier"
	/// Navigation display name, independent of the central star.
	var/name = "ST 220 AB-C d1-1"
	/// Arrival coordinates in virtual sector units.
	var/entry_x = 200
	/// Arrival ordinate in virtual sector units.
	var/entry_y = -400
	/// Sector IDs reachable through the bluespace terminal.
	var/list/jump_routes = list("epsilon_eridani")
	/// True only after every physical destination has finished loading.
	var/ready = FALSE
	/// Per-hull discoveries retained between sector visits; contains no vessel references.
	var/list/ship_charts = list()
	/// Sector-owned encounter regions.
	var/list/zones = list()
	/// Chart-only bodies: name, position, symbol radius and orbit centre; never landing targets.
	var/list/celestial_bodies = list()

/datum/stationtrauma_overmap_sector/space/Destroy()
	. = ..()
	ship_charts.Cut()
	QDEL_LIST(zones)

/** Epsilon Eridani station sector, sharing the native station map rather than a copy. */
/datum/stationtrauma_overmap_sector/space/home
	id = "epsilon_eridani"
	name = "Эпсилон Эридана"
	jump_routes = list("frontier")
	celestial_bodies = list(
		list("name" = "Лазис Ардакс", "x" = 1000, "y" = -240, "radius" = 22, "kind" = "lava", "orbit_x" = 0, "orbit_y" = 0),
		list("name" = "Эгир", "x" = 1320, "y" = -400, "radius" = 7, "kind" = "moon", "orbit_x" = 1000, "orbit_y" = -240),
	)

/** The sector retains each hull's static chart between visits, without retaining the hull itself. */
/datum/stationtrauma_overmap_sector/space/register(id, datum/stationtrauma_overmap/space/navigation)
	if(!istype(navigation) || !..())
		return FALSE
	var/list/chart = ship_charts[id]
	if(!chart)
		chart = list(list(), list(), list())
		ship_charts[id] = chart
	navigation.discovered_sites = chart[1]
	navigation.visited_sites = chart[2]
	navigation.charted_zones = chart[3]
	navigation.zones = zones
	return TRUE

/datum/stationtrauma_overmap_sector/space/unregister(datum/stationtrauma_overmap/space/navigation)
	if(!..())
		return FALSE
	navigation.discovered_sites = list()
	navigation.visited_sites = list()
	navigation.charted_zones = list()
	navigation.zones = list()
	return TRUE

/** The native template loader supplies unique areas and shuttle IDs for each physical hull. */
/proc/load_stationtrauma_space_ship(map_path)
	var/datum/map_template/stationtrauma_space/template = new(map_path, "Overmap ship")
	var/datum/space_level/home = template.load_new_z()
	if(!home)
		qdel(template)
		return null
	var/min_x = round((world.maxx - template.width) / 2) + 1
	var/min_y = round((world.maxy - template.height) / 2) + 1
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	var/list/areas = list()
	for(var/turf/tile as anything in block(locate(min_x, min_y, home.z_value), locate(min_x + template.width - 1, min_y + template.height - 1, home.z_value)))
		areas |= get_area(tile)
		if(!vessel)
			vessel = locate() in tile
	if(vessel)
		for(var/area/ship_area as anything in areas)
			if(istype(ship_area, vessel.area_type))
				vessel.shuttle_areas[ship_area] = TRUE
		if(length(vessel.shuttle_areas))
			vessel.calculate_docking_port_information()
			SSatoms.InitializeAtoms(list(vessel))
			qdel(template)
			return vessel
	qdel(template)
	return null

/** Register a hull and prepare its flight level and consoles. */
/datum/stationtrauma_overmap_sector/space/proc/attach(obj/docking_port/mobile/stationtrauma_space/vessel)
	if(QDELETED(vessel) || vessel.width < 1 || vessel.height < 1 || !length(vessel.shuttle_areas))
		return FALSE
	if(!(vessel.ship_class in list(ST_SHIP_SMALL, ST_SHIP_MEDIUM, ST_SHIP_CAPITAL)))
		stack_trace("Overmap hull [vessel.shuttle_id] has an invalid ship_class: [vessel.ship_class]")
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
	navigation.initialize_ship_audio()
	if(vessel.starting_dock)
		if(!navigation.select_site(vessel.starting_dock) || !navigation.dock())
			qdel(navigation)
			return FALSE
	navigation.update_parallax()
	return TRUE

/** Physical destinations belong to the sector and are loaded exactly once. */
/datum/stationtrauma_overmap_sector/space/proc/load_locations()
	if(ready || length(sites))
		return ready
	if(istype(src, /datum/stationtrauma_overmap_sector/space/home))
		for(var/obj/docking_port/stationary/stationtrauma_space_station/port in SSshuttle.stationary_docking_ports)
			var/datum/stationtrauma_overmap_site/space/site = new
			site.id = port.site_id
			site.name = port.station_name
			site.pos_x = 1000
			site.pos_y = 0
			site.physical_docking = TRUE
			site.berth = port
			sites[site.id] = site
		ready = length(sites) > 0
		return ready
	var/datum/map_template/stationtrauma_space/template
	var/list/locations = list(
		list("asteroid_field", "Астероидное поле", 1250, -450, 'modular_bandastation/space_overmap/maps/asteroid_field.dmm', /atom/movable/screen/parallax_layer/random/asteroids),
		list("drift_cargo", "Дрейфующий груз", rand(700, 900), rand(-160, -40), 'modular_bandastation/space_overmap/maps/drift_cargo.dmm', /atom/movable/screen/parallax_layer/layer_3),
	)
	for(var/list/location as anything in locations)
		template = new(location[5], location[2])
		var/datum/space_level/level = template.load_new_z()
		if(!level)
			QDEL_NULL(template)
			return null
		level.space_parallax_background = location[6]
		var/right_edge = round((world.maxx - template.width) / 2) + template.width
		var/datum/stationtrauma_overmap_site/space/site = new
		site.id = location[1]
		site.name = location[2]
		site.pos_x = location[3]
		site.pos_y = location[4]
		site.discovered = FALSE
		site.needs_scan = TRUE
		site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 2, round(world.maxy / 2), level.z_value))
		sites[site.id] = site
		QDEL_NULL(template)
	var/list/positions = list(list(800, 350), list(-100, -1250), list(-1500, 800), list(1800, 1100), list(-1800, -1300))
	var/list/profiles = list(/datum/stationtrauma_overmap_site/space/planet, /datum/stationtrauma_overmap_site/space/planet/frozen, /datum/stationtrauma_overmap_site/space/planet/arid, /datum/stationtrauma_overmap_site/space/planet/lush, /datum/stationtrauma_overmap_site/space/planet/lava)
	var/first_seed = rand(1, 1000001 - length(positions))
	for(var/index in 1 to length(positions))
		var/profile = profiles[index]
		// Planets farther from the arrival point roll stronger dangers and rewards.
		var/modifier_level = sqrt((positions[index][1] - entry_x) ** 2 + (positions[index][2] - entry_y) ** 2) / 500
		var/datum/stationtrauma_overmap_site/space/planet/planet = load_stationtrauma_planet(seed = first_seed + index - 1, planet_id = "planet_[index]", planet_name = "[name] [index]", planet_type = profile, modifier_level = modifier_level)
		if(!planet)
			return FALSE
		planet.pos_x = positions[index][1]
		planet.pos_y = positions[index][2]
		sites[planet.id] = planet
	if(!load_ruin_sector())
		return null
	build_encounters()
	ready = TRUE
	return TRUE
// AI EDIT END
