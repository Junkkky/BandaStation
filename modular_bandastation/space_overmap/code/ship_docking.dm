/datum/stationtrauma_overmap/space
	var/datum/stationtrauma_ship_docking/ship_docking
	var/datum/weakref/docking_request
	var/docking_request_until = 0
	var/docking_request_revision = 0
	var/docking_request_sequence = 0

/datum/stationtrauma_overmap/space/proc/available_for_ship_docking()
	return !QDELETED(src) && is_operational() && sector?.ships[vessel.shuttle_id] == src && !preparing && !planning && !relocating && !arrival_pending && !docked && !ship_docking && !connection.active && vessel.z == flight_berth.z

/datum/stationtrauma_overmap/space/proc/can_join_ship(datum/stationtrauma_overmap/space/other)
	return !QDELETED(other) && other != src && available_for_ship_docking() && other.available_for_ship_docking() && other.sector == sector \
		&& (pos_x - other.pos_x) ** 2 + (pos_y - other.pos_y) ** 2 <= (radius + other.radius + ST_NAV_APPROACH) ** 2 \
		&& (velocity_x - other.velocity_x) ** 2 + (velocity_y - other.velocity_y) ** 2 <= ST_SPACE_DOCK_SPEED ** 2

/datum/stationtrauma_overmap/space/proc/incoming_ship_request()
	var/datum/stationtrauma_overmap/space/sender = docking_request?.resolve()
	if(QDELETED(sender) || world.time >= docking_request_until || sender.sector != sector || sender.control_revision != docking_request_revision)
		docking_request = null
		return null
	return sender

/datum/stationtrauma_overmap/space/proc/ship_docking_request_data()
	var/datum/stationtrauma_overmap/space/sender = incoming_ship_request()
	if(!sender)
		return null
	var/list/contact = ship_observations[sender.vessel.shuttle_id]
	return list("token" = docking_request_sequence, "contact" = contact?["id"])

/** Only an unexpired crew-local contact may address another vessel; native IDs never leave the server. */
/datum/stationtrauma_overmap/space/proc/request_ship_docking(number)
	if(!ISINTEGER(number) || number < 1 || !available_for_ship_docking())
		return FALSE
	var/datum/stationtrauma_overmap/space/other
	for(var/id in ship_observations)
		var/list/contact = ship_observations[id]
		if(contact["id"] == number && world.time - contact["seen"] < ST_NAV_SHIP_MEMORY)
			other = sector.ships[id]
			break
	if(!istype(other))
		return FALSE
	advance()
	other.advance()
	if(!can_join_ship(other) || other.incoming_ship_request())
		status = "Запрос не передан: сократите дистанцию и относительную скорость либо дождитесь ответа борта"
		return FALSE
	other.docking_request = WEAKREF(src)
	other.docking_request_revision = control_revision
	other.docking_request_until = world.time + ST_SPACE_DOCK_REQUEST_TIME
	other.docking_request_sequence++
	other.record_ship_observation(vessel.shuttle_id, src, "signal")
	other.navigation_notice("Получен запрос на стыковку. Подтвердите или отклоните его на навигационной консоли.")
	status = "Запрос на стыковку передан"
	return TRUE

/datum/stationtrauma_overmap/space/proc/respond_ship_docking(token, accepted)
	var/datum/stationtrauma_overmap/space/sender = incoming_ship_request()
	if(!sender || !ISINTEGER(token) || token != docking_request_sequence)
		return FALSE
	docking_request = null
	if(!accepted)
		sender.navigation_notice("Запрос на стыковку отклонён.")
		return TRUE
	advance()
	sender.advance()
	if(!can_join_ship(sender))
		status = "Стыковка невозможна: проверьте дистанцию и относительную скорость"
		return FALSE
	var/datum/stationtrauma_ship_docking/link = new(sender, src)
	// Both orders are committed before the first yield; leaving the console does not cancel a manoeuvre.
	INVOKE_ASYNC(link, TYPE_PROC_REF(/datum/stationtrauma_ship_docking, connect))
	return TRUE

/** A pair owns one shared seam; each hull retains its independent physical level and contents. */
/datum/stationtrauma_ship_docking
	var/datum/stationtrauma_overmap/space/first
	var/datum/stationtrauma_overmap/space/second
	var/datum/stationtrauma_map_connection/connection
	var/obj/docking_port/stationary/anchor
	var/turf/first_origin
	var/turf/second_origin
	var/first_revision
	var/second_revision
	var/closing = FALSE

/datum/stationtrauma_ship_docking/New(datum/stationtrauma_overmap/space/a, datum/stationtrauma_overmap/space/b)
	first = a
	second = b
	connection = a.connection
	a.ship_docking = b.ship_docking = src
	a.stop("Стыковочный манёвр")
	b.stop("Стыковочный манёвр")
	a.clear_encounters()
	b.clear_encounters()
	a.preparing = b.preparing = TRUE
	a.docking_request = b.docking_request = null
	a.selected_destination = b.selected_destination = null
	a.prepared_site = b.prepared_site = null
	first_revision = a.control_revision
	second_revision = b.control_revision
	first_origin = get_turf(a.vessel)
	second_origin = get_turf(b.vessel)
	return ..()

/datum/stationtrauma_ship_docking/Destroy()
	if(!QDELETED(connection))
		connection.disconnect()
	for(var/datum/stationtrauma_overmap/space/map as anything in list(first, second))
		if(!QDELETED(map) && map.ship_docking == src)
			map.ship_docking = null
			map.preparing = FALSE
			map.status = closing ? "Соединение разомкнуто" : "Стыковка прервана"
			map.refresh_engine_audio()
	if(anchor)
		qdel(anchor, force = TRUE)
		anchor = null
	first = second = null
	first_origin = second_origin = null
	connection = null
	return ..()

/** Revalidate both reservations, native locations and pilot orders before publishing the prepared seam. */
/datum/stationtrauma_ship_docking/proc/current()
	return !closing && !QDELETED(first) && !QDELETED(second) && first.is_operational() && second.is_operational() \
		&& first.ship_docking == src && second.ship_docking == src && first.sector == second.sector \
		&& first.control_revision == first_revision && second.control_revision == second_revision \
		&& get_turf(first.vessel) == first_origin && get_turf(second.vessel) == second_origin

/datum/stationtrauma_ship_docking/proc/connect()
	var/ready = FALSE
	var/datum/stationtrauma_work_budget/budget = new
	if(current())
		var/list/bounds = second.vessel.return_coords()
		var/horizontal = !!(connection.direction & (EAST|WEST))
		var/positive = connection.direction == NORTH || connection.direction == EAST
		var/low = horizontal ? min(bounds[1], bounds[3]) : min(bounds[2], bounds[4])
		var/high = horizontal ? max(bounds[1], bounds[3]) : max(bounds[2], bounds[4])
		var/edge = positive ? low - 1 : high + 1
		var/turf/edge_tile = locate(horizontal ? edge : second.vessel.x, horizontal ? second.vessel.y : edge, second.vessel.z)
		if(isspaceturf(edge_tile))
			anchor = new /obj/docking_port/stationary/stationtrauma_space_site(edge_tile)
			try
				ready = connection.connect(anchor, budget, FALSE, 1, 1) && connection.activate(budget, CALLBACK(src, PROC_REF(current)))
			catch(var/exception/failure)
				stack_trace("Ship docking connection failed: [failure]")
	if(QDELETED(src))
		return FALSE
	if(!ready || !current())
		qdel(src)
		return FALSE
	first.preparing = second.preparing = FALSE
	first.status = second.status = "Корабли состыкованы; внешний переход через шлюзы"
	first.play_maneuver_audio(second.vessel)
	return TRUE

/** Either pilot may release a voluntary pair; stop during cleanup cancels thrust, not the safe disconnect. */
/datum/stationtrauma_ship_docking/proc/release(datum/stationtrauma_overmap/space/departing)
	if(closing || !(departing in list(first, second)) || QDELETED(first) || QDELETED(second) || !connection.active || first.preparing || second.preparing || !departing.is_operational() || !departing.vessel.engines_running || departing.engine_fraction() <= 0)
		return FALSE
	closing = TRUE
	first.preparing = second.preparing = TRUE
	var/revision = departing.control_revision
	var/datum/stationtrauma_overmap/space/peer = departing == first ? second : first
	connection.disconnect_cooperatively(new /datum/stationtrauma_work_budget)
	if(QDELETED(src))
		return FALSE
	var/ready = !QDELETED(departing) && departing.is_operational() && departing.control_revision == revision && departing.vessel.engines_running && departing.engine_fraction() > 0
	if(ready)
		departing.play_maneuver_audio(QDELETED(peer) ? null : peer.vessel, departing = TRUE)
	qdel(src)
	return ready
