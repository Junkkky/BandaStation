/** Start or refresh a bounded local drift; another pulse never adds to its step budget. */
/datum/controller/subsystem/floodwater/proc/start_water_drift(atom/movable/movable, direction, force)
	if(!(direction in GLOB.cardinals) || force <= 0)
		return FALSE
	if(isitem(movable))
		var/obj/item/item = movable
		force /= max(1, item.w_class / WEIGHT_CLASS_NORMAL)
	if(!movable?.can_drift_stationtrauma_water(force))
		return FALSE
	var/turf/open/tile = movable.loc
	var/turf/open/next_tile = get_step(tile, direction)
	if(!isopenturf(next_tile) || next_tile.get_water_depth() <= 0 || !tile.can_pass_stationtrauma_water(next_tile))
		return FALSE
	var/datum/component/floodwater_drift/drift = movable.GetComponent(/datum/component/floodwater_drift)
	if(drift)
		drift.refresh(direction, force)
	else
		movable.AddComponent(/datum/component/floodwater_drift, direction, force)
	return TRUE

/** Recheck native resistance and protection on each residual step, including changes after a throw. */
/atom/movable/proc/can_drift_stationtrauma_water(force)
	if(QDELETED(src) || !isopenturf(loc) || anchored || throwing || pulledby || has_buckled_mobs() || move_resist == INFINITY || force < move_resist * MOVE_FORCE_PUSH_RATIO)
		return FALSE
	var/turf/open/tile = loc
	if(tile.get_water_depth() <= 0)
		return FALSE
	if(isliving(src))
		var/mob/living/victim = src
		if(victim.buckled || HAS_TRAIT(victim, TRAIT_GODMODE) || HAS_TRAIT(victim, TRAIT_NEGATES_GRAVITY))
			return FALSE
		if((victim.movement_type & MOVETYPES_NOT_TOUCHING_GROUND) && tile.get_water_depth() < FLOOD_WATER_SUBMERGED)
			return FALSE
	return !(SEND_SIGNAL(src, COMSIG_ATOM_PRE_PRESSURE_PUSH) & COMSIG_ATOM_BLOCKS_PRESSURE)

/** Two fading native moves after the last impulse; only moving objects enter Fast Processing. */
/datum/component/floodwater_drift
	/// Last confirmed direction and force, shared by refreshed pulses.
	var/direction
	/// Residual movement force decays after each successful step.
	var/force
	/// Remaining steps never accumulate across overlapping jets.
	var/steps_left
	/// Stop even if the server cannot schedule the remaining moves in time.
	var/expires
	/// Preserve the next scheduled move when refreshed, avoiding starvation under a continuous flow.
	var/next_move
	/// Ignore our own movement signal; pickup, teleport or player movement cancels the drift.
	var/moving = FALSE
	/// Restore our temporary glide only if another movement has not already replaced it.
	var/original_glide
	/// Most recent glide owned by this component.
	var/last_glide

/datum/component/floodwater_drift/Initialize(direction, force)
	if(!ismovable(parent) || !(direction in GLOB.cardinals) || force <= 0)
		return COMPONENT_INCOMPATIBLE
	var/atom/movable/movable = parent
	original_glide = movable.glide_size
	next_move = world.time + FLOOD_WATER_DRIFT_INTERVAL
	refresh(direction, force)
	START_PROCESSING(SSfastprocess, src)

/datum/component/floodwater_drift/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_external_move))

/datum/component/floodwater_drift/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/datum/component/floodwater_drift/Destroy(force)
	STOP_PROCESSING(SSfastprocess, src)
	var/atom/movable/movable = parent
	if(ismovable(movable) && !QDELETED(movable) && movable.glide_size == last_glide)
		movable.set_glide_size(original_glide)
	return ..()

/** Accepted flow replenishes a fixed budget, rather than creating another processor or timer. */
/datum/component/floodwater_drift/proc/refresh(direction, force)
	src.direction = direction
	src.force = force
	steps_left = FLOOD_WATER_DRIFT_STEPS
	expires = world.time + FLOOD_WATER_DRIFT_DURATION

/datum/component/floodwater_drift/proc/on_external_move()
	SIGNAL_HANDLER
	if(!moving)
		qdel(src)

/datum/component/floodwater_drift/process(seconds_per_tick)
	var/atom/movable/movable = parent
	if(world.time >= expires)
		qdel(src)
		return
	// Let the final glide finish before restoring it; there are no further movement attempts.
	if(!steps_left)
		return
	if(!movable.can_drift_stationtrauma_water(force))
		qdel(src)
		return
	if(world.time < next_move)
		return
	var/turf/open/tile = movable.loc
	var/turf/open/next_tile = get_step(tile, direction)
	if(!isopenturf(next_tile) || next_tile.get_water_depth() <= 0 || !tile.can_pass_stationtrauma_water(next_tile))
		qdel(src)
		return
	var/delay = FLOOD_WATER_DRIFT_INTERVAL * (1 + FLOOD_WATER_DRIFT_STEPS - steps_left)
	last_glide = DELAY_TO_GLIDE_SIZE(delay)
	moving = TRUE
	var/moved = movable.Move(next_tile, direction, last_glide, FALSE)
	moving = FALSE
	if(!moved || QDELETED(movable) || movable.loc != next_tile)
		qdel(src)
		return
	steps_left--
	force *= FLOOD_WATER_DRIFT_DAMPING
	next_move = world.time + delay * 2

/** Catch the native entry before a throw can finish, including the first visitor to a lazy ocean tile. */
/atom/movable/proc/start_stationtrauma_ocean_drift()
	if(!isitem(src) || !throwing || GetComponent(/datum/component/floodwater_thrown_drift))
		return
	var/datum/component/floodwater/water = loc.GetComponent(/datum/component/floodwater)
	if(water?.infinite_source && water.get_depth() >= FLOOD_WATER_DEEP)
		AddComponent(/datum/component/floodwater_thrown_drift)

/turf/open/space/ocean/Entered(atom/movable/arrived)
	. = ..()
	arrived.start_stationtrauma_ocean_drift()

/turf/open/space/openspace/ocean/Entered(atom/movable/arrived)
	. = ..()
	arrived.start_stationtrauma_ocean_drift()

/** A throw that reaches open ocean keeps drifting on the native movement loop, at water speed. */
/datum/component/floodwater_thrown_drift
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Native smooth movement preserves the throw's angle, including shallow diagonals.
	var/datum/move_loop/smooth_move/drifting_loop
	/// Only movement made by our loop may retain the drift after landing.
	var/moving = FALSE

/datum/component/floodwater_thrown_drift/Initialize()
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	var/obj/item/item = parent
	if(!item.throwing)
		return COMPONENT_INCOMPATIBLE

/datum/component/floodwater_thrown_drift/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_IMPACT, PROC_REF(on_impact))
	RegisterSignal(parent, COMSIG_MOVABLE_THROW_LANDED, PROC_REF(on_landed))

/datum/component/floodwater_thrown_drift/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_IMPACT, COMSIG_MOVABLE_THROW_LANDED, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_POST_THROW))

/datum/component/floodwater_thrown_drift/Destroy(force)
	if(drifting_loop)
		UnregisterSignal(drifting_loop, list(COMSIG_MOVELOOP_PREPROCESS_CHECK, COMSIG_MOVELOOP_POSTPROCESS, COMSIG_MOVELOOP_STOP, COMSIG_QDELETING))
		QDEL_NULL(drifting_loop)
	return ..()

/datum/component/floodwater_thrown_drift/proc/on_impact(obj/item/source, atom/hit, datum/thrownthing/throwing, caught)
	SIGNAL_HANDLER
	if(caught || !isopenturf(hit))
		qdel(src)

/datum/component/floodwater_thrown_drift/proc/can_float()
	var/obj/item/item = parent
	if(!isopenturf(item.loc) || item.anchored || item.move_resist == INFINITY || item.throwing || item.pulledby || item.GetComponent(/datum/component/floodwater_drift))
		return FALSE
	var/datum/component/floodwater/water = item.loc.GetComponent(/datum/component/floodwater)
	return water?.infinite_source && water.get_depth() >= FLOOD_WATER_DEEP

/datum/component/floodwater_thrown_drift/proc/on_landed(obj/item/source, datum/thrownthing/throwing)
	SIGNAL_HANDLER
	if(throwing.blocked || !throwing.dist_travelled || !can_float())
		qdel(src)
		return
	UnregisterSignal(parent, list(COMSIG_MOVABLE_IMPACT, COMSIG_MOVABLE_THROW_LANDED))
	drifting_loop = GLOB.move_manager.smooth_move(
		moving = parent,
		angle = get_angle(throwing.starting_turf, throwing.target_turf),
		delay = 0.6 SECONDS,
		subsystem = SSnewtonian_movement,
		priority = MOVEMENT_SPACE_PRIORITY,
		flags = MOVEMENT_LOOP_OUTSIDE_CONTROL|MOVEMENT_LOOP_NO_DIR_UPDATE,
	)
	if(!drifting_loop)
		qdel(src)
		return
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_MOVABLE_POST_THROW, PROC_REF(stop_drift))
	RegisterSignal(drifting_loop, COMSIG_MOVELOOP_PREPROCESS_CHECK, PROC_REF(before_move))
	RegisterSignal(drifting_loop, COMSIG_MOVELOOP_POSTPROCESS, PROC_REF(after_move))
	RegisterSignal(drifting_loop, COMSIG_MOVELOOP_STOP, PROC_REF(stop_drift))
	RegisterSignal(drifting_loop, COMSIG_QDELETING, PROC_REF(loop_deleted))

/datum/component/floodwater_thrown_drift/proc/before_move()
	SIGNAL_HANDLER
	if(!can_float())
		qdel(src)
		return MOVELOOP_SKIP_STEP
	moving = TRUE

/datum/component/floodwater_thrown_drift/proc/after_move(datum/source, result)
	SIGNAL_HANDLER
	moving = FALSE
	if(result != MOVELOOP_SUCCESS)
		qdel(src)

/datum/component/floodwater_thrown_drift/proc/on_moved(obj/item/source, atom/old_loc, direction, forced)
	SIGNAL_HANDLER
	if(!moving || forced)
		qdel(src)

/datum/component/floodwater_thrown_drift/proc/stop_drift()
	SIGNAL_HANDLER
	qdel(src)

/datum/component/floodwater_thrown_drift/proc/loop_deleted()
	SIGNAL_HANDLER
	drifting_loop = null
	qdel(src)

/** A floating throw must not fall to the next ocean deck when native throwing finalizes. */
/turf/open/space/ocean/zFall(atom/movable/falling, levels = 1, force = FALSE, falling_from_move = FALSE)
	if(!force && falling.GetComponent(/datum/component/floodwater_thrown_drift))
		return FALSE
	return ..()

/turf/open/space/openspace/ocean/zFall(atom/movable/falling, levels = 1, force = FALSE, falling_from_move = FALSE)
	if(!force && falling.GetComponent(/datum/component/floodwater_thrown_drift))
		return FALSE
	return ..()
