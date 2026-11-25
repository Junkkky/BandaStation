/// Random tries for a living anomaly's spot.
#define PLANETARY_ANOMALY_ATTEMPTS 250
/// Tiles a living anomaly keeps from fields and other anomalies.
#define PLANETARY_ANOMALY_SPACING 8

/// Living anomalies by danger band, weighted: green planets get the milder ones only.
GLOBAL_LIST_INIT(planetary_anomaly_weights, list(
	list(
		/obj/effect/anomaly/pulsing/sparkler = 1,
		/obj/effect/anomaly/pulsing/veins = 1,
		/obj/effect/anomaly/pulsing/phantom = 1,
		/obj/effect/anomaly/pulsing/transfusion = 1,
		/obj/effect/anomaly/pulsing/chronograph = 1,
		/obj/effect/anomaly/pulsing/pulsar = 1,
	),
	list(
		/obj/effect/anomaly/pulsing/sparkler = 1,
		/obj/effect/anomaly/pulsing/veins = 2,
		/obj/effect/anomaly/pulsing/phantom = 2,
		/obj/effect/anomaly/pulsing/transfusion = 2,
		/obj/effect/anomaly/pulsing/chronograph = 2,
		/obj/effect/anomaly/pulsing/pulsar = 2,
		/obj/effect/anomaly/pulsing/heartbeat = 1,
		/obj/effect/anomaly/pulsing/tvstatic = 1,
		/obj/effect/anomaly/pulsing/plasmasoul = 1,
		/obj/effect/anomaly/pulsing/melter = 1,
	),
	list(
		/obj/effect/anomaly/pulsing/sparkler = 1,
		/obj/effect/anomaly/pulsing/veins = 1,
		/obj/effect/anomaly/pulsing/phantom = 1,
		/obj/effect/anomaly/pulsing/transfusion = 1,
		/obj/effect/anomaly/pulsing/chronograph = 1,
		/obj/effect/anomaly/pulsing/pulsar = 1,
		/obj/effect/anomaly/pulsing/heartbeat = 1,
		/obj/effect/anomaly/pulsing/tvstatic = 1,
		/obj/effect/anomaly/pulsing/plasmasoul = 1,
		/obj/effect/anomaly/pulsing/melter = 1,
	),
))

/**
 * On a planet with the anomalous zone modifier, plans one drifting anomaly per danger band
 * step on open ground away from the camp, ruins, dig sites, field clusters and each other. Returns how many.
 */
/datum/map_generator/expedition_barren/proc/place_planetary_anomalies(datum/stationtrauma_overmap_site/space/planet/planet)
	if(!anomaly_fields || !planet)
		return 0
	var/band = XENOARCH_BAND_INDEX(xenoarch_band_for_level(planet.modifier_level))
	. = 0
	for(var/i in 1 to band)
		var/obj/effect/anomaly/pulsing/anomaly_type = pick_weight(GLOB.planetary_anomaly_weights[band])
		// Some pulses can start at an offset before applying their own area of effect.
		var/reach = initial(anomaly_type.drift_radius) + initial(anomaly_type.effect_range) * 2
		var/list/spot = find_planetary_anomaly_spot(reach)
		if(!spot)
			continue
		plan_take(spot[1], spot[2])
		anomaly_spots += list(list(spot[1], spot[2], 0))
		plan_work(spot[1], spot[2], spot[1], spot[2], CALLBACK(src, PROC_REF(set_planetary_anomaly), level_turf(spot[1], spot[2]), anomaly_type))
		.++

/// Sets a planned anomaly of [anomaly_type] on [spot]
/datum/map_generator/expedition_barren/proc/set_planetary_anomaly(turf/spot, anomaly_type)
	var/obj/effect/anomaly/anomaly = new anomaly_type(spot)
	settle_planetary_anomaly(anomaly)
	if(istype(anomaly, /obj/effect/anomaly/pulsing/tvstatic) && prob(25))
		new /obj/effect/mob_spawn/corpse/human/legioninfested(spot)
		var/mob/living/carbon/human/body = locate() in spot
		if(body)
			var/obj/effect/anomaly/pulsing/tvstatic/tvstatic = anomaly
			tvstatic.hold_body(body)

/// Relative open ground clear of reserved tiles and of fields, anomalies and dig sites nearby, or null.
/datum/map_generator/expedition_barren/proc/find_planetary_anomaly_spot(reach)
	for(var/attempt in 1 to PLANETARY_ANOMALY_ATTEMPTS)
		budget?.yield()
		var/x = rand(1, width)
		var/y = rand(1, width)
		if(!plan_ground(x, y) || !anomaly_route_clear(x, y, reach))
			continue
		var/crowded = FALSE
		// a cluster's fields lie up to its reach from its centre
		for(var/list/taken as anything in anomaly_spots)
			if(max(abs(taken[1] - x), abs(taken[2] - y)) <= PLANETARY_ANOMALY_SPACING + taken[3])
				crowded = TRUE
				break
		for(var/list/anchor as anything in dig_anchors)
			if(max(abs(anchor[1] - x), abs(anchor[2] - y)) <= PLANETARY_ANOMALY_SPACING + 2)
				crowded = TRUE
				break
		if(!crowded)
			return list(x, y)
	return null

#undef PLANETARY_ANOMALY_ATTEMPTS
#undef PLANETARY_ANOMALY_SPACING
