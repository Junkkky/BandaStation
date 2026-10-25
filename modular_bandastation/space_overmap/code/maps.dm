/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Raven: испытательный корабль"
	requires_power = FALSE

/area/shuttle/stationtrauma_space/brig
	name = "Raven: изолятор"

/area/space/stationtrauma_space_home
	name = "Окрестности Raven"

/area/stationtrauma_space_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/area/stationtrauma_space_site/centcom
	name = "Испытательный док ЦК"
/area/stationtrauma_space_site/paradise
	name = "Покинутый охранный шаттл"
/area/stationtrauma_space_site/sierra
	name = "Заброшенная лаборатория"
/area/stationtrauma_space_site/voidcrew
	name = "Ботаническая станция"
/area/stationtrauma_space_site/tg
	name = "Обломки станции"
/area/stationtrauma_space_site/asteroid
	name = "Астероидное поле"
	default_gravity = ZERO_GRAVITY
/area/stationtrauma_space_site/planet
	name = "Безвоздушная луна"

/// Native engines and hull ownership, without the emergency shuttle's evacuation controller.
/obj/docking_port/mobile/stationtrauma_space
	name = "Raven"
	shuttle_id = "stationtrauma_space_raven"
	area_type = /area/shuttle/stationtrauma_space
	width = 21
	height = 32
	dheight = 16
	var/datum/stationtrauma_overmap/space/overmap

/obj/docking_port/mobile/stationtrauma_space/Destroy(force)
	QDEL_NULL(overmap)
	return ..()

/// Physical relocation is deliberately replaced by the shared virtual navigation model.
/obj/docking_port/mobile/stationtrauma_space/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	return DOCKING_BLOCKED

/obj/docking_port/stationary/stationtrauma_space_site
	name = "Виртуальная стоянка"

/datum/stationtrauma_overmap_site/space
	/// Landing and docking share transitions, but remain explicit navigation orders.
	var/landing = FALSE

/datum/map_template/stationtrauma_space
	should_place_on_top = FALSE

/** Templates initialize their footprint; the traversable vacuum outside it also needs native space gas. */
/datum/map_template/stationtrauma_space/initTemplateBounds(list/bounds)
	if(bounds)
		var/datum/stationtrauma_work_budget/budget = new
		for(var/turf/open/space/tile in block(locate(1, 1, bounds[MAP_MINZ]), locate(world.maxx, world.maxy, bounds[MAP_MAXZ])))
			tile.air ||= tile.space_gas
			budget.yield()
	return ..()

/// Native equipment for actually leaving the prototype and collecting asteroid ore.
/obj/structure/closet/crate/stationtrauma_space_eva
	name = "экспедиционное снаряжение"

/obj/structure/closet/crate/stationtrauma_space_eva/PopulateContents()
	for(var/index in 1 to 2)
		new /obj/item/clothing/suit/space(src)
		new /obj/item/clothing/head/helmet/space(src)
		new /obj/item/tank/jetpack/void(src)
		new /obj/item/clothing/mask/breath(src)
		new /obj/item/pickaxe(src)
		new /obj/item/storage/bag/ore(src)

GLOBAL_VAR_INIT(stationtrauma_space_loaded, FALSE)

ADMIN_VERB(stationtrauma_space_prototype, R_DEBUG, "StationTrauma - Space Overmap Prototype", "Load a copied Raven and all small space destinations.", ADMIN_CATEGORY_DEBUG)
	if(GLOB.stationtrauma_space_loaded)
		to_chat(user, span_warning("Космический прототип уже загружен или загружается."), confidential = TRUE)
		return
	GLOB.stationtrauma_space_loaded = TRUE
	to_chat(user, span_notice("Загружаются Raven и все точки маршрута. Дождись готовности."), confidential = TRUE)
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	try
		vessel = load_stationtrauma_space()
	catch(var/exception/failure)
		stack_trace("Space overmap prototype failed: [failure]")
	if(!vessel)
		to_chat(user, span_warning("Ошибка загрузки. Подробности в runtime log; повтор отключён до перезапуска."), confidential = TRUE)
		return
	to_chat(user, span_notice("Raven готов: ([vessel.x], [vessel.y], [vessel.z]). Навигация на мостике: ([vessel.x + 10], [vessel.y + 14], [vessel.z])."), confidential = TRUE)

/** Bind a primary-map Raven or load an admin copy, retaining every destination between visits. */
/proc/load_stationtrauma_space(obj/docking_port/mobile/stationtrauma_space/vessel)
	var/datum/map_template/stationtrauma_space/template
	if(!vessel)
		template = new('modular_bandastation/space_overmap/maps/raven.dmm', "Space prototype: Raven")
		var/datum/space_level/home = template.load_new_z()
		if(!home)
			qdel(template)
			return null
		var/min_x = round((world.maxx - template.width) / 2) + 1
		var/min_y = round((world.maxy - template.height) / 2) + 1
		var/turf/marker = locate(min_x, min_y + 16, home.z_value)
		vessel = locate() in marker
		qdel(template)
		if(vessel)
			SSatoms.InitializeAtoms(list(vessel))
	if(!vessel)
		return null
	if(vessel.overmap)
		return vessel
	if(!vessel.registered)
		vessel.register()
	vessel.linkup(null)
	var/datum/stationtrauma_overmap/space/map = new(vessel)
	vessel.overmap = map
	var/datum/stationtrauma_work_budget/budget = new
	var/list/bounds = vessel.return_coords()
	var/area/space/stationtrauma_space_home/exterior = get_area(locate(min(bounds[1], bounds[3]), min(bounds[2], bounds[4]), vessel.z))
	for(var/turf/open/space/tile as anything in block(locate(1, 1, vessel.z), locate(world.maxx, world.maxy, vessel.z)))
		budget.yield()
		var/area/old_area = get_area(tile)
		if(old_area.type == /area/space)
			tile.change_area(old_area, exterior)
	map.exterior = exterior
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/console in ship_area)
			console.vessel = vessel
	// The first entry is the copied CC. Coordinates are navigation metres, never turf coordinates.
	var/list/locations = list(
		list("centcom_dock", "ЦК: испытательный док", 0, 0, FALSE, 'modular_bandastation/space_overmap/maps/centcom_dock.dmm'),
		list("paradise_ruin", "Покинутый охранный шаттл", 850, 200, FALSE, 'modular_bandastation/space_overmap/maps/paradise_ruin.dmm'),
		list("voidcrew_ruin", "Ботаническая станция", 500, 950, FALSE, 'modular_bandastation/space_overmap/maps/voidcrew_ruin.dmm'),
		list("tg_ruin", "Обломки станции", -900, 550, FALSE, 'modular_bandastation/space_overmap/maps/tg_ruin.dmm'),
		list("sierra_ruin", "Заброшенная лаборатория", -650, -700, FALSE, 'modular_bandastation/space_overmap/maps/sierra_ruin.dmm'),
		list("asteroid_field", "Астероидное поле", 1250, -450, FALSE, 'modular_bandastation/space_overmap/maps/asteroid_field.dmm'),
		list("moon", "Безвоздушная луна", -100, -1250, TRUE, 'modular_bandastation/space_overmap/maps/moon.dmm'),
	)
	for(var/list/location as anything in locations)
		template = new(location[6], location[2])
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
		site.landing = location[5]
		site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 2, vessel.y, level.z_value))
		map.sites[site.id] = site
		qdel(template)
	map.preparing = FALSE
	map.select_site("centcom_dock")
	if(!map.dock())
		return null
	return vessel
