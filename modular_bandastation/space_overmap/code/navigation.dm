/// Vacuum adapter; shared routes, swept collisions, passages and previews also serve submarines.
/datum/stationtrauma_overmap/space
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	var/area/space/stationtrauma_space_home/exterior
	var/datum/stationtrauma_map_connection/connection
	var/datum/stationtrauma_overmap_site/space/docked
	var/throttle = 100

/datum/stationtrauma_overmap/space/New(obj/docking_port/mobile/stationtrauma_space/owner)
	vessel = owner
	radius = max(12, sqrt(owner.width ** 2 + owner.height ** 2) / 2)
	preparing = TRUE
	connection = new(owner, 1, WEST)
	return ..()

/datum/stationtrauma_overmap/space/Destroy()
	QDEL_NULL(connection)
	vessel = null
	exterior = null
	docked = null
	return ..()

/datum/stationtrauma_overmap/space/process(seconds_per_tick)
	if(!is_operational())
		return PROCESS_KILL
	advance()

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
	return 60 * throttle / 100 * engine_fraction()

/** Manual thrust retains lateral drift; the autopilot uses the same bounded acceleration to brake. */
/datum/stationtrauma_overmap/space/integrate_velocity(seconds, available)
	var/change_x = sin(course) * available - velocity_x
	var/change_y = cos(course) * available - velocity_y
	var/acceleration = 4 * throttle / 100 * engine_fraction()
	if(!autopilot)
		var/forward = velocity_x * sin(course) + velocity_y * cos(course)
		var/impulse = min(acceleration * seconds, max(0, available - forward))
		change_x = sin(course) * impulse
		change_y = cos(course) * impulse
	else
		var/change_length = sqrt(change_x ** 2 + change_y ** 2)
		var/fraction = change_length ? min(1, acceleration * seconds / change_length) : 0
		change_x *= fraction
		change_y *= fraction
	var/list/displacement = list((velocity_x + change_x / 2) * seconds, (velocity_y + change_y / 2) * seconds)
	velocity_x += change_x
	velocity_y += change_y
	return displacement

/datum/stationtrauma_overmap/space/select_site(id)
	. = ..()
	if(.)
		prepared_site = sites[id]

/** Disconnect only the view and gates; resources, mobs and structures remain on their own levels. */
/datum/stationtrauma_overmap/space/sail()
	if(!propulsion_available() || arrival_pending)
		return FALSE
	if(docked)
		var/revision = control_revision
		preparing = TRUE
		connection.disconnect_cooperatively(new /datum/stationtrauma_work_budget)
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
	return is_operational() && site?.berth && !site.failed && revision == control_revision && !helm_engaged && site == sites[selected_destination] && distance_to(site) <= radius + site.radius + ST_NAV_APPROACH + 5

/** Build inactive seams cooperatively and revalidate stop/selection before publishing them. */
/datum/stationtrauma_overmap/space/proc/dock()
	var/datum/stationtrauma_overmap_site/space/site = sites[selected_destination]
	if(preparing || docked || helm_engaged || speed > 0.05 || !can_dock(site, control_revision))
		return FALSE
	stop("Стыковка: [site.name]")
	var/revision = control_revision
	preparing = TRUE
	var/datum/stationtrauma_work_budget/budget = new
	var/ready = FALSE
	try
		ready = connection.connect(site.berth, budget, FALSE, 1, 1) && connection.activate(budget, CALLBACK(src, PROC_REF(can_dock), site, revision))
	catch(var/exception/failure)
		stack_trace("Space prototype docking failed: [failure]")
	if(!ready)
		connection.disconnect_cooperatively(budget)
	preparing = FALSE
	if(!ready)
		if(revision == control_revision)
			status = "Стыковка не выполнена: переход перекрыт"
		return FALSE
	docked = site
	site.visited = TRUE
	pos_x = site.pos_x
	pos_y = site.pos_y
	status = site.landing ? "Посадка: [site.name]" : "Стыковка: [site.name]"
	return TRUE

/datum/stationtrauma_overmap/space/update_parallax()
	// Raven's bow faces north; native parallax moves the backdrop in the opposite direction.
	var/direction = speed > 0.05 ? NORTH : NONE
	if(direction == parallax_direction)
		return
	parallax_direction = direction
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		ship_area.set_parallax_movedir(direction)
	exterior?.set_parallax_movedir(direction)

/datum/stationtrauma_overmap/space/on_collision(datum/stationtrauma_overmap_terrain/obstacle, impact_speed)
	var/list/nearest = obstacle.nearest(pos_x, pos_y)
	var/turf/target = stationtrauma_navigation_hull_target(vessel, course, 1, nearest[1] - pos_x, nearest[2] - pos_y)
	stationtrauma_damage_hull(vessel, target, impact_speed)
