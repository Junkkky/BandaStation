GLOBAL_DATUM_INIT(event_station_return, /datum/gateway_destination/event_station, new)

/// The last scene's exit: only an administrator opens it, and it throws arrivals out in front of the station bridge.
/obj/machinery/gateway/gate_closure/station
	uses_lever = FALSE

/obj/machinery/gateway/gate_closure/station/interact(mob/user)
	to_chat(user, span_notice("Гейт мёртв. Его откроет только что-то извне."))

/// Event-only destination, never offered by a console: the station corridor just outside the bridge doors.
/datum/gateway_destination/event_station
	name = "Станция"
	hidden = TRUE
	/// Corridor tiles in front of the bridge doors, found on first use.
	var/list/turf/landings

/datum/gateway_destination/event_station/get_target_turf()
	if(isnull(landings))
		landings = find_bridge_front()
	var/list/turf/free = list()
	for(var/turf/landing as anything in landings)
		if(!landing.is_blocked_turf(exclude_mobs = TRUE))
			free += landing
	if(length(free))
		return pick(free)
	return length(landings) ? pick(landings) : null

/datum/gateway_destination/event_station/post_transfer(atom/movable/traveller)
	. = ..()
	new /obj/effect/portal/event_boss/opening(get_turf(traveller), 3 SECONDS)
	if(isliving(traveller))
		var/mob/living/arrival = traveller
		arrival.Knockdown(3 SECONDS)

/// Open corridor tiles outside every door between the bridge and the rest of the station, with their neighbours in the same corridor.
/datum/gateway_destination/event_station/proc/find_bridge_front()
	var/list/turf/found = list()
	for(var/obj/machinery/door/airlock/door as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/door/airlock))
		var/turf/door_turf = get_turf(door)
		if(!door_turf || !is_station_level(door_turf.z))
			continue
		var/list/turf/bridge_side = list()
		var/list/turf/outside = list()
		for(var/direction in GLOB.cardinals)
			var/turf/neighbour = get_step(door_turf, direction)
			if(!isopenturf(neighbour))
				continue
			if(istype(neighbour.loc, /area/station/command/bridge))
				bridge_side += neighbour
			else
				outside += neighbour
		if(!length(outside) || (!length(bridge_side) && !istype(door_turf.loc, /area/station/command/bridge)))
			continue
		for(var/turf/corridor as anything in outside)
			found |= corridor
			for(var/turf/open/near in orange(1, corridor))
				if(near.loc == corridor.loc && !near.is_blocked_turf(exclude_mobs = TRUE))
					found |= near
	return found

ADMIN_VERB(gate_closure_station_return, R_FUN, "Gate Closure - Гейт редспейса на станцию", "Открыть или закрыть последний гейт редспейса, выводящий к мостику станции.", ADMIN_CATEGORY_EVENTS)
	var/list/gates = SSmachines.get_machines_by_type(/obj/machinery/gateway/gate_closure/station)
	var/obj/machinery/gateway/gate_closure/station/gate = length(gates) ? gates[1] : null
	if(QDELETED(gate))
		to_chat(user, span_warning("Гейт редспейса на станцию не найден."), confidential = TRUE)
		return
	if(gate.target)
		gate.deactivate()
	else
		if(!GLOB.event_station_return.get_target_turf())
			to_chat(user, span_warning("Не найдено ни одной клетки перед мостиком станции."), confidential = TRUE)
			return
		gate.activate(GLOB.event_station_return)
	log_admin("[key_name(user)] [gate.target ? "opened" : "closed"] the redspace gateway to the station bridge.")
	message_admins("[key_name_admin(user)] [gate.target ? "открыл" : "закрыл"] гейт редспейса на станцию.")
