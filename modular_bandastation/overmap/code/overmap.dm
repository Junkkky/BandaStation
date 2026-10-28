/// Navigation metres are independent of physical turf coordinates.
#define ST_NAV_TURN_RATE 15
#define ST_NAV_APPROACH 40
#define ST_NAV_ACTIVE_RANGE 1200
#define ST_NAV_PASSIVE_RANGE 700
#define ST_NAV_PING_INTERVAL (3 SECONDS)
#define ST_NAV_SHIP_MEMORY (1 MINUTES)

/** First contact of a moving point with a circle; null means a clear segment. */
/proc/stationtrauma_circle_hit(px, py, dx, dy, cx, cy, radius)
	var/length_squared = dx * dx + dy * dy
	if(!length_squared)
		return null
	var/offset_x = px - cx
	var/offset_y = py - cy
	var/projection = offset_x * dx + offset_y * dy
	var/separation = offset_x * offset_x + offset_y * offset_y - radius * radius
	if(separation <= 0)
		return projection < 0 ? 0 : null
	var/discriminant = projection * projection - length_squared * separation
	if(discriminant < 0)
		return null
	var/contact = (-projection - sqrt(discriminant)) / length_squared
	return contact >= 0 && contact <= 1 ? contact : null

/** Swept circle against a terrain segment, including its rounded ends; no tunnelling between ticks. */
/proc/stationtrauma_terrain_hit(px, py, dx, dy, ax, ay, bx, by, radius)
	var/length = sqrt((bx - ax) ** 2 + (by - ay) ** 2)
	if(!length)
		return stationtrauma_circle_hit(px, py, dx, dy, ax, ay, radius)
	var/tangent_x = (bx - ax) / length
	var/tangent_y = (by - ay) / length
	var/normal_offset = (py - ay) * tangent_x - (px - ax) * tangent_y
	var/normal_motion = dy * tangent_x - dx * tangent_y
	var/along = (px - ax) * tangent_x + (py - ay) * tangent_y
	var/nearest = clamp(along, 0, length)
	var/offset_x = px - ax - nearest * tangent_x
	var/offset_y = py - ay - nearest * tangent_y
	if(offset_x ** 2 + offset_y ** 2 <= radius ** 2)
		return offset_x * dx + offset_y * dy < 0 ? 0 : null
	var/contact = stationtrauma_circle_hit(px, py, dx, dy, ax, ay, radius)
	var/end_contact = stationtrauma_circle_hit(px, py, dx, dy, bx, by, radius)
	if(!isnull(end_contact) && (isnull(contact) || end_contact < contact))
		contact = end_contact
	if(!normal_motion)
		return contact
	for(var/side in list(-1, 1))
		var/fraction = (side * radius - normal_offset) / normal_motion
		if(fraction < 0 || fraction > 1 || (!isnull(contact) && fraction >= contact))
			continue
		var/projected = along + fraction * (dx * tangent_x + dy * tangent_y)
		if(projected >= 0 && projected <= length)
			contact = fraction
	return contact

/** One virtual vessel; movement never scans or relocates physical map contents. */
/datum/stationtrauma_overmap
	var/datum/stationtrauma_overmap_sector/sector
	var/list/discovered_sites = list()
	var/list/visited_sites = list()
	/// Stable selected location ID, independent of its physical map.
	var/selected_destination
	/// Navigation status shared by attached displays.
	var/status = "На стоянке"
	/// Initial distance to the current destination, in metres.
	var/trip_distance = 0
	/// Distance travelled since selecting the destination, in metres.
	var/travelled = 0
	/// Stable berth ID -> mapped site; unloaded sites have metadata but no physical levels.
	var/list/sites = list()
	/// Small authored contact registry, independent of the contents of any z-level.
	var/list/contacts = list()
	/// Position in metres, with north at positive Y.
	var/pos_x = 0
	var/pos_y = 0
	/// Current and ordered compass course, degrees clockwise from north.
	var/course = 90
	var/ordered_course = 90
	/// Actual speed, including acceleration and braking.
	var/speed = 0
	/// Persistent manual thrust order; zero thrust does not erase velocity.
	var/throttle = 100
	/// Active braking may also be requested by the autopilot before a turn.
	var/braking = FALSE
	/// Velocity components retain inertia when the hull turns or powered thrust changes.
	var/velocity_x = 0
	var/velocity_y = 0
	/// Propulsion order survives a loading hold, but never an explicit stop.
	var/helm_engaged = FALSE
	/// Last integrated server time; UI refreshes never advance simulation time twice.
	var/last_update = 0
	/// Conservative physical footprint used by both collision detection and the display.
	var/radius = 12
	/// Loading and seam construction have a single worker, separate from movement.
	var/preparing = FALSE
	var/datum/stationtrauma_overmap_site/prepared_site
	var/arrival_pending = FALSE
	/// Manual helm, stop and site changes invalidate any yielded pathfinding request.
	var/control_revision = 0
	var/planning = FALSE
	var/autopilot = FALSE
	var/list/autopilot_path
	/// Direction changes alone notify native parallax listeners.
	var/parallax_direction = NONE
	/// Shared sonar settings, observations and cooldown for every linked console.
	var/active_sonar = FALSE
	var/next_ping = 0
	var/last_ping
	var/next_listen = 0
	var/list/echoes = list()
	/// Static terrain discovered by active pulses; moving contacts are never stored here.
	var/list/charted_terrain = list()
	/// Sector IDs remain server-side; each crew numbers its own position snapshots.
	var/list/ship_observations = list()
	var/next_contact_number = 0

/datum/stationtrauma_overmap/New()
	last_update = world.time
	START_PROCESSING(SSfastprocess, src)

/datum/stationtrauma_overmap/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	sector?.unregister(src)
	QDEL_LIST_ASSOC_VAL(sites)
	QDEL_LIST(contacts)
	discovered_sites.Cut()
	visited_sites.Cut()
	charted_terrain.Cut()
	ship_observations.Cut()
	prepared_site = null
	return ..()

/datum/stationtrauma_overmap/proc/knows_site(datum/stationtrauma_overmap_site/site)
	return !QDELETED(site) && sites[site.id] == site && (site.discovered || discovered_sites[site.id])

/datum/stationtrauma_overmap/proc/discover_site(datum/stationtrauma_overmap_site/site)
	discovered_sites[site.id] = TRUE

/datum/stationtrauma_overmap/process(seconds_per_tick)
	if(!is_operational())
		return PROCESS_KILL
	advance()
	if(active_sonar && world.time >= next_ping)
		if(has_sensors())
			ping()
		else
			active_sonar = FALSE
			listen()
	else if(!active_sonar && world.time >= next_listen)
		listen()

/** Integrate only the marker, testing the swept path before committing any position. */
/datum/stationtrauma_overmap/proc/advance()
	var/seconds = max(0, world.time - last_update) / (1 SECONDS)
	last_update = world.time
	if(!seconds || !helm_engaged || arrival_pending)
		return
	var/turn = WRAP(ordered_course - course + 180, 0, 360) - 180
	if(autopilot)
		steer_autopilot()
		if(!helm_engaged)
			return
		turn = WRAP(ordered_course - course + 180, 0, 360) - 180
	course = WRAP(course + clamp(turn, -ST_NAV_TURN_RATE * seconds, ST_NAV_TURN_RATE * seconds), 0, 360)
	var/datum/stationtrauma_overmap_site/site = sites[selected_destination]
	var/available = get_target_speed()
	if(autopilot && length(autopilot_path))
		var/list/node = autopilot_path[1]
		var/distance = sqrt((node[1] - pos_x) ** 2 + (node[2] - pos_y) ** 2)
		var/margin = length(autopilot_path) == 1 ? max(0, radius + site.radius - 2) : 10
		if(length(autopilot_path) == 1 && (prepared_site != sites[selected_destination] || preparing))
			margin += ST_NAV_APPROACH + 4
		var/remaining = max(0, distance - margin)
		available = min(available, 0.7 * sqrt(2 * get_braking_acceleration() * remaining), remaining / max(1, get_response_time()))
		if(abs(turn) > 5 || remaining == 0)
			available = 0
	if(braking)
		available = 0
	var/list/displacement = integrate_velocity(seconds, available)
	var/dx = displacement[1]
	var/dy = displacement[2]
	speed = sqrt(velocity_x ** 2 + velocity_y ** 2)
	var/fraction = 1
	var/datum/stationtrauma_overmap_terrain/obstacle
	for(var/datum/stationtrauma_overmap_terrain/terrain in contacts)
		if(!terrain.blocking)
			continue
		var/hit = stationtrauma_terrain_hit(pos_x, pos_y, dx, dy, terrain.pos_x, terrain.pos_y, terrain.end_x, terrain.end_y, radius)
		if(!isnull(hit) && hit <= fraction)
			fraction = hit
			obstacle = terrain
	// Stop just outside a contact, avoiding repeated impacts from float rounding.
	var/step_length = sqrt(dx * dx + dy * dy)
	var/travel_fraction = fraction < 1 ? max(0, fraction - 1 / max(1, step_length)) : 1
	pos_x += dx * travel_fraction
	pos_y += dy * travel_fraction
	travelled += step_length * travel_fraction
	if(obstacle)
		var/impact_speed = speed
		stop("Столкновение: [obstacle.name]")
		on_collision(obstacle, impact_speed)
	else
		if(site && speed <= 0.05 && (!braking || autopilot) && prepared_site == site && !preparing && distance_to(site) <= radius + site.radius + 2)
			arrival_pending = TRUE
			INVOKE_ASYNC(src, PROC_REF(arrive), site)
		else if(braking && !autopilot && speed <= 0.05)
			stop("Движение остановлено")
		else
			status = braking ? "Торможение" : "В пути"
	update_parallax()

/** Technical stop for collisions, completed manoeuvres and failed preparation; pilot controls request braking. */
/datum/stationtrauma_overmap/proc/stop(reason = "Стоп-машина")
	control_revision++
	autopilot = FALSE
	autopilot_path = null
	braking = FALSE
	helm_engaged = FALSE
	speed = 0
	velocity_x = 0
	velocity_y = 0
	last_update = world.time
	if(!is_operational())
		return
	status = reason
	update_parallax()

/** Engage the helm; environment adapters own departure and physical map preparation. */
/datum/stationtrauma_overmap/proc/sail()
	if(arrival_pending || !is_operational() || !propulsion_available())
		return FALSE
	var/datum/stationtrauma_overmap_site/site = sites[selected_destination]
	if(site && (!knows_site(site) || site.failed))
		return FALSE
	helm_engaged = TRUE
	last_update = world.time
	return TRUE

/** Select registered IDs only; never retarget an in-flight preparation or arrival. */
/datum/stationtrauma_overmap/proc/select_site(id)
	var/datum/stationtrauma_overmap_site/site = sites[id]
	if(!site || !knows_site(site) || preparing || arrival_pending || site.failed)
		return FALSE
	control_revision++
	autopilot = FALSE
	autopilot_path = null
	selected_destination = id
	trip_distance = distance_to(site)
	travelled = 0
	ordered_course = delta_to_angle(site.pos_x - pos_x, site.pos_y - pos_y)
	return TRUE

/** Recheck after any yielded preparation; a stop invalidates pending arrival. */
/datum/stationtrauma_overmap/proc/can_arrive(datum/stationtrauma_overmap_site/site)
	return knows_site(site) && is_operational() && helm_engaged && arrival_pending && (!braking || autopilot) && speed <= 0.05 && !preparing && prepared_site == site && sites[selected_destination] == site && distance_to(site) <= radius + site.radius + 2

/** Environment adapters must validate and activate their physical connection before calling the parent. */
/datum/stationtrauma_overmap/proc/arrive(datum/stationtrauma_overmap_site/site)
	if(can_arrive(site))
		pos_x = site.pos_x
		pos_y = site.pos_y
		visited_sites[site.id] = TRUE
		selected_destination = null
		stop("Стоянка: [site.name]")
	arrival_pending = FALSE

/** Euclidean distance uses world metadata, never physical Z-levels. */
/datum/stationtrauma_overmap/proc/distance_to(datum/stationtrauma_overmap_site/site)
	return sqrt((site.pos_x - pos_x) ** 2 + (site.pos_y - pos_y) ** 2)

/** Physical ownership may stop processing without imposing a concrete vessel type. */
/datum/stationtrauma_overmap/proc/is_operational()
	return TRUE

/** Sensor adapters decide whether a powered detector is available. */
/datum/stationtrauma_overmap/proc/has_sensors()
	return TRUE

/** Propulsion adapters validate engine availability before engaging the helm. */
/datum/stationtrauma_overmap/proc/propulsion_available()
	return TRUE

/** Unpowered by default; a vessel adapter supplies its currently available target speed. */
/datum/stationtrauma_overmap/proc/get_target_speed()
	return 0

/** Positive first-order velocity response time in seconds; independent of physical water simulation. */
/datum/stationtrauma_overmap/proc/get_response_time()
	return 1

/** Default first-order response; vacuum adapters can integrate thrust without environmental drag. */
/datum/stationtrauma_overmap/proc/integrate_velocity(seconds, available)
	if(braking || (autopilot && !available))
		return integrate_braking(seconds)
	var/response_time = get_response_time()
	var/response = 1 - NUM_E ** (-seconds / response_time)
	var/target_x = sin(course) * available
	var/target_y = cos(course) * available
	var/dx = target_x * seconds + (velocity_x - target_x) * response_time * response
	var/dy = target_y * seconds + (velocity_y - target_y) * response_time * response
	velocity_x += (target_x - velocity_x) * response
	velocity_y += (target_y - velocity_y) * response
	return list(dx, dy)

/** Environment-specific visual motion; no world turfs are moved by the shared model. */
/datum/stationtrauma_overmap/proc/update_parallax()
	return

/** Physical damage is applied by the vessel adapter after the virtual collision stops motion. */
/datum/stationtrauma_overmap/proc/on_collision(datum/stationtrauma_overmap_terrain/obstacle, impact_speed)
	return
