// AI EDIT START - space overmap module integration
/** Vacuum propulsion and physical vessel navigation. */
/datum/stationtrauma_overmap/space
	throttle = 0
	/// Physical hull controlled by this navigation instance or console.
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	/// Flight-level space area with a stationary parallax background.
	var/area/space/stationtrauma_space_home/exterior
	/// Physical seam used for previews and traversal between hull and destination.
	var/datum/stationtrauma_map_connection/connection
	/// Currently connected destination; null in free flight.
	var/datum/stationtrauma_overmap_site/space/docked
	/// Manual lateral thrust order, retained until release or an explicit propulsion command.
	var/maneuver_direction = NONE
	/// Stoppable completion timer for the current station call.
	var/dispatch_timer
	/// Site reserved by the pending station delivery.
	var/datum/stationtrauma_overmap_site/space/dispatch_target

/datum/stationtrauma_overmap/space/New(obj/docking_port/mobile/stationtrauma_space/owner)
	vessel = owner
	radius = max(12, sqrt(owner.width ** 2 + owner.height ** 2) / 2)
	preparing = TRUE
	connection = new(owner, 1, WEST)
	prepare_flight_berth()
	return ..()

/datum/stationtrauma_overmap/space/Destroy()
	docking_request = null
	QDEL_NULL(ship_docking)
	QDEL_NULL(interior_audio)
	if(engine_audio)
		engine_audio.end_sound = null
		QDEL_NULL(engine_audio)
	cancel_dispatch()
	cancel_jump()
	clear_encounters()
	zones = null
	charted_zones.Cut()
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/space/site = sites[id]
		if(site.docking_owner == src)
			site.docking_owner = null
	QDEL_NULL(connection)
	if(flight_berth)
		qdel(flight_berth, force = TRUE)
		flight_berth = null
	if(vessel?.overmap == src)
		vessel.overmap = null
	for(var/area/ship_area as anything in vessel?.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/console in ship_area)
			if(console.vessel == vessel)
				console.vessel = null
	vessel = null
	exterior = null
	docked = null
	return ..()

/datum/stationtrauma_overmap/space/process(seconds_per_tick)
	if(!is_operational())
		return PROCESS_KILL
	advance()
	refresh_engine_audio()
	process_encounters()
	if(!preparing && !relocating && world.time >= next_listen)
		listen()

/datum/stationtrauma_overmap/space/listen()
	next_listen = world.time + 2 SECONDS
	observe_ships(sensor_range, passive = TRUE)

/** Nominal drive load distinguishes powered manoeuvres from unpowered drift. */
/datum/stationtrauma_overmap/space/detection_signature()
	var/drive = 0
	if(helm_engaged)
		drive = abs(throttle) / 100
		if(braking || maneuver_direction)
			drive = 1
		drive *= vessel.engines_running ? engine_fraction() : 0
	return max(..(), 0.1 + 0.4 * drive)

/datum/stationtrauma_overmap/space/is_operational()
	return !QDELETED(vessel)

/** Available fraction of the native engine registry's nominal power. */
/datum/stationtrauma_overmap/space/proc/engine_fraction()
	var/power = 0
	for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list)
		if(!QDELETED(engine) && engine.anchored && engine.engine_state == initial(engine.engine_state) && !(engine.machine_stat & BROKEN) && engine.get_integrity() > 0)
			if(engine.requires_combustion)
				var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
				power += engine.engine_power * (feed?.propulsion_fraction() || 0)
			else
				power += engine.engine_power
	return clamp(power / max(1, vessel.initial_engine_power), 0, 1)

/datum/stationtrauma_overmap/space/propulsion_available()
	return !preparing && !ship_docking && vessel.engines_running && engine_fraction() > 0

/datum/stationtrauma_overmap/space/get_target_speed()
	return vessel.engines_running ? 5 * engine_fraction() * throttle / 100 : 0

/datum/stationtrauma_overmap/space/get_braking_acceleration()
	return vessel.engines_running ? (5 / 15) * engine_fraction() : 0

/datum/stationtrauma_overmap/space/get_braking_distance()
	var/acceleration = get_braking_acceleration()
	return acceleration ? speed ** 2 / (2 * acceleration) : null

/** Manual thrust retains lateral drift; the autopilot uses the same bounded acceleration to brake. */
/datum/stationtrauma_overmap/space/integrate_velocity(seconds, available)
	var/list/step = thrust_step(seconds, available, maneuver_direction, course, velocity_x, velocity_y)
	velocity_x = step[3]
	velocity_y = step[4]
	return step

/** Retain a validated lateral thrust order independently of navigation window focus. */
/datum/stationtrauma_overmap/space/proc/command_maneuver(direction)
	if(!(direction in list(NONE, EAST, WEST)) || !vessel.engines_running || preparing || relocating || docked || ship_docking || autopilot || braking)
		return FALSE
	if(direction && !helm_engaged && !sail())
		return FALSE
	command_course(ordered_course)
	maneuver_direction = direction
	return TRUE

/** Successful automation replaces the retained manual lateral thrust order. */
/datum/stationtrauma_overmap/space/engage_autopilot()
	. = ..()
	if(. && !QDELETED(src))
		maneuver_direction = NONE

/** Thrust resumes manual flight without requiring another undocking order. */
/datum/stationtrauma_overmap/space/command_throttle(value)
	if(!IS_FINITE(value) || !vessel.engines_running || ship_docking)
		return FALSE
	. = ..(abs(value))
	if(!.)
		return FALSE
	throttle = value
	if(value == 0)
		request_brake()
	if(value != 0 && !helm_engaged && !docked && !preparing && !relocating)
		return sail()

/datum/stationtrauma_overmap/space/stop(reason = "Корабль остановлен")
	cancel_dispatch()
	cancel_jump()
	throttle = 0
	maneuver_direction = NONE
	. = ..()
	refresh_engine_audio()

/datum/stationtrauma_overmap/space/request_brake()
	cancel_jump()
	maneuver_direction = NONE
	return ..()

/** Return displacement and final velocity without mutating the live ship, also used by the chart forecast. */
/datum/stationtrauma_overmap/space/proc/thrust_step(seconds, available, direction, heading, vx, vy)
	var/change_x = sin(heading) * available - vx
	var/change_y = cos(heading) * available - vy
	var/acceleration = get_braking_acceleration()
	if(!autopilot && !braking)
		var/forward_speed = sin(heading) * vx + cos(heading) * vy
		var/budget = acceleration * seconds
		var/forward_change = clamp(available - forward_speed, -budget, budget)
		var/side_change = budget * (!!(direction & EAST) - !!(direction & WEST))
		var/requested = sqrt(forward_change ** 2 + side_change ** 2)
		var/budget_scale = requested > budget ? budget / requested : 1
		var/next_x = vx + (sin(heading) * forward_change + cos(heading) * side_change) * budget_scale
		var/next_y = vy + (cos(heading) * forward_change - sin(heading) * side_change) * budget_scale
		var/next_speed = sqrt(next_x ** 2 + next_y ** 2)
		// Permit steering at the cap, and preserve existing drift after engine damage.
		var/limit = max(5 * engine_fraction(), sqrt(vx ** 2 + vy ** 2))
		var/scale = next_speed > limit ? limit / next_speed : 1
		change_x = next_x * scale - vx
		change_y = next_y * scale - vy
	else
		if(braking)
			change_x = -vx
			change_y = -vy
	var/change_length = sqrt(change_x ** 2 + change_y ** 2)
	var/duration = acceleration ? min(seconds, change_length / acceleration) : 0
	var/fraction = change_length ? acceleration * duration / change_length : 0
	if(autopilot || braking)
		change_x *= fraction
		change_y *= fraction
	return list(vx * seconds + change_x * (seconds - duration / 2), vy * seconds + change_y * (seconds - duration / 2), vx + change_x, vy + change_y)

/** Forecast 20/40/60 seconds under the present thrust order; do not advance time or reveal terrain. */
/datum/stationtrauma_overmap/space/proc/predict_trajectory()
	var/list/points = list()
	if(!helm_engaged || docked || ship_docking || relocating || jump_target)
		return points
	var/x = pos_x
	var/y = pos_y
	var/vx = velocity_x
	var/vy = velocity_y
	var/heading = course
	var/available = braking ? 0 : get_target_speed()
	// Forecast holds the current order; future autopilot decisions and collisions can change it.
	for(var/second in 1 to 60)
		var/turn = WRAP(ordered_course - heading + 180, 0, 360) - 180
		heading = WRAP(heading + clamp(turn, -ST_NAV_TURN_RATE, ST_NAV_TURN_RATE), 0, 360)
		var/list/step = thrust_step(1, available, maneuver_direction, heading, vx, vy)
		x += step[1]
		y += step[2]
		vx = step[3]
		vy = step[4]
		if(second % 20 == 0)
			points += list(list("x" = x, "y" = y, "seconds" = second))
	return points

/datum/stationtrauma_overmap/space/select_site(id)
	if(relocating)
		return FALSE
	. = ..()
	if(.)
		prepared_site = sites[id]

/** Leave virtual docks in place; planetary departures first return the real hull to its flight berth. */
/datum/stationtrauma_overmap/space/sail()
	var/leaving_ship = !!ship_docking
	if(ship_docking && !ship_docking.release(src))
		return FALSE
	if(!propulsion_available() || arrival_pending || relocating)
		return FALSE
	if(leaving_ship)
		throttle = 50
	if((docked?.landing || docked?.physical_docking) && !relocate(flight_berth))
		stop(status)
		return FALSE
	if(docked)
		var/datum/stationtrauma_overmap_site/space/old_dock = docked
		var/revision = control_revision
		preparing = TRUE
		connection.disconnect_cooperatively(new /datum/stationtrauma_work_budget)
		if(QDELETED(src))
			return FALSE
		if(old_dock.docking_owner == src)
			old_dock.docking_owner = null
		docked = null
		preparing = FALSE
		play_maneuver_audio(old_dock.berth, departing = TRUE)
		refresh_engine_audio()
		update_parallax()
		if(QDELETED(src) || revision != control_revision)
			return FALSE
		throttle = 50
		// The berth just left is no longer an arrival order during the first slow acceleration tick.
		if(sites[selected_destination] == old_dock)
			selected_destination = null
			prepared_site = null
	return ..()

/** Stop the autopilot at its destination; manual flight remains unrestricted. */
/datum/stationtrauma_overmap/space/arrive(datum/stationtrauma_overmap_site/site)
	if(autopilot && can_arrive(site))
		stop("Точка назначения достигнута: [site.name]")
	arrival_pending = FALSE

/** Whether docking may begin before the berth exists because the descent generates it. */
/datum/stationtrauma_overmap_site/space/proc/awaits_surface()
	return FALSE

/** Revalidate the selected site, berth ownership, proximity and helm order revision. */
/datum/stationtrauma_overmap/space/proc/can_dock(datum/stationtrauma_overmap_site/space/site, revision)
	if(!is_operational() || ship_docking || !knows_site(site) || (QDELETED(site.berth) && !site.awaits_surface()) || site.failed || !vessel.permits_docking(site) || (site.docking_owner && site.docking_owner != src) || revision != control_revision || helm_engaged || site != sites[selected_destination] || distance_to(site) > radius + site.radius + ST_NAV_APPROACH + 5)
		return FALSE
	// The generated berth is sized for the prototype hull; descent revalidates it once it exists.
	if(site.awaits_surface())
		return TRUE
	if(site.landing || site.physical_docking)
		var/compatibility = vessel.canDock(site.berth)
		return compatibility == SHUTTLE_CAN_DOCK || compatibility == SHUTTLE_ALREADY_DOCKED
	return TRUE

/** Build inactive seams cooperatively and revalidate stop/selection before publishing them. */
/datum/stationtrauma_overmap/space/proc/dock()
	var/datum/stationtrauma_overmap_site/space/site = sites[selected_destination]
	if(preparing || docked || helm_engaged || speed > 0.05 || !can_dock(site, control_revision))
		return FALSE
	// Reserve before native movement or seam construction can yield to another ship.
	site.docking_owner = src
	clear_encounters()
	stop("Стыковка: [site.name]")
	var/revision = control_revision
	preparing = TRUE
	var/datum/stationtrauma_work_budget/budget = new
	var/ready = FALSE
	var/physical_docking = site.landing || site.physical_docking
	try
		if(site.landing)
			ready = descend(site, revision)
		else if(physical_docking)
			ready = relocate(site.berth)
		else
			ready = connection.connect(site.berth, budget, FALSE, 1, 1) && connection.activate(budget, CALLBACK(src, PROC_REF(can_dock), site, revision))
	catch(var/exception/failure)
		stack_trace("Space prototype docking failed: [failure]")
	if(QDELETED(src))
		return FALSE
	landing_started = 0
	update_parallax()
	// Native relocation has committed the hull; an engine stop cannot roll that movement back.
	ready = ready && (physical_docking ? vessel.get_docked() == site.berth : can_dock(site, revision))
	if(!ready)
		connection.disconnect_cooperatively(budget)
		if(site.docking_owner == src)
			site.docking_owner = null
	preparing = FALSE
	if(!ready)
		if(revision == control_revision && !site.landing)
			status = "Стыковка не выполнена: переход перекрыт"
		return FALSE
	docked = site
	visited_sites[site.id] = TRUE
	pos_x = site.pos_x
	pos_y = site.pos_y
	status = site.landing ? "Посадка: [site.name]" : "Стыковка: [site.name]"
	play_maneuver_audio(site.berth)
	refresh_engine_audio()
	update_parallax()
	return TRUE

/datum/stationtrauma_overmap/space/update_parallax()
	var/direction = speed > 0.05 || landing_started || jump_phase >= HYPERSPACE_LAUNCH ? vessel.preferred_direction : NONE
	var/background = parallax_background()
	var/motion_changed = direction != parallax_direction
	if(!motion_changed && background == space_background)
		return
	space_background = background
	parallax_direction = direction
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		ship_area.set_space_parallax_background(background)
		if(motion_changed)
			ship_area.set_parallax_movedir(direction)
	exterior?.set_space_parallax_background(background)
	exterior?.set_parallax_movedir(NONE)

/datum/stationtrauma_overmap/space/on_collision(datum/stationtrauma_overmap_terrain/obstacle, impact_speed)
	var/list/nearest = obstacle.nearest(pos_x, pos_y)
	var/turf/target = stationtrauma_navigation_hull_target(vessel, course, 1, nearest[1] - pos_x, nearest[2] - pos_y, vessel.preferred_direction)
	// A full-speed impact (5 sector units/s) reaches the severe, repairable hull tear tier.
	stationtrauma_damage_hull(vessel, target, impact_speed * 12)
// AI EDIT END
