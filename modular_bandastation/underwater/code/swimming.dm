/datum/movespeed_modifier/floodwater
	variable = TRUE

/// Occupants, rather than every ocean tile, process swimming and breathing.
/datum/status_effect/floodwater
	id = "floodwater"
	alert_type = null
	status_type = STATUS_EFFECT_UNIQUE
	tick_interval = 2 SECONDS
	/// Visual bobbing does not grant FLOATING, flight collision rules or zero-gravity motion.
	var/bobbing = FALSE
	/// A held vertical key cannot start overlapping strokes.
	var/vertical_swim_pending = FALSE

/datum/status_effect/floodwater/on_apply()
	RegisterSignals(owner, list(COMSIG_MOB_LOGIN, COMSIG_MOB_HUD_CREATED, COMSIG_MOB_HUD_REFRESHED, COMSIG_MOB_RESET_PERSPECTIVE, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM, SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF), SIGNAL_ADDTRAIT(TRAIT_SIGHT_BYPASS), SIGNAL_REMOVETRAIT(TRAIT_SIGHT_BYPASS)), PROC_REF(queue_presentation_refresh))
	RegisterSignal(owner, COMSIG_MOB_LOGOUT, PROC_REF(clear_presentation))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(update_water))
	RegisterSignal(owner, COMSIG_CARBON_PRE_BREATHE, PROC_REF(before_breath))
	RegisterSignal(owner, COMSIG_MOB_CLIENT_MOVED, PROC_REF(on_swim_step))
	RegisterSignal(owner, COMSIG_MOVABLE_HEAR, PROC_REF(muffle_water_speech))
	RegisterSignals(owner, list(COMSIG_LIVING_SET_BUCKLED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_MOB_STATCHANGE, COMSIG_MOVETYPE_FLAG_ENABLED, COMSIG_MOVETYPE_FLAG_DISABLED, SIGNAL_ADDTRAIT(TRAIT_NO_FLOATING_ANIM), SIGNAL_REMOVETRAIT(TRAIT_NO_FLOATING_ANIM)), PROC_REF(update_water))
	RegisterSignals(owner, list(COMSIG_LIVING_POST_UPDATE_TRANSFORM, COMSIG_LIVING_UPDATE_OFFSETS), PROC_REF(queue_bob_refresh))
	return TRUE

/datum/status_effect/floodwater/on_remove()
	update_submersion_sound(current_water())
	UnregisterSignal(owner, list(COMSIG_MOB_LOGIN, COMSIG_MOB_HUD_CREATED, COMSIG_MOB_HUD_REFRESHED, COMSIG_MOB_RESET_PERSPECTIVE, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM, COMSIG_MOB_LOGOUT, SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF), SIGNAL_ADDTRAIT(TRAIT_SIGHT_BYPASS), SIGNAL_REMOVETRAIT(TRAIT_SIGHT_BYPASS)))
	clear_presentation()
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_CARBON_PRE_BREATHE, COMSIG_MOB_CLIENT_MOVED, COMSIG_MOVABLE_HEAR, COMSIG_LIVING_SET_BUCKLED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_MOB_STATCHANGE, COMSIG_MOVETYPE_FLAG_ENABLED, COMSIG_MOVETYPE_FLAG_DISABLED, SIGNAL_ADDTRAIT(TRAIT_NO_FLOATING_ANIM), SIGNAL_REMOVETRAIT(TRAIT_NO_FLOATING_ANIM), COMSIG_LIVING_POST_UPDATE_TRANSFORM, COMSIG_LIVING_UPDATE_OFFSETS))
	var/datum/component/floodwater_swimming/motion = owner.GetComponent(/datum/component/floodwater_swimming)
	if(motion)
		qdel(motion)
	stop_bob()
	REMOVE_TRAIT(owner, TRAIT_SILENT_FOOTSTEPS, REF(src))
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/floodwater)
	owner.refresh_gravity()

/datum/status_effect/floodwater/proc/current_water()
	if(!isopenturf(owner.loc))
		return null
	return owner.loc.GetComponent(/datum/component/floodwater)

/datum/status_effect/floodwater/proc/update_water()
	SIGNAL_HANDLER
	var/datum/component/floodwater/water = current_water()
	if(!water)
		qdel(src)
		return
	update_slowdown(water)
	update_bob(water)
	update_presentation(water)

/datum/status_effect/floodwater/proc/update_slowdown(datum/component/floodwater/water)
	if(water.get_depth() >= FLOOD_WATER_DEEP && water.affects(owner))
		ADD_TRAIT(owner, TRAIT_SILENT_FOOTSTEPS, REF(src))
	else
		REMOVE_TRAIT(owner, TRAIT_SILENT_FOOTSTEPS, REF(src))
	var/slowdown = 0
	if(water.affects(owner) && !HAS_TRAIT(owner, TRAIT_SWIMMER))
		slowdown = min(FLOOD_WATER_SWIM_SLOWDOWN, water.get_stage() * 0.15)
		if(owner.can_stationtrauma_swim(water))
			var/datum/component/floodwater_swimming/motion = owner.GetComponent(/datum/component/floodwater_swimming)
			var/progress = QDELETED(motion) ? 0 : max(0, motion.strokes - 1) / (FLOOD_WATER_SWIM_STROKES - 1)
			slowdown = FLOOD_WATER_SWIM_SLOWDOWN - (FLOOD_WATER_SWIM_SLOWDOWN - FLOOD_WATER_SWIM_CRUISE_SLOWDOWN) * progress
	var/datum/movespeed_modifier/modifier = owner.has_movespeed_modifier(/datum/movespeed_modifier/floodwater)
	if(!modifier || modifier.multiplicative_slowdown != slowdown)
		owner.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/floodwater, multiplicative_slowdown = slowdown)

/** Charge only actual player strokes, never standing, throws, pulling or residual coasting. */
/datum/status_effect/floodwater/proc/on_swim_step(mob/living/source, direction, old_direction, atom/old_loc)
	SIGNAL_HANDLER
	var/datum/component/floodwater/water = current_water()
	if(!owner.can_stationtrauma_swim(water) || !isturf(old_loc) || old_loc.z != owner.z || get_dist(old_loc, owner.loc) != 1)
		return
	var/datum/component/floodwater_swimming/motion = owner.GetComponent(/datum/component/floodwater_swimming)
	if(!motion)
		motion = owner.AddComponent(/datum/component/floodwater_swimming)
	motion?.stroke(get_dir(old_loc, owner.loc))
	show_swim_bubbles(old_loc, get_dir(old_loc, owner.loc))
	if(!HAS_TRAIT(owner, TRAIT_SWIMMER))
		var/skill = owner.mind?.get_skill_level(/datum/skill/athletics) || 0
		var/cost = max(0.15, 0.5 - skill * 0.05)
		owner.apply_damage(HAS_TRAIT(owner, TRAIT_STRENGTH) ? cost / 2 : cost, STAMINA)
	update_water()

/** Reuse the native two-pixel visual only; changing movetype would also change collisions and gravity. */
/datum/status_effect/floodwater/proc/update_bob(datum/component/floodwater/water)
	var/datum/component/floodwater_swimming/motion = owner.GetComponent(/datum/component/floodwater_swimming)
	var/active = owner.can_stationtrauma_swim(water) && !HAS_TRAIT(owner, TRAIT_NO_FLOATING_ANIM) && (!QDELETED(motion) || !owner.stationtrauma_swim_grip())
	if(active == bobbing)
		return
	if(active)
		bobbing = TRUE
		DO_FLOATING_ANIM(owner)
	else
		stop_bob()

/** Never stop a native flight animation that has taken over our former swimming bob. */
/datum/status_effect/floodwater/proc/stop_bob()
	if(!bobbing)
		return
	bobbing = FALSE
	if(!QDELETED(owner) && !(owner.movement_type & (FLOATING|FLYING)))
		STOP_FLOATING_ANIM(owner)

/** Native stance/offset animations must finish before restoring the swimming bob. */
/datum/status_effect/floodwater/proc/queue_bob_refresh()
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(refresh_bob)), 0.3 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)

/datum/status_effect/floodwater/proc/refresh_bob()
	stop_bob()
	update_water()

/// Keep the normal lungs/species/tank checks, including empty tanks and invalid masks.
/datum/status_effect/floodwater/proc/before_breath(mob/living/carbon/swimmer)
	SIGNAL_HANDLER
	var/datum/component/floodwater/water = current_water()
	if(!water?.head_underwater(swimmer) || HAS_TRAIT(swimmer, TRAIT_NODROWN) || HAS_TRAIT(swimmer, TRAIT_NOBREATH))
		return
	if(swimmer.invalid_internals())
		swimmer.cutoff_internals()
	if(!swimmer.internal && !swimmer.external)
		// The standard breathe() now checks an empty breath instead of inhaling the room's air.
		swimmer.losebreath = max(swimmer.losebreath, 1)

/datum/status_effect/floodwater/tick(seconds_between_ticks)
	var/datum/component/floodwater/water = current_water()
	if(!water)
		qdel(src)
		return
	update_slowdown(water)
	update_bob(water)
	update_presentation(water)
	if(owner.stat == DEAD || !water.affects(owner))
		return
	if(isbasicmob(owner) && water.head_underwater(owner) && !HAS_TRAIT(owner, TRAIT_NODROWN) && !HAS_TRAIT(owner, TRAIT_NOBREATH))
		var/mob/living/basic/swimmer = owner
		if(swimmer.unsuitable_atmos_damage)
			swimmer.adjust_oxy_loss(2 * seconds_between_ticks)
