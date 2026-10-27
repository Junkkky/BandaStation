/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Корабль"
	requires_power = FALSE

/area/shuttle/stationtrauma_space/brig
	name = "Raven: изолятор"

/area/space/stationtrauma_space_home
	name = "Открытый космос"

/area/stationtrauma_space_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/area/stationtrauma_space_site/centcom
	name = "Центральное командование"
/area/stationtrauma_space_site/asteroid
	name = "Астероидное поле"
	default_gravity = ZERO_GRAVITY
/area/stationtrauma_space_site/planet
	name = "Безвоздушная луна"

/area/stationtrauma_space_site/cargo
	name = "Дрейфующая грузовая платформа"
	default_gravity = ZERO_GRAVITY

/obj/structure/closet/crate/stationtrauma_salvage
	name = "аварийный запас материалов"

/obj/structure/closet/crate/stationtrauma_salvage/PopulateContents()
	new /obj/item/stack/sheet/iron(src, 15)
	new /obj/item/stack/sheet/glass(src, 5)
	new /obj/item/stack/cable_coil(src, 20)

/// Native engines and hull ownership, without the emergency shuttle's evacuation controller.
/obj/docking_port/mobile/stationtrauma_space
	name = "Корабль"
	shuttle_id = "overmap_ship"
	area_type = /area/shuttle/stationtrauma_space
	var/datum/stationtrauma_overmap/space/overmap
	/// Navigation metres and heading; physical coordinates are supplied by the native port.
	var/overmap_x = 0
	var/overmap_y = 0
	var/overmap_course = 90
	var/starting_dock
	var/can_land = TRUE
	var/list/transponders = list()

/obj/docking_port/mobile/stationtrauma_space/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE
	for(var/obj/machinery/computer/stationtrauma_transponder/device as anything in transponders)
		device.vessel = null
	transponders.Cut()
	QDEL_NULL(overmap)
	return ..()

/obj/docking_port/stationary/stationtrauma_space_site
	name = "Стыковочная площадка"

/area/shuttle/stationtrauma_space/pocketrocket
	name = "Pocket Rocket"

/area/shuttle/stationtrauma_space/pocketrocket/bridge
	name = "Pocket Rocket: рубка"

/area/shuttle/stationtrauma_space/pocketrocket/cargo
	name = "Pocket Rocket: грузовой отсек"

/area/shuttle/stationtrauma_space/pocketrocket/crew
	name = "Pocket Rocket: жилой отсек"

/area/shuttle/stationtrauma_space/pocketrocket/crew/canteen
	name = "Pocket Rocket: камбуз"

/area/shuttle/stationtrauma_space/pocketrocket/maintenance/central
	name = "Pocket Rocket: технический отсек"

/datum/stationtrauma_overmap_site/space
	var/datum/stationtrauma_overmap/space/docking_owner
	/// Landing and docking share transitions, but remain explicit navigation orders.
	var/landing = FALSE
	var/needs_scan = FALSE
	var/ruin_id

/datum/map_template/stationtrauma_space
	should_place_on_top = FALSE

/** Templates initialize their footprint; the traversable vacuum outside it also needs native space gas. */
/datum/map_template/stationtrauma_space/initTemplateBounds(list/bounds)
	if(bounds)
		for(var/z_level in bounds[MAP_MINZ] to bounds[MAP_MAXZ])
			stationtrauma_space_vacuum(z_level)
	return ..()

/** Native ruins and authored destinations need the same traversable vacuum outside their footprint. */
/proc/stationtrauma_space_vacuum(z_level)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/open/space/tile in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		tile.air ||= tile.space_gas
		budget.yield()

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

/** Admin-loaded hulls join the same sector as mapped vessels. */
/proc/load_stationtrauma_space(obj/docking_port/mobile/stationtrauma_space/vessel)
	if(!vessel)
		vessel = load_stationtrauma_space_ship('modular_bandastation/space_overmap/maps/raven.dmm')
	if(!vessel)
		return null
	if(!SSstationtrauma_space_voyage.sector)
		SSstationtrauma_space_voyage.sector = new
		if(!SSstationtrauma_space_voyage.sector.load_locations())
			return null
	return SSstationtrauma_space_voyage.sector.attach(vessel) ? vessel : null
