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
	/// Up to three recent positions, oldest first, drawn as the chart's fading track.
	var/list/track = list()
	/// World time of the next track sample.
	var/next_track = 0

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
	if(world.time >= next_track)
		next_track = world.time + 20 SECONDS
		track += list(list(pos_x, pos_y))
		if(length(track) > 3)
			track.Cut(1, 2)
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
	return integrate_thrust(seconds, available, maneuver_direction)

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

/** Integrate bounded forward and lateral acceleration, preserving unopposed drift. */
/datum/stationtrauma_overmap/space/proc/integrate_thrust(seconds, available, direction)
	var/change_x = sin(course) * available - velocity_x
	var/change_y = cos(course) * available - velocity_y
	var/acceleration = get_braking_acceleration()
	if(!autopilot && !braking)
		var/forward_speed = sin(course) * velocity_x + cos(course) * velocity_y
		var/budget = acceleration * seconds
		var/forward_change = clamp(available - forward_speed, -budget, budget)
		var/side_change = budget * (!!(direction & EAST) - !!(direction & WEST))
		var/requested = sqrt(forward_change ** 2 + side_change ** 2)
		var/budget_scale = requested > budget ? budget / requested : 1
		var/next_x = velocity_x + (sin(course) * forward_change + cos(course) * side_change) * budget_scale
		var/next_y = velocity_y + (cos(course) * forward_change - sin(course) * side_change) * budget_scale
		var/next_speed = sqrt(next_x ** 2 + next_y ** 2)
		// Permit steering at the cap, and preserve existing drift after engine damage.
		var/limit = max(5 * engine_fraction(), sqrt(velocity_x ** 2 + velocity_y ** 2))
		var/scale = next_speed > limit ? limit / next_speed : 1
		change_x = next_x * scale - velocity_x
		change_y = next_y * scale - velocity_y
	else
		if(braking)
			change_x = -velocity_x
			change_y = -velocity_y
	var/change_length = sqrt(change_x ** 2 + change_y ** 2)
	var/duration = acceleration ? min(seconds, change_length / acceleration) : 0
	var/fraction = change_length ? acceleration * duration / change_length : 0
	if(autopilot || braking)
		change_x *= fraction
		change_y *= fraction
	var/list/displacement = list(velocity_x * seconds + change_x * (seconds - duration / 2), velocity_y * seconds + change_y * (seconds - duration / 2))
	velocity_x += change_x
	velocity_y += change_y
	return displacement

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
	if(!is_operational() || ship_docking || !knows_site(site) || QDELETED(site.berth) || site.failed || !vessel.permits_docking(site) || (site.docking_owner && site.docking_owner != src) || revision != control_revision || helm_engaged || site != sites[selected_destination] || distance_to(site) > radius + site.radius + ST_NAV_APPROACH + 5)
		return FALSE
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
	try
		if(site.landing || site.physical_docking)
			ready = relocate(site.berth)
		else
			ready = connection.connect(site.berth, budget, FALSE, 1, 1) && connection.activate(budget, CALLBACK(src, PROC_REF(can_dock), site, revision))
	catch(var/exception/failure)
		stack_trace("Space prototype docking failed: [failure]")
	if(QDELETED(src))
		return FALSE
	ready = ready && can_dock(site, revision)
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
	var/direction = speed > 0.05 || jump_phase >= HYPERSPACE_LAUNCH ? vessel.preferred_direction : NONE
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
