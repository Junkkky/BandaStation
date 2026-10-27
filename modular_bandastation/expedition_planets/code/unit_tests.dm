/datum/unit_test/expedition_planet_terrain/Run()
	for(var/seed in list(1, 12345, 999999))
		var/datum/map_generator/expedition_barren/first = new(seed)
		var/datum/map_generator/expedition_barren/repeated = new(seed)
		var/datum/map_generator/expedition_barren/other = new(seed + 1)
		var/differences = 0
		var/minerals = 0
		for(var/x in 3 to 94 step 6)
			for(var/y in 3 to 94 step 6)
				var/terrain = first.terrain_at(x, y)
				if(terrain != repeated.terrain_at(x, y))
					Fail("Planet seed [seed] does not reproduce its terrain at [x],[y]", __FILE__, __LINE__)
				differences += terrain != other.terrain_at(x, y)
				minerals += ispath(terrain, /turf/closed/mineral)
		if(!differences || !minerals)
			Fail("Planet seed [seed] lacks varied mineable terrain", __FILE__, __LINE__)
		first.camp_x = 21
		first.camp_y = 27
		first.camp_width = 56
		first.camp_height = 44
		for(var/x in 21 to 76)
			for(var/y in 27 to 70)
				if(first.terrain_at(x, y) != /turf/open/misc/asteroid/airless)
					Fail("Planet seed [seed] generated an obstacle in its reserved camp", __FILE__, __LINE__)
		for(var/offset in 3 to 94)
			if(first.terrain_at(48, offset) != /turf/open/misc/asteroid/airless || first.terrain_at(offset, 48) != /turf/open/misc/asteroid/airless)
				Fail("Planet seed [seed] blocked a reserved field approach", __FILE__, __LINE__)
		if(first.terrain_at(1, 48) != /turf/closed/indestructible/rock || first.terrain_at(96, 48) != /turf/closed/indestructible/rock)
			Fail("Planet seed [seed] exposes the map edge", __FILE__, __LINE__)
		qdel(first)
		qdel(repeated)
		qdel(other)
