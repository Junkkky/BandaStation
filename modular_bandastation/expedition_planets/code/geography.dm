/datum/map_generator/expedition_barren
	/// The dominant shapes this profile may roll. A repeated entry carries additional weight.
	var/list/landforms = list("massif", "plateau", "ridge", "rift", "craters")
	/// Material in basins, islands and channels. Dry profiles use their rock unless a wet shape opts in.
	var/basin_type
	/// Material exposed where the surface splits.
	var/rift_type = /turf/open/chasm/true/expedition

/turf/open/chasm/true/expedition
	planetary_atmos = TRUE
	initial_gas_mix = AIRLESS_ATMOS
	baseturfs = /turf/open/chasm/true/expedition

/datum/map_generator/expedition_barren/frozen
	landforms = list("plateau", "ridge", "frozen_lake", "frozen_river", "craters")
	basin_type = /turf/open/misc/ice/expedition

/datum/map_generator/expedition_barren/frozen/plain
	landforms = list("caldera", "islands", "lakes", "river", "branches")
	basin_type = /turf/open/lava/plasma/expedition_frozen

/datum/map_generator/expedition_barren/arid
	landforms = list("dunes", "dunes", "ridge", "massif", "craters", "dry_river", "oasis")
	basin_type = /turf/open/water/expedition_arid

/datum/map_generator/expedition_barren/lush
	landforms = list("river", "branches", "lakes", "ridge", "massif")
	basin_type = /turf/open/water/jungle

/datum/map_generator/expedition_barren/forest
	landforms = list("ridge", "river", "lakes", "massif", "plateau")
	basin_type = /turf/open/water/jungle

/datum/map_generator/expedition_barren/lava
	landforms = list("plateau", "massif", "rift", "caldera", "islands", "lakes", "river", "branches")
	basin_type = /turf/open/lava/smooth/expedition_volcanic
	rift_type = /turf/open/chasm/lavaland/expedition_volcanic

/datum/map_generator/expedition_barren/dead
	landforms = list("rift", "craters", "craters", "dry_river", "massif", "ridge")

/** One large form is broken up by mid-scale terrain and a finer contour. */
/datum/map_generator/expedition_barren/proc/plan_geography()
	var/form = landforms[1 + round(seed / 23) % length(landforms)]
	var/liquid = basin_type || rock_type
	var/angle = seed % 360
	var/x_axis = cos(angle)
	var/y_axis = sin(angle)
	var/cx = round(width * (0.38 + (seed % 13) / 50))
	var/cy = round(width * (0.38 + (round(seed / 13) % 13) / 50))
	var/rx = width * (0.16 + (round(seed / 71) % 9) / 50)
	var/ry = width * (0.14 + (round(seed / 97) % 8) / 50)
	var/river_length = width * (seed % 4 ? 0.91 : 0.32 + (round(seed / 7) % 3) / 18)
	var/river_width = 2 + round(seed / 17) % 4
	var/channel_curvature = 4 + round(seed / 43) % 12
	// a field of small craters, each list(x, y, radius, sinkhole); a large surface has larger ones
	var/list/crater_field = list()
	if(form == "craters")
		var/small_seed = seed % 9973
		for(var/index in 1 to 3 + small_seed % 3)
			var/radius = (8 + (small_seed * (index + 1)) % 9) * width / 128
			var/crater_x = round(width * (0.14 + ((small_seed * (index + 2) * 37) % 72) / 100))
			var/crater_y = round(width * (0.14 + ((small_seed * (index + 5) * 53) % 72) / 100))
			crater_field += list(list(crater_x, crater_y, radius, (small_seed + index) % 3 == 0))
	for(var/y in 3 to width - 2)
		budget?.yield()
		var/dy = y - cy
		var/row = (y - 1) * width
		for(var/x in 3 to width - 2)
			var/dx = x - cx
			var/along = dx * x_axis + dy * y_axis
			var/across = dx * -y_axis + dy * x_axis
			var/middle_noise = surface_noise(100000, x, y, 21) - 0.5
			var/fine_noise = surface_noise(200000, x, y, 6) - 0.5
			var/edge = middle_noise * 0.72 + fine_noise * 0.29
			var/distance = (along / rx) ** 2 + (across / ry) ** 2
			var/terrain
			switch(form)
				if("massif")
					if(distance < 1 + edge && middle_noise + fine_noise * 0.3 > -0.15)
						terrain = rock_type
				if("plateau")
					if(distance < 1 + edge)
						terrain = floor_type
					else if(distance < 1.36 + edge && middle_noise > -0.06)
						terrain = rock_type
				if("ridge", "dunes")
					var/spine = channel_curvature * sin(along * 4 + angle)
					var/deviation = abs(across - spine)
					if(form == "dunes")
						deviation = abs((deviation + 4) % 13 - 6)
					if(abs(along) < width * (0.42 + middle_noise * 0.16) && deviation < (form == "dunes" ? 2 : 7) + edge * 8)
						terrain = rock_type
				if("craters")
					// a crater is a small bowl of the planet's own ground, flora and all, in a ring of rock; a few
					// have a sinkhole at the bottom
					for(var/list/crater as anything in crater_field)
						var/reach = sqrt((x - crater[1]) ** 2 + (y - crater[2]) ** 2) / crater[3] - edge * 0.4
						if(reach >= 1.05)
							continue
						if(reach < 0.3 && crater[4])
							terrain = rift_type
						else if(reach >= 0.8)
							terrain = rock_type
						break
				if("lakes", "frozen_lake", "oasis")
					var/secondary = ((along + rx) / (rx * 0.6)) ** 2 + ((across - ry) / (ry * 0.52)) ** 2
					var/size = form == "oasis" ? 0.25 : 0.79
					if(min(distance, secondary) < size + edge * 0.65)
						terrain = liquid
				if("caldera")
					if(distance < 1.28 + edge && distance > 0.18 + edge * 0.35)
						terrain = liquid
					else if(distance <= 0.18 + edge * 0.35)
						terrain = floor_type
					else if(distance < 1.49 + edge && middle_noise > -0.16)
						terrain = rock_type
				if("islands")
					var/land_height = surface_noise(300000, x, y, width / 3.6) + edge
					if(land_height < 0.44)
						terrain = liquid
					else if(land_height < 0.55)
						terrain = floor_type
				if("river", "branches", "rift", "dry_river", "frozen_river")
					var/curve = sin(along * (3 + seed % 4) + angle) * channel_curvature \
						+ sin(along * 13 - angle) * 3 + middle_noise * 12
					var/distance_to_channel = abs(across - curve)
					if(form == "branches" && along > -4)
						var/tributary = curve + along * (seed % 2 ? 0.6 : -0.6)
						distance_to_channel = min(distance_to_channel, abs(across - tributary))
					var/end_taper = clamp((river_length - abs(along)) / 8, 0, 1)
					var/half_width = max(1, river_width + edge * 7) * end_taper
					if(end_taper && distance_to_channel <= half_width)
						if(form == "rift")
							terrain = rift_type
						else if(form == "dry_river")
							terrain = floor_type
						else
							terrain = liquid
					else if(form == "dry_river" && end_taper && distance_to_channel < half_width + 2 + fine_noise * 3)
						terrain = rock_type
			if(terrain)
				surface_terrain[row + x] = terrain
	// The plasma profile keeps its defining material even on an unusually high island field.
	if(basin_type == /turf/open/lava/plasma/expedition_frozen && !(basin_type in surface_terrain))
		for(var/y in cy - 9 to cy + 9)
			for(var/x in cx - 9 to cx + 9)
				if((x - cx) ** 2 + (y - cy) ** 2 <= 45 + 30 * surface_noise(200000, x, y, 6))
					surface_terrain[(y - 1) * width + x] = basin_type
