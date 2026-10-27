/// Vacuum adapter; shared routes, swept collisions, passages and previews also serve submarines.
/datum/stationtrauma_overmap/space
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	var/area/space/stationtrauma_space_home/exterior
	var/datum/stationtrauma_map_connection/connection
	var/datum/stationtrauma_overmap_site/space/docked
	var/maneuver_direction = NONE
	var/maneuver_until = 0

/datum/stationtrauma_overmap/space/New(obj/docking_port/mobile/stationtrauma_space/owner)
	vessel = owner
	radius = max(12, sqrt(owner.width ** 2 + owner.height ** 2) / 2)
	preparing = TRUE
	connection = new(owner, 1, WEST)
	prepare_flight_berth()
	return ..()

/datum/stationtrauma_overmap/space/Destroy()
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
		drive = throttle / 100
		if(braking || (maneuver_direction && world.time < maneuver_until))
			drive = 1
		drive *= engine_fraction()
	return max(..(), 0.1 + 0.4 * drive)

/datum/stationtrauma_overmap/space/is_operational()
	return !QDELETED(vessel)

/** Native engine membership is maintained by shuttle construction/destruction, not world scans. */
/datum/stationtrauma_overmap/space/proc/engine_fraction()
	var/power = 0
	for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list)
		if(!QDELETED(engine) && engine.anchored && engine.engine_state == initial(engine.engine_state) && !(engine.machine_stat & BROKEN) && engine.get_integrity() > 0)
			power += engine.engine_power
	return clamp(power / max(1, vessel.initial_engine_power), 0, 1)

/datum/stationtrauma_overmap/space/propulsion_available()
	return !preparing && engine_fraction() > 0

/datum/stationtrauma_overmap/space/get_target_speed()
	return 5 * engine_fraction()

/datum/stationtrauma_overmap/space/get_braking_acceleration()
	return (5 / 15) * engine_fraction() * (autopilot ? throttle / 100 : 1)

/datum/stationtrauma_overmap/space/get_braking_distance()
	var/acceleration = get_braking_acceleration()
	return acceleration ? speed ** 2 / (2 * acceleration) : null

/** Manual thrust retains lateral drift; the autopilot uses the same bounded acceleration to brake. */
/datum/stationtrauma_overmap/space/integrate_velocity(seconds, available)
	// Split at expiry: a delayed tick must not extend a lost keyboard command.
	var/active_seconds = clamp((maneuver_until - world.time) / (1 SECONDS) + seconds, 0, seconds)
	if(!maneuver_direction || !active_seconds)
		return integrate_thrust(seconds, available, NONE)
	if(active_seconds == seconds)
		return integrate_thrust(seconds, available, maneuver_direction)
	var/list/displacement = integrate_thrust(active_seconds, available, maneuver_direction)
	var/list/coasting = integrate_thrust(seconds - active_seconds, available, NONE)
	return list(displacement[1] + coasting[1], displacement[2] + coasting[2])

/datum/stationtrauma_overmap/space/proc/command_maneuver(direction)
	if(!(direction in list(NONE, EAST, WEST)) || !helm_engaged || preparing || relocating || docked || autopilot || braking)
		return FALSE
	maneuver_direction = direction
	maneuver_until = world.time + 0.6 SECONDS
	return TRUE

/datum/stationtrauma_overmap/space/stop(reason = "Стоп-машина")
	maneuver_direction = NONE
	maneuver_until = 0
	return ..()

/datum/stationtrauma_overmap/space/request_brake()
	maneuver_direction = NONE
	maneuver_until = 0
	return ..()

/datum/stationtrauma_overmap/space/proc/integrate_thrust(seconds, available, direction)
	var/change_x = sin(course) * available - velocity_x
	var/change_y = cos(course) * available - velocity_y
	var/acceleration = get_braking_acceleration()
	if(!autopilot && !braking)
		var/forward_thrust = throttle / 100
		var/side_thrust = !!(direction & EAST) - !!(direction & WEST)
		var/magnitude = sqrt(forward_thrust ** 2 + side_thrust ** 2)
		var/thrust_x = magnitude ? (sin(course) * forward_thrust + cos(course) * side_thrust) / magnitude : 0
		var/thrust_y = magnitude ? (cos(course) * forward_thrust - sin(course) * side_thrust) / magnitude : 0
		acceleration *= min(1, magnitude)
		var/next_x = velocity_x + thrust_x * acceleration * seconds
		var/next_y = velocity_y + thrust_y * acceleration * seconds
		var/next_speed = sqrt(next_x ** 2 + next_y ** 2)
		// Permit steering at the cap, and preserve existing drift after engine damage.
		var/limit = max(available, sqrt(velocity_x ** 2 + velocity_y ** 2))
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
	if(!propulsion_available() || arrival_pending || relocating)
		return FALSE
	if(docked?.landing && !relocate(flight_berth))
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
		if(QDELETED(src) || revision != control_revision)
			return FALSE
	return ..()

/** Approaching is distinct from docking; the physical connection opens only after an explicit order. */
/datum/stationtrauma_overmap/space/arrive(datum/stationtrauma_overmap_site/site)
	if(can_arrive(site))
		stop("Подход завершён: [site.name]. Доступна стыковка или посадка.")
	arrival_pending = FALSE

/datum/stationtrauma_overmap/space/proc/can_dock(datum/stationtrauma_overmap_site/space/site, revision)
	return is_operational() && knows_site(site) && site.berth && !site.failed && (!site.landing || vessel.can_land) && (!site.docking_owner || site.docking_owner == src) && revision == control_revision && !helm_engaged && site == sites[selected_destination] && distance_to(site) <= radius + site.radius + ST_NAV_APPROACH + 5

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
		if(site.landing)
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
	return TRUE

/datum/stationtrauma_overmap/space/update_parallax()
	var/direction = speed > 0.05 ? vessel.preferred_direction : NONE
	if(direction == parallax_direction)
		return
	parallax_direction = direction
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		ship_area.set_parallax_movedir(direction)
	exterior?.set_parallax_movedir(direction)

/datum/stationtrauma_overmap/space/on_collision(datum/stationtrauma_overmap_terrain/obstacle, impact_speed)
	var/list/nearest = obstacle.nearest(pos_x, pos_y)
	var/turf/target = stationtrauma_navigation_hull_target(vessel, course, 1, nearest[1] - pos_x, nearest[2] - pos_y, vessel.preferred_direction)
	stationtrauma_damage_hull(vessel, target, impact_speed)
