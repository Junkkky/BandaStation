/** Own passages across a full-width, multi-deck seam; each gate shows the far side with the native border mirage. */
/datum/stationtrauma_map_connection
	/// Vessel supplying the physical footprint.
	var/obj/docking_port/mobile/vessel
	/// Number of contiguous physical decks connected together.
	var/decks
	/// Vessel-facing side of the seam.
	var/direction = NORTH
	/// One publication flag controls every prepared passage.
	var/active = FALSE
	/// Geometry invalidation interrupts paused preparation.
	var/revision = 0
	/// Geometry revision captured before building the inactive connection.
	var/prepared_revision = 0
	/// Owned gates; real actors never belong to this list.
	var/list/passages = list()
	/// Environment adapters specialize eligibility.
	var/passage_type = /datum/component/stationtrauma_map_passage

/// Every live connection, for resolving what a viewer sees through an open seam.
GLOBAL_LIST_EMPTY(stationtrauma_map_connections)

/datum/stationtrauma_map_connection/New(obj/docking_port/mobile/owner, deck_count = 1, facing = NORTH)
	if(!istype(owner) || !ISINTEGER(deck_count) || deck_count < 1 || !(facing in GLOB.cardinals))
		CRASH("A map connection requires a native vessel and a positive integer deck count")
	vessel = owner
	decks = deck_count
	direction = facing
	RegisterSignal(vessel, COMSIG_QDELETING, PROC_REF(owner_deleted))
	GLOB.stationtrauma_map_connections += src

/datum/stationtrauma_map_connection/Destroy()
	GLOB.stationtrauma_map_connections -= src
	disconnect()
	UnregisterSignal(vessel, COMSIG_QDELETING)
	vessel = null
	return ..()

/** Release the connection when its physical hull is deleted. */
/datum/stationtrauma_map_connection/proc/owner_deleted()
	SIGNAL_HANDLER
	qdel(src)

/** Remove a deleted gate and invalidate pending preparation. */
/datum/stationtrauma_map_connection/proc/member_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	if(source in passages)
		revision++
	passages -= source

/** A physical map cannot be connected until its atom initialization has finished. */
/datum/stationtrauma_map_connection/proc/is_loading()
	return SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD

/** Delete owned passages. */
/datum/stationtrauma_map_connection/proc/disconnect()
	active = FALSE
	revision++
	var/list/old_passages = passages
	passages = list()
	QDEL_LIST(old_passages)

/** Close every gate immediately, then spread subscription destruction over server ticks. */
/datum/stationtrauma_map_connection/proc/disconnect_cooperatively(datum/stationtrauma_work_budget/budget)
	active = FALSE
	revision++
	var/list/old_passages = passages
	passages = list()
	for(var/datum/component/stationtrauma_map_passage/passage as anything in old_passages)
		budget.yield()
		if(!QDELETED(passage))
			qdel(passage)

/** Validate topology only; each transfer rechecks occupied landings and native projectile cover. */
/datum/stationtrauma_map_connection/proc/gate_available(turf/open/tile, allow_owned = FALSE)
	if(!isspaceturf(tile) || tile.destination_z)
		return FALSE
	var/datum/component/stationtrauma_map_passage/passage = tile.GetComponent(/datum/component/stationtrauma_map_passage)
	if(passage && (!allow_owned || passage.connection != src))
		return FALSE
	return TRUE

/** Prepare inactive gates cooperatively; publish only a complete corridor. */
/datum/stationtrauma_map_connection/proc/connect(obj/docking_port/stationary/berth, datum/stationtrauma_work_budget/budget, activate = TRUE, ship_clearance = 0, site_clearance = 0)
	if(QDELETED(vessel) || !berth || berth.z == vessel.z || is_loading() || passages.len)
		return FALSE
	budget ||= new
	prepared_revision = revision
	var/ready = FALSE
	try
		ready = prepare(berth, budget, ship_clearance, site_clearance)
		if(ready && activate)
			ready = activate(budget)
	catch(var/exception/failure)
		disconnect_cooperatively(budget)
		throw failure
	if(!ready)
		disconnect_cooperatively(budget)
	return ready

/** Return the hull's seam coordinate, or null when its gate and landing cannot fit inside the transition border. */
/datum/stationtrauma_map_connection/proc/get_ship_edge(list/bounds, clearance, facing)
	var/horizontal = !!(facing & (EAST|WEST))
	var/positive = facing == NORTH || facing == EAST
	var/low = horizontal ? min(bounds[1], bounds[3]) : min(bounds[2], bounds[4])
	var/high = horizontal ? max(bounds[1], bounds[3]) : max(bounds[2], bounds[4])
	var/edge = positive ? high + 1 + clearance : low - 1 - clearance
	var/axis_limit = horizontal ? world.maxx : world.maxy
	if(edge <= TRANSITIONEDGE + 1 || edge >= axis_limit - TRANSITIONEDGE)
		return null
	return edge

/** Build inactive passages cooperatively. */
/datum/stationtrauma_map_connection/proc/prepare(obj/docking_port/stationary/berth, datum/stationtrauma_work_budget/budget, ship_clearance, site_clearance)
	var/clearance = max(30, maxviewdist())
	ship_clearance ||= clearance
	site_clearance ||= clearance
	if(!ISINTEGER(ship_clearance) || ship_clearance < 1 || !ISINTEGER(site_clearance) || site_clearance < 1)
		return FALSE
	var/list/bounds = vessel.return_coords()
	var/ship_edge = get_ship_edge(bounds, ship_clearance, direction)
	if(isnull(ship_edge))
		return FALSE
	var/horizontal = !!(direction & (EAST|WEST))
	var/positive = direction == NORTH || direction == EAST
	var/site_edge = (horizontal ? berth.x : berth.y) + (positive ? -site_clearance : site_clearance)
	var/axis_limit = horizontal ? world.maxx : world.maxy
	var/extent = horizontal ? world.maxy : world.maxx
	if(site_edge <= TRANSITIONEDGE + 1 || site_edge >= axis_limit - TRANSITIONEDGE)
		return FALSE
	for(var/deck in 0 to decks - 1)
		for(var/column in 1 to extent)
			budget.yield()
			if(QDELETED(src) || QDELETED(vessel) || QDELETED(berth) || prepared_revision != revision)
				return FALSE
			var/turf/open/ship_gate = locate(horizontal ? ship_edge : column, horizontal ? column : ship_edge, vessel.z + deck)
			var/turf/open/site_gate = locate(horizontal ? site_edge : column, horizontal ? column : site_edge, berth.z + deck)
			var/turf/open/ship_landing = get_step(ship_gate, REVERSE_DIR(direction))
			var/turf/open/site_landing = get_step(site_gate, direction)
			for(var/turf/open/tile as anything in list(ship_gate, site_gate, ship_landing, site_landing))
				if(!gate_available(tile))
					return FALSE
			for(var/datum/component/stationtrauma_map_passage/passage as anything in list(ship_gate.AddComponent(passage_type, site_landing, direction, src), site_gate.AddComponent(passage_type, ship_landing, REVERSE_DIR(direction), src)))
				passages += passage
				RegisterSignal(passage, COMSIG_QDELETING, PROC_REF(member_deleted))
	return TRUE

/** Recheck live gates, then open both directions in one non-yielding publication. */
/datum/stationtrauma_map_connection/proc/activate(datum/stationtrauma_work_budget/budget, datum/callback/arrival_check)
	if(QDELETED(src) || QDELETED(vessel) || !passages.len || prepared_revision != revision)
		return FALSE
	for(var/datum/component/stationtrauma_map_passage/passage as anything in passages)
		budget?.yield()
		if(QDELETED(src) || QDELETED(vessel) || QDELETED(passage) || !gate_available(passage.parent, TRUE) || !gate_available(passage.landing, TRUE))
			return FALSE
	if(prepared_revision != revision)
		return FALSE
	if(arrival_check && !arrival_check.Invoke())
		return FALSE
	active = TRUE
	for(var/datum/component/stationtrauma_map_passage/passage as anything in passages)
		passage.show_mirage()
	return TRUE

/**
 * The turf on the viewer's level where `target`, seen through an open seam, appears; null when it is not seen through one.
 *
 * The mirage shows real far-side atoms, so a click hands over their own coordinates; whatever aims at coordinates needs this image instead.
 */
/proc/stationtrauma_seam_image_turf(atom/viewer, atom/target)
	var/turf/here = get_turf(viewer)
	var/turf/there = get_turf(target)
	if(!here || !there || here.z == there.z)
		return null
	for(var/datum/stationtrauma_map_connection/connection as anything in GLOB.stationtrauma_map_connections)
		if(!connection.active)
			continue
		for(var/datum/component/stationtrauma_map_passage/passage as anything in connection.passages)
			var/turf/gate = passage.parent
			// Every gate of one seam side shares the same offset, so the first gate from this level to that one decides.
			if(gate.z == here.z && passage.landing.z == there.z)
				return locate(there.x + gate.x - passage.landing.x, there.y + gate.y - passage.landing.y, here.z)
	return null

/obj/projectile/aim_projectile(atom/target, atom/source, list/modifiers = null, deviation = 0)
	var/turf/image = stationtrauma_seam_image_turf(source, target)
	if(!image)
		return ..()
	// Aim along the image the shooter sees, then keep the real far-side target for the direct hit.
	. = ..(image, source, modifiers, deviation)
	if(.)
		original = target

/atom/base_ranged_item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Guns keep the real target; their shot aims at the image itself. Other tools aim at coordinates, which only the image turf gives.
	if(!isgun(tool))
		var/turf/image = stationtrauma_seam_image_turf(user, src)
		if(image)
			return image.base_ranged_item_interaction(user, tool, modifiers)
	return ..()

/mob/living/throw_item(atom/target)
	return ..(stationtrauma_seam_image_turf(src, target) || target)
