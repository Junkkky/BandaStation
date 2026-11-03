/// A powered compartment and an unmetered engine bay on the same real hull.
/datum/unit_test/overmap_docking/power
	abstract_type = /datum/unit_test/overmap_docking/power

/datum/unit_test/overmap_docking/power/New()
	..()
	hull_area.requires_power = TRUE
	hull_area.power_equip = FALSE
	var/area/shuttle/stationtrauma_space/engine_bay = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += engine_bay
	engine_bay.requires_power = FALSE
	var/turf/bay_tile = get_step(ship, NORTH)
	bay_tile.change_area(get_area(bay_tile), engine_bay)
	ship.shuttle_areas[engine_bay] = TRUE
	navigation.speed = 1
	navigation.velocity_x = 1

/// An unmetered engine bay cannot energize the emergency thrusters of a dead ship grid.
/datum/unit_test/overmap_docking/power/dead_grid

/datum/unit_test/overmap_docking/power/dead_grid/Run()
	TEST_ASSERT(!navigation.command_emergency_brake(), "An unmetered engine bay must not let a hull with a dead equipment grid engage emergency braking")

/// Losing equipment power after the brake order leaves only passive hull drag.
/datum/unit_test/overmap_docking/power/grid_loss

/datum/unit_test/overmap_docking/power/grid_loss/Run()
	hull_area.power_equip = TRUE
	TEST_ASSERT(navigation.command_emergency_brake(), "A live equipment grid must allow emergency braking")
	navigation.integrate_velocity(1, 0)
	var/powered_velocity = navigation.velocity_x
	hull_area.power_equip = FALSE
	navigation.velocity_x = 1
	navigation.integrate_velocity(1, 0)
	var/unpowered_velocity = navigation.velocity_x
	navigation.emergency_braking = FALSE
	navigation.velocity_x = 1
	navigation.integrate_velocity(1, 0)
	TEST_ASSERT_EQUAL(unpowered_velocity, navigation.velocity_x, "An existing emergency-brake order must fall back to passive drag when the equipment grid loses power")
	TEST_ASSERT(unpowered_velocity > powered_velocity, "Live emergency thrusters must decelerate the hull more than passive drag")

/// Hulls entirely configured for unmetered power retain their native free-power behaviour.
/datum/unit_test/overmap_docking/unmetered_power

/datum/unit_test/overmap_docking/unmetered_power/Run()
	hull_area.power_equip = FALSE
	navigation.speed = 1
	navigation.velocity_x = 1
	navigation.integrate_velocity(1, 0)
	var/passive_velocity = navigation.velocity_x
	navigation.velocity_x = 1
	TEST_ASSERT(navigation.command_emergency_brake(), "A hull without any metered compartments must retain free emergency-thruster power")
	navigation.integrate_velocity(1, 0)
	TEST_ASSERT(navigation.velocity_x < passive_velocity, "The free-power hull must actually gain emergency-thruster deceleration")
