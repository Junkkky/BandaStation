/** A real opening in the upper deck joins finite water only; ordinary space is never a drain. */
/turf/open/proc/can_pass_stationtrauma_water_down(turf/open/lower)
	if(!isopenspaceturf(src) || isspaceturf(src) || !isopenturf(lower) || isspaceturf(lower) || istype(lower, /turf/open/water) || blocks_air || lower.blocks_air)
		return FALSE
	if(GET_TURF_BELOW(src) != lower || GET_TURF_ABOVE(lower) != src || !zAirOut(DOWN, lower) || !lower.zAirIn(DOWN, src))
		return FALSE
	for(var/obj/barrier in contents)
		if(!CANATMOSPASS(barrier, lower, FALSE))
			return FALSE
	for(var/obj/barrier in lower.contents)
		if(!CANATMOSPASS(barrier, src, FALSE))
			return FALSE
	return TRUE

/** Inspect the two local vertical edges only when their geometry changes. */
/datum/floodwater_hybrid/proc/refresh_vertical_links(datum/floodwater_front_cell/cell)
	refresh_vertical_portal(cell)
	var/turf/above = GET_TURF_ABOVE(cell.tile)
	var/datum/floodwater_front_cell/upper = by_turf[above]
	if(!upper && isopenspaceturf(above) && !isspaceturf(above))
		upper = SSfloodwater.ensure_water_domain(above)
	if(upper)
		refresh_vertical_portal(upper)

/** Reuse a portal across repairs; neither discovery nor flow merges the decks into one group. */
/datum/floodwater_hybrid/proc/refresh_vertical_portal(datum/floodwater_front_cell/upper)
	var/datum/floodwater_front_portal/portal = vertical_portals[upper]
	var/turf/open/upper_tile = upper.tile
	var/turf/open/lower_tile = GET_TURF_BELOW(upper_tile)
	if(!isopenspaceturf(upper_tile) || isspaceturf(upper_tile) || !isopenturf(lower_tile) || isspaceturf(lower_tile) || istype(lower_tile, /turf/open/water))
		portal?.set_open(FALSE)
		return
	var/datum/floodwater_front_cell/lower = by_turf[lower_tile] || SSfloodwater.ensure_water_domain(lower_tile)
	if(!lower)
		return
	// Domain registration can discover this same edge recursively.
	portal = vertical_portals[upper]
	if(!portal)
		portal = new
		portal.solver = src
		portal.left = upper
		portal.elevation = FLOOD_WATER_MAX_DEPTH
		portal.open_index = open_vertical_portals
		portal.open_order = vertical_portals.len
		vertical_portals[upper] = portal
	if(portal.right != lower)
		portal.set_open(FALSE)
		portal.right = lower
	portal.set_open(!upper.blocked && !lower.blocked && upper_tile.can_pass_stationtrauma_water_down(lower_tile))

/** A saturated lower stock can lift finite water into the existing upper front. */
/datum/floodwater_front_portal/proc/prepare_lift(dt)
	if(left.root() == right.root() || opening <= 0 || dt <= 0)
		return null
	var/difference = right.head_pressure() - left.head_pressure() - elevation * FLOOD_WATER_KPA_PER_CM
	if(difference <= FLOOD_WATER_HEAD_EPSILON)
		return null
	return list(right, left, min(rate, 600 * opening * sqrt(2 * difference)) * dt, revision, solver.geometry_version, ++serial, dt, TRUE)

/** A lift spends lower head and real litres; ordinary withdrawal wakes the replenishing ocean. */
/datum/floodwater_front_portal/proc/commit_lift(list/plan)
	var/datum/floodwater_front_cell/source = plan[1]
	var/datum/floodwater_front_cell/destination = plan[2]
	var/datum/floodwater_front_group/from_group = source.root()
	var/datum/floodwater_front_group/to_group = destination.root()
	if(source != right || destination != left || elevation <= 0 || from_group == to_group || !from_group?.is_full() || to_group?.is_full() || opening <= 0)
		return 0
	var/difference = source.head_pressure() - destination.head_pressure() - elevation * FLOOD_WATER_KPA_PER_CM
	if(difference <= FLOOD_WATER_HEAD_EPSILON)
		return 0
	var/destination_count = destination.local ? 1 : to_group?.members.len || 1
	var/live_flow = min(rate, 600 * opening * sqrt(2 * difference)) * plan[7]
	var/head_limit = difference / (FLOOD_WATER_HEAD_STIFFNESS / from_group.volume + FLOOD_WATER_KPA_PER_CM / FLOOD_WATER_LITRES_PER_CM / destination_count)
	var/amount = min(plan[3], live_flow, head_limit, source.available(), destination.capacity())
	if(amount <= 0)
		return 0
	// Withdrawal vents a partial stock; another lift needs replenishment and renewed head.
	solver.withdraw(source, amount)
	solver.receive(destination, amount)
	committed_serial = plan[6]
	solver.confirm_flow(source, destination, amount, difference, opening)
	return amount
