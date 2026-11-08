/// Cave connectors must open onto solid ground even when the surrounding biome is lava.
/datum/unit_test/overmap_planet_cave_clearing
	/// Reservation owned by this fixture, independent of the shared test room's floor bounds.
	var/datum/turf_reservation/space
	/// Preserve the reserved turfs even when a failed assertion returns early.
	var/list/original_turfs = list()

/datum/unit_test/overmap_planet_cave_clearing/Destroy()
	for(var/turf/tile as anything in original_turfs)
		var/list/original = original_turfs[tile]
		var/turf/restored = tile.ChangeTurf(original[1], original[2], CHANGETURF_IGNORE_AIR)
		restored.change_area(get_area(restored), original[3])
		if(isopenturf(restored))
			var/turf/open/open_turf = restored
			if(original[4])
				open_turf.copy_air(original[4])
			else
				open_turf.air = null
			restored.air_update_turf(TRUE, TRUE)
	original_turfs.Cut()
	QDEL_NULL(space)
	return ..()

/datum/unit_test/overmap_planet_cave_clearing/Run()
	space = SSmapping.request_turf_block_reservation(4, 1)
	TEST_ASSERT_NOTNULL(space, "The cave clearing fixture needs its own turf reservation.")
	var/turf/clearing_center = space.bottom_left_turfs[1]
	var/turf/clearing_edge = locate(clearing_center.x + 2, clearing_center.y, clearing_center.z)
	var/turf/natural_lava = locate(clearing_center.x + 3, clearing_center.y, clearing_center.z)
	var/datum/map_generator/expedition_barren/lava/generator = allocate(/datum/map_generator/expedition_barren/lava, 1)
	generator.width = 32
	generator.origin_x = clearing_center.x - 7
	generator.origin_y = clearing_center.y - 7
	generator.cave_level = TRUE
	generator.connector_points = list(list(8, 8))
	generator.cave_biome_table = /datum/biome/expedition/volcanic_lava
	// Both pocket outcomes are lava, so this fixture tests clearing safety independently of noise.
	generator.rock_type = /turf/open/lava/smooth/expedition_volcanic
	generator.mineral_chance = 0
	generator.edge_roughness = 0
	var/list/turfs = list(clearing_center, clearing_edge, natural_lava)
	for(var/turf/tile as anything in turfs)
		var/datum/gas_mixture/original_air
		if(isopenturf(tile))
			var/turf/open/open_turf = tile
			if(open_turf.air)
				original_air = allocate(/datum/gas_mixture)
				original_air.copy_from(open_turf.air)
		original_turfs[tile] = list(tile.type, islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs, get_area(tile), original_air)

	generator.generate_terrain(turfs, get_area(clearing_center))

	TEST_ASSERT_EQUAL(clearing_center.type, /turf/open/misc/asteroid/basalt/expedition_volcanic, "The cave connector opens directly onto lava instead of solid volcanic ground.")
	TEST_ASSERT_EQUAL(clearing_edge.type, /turf/open/misc/asteroid/basalt/expedition_volcanic, "The edge of the cave connector clearing must also be solid ground.")
	TEST_ASSERT_EQUAL(natural_lava.type, /turf/open/lava/smooth/expedition_volcanic, "Making a connector clearing safe must preserve the surrounding lava biome.")

/// Profiles populate the real ground with their own fauna, without multiplying summoners into whole packs.
/datum/unit_test/overmap_planet_fauna

/datum/unit_test/overmap_planet_fauna/Run()
	var/turf/centre = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/list/cases = list(
		list(/datum/map_generator/expedition_barren/dead, /datum/biome/expedition/dead, null, 1, 2),
		list(/datum/map_generator/expedition_barren/frozen, /datum/biome/expedition/snow, /mob/living/basic/mining/legion/snow, 1, 1),
		list(/datum/map_generator/expedition_barren/frozen, /datum/biome/expedition/snow, /mob/living/basic/mining/ice_demon, 1, 1),
		list(/datum/map_generator/expedition_barren/arid, /datum/biome/expedition/sand, /mob/living/basic/mining/goliath, 1, 1),
		list(/datum/map_generator/expedition_barren/lava, /datum/biome/expedition/volcanic, /mob/living/basic/mining/legion, 1, 1),
	)
	for(var/list/entry as anything in cases)
		var/datum/map_generator/expedition_barren/generator = allocate(entry[1], 1)
		var/datum/biome/biome = generator.local_biome(entry[2])
		// Remove only the anchor roll and species selection from this small placement fixture.
		biome.fauna_density = 100
		if(entry[3])
			TEST_ASSERT(entry[3] in biome.fauna_types, "The profile no longer offers its expected fauna [entry[3]].")
			biome.fauna_types = list(entry[3])
		var/list/wild = list()
		wild[biome] = list(centre)
		generator.place_packs(wild)
		var/list/creatures = list()
		for(var/turf/tile in RANGE_TURFS(2, centre))
			for(var/mob/living/creature in tile)
				creatures += creature
				allocated += creature
				if(!entry[3])
					TEST_ASSERT(istype(creature, /mob/living/basic/zombie/rotten/expedition), "The dead world spawned [creature.type] instead of its plague carriers.")
		TEST_ASSERT(length(creatures) >= entry[4] && length(creatures) <= entry[5], "[generator.type] spawned [length(creatures)] mobs at a single anchor.")
		QDEL_LIST(creatures)

/// Planetary carcasses use the native bite infection, while the ordinary ruin carcass stays non-infectious.
/datum/unit_test/overmap_planet_zombie_bite

/datum/unit_test/overmap_planet_zombie_bite/Run()
	var/mob/living/basic/zombie/rotten/expedition/carrier = allocate(/mob/living/basic/zombie/rotten/expedition)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(carrier.infection_chance > 0, "The planetary carcass cannot infect through its bites.")
	TEST_ASSERT_EQUAL(/mob/living/basic/zombie/rotten::infection_chance, 0, "The ordinary ruin carcass must stay non-infectious.")
	// Make the bite deterministic; the native infection proc still checks the victim's actual armour and organs.
	carrier.infection_chance = 100
	carrier.melee_attack(victim, ignore_cooldown = TRUE)
	TEST_ASSERT_NOTNULL(victim.get_organ_slot(ORGAN_SLOT_ZOMBIE), "A successful unprotected bite did not insert the native zombie infection.")

/// Orbital artwork follows proximity and manoeuvre state without replacing the moving native space field.
/datum/unit_test/overmap_docking/orbital_parallax

/datum/unit_test/overmap_docking/orbital_parallax/Run()
	var/datum/stationtrauma_overmap_site/space/planet/planet = allocate(/datum/stationtrauma_overmap_site/space/planet)
	planet.id = "unit_test_planet"
	planet.pos_x = navigation.pos_x + 500
	planet.pos_y = navigation.pos_y
	navigation.sites[planet.id] = planet
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A distant world must not appear behind the ship")
	planet.pos_x = navigation.pos_x + 100
	TEST_ASSERT_EQUAL(navigation.parallax_planet(), planet.parallax_layer, "A nearby charted world must appear without loading its surface")
	planet.discovered = FALSE
	TEST_ASSERT_NULL(navigation.parallax_planet(), "The background must not disclose an undiscovered world")
	planet.discovered = TRUE
	planet.failed = TRUE
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A failed destination must not leave an orbital image")
	planet.failed = FALSE
	navigation.speed = 1
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, planet.parallax_layer, "The ship must publish its nearby world to the viewers' area")
	TEST_ASSERT_EQUAL(hull_area.parallax_movedir, ship.preferred_direction, "The ordinary space layers must keep scrolling beside a fixed planet")
	TEST_ASSERT_EQUAL(navigation.parallax_background(), /atom/movable/screen/parallax_layer/layer_3, "An orbital world must not replace the native star field")
	var/datum/stationtrauma_overmap_site/space/planet/frozen/ice = allocate(/datum/stationtrauma_overmap_site/space/planet/frozen)
	ice.id = "unit_test_ice"
	ice.pos_x = navigation.pos_x + 90
	ice.pos_y = navigation.pos_y
	navigation.sites[ice.id] = ice
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, ice.parallax_layer, "A different nearest biome must update even when motion and star field stay the same")
	ice.failed = TRUE
	navigation.jump_phase = HYPERSPACE_LAUNCH
	navigation.update_parallax()
	TEST_ASSERT_NULL(hull_area.space_parallax_planet, "A departing bluespace jump must remove the orbital world")
	navigation.jump_phase = NONE
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, planet.parallax_layer, "Cancelling or finishing a jump near the world must restore its image")
	planet.pos_x = navigation.pos_x + 500
	navigation.approach_site = planet
	navigation.approach_started = world.time
	TEST_ASSERT_EQUAL(navigation.parallax_planet(), planet.parallax_layer, "The current descent keeps its world throughout the approach")
	planet.berth = bay
	TEST_ASSERT_NULL(navigation.parallax_planet(), "The world must disappear when the hull reaches its physical surface level")
	navigation.approach_departing = TRUE
	TEST_ASSERT_EQUAL(navigation.parallax_planet(), planet.parallax_layer, "Ascent must restore the fixed world while space scrolls")
	navigation.approach_site = null
	navigation.approach_started = 0
	navigation.approach_departing = FALSE
	navigation.docked = planet
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A landed hull must not see its entire world in the sky")
	planet.berth = null
	planet.pos_x = navigation.pos_x + 100
	navigation.docked = site
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A physical station berth must retain its own background")
	navigation.docked = null
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, planet.parallax_layer, "Leaving the physical berth restores a nearby world")
	planet.pos_x = navigation.pos_x + 500
	navigation.update_parallax()
	TEST_ASSERT_NULL(hull_area.space_parallax_planet, "Leaving orbital range must clear the cached world")
	TEST_ASSERT_NULL(exterior.space_parallax_planet, "The empty flight level must clear the same orbital profile")
