/// Share of a compartment's floor in vacuum that marks it depressurised; airlock chambers and nozzles stay below it.
#define COMPARTMENT_DEPRESSURISED_SHARE 0.25

/area/shuttle/stationtrauma_space
	/// Mapped airless (external airlock chambers): never reported as depressurised.
	var/vacuum_by_design = FALSE

/**
 * Per-compartment damage summary for the helm, read from the physical hull: mean pressure, open fire, tiles open to space.
 * shortcut: scans the hull footprint on every UI refresh (~1 ms for Raven's 672 tiles); cache per tick once capital hulls exist.
 */
/obj/docking_port/mobile/stationtrauma_space/proc/compartment_report()
	var/list/rooms = list()
	for(var/turf/tile as anything in return_turfs())
		var/area/room = get_area(tile)
		if(!shuttle_areas[room])
			continue
		var/list/entry = rooms[room]
		if(!entry)
			var/area/shuttle/stationtrauma_space/ship_room = room
			entry = list("name" = room.name, "airless" = istype(ship_room) && ship_room.vacuum_by_design, "breaches" = 0, "fire" = FALSE, "floor_tiles" = 0, "vacuum_tiles" = 0, "total_pressure" = 0)
			rooms[room] = entry
		if(isspaceturf(tile))
			entry["breaches"]++
			continue
		if(!isopenturf(tile))
			continue
		var/turf/open/open_tile = tile
		if(open_tile.active_hotspot)
			entry["fire"] = TRUE
		var/pressure = open_tile.return_air()?.return_pressure() || 0
		entry["floor_tiles"]++
		entry["total_pressure"] += pressure
		if(pressure < HAZARD_LOW_PRESSURE)
			entry["vacuum_tiles"]++
	var/list/report = list()
	for(var/area/room as anything in rooms)
		var/list/entry = rooms[room]
		var/floor_tiles = entry["floor_tiles"]
		report += list(list(
			"name" = entry["name"],
			"pressure" = floor_tiles ? round(entry["total_pressure"] / floor_tiles) : null,
			"low_pressure" = !entry["airless"] && floor_tiles && entry["vacuum_tiles"] > floor_tiles * COMPARTMENT_DEPRESSURISED_SHARE,
			"fire" = entry["fire"],
			"breaches" = entry["breaches"],
		))
	return report

#undef COMPARTMENT_DEPRESSURISED_SHARE
