SUBSYSTEM_DEF(floodwater)
	name = "Floodwater"
	wait = 0.1 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	ss_flags = SS_NO_INIT | SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/active = list()
	/// Damaged ocean contacts, including parked full-room leaks; intact barriers never enter this list.
	var/list/leaks = list()
	var/list/pumps = list()
	/// C is the only finite-water solver; domains are admitted when water appears.
	var/datum/floodwater_hybrid/hybrid = new
	/// Snapshots and cursors survive MC pauses without repeating inflow or pump work.
	var/list/source_run = list()
	var/list/pump_run = list()
	var/work_phase = FLOOD_WORK_SOURCES
	var/work_cursor = 0
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
		if(!simulate_step())
			return
		pending_time = max(0, pending_time - step_seconds)
		steps_completed++
		fire_steps++
		if(debug.enabled)
			debug.steps++
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/floodwater/stat_entry(msg)
	msg = "Sources:[length(active)] Steps:[steps_completed] Behind:[round(pending_time, 0.1)]s Dropped:[round(discarded_time, 0.1)]s"
	msg += " C:Groups[hybrid.groups.len] Front[hybrid.pending.len] Geometry[hybrid.dirty_groups.len] Effects[hybrid.changed.len + hybrid.paint_groups.len]"
	if(debug.enabled)
		msg += debug.statistics()
	return ..(msg)

/** Complete one physical step in order: ocean input, C ownership/effects, then pumps. */
/datum/controller/subsystem/floodwater/proc/simulate_step()
	if(!step_running)
		step_running = TRUE
		source_run = active
		active = list()
		work_cursor = source_run.len
		work_phase = FLOOD_WORK_SOURCES
	if(work_phase == FLOOD_WORK_SOURCES)
		if(debug.enabled)
			debug.measure_phase("Ocean")
		while(work_cursor)
			var/datum/component/source = source_run[work_cursor--]
			if(!QDELETED(source))
				if(istype(source, /datum/component/floodwater_leak))
					var/datum/component/floodwater_leak/leak = source
					if(debug.enabled)
						debug.measure_phase("Leaks")
					leak.feed_ocean()
					if(debug.enabled)
						debug.measure_phase("Ocean")
				else
					var/datum/component/floodwater/ocean = source
					if(ocean.infinite_source)
						ocean.feed_ocean()
			if(MC_TICK_CHECK)
				return FALSE
		source_run.Cut()
		work_phase = FLOOD_WORK_FRONT
	if(work_phase == FLOOD_WORK_FRONT)
		if(!hybrid.advance_native(step_seconds))
			return FALSE
		pump_run = pumps.Copy()
		work_cursor = pump_run.len
		work_phase = FLOOD_WORK_PUMPS
	if(debug.enabled)
		debug.measure_phase("Pumps")
	while(work_cursor)
		var/obj/machinery/bilge_pump/pump = pump_run[work_cursor--]
		if(!QDELETED(pump))
			pump.collect_water(step_seconds)
			// A cold geometry traversal has not collected yet; finish it before advancing time.
			if(state == SS_PAUSED && pump.drain_building)
				work_cursor++
		if(MC_TICK_CHECK)
			return FALSE
	pump_run.Cut()
	step_running = FALSE
	return TRUE
