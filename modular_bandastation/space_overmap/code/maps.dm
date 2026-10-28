/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Корабль"
	requires_power = FALSE
	ambientsounds = list(null)
	ambient_buzz = null

/area/shuttle/stationtrauma_space/brig
	name = "Raven: изолятор"

/area/space/stationtrauma_space_home
	name = "Открытый космос"

/area/stationtrauma_space_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/area/stationtrauma_space_site/asteroid
	name = "Астероидное поле"
	default_gravity = ZERO_GRAVITY
/area/stationtrauma_space_site/planet
	name = "Экспедиционная база"

/area/stationtrauma_space_site/cargo
	name = "Дрейфующая грузовая платформа"
	default_gravity = ZERO_GRAVITY

/obj/structure/closet/crate/stationtrauma_salvage
	name = "аварийный запас материалов"

/obj/structure/closet/crate/stationtrauma_salvage/PopulateContents()
	new /obj/item/stack/sheet/iron(src, 15)
	new /obj/item/stack/sheet/glass(src, 5)
	new /obj/item/stack/cable_coil(src, 20)

/** Native shuttle hull participating in the overmap. */
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
	var/overmap_sector = "epsilon_eridani"
	var/dispatchable = FALSE
	var/engines_running = FALSE
	/// Mapper-declared role; physical berth compatibility still uses the actual hull dimensions.
	var/ship_class = ST_SHIP_MEDIUM
	var/can_land = TRUE
	var/list/transponders = list()

/obj/docking_port/mobile/stationtrauma_space/proc/permits_docking(datum/stationtrauma_overmap_site/space/site)
	if(QDELETED(site))
		return FALSE
	if(ship_class == ST_SHIP_CAPITAL)
		return !site.landing && !site.physical_docking
	return (ship_class == ST_SHIP_SMALL || ship_class == ST_SHIP_MEDIUM) && (!site.landing || can_land)

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
	/// Whether this destination requires a surface landing.
	var/landing = FALSE
	var/physical_docking = FALSE
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

/** Initialize vacuum outside a loaded template's footprint. */
/proc/stationtrauma_space_vacuum(z_level)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/open/space/tile in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		tile.air ||= tile.space_gas
		budget.yield()

/** Starting EVA and mining equipment. */
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
