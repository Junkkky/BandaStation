/** Listen only for already committed boundary transfers; stable water has no impulse work. */
/datum/controller/subsystem/floodwater/PreInit()
	. = ..()
	RegisterSignal(src, COMSIG_STATIONTRAUMA_WATER_TRANSFER, PROC_REF(on_water_transfer))

/datum/floodwater_front_cell
	/// Limit occupant scans at one live outlet, independently of the hydraulic microstep.
	COOLDOWN_DECLARE(impulse_cooldown)
	/// A new burst requires a break in confirmed flow, rather than expiration of a victim's cooldown.
	var/impulse_last_transfer
	/// Replacing an existing ocean breach with a floor must not announce another decompression.
	var/impulse_floor_repair = FALSE

/mob/living
	/// Shared between overlapping water jets so they cannot repeatedly restart a throw or knockdown.
	COOLDOWN_DECLARE(floodwater_impulse_cooldown)

/** Hull repair can admit a floor that did not exist when the wet domain was first discovered. */
/datum/controller/subsystem/floodwater/proc/mark_repaired_inlet(turf/tile)
	if(!isfloorturf(tile) || relocating_turfs[tile])
		return
	if(!hybrid.by_turf[tile])
		hybrid.add_domain(list(tile))
	var/datum/floodwater_front_cell/contact = hybrid.by_turf[tile]
	contact.impulse_floor_repair = TRUE

/** A short straight jet follows the committed direction and stops at live barriers. */
/datum/controller/subsystem/floodwater/proc/on_water_transfer(datum/source, turf/open/from_tile, turf/open/to_tile, litres, head, opening, weak_leak)
	SIGNAL_HANDLER
	if(weak_leak || litres <= 0 || head <= 0 || opening <= 0)
		return
	if(!isopenturf(from_tile) || !isopenturf(to_tile))
		return
	// The current jet renderer and throws follow a horizontal line; vertical jets need separate presentation.
	if(from_tile.z != to_tile.z)
		return
	var/datum/floodwater_front_cell/contact = hybrid.by_turf[to_tile] || hybrid.by_turf[from_tile]
	if(!contact)
		return
	var/direction = get_dir(from_tile, to_tile)
	var/strength = sqrt(head * opening / FLOOD_WATER_BREACH_OPENING)
	if(strength < FLOOD_WATER_IMPULSE_KNOCKDOWN)
		show_flow_visual(contact, from_tile, to_tile, direction, FALSE)
		return
	if(!from_tile.can_pass_stationtrauma_water(to_tile))
		return
	var/datum/component/floodwater/source_water = from_tile.GetComponent(/datum/component/floodwater)
	var/repaired_inlet = contact.impulse_floor_repair && source_water?.infinite_source
	if(repaired_inlet)
		contact.impulse_floor_repair = FALSE
	var/burst = !repaired_inlet && (isnull(contact.impulse_last_transfer) || world.time - contact.impulse_last_transfer > FLOOD_WATER_IMPULSE_RESET)
	contact.impulse_last_transfer = world.time
	if(!burst && !COOLDOWN_FINISHED(contact, impulse_cooldown))
		return
	COOLDOWN_START(contact, impulse_cooldown, FLOOD_WATER_IMPULSE_INTERVAL)
	show_flow_visual(contact, from_tile, to_tile, direction, burst, TRUE)
	var/previous_phase = debug.phase_name
	if(debug.enabled)
		debug.measure_phase("Impulse")
	var/turf/open/tile = from_tile
	var/drift_objects = 0
	for(var/distance in -1 to FLOOD_WATER_IMPULSE_REACH)
		var/local_strength = strength / (max(0, distance) + 1)
		if(local_strength < FLOOD_WATER_IMPULSE_KNOCKDOWN)
			break
		// Native throws can move occupants immediately, so keep this tile's starting candidates.
		for(var/atom/movable/occupant in tile.contents.Copy())
			if(isliving(occupant))
				push_water_victim(occupant, tile, direction, local_strength, burst)
			else if((isitem(occupant) || istype(occupant, /obj/structure)) && drift_objects < FLOOD_WATER_DRIFT_OBJECT_LIMIT)
				var/force = min(MOVE_FORCE_VERY_STRONG, MOVE_FORCE_DEFAULT * local_strength / FLOOD_WATER_IMPULSE_KNOCKDOWN)
				if(start_water_drift(occupant, direction, force))
					drift_objects++
		var/turf/open/next_tile = get_step(tile, direction)
		if(!tile.can_pass_stationtrauma_water(next_tile))
			break
		tile = next_tile
	if(debug.enabled)
		debug.measure_phase(previous_phase)

/** Native status and throwing retain immunity, cancellation, movement resistance and collision handling. */
/datum/controller/subsystem/floodwater/proc/push_water_victim(mob/living/victim, turf/open/tile, direction, strength, burst)
	if(QDELETED(victim) || victim.loc != tile || victim.anchored || victim.buckled || HAS_TRAIT(victim, TRAIT_GODMODE))
		return
	if((victim.movement_type & MOVETYPES_NOT_TOUCHING_GROUND) && tile.get_water_depth() < FLOOD_WATER_SUBMERGED)
		return
	if(HAS_TRAIT(victim, TRAIT_NEGATES_GRAVITY))
		return
	var/force = min(MOVE_FORCE_VERY_STRONG, MOVE_FORCE_DEFAULT * strength / FLOOD_WATER_IMPULSE_KNOCKDOWN)
	if(victim.move_resist == INFINITY || force < victim.move_resist * MOVE_FORCE_PUSH_RATIO || (SEND_SIGNAL(victim, COMSIG_ATOM_PRE_PRESSURE_PUSH) & COMSIG_ATOM_BLOCKS_PRESSURE))
		return
	victim.apply_status_effect(/datum/status_effect/floodwater_current)
	if(!victim.throwing && victim.body_position == LYING_DOWN)
		start_water_drift(victim, direction, force)
	if(victim.throwing || !COOLDOWN_FINISHED(victim, floodwater_impulse_cooldown))
		return
	if(!burst && !prob(FLOOD_WATER_IMPULSE_REPEAT_CHANCE))
		return
	COOLDOWN_START(victim, floodwater_impulse_cooldown, FLOOD_WATER_IMPULSE_COOLDOWN)
	victim.Knockdown(min(FLOOD_WATER_IMPULSE_KNOCKDOWN_MAX, 0.5 SECONDS * strength / FLOOD_WATER_IMPULSE_KNOCKDOWN))
	if(strength >= FLOOD_WATER_IMPULSE_THROW)
		var/range = clamp(round(strength / FLOOD_WATER_IMPULSE_THROW), 1, FLOOD_WATER_IMPULSE_RANGE)
		var/speed = min(range, FLOOD_WATER_IMPULSE_SPEED)
		victim.safe_throw_at(get_ranged_target_turf(victim, direction, range), range, speed, spin = FALSE, callback = CALLBACK(src, PROC_REF(start_water_drift), victim, direction, force), force = force, gentle = strength < FLOOD_WATER_IMPULSE_HURT)

/** Only confirmed local flow refreshes this short resistance; still water cannot keep it alive. */
/datum/status_effect/floodwater_current
	id = "floodwater_current"
	duration = FLOOD_WATER_CURRENT_DURATION
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null

/datum/status_effect/floodwater_current/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/floodwater_current)
	return TRUE

/datum/status_effect/floodwater_current/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/floodwater_current)

/** Additional walking resistance in a live jet, independent of the existing water-depth slowdown. */
/datum/movespeed_modifier/floodwater_current
	multiplicative_slowdown = 1
