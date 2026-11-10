/**
 * # Field clusters
 *
 * A pass after dig sites, once per planet: one cluster of fields per danger band step (green 1, red 3),
 * each a scatter of fields on open ground with one or two artefacts grown in them. Clusters keep off the
 * camp, its corridors, ruins, dig sites and each other. The band picks which fields appear.
 */

/// Fields in one cluster, before running out of ground.
#define FIELD_CLUSTER_SIZE_MIN 6
#define FIELD_CLUSTER_SIZE_MAX 10
/// How far a cluster's fields spread from its centre.
#define FIELD_CLUSTER_RADIUS 4
/// Random tries for a cluster centre.
#define FIELD_CLUSTER_ATTEMPTS 250

/// Fields by danger band, weighted.
GLOBAL_LIST_INIT(anomaly_field_weights, list(
	list(
		/obj/effect/anomaly_field/tramplin = 3,
		/obj/effect/anomaly_field/thermal/heater = 2,
		/obj/effect/anomaly_field/thermal/cooler = 2,
		/obj/effect/anomaly_field/zharka = 2,
		/obj/effect/anomaly_field/vspishka = 1,
	),
	list(
		/obj/effect/anomaly_field/electra = 3,
		/obj/effect/anomaly_field/zharka = 3,
		/obj/effect/anomaly_field/tramplin = 2,
		/obj/effect/anomaly_field/thermal/heater = 1,
		/obj/effect/anomaly_field/thermal/cooler = 1,
		/obj/effect/anomaly_field/vspishka = 1,
		/obj/effect/anomaly_field/rvach = 1,
	),
	list(
		/obj/effect/anomaly_field/electra = 3,
		/obj/effect/anomaly_field/rvach = 3,
		/obj/effect/anomaly_field/zharka = 3,
		/obj/effect/anomaly_field/tramplin = 2,
		/obj/effect/anomaly_field/vspishka = 2,
	),
))

/// Places the planet's field clusters on `surface`. Returns how many were placed.
/datum/map_generator/expedition_barren/proc/place_anomaly_fields(list/turfs, area/surface, datum/stationtrauma_overmap_site/space/planet/planet, datum/stationtrauma_work_budget/budget)
	if(!length(turfs) || !planet)
		return 0
	var/band = XENOARCH_BAND_INDEX(xenoarch_band_for_level(planet.modifier_level))
	var/list/centres = list()
	for(var/i in 1 to band)
		var/turf/centre = find_field_cluster_centre(turfs, surface, centres, budget)
		if(!centre)
			break
		build_field_cluster(centre, surface, band)
		centres += centre
	return length(centres)

/// Open ground clear of reserved tiles, dig sites and other clusters, or null.
/datum/map_generator/expedition_barren/proc/find_field_cluster_centre(list/turfs, area/surface, list/centres, datum/stationtrauma_work_budget/budget)
	for(var/attempt in 1 to FIELD_CLUSTER_ATTEMPTS)
		budget?.yield()
		var/turf/candidate = pick(turfs)
		if(!dig_site_ground_ok(candidate, surface) || !dig_site_clear(candidate, surface))
			continue
		var/too_close = FALSE
		for(var/turf/taken as anything in centres)
			if(get_dist(candidate, taken) < XENOARCH_SITE_SPACING)
				too_close = TRUE
				break
		if(too_close || (locate(/obj/structure/xenoarch_stake) in range(FIELD_CLUSTER_RADIUS + 3, candidate)))
			continue
		return candidate
	return null

/// Scatters fields around `centre` and grows one or two artefacts in those that can hold them.
/datum/map_generator/expedition_barren/proc/build_field_cluster(turf/centre, area/surface, band)
	var/list/weights = GLOB.anomaly_field_weights[band]
	var/list/spots = list()
	for(var/turf/spot as anything in RANGE_TURFS(FIELD_CLUSTER_RADIUS, centre))
		if(dig_site_ground_ok(spot, surface))
			spots += spot
	var/list/bearers = list()
	for(var/i in 1 to min(rand(FIELD_CLUSTER_SIZE_MIN, FIELD_CLUSTER_SIZE_MAX), length(spots)))
		var/field_type = pick_weight(weights)
		var/obj/effect/anomaly_field/field = new field_type(pick_n_take(spots))
		if(length(field.artefact_types))
			bearers += field
	if(!length(bearers) && length(spots))
		bearers += new /obj/effect/anomaly_field/zharka(pick_n_take(spots))
	for(var/i in 1 to min(rand(1, 2), length(bearers)))
		var/obj/effect/anomaly_field/field = pick_n_take(bearers)
		field.bear_artefact(band)

#undef FIELD_CLUSTER_SIZE_MIN
#undef FIELD_CLUSTER_SIZE_MAX
#undef FIELD_CLUSTER_RADIUS
#undef FIELD_CLUSTER_ATTEMPTS
