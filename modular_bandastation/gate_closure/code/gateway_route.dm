/// Loads the event profile's pre-baked locations, once before the round.
SUBSYSTEM_DEF(gate_closure)
	name = "Gate closure"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
		/datum/controller/subsystem/air,
		/datum/controller/subsystem/lighting,
		/datum/controller/subsystem/redspace,
		/datum/controller/subsystem/weather,
	)
	/// Z levels of every event location: the route, the islands and the beach.
	var/list/event_levels = list()

/datum/controller/subsystem/gate_closure/Initialize()
	if(SSmapping.current_map.map_name != "Cyberiad Gate Closure")
		return SS_INIT_NO_NEED

	// A random away mission may already have loaded the beach; do not split arrivals between copies.
	var/beach_loaded = FALSE
	for(var/datum/gateway_destination/point/point in GLOB.gateway_destinations)
		if(point.id == AWAYSTART_BEACH && length(point.target_turfs))
			beach_loaded = TRUE
			break
	if(!beach_loaded && !load_new_z_level("_maps/RandomZLevels/TheBeach.dmm", "Beach", TRUE))
		return SS_INIT_FAILURE
	for(var/location in list("cyberiad_wreck", "Avangarde_bar", "Avangarde_dest", "limnea_destroy", "wedding_distortion", "limneya_peti_blanshir_house", "katorga13", "centcom_ruins", "redspace_v2"))
		if(!load_new_z_level("_maps/map_files/gate_closure/[location].dmm", location, TRUE))
			return SS_INIT_FAILURE
	// Not on the gateway route: everyone falling into the abyss of any location lands on one of these islands.
	if(!load_new_z_level("_maps/map_files/gate_closure/redspace_islands.dmm", "redspace_islands", TRUE))
		return SS_INIT_FAILURE
	if(length(GLOB.gate_closure_island_landings))
		var/turf/island = GLOB.gate_closure_island_landings[1]
		SSredspace.enable_z_level(island.z)
	for(var/obj/machinery/gateway/away/beach_gate as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/gateway/away))
		if(!istype(get_area(beach_gate), /area/awaymission/beach))
			continue
		var/obj/machinery/gateway/gate_closure/beach/replacement = new(get_turf(beach_gate))
		replacement.setDir(beach_gate.dir)
		qdel(beach_gate)

	var/rain_level
	if(length(GLOB.gate_closure_island_landings))
		var/turf/island = GLOB.gate_closure_island_landings[1]
		event_levels |= island.z
	// Only the beach is reachable from the real station's gateway control.
	for(var/datum/gateway_destination/destination as anything in GLOB.gateway_destinations)
		var/datum/gateway_destination/point/point = destination
		var/is_event_point = istype(point) && (point.id in list(AWAYSTART_BEACH, "gate_closure_wreck", "gate_closure_avangarde_bar", "gate_closure_avangarde", "gate_closure_limnea", "gate_closure_wedding", "gate_closure_peti_house", "gate_closure_katorga", "gate_closure_centcom", "gate_closure_redspace"))
		if(istype(destination, /datum/gateway_destination/gateway/home))
			continue
		destination.enabled = is_event_point
		destination.hidden = !is_event_point || point.id != AWAYSTART_BEACH
		if(is_event_point)
			destination.wait = 0
			if(point.id == AWAYSTART_BEACH)
				destination.name = "Пляж"
			// Rifts placed on the locations sustain spawned demons; away from them demons drain as on the station.
			if(length(point.target_turfs))
				var/turf/arrival = point.target_turfs[1]
				SSredspace.enable_z_level(arrival.z)
				event_levels |= arrival.z
				if(point.id == "gate_closure_peti_house")
					rain_level = arrival.z

	// It always rains on the suburb streets, never inside the houses.
	var/area/suburb = GLOB.areas_by_type[/area/awaymission/gate_closure/peti_house]
	if(rain_level && suburb)
		SSweather.run_weather(/datum/weather/particle/rain_storm/gate_closure, rain_level, list(WEATHER_FORCED_AREAS = list(suburb)))

	// No access checks anywhere in the scenes; most of them live in object types, out of reach of map edits.
	for(var/z_level in event_levels)
		for(var/turf/level_turf as anything in Z_TURFS(z_level))
			for(var/obj/thing in level_turf)
				thing.req_access = null
				thing.req_one_access = null
		CHECK_TICK

	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(on_crew_ready))
	return SS_INIT_SUCCESS

/// Private arrival points are not offered by ordinary away-mission configurations.
/obj/effect/landmark/awaystart/gate_closure
	delay = FALSE
	id = "gate_closure_redspace"
	name = "Неизвестный сигнал"

/// The arrival on the ruined station copy, separate from the live station.
/obj/effect/landmark/awaystart/gate_closure/wreck
	id = "gate_closure_wreck"

/// Arrival at the Avangarde bar.
/obj/effect/landmark/awaystart/gate_closure/avangarde_bar
	id = "gate_closure_avangarde_bar"

/// Arrival in the snowbound Avangarde settlement.
/obj/effect/landmark/awaystart/gate_closure/avangarde
	id = "gate_closure_avangarde"

/// Arrival on the imported ruined Limnea map.
/obj/effect/landmark/awaystart/gate_closure/limnea
	id = "gate_closure_limnea"

/// Arrival on the imported distorted wedding map.
/obj/effect/landmark/awaystart/gate_closure/wedding
	id = "gate_closure_wedding"

/// Arrival in the suburb around the Petit-Blanchir house.
/obj/effect/landmark/awaystart/gate_closure/peti_house
	id = "gate_closure_peti_house"

/// Arrival at the retained one-level Katorga scene.
/obj/effect/landmark/awaystart/gate_closure/katorga
	id = "gate_closure_katorga"

/// Arrival in the ruined Central Command.
/obj/effect/landmark/awaystart/gate_closure/centcom
	id = "gate_closure_centcom"

/// A native gateway frame with a fixed, one-way story destination.
/obj/machinery/gateway/gate_closure
	use_power = NO_POWER_USE
	/// Arrival point ID; a mapper can direct the next scene without changing teleport logic.
	var/arrival_id = "gate_closure_redspace"
	/// Whether a lever drives this gateway; one is adopted nearby or placed two tiles west.
	var/uses_lever = TRUE
	/// Owned scene lever; removed with its gateway.
	var/obj/structure/gate_closure_lever/lever

/obj/machinery/gateway/gate_closure/post_machine_initialize()
	. = ..()
	if(!uses_lever || !QDELETED(lever))
		return
	lever = null
	for(var/obj/structure/gate_closure_lever/candidate in range(3, src))
		if(QDELETED(candidate) || !QDELETED(candidate.gateway))
			continue
		if(!lever || get_dist(src, candidate) < get_dist(src, lever))
			lever = candidate
	if(lever)
		lever.gateway = src
		return
	var/turf/position = get_step(get_step(src, WEST), WEST)
	if(isopenturf(position) && !position.is_blocked_turf())
		lever = new(position)
		lever.gateway = src

/obj/machinery/gateway/gate_closure/Destroy()
	QDEL_NULL(lever)
	return ..()

/obj/machinery/gateway/gate_closure/interact(mob/user)
	. = ..()
	to_chat(user, span_notice("Переход управляется тугим рычагом рядом с гейтом."))

/// Called by the linked lever only after its full uninterrupted interaction.
/obj/machinery/gateway/gate_closure/proc/switch_route(mob/user)
	if(target)
		deactivate()
		return
	for(var/datum/gateway_destination/point/destination in GLOB.gateway_destinations)
		if(destination.id == arrival_id && destination.is_available())
			activate(destination)
			return
	to_chat(user, span_warning("Гейт не отвечает."))

/// Leaves the islands for the station fragments.
/obj/machinery/gateway/gate_closure/wreck
	arrival_id = "gate_closure_wreck"

/// Leaves the wreck for the Avangarde bar.
/obj/machinery/gateway/gate_closure/avangarde_bar
	arrival_id = "gate_closure_avangarde_bar"

/// Leaves the bar for Avangarde.
/obj/machinery/gateway/gate_closure/avangarde
	arrival_id = "gate_closure_avangarde"

/// Leaves Avangarde for Limnea.
/obj/machinery/gateway/gate_closure/limnea
	arrival_id = "gate_closure_limnea"

/// Leaves Limnea for Wedding.
/obj/machinery/gateway/gate_closure/wedding
	arrival_id = "gate_closure_wedding"

/// Leaves Wedding for the Petit-Blanchir house.
/obj/machinery/gateway/gate_closure/peti_house
	arrival_id = "gate_closure_peti_house"

/// Leaves the Petit-Blanchir house for Katorga.
/obj/machinery/gateway/gate_closure/katorga
	arrival_id = "gate_closure_katorga"

/// Leaves Katorga for the ruined Central Command, whose exit leads to redspace.
/obj/machinery/gateway/gate_closure/centcom
	arrival_id = "gate_closure_centcom"

/obj/machinery/gateway/gate_closure/beach
	arrival_id = "gate_closure_wreck"
	uses_lever = FALSE

/// The beach exit is already open; only subsequent scenes require a lever.
/obj/machinery/gateway/gate_closure/beach/post_machine_initialize()
	. = ..()
	switch_route(null)

/obj/machinery/gateway/gate_closure/beach/interact(mob/user)
	return
