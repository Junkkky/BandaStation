/// Pause the real native preflight at a deterministic point; retain all movement and occupancy checks.
/obj/docking_port/mobile/stationtrauma_space/unit_test_docking
	width = 2
	height = 3
	var/datum/callback/preflight_action

/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/preflight_check(list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, rotation)
	. = ..()
	if(. || !preflight_action)
		return
	var/datum/callback/action = preflight_action
	preflight_action = null
	sleep(0)
	action.Invoke()

/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/Destroy(force)
	preflight_action = null
	return ..()

/// A small real shuttle and two physical berths, without loading a map template.
/area/space/stationtrauma_space_home/unit_test_docking
	area_flags_mapping = NONE

/area/shuttle/stationtrauma_space/unit_test_docking
	area_flags_mapping = NONE

/datum/unit_test/overmap_docking
	abstract_type = /datum/unit_test/overmap_docking
	var/datum/turf_reservation/space
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/ship
	var/obj/docking_port/stationary/stationtrauma_space_station/bay
	var/obj/docking_port/stationary/home
	var/datum/stationtrauma_overmap/space/navigation
	var/datum/stationtrauma_overmap_site/space/site
	var/area/space/stationtrauma_space_home/exterior
	var/area/shuttle/stationtrauma_space/hull_area
	var/list/stationary_ids
	var/list/mobile_ids
	var/list/original_areas = list()

/datum/unit_test/overmap_docking/New()
	..()
	stationary_ids = SSshuttle.assoc_stationary.Copy()
	mobile_ids = SSshuttle.assoc_mobile.Copy()
	space = SSmapping.request_turf_block_reservation(18, 10)
	exterior = new /area/space/stationtrauma_space_home/unit_test_docking
	hull_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += exterior
	allocated += hull_area
	for(var/turf/tile as anything in space.reserved_turfs)
		original_areas[tile] = get_area(tile)
		tile.change_area(get_area(tile), exterior)
	var/turf/corner = space.bottom_left_turfs[1]
	var/turf/anchor = locate(corner.x + 2, corner.y + 2, corner.z)
	for(var/turf/tile as anything in block(anchor, locate(anchor.x + 1, anchor.y + 2, anchor.z)))
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), hull_area)
	anchor = locate(corner.x + 2, corner.y + 2, corner.z)
	ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, anchor, list(hull_area))
	ship.register()
	for(var/turf/tile as anything in ship.return_ordered_turfs(ship.x, ship.y, ship.z, ship.dir))
		TEST_ASSERT_EQUAL(get_area(tile), hull_area, "Every fixture hull tile must belong to the shuttle area")
		ship.underlying_areas_by_turf[tile] = exterior
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, anchor)
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, ship)
	navigation = allocate(/datum/stationtrauma_overmap/space, ship)
	ship.overmap = navigation
	STOP_PROCESSING(SSfastprocess, navigation)
	navigation.exterior = exterior
	navigation.preparing = FALSE
	var/turf/destination = locate(corner.x + 11, corner.y + 5, corner.z)
	bay = allocate(/obj/docking_port/stationary/stationtrauma_space_station, destination)
	bay.width = ship.width
	bay.height = ship.height
	bay.setDir(EAST)
	home = allocate(/obj/docking_port/stationary, destination)
	site = allocate(/datum/stationtrauma_overmap_site/space)
	site.id = "unit_test_dock"
	site.name = "Unit test bay"
	site.physical_docking = TRUE
	site.berth = bay
	site.pos_x = navigation.pos_x
	site.pos_y = navigation.pos_y
	navigation.sites[site.id] = site
	navigation.selected_destination = site.id
	navigation.prepared_site = site

/datum/unit_test/overmap_docking/Destroy()
	qdel(navigation)
	qdel(ship, force = TRUE)
	qdel(bay, force = TRUE)
	qdel(home, force = TRUE)
	// Native registration keeps counters after ports are deleted.
	SSshuttle.assoc_stationary = stationary_ids
	SSshuttle.assoc_mobile = mobile_ids
	stationary_ids = null
	mobile_ids = null
	navigation = null
	ship = null
	bay = null
	home = null
	site = null
	for(var/turf/tile as anything in original_areas)
		tile.change_area(get_area(tile), original_areas[tile])
	original_areas.Cut()
	qdel(space)
	space = null
	return ..()

/datum/unit_test/overmap_docking/engine_stop
	var/interrupted = FALSE
	var/revision_after_stop

/datum/unit_test/overmap_docking/engine_stop/Run()
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The real engine must start before docking")
	ship.preflight_action = CALLBACK(src, PROC_REF(stop_during_preflight))
	var/result = navigation.dock()
	TEST_ASSERT(interrupted, "The stop action must execute while native relocation is suspended")
	TEST_ASSERT(!ship.engines_running, "Emergency engine shutdown must remain effective during relocation")
	TEST_ASSERT_EQUAL(ship.get_docked(), bay, "Native docking must actually move the hull into the bay")
	TEST_ASSERT_EQUAL(navigation.docked, site, "A committed physical arrival must retain its dock state despite a newer helm revision")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "The physically occupied site must remain owned")
	TEST_ASSERT(result, "Committed docking must report success")
	TEST_ASSERT_EQUAL(navigation.control_revision, revision_after_stop, "Arrival must not overwrite the stop action with another helm order")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The engine must be restartable after docking")
	TEST_ASSERT(navigation.sail(), "Departure after the interrupted arrival must remain possible")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Departure must physically return the hull to flight space")
	TEST_ASSERT_NULL(navigation.docked, "Departure must clear the virtual dock")
	TEST_ASSERT_NULL(site.docking_owner, "Departure must release site ownership")

/datum/unit_test/overmap_docking/engine_stop/proc/stop_during_preflight()
	TEST_ASSERT(navigation.relocating && navigation.preparing, "The callback must run within native docking")
	interrupted = TRUE
	TEST_ASSERT(navigation.set_engines_running(FALSE), "Emergency stop must be accepted during native docking")
	revision_after_stop = navigation.control_revision
	TEST_ASSERT(!navigation.dock(), "A repeated dock request cannot start another relocation")
	TEST_ASSERT(!navigation.sail(), "Departure cannot race an unfinished native relocation")
	TEST_ASSERT(!navigation.select_site("missing"), "Selection cannot change during native relocation")

/datum/unit_test/overmap_docking/blocked_preflight
	var/obj/item/blocker

/datum/unit_test/overmap_docking/blocked_preflight/Run()
	ship.preflight_action = CALLBACK(src, PROC_REF(block_during_preflight))
	var/result = navigation.dock()
	TEST_ASSERT_NOTNULL(blocker, "The blocking action must execute during real native preflight")
	TEST_ASSERT(!result, "A destination occupied during yielding preflight must reject the arrival")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Rejected arrival must leave the physical hull at its old berth")
	TEST_ASSERT_NULL(navigation.docked, "Rejected arrival cannot publish a dock")
	TEST_ASSERT_NULL(site.docking_owner, "Rejected arrival must release its reservation")
	TEST_ASSERT_EQUAL(get_turf(blocker), get_turf(bay), "The late blocker must not be moved or crushed")

/datum/unit_test/overmap_docking/blocked_preflight/proc/block_during_preflight()
	blocker = allocate(/obj/item, get_turf(bay))

/datum/unit_test/overmap_docking/evacuation

/datum/unit_test/overmap_docking/evacuation/Run()
	TEST_ASSERT(navigation.dock(), "The expedition ship must first physically dock at the shared bay")
	var/turf/old_flight_anchor = get_turf(navigation.flight_berth)
	var/obj/item/blocker = allocate(/obj/item, old_flight_anchor)
	var/mob/living/carbon/human/consistent/eva = allocate(/mob/living/carbon/human/consistent, old_flight_anchor)
	ADD_TRAIT(eva, TRAIT_GODMODE, TRAIT_GENERIC)
	var/old_health = eva.health
	var/old_maxz = world.maxz
	TEST_ASSERT(!ship.check_dock(navigation.flight_berth, TRUE), "The abandoned flight footprint must actually block native return")
	TEST_ASSERT_EQUAL(SSshuttle.emergency.canDock(home), SHUTTLE_SOMEONE_ELSE_DOCKED, "The emergency shuttle must not crush the expedition hull")
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "Service departure must finish within its bounded search")
	TEST_ASSERT_NULL(home.get_docked(), "Evacuation must clear the shared bay even when the old flight footprint is occupied")
	TEST_ASSERT_EQUAL(SSshuttle.emergency.canDock(home), SHUTTLE_CAN_DOCK, "The evacuation shuttle must be allowed to arrive after the service departure")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Service departure must move the hull to its retained flight berth")
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "An available berth on the existing flight level must not allocate another z-level")
	TEST_ASSERT_NULL(navigation.docked, "Service departure must release the virtual dock")
	TEST_ASSERT_NULL(site.docking_owner, "Service departure must release site ownership")
	TEST_ASSERT_NULL(navigation.selected_destination, "Service departure must clear the old arrival order")
	TEST_ASSERT(!QDELETED(eva) && get_turf(eva) == old_flight_anchor && eva.health == old_health, "The stranded EVA occupant must remain alive and unmoved")
	TEST_ASSERT(!QDELETED(blocker) && get_turf(blocker) == old_flight_anchor, "The item left outside must remain intact and unmoved")
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "Repeated evacuation attempts must not allocate new space")

/datum/unit_test/overmap_docking/no_safe_berth/Run()
	TEST_ASSERT(navigation.dock(), "The expedition ship must first dock at the shared bay")
	var/turf/original_position = get_turf(navigation.flight_berth)
	var/old_maxz = world.maxz
	var/list/blockers = list()
	for(var/turf/tile as anything in space.reserved_turfs)
		if(get_area(tile) == exterior)
			var/obj/item/blocker = allocate(/obj/item, tile)
			blockers[blocker] = tile
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "An exhausted search must release its preparation lock")
	TEST_ASSERT_EQUAL(home.get_docked(), ship, "With no safe destination the expedition hull must stay at the bay")
	TEST_ASSERT_EQUAL(get_turf(navigation.flight_berth), original_position, "An exhausted search must restore the old flight marker")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A failed departure cannot release the occupied site")
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "An exhausted search must not grow world.maxz on retries")
	for(var/obj/item/blocker as anything in blockers)
		TEST_ASSERT(!QDELETED(blocker) && get_turf(blocker) == blockers[blocker], "Searching for a berth must preserve every blocking object")

/datum/unit_test/overmap_docking/service_preflight_blocked
	var/obj/item/late_blocker
	var/turf/rejected_position

/datum/unit_test/overmap_docking/service_preflight_blocked/Run()
	TEST_ASSERT(navigation.dock(), "The expedition ship must first dock at the shared bay")
	var/turf/original_position = get_turf(navigation.flight_berth)
	allocate(/obj/item, original_position)
	ship.preflight_action = CALLBACK(src, PROC_REF(block_service_departure))
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "A rejected service departure must release its preparation lock")
	TEST_ASSERT_NOTNULL(late_blocker, "The new service berth must reach native yielding preflight")
	TEST_ASSERT_NOTEQUAL(rejected_position, original_position, "The service departure must have found an alternative berth")
	TEST_ASSERT_EQUAL(home.get_docked(), ship, "A late blocker must keep the hull at the original bay")
	TEST_ASSERT_EQUAL(get_turf(navigation.flight_berth), original_position, "Failed physical relocation must restore the old flight marker")
	TEST_ASSERT_EQUAL(navigation.docked, site, "A failed service departure must retain its dock state")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A failed service departure must retain ownership")
	TEST_ASSERT(!QDELETED(late_blocker) && get_turf(late_blocker) == rejected_position, "Late occupants must not be crushed or moved")

/datum/unit_test/overmap_docking/service_preflight_blocked/proc/block_service_departure()
	TEST_ASSERT(navigation.relocating && navigation.preparing, "The callback must run during the service departure")
	rejected_position = get_turf(navigation.flight_berth)
	late_blocker = allocate(/obj/item, rejected_position)
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	TEST_ASSERT_EQUAL(home.get_docked(), ship, "Repeated evacuation cannot start a second relocation during preflight")

/// A service departure must leave the ship able to visit a virtual site through a real map seam.
/datum/unit_test/overmap_docking/evacuation_then_virtual_dock
	var/list/borrowed_turfs = list()
	var/obj/docking_port/stationary/virtual_berth

/datum/unit_test/overmap_docking/evacuation_then_virtual_dock/Destroy()
	// Remove passages, previews and the moved hull before restoring their borrowed coordinates.
	qdel(navigation)
	qdel(ship, force = TRUE)
	qdel(virtual_berth, force = TRUE)
	virtual_berth = null
	for(var/turf/tile as anything in borrowed_turfs)
		var/list/original = borrowed_turfs[tile]
		tile = tile.ChangeTurf(original[1], original[2])
		tile.change_area(get_area(tile), original[3])
		tile.turf_flags = original[4]
		if(isopenturf(tile))
			var/turf/open/open_tile = tile
			open_tile.destination_x = original[5]
			open_tile.destination_y = original[6]
			open_tile.destination_z = original[7]
	borrowed_turfs.Cut()
	return ..()

/datum/unit_test/overmap_docking/evacuation_then_virtual_dock/proc/borrow_space(turf/tile, add_to_exterior = FALSE)
	var/turf/open/open_tile = isopenturf(tile) ? tile : null
	if(!borrowed_turfs[tile])
		borrowed_turfs[tile] = list(tile.type, islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs, get_area(tile), tile.turf_flags, open_tile?.destination_x, open_tile?.destination_y, open_tile?.destination_z)
	if(!isspaceturf(tile))
		tile = tile.ChangeTurf(/turf/open/space)
	open_tile = tile
	open_tile.destination_x = 0
	open_tile.destination_y = 0
	open_tile.destination_z = 0
	if(add_to_exterior)
		tile.change_area(get_area(tile), exterior)

/datum/unit_test/overmap_docking/evacuation_then_virtual_dock/Run()
	TEST_ASSERT(navigation.dock(), "The expedition hull must first dock at the shared bay")
	var/turf/original_flight = get_turf(navigation.flight_berth)
	var/obj/item/blocker = allocate(/obj/item, original_flight)
	// Restrict this test's exterior to two real positions, with the world-edge candidate first.
	for(var/turf/tile as anything in space.reserved_turfs)
		if(get_area(tile) == exterior)
			tile.change_area(exterior, original_areas[tile])
	var/flight_z = original_flight.z
	var/remote_z = run_loc_floor_bottom_left.z
	TEST_ASSERT_NOTEQUAL(flight_z, remote_z, "A virtual site must be on another physical level")
	// x < SHUTTLE_TRANSIT_BORDER is outside every reservation, so these cells have no other owner.
	for(var/anchor_x in list(1, 12))
		for(var/turf/tile as anything in block(locate(anchor_x, 32, flight_z), locate(anchor_x + 1, 34, flight_z)))
			TEST_ASSERT_NULL(SSmapping.used_turfs[tile], "Borrowed flight cells must not belong to another reservation")
			borrow_space(tile, TRUE)
	// Native seams span the entire level. Prepare and later restore both real gate/landing columns.
	for(var/gate_z in list(flight_z, remote_z))
		for(var/turf/tile as anything in block(locate(10, 1, gate_z), locate(11, world.maxy, gate_z)))
			borrow_space(tile)
	virtual_berth = allocate(/obj/docking_port/stationary/stationtrauma_space_site, locate(10, 32, remote_z))
	var/datum/stationtrauma_overmap_site/space/virtual_site = allocate(/datum/stationtrauma_overmap_site/space)
	virtual_site.id = "unit_test_virtual_dock"
	virtual_site.name = "Unit test virtual site"
	virtual_site.berth = virtual_berth
	virtual_site.pos_x = navigation.pos_x
	virtual_site.pos_y = navigation.pos_y
	navigation.sites[virtual_site.id] = virtual_site
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "Service departure must complete")
	TEST_ASSERT_NULL(home.get_docked(), "The shared bay must be physically vacated")
	TEST_ASSERT(!QDELETED(blocker) && get_turf(blocker) == original_flight, "The original flight blocker must stay intact")
	TEST_ASSERT(navigation.select_site(virtual_site.id), "The crew must be able to select a virtual destination after evacuation")
	TEST_ASSERT(navigation.dock(), "The post-evacuation hull position must permit a real virtual-site seam")
	TEST_ASSERT(navigation.connection.active, "The post-evacuation seam must publish its passages")
	var/obj/item/coin/traveller = allocate(/obj/item/coin, locate(11, 32, flight_z))
	TEST_ASSERT(traveller.Move(locate(10, 32, flight_z)), "The traveller must enter the actual ship-side passage")
	deadline = world.time + 5 SECONDS
	UNTIL(traveller.z == remote_z || world.time >= deadline)
	TEST_ASSERT_EQUAL(get_turf(traveller), locate(10, 32, remote_z), "The published seam must transport the traveller to the virtual site")
