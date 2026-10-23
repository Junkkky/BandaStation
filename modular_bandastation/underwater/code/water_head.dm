/** Aggregate head is independent of rendered depth; geometry temporarily carries it in local packets. */
/datum/floodwater_front_group
	/// Absolute kPa retained by a full, isolated aggregate; zero means an unpressurized free column.
	var/pressure_head = 0
	/// Sub-ULP head changes retained instead of lost to float32 rounding.
	var/pressure_remainder = 0

/datum/floodwater_front_cell
	/// Head carried alongside a materialized packet during a resumable split.
	var/pressure_head = 0

/** Physical saturation, including front packets; rendering stage 4 alone is insufficient. */
/datum/floodwater_front_group/proc/is_full()
	return !dirty && !retired && bulk_count && bulk_count == owned_count && volume >= bulk_count * (FLOOD_FRONT_CAPACITY - FLOOD_WATER_FULL_TOLERANCE)

/** Preserve small accepted pressure changes on large rooms. */
/datum/floodwater_front_group/proc/shift_head(change)
	change += pressure_remainder
	var/previous = pressure_head
	pressure_head += change
	pressure_remainder = change - (pressure_head - previous)
	wake_portals()

/** Vented native air plus the current free water column, in kPa. */
/datum/floodwater_front_cell/proc/free_pressure()
	var/turf/open/floor = tile
	return (isopenturf(floor) ? floor.stationtrauma_air_pressure() : 0) + amount() / FLOOD_WATER_LITRES_PER_CM * FLOOD_WATER_KPA_PER_CM

/** Partial water remains a free column; a full packet can retain independent hydraulic head. */
/datum/floodwater_front_cell/proc/head_pressure()
	var/free_head = free_pressure()
	if(amount() < FLOOD_FRONT_CAPACITY - FLOOD_WATER_FULL_TOLERANCE)
		return free_head
	return max(free_head, local ? pressure_head : root()?.pressure_head || 0)

/** Full sides exchange equal real portions: finite stocks stay bounded while head changes. */
/datum/floodwater_front_portal/proc/prepare_head(dt)
	if(left.root() == right.root() || opening <= 0 || dt <= 0)
		return null
	var/difference = left.head_pressure() - right.head_pressure() + elevation * FLOOD_WATER_KPA_PER_CM
	if(abs(difference) <= FLOOD_WATER_HEAD_EPSILON)
		return null
	var/datum/floodwater_front_cell/source = difference > 0 ? left : right
	var/datum/floodwater_front_cell/destination = source == left ? right : left
	return list(source, destination, 600 * opening * sqrt(2 * abs(difference)) * dt, revision, solver.geometry_version, ++serial, dt)

/** A stale plan cannot change head or create a confirmed event after closure or withdrawal. */
/datum/floodwater_front_portal/proc/commit_head(list/plan)
	var/datum/floodwater_front_cell/source = plan[1]
	var/datum/floodwater_front_cell/destination = plan[2]
	var/datum/floodwater_front_group/from_group = source.root()
	var/datum/floodwater_front_group/to_group = destination.root()
	if(from_group == to_group || !from_group?.is_full() || !to_group?.is_full() || opening <= 0)
		return 0
	var/from_head = source.head_pressure()
	var/to_head = destination.head_pressure()
	var/difference = from_head - to_head + (source == left ? elevation : -elevation) * FLOOD_WATER_KPA_PER_CM
	if(difference <= FLOOD_WATER_HEAD_EPSILON)
		return 0
	var/from_weight = 1 / from_group.volume
	var/to_weight = 1 / to_group.volume
	var/live_flow = 600 * opening * sqrt(2 * difference) * plan[7]
	var/amount = min(plan[3], live_flow, difference / (FLOOD_WATER_HEAD_STIFFNESS * (from_weight + to_weight)), from_group.volume, to_group.volume)
	if(amount <= 0)
		return 0
	from_group.pressure_head = from_head
	to_group.pressure_head = to_head
	from_group.shift_head(-FLOOD_WATER_HEAD_STIFFNESS * amount * from_weight)
	to_group.shift_head(FLOOD_WATER_HEAD_STIFFNESS * amount * to_weight)
	committed_serial = plan[6]
	solver.confirm_flow(source, destination, amount, difference, opening)
	return amount

/** Core fixtures have no native actors; only the native binding publishes confirmed transfers. */
/datum/floodwater_front_solver/proc/confirm_flow(datum/floodwater_front_cell/source, datum/floodwater_front_cell/destination, amount, difference, opening)
	return

/** No queue or speculative impulse: observers receive only a completed, live paired transfer. */
/datum/floodwater_hybrid/confirm_flow(datum/floodwater_front_cell/source, datum/floodwater_front_cell/destination, amount, difference, opening)
	ocean_wakeup = TRUE
	SEND_SIGNAL(SSfloodwater, COMSIG_STATIONTRAUMA_WATER_TRANSFER, source.tile, destination.tile, amount, difference, opening, FALSE)

/** Hold a new full/full edge apart even if a geometry callback has already frozen its owners. */
/datum/floodwater_hybrid/set_link(datum/floodwater_front_cell/left, datum/floodwater_front_cell/right, opened)
	var/datum/floodwater_front_cell/first = left.id < right.id ? left : right
	var/datum/floodwater_front_cell/second = first == left ? right : left
	var/list/edges = portals[first]
	var/datum/floodwater_front_portal/portal = edges?[second]
	if(portal?.pressure_link)
		if(opened)
			return TRUE
		portal.pressure_link = FALSE
		portal.set_open(FALSE)
	if(opened && !(right in left.neighbors) && left.root() && right.root() && left.root() != right.root() && left.amount() >= FLOOD_FRONT_CAPACITY - FLOOD_WATER_FULL_TOLERANCE && right.amount() >= FLOOD_FRONT_CAPACITY - FLOOD_WATER_FULL_TOLERANCE && abs(left.head_pressure() - right.head_pressure()) > FLOOD_WATER_HEAD_EPSILON)
		return TRUE
	return ..()

/** Exchange at an actual ocean contact without adding compressed litres above finite capacity. */
/datum/floodwater_hybrid/proc/exchange_ocean_head(datum/component/floodwater/source, datum/floodwater_front_cell/contact, opening, dt, weak_leak = FALSE)
	var/datum/floodwater_front_group/owner = contact?.root()
	if(!source?.infinite_source || !owner?.is_full() || contact.blocked || opening <= 0 || dt <= 0)
		return 0
	// Below the free column, ordinary outflow drains finite litres instead of lowering stored head forever.
	var/difference = source.reservoir_pressure - contact.head_pressure()
	var/balance = max(source.reservoir_pressure, contact.free_pressure()) - contact.head_pressure()
	if(abs(balance) <= FLOOD_WATER_HEAD_EPSILON)
		return 0
	var/amount = min(600 * opening * sqrt(2 * abs(difference)) * dt, abs(balance) * owner.volume / FLOOD_WATER_HEAD_STIFFNESS, owner.volume)
	if(amount <= 0)
		return 0
	owner.pressure_head = contact.head_pressure()
	owner.shift_head(FLOOD_WATER_HEAD_STIFFNESS * amount / owner.volume * (difference > 0 ? 1 : -1))
	var/turf/outside = source.parent
	SEND_SIGNAL(SSfloodwater, COMSIG_STATIONTRAUMA_WATER_TRANSFER, difference > 0 ? outside : contact.tile, difference > 0 ? contact.tile : outside, amount, abs(difference), opening, weak_leak)
	return amount
