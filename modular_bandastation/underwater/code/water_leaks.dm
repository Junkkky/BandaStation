/** Small ocean inlets on existing damaged walls/windows; finite water still belongs to C. */
/datum/component/floodwater_leak
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Total effective opening in square metres, shared by this barrier's ocean contacts.
	var/opening = 0
	/// External ocean turf -> finite intake; never a new passable link through the barrier.
	var/list/ports = list()
	/// Local geometry subscriptions exist only while the barrier is damaged.
	var/list/watched = list()
	/// Blocking objects must wake parked contacts on density changes or deletion.
	var/list/obstacles = list()

/datum/component/floodwater_leak/Initialize()
	if(!iswallturf(parent) && !istype(parent, /obj/structure/window))
		return COMPONENT_INCOMPATIBLE
	return ..()

/datum/component/floodwater_leak/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(examine))
	if(iswallturf(parent))
		RegisterSignals(parent, list(COMSIG_ATOM_BULLET_ACT, COMSIG_ATOM_HULK_ATTACK, COMSIG_ATOM_ATTACK_MECH, COMSIG_ATOM_EX_ACT, COMSIG_ATOM_ITEM_INTERACTION, COMSIG_ATOM_TOOL_ACT(TOOL_WELDER)), PROC_REF(queue_refresh))
		RegisterSignal(parent, COMSIG_TURF_CHANGE, PROC_REF(turf_changed))
	else
		RegisterSignals(parent, list(COMSIG_ATOM_INTEGRITY_CHANGED, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE), PROC_REF(queue_refresh))
	refresh()

/datum/component/floodwater_leak/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_EXAMINE, COMSIG_ATOM_BULLET_ACT, COMSIG_ATOM_HULK_ATTACK, COMSIG_ATOM_ATTACK_MECH, COMSIG_ATOM_EX_ACT, COMSIG_ATOM_ITEM_INTERACTION, COMSIG_ATOM_TOOL_ACT(TOOL_WELDER), COMSIG_TURF_CHANGE, COMSIG_ATOM_INTEGRITY_CHANGED, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE))
	return ..()

/datum/component/floodwater_leak/Destroy(force)
	SSfloodwater.active -= src
	SSfloodwater.leaks -= src
	clear_ports()
	return ..()

/** Native wall attacks announce before adding dents; observe their final result once. */
/datum/component/floodwater_leak/proc/queue_refresh()
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(refresh)), 0, TIMER_UNIQUE)

/datum/component/floodwater_leak/proc/turf_changed(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	if(source == parent)
		qdel(src)
		return
	post_change_callbacks += CALLBACK(src, PROC_REF(refresh))

/datum/component/floodwater_leak/proc/geometry_changed(datum/source, atom/movable/moved)
	SIGNAL_HANDLER
	if(istype(moved, /atom/movable) && (!isobj(moved) || moved.can_atmos_pass == ATMOS_PASS_YES))
		return
	queue_refresh()

/datum/component/floodwater_leak/proc/examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(opening && ports.len)
		examine_list += span_warning("Через повреждения сочится морская вода. Заварите повреждения сварочным аппаратом.")

/** Existing dents and window integrity are the damage model; no second hull health pool. */
/datum/component/floodwater_leak/proc/damaged_opening()
	if(iswallturf(parent))
		// shortcut: scripted add_dent without an attack signal needs refresh; add a native dent signal if gameplay starts doing this.
		var/turf/closed/wall/wall = parent
		var/leaking_dents = max(0, min(length(wall.dent_decals), FLOOD_WATER_LEAK_MAX_DENTS) - FLOOD_WATER_LEAK_MIN_DENTS + 1)
		return leaking_dents * FLOOD_WATER_LEAK_OPENING
	var/obj/structure/window/window = parent
	if(!window.anchored || !window.density || !window.max_integrity)
		return 0
	var/damage = max(0, FLOOD_WATER_LEAK_WINDOW_INTEGRITY - window.get_integrity() / window.max_integrity)
	return damage / FLOOD_WATER_LEAK_WINDOW_INTEGRITY * FLOOD_WATER_LEAK_MAX_DENTS * FLOOD_WATER_LEAK_OPENING

/datum/component/floodwater_leak/proc/clear_ports()
	for(var/obj/obstacle as anything in obstacles)
		UnregisterSignal(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING))
	obstacles.Cut()
	for(var/turf/tile as anything in watched)
		UnregisterSignal(tile, list(COMSIG_TURF_CHANGE, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED))
	watched.Cut()
	ports.Cut()

/datum/component/floodwater_leak/proc/watch_tile(turf/tile)
	if(!tile || tile == parent || (tile in watched))
		return
	watched += tile
	RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(turf_changed))
	RegisterSignals(tile, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED), PROC_REF(geometry_changed))
	for(var/obj/obstacle in tile)
		if(obstacle == parent || obstacle.can_atmos_pass == ATMOS_PASS_YES || (obstacle in obstacles))
			continue
		obstacles += obstacle
		RegisterSignals(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING), PROC_REF(queue_refresh))

/** Rebuild at most four local ports when damage or nearby geometry changes. */
/datum/component/floodwater_leak/proc/refresh()
	SSfloodwater.active -= src
	SSfloodwater.leaks -= src
	clear_ports()
	var/turf/location = get_turf(parent)
	if(!istype(get_area(location), /area/shuttle/stationtrauma))
		qdel(src)
		return
	opening = damaged_opening()
	if(!opening)
		return
	watch_tile(location)
	for(var/direction in GLOB.cardinals)
		var/turf/open/outside = get_step(location, direction)
		var/turf/open/intake = location
		watch_tile(outside)
		if(iswallturf(parent))
			intake = get_step(location, turn(direction, 180))
		else
			var/obj/structure/window/window = parent
			if(window.fulltile)
				intake = get_step(location, turn(direction, 180))
			if(CANATMOSPASS(window, outside, FALSE))
				continue
		watch_tile(intake)
		if(can_leak(outside, intake))
			ports[outside] = intake
	if(ports.len)
		SSfloodwater.leaks[src] = TRUE
		wake()

/** Only this damaged barrier is bypassed; other windows, doors and walls still isolate. */
/datum/component/floodwater_leak/proc/can_leak(turf/open/outside, turf/open/intake)
	if(!istype(outside, /turf/open/space/ocean) || !isopenturf(intake) || isspaceturf(intake) || istype(intake, /turf/open/water) || intake.blocks_air || !istype(get_area(intake), /area/shuttle/stationtrauma))
		return FALSE
	var/datum/component/floodwater/source = outside.GetComponent(/datum/component/floodwater)
	if(!source?.infinite_source)
		return FALSE
	var/datum/component/floodwater/inside_water = intake.GetComponent(/datum/component/floodwater)
	if(inside_water?.infinite_source)
		return FALSE
	var/turf/location = get_turf(parent)
	var/direction = get_dir(location, outside)
	if(outside.z != location.z || get_step(location, direction) != outside || !(direction in GLOB.cardinals))
		return FALSE
	if(intake != location && get_step(location, turn(direction, 180)) != intake)
		return FALSE
	if(istype(parent, /obj/structure/window))
		var/obj/structure/window/window = parent
		if(CANATMOSPASS(window, outside, FALSE))
			return FALSE
	for(var/obj/obstacle in location)
		if(obstacle != parent && (!CANATMOSPASS(obstacle, outside, FALSE) || !CANATMOSPASS(obstacle, intake, FALSE)))
			return FALSE
	for(var/obj/obstacle in outside)
		if(!CANATMOSPASS(obstacle, intake, FALSE))
			return FALSE
	if(intake != location)
		for(var/obj/obstacle in intake)
			if(!CANATMOSPASS(obstacle, outside, FALSE))
				return FALSE
	return TRUE

/** A parked full-room inlet is woken by aggregate withdrawals, not by polling wet floors. */
/datum/component/floodwater_leak/proc/wake(datum/floodwater_front_group/owner = null, datum/floodwater_front_cell/withdrawn_cell = null)
	for(var/turf/outside as anything in ports)
		var/datum/floodwater_front_cell/contact = SSfloodwater.hybrid.by_turf[ports[outside]]
		if(owner && contact?.root() != owner)
			continue
		if(!owner && withdrawn_cell && contact != withdrawn_cell)
			continue
		// Geometry callbacks must not reactivate an inlet with no room to receive water.
		if(!contact || contact.capacity() > 0 || contact.root()?.dirty)
			SSfloodwater.active[src] = TRUE
			return

/** Feed accepted litres into C; keep the original large-breach flow untouched. */
/datum/component/floodwater_leak/proc/feed_ocean()
	if(!istype(get_area(parent), /area/shuttle/stationtrauma))
		qdel(src)
		return
	if(opening != damaged_opening())
		refresh()
	if(!ports.len || !opening)
		return
	for(var/turf/open/outside as anything in ports)
		var/turf/open/intake = ports[outside]
		if(QDELETED(outside) || QDELETED(intake) || !can_leak(outside, intake))
			continue
		var/datum/component/floodwater/source = outside.GetComponent(/datum/component/floodwater)
		var/datum/component/floodwater/water = intake.GetComponent(/datum/component/floodwater)
		var/difference = source.reservoir_pressure - intake.stationtrauma_water_pressure(water)
		if(difference <= FLOOD_WATER_PRESSURE_EPSILON)
			continue
		var/volume = 600 * opening / ports.len * sqrt(2 * difference) * SSfloodwater.step_seconds
		volume = limit_stationtrauma_boundary_flow(intake, water, source.reservoir_pressure, volume)
		if(!volume)
			continue
		var/transferred = intake.add_water(volume, source.temperature)
		var/datum/floodwater_front_cell/contact = SSfloodwater.hybrid.by_turf[intake]
		if(transferred || contact?.root()?.dirty)
			wake()

/** Hull membership observes ordinary mapped/rebuilt windows, without a global window override. */
/datum/element/stationtrauma_hull/proc/watch_window(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(istype(arrived, /obj/structure/window) && arrived.flags_1 & INITIALIZED_1)
		arrived.AddComponent(/datum/component/floodwater_leak)
