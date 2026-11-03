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
