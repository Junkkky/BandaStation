/** Bound our own uninterrupted work; do not change global maploading or MC scheduling limits. */
/datum/stationtrauma_work_budget
	var/slice_tick = -1
	var/slice_start = 0
	var/peak_usage = 0
	/// Ten percent of a normal server tick, plus at most one native batch.
	var/allowance = 10

/datum/stationtrauma_work_budget/proc/yield()
	if(slice_tick != world.time)
		slice_tick = world.time
		slice_start = TICK_USAGE
	var/used = max(0, TICK_USAGE - slice_start)
	peak_usage = max(peak_usage, used)
	if(used < allowance && TICK_USAGE < TICK_LIMIT_MC)
		return
	sleep(world.tick_lag)
	slice_tick = world.time
	slice_start = TICK_USAGE

