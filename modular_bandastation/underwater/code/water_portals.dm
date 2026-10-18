/** Equalized edges retain local subscriptions, but leave the native transfer queue. */
/datum/floodwater_front_portal
	/// Queue membership is independent of geometric openness.
	var/active = FALSE
	/// Owners observed at sleep time; geometry may replace them before cleanup.
	var/datum/floodwater_front_group/sleep_left
	/// Second observed owner, possibly the same as the first.
	var/datum/floodwater_front_group/sleep_right

/datum/floodwater_front_cell
	/// Sleeping incident edges, including edges whose endpoint is still dry.
	var/list/sleeping_portals

/datum/floodwater_front_group
	/// Sleeping edges observing any share of this aggregate stock.
	var/list/sleeping_portals

/** Drop both endpoint and aggregate subscriptions before waking, closing or deleting an edge. */
/datum/floodwater_front_portal/proc/forget_sleep()
	LAZYREMOVE(left?.sleeping_portals, src)
	LAZYREMOVE(right?.sleeping_portals, src)
	LAZYREMOVE(sleep_left?.sleeping_portals, src)
	LAZYREMOVE(sleep_right?.sleeping_portals, src)
	sleep_left = null
	sleep_right = null
	var/datum/floodwater_hybrid/native = solver
	if(istype(native))
		if(!length(left?.sleeping_portals))
			native.pressure_watch -= left
		if(!length(right?.sleeping_portals))
			native.pressure_watch -= right

/** Sorted insertion preserves the original transfer order after any wake event. */
/datum/floodwater_front_portal/proc/set_active(awake)
	forget_sleep()
	awake = awake && open
	if(active == awake)
		return
	active = awake
	if(!open_index)
		return
	if(active)
		BINARY_INSERT(src, open_index, /datum/floodwater_front_portal, src, open_order, COMPARE_KEY)
	else
		open_index -= src
	var/datum/floodwater_hybrid/native = solver
	if(!active || !istype(native) || native.native_phase != (open_index == native.open_vertical_portals ? FLOOD_NATIVE_VERTICAL : FLOOD_NATIVE_PORTALS))
		return
	var/datum/floodwater_front_portal/previous = native.native_cursor > 1 ? native.portal_run[native.native_cursor - 1] : null
	if((previous && previous.open_order >= open_order) || (src in native.portal_run))
		return
	// Insert only after the cursor: a newly supplied downstream edge keeps this interval's original turn.
	BINARY_INSERT(src, native.portal_run, /datum/floodwater_front_portal, src, open_order, COMPARE_KEY)

/** Only a completed, unsuccessful live transfer can park an open edge. */
/datum/floodwater_front_portal/proc/sleep_until_changed()
	if(!active || !open || left.root()?.dirty || right.root()?.dirty)
		return
	set_active(FALSE)
	sleep_left = left.root()
	sleep_right = right.root()
	LAZYOR(left.sleeping_portals, src)
	LAZYOR(right.sleeping_portals, src)
	if(sleep_left)
		LAZYOR(sleep_left.sleeping_portals, src)
	if(sleep_right)
		LAZYOR(sleep_right.sleeping_portals, src)
	var/datum/floodwater_hybrid/native = solver
	if(!istype(native) || !sleep_right?.is_full() || (!sleep_left?.is_full() && elevation <= 0))
		return
	for(var/datum/floodwater_front_cell/cell as anything in list(left, right))
		// LINDA has no general pressure signal; a full lower stock can also feed a dry upper endpoint.
		if(!(cell in native.pressure_watch))
			native.pressure_watch[cell] = cell.head_pressure()

/** A remote withdrawal changes every bulk share, not just the pump's intake cell. */
/datum/floodwater_front_group/proc/wake_portals()
	while(length(sleeping_portals))
		var/datum/floodwater_front_portal/portal = sleeping_portals[sleeping_portals.len]
		portal.set_active(TRUE)

/** Dry endpoints have no owner to receive a stock-change notification. */
/datum/floodwater_front_cell/proc/wake_portals()
	while(length(sleeping_portals))
		var/datum/floodwater_front_portal/portal = sleeping_portals[sleeping_portals.len]
		portal.set_active(TRUE)

/datum/floodwater_hybrid/wake(datum/floodwater_front_group/owner)
	owner.wake_portals()
	return ..()

/datum/floodwater_hybrid/invalidate(datum/floodwater_front_group/owner)
	owner?.wake_portals()
	return ..()

/datum/floodwater_hybrid/enqueue(datum/floodwater_front_cell/cell)
	cell.wake_portals()
	return ..()

/datum/floodwater_hybrid/process_cell(datum/floodwater_front_cell/cell, dt)
	// Local-front coarsening writes bulk shares directly, without receive().
	cell.root()?.wake_portals()
	return ..()
