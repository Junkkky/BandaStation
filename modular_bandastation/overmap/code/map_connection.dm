/** Own passages and previews across a full-width, multi-deck seam. */
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
	/// Owned gates and event-driven previews; real actors never belong to these lists.
	var/list/passages = list()
	var/list/previews = list()
	/// Environment adapters specialize eligibility and visual continuity.
	var/passage_type = /datum/component/stationtrauma_map_passage
	var/preview_type = /datum/stationtrauma_map_preview

/datum/stationtrauma_map_connection/New(obj/docking_port/mobile/owner, deck_count = 1, facing = NORTH)
	if(!istype(owner) || !ISINTEGER(deck_count) || deck_count < 1 || !(facing in GLOB.cardinals))
		CRASH("A map connection requires a native vessel and a positive integer deck count")
	vessel = owner
	decks = deck_count
	direction = facing
	RegisterSignal(vessel, COMSIG_QDELETING, PROC_REF(owner_deleted))

/datum/stationtrauma_map_connection/Destroy()
	disconnect()
	UnregisterSignal(vessel, COMSIG_QDELETING)
	vessel = null
	return ..()

/datum/stationtrauma_map_connection/proc/owner_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/stationtrauma_map_connection/proc/member_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	if((source in passages) || (source in previews))
		revision++
	passages -= source
	previews -= source

/** A physical map cannot be connected until its atom initialization has finished. */
/datum/stationtrauma_map_connection/proc/is_loading()
	return SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD

/** Delete owned passages and previews. */
/datum/stationtrauma_map_connection/proc/disconnect()
	active = FALSE
	revision++
	var/list/old_previews = previews
	var/list/old_passages = passages
	previews = list()
	passages = list()
	QDEL_LIST(old_previews)
	QDEL_LIST(old_passages)

/** Close every gate immediately, then spread subscription destruction over server ticks. */
/datum/stationtrauma_map_connection/proc/disconnect_cooperatively(datum/stationtrauma_work_budget/budget)
	active = FALSE
	revision++
	var/list/old_previews = previews
	var/list/old_passages = passages
	previews = list()
	passages = list()
	for(var/datum/stationtrauma_map_preview/preview as anything in old_previews)
		if(!QDELETED(preview))
			preview.suspend()
	for(var/datum/stationtrauma_map_preview/preview as anything in old_previews)
		if(!QDELETED(preview))
			preview.clear_cooperatively(budget)
			qdel(preview)
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

/** Prepare inactive gates and previews cooperatively; publish only a complete corridor. */
/datum/stationtrauma_map_connection/proc/connect(obj/docking_port/stationary/berth, datum/stationtrauma_work_budget/budget, activate = TRUE, ship_clearance = 0, site_clearance = 0)
	if(QDELETED(vessel) || !berth || berth.z == vessel.z || is_loading() || passages.len || previews.len)
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

/** Build inactive passages and previews cooperatively. */
/datum/stationtrauma_map_connection/proc/prepare(obj/docking_port/stationary/berth, datum/stationtrauma_work_budget/budget, ship_clearance, site_clearance)
	var/clearance = max(30, maxviewdist())
	ship_clearance ||= clearance
	site_clearance ||= clearance
	if(!ISINTEGER(ship_clearance) || ship_clearance < 1 || !ISINTEGER(site_clearance) || site_clearance < 1)
		return FALSE
	var/list/bounds = vessel.return_coords()
	var/horizontal = !!(direction & (EAST|WEST))
	var/positive = direction == NORTH || direction == EAST
	var/low = horizontal ? min(bounds[1], bounds[3]) : min(bounds[2], bounds[4])
	var/high = horizontal ? max(bounds[1], bounds[3]) : max(bounds[2], bounds[4])
	var/ship_edge = positive ? high + 1 + ship_clearance : low - 1 - ship_clearance
	var/site_edge = (horizontal ? berth.x : berth.y) + (positive ? -site_clearance : site_clearance)
	var/axis_limit = horizontal ? world.maxx : world.maxy
	var/extent = horizontal ? world.maxy : world.maxx
	if(min(ship_edge, site_edge) <= TRANSITIONEDGE + 1 || max(ship_edge, site_edge) >= axis_limit - TRANSITIONEDGE)
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
	for(var/deck in 0 to decks - 1)
		var/turf/ship_gate = locate(horizontal ? ship_edge : 1, horizontal ? 1 : ship_edge, vessel.z + deck)
		var/turf/site_gate = locate(horizontal ? site_edge : 1, horizontal ? 1 : site_edge, berth.z + deck)
		for(var/turf/gate as anything in list(ship_gate, site_gate))
			var/datum/stationtrauma_map_preview/preview = new preview_type(gate.GetComponent(/datum/component/stationtrauma_map_passage), extent, TRUE)
			previews += preview
			RegisterSignal(preview, COMSIG_QDELETING, PROC_REF(member_deleted))
			if(!preview.rebuild(budget) || QDELETED(src) || QDELETED(vessel) || prepared_revision != revision)
				return FALSE
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
	for(var/datum/stationtrauma_map_preview/preview as anything in previews)
		if(QDELETED(preview) || preview.closing || preview.rebuilding)
			return FALSE
	if(arrival_check && !arrival_check.Invoke())
		return FALSE
	active = TRUE
	for(var/datum/stationtrauma_map_preview/preview as anything in previews)
		preview.activate()
	return TRUE
