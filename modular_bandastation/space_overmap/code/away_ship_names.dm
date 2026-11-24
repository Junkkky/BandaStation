GLOBAL_LIST_EMPTY(used_away_ship_names)

/obj/docking_port/mobile/stationtrauma_space
	/// The registered short name used by this mission's transponder.
	var/away_ship_name

/// Assign a name once, drawing without replacement and falling back to registry numbers.
/obj/docking_port/mobile/stationtrauma_space/proc/draw_away_ship_name(list/names)
	if(away_ship_name)
		return
	for(var/candidate in shuffle(names))
		if(register_away_ship_name(candidate))
			return
	var/static/last_registry_number = 0
	do
		last_registry_number++
	while(!register_away_ship_name("Патруль-[last_registry_number]"))

/// Reserve the name for the round and update the hull and its factory transponder together.
/obj/docking_port/mobile/stationtrauma_space/proc/register_away_ship_name(new_name)
	var/registry_key = lowertext(new_name)
	if(GLOB.used_away_ship_names[registry_key])
		return FALSE

	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in SSshuttle.mobile_docking_ports)
		if(vessel == src || QDELETED(vessel))
			continue
		if(lowertext(vessel.name) == registry_key)
			return FALSE
		for(var/obj/machinery/computer/stationtrauma_transponder/transponder as anything in vessel.transponders)
			var/obj/item/circuitboard/computer/stationtrauma_transponder/board = transponder.circuit
			if(istype(board) && lowertext(board.callsign) == registry_key)
				return FALSE

	GLOB.used_away_ship_names[registry_key] = TRUE
	away_ship_name = new_name
	name = "ОКН «[new_name]»"
	for(var/obj/machinery/computer/stationtrauma_transponder/nt_patrol/transponder in transponders)
		var/obj/item/circuitboard/computer/stationtrauma_transponder/nt/patrol/board = transponder.circuit
		if(istype(board) && board.loc == transponder)
			board.callsign = new_name
	return TRUE
