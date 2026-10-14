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
	last_glide = DELAY_TO_GLIDE_SIZE(delay / (1 SECONDS))
	moving = TRUE
	var/moved = movable.Move(next_tile, direction, last_glide, FALSE)
	moving = FALSE
	if(!moved || QDELETED(movable) || movable.loc != next_tile)
		qdel(src)
		return
	steps_left--
	force *= FLOOD_WATER_DRIFT_DAMPING
	next_move = world.time + delay * 2
