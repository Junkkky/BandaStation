SUBSYSTEM_DEF(floodwater)
	name = "Floodwater"
	wait = 0.1 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	ss_flags = SS_NO_INIT | SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/active = list()
	var/list/pumps = list()
	var/datum/floodwater_step/step = new
	var/datum/floodwater_pressure/pressure = new
	var/datum/floodwater_debug/debug = new
	var/last_update
	var/pending_time = 0
	var/step_seconds = 0.02
	var/steps_completed = 0
	var/step_running = FALSE
	var/fire_steps = 0
	var/discarded_time = 0

/datum/controller/subsystem/floodwater/fire(resumed = FALSE)
	if(!debug.enabled)
		return advance_water(resumed)
	if(!resumed)
		debug.reset()
	var/started = TICK_USAGE_REAL
	debug.measure_phase("Prepare")
	advance_water(resumed)
	debug.measure_phase(null)
	var/elapsed = TICK_DELTA_TO_MS(TICK_USAGE_REAL - started)
	debug.cpu_ms += elapsed
	debug.max_slice_ms = max(debug.max_slice_ms, elapsed)

/datum/controller/subsystem/floodwater/proc/advance_water(resumed = FALSE)
	if(world.time >= debug.next_update)
		if(debug.enabled)
			debug.measure_phase("Debug")
		debug.update_viewers()
		debug.next_update = world.time + 0.5 SECONDS
		if(debug.enabled)
			debug.measure_phase("Prepare")
	if(!resumed)
		fire_steps = 0
		// Preserve ordinary elapsed time, but never repay a long server stall in one fire.
		pending_time += isnull(last_update) ? wait / (1 SECONDS) : max(0, (world.time - last_update) / (1 SECONDS))
		last_update = world.time
		if(pending_time > FLOOD_WATER_MAX_BACKLOG)
			discarded_time += pending_time - FLOOD_WATER_MAX_BACKLOG
			pending_time = FLOOD_WATER_MAX_BACKLOG
	// One normal interval plus one catch-up interval repays bounded debt without an unbounded fire.
	var/step_budget = 2 * max(1, CEILING(wait / (1 SECONDS) / step_seconds, 1))
	while(pending_time + FLOOD_WATER_FLOW_EPSILON >= step_seconds && fire_steps < step_budget)
		if(!simulate_step(step_running))
			return
		pending_time = max(0, pending_time - step_seconds)
		steps_completed++
		fire_steps++
		if(debug.enabled)
			debug.steps++
		resumed = FALSE
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/floodwater/stat_entry(msg)
	msg = "Active:[length(active)] Steps:[steps_completed] Behind:[round(pending_time, 0.1)]s Dropped:[round(discarded_time, 0.1)]s"
	if(debug.enabled)
		msg += debug.statistics()
	return ..(msg)
