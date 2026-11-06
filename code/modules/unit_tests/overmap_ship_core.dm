/// A built frame registers through the matching core and makes its first ordinary departure.
/datum/unit_test/overmap_ship_core
	/// The core and declared ship class expected for this frame.
	var/core_type = /obj/machinery/computer/stationtrauma_ship_core
	/// Vessel class assigned by the registered core.
	var/expected_class = "small"
	/// Extents of the native test frame.
	var/frame_width = 4
	var/frame_height = 4
	/// Player-built hull created by the core.
	var/obj/docking_port/mobile/stationtrauma_space/player/ship
	/// The synthetic construction area must stop counting as a station after the test.
	var/datum/space_level/station_level
	/// The native frame owns turf registrations that must be removed before deletion.
	var/datum/shuttle_frame/frame
	/// Original sector, restored when the test finishes.
	var/datum/stationtrauma_overmap_sector/space/home/original_sector
	/// Isolated home sector for the commissioning attempt.
	var/datum/stationtrauma_overmap_sector/space/home/sector
	/// Native ID counters persist after a test port is deleted.
	var/list/stationary_ids
	/// Native ID counters persist after a test ship is deleted.
	var/list/mobile_ids

/datum/unit_test/overmap_ship_core/Run()
	stationary_ids = SSshuttle.assoc_stationary.Copy()
	mobile_ids = SSshuttle.assoc_mobile.Copy()
	original_sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	sector = allocate(/datum/stationtrauma_overmap_sector/space/home)
	sector.ready = TRUE
	SSstationtrauma_space_voyage.sectors["epsilon_eridani"] = sector
	station_level = SSmapping.add_new_zlevel("Ship core test station", list(ZTRAIT_STATION = TRUE))
	var/station_z = station_level.z_value
	var/hatch_x = 4 + frame_width - 1
	var/list/frame_turfs = list()
	for(var/turf/tile as anything in block(locate(4, 4, station_z), locate(hatch_x, 4 + frame_height - 1, station_z)))
		frame_turfs += tile.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
	frame = allocate(/datum/shuttle_frame, frame_turfs)
	var/turf/origin = locate(4, 4, station_z)
	var/obj/machinery/computer/stationtrauma_ship_core/core = allocate(core_type, origin)
	var/mob/living/carbon/human/consistent/builder = allocate(/mob/living/carbon/human/consistent, locate(5, 4, station_z))
	var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch = allocate(/obj/machinery/door/airlock/stationtrauma_docking/ship, locate(hatch_x, 5, station_z))
	hatch.setDir(WEST)
	TEST_ASSERT_NULL(core.commission(builder), "An inward hatch must prevent registering a new hull")
	TEST_ASSERT_NULL(SSshuttle.get_containing_shuttle(core), "A rejected frame must remain unregistered")
	hatch.setDir(EAST)
	var/obj/machinery/computer/stationtrauma_space_navigation/helm = allocate(/obj/machinery/computer/stationtrauma_space_navigation, locate(4, 5, station_z))
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, locate(4, 6, station_z))
	engine.anchored = TRUE
	engine.on_construction(builder)
	engine.engine_state = initial(engine.engine_state)
	var/turf/vacuum = locate(hatch_x + 1, 5, station_z)
	var/area/station_vacuum = get_area(vacuum)
	ship = core.commission(builder)
	if(!ship)
		ship = SSshuttle.get_containing_shuttle(core)
		TEST_FAIL("A completed native frame with an outward hatch must register")
		return
	TEST_ASSERT_EQUAL(get_area(vacuum), station_vacuum, "Registering a ship must preserve station vacuum")
	TEST_ASSERT_EQUAL(ship.ship_class, expected_class, "The core must register the hull with its declared ship class")
	TEST_ASSERT_EQUAL(helm.vessel, ship, "Registration must connect the built helm")
	TEST_ASSERT_EQUAL(length(ship.engine_list), 1, "Registration must link the built engine exactly once")
	var/datum/stationtrauma_overmap/space/navigation = ship.overmap
	TEST_ASSERT_NOTNULL(navigation?.docked, "The new hull must start at its private construction berth")
	TEST_ASSERT_NOTEQUAL(navigation.flight_berth.z, station_z, "The flight berth must be on a dedicated level")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The commissioned hull must have its fitted engine")
	TEST_ASSERT(navigation.depart(instant = TRUE), "The new hull must be able to take off through normal navigation")
	TEST_ASSERT_EQUAL(get_turf(ship), get_turf(navigation.flight_berth), "The first departure must move the hull to its flight level")
	TEST_ASSERT_NULL(locate(/obj/docking_port/stationary/stationtrauma_space_construction) in origin, "Departure must release the temporary construction berth")

/// A complete 475-tile M hull can register even above the ordinary shuttle construction cap.
/datum/unit_test/overmap_ship_core/medium
	core_type = /obj/machinery/computer/stationtrauma_ship_core/medium
	expected_class = "medium"
	frame_width = 19
	frame_height = 25

/datum/unit_test/overmap_ship_core/Destroy()
	if(frame)
		frame.remove_turfs(frame.turfs.Copy())
		frame = null
	if(!QDELETED(ship))
		qdel(ship, force = TRUE)
	ship = null
	if(sector)
		if(original_sector)
			SSstationtrauma_space_voyage.sectors["epsilon_eridani"] = original_sector
		else
			SSstationtrauma_space_voyage.sectors -= "epsilon_eridani"
		sector = null
	if(station_level)
		var/station_z = station_level.z_value
		station_level.traits -= ZTRAIT_STATION
		var/list/station_levels = SSmapping.z_trait_levels[ZTRAIT_STATION]
		station_levels -= list(station_z)
		GLOB.station_levels_cache[station_z] = null
		station_level = null
	SSshuttle.assoc_stationary = stationary_ids
	SSshuttle.assoc_mobile = mobile_ids
	return ..()
