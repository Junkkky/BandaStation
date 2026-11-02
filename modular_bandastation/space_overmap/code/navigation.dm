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
	/// Emergency manoeuvring thrusters are braking; they need ship power, not the main engines.
	var/emergency_braking = FALSE

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
	// Drag or the emergency thrusters ended an unpowered drift.
	if(helm_engaged && !vessel.engines_running && !arrival_pending && !jump_target && speed <= ST_NAV_STOPPED_SPEED)
		stop("Дрейф погашен")
	refresh_engine_audio()
	process_encounters()
	if(!preparing && !relocating && world.time >= next_listen)
		listen()

/** Passive ship observations within sensor range, refreshed every two seconds. */
/datum/stationtrauma_overmap/space/proc/listen()
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
		power += engine.engine_power * engine_output(engine)
	return clamp(power / max(1, vessel.initial_engine_power), 0, 1)

/** Engine power actually delivered per hull tile: the heavier the hull, the weaker the same engines. */
/datum/stationtrauma_overmap/space/proc/thrust_ratio()
	var/power = 0
	for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list)
		power += engine.engine_power * engine_output(engine)
	return power / max(1, vessel.hull_mass)

/** Top speed from the delivered thrust ratio; it grows with its square root and is capped. */
/datum/stationtrauma_overmap/space/proc/max_speed()
	return min(ST_SPACE_MAX_SPEED, ST_SPACE_REFERENCE_SPEED * sqrt(thrust_ratio() / ST_SPACE_REFERENCE_THRUST))

/datum/stationtrauma_overmap/space/turn_rate()
	return ST_NAV_TURN_RATE * clamp(sqrt(ST_SPACE_REFERENCE_MASS / max(1, vessel.hull_mass)), 0.5, 2)

/** Share of one intact engine's nominal power; gas-fed nozzles depend on their delivered feed. */
/datum/stationtrauma_overmap/space/proc/engine_output(obj/machinery/power/shuttle_engine/engine)
	if(QDELETED(engine) || !engine.anchored || engine.engine_state != initial(engine.engine_state) || (engine.machine_stat & BROKEN) || engine.get_integrity() <= 0)
		return 0
	if(!engine.requires_combustion)
		return 1
	var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
	return feed?.propulsion_fraction() || 0

/datum/stationtrauma_overmap/space/propulsion_available()
	return !preparing && !ship_docking && vessel.engines_running && engine_fraction() > 0

/datum/stationtrauma_overmap/space/get_target_speed()
	return vessel.engines_running ? max_speed() * throttle / 100 : 0

/datum/stationtrauma_overmap/space/get_braking_acceleration()
	return vessel.engines_running ? min(1, (ST_SPACE_REFERENCE_SPEED / 15) * thrust_ratio() / ST_SPACE_REFERENCE_THRUST) : 0

/datum/stationtrauma_overmap/space/get_braking_distance()
	var/acceleration = get_braking_acceleration() + drift_damping()
	return acceleration ? speed ** 2 / (2 * acceleration) : null

/** Deceleration applied regardless of the main engines: constant drag plus powered emergency thrusters. */
/datum/stationtrauma_overmap/space/proc/drift_damping()
	return ST_SPACE_DRAG + (emergency_braking && vessel.has_power() ? ST_SPACE_RCS_DECELERATION : 0)

/** Brake on the powered emergency thrusters; works with the main engines off or destroyed. */
/datum/stationtrauma_overmap/space/proc/command_emergency_brake()
	if(preparing || relocating || docked || ship_docking || speed <= ST_NAV_STOPPED_SPEED || !vessel.has_power())
		return FALSE
	request_brake()
	emergency_braking = TRUE
	return TRUE

/** Manual thrust retains lateral drift; the autopilot uses the same bounded acceleration to brake. */
/datum/stationtrauma_overmap/space/integrate_velocity(seconds, available)
	var/list/step = thrust_step(seconds, available, maneuver_direction, course, velocity_x, velocity_y, drift_damping())
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
		emergency_braking = FALSE

/** Thrust resumes manual flight without requiring another undocking order. */
/datum/stationtrauma_overmap/space/command_throttle(value)
	if(!IS_FINITE(value) || !vessel.engines_running || ship_docking)
		return FALSE
	. = ..(abs(value))
	if(!.)
		return FALSE
	throttle = value
	if(value != 0)
		emergency_braking = FALSE
	if(value == 0)
		request_brake()
	if(value != 0 && !helm_engaged && !docked && !preparing && !relocating)
		return sail()

/datum/stationtrauma_overmap/space/stop(reason = "Корабль остановлен")
	cancel_dispatch()
	cancel_jump()
	throttle = 0
	maneuver_direction = NONE
	emergency_braking = FALSE
	. = ..()
	refresh_engine_audio()

/datum/stationtrauma_overmap/space/request_brake()
	cancel_jump()
	maneuver_direction = NONE
	return ..()

/**
 * Return displacement and final velocity without mutating the live ship, also used by the chart forecast.
 *
 * Arguments:
 * * damping - Deceleration per second that acts whatever the engines do
 */
/datum/stationtrauma_overmap/space/proc/thrust_step(seconds, available, direction, heading, vx, vy, damping = 0)
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
		var/limit = max(max_speed(), sqrt(vx ** 2 + vy ** 2))
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
	var/next_x = vx + change_x
	var/next_y = vy + change_y
	var/step_x = vx * seconds + change_x * (seconds - duration / 2)
	var/step_y = vy * seconds + change_y * (seconds - duration / 2)
	var/next_speed = sqrt(next_x ** 2 + next_y ** 2)
	if(damping > 0 && next_speed > 0)
		var/loss = min(next_speed, damping * seconds)
		step_x -= next_x / next_speed * loss * seconds / 2
		step_y -= next_y / next_speed * loss * seconds / 2
		next_x *= (next_speed - loss) / next_speed
		next_y *= (next_speed - loss) / next_speed
	return list(step_x, step_y, next_x, next_y)

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
	var/damping = drift_damping()
	var/rate = turn_rate()
	// Forecast holds the current order; future autopilot decisions and collisions can change it.
	for(var/second in 1 to 60)
		var/turn = WRAP(ordered_course - heading + 180, 0, 360) - 180
		heading = WRAP(heading + clamp(turn, -rate, rate), 0, 360)
		var/list/step = thrust_step(1, available, maneuver_direction, heading, vx, vy, damping)
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

/** Revalidate the selected site, berth ownership, proximity and helm order revision. */
/datum/stationtrauma_overmap/space/proc/can_dock(datum/stationtrauma_overmap_site/space/site, revision)
	if(!is_operational() || ship_docking || !knows_site(site) || (QDELETED(site.berth) && !site.awaits_map()) || site.failed || !vessel.permits_docking(site) || (site.docking_owner && site.docking_owner != src) || revision != control_revision || helm_engaged || site != sites[selected_destination] || distance_to(site) > radius + site.radius + ST_NAV_APPROACH + 5)
		return FALSE
	// Loaded berths are sized for the prototype hull; the approach revalidates them once they exist.
	if(site.awaits_map())
		return TRUE
	if(site.landing || site.physical_docking)
		var/compatibility = vessel.canDock(site.berth)
		return compatibility == SHUTTLE_CAN_DOCK || compatibility == SHUTTLE_ALREADY_DOCKED
	return TRUE

/** Build inactive seams cooperatively and revalidate stop/selection before publishing them. */
/datum/stationtrauma_overmap/space/proc/dock()
	var/datum/stationtrauma_overmap_site/space/site = sites[selected_destination]
	if(preparing || docked || helm_engaged || speed > ST_NAV_STOPPED_SPEED || !can_dock(site, control_revision))
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
		if(site.physical_docking)
			ready = relocate(site.berth)
		else if(approach(site, revision))
			ready = site.landing ? relocate(site.berth) : connection.connect(site.berth, budget, FALSE, 1, 1) && connection.activate(budget, CALLBACK(src, PROC_REF(can_dock), site, revision))
	catch(var/exception/failure)
		stack_trace("Space prototype docking failed: [failure]")
	if(QDELETED(src))
		return FALSE
	approach_started = 0
	update_parallax()
	// Native relocation has committed the hull; an engine stop cannot roll that movement back.
	ready = ready && (physical_docking ? vessel.get_docked() == site.berth : can_dock(site, revision))
	if(!ready)
		connection.disconnect_cooperatively(budget)
		if(site.docking_owner == src)
			site.docking_owner = null
	preparing = FALSE
	if(!ready)
		if(revision == control_revision && !site.failed)
			status = site.landing ? "Посадка прервана" : "Стыковка не выполнена: переход перекрыт"
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

/**
 * Parallax follows the real velocity in the hull's frame: a ship sliding sideways or backwards shows it.
 *
 * Native parallax animates only cardinal directions, so the motion is rounded to the nearest one.
 */
/datum/stationtrauma_overmap/space/proc/parallax_motion_dir()
	if(approach_started || jump_phase >= HYPERSPACE_LAUNCH)
		return vessel.preferred_direction
	if(speed <= ST_NAV_STOPPED_SPEED)
		return NONE
	// Compass bearing of the velocity relative to the virtual heading, turned onto the hull's mapped nose.
	var/bearing = 90 - ATAN2(velocity_x, velocity_y)
	var/angle = WRAP(dir2angle(vessel.preferred_direction) + bearing - course, 0, 360)
	// Keep the current direction near a 45 degree boundary instead of flickering between two.
	if(parallax_direction && abs(WRAP(angle - dir2angle(parallax_direction) + 180, 0, 360) - 180) <= 55)
		return parallax_direction
	return angle2dir_cardinal(angle)

/datum/stationtrauma_overmap/space/update_parallax()
	var/direction = parallax_motion_dir()
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
