/** Ocean-specific connection policy; the common owner handles gates, previews and projectiles. */
/datum/stationtrauma_map_connection/ocean
	passage_type = /datum/component/stationtrauma_ocean_passage
	preview_type = /datum/stationtrauma_ocean_preview

/datum/stationtrauma_map_connection/ocean/is_loading()
	return ..() || SSfloodwater.loading_ocean_levels.len

/datum/stationtrauma_map_connection/ocean/gate_available(turf/open/tile, allow_owned = FALSE)
	return tile?.GetComponent(/datum/component/floodwater)?.infinite_source && ..()

/** Permanent coordinates and underwater connection ownership. */
/obj/docking_port/mobile/stationtrauma
	/// Current destination; the physical vessel remains at home.
	var/obj/docking_port/stationary/stationtrauma/fixed_location
	/// Shared scene connection with ocean validation and visual extensions.
	var/datum/stationtrauma_map_connection/ocean/map_connection

/obj/docking_port/mobile/stationtrauma/Destroy()
	QDEL_NULL(overmap)
	QDEL_NULL(map_connection)
	return ..()

/** Change only this vessel's areas, including the real ocean occupied by outside swimmers. */
/obj/docking_port/mobile/stationtrauma/proc/set_fixed_parallax(direction)
	var/list/areas = shuttle_areas.Copy()
	for(var/deck in 0 to decks - 1)
		areas[get_area(locate(1, 1, z + deck))] = TRUE
	for(var/area/zone as anything in areas)
		zone.set_parallax_movedir(direction)

/** Existing submarine callers delegate to the common connection owner. */
/obj/docking_port/mobile/stationtrauma/proc/disconnect_ocean_passages()
	map_connection.disconnect()

/obj/docking_port/mobile/stationtrauma/proc/disconnect_ocean_cooperatively(datum/stationtrauma_work_budget/budget)
	map_connection.disconnect_cooperatively(budget)

/obj/docking_port/mobile/stationtrauma/proc/connect_ocean_location(obj/docking_port/stationary/stationtrauma/berth, datum/stationtrauma_work_budget/budget, activate = TRUE)
	if(!berth || !(berth in berths))
		return FALSE
	return map_connection.connect(berth, budget, activate, berth.ship_ocean_clearance, berth.site_ocean_clearance)

/obj/docking_port/mobile/stationtrauma/proc/activate_ocean_passages(datum/stationtrauma_work_budget/budget, datum/callback/arrival_check)
	return map_connection.activate(budget, arrival_check)
