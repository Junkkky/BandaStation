/datum/stationtrauma_overmap/space
	/// Shared docking link. A hostile approach uses a separate reservation until capture.
	var/datum/stationtrauma_ship_docking/ship_docking
	/// Weak sender reference for an incoming voluntary docking request.
	var/datum/weakref/docking_request
	/// world.time expiry of the pending request.
	var/docking_request_until = 0
	/// Sender control revision captured when the request was issued.
	var/docking_request_revision = 0
	/// Monotonic response token rejecting replies to superseded requests.
	var/docking_request_sequence = 0
	/// Interval between successful outgoing requests, independent of helm revisions and recipient replies.
	COOLDOWN_DECLARE(ship_docking_request_cooldown)

/** Whether this free hull may reserve or accept a voluntary ship connection. */
/datum/stationtrauma_overmap/space/proc/available_for_ship_docking(datum/stationtrauma_boarding_attempt/allowed_boarding)
	return !QDELETED(src) && is_operational() && !vessel.orbital_only && sector?.ships[vessel.shuttle_id] == src && !preparing && (allowed_boarding || !planning) && !relocating && !arrival_pending && !docked && !ship_docking && boarding_attempt == allowed_boarding && !connection.active && vessel.z == flight_berth.z

/** Check two available hulls for common sector, proximity and low relative speed. */
/datum/stationtrauma_overmap/space/proc/can_join_ship(datum/stationtrauma_overmap/space/other)
	return !QDELETED(other) && other != src && available_for_ship_docking() && other.available_for_ship_docking() && other.sector == sector \
		&& (pos_x - other.pos_x) ** 2 + (pos_y - other.pos_y) ** 2 <= ST_SPACE_DOCK_RANGE ** 2 \
		&& (velocity_x - other.velocity_x) ** 2 + (velocity_y - other.velocity_y) ** 2 <= ST_SPACE_DOCK_SPEED ** 2

/** Crew-local contact numbers that currently pass the same check as a docking request. */
/datum/stationtrauma_overmap/space/proc/dockable_ship_contacts()
	var/list/numbers = list()
	if(!available_for_ship_docking())
		return numbers
	for(var/id in ship_observations)
		var/list/contact = ship_observations[id]
		if(world.time - contact["seen"] < ST_NAV_SHIP_MEMORY && can_join_ship(sector.ships[id]))
			numbers += contact["id"]
	return numbers

/** Return the live sender only while its request and order revision remain valid. */
/datum/stationtrauma_overmap/space/proc/incoming_ship_request()
	var/datum/stationtrauma_overmap/space/sender = docking_request?.resolve()
	if(QDELETED(sender) || world.time >= docking_request_until || sender.sector != sector || sender.control_revision != docking_request_revision)
		docking_request = null
		return null
	return sender

/** Expose a reply token and crew-local contact number, never a native hull ID. */
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
	if(!COOLDOWN_FINISHED(src, ship_docking_request_cooldown))
		status = "Запрос не передан: подождите перед повторным запросом на стыковку"
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
	COOLDOWN_START(src, ship_docking_request_cooldown, ST_SPACE_DOCK_REQUEST_TIME)
	other.docking_request = WEAKREF(src)
	other.docking_request_revision = control_revision
	other.docking_request_until = world.time + ST_SPACE_DOCK_REQUEST_TIME
	other.docking_request_sequence++
	other.record_ship_observation(vessel.shuttle_id, src, "signal")
	other.navigation_notice("Получен запрос на стыковку. Подтвердите или отклоните его на навигационной консоли.")
	// Audible across the bridge, so nobody has to watch the console to notice a request.
	for(var/area/ship_area as anything in other.vessel.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/console in ship_area)
			playsound(console, 'sound/machines/terminal/terminal_alert.ogg', 70, extrarange = 4)
	status = "Запрос на стыковку передан"
	return TRUE

/** Consume a current reply token and reserve both hulls only after revalidation. */
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

/**
 * Outer hatches of this hull: turf mapped to the cardinal direction of the open space it leads to.
 *
 * A hatch is an airlock against space, or an open hull tile against space just outside a door, such as cargo bay doors.
 * Airlocks come first, so airlock pairings are tried before bay openings.
 */
/obj/docking_port/mobile/stationtrauma_space/proc/outer_hatches()
	var/list/airlocks = list()
	var/list/openings = list()
	for(var/turf/tile as anything in return_turfs())
		if(!shuttle_areas[get_area(tile)] || tile.density)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/outside = get_step(tile, direction)
			var/turf/inside = get_step(tile, REVERSE_DIR(direction))
			if(!isspaceturf(outside) || shuttle_areas[get_area(outside)] || !inside || !shuttle_areas[get_area(inside)])
				continue
			if(locate(/obj/machinery/door/airlock) in tile)
				airlocks[tile] = direction
			else if(locate(/obj/machinery/door) in inside)
				openings[tile] = direction
			break
	return airlocks + openings

/** Offset from this port to a hull `tile` if the port faced `facing`, following native ordered-turf rotation. */
/obj/docking_port/mobile/stationtrauma_space/proc/rotated_offset(turf/tile, facing)
	var/list/current = stationtrauma_port_rotation(dir)
	var/list/target = stationtrauma_port_rotation(facing)
	var/relative_x = tile.x - x
	var/relative_y = tile.y - y
	var/component_x = relative_x * current[1] + relative_y * current[2]
	var/component_y = relative_y * current[1] - relative_x * current[2]
	return list(component_x * target[1] - component_y * target[2], component_y * target[1] + component_x * target[2])

/** Native docking port cosine and sine for a cardinal direction. */
/proc/stationtrauma_port_rotation(direction)
	switch(direction)
		if(WEST)
			return list(0, 1)
		if(SOUTH)
			return list(-1, 0)
		if(EAST)
			return list(0, -1)
	return list(1, 0)

/**
 * Find a berth one gangway tile from the host. Return both hatch turfs and the outward bearing in matched_hatches.
 *
 * The hull may rotate; every moving hull tile must land on the host's open exterior vacuum away from the level border.
 * Placement can yield between candidates. The caller revalidates the approach and relocation rechecks the berth.
 */
/datum/stationtrauma_overmap/space/proc/flush_berth(datum/stationtrauma_overmap/space/host, list/matched_hatches)
	if(QDELETED(host?.exterior))
		return null
	var/list/hull = vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir)
	var/datum/stationtrauma_work_budget/budget = new
	var/list/guest_hatches = vessel.ship_docking_hatches()
	var/list/host_hatches = host.vessel.ship_docking_hatches()
	for(var/turf/host_hatch as anything in host_hatches)
		var/host_out = host_hatches[host_hatch]
		var/turf/collar_tile = get_step(host_hatch, host_out)
		if(!isspaceturf(collar_tile) || get_area(collar_tile) != host.exterior || collar_tile.is_blocked_turf())
			continue
		var/turf/meeting = get_step(collar_tile, host_out)
		var/turf/beyond = get_step(meeting, host_out)
		if(!beyond)
			continue
		for(var/turf/guest_hatch as anything in guest_hatches)
			var/turf/guest_inside = get_step(guest_hatch, REVERSE_DIR(guest_hatches[guest_hatch]))
			for(var/facing in GLOB.cardinals)
				var/list/door_offset = vessel.rotated_offset(guest_hatch, facing)
				var/list/inside_offset = vessel.rotated_offset(guest_inside, facing)
				// The guest hatch takes the meeting tile and its own interior lies farther from the host.
				if(inside_offset[1] - door_offset[1] != beyond.x - meeting.x || inside_offset[2] - door_offset[2] != beyond.y - meeting.y)
					continue
				var/turf/port_turf = locate(meeting.x - door_offset[1], meeting.y - door_offset[2], meeting.z)
				if(!port_turf)
					continue
				budget.yield()
				if(QDELETED(src) || QDELETED(host) || QDELETED(host.exterior))
					return null
				var/list/bounds = vessel.return_coords(port_turf.x, port_turf.y, facing)
				if(min(bounds[1], bounds[3]) <= TRANSITIONEDGE + 1 || max(bounds[1], bounds[3]) >= world.maxx - TRANSITIONEDGE || min(bounds[2], bounds[4]) <= TRANSITIONEDGE + 1 || max(bounds[2], bounds[4]) >= world.maxy - TRANSITIONEDGE)
					continue
				var/list/landing = vessel.return_ordered_turfs(port_turf.x, port_turf.y, port_turf.z, facing)
				if(length(landing) != length(hull))
					continue
				var/clear = TRUE
				for(var/index in 1 to length(hull))
					if(!vessel.shuttle_areas[get_area(hull[index])])
						continue
					var/turf/tile = landing[index]
					if(tile == collar_tile || !isspaceturf(tile) || get_area(tile) != host.exterior)
						clear = FALSE
						break
				if(!clear)
					continue
				var/obj/docking_port/stationary/stationtrauma_space_site/berth = new(port_turf)
				berth.name = "Стыковочный узел"
				berth.width = vessel.width
				berth.height = vessel.height
				berth.dwidth = vessel.dwidth
				berth.dheight = vessel.dheight
				berth.setDir(facing)
				if(vessel.check_dock(berth, TRUE))
					matched_hatches += list(guest_hatch, host_hatch, host_out)
					return berth
				qdel(berth, force = TRUE)
	return null

/** Prefer a fitted docking hatch, then a conventional door with an interior floor behind it. */
/obj/docking_port/mobile/stationtrauma_space/proc/ship_docking_hatches()
	var/list/fitted = list()
	var/list/ordinary = list()
	var/list/hatches = outer_hatches()
	for(var/turf/tile as anything in hatches)
		var/obj/machinery/door/airlock/hatch = locate() in tile
		var/outward = hatches[tile]
		var/turf/inside = get_step(tile, REVERSE_DIR(outward))
		if(!isfloorturf(tile) || !isfloorturf(inside) || !hatch?.density || hatch.operating || inside.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/obj/machinery/door/airlock/stationtrauma_docking/ship/port = hatch
		if(istype(port))
			if(port.dir == outward && !port.gangway && !port.ship_collar)
				fitted[tile] = outward
		else
			ordinary[tile] = outward
	return fitted + ordinary

/** Two real hulls coupled on the second vessel’s flight level. */
/datum/stationtrauma_ship_docking
	/// First reserved navigation instance; cleared when the pair is destroyed.
	var/datum/stationtrauma_overmap/space/first
	/// Second reserved navigation instance; cleared when the pair is destroyed.
	var/datum/stationtrauma_overmap/space/second
	/// The sealed passage between the two independent hatches.
	var/datum/stationtrauma_dock_gangway/ship_to_ship/collar
	var/maneuver_name = "Стыковка"
	var/arrival_alarm
	/// Temporary native berth for the first hull on the second hull’s level.
	var/obj/docking_port/stationary/anchor
	/// Set once native relocation has committed.
	var/flush = FALSE
	/// Physical position captured before yielding connection preparation.
	var/turf/first_origin
	/// Peer physical position captured before yielding connection preparation.
	var/turf/second_origin
	/// First helm order revision captured at pair reservation.
	var/first_revision
	/// Peer helm order revision captured at pair reservation.
	var/second_revision
	/// Whether a safe cooperative disconnect has started.
	var/closing = FALSE

/datum/stationtrauma_ship_docking/New(datum/stationtrauma_overmap/space/a, datum/stationtrauma_overmap/space/b)
	first = a
	second = b
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
	QDEL_NULL(collar)
	for(var/datum/stationtrauma_overmap/space/map as anything in list(first, second))
		if(!QDELETED(map) && map.ship_docking == src)
			if(closing && map.approach_departing)
				map.end_approach()
			map.ship_docking = null
			map.preparing = FALSE
			map.status = closing ? "Соединение разомкнуто" : "Стыковка прервана"
			map.refresh_engine_audio()
	// An interrupted flush pair must not strand the first hull on its peer's level.
	if(flush && !QDELETED(first) && !QDELETED(first.vessel) && first.vessel.z != first.flight_berth?.z)
		INVOKE_ASYNC(first, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, relocate), first.flight_berth)
	if(anchor)
		qdel(anchor, force = TRUE)
		anchor = null
	first = second = null
	first_origin = second_origin = null
	return ..()

/** Revalidate both reservations, native locations and pilot orders before committing the physical rendezvous. */
/datum/stationtrauma_ship_docking/proc/current()
	return !closing && !QDELETED(first) && !QDELETED(second) && first.is_operational() && second.is_operational() \
		&& first.ship_docking == src && second.ship_docking == src && first.sector == second.sector \
		&& first.control_revision == first_revision && second.control_revision == second_revision \
		&& get_turf(first.vessel) == first_origin && get_turf(second.vessel) == second_origin

/** Hold the pair through a manoeuvre; fails as soon as the pair is gone or `still_valid` does. */
/datum/stationtrauma_ship_docking/proc/hold(datum/callback/still_valid, duration = ST_SPACE_MOORING_TIME)
	var/started = world.time
	while(world.time - started < duration)
		sleep(1 SECONDS)
		if(QDELETED(src) || !still_valid.Invoke())
			return FALSE
	return TRUE

/** Bring consenting hulls alongside and deploy the same pressure collar used for boarding. */
/datum/stationtrauma_ship_docking/proc/connect()
	first.status = second.status = "Стыковочный манёвр: сближение шлюзов"
	if(!hold(CALLBACK(src, PROC_REF(current))))
		if(!QDELETED(src))
			qdel(src)
		return FALSE
	var/list/matched = list()
	var/obj/docking_port/stationary/berth = first.flush_berth(second, matched)
	if(QDELETED(src))
		if(berth)
			qdel(berth, force = TRUE)
		return FALSE
	anchor = berth
	if(!anchor || !current())
		first.navigation_notice("Стыковка прервана: не удалось совместить внешние шлюзы.")
		second.navigation_notice("Стыковка прервана: не удалось совместить внешние шлюзы.")
		qdel(src)
		return FALSE
	var/obj/machinery/door/airlock/guest = locate() in matched[1]
	var/obj/machinery/door/airlock/host = locate() in matched[2]
	if(!join_hatches(guest, host, matched[3]))
		return FALSE
	first.play_maneuver_audio(second.vessel)
	return TRUE

/datum/stationtrauma_ship_docking/proc/can_join_hatches(obj/machinery/door/airlock/guest, obj/machinery/door/airlock/host, outward)
	if(!current() || !guest?.density || !host?.density || guest.operating || host.operating || !first.vessel.shuttle_areas[get_area(guest)] || !second.vessel.shuttle_areas[get_area(host)])
		return FALSE
	var/turf/gap = get_step(host, outward)
	var/turf/meeting = get_step(gap, outward)
	var/list/offset = first.vessel.rotated_offset(get_turf(guest), anchor.dir)
	return isspaceturf(gap) && get_area(gap) == second.exterior && !gap.is_blocked_turf() && meeting?.z == anchor.z \
		&& anchor.x + offset[1] == meeting.x && anchor.y + offset[2] == meeting.y

/datum/stationtrauma_ship_docking/proc/join_hatches(obj/machinery/door/airlock/guest, obj/machinery/door/airlock/host, outward)
	flush = first.relocate(anchor, CALLBACK(src, PROC_REF(can_join_hatches), guest, host, outward))
	if(QDELETED(src))
		return
	if(!flush)
		first.navigation_notice("[maneuver_name]: место у шлюза занято.")
		second.navigation_notice("[maneuver_name]: место у шлюза занято.")
		qdel(src)
		return
	collar = new
	if(!collar.fit(guest, host, outward))
		QDEL_NULL(collar)
		// A late obstruction must never leave a relocated ship under two independent helms.
		if(first.relocate(first.flight_berth))
			if(!QDELETED(src))
				first.navigation_notice("[maneuver_name]: трап перекрыт, корабль вернулся на свою стоянку.")
				second.navigation_notice("[maneuver_name]: трап перекрыт.")
				qdel(src)
			return
		if(QDELETED(src))
			return
	first.preparing = second.preparing = FALSE
	for(var/datum/stationtrauma_overmap/space/ship as anything in list(first, second))
		if(!collar)
			ship.status = "Трап перекрыт. Корабли удерживаются рядом. Освободите стоянку и отдайте захваты."
			ship.navigation_notice(ship.status)
			continue
		var/obj/machinery/door/airlock/door = ship == first ? guest : host
		var/area/room = get_area(door)
		var/bearing = get_dir(door, collar.floors[1])
		var/side
		switch(WRAP(dir2angle(bearing) - dir2angle(ship.vessel.preferred_direction), 0, 360))
			if(0)
				side = "нос"
			if(90)
				side = "правый борт"
			if(180)
				side = "корма"
			if(270)
				side = "левый борт"
		ship.status = "[maneuver_name]: трап закреплён — [side], [room.name], шлюз «[door.name]»."
		ship.navigation_notice(ship.status, ship == second ? arrival_alarm : null)
		if(collar.opening_problem)
			ship.navigation_notice("Давление в переходе небезопасно: [collar.opening_problem].")
	return TRUE

/**
 * Either pilot may release a voluntary pair after casting off; stop during cleanup cancels thrust, not the safe disconnect.
 *
 * Arguments:
 * * instant - Skip casting off, for admin repositioning
 */
/datum/stationtrauma_ship_docking/proc/release(datum/stationtrauma_overmap/space/departing, instant = FALSE)
	if(closing || !(departing in list(first, second)) || QDELETED(first) || QDELETED(second) || !flush || collar?.busy || first.preparing || second.preparing || !departing.is_operational() || !departing.vessel.engines_running || departing.engine_fraction() <= 0)
		return FALSE
	closing = TRUE
	first.preparing = second.preparing = TRUE
	var/revision = departing.control_revision
	var/datum/stationtrauma_overmap/space/peer = departing == first ? second : first
	if(!instant)
		departing.begin_approach(null, ST_SPACE_MOORING_TIME, departing = TRUE)
	departing.status = peer.status = "Расстыковка: набор тяги"
	if(!instant && !hold(CALLBACK(src, PROC_REF(releasable), departing, revision), ST_SPACE_DEPARTURE_DELAY))
		if(QDELETED(src))
			return FALSE
		closing = FALSE
		departing.end_approach()
		first.preparing = second.preparing = FALSE
		first.status = second.status = "Расстыковка прервана"
		return FALSE
	var/problem = collar?.seal_for_release()
	if(QDELETED(src))
		return FALSE
	if(problem || !first.relocate(first.flight_berth, CALLBACK(src, PROC_REF(commit_release), departing, revision, instant)))
		if(QDELETED(src))
			return FALSE
		if(!problem)
			if(!releasable(departing, revision))
				problem = "утрачена тяга или отменён приказ"
			else if(collar && !collar.clear_for_release())
				problem = "переход или шлюз занят"
			else
				problem = "стоянка корабля перекрыта"
		closing = FALSE
		if(collar)
			collar.busy = FALSE
		departing.end_approach()
		first.preparing = second.preparing = FALSE
		first.status = second.status = "Расстыковка прервана: [problem]."
		departing.navigation_notice(departing.status)
		return FALSE
	if(QDELETED(src))
		return FALSE
	QDEL_NULL(collar)
	var/ready = releasable(departing, revision)
	if(ready && !instant)
		ready = departing.departure_flight(revision)
		if(QDELETED(src))
			return FALSE
	qdel(src)
	return ready

/** Play the release after preflight revalidation and immediately before the hull moves. */
/datum/stationtrauma_ship_docking/proc/commit_release(datum/stationtrauma_overmap/space/departing, revision, instant)
	if(QDELETED(src) || !closing || !releasable(departing, revision) || (collar && !collar.clear_for_release()))
		return FALSE
	departing.status = "Расстыковка: отдача захватов"
	if(!instant)
		departing.play_departure_effects()
	return TRUE

/** Whether the departing hull may still fly away under the order that started the release. */
/datum/stationtrauma_ship_docking/proc/releasable(datum/stationtrauma_overmap/space/departing, revision)
	return !QDELETED(departing) && departing.is_operational() && departing.control_revision == revision && departing.vessel.engines_running && departing.engine_fraction() > 0
