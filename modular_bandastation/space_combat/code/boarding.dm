/datum/stationtrauma_overmap/space
	/// A hostile reservation, separate from helm locks and the eventual physical connection.
	var/datum/stationtrauma_boarding_attempt/boarding_attempt

/datum/stationtrauma_overmap/space/advance()
	var/datum/stationtrauma_ship_docking/boarding/link = ship_docking
	if(istype(link))
		link.advance_drift()
		return
	. = ..()
	boarding_attempt?.check_approach()

/** Reuse the voluntary docking footprint checks while retaining both pilots' normal controls. */
/datum/stationtrauma_overmap/space/proc/boarding_problem(datum/stationtrauma_overmap/space/defender, datum/stationtrauma_boarding_attempt/attempt)
	if(QDELETED(defender) || defender == src || sector != defender.sector || !available_for_ship_docking(attempt) || !defender.available_for_ship_docking(attempt) \
		|| jump_target || defender.jump_target || approach_started || defender.approach_started)
		return "один из кораблей вышел из свободного полёта"
	if(defender.speed > ST_BOARDING_SPEED)
		return "цель разогналась выше [ST_BOARDING_SPEED] км/с"
	if(speed > ST_BOARDING_SPEED)
		return "наш корабль разогнался выше [ST_BOARDING_SPEED] км/с"
	if((pos_x - defender.pos_x) ** 2 + (pos_y - defender.pos_y) ** 2 > ST_SPACE_DOCK_RANGE ** 2)
		return "корабли вне дистанции захвата"
	return null

/datum/stationtrauma_overmap/space/proc/boardable_contacts()
	. = list()
	if(!available_for_ship_docking())
		return
	for(var/id in ship_observations)
		var/list/contact = ship_sensor_observation(id)
		if(contact && !boarding_problem(sector.ships[id]))
			. += contact["id"]

/datum/stationtrauma_overmap/space/proc/request_boarding(number)
	if(!ISINTEGER(number) || number < 1 || !available_for_ship_docking())
		return FALSE
	var/datum/stationtrauma_overmap/space/defender
	for(var/id in ship_observations)
		var/list/contact = ship_sensor_observation(id)
		if(contact && contact["id"] == number)
			defender = sector.ships[id]
			break
	if(QDELETED(defender))
		return FALSE
	advance()
	defender.advance()
	var/problem = boarding_problem(defender)
	if(problem)
		navigation_notice("Абордаж недоступен: [problem].")
		return FALSE
	var/datum/stationtrauma_boarding_attempt/attempt = new(src, defender)
	if(!length(vessel.ship_docking_hatches()) || !length(defender.vessel.ship_docking_hatches()))
		navigation_notice("Абордаж недоступен: у обоих бортов нужен свободный внешний шлюз.")
		qdel(attempt)
		return FALSE
	attempt.begin()
	return TRUE

/** Choose a compatible berth at the selected fixed installation, or revalidate the exact berth already claimed. */
/datum/stationtrauma_overmap/space/proc/station_boarding_berth(datum/stationtrauma_overmap_site/space/docking_target/target, datum/stationtrauma_boarding_attempt/station/attempt)
	if(!istype(target) || target.host || target.failed || !knows_site(target) || selected_destination != target.id || !available_for_ship_docking(attempt) \
		|| jump_target || approach_started || speed > ST_BOARDING_SPEED || distance_to(target) > ST_SPACE_DOCK_RANGE || get_station_docking_request() || carrier_busy())
		return null
	if(attempt)
		var/datum/stationtrauma_overmap_site/space/held = attempt.reserved_berth
		return station_berth_available(held, target, src) && distance_to(held) <= ST_SPACE_DOCK_RANGE ? held : null
	var/datum/stationtrauma_overmap_site/space/fallback
	for(var/datum/stationtrauma_overmap_site/space/site as anything in target.berths)
		if(!station_berth_available(site, target) || distance_to(site) > ST_SPACE_DOCK_RANGE)
			continue
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		if(istype(slot) && slot.accepted_ship_class == vessel.ship_class)
			return site
		fallback ||= site
	return fallback

/** Address a discovered chart object, never a player-supplied physical port. */
/datum/stationtrauma_overmap/space/proc/request_station_boarding(target_id)
	if(!istext(target_id) || target_id != selected_destination)
		return FALSE
	advance()
	var/datum/stationtrauma_overmap_site/space/site = station_boarding_berth(sites[target_id])
	if(!site)
		return FALSE
	var/datum/stationtrauma_boarding_attempt/station/attempt = new(src)
	attempt.reserved_berth = site
	attempt.begin()
	return TRUE

/** Reserve both helms against competing capture attempts while both ships still fly independently. */
/datum/stationtrauma_boarding_attempt
	var/datum/stationtrauma_overmap/space/attacker
	var/datum/stationtrauma_overmap/space/defender
	var/end_time
	var/commit_timer
	var/end_notice = "Абордаж отменён."

/datum/stationtrauma_boarding_attempt/New(datum/stationtrauma_overmap/space/source, datum/stationtrauma_overmap/space/target)
	attacker = source
	defender = target
	return ..()

/datum/stationtrauma_boarding_attempt/Destroy()
	if(commit_timer)
		deltimer(commit_timer)
	for(var/datum/stationtrauma_overmap/space/ship as anything in list(attacker, defender))
		if(!QDELETED(ship) && ship.boarding_attempt == src)
			ship.boarding_attempt = null
			if(end_notice)
				ship.navigation_notice(end_notice)
				ship.status = end_notice
	attacker = defender = null
	return ..()

/datum/stationtrauma_boarding_attempt/proc/begin()
	attacker.boarding_attempt = src
	end_time = world.time + ST_BOARDING_TIME
	commit_timer = addtimer(CALLBACK(src, PROC_REF(complete)), ST_BOARDING_TIME, TIMER_STOPPABLE)
	if(!defender)
		return
	defender.boarding_attempt = src
	defender.record_ship_observation(attacker.vessel.shuttle_id, attacker, "signal")
	defender.navigation_notice("ВНИМАНИЕ. Начата принудительная стыковка. До захвата [ST_BOARDING_TIME / (1 SECONDS)] с. Разгон выше [ST_BOARDING_SPEED] км/с сорвёт абордаж.", 'sound/effects/siren.ogg')
	attacker.navigation_notice("Начат абордаж. Удерживайте оба борта в зоне захвата.")

/datum/stationtrauma_boarding_attempt/proc/display_data(datum/stationtrauma_overmap/space/observer)
	return list("incoming" = observer == defender, "eta" = max(0, end_time - world.time) / (1 SECONDS))

/** Called after motion updates, so a brief excess speed still breaks the reservation. */
/datum/stationtrauma_boarding_attempt/proc/check_approach()
	var/problem = QDELETED(attacker) ? "корабль ушёл" : approach_problem()
	if(!problem)
		return TRUE
	end_notice = "Абордаж сорван: [problem]."
	qdel(src)
	return FALSE

/datum/stationtrauma_boarding_attempt/proc/approach_problem()
	return attacker.boarding_problem(defender, src)

/** Compute the placement while the pilots are still free, then revalidate before taking either helm. */
/datum/stationtrauma_boarding_attempt/proc/complete()
	commit_timer = null
	var/list/matched = list()
	var/obj/docking_port/stationary/berth = attacker.flush_berth(defender, matched)
	if(!QDELETED(src))
		attacker.advance()
	if(!QDELETED(src))
		defender.advance()
	if(QDELETED(src) || !check_approach())
		if(berth)
			qdel(berth, force = TRUE)
		return
	if(!berth)
		end_notice = "Абордаж сорван: нет места совместить внешние шлюзы."
		qdel(src)
		return
	var/obj/machinery/door/airlock/guest = locate() in matched[1]
	var/obj/machinery/door/airlock/host = locate() in matched[2]
	var/datum/stationtrauma_ship_docking/boarding/link = new(attacker, defender)
	link.anchor = berth
	end_notice = null
	qdel(src)
	link.join_hatches(guest, host, matched[3])

/** A fixed installation can be boarded at a free mapped berth without a dispatcher's approval. */
/datum/stationtrauma_boarding_attempt/station
	/// Held through the countdown and native preflight; the docked ship takes ownership on arrival.
	var/datum/stationtrauma_overmap_site/space/reserved_berth
	/// Native docking performs the final footprint, order and ownership checks during this phase.
	var/committing = FALSE

/datum/stationtrauma_boarding_attempt/station/begin()
	reserved_berth.docking_owner = attacker
	..()
	attacker.navigation_notice("Начат абордаж объекта «[reserved_berth.docking_target.name]». Удерживайте дистанцию и скорость до [ST_BOARDING_SPEED] км/с.")

/datum/stationtrauma_boarding_attempt/station/Destroy()
	if(!QDELETED(reserved_berth) && reserved_berth.docking_owner == attacker && attacker?.docked != reserved_berth)
		reserved_berth.docking_owner = null
	reserved_berth = null
	return ..()

/datum/stationtrauma_boarding_attempt/station/approach_problem()
	if(!committing && !attacker.station_boarding_berth(reserved_berth?.docking_target, src))
		return "цель или причал недоступны, превышена скорость или дистанция захвата"
	return null

/datum/stationtrauma_boarding_attempt/station/complete()
	commit_timer = null
	attacker.advance()
	if(QDELETED(src) || !check_approach())
		return
	committing = TRUE
	attacker.stop("Абордаж: захват причала")
	var/arrived = attacker.dock(instant = TRUE, station_authorized = TRUE)
	if(QDELETED(src))
		return
	if(arrived)
		end_notice = null
		attacker.navigation_notice("Абордаж завершён. Корабль пришвартован к причалу «[reserved_berth.name]».")
	else if(!QDELETED(attacker))
		end_notice = "Абордаж сорван. [attacker.status]"
	qdel(src)

/** Both hulls share one physical level and one inertial velocity after capture. */
/datum/stationtrauma_ship_docking/boarding
	maneuver_name = "Абордаж"
	arrival_alarm = 'sound/machines/warning-buzzer.ogg'
	/// Only the helm supplying thrust can countermand this order.
	var/datum/stationtrauma_overmap/space/release_helm
	var/release_at
	/// Distinguishes a cancelled order from a new one issued before its sleeping worker wakes.
	var/release_order = 0
	var/drift_updated

/datum/stationtrauma_ship_docking/boarding/New(datum/stationtrauma_overmap/space/a, datum/stationtrauma_overmap/space/b)
	var/a_mass = max(1, a.vessel.hull_mass)
	var/b_mass = max(1, b.vessel.hull_mass)
	var/vx = (a.velocity_x * a_mass + b.velocity_x * b_mass) / (a_mass + b_mass)
	var/vy = (a.velocity_y * a_mass + b.velocity_y * b_mass) / (a_mass + b_mass)
	..(a, b)
	drift_updated = world.time
	first.velocity_x = second.velocity_x = vx
	first.velocity_y = second.velocity_y = vy
	first.speed = second.speed = sqrt(vx ** 2 + vy ** 2)

/datum/stationtrauma_ship_docking/boarding/Destroy()
	release_helm = null
	var/list/hulls = list(first, second)
	. = ..()
	for(var/datum/stationtrauma_overmap/space/ship as anything in hulls)
		if(!QDELETED(ship) && !ship.ship_docking)
			ship.helm_engaged = ship.speed > ST_NAV_STOPPED_SPEED
			ship.last_update = world.time
			ship.update_parallax()

/datum/stationtrauma_ship_docking/boarding/proc/can_start_release(datum/stationtrauma_overmap/space/helm)
	return !closing && !release_helm && flush && !collar?.busy && (helm in list(first, second)) && !first.preparing && !second.preparing && releasable(helm, helm.control_revision)

/datum/stationtrauma_ship_docking/boarding/proc/announce_release(message, alarm)
	for(var/datum/stationtrauma_overmap/space/ship as anything in list(first, second))
		ship.status = message
		ship.navigation_notice(message, alarm)

/datum/stationtrauma_ship_docking/boarding/proc/cancel_release(datum/stationtrauma_overmap/space/helm)
	if(closing || !release_helm || helm != release_helm)
		return FALSE
	release_helm = null
	release_at = null
	announce_release("Мостик отменил расстыковку. Абордажные захваты удерживаются.")
	return TRUE

/datum/stationtrauma_ship_docking/boarding/release(datum/stationtrauma_overmap/space/departing, instant = FALSE)
	if(!can_start_release(departing))
		return FALSE
	release_helm = departing
	release_at = world.time + ST_BOARDING_RELEASE_TIME
	var/order = ++release_order
	var/revision = departing.control_revision
	announce_release("[departing.vessel.name] готовится разорвать абордажный захват. До разъединения [ST_BOARDING_RELEASE_TIME / (1 SECONDS)] с.", 'sound/machines/warning-buzzer.ogg')
	while(world.time < release_at)
		sleep(min(1 SECONDS, release_at - world.time))
		if(QDELETED(src) || release_helm != departing || order != release_order)
			return FALSE
		if(!releasable(departing, revision))
			release_helm = null
			release_at = null
			announce_release("Расстыковка прервана: потеря тяги или сброс команды на мостике. Захваты удерживаются.")
			return FALSE
	advance_drift()
	if(QDELETED(src))
		return FALSE
	closing = TRUE
	var/problem = collar?.seal_for_release()
	if(QDELETED(src))
		return FALSE
	if(problem || !first.relocate(first.flight_berth, CALLBACK(src, PROC_REF(commit_boarding_release), departing, revision)))
		if(QDELETED(src))
			return FALSE
		closing = FALSE
		release_helm = null
		release_at = null
		if(collar)
			collar.busy = FALSE
		announce_release("Расстыковка прервана: [problem || "проверьте тягу, стоянку и проход"]. Захваты удерживаются.")
		return FALSE
	announce_release("Абордажные захваты разомкнуты.")
	qdel(src)
	return TRUE

/datum/stationtrauma_ship_docking/boarding/proc/commit_boarding_release(datum/stationtrauma_overmap/space/departing, revision)
	return closing && releasable(departing, revision) && (!collar || collar.clear_for_release())

/** Advance the shared drift once per timestamp, stopping both hulls at the first obstacle. */
/datum/stationtrauma_ship_docking/boarding/proc/advance_drift()
	if(QDELETED(first) || QDELETED(second))
		qdel(src)
		return
	if(!flush || closing)
		return
	var/seconds = (world.time - drift_updated) / (1 SECONDS)
	drift_updated = world.time
	if(seconds <= 0 || !first.speed)
		return
	var/dx = first.velocity_x * seconds
	var/dy = first.velocity_y * seconds
	var/fraction = 1
	var/datum/stationtrauma_overmap/space/struck
	var/datum/stationtrauma_overmap_terrain/obstacle
	var/list/hulls = list(first, second)
	for(var/datum/stationtrauma_overmap/space/ship as anything in hulls)
		for(var/datum/stationtrauma_overmap_terrain/terrain as anything in ship.contacts)
			if(!terrain.blocking)
				continue
			var/hit = stationtrauma_terrain_hit(ship.pos_x, ship.pos_y, dx, dy, terrain.pos_x, terrain.pos_y, terrain.end_x, terrain.end_y, ship.radius)
			if(!isnull(hit) && hit <= fraction)
				fraction = hit
				struck = ship
				obstacle = terrain
	if(obstacle)
		fraction = max(0, fraction - 1 / max(1, sqrt(dx ** 2 + dy ** 2)))
		first.velocity_x = second.velocity_x = first.velocity_y = second.velocity_y = 0
		var/impact_speed = first.speed
		first.speed = second.speed = 0
		struck.on_collision(obstacle, impact_speed)
	for(var/datum/stationtrauma_overmap/space/ship as anything in hulls)
		if(!QDELETED(ship))
			ship.pos_x += dx * fraction
			ship.pos_y += dy * fraction
			ship.last_update = world.time
