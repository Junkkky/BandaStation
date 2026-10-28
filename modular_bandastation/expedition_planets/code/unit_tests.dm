/obj/machinery/atmospherics/pipe/smart/simple/general/visible/expedition/test_straight
	initialize_directions = NORTH | SOUTH

/obj/machinery/atmospherics/pipe/smart/simple/general/visible/expedition/test_corner
	initialize_directions = NORTH | EAST

/datum/unit_test/expedition_pipe_ports/Run()
	for(var/pipe_type in list(/obj/machinery/atmospherics/pipe/smart/simple/general/visible/expedition/test_straight, /obj/machinery/atmospherics/pipe/smart/simple/general/visible/expedition/test_corner))
		var/obj/machinery/atmospherics/pipe/pipe = new pipe_type
		if(pipe.initialize_directions != initial(pipe.initialize_directions))
			Fail("Imported pipe [pipe_type] lost its authored ports during initialization", __FILE__, __LINE__)
		qdel(pipe)

/datum/unit_test/expedition_planet_terrain/Run()
	for(var/profile in list(/datum/map_generator/expedition_barren, /datum/map_generator/expedition_barren/frozen, /datum/map_generator/expedition_barren/arid, /datum/map_generator/expedition_barren/lush))
		for(var/seed in list(1, 12345, 999999))
			var/datum/map_generator/expedition_barren/first = new profile(seed)
			var/datum/map_generator/expedition_barren/repeated = new profile(seed)
			var/datum/map_generator/expedition_barren/other = new profile(seed + 1)
			var/differences = 0
			var/minerals = 0
			for(var/x in 3 to 94 step 6)
				for(var/y in 3 to 94 step 6)
					var/terrain = first.terrain_at(x, y)
					if(terrain != repeated.terrain_at(x, y))
						Fail("Planet [profile] seed [seed] does not reproduce terrain at [x],[y]", __FILE__, __LINE__)
					differences += terrain != other.terrain_at(x, y)
					minerals += ispath(terrain, /turf/closed/mineral)
			if(!differences || !minerals)
				Fail("Planet [profile] seed [seed] lacks varied mineable terrain", __FILE__, __LINE__)
			first.camp_x = 21
			first.camp_y = 27
			first.camp_width = 56
			first.camp_height = 44
			for(var/x in 21 to 76)
				for(var/y in 27 to 70)
					if(first.terrain_at(x, y) != first.floor_type)
						Fail("Planet [profile] seed [seed] obstructs its reserved camp", __FILE__, __LINE__)
			var/middle = round(first.width / 2)
			for(var/offset in 3 to first.width - 2)
				if(first.terrain_at(middle, offset) != first.floor_type || first.terrain_at(offset, middle) != first.floor_type)
					Fail("Planet [profile] seed [seed] blocks a field approach", __FILE__, __LINE__)
			if(first.terrain_at(1, middle) != /turf/closed/indestructible/rock || first.terrain_at(first.width, middle) != /turf/closed/indestructible/rock)
				Fail("Planet [profile] seed [seed] exposes the map edge", __FILE__, __LINE__)
			qdel(first)
			qdel(repeated)
			qdel(other)

/datum/unit_test/expedition_frozen_terrain/Run()
	for(var/seed in list(1, 12345, 999999))
		var/datum/map_generator/expedition_barren/frozen/generator = new(seed)
		var/datum/map_generator/expedition_barren/frozen/repeated = new(seed)
		var/lakes = 0
		var/mountains = 0
		var/ores = 0
		for(var/x in 3 to 94 step 2)
			for(var/y in 3 to 94 step 2)
				var/terrain = generator.terrain_at(x, y)
				if(terrain != repeated.terrain_at(x, y))
					Fail("Frozen seed [seed] does not reproduce terrain at [x],[y]", __FILE__, __LINE__)
				lakes += terrain == /turf/open/misc/ice/expedition
				mountains += terrain == /turf/closed/mineral/snowmountain
				ores += terrain == /turf/closed/mineral/iron/ice
		if(!lakes || !mountains || !ores || ores >= mountains / 10)
			Fail("Frozen seed [seed] lacks ice, rock or sparse ore: [lakes]/[mountains]/[ores]", __FILE__, __LINE__)
		generator.camp_x = generator.camp_y = 21
		generator.camp_width = generator.camp_height = 56
		for(var/x in 21 to 76)
			for(var/y in 21 to 76)
				if(generator.terrain_at(x, y) != generator.floor_type)
					Fail("Frozen seed [seed] obstructs its reserved landing region", __FILE__, __LINE__)
		var/middle = round(generator.width / 2)
		for(var/offset in 3 to generator.width - 2)
			if(generator.terrain_at(middle, offset) != generator.floor_type || generator.terrain_at(offset, middle) != generator.floor_type)
				Fail("Frozen seed [seed] blocks a field approach", __FILE__, __LINE__)
		if(generator.terrain_at(1, middle) != /turf/closed/indestructible/rock)
			Fail("Frozen seed [seed] exposes the map edge", __FILE__, __LINE__)
		qdel(generator)
		qdel(repeated)
	var/datum/stationtrauma_overmap_site/space/planet/frozen/planet = new
	var/list/survey = planet.survey_data()
	if(survey["temperature"] != ICEBOX_MIN_TEMPERATURE)
		Fail("Frozen survey or generator disagrees with its native environment", __FILE__, __LINE__)
	qdel(planet)

/datum/unit_test/expedition_ruin_footprints/Run()
	for(var/profile in list(/datum/map_generator/expedition_barren, /datum/map_generator/expedition_barren/frozen, /datum/map_generator/expedition_barren/arid, /datum/map_generator/expedition_barren/lush))
		var/datum/map_generator/expedition_barren/generator = new profile(12345)
		generator.ruin_bounds = list(list(70, 5, 119, 54), list(5, 70, 44, 108), list(70, 70, 99, 99))
		for(var/list/bounds as anything in generator.ruin_bounds)
			for(var/x in bounds[1] - 1 to bounds[3] + 1)
				for(var/y in bounds[2] - 1 to bounds[4] + 1)
					if(generator.terrain_at(x, y) != generator.floor_type)
						Fail("Planet [profile] obstructs a reserved ruin at [x],[y]", __FILE__, __LINE__)
			var/row = round((bounds[2] + bounds[4]) / 2)
			for(var/x in min(round(generator.width / 2), bounds[1]) to max(round(generator.width / 2), bounds[3]))
				if(generator.terrain_at(x, row) != generator.floor_type)
					Fail("Planet [profile] obstructs a ruin approach at [x],[row]", __FILE__, __LINE__)
		qdel(generator)
