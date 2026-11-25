// Bombardment craters follow Sierra's radiation bombing planet theme, rebuilt on TG decals; no donor code is copied.
// https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/code/modules/overmap/exoplanets/planet_themes/radiation_bombing.dm

/// Radius in turfs of the scorched ground around a crater's core.
#define EXPEDITION_CRATER_RADIUS 3

/datum/map_generator/expedition_barren
	/// Whether the radiation bombardment modifier pocked the surface with craters.
	var/craters = FALSE

/**
 * Pock the open surface with old bombardment craters: a glowing radioactive core in rubble, scorched ground,
 * ash and charred remains around it.
 *
 * Crater turfs join the feature turfs, so flora and fauna placed afterwards keep out of them.
 */
/datum/map_generator/expedition_barren/proc/place_craters()
	if(!craters)
		return
	// Sierra's share of the surface: thirteen craters on a 128-turf square.
	for(var/index in 1 to round(0.0008 * width * width))
		for(var/attempt in 1 to 30)
			var/x = rand(EXPEDITION_CRATER_RADIUS + 3, width - EXPEDITION_CRATER_RADIUS - 2)
			var/y = rand(EXPEDITION_CRATER_RADIUS + 3, width - EXPEDITION_CRATER_RADIUS - 2)
			if(is_reserved(x, y) || in_camp_clearance(x, y))
				continue
			if(!ispath(terrain_at(x, y), /turf/open/misc) || !plan_free(x, y))
				continue
			// the scorched ground keeps later plans off, as the crater turfs keep flora and fauna off
			for(var/near_y in y - EXPEDITION_CRATER_RADIUS to y + EXPEDITION_CRATER_RADIUS)
				for(var/near_x in x - EXPEDITION_CRATER_RADIUS to x + EXPEDITION_CRATER_RADIUS)
					if(sqrt((near_x - x) ** 2 + (near_y - y) ** 2) <= EXPEDITION_CRATER_RADIUS && !is_reserved(near_x, near_y) && ispath(terrain_at(near_x, near_y), /turf/open/misc))
						plan_take(near_x, near_y)
			plan_work(x - EXPEDITION_CRATER_RADIUS, y - EXPEDITION_CRATER_RADIUS, x + EXPEDITION_CRATER_RADIUS, y + EXPEDITION_CRATER_RADIUS, CALLBACK(src, PROC_REF(scorch_crater), level_turf(x, y)))
			break

/** Scorch one crater around `core`, leaving reserved ground and earlier features untouched. */
/datum/map_generator/expedition_barren/proc/scorch_crater(turf/open/misc/core)
	var/static/list/remains = list(/obj/effect/decal/remains/human, /obj/effect/decal/remains/xeno)
	for(var/turf/open/misc/tile in RANGE_TURFS(EXPEDITION_CRATER_RADIUS, core))
		if(sqrt((tile.x - core.x) ** 2 + (tile.y - core.y) ** 2) > EXPEDITION_CRATER_RADIUS || is_reserved(tile.x - origin_x + 1, tile.y - origin_y + 1) || LAZYACCESS(feature_turfs, tile))
			continue
		LAZYSET(feature_turfs, tile, TRUE)
		tile.add_atom_colour("#6e665c", FIXED_COLOUR_PRIORITY)
		if(tile == core)
			continue
		if(prob(25))
			new /obj/effect/decal/cleanable/ash(tile)
		else if(prob(10))
			var/remain_type = pick(remains)
			new remain_type(tile)
	new /obj/effect/decal/cleanable/rubble(core)
	// The glowing core irradiates its surroundings until someone scrubs it away.
	new /obj/effect/decal/cleanable/greenglow/radioactive(core)

#undef EXPEDITION_CRATER_RADIUS
