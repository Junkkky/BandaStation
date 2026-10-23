/** Swimming controls apply only to mobile, upright occupants of deep hydraulic water. */
/mob/living/proc/can_stationtrauma_swim(datum/component/floodwater/water = null)
	if(!isopenturf(loc) || stat != STABLE || body_position != STANDING_UP || !(mobility_flags & MOBILITY_MOVE) || anchored || buckled || throwing || pulledby || (movement_type & MOVETYPES_NOT_TOUCHING_GROUND) || HAS_TRAIT(src, TRAIT_MOB_ELEVATED) || HAS_TRAIT(src, TRAIT_NEGATES_GRAVITY))
		return FALSE
	water = water || loc.GetComponent(/datum/component/floodwater)
	return water && water.get_depth() >= FLOOD_WATER_DEEP && water.affects(src)

/** HUD and keyboard share the same swimming command; dry movement retains the native path. */
/mob/living/up()
	var/datum/status_effect/floodwater/water = has_status_effect(/datum/status_effect/floodwater)
	if(water?.begin_vertical_swim(UP))
		return
	return ..()

/mob/living/down()
	var/datum/status_effect/floodwater/water = has_status_effect(/datum/status_effect/floodwater)
	if(water?.begin_vertical_swim(DOWN))
		return
	return ..()

/** Ladders and remote controls keep native priority; a held key cannot overlap strokes. */
/datum/status_effect/floodwater/proc/begin_vertical_swim(direction)
	if(!owner.can_stationtrauma_swim() || owner.remote_control || (locate(/obj/structure/ladder) in owner.loc))
		return FALSE
	if(!vertical_swim_pending)
		vertical_swim_pending = TRUE
		INVOKE_ASYNC(src, PROC_REF(swim_vertical), direction)
	return TRUE

/** Keep native geometry, incapacitation and pulling checks, omitting only the requirement to fly against gravity. */
/datum/status_effect/floodwater/proc/swim_vertical(direction)
	var/mob/living/swimmer = owner
	var/flags = (ZMOVE_FLIGHT_FLAGS & ~ZMOVE_CAN_FLY_CHECKS)|ZMOVE_FEEDBACK
	var/moved = FALSE
	if(swimmer.can_z_move(direction, get_turf(swimmer), null, flags) && do_after(swimmer, 1 SECONDS, cog_icon = null))
		if(!QDELETED(src) && !QDELETED(swimmer) && swimmer.can_stationtrauma_swim() && !swimmer.remote_control)
			moved = swimmer.zMove(direction, z_move_flags = flags)
	if(!QDELETED(src))
		vertical_swim_pending = FALSE
	return moved

/** Nearby solid walls and anchored glass/closed doors provide the same local support as zero gravity. */
/mob/living/proc/stationtrauma_swim_grip()
	if(!isturf(loc))
		return FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/nearby = get_step(src, direction)
		if(nearby?.density)
			return TRUE
		var/obj/structure/window/window = locate() in nearby
		if(window?.anchored && window.density && !CANATMOSPASS(window, loc, FALSE))
			return TRUE
		var/obj/machinery/door/door = locate() in nearby
		if(door?.density && !CANATMOSPASS(door, loc, FALSE))
			return TRUE
	return FALSE

/** Only active strokes and their short coast enter processing; water cells are never scanned. */
/datum/component/floodwater_swimming
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Actual successful stroke direction, not the direction attempted against a barrier.
	var/direction
	/// Consecutive strokes determine speed and a maximum three-step coast.
	var/strokes = 0
	/// A pause or turn loses the accumulated acceleration.
	var/last_stroke = 0
	/// Remaining residual moves never accumulate beyond the acceleration limit.
	var/steps_left = 0
	/// Coast starts after normal input cadence and slows after each step.
	var/next_move = 0
	/// A blocked held key cannot leave an active processor forever.
	var/expires = 0
	/// Own coast moves retain the component; other forced moves cancel it.
	var/moving = FALSE
	/// The late client pre-move signal identifies the following voluntary native move.
	var/turf/input_from
	/// A blocked input must not authorize a later unrelated displacement.
	var/turf/input_to
	/// The marker is valid only during the same synchronous move call.
	var/input_time = -1
	/// Preserve pre-existing glide unless another system has since changed it.
	var/original_glide
	/// Last glide value set by our own coast.
	var/last_glide

/datum/component/floodwater_swimming/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/swimmer = parent
	if(!swimmer.can_stationtrauma_swim())
		return COMPONENT_INCOMPATIBLE
	original_glide = swimmer.glide_size
	START_PROCESSING(SSnewtonian_movement, src)

/datum/component/floodwater_swimming/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(prepare_step))
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))

/datum/component/floodwater_swimming/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGOUT))

/datum/component/floodwater_swimming/Destroy(force)
	STOP_PROCESSING(SSnewtonian_movement, src)
	var/mob/living/swimmer = parent
	if(!QDELETED(swimmer) && swimmer.glide_size == last_glide)
		swimmer.set_glide_size(original_glide)
	. = ..()
	if(!QDELETED(swimmer))
		var/datum/status_effect/floodwater/water = swimmer.has_status_effect(/datum/status_effect/floodwater)
		if(!QDELETED(water))
			water.update_water()

/** Successful player input replenishes a bounded coast, never extends a previously queued movement list. */
/datum/component/floodwater_swimming/proc/stroke(new_direction)
	var/mob/living/swimmer = parent
	input_time = -1
	var/chain = max(FLOOD_WATER_SWIM_CHAIN, swimmer.cached_multiplicative_slowdown * 1.5)
	strokes = direction == new_direction && world.time - last_stroke <= chain ? min(strokes + 1, FLOOD_WATER_SWIM_STROKES) : 1
	direction = new_direction
	last_stroke = world.time
	steps_left = strokes >= FLOOD_WATER_SWIM_STROKES ? strokes : 0
	next_move = world.time + max(FLOOD_WATER_SWIM_RELEASE_DELAY, swimmer.cached_multiplicative_slowdown * 1.5)
	expires = next_move + 3 SECONDS

/datum/component/floodwater_swimming/proc/prepare_step(mob/living/source, list/move_args)
	SIGNAL_HANDLER
	input_from = source.loc
	input_to = move_args[MOVE_ARG_NEW_LOC]
	input_time = world.time

/datum/component/floodwater_swimming/proc/on_moved(mob/living/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(moving)
		return
	if(!forced && input_time == world.time)
		// Native diagonal input emits two cardinal Moved signals before the single client-moved signal.
		if(source.moving_diagonally && input_from.z == source.z && get_dist(input_from, source.loc) <= 1)
			return
		if(old_loc == input_from && source.loc == input_to)
			input_time = -1
			return
	qdel(src)

/datum/component/floodwater_swimming/proc/on_logout()
	SIGNAL_HANDLER
	qdel(src)

/** Native Move chooses its own diagonal split order, so both intermediate paths must stay wet and open. */
/datum/component/floodwater_swimming/proc/can_coast_to(turf/open/tile, turf/open/next_tile)
	if(!isopenturf(next_tile) || next_tile.get_water_depth() < FLOOD_WATER_DEEP)
		return FALSE
	if(direction in GLOB.cardinals)
		return tile.can_pass_stationtrauma_water(next_tile)
	for(var/side in list(direction & (NORTH|SOUTH), direction & (EAST|WEST)))
		var/turf/open/intermediate = get_step(tile, side)
		if(!isopenturf(intermediate) || intermediate.get_water_depth() < FLOOD_WATER_DEEP || !tile.can_pass_stationtrauma_water(intermediate) || !intermediate.can_pass_stationtrauma_water(next_tile))
			return FALSE
	return TRUE

/datum/component/floodwater_swimming/process(seconds_per_tick)
	var/mob/living/swimmer = parent
	if((input_time >= 0 && world.time > input_time) || world.time >= expires || !swimmer.can_stationtrauma_swim() || swimmer.pulling || swimmer.has_buckled_mobs() || swimmer.GetComponent(/datum/component/floodwater_drift) || swimmer.client?.movement_locked)
		qdel(src)
		return
	if(swimmer.client?.intended_direction || world.time < next_move)
		return
	if(!steps_left || swimmer.stationtrauma_swim_grip())
		qdel(src)
		return
	var/turf/open/tile = swimmer.loc
	var/turf/open/next_tile = get_step(tile, direction)
	if(!can_coast_to(tile, next_tile))
		qdel(src)
		return
	var/delay = FLOOD_WATER_SWIM_COAST_INTERVAL + (strokes - steps_left) * FLOOD_WATER_SWIM_COAST_DECAY
	if(!(direction in GLOB.cardinals))
		delay *= 1.4
	last_glide = MOVEMENT_ADJUSTED_GLIDE_SIZE(delay, SSnewtonian_movement.visual_delay)
	swimmer.client?.visual_delay = last_glide
	moving = TRUE
	var/moved = swimmer.Move(next_tile, direction, last_glide, FALSE)
	moving = FALSE
	if(!moved || QDELETED(src) || QDELETED(swimmer) || swimmer.loc != next_tile)
		qdel(src)
		return
	steps_left--
	var/datum/status_effect/floodwater/water = swimmer.has_status_effect(/datum/status_effect/floodwater)
	water?.show_swim_bubbles(tile, direction)
	next_move = world.time + delay
