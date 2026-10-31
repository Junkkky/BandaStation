// AI EDIT START - space overmap module integration
/*
 * raven.dmm: adapted from local _maps/shuttles/emergency/emergency_raven.dmm, /tg/ contributors, CC BY-SA 3.0.
 */
/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Корабль"
	requires_power = FALSE
	ambientsounds = list(null)
	ambient_buzz = null

/** Mapped expedition area: Raven: изолятор. */
/area/shuttle/stationtrauma_space/brig
	name = "Raven: изолятор"

/** Mapped expedition area: Открытый космос. */
/area/space/stationtrauma_space_home
	name = "Открытый космос"

/** Mapped expedition area: stationtrauma space site. */
/area/stationtrauma_space_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/** Mapped expedition area: Астероидное поле. */
/area/stationtrauma_space_site/asteroid
	name = "Астероидное поле"
	default_gravity = ZERO_GRAVITY
/** Mapped expedition area: Экспедиционная база. */
/area/stationtrauma_space_site/planet
	name = "Экспедиционная база"

/** Mapped expedition area: Дрейфующая грузовая платформа. */
/area/stationtrauma_space_site/cargo
	name = "Дрейфующая грузовая платформа"
	default_gravity = ZERO_GRAVITY

/** Finite emergency construction materials placed on the cargo platform. */
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
	/// Owned virtual navigation instance attached to this physical hull.
	var/datum/stationtrauma_overmap/space/overmap
	/// Navigation metres and heading; physical coordinates are supplied by the native port.
	var/overmap_x = 0
	/// Mapped starting northing in virtual sector units.
	var/overmap_y = 0
	/// Mapped initial compass heading in degrees.
	var/overmap_course = 90
	/// Optional sector site ID to dock at during scenario initialization.
	var/starting_dock
	/// Mapped starting sector ID.
	var/overmap_sector = "epsilon_eridani"
	/// Whether a station terminal may call this idle ship to its berth.
	var/dispatchable = FALSE
	/// Crew main-engine switch; propulsion requires this and intact engines.
	var/engines_running = FALSE
	/// Mapped combustion controller; ordinary ships keep their existing propulsion model.
	var/datum/weakref/combustion_controller
	/// Mapper-declared role; physical berth compatibility still uses the actual hull dimensions.
	var/ship_class = ST_SHIP_MEDIUM
	/// Whether this hull may use planetary surface berths.
	var/can_land = TRUE
	/// Connected transponder consoles; each console unregisters during teardown.
	var/list/transponders = list()

/** Check mapped hull class and landing capability against the destination kind. */
/obj/docking_port/mobile/stationtrauma_space/proc/permits_docking(datum/stationtrauma_overmap_site/space/site)
	if(QDELETED(site))
		return FALSE
	if(ship_class == ST_SHIP_CAPITAL)
		return !site.landing && !site.physical_docking
	return (ship_class == ST_SHIP_SMALL || ship_class == ST_SHIP_MEDIUM) && (!site.landing || can_land)

/** Pair receivers after the native pass has registered every nozzle, regardless of map order. */
/obj/docking_port/mobile/stationtrauma_space/linkup(obj/docking_port/stationary/dock)
	. = ..()
	var/obj/machinery/computer/ship_combustion/chamber = combustion_controller?.resolve()
	chamber?.bind_propulsion()

/obj/docking_port/mobile/stationtrauma_space/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE
	for(var/obj/machinery/computer/stationtrauma_transponder/device as anything in transponders)
		device.vessel = null
	transponders.Cut()
	var/obj/machinery/computer/ship_combustion/chamber = combustion_controller?.resolve()
	chamber?.stop_chamber("Потеря связи с кораблём")
	combustion_controller = null
	QDEL_NULL(overmap)
	return ..()

/** Physical anchor for a destination connected by a remote map seam. */
/obj/docking_port/stationary/stationtrauma_space_site
	name = "Стыковочная площадка"

/** Mapped expedition area: Pocket Rocket. */
/area/shuttle/stationtrauma_space/pocketrocket
	name = "Pocket Rocket"

/** Mapped expedition area: Pocket Rocket: рубка. */
/area/shuttle/stationtrauma_space/pocketrocket/bridge
	name = "Pocket Rocket: рубка"

/** Mapped expedition area: Pocket Rocket: грузовой отсек. */
/area/shuttle/stationtrauma_space/pocketrocket/cargo
	name = "Pocket Rocket: грузовой отсек"

/** Mapped expedition area: Pocket Rocket: жилой отсек. */
/area/shuttle/stationtrauma_space/pocketrocket/crew
	name = "Pocket Rocket: жилой отсек"

/** Mapped expedition area: Pocket Rocket: камбуз. */
/area/shuttle/stationtrauma_space/pocketrocket/crew/canteen
	name = "Pocket Rocket: камбуз"

/** Mapped expedition area: Pocket Rocket: технический отсек. */
/area/shuttle/stationtrauma_space/pocketrocket/maintenance/central
	name = "Pocket Rocket: технический отсек"

/** Space destination with native docking reservation and detection requirements. */
/datum/stationtrauma_overmap_site/space
	/// Navigation instance currently reserving or occupying this site.
	var/datum/stationtrauma_overmap/space/docking_owner
	/// Whether this destination requires a surface landing.
	var/landing = FALSE
	/// Whether arrival moves the physical hull into the native station berth.
	var/physical_docking = FALSE
	/// Whether this site requires a crew-local sensor discovery.
	var/needs_scan = FALSE
	/// Source ruin template ID retained for diagnostics.
	var/ruin_id

/** Ship and destination loader replacing space instead of stacking over it. */
/datum/map_template/stationtrauma_space
	should_place_on_top = FALSE

/** A failed map must release native loading gates before an outer caller handles the failure. */
/datum/parsed_map/load(x_offset = 0, y_offset = 0, z_offset = 0, crop_map = FALSE, no_changeturf = FALSE, x_lower = -INFINITY, x_upper = INFINITY, y_lower = -INFINITY, y_upper = INFINITY, z_lower = -INFINITY, z_upper = INFINITY, place_on_top = FALSE, new_z = FALSE)
	Master.StartLoadingMap()
	try
		. = _load_impl(x_offset, y_offset, z_offset, crop_map, no_changeturf, x_lower, x_upper, y_lower, y_upper, z_lower, z_upper, place_on_top, new_z)
	catch(var/exception/failure)
		SSatoms.map_loader_stop(REF(src))
		loading = FALSE
		bounds = null
		Master.StopLoadingMap()
		log_mapping("Failed to load map [original_path]: [failure] at [failure.file]:[failure.line]")
		return FALSE
	Master.StopLoadingMap()

/// Processing requests for template machines whose pipe networks are not ready yet.
/datum/controller/subsystem/air/var/list/initializing_machines = list()

/** Retain in-flight template requests when SSair is recreated. */
/datum/controller/subsystem/air/Recover()
	initializing_machines = SSair.initializing_machines
	return ..()

/** Keep a new template machine out of the live run until its networks have been built. */
/datum/controller/subsystem/air/start_processing_machine(obj/machinery/machine)
	if(!QDELETED(machine) && !isnull(initializing_machines[machine]))
		initializing_machines[machine] = TRUE
		return
	return ..()

/** Preserve a stop request made during template initialization, including destruction. */
/datum/controller/subsystem/air/stop_processing_machine(obj/machinery/machine)
	if(!isnull(initializing_machines[machine]))
		initializing_machines[machine] = FALSE
	return ..()

/** Native initialization yields before building pipe networks; defer only the newly loaded machines. */
/datum/map_template/initTemplateBounds(list/bounds)
	if(!bounds || !SSatoms.initialized)
		return ..()
	var/list/machines = list()
	for(var/turf/tile as anything in block(bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ], bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]))
		for(var/obj/machinery/machine in tile)
			if(QDELETED(machine) || (machine.flags_1 & INITIALIZED_1) || !isnull(SSair.initializing_machines[machine]))
				continue
			var/was_processing = machine.atmos_processing
			SSair.stop_processing_machine(machine)
			SSair.initializing_machines[machine] = was_processing
			machines += machine
	// An outer catch would bypass SSatoms cleanup when an individual atom fails to initialize.
	. = ..()
	for(var/obj/machinery/machine as anything in machines)
		var/requested = SSair.initializing_machines[machine]
		SSair.initializing_machines -= machine
		if(!QDELETED(src) && requested && !QDELETED(machine))
			SSair.start_processing_machine(machine)

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
// AI EDIT END
