/** Sector-side travel for a single kinetic projectile. */
/datum/stationtrauma_kinetic_shot
	/// Round profile retained even if the firing mount is destroyed in flight.
	var/obj/projectile/bullet/stationtrauma_kinetic/projectile_type = /obj/projectile/bullet/stationtrauma_kinetic
	/// Sector at launch, also used to reject an invalidated departure.
	var/datum/weakref/sector_ref
	/// Firing hull, excluded from collisions and always shown its own shot.
	var/datum/weakref/source_ref
	/// Crew attribution retained through the transfer between maps.
	var/datum/weakref/gunner_ref
	/// Weapon for physical hit attribution.
	var/datum/weakref/weapon_ref
	/// Unique marker number within the sector.
	var/number
	/// Virtual easting of the projectile.
	var/pos_x
	/// Virtual northing of the projectile.
	var/pos_y
	/// Normalized eastward direction of travel.
	var/direction_x
	/// Normalized northward direction of travel.
	var/direction_y
	/// Remaining sector distance, set from the mount’s range at launch.
	var/remaining
	/// Last integrated time. The final step may use less than the full tick.
	var/last_update
	/// Terminal plot echo outlives the simulation until the next UI update.
	var/finished_at

/datum/stationtrauma_kinetic_shot/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	var/datum/stationtrauma_overmap_sector/space/sector = sector_ref?.resolve()
	if(sector)
		sector.kinetic_shots -= src
	sector_ref = source_ref = gunner_ref = weapon_ref = null
	return ..()

/datum/stationtrauma_overmap_sector/space
	/// Only rounds currently in the sector participate in tracking and collision.
	var/list/kinetic_shots = list()
	/// Monotonic identifier for projectile chart labels.
	var/next_kinetic_shot = 0
	/// Confirmed shell impacts available to the chart during its next refresh.
	var/list/kinetic_impacts = list()
	/// Gives each pulse its own identity, including rounds hitting in the same tick.
	var/next_kinetic_impact = 0

/datum/stationtrauma_overmap_sector/space/proc/prune_kinetic_impacts()
	var/expired = 0
	for(var/list/impact as anything in kinetic_impacts)
		if(world.time - impact["time"] < ST_KINETIC_IMPACT_MEMORY)
			break
		expired++
	if(expired)
		kinetic_impacts.Cut(1, expired + 1)

/datum/stationtrauma_overmap_sector/space/proc/record_kinetic_impact(datum/stationtrauma_overmap/space/ship, x, y, shielded = FALSE)
	prune_kinetic_impacts()
	next_kinetic_impact++
	kinetic_impacts += list(list(
		"id" = next_kinetic_impact,
		"time" = world.time,
		"ship" = ship ? WEAKREF(ship) : null,
		"shielded" = shielded,
		"x" = x,
		"y" = y,
	))

/** A vessel remains exposed during approach preparation and jump warmup. */
/datum/stationtrauma_overmap/space/proc/kinetic_exposed()
	return !QDELETED(vessel) && !QDELETED(sector) && !QDELETED(flight_berth) && sector.ships[vessel.shuttle_id] == src \
		&& !relocating && !docked && jump_phase < HYPERSPACE_LAUNCH && !connection?.active \
		&& vessel.z == flight_berth.z

/** Launch only while the firing hull is in free flight. */
/datum/stationtrauma_overmap/space/proc/kinetic_flight_ready()
	return kinetic_exposed() && !preparing && !ship_docking && !jump_target

/** Distance from the fired-on chart origin to the start of a shell's sector path. */
/datum/stationtrauma_overmap/space/proc/kinetic_launch_offset()
	return radius + 1

/** Consume the outgoing physical segment and start sector travel on its fixed firing line. */
/datum/stationtrauma_kinetic_shot/proc/enter_sector()
	var/datum/stationtrauma_overmap/space/source = source_ref?.resolve()
	var/datum/stationtrauma_overmap_sector/space/sector = sector_ref?.resolve()
	if(QDELETED(source) || QDELETED(sector) || source.sector != sector || !source.kinetic_flight_ready())
		return FALSE
	source.advance()
	if(source.sector != sector || !source.kinetic_flight_ready())
		return FALSE
	sector.next_kinetic_shot++
	number = sector.next_kinetic_shot
	sector.kinetic_shots += src
	last_update = world.time
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/** Swept point-circle collision in the hull's moving frame. */
/datum/stationtrauma_kinetic_shot/proc/contact_fraction(dx, dy, hull_x, hull_y, hull_dx, hull_dy, radius)
	return stationtrauma_circle_hit(pos_x, pos_y, dx - hull_dx, dy - hull_dy, hull_x, hull_y, radius)

/datum/stationtrauma_kinetic_shot/process(seconds_per_tick)
	var/datum/stationtrauma_overmap_sector/space/sector = sector_ref?.resolve()
	if(QDELETED(sector))
		qdel(src)
		return PROCESS_KILL
	if(!isnull(finished_at))
		if(world.time >= finished_at + 1.2 SECONDS)
			qdel(src)
			return PROCESS_KILL
		return
	var/seconds = min((world.time - last_update) / (1 SECONDS), remaining / ST_AUTOCANNON_SPEED)
	if(seconds <= 0)
		return
	var/distance = ST_AUTOCANNON_SPEED * seconds
	var/dx = direction_x * distance
	var/dy = direction_y * distance
	var/fraction
	for(var/datum/stationtrauma_overmap_terrain/terrain as anything in sector.contacts)
		if(!terrain.blocking)
			continue
		var/contact = stationtrauma_terrain_hit(pos_x, pos_y, dx, dy, terrain.pos_x, terrain.pos_y, terrain.end_x, terrain.end_y, 0)
		if(!isnull(contact) && (isnull(fraction) || contact < fraction))
			fraction = contact

	var/datum/stationtrauma_overmap/space/firing_ship = source_ref?.resolve()
	var/datum/stationtrauma_overmap_site/space/docking_target/fixed_target
	var/datum/stationtrauma_overmap_site/space/fixed_berth
	var/datum/stationtrauma_overmap/space/target
	var/offset_x
	var/offset_y
	for(var/datum/stationtrauma_overmap_site/space/docking_target/site as anything in sector.fixed_combat_sites)
		var/contact = stationtrauma_circle_hit(pos_x, pos_y, dx, dy, site.pos_x, site.pos_y, site.radius)
		if(isnull(contact) || (!isnull(fraction) && contact >= fraction))
			continue
		var/datum/stationtrauma_overmap_site/space/berth = site.combat_berth(sector)
		if(!berth)
			continue
		fixed_target = site
		fixed_berth = berth
		fraction = contact
		offset_x = pos_x + dx * fraction - site.pos_x
		offset_y = pos_y + dy * fraction - site.pos_y
	for(var/id in sector.ships)
		var/datum/stationtrauma_overmap/space/candidate = sector.ships[id]
		if(QDELETED(candidate) || candidate == firing_ship || !candidate.kinetic_exposed())
			continue
		var/elapsed = (last_update - candidate.last_update) / (1 SECONDS)
		var/hull_x = candidate.pos_x + candidate.velocity_x * elapsed
		var/hull_y = candidate.pos_y + candidate.velocity_y * elapsed
		var/hull_dx = candidate.velocity_x * seconds
		var/hull_dy = candidate.velocity_y * seconds
		var/contact = contact_fraction(dx, dy, hull_x, hull_y, hull_dx, hull_dy, candidate.radius)
		if(isnull(contact) || (!isnull(fraction) && contact >= fraction))
			continue
		target = candidate
		fraction = contact
		offset_x = pos_x - hull_x + (dx - hull_dx) * contact
		offset_y = pos_y - hull_y + (dy - hull_dy) * contact

	if(target)
		var/obj/machinery/stationtrauma_ship_shield/shield = target.vessel.combat_shield_ref?.resolve()
		var/impact = initial(projectile_type.shield_impact)
		var/absorbed = shield?.absorb(impact) || 0
		if(absorbed)
			sector.record_kinetic_impact(target, target.pos_x, target.pos_y, shielded = TRUE)
		var/strength = 1 - absorbed / impact
		if(strength > 0)
			project_into_hull(target, offset_x, offset_y, strength)
	else if(fixed_target)
		project_into_site(fixed_target, fixed_berth, offset_x, offset_y)
	if(!isnull(fraction) || distance >= remaining)
		pos_x += dx * (isnull(fraction) ? 1 : fraction)
		pos_y += dy * (isnull(fraction) ? 1 : fraction)
		if(!target && !fixed_target && !isnull(fraction))
			sector.record_kinetic_impact(null, pos_x, pos_y)
		finished_at = world.time
		return
	pos_x += dx
	pos_y += dy
	remaining -= distance
	last_update = world.time

/** Map the point and angle of approach into the target map, keeping the lateral offset. */
/datum/stationtrauma_kinetic_shot/proc/project_into_hull(datum/stationtrauma_overmap/space/target, offset_x, offset_y, strength)
	var/obj/docking_port/mobile/stationtrauma_space/hull = target.vessel
	var/rotation = target.course - dir2angle(hull.preferred_direction)
	var/flight_angle = delta_to_angle(direction_x, direction_y) - rotation
	var/list/bounds = hull.return_coords()
	var/center_x = (bounds[1] + bounds[3]) / 2
	var/center_y = (bounds[2] + bounds[4]) / 2
	var/local_x = offset_x * cos(rotation) - offset_y * sin(rotation)
	var/local_y = offset_x * sin(rotation) + offset_y * cos(rotation)
	var/turf/entry = locate(
		round(center_x + local_x - sin(flight_angle) * 4),
		round(center_y + local_y - cos(flight_angle) * 4),
		hull.z,
	)
	if(!isspaceturf(entry) || entry.is_transition_turf() || hull.shuttle_areas[get_area(entry)])
		return
	var/obj/projectile/bullet/stationtrauma_kinetic/round = new projectile_type(entry)
	round.target_hull_ref = WEAKREF(hull)
	fire_incoming(round, flight_angle, strength, ceil(target.radius * 2 + 8))

/// Both native maps receive the same projectile, damage profile and firing attribution.
/datum/stationtrauma_kinetic_shot/proc/fire_incoming(obj/projectile/bullet/stationtrauma_kinetic/round, flight_angle, strength, distance)
	round.impact_strength *= strength
	round.damage *= strength
	round.range = round.maximum_range = distance
	round.firer = gunner_ref?.resolve()
	round.fired_from = weapon_ref?.resolve()
	round.fire(WRAP(flight_angle, 0, 360))

/** Only the firing hull and nearby observers receive a mark on their plot. */
/datum/stationtrauma_overmap/space/proc/kinetic_echo_data()
	. = list()
	var/datum/stationtrauma_overmap_sector/space/here = sector
	for(var/datum/stationtrauma_kinetic_shot/shot as anything in here?.kinetic_shots)
		if(shot.source_ref?.resolve() != src && (shot.pos_x - pos_x) ** 2 + (shot.pos_y - pos_y) ** 2 > (sensor_range / 2) ** 2)
			continue
		. += list(list(
			"id" = shot.number,
			"x" = shot.pos_x, "y" = shot.pos_y,
			"heading" = delta_to_angle(shot.direction_x, shot.direction_y),
			"finished" = !isnull(shot.finished_at),
		))

/** Report ship impacts on existing chart marks, without revealing live target coordinates. */
/datum/stationtrauma_overmap/space/proc/kinetic_impact_data()
	. = list()
	var/datum/stationtrauma_overmap_sector/space/here = sector
	if(QDELETED(here))
		return
	here.prune_kinetic_impacts()
	for(var/list/impact as anything in here.kinetic_impacts)
		var/kind = impact["shielded"] ? "shield" : "ship"
		var/datum/weakref/ship_ref = impact["ship"]
		var/datum/stationtrauma_overmap/space/target = ship_ref?.resolve()
		if(target == src)
			. += list(list("id" = impact["id"], "kind" = kind, "contact" = null))
			continue
		if((impact["x"] - pos_x) ** 2 + (impact["y"] - pos_y) ** 2 > (sensor_range / 2) ** 2)
			continue
		if(!ship_ref)
			. += list(list("id" = impact["id"], "kind" = "terrain", "x" = impact["x"], "y" = impact["y"]))
			continue
		if(QDELETED(target) || target.sector != here || QDELETED(target.vessel))
			continue
		var/list/observation = ship_observations[target.vessel.shuttle_id]
		if(observation && world.time - observation["seen"] < ST_NAV_SHIP_MEMORY)
			. += list(list("id" = impact["id"], "kind" = kind, "contact" = observation["id"]))

/** A physical segment of a naval round. */
/obj/projectile/bullet/stationtrauma_kinetic
	name = "кинетический снаряд"
	icon = 'modular_bandastation/space_combat/icons/patrol_tracers.dmi'
	icon_state = "light"
	damage = 55
	speed = ST_AUTOCANNON_LOCAL_SPEED
	sharpness = NONE
	/// Owned by the outgoing projectile until a successful departure.
	var/datum/stationtrauma_kinetic_shot/outgoing_shot
	/// Limits incoming damage to the hull selected by the sector collision.
	var/datum/weakref/target_hull_ref
	/// Fixed installation and sector notified on the first physical hit.
	var/datum/weakref/target_site_ref
	var/datum/weakref/target_sector_ref
	/// One pulse for the first physical contact of this incoming round.
	var/recorded_impact = FALSE
	/// Amount of field charge needed to intercept a complete shell.
	var/shield_impact = ST_SHIP_SHIELD_KINETIC_IMPACT
	/// Wall damage after passing through a depleted shield.
	var/impact_strength = 1

/obj/projectile/bullet/stationtrauma_kinetic/heavy
	name = "тяжёлый кинетический снаряд"
	icon_state = "heavy"
	damage = 165
	shield_impact = 3 * ST_SHIP_SHIELD_KINETIC_IMPACT
	impact_strength = 3

/obj/projectile/bullet/stationtrauma_kinetic/Initialize(mapload)
	. = ..()
	add_overlay(emissive_appearance(icon, icon_state, src))

/obj/projectile/bullet/stationtrauma_kinetic/Destroy()
	QDEL_NULL(outgoing_shot)
	target_hull_ref = target_site_ref = target_sector_ref = null
	return ..()

/obj/projectile/bullet/stationtrauma_kinetic/Move(atom/newloc, direction, glide_size_override = 0, update_dir = TRUE)
	var/turf/next = newloc
	if(istype(next) && (next.is_transition_turf() || next.x == 1 || next.x == world.maxx || next.y == 1 || next.y == world.maxy))
		if(outgoing_shot && isspaceturf(next) && next.z == z && outgoing_shot.enter_sector())
			outgoing_shot = null
		qdel(src)
		return FALSE
	return ..()

/obj/projectile/bullet/stationtrauma_kinetic/can_hit_target(atom/target, direct_target, ignore_loc, cross_failed)
	if(target_hull_ref)
		var/obj/docking_port/mobile/stationtrauma_space/hull = target_hull_ref.resolve()
		var/turf/point = get_turf(target)
		if(QDELETED(hull) || !hull.overmap?.kinetic_exposed() || !point || !hull.is_in_shuttle_bounds(point) || !hull.shuttle_areas[get_area(point)])
			return FALSE
	return ..()

/obj/projectile/bullet/stationtrauma_kinetic/on_hit(atom/target, blocked = 0, pierce_hit)
	if(target_site_ref && !recorded_impact)
		var/datum/stationtrauma_overmap_site/space/docking_target/site = target_site_ref.resolve()
		var/datum/stationtrauma_overmap_sector/space/here = target_sector_ref?.resolve()
		if(site && here?.sites[site.id] == site)
			recorded_impact = TRUE
			here.record_kinetic_impact(null, site.pos_x, site.pos_y)
	if(target_hull_ref && !recorded_impact)
		var/obj/docking_port/mobile/stationtrauma_space/hull = target_hull_ref.resolve()
		var/datum/stationtrauma_overmap/space/ship = hull?.overmap
		if(!QDELETED(ship?.sector))
			recorded_impact = TRUE
			var/datum/stationtrauma_overmap_sector/space/here = ship.sector
			here.record_kinetic_impact(ship, ship.pos_x, ship.pos_y)
	if(blocked < 100 && iswallturf(target) && !isindestructiblewall(target))
		target.AddComponent(/datum/component/torn_wall, null, impact_strength)
	return ..()
