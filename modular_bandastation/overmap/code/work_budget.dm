// AI EDIT START - overmap module integration
/** Bound module work within native MC scheduling limits. */
/datum/stationtrauma_work_budget
	/// world.time at which the current cooperative work slice began.
	var/slice_tick = -1
	/// TICK_USAGE recorded at the start of the current work slice.
	var/slice_start = 0
	/// Runtime work gets ten percent of a tick; initialization uses the native MC limit.
	var/allowance = 10

/** Yield when this work slice or the native MC tick budget is exhausted. */
/datum/stationtrauma_work_budget/proc/yield()
	if(slice_tick != world.time)
		slice_tick = world.time
		slice_start = TICK_USAGE
	var/used = max(0, TICK_USAGE - slice_start)
	if(TICK_USAGE < TICK_LIMIT_MC && (Master.current_initializing_subsystem || used < allowance))
		return
	sleep(world.tick_lag)
	slice_tick = world.time
	slice_start = TICK_USAGE
// AI EDIT END
