/**
 * # Alert for [/datum/status_effect/direction_lock]
 *
 * Displays the active direction-lock state and cancels it when clicked.
 */
/atom/movable/screen/alert/status_effect/direction_lock
	name = "Фиксация взгляда"
	desc = "Ваш взгляд зафиксирован, из-за чего вы двигаетесь медленнее. Нажмите сюда, чтобы отменить."
	use_user_hud_icon = USER_HUD_STYLE_INHERIT
	overlay_state = "direction_lock"
	clickable_glow = TRUE

/atom/movable/screen/alert/status_effect/direction_lock/Click(location, control, params)
	. = ..()
	if(!.)
		return

	var/datum/status_effect/direction_lock/lock_effect = attached_effect
	if(istype(lock_effect) && !QDELETED(lock_effect))
		lock_effect.cancel_lock("фиксация взгляда снята")
	return TRUE

/**
 * # Direction Lock Status Effect
 *
 * Locks a living mob's facing direction to either a fixed cardinal direction
 * or continuously toward a tracked living mob while applying a movement slowdown.
 */
/datum/status_effect/direction_lock
	id = ALERT_DIRECTION_LOCK
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_AUTO_TICK
	processing_speed = STATUS_EFFECT_NORMAL_PROCESS
	status_type = STATUS_EFFECT_UNIQUE
	on_remove_on_mob_delete = TRUE
	remove_on_fullheal = TRUE
	alert_type = /atom/movable/screen/alert/status_effect/direction_lock
	/// Cardinal direction the owner is forced to face.
	var/locked_dir = NONE
	/// Weakref to the living mob being tracked, if tracking a target instead of a static direction.
	var/datum/weakref/target_ref
	/// Guard flag allowing only this status effect to change owner.dir.
	var/updating_dir = FALSE

/datum/status_effect/direction_lock/on_creation(mob/living/new_owner, initial_dir = NONE, mob/living/track_target = null)
	. = ..()
	if(!.)
		return
	update_alert_desc()

/datum/status_effect/direction_lock/on_apply(initial_dir = NONE, mob/living/track_target = null)
	if(!owner.can_use_direction_lock())
		return FALSE

	if(track_target)
		if(!istype(track_target) || track_target == owner || !can_see_target(track_target))
			return FALSE
		target_ref = WEAKREF(track_target)
		RegisterSignal(track_target, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_moved))
		RegisterSignal(track_target, COMSIG_QDELETING, PROC_REF(on_target_deleted))
		var/target_dir = owner.get_cardinal_dir_to(track_target)
		if(target_dir in GLOB.cardinals)
			locked_dir = target_dir
		else if(owner.dir in GLOB.cardinals)
			locked_dir = owner.dir
		else
			locked_dir = SOUTH
	else
		if(!(initial_dir in GLOB.cardinals))
			return FALSE
		locked_dir = initial_dir
		// Static direction lock needs no periodic visibility polling.
		tick_interval = STATUS_EFFECT_NO_TICK

	RegisterSignal(owner, COMSIG_ATOM_PRE_DIR_CHANGE, PROC_REF(on_pre_dir_change))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))
	RegisterSignal(owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_owner_statchange))
	RegisterSignal(owner, SIGNAL_ADDTRAIT(TRAIT_KNOCKEDOUT), PROC_REF(on_owner_knocked_out))
	RegisterSignal(owner, COMSIG_LIVING_SET_BUCKLED, PROC_REF(on_owner_buckled))

	owner.add_movespeed_modifier(/datum/movespeed_modifier/status_effect/direction_lock)
	set_owner_dir(locked_dir)
	return TRUE

/datum/status_effect/direction_lock/on_remove()
	clear_target()
	if(owner)
		UnregisterSignal(owner, list(
			COMSIG_ATOM_PRE_DIR_CHANGE,
			COMSIG_MOVABLE_MOVED,
			COMSIG_MOB_STATCHANGE,
			SIGNAL_ADDTRAIT(TRAIT_KNOCKEDOUT),
			COMSIG_LIVING_SET_BUCKLED,
		))
		owner.remove_movespeed_modifier(/datum/movespeed_modifier/status_effect/direction_lock)

/datum/status_effect/direction_lock/tick(seconds_between_ticks)
	if(!target_ref)
		stop_ticking()
		return
	update_tracked_direction()

/**
 * Cancels the direction lock with an optional balloon alert for the owner.
 *
 * Arguments:
 * * feedback - Optional lowercase balloon alert text shown if the owner is conscious.
 */
/datum/status_effect/direction_lock/proc/cancel_lock(feedback = null)
	if(QDELETED(src))
		return
	if(feedback && !QDELETED(owner) && !IS_UNCONSCIOUS_OR_CRIT(owner))
		owner.balloon_alert(owner, feedback)
	qdel(src)

/**
 * Restores owner.dir to the current locked direction if BYOND step() overrode it.
 */
/datum/status_effect/direction_lock/proc/restore_locked_dir()
	if(QDELETED(src) || QDELETED(owner))
		return
	set_owner_dir(locked_dir)

/// Updates owner.dir through setDir while temporarily bypassing our own dir-change block.
/datum/status_effect/direction_lock/proc/set_owner_dir(new_dir)
	if(!(new_dir in GLOB.cardinals) || QDELETED(owner))
		return
	locked_dir = new_dir
	if(owner.dir == new_dir)
		return
	updating_dir = TRUE
	owner.setDir(new_dir)
	updating_dir = FALSE

/// Updates alert tooltip text to reflect either fixed direction or tracked target.
/datum/status_effect/direction_lock/proc/update_alert_desc()
	if(!linked_alert)
		return
	var/mob/living/target = target_ref?.resolve()
	if(target)
		linked_alert.desc = "Вы следите взглядом за [target.name], из-за чего двигаетесь медленнее. Нажмите сюда, чтобы отменить."
		return
	linked_alert.desc = "Ваш взгляд зафиксирован ([dir_to_ru_name(locked_dir)]), из-за чего вы двигаетесь медленнее. Нажмите сюда, чтобы отменить."

/// Clears target weakref and unregisters target tracking signals.
/datum/status_effect/direction_lock/proc/clear_target()
	var/mob/living/target = target_ref?.resolve()
	if(target)
		UnregisterSignal(target, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	target_ref = null

/// Checks whether the tracked target is still on an open turf in the owner's field of view.
/datum/status_effect/direction_lock/proc/can_see_target(mob/living/target)
	if(QDELETED(target) || QDELETED(owner))
		return FALSE
	if(!isturf(target.loc) || target.z != owner.z)
		return FALSE
	var/view_range = owner.client?.view || world.view
	var/list/view_size = getviewsize(view_range)
	if(abs(target.x - owner.x) * 2 > view_size[1] || abs(target.y - owner.y) * 2 > view_size[2])
		return FALSE
	// Typed mob iteration avoids collecting turfs and /obj lists from view().
	for(var/mob/living/seen in view(view_range, owner))
		if(seen == target)
			return TRUE
	return FALSE

/// Recomputes facing toward the tracked target or cancels if visibility is lost.
/datum/status_effect/direction_lock/proc/update_tracked_direction()
	if(QDELETED(src) || QDELETED(owner))
		return
	var/mob/living/target = target_ref?.resolve()
	if(!can_see_target(target))
		cancel_lock("цель потеряна из виду")
		return
	var/new_dir = owner.get_cardinal_dir_to(target)
	if(new_dir in GLOB.cardinals)
		set_owner_dir(new_dir)
	else
		set_owner_dir(locked_dir)

/datum/status_effect/direction_lock/proc/on_pre_dir_change(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(updating_dir)
		return
	return COMPONENT_ATOM_BLOCK_DIR_CHANGE

/datum/status_effect/direction_lock/proc/on_owner_moved(datum/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	if(!isturf(owner.loc))
		cancel_lock("фиксация взгляда снята")
		return
	if(target_ref)
		update_tracked_direction()
		return
	restore_locked_dir()

/datum/status_effect/direction_lock/proc/on_owner_statchange(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat >= SOFT_CRIT)
		cancel_lock()

/datum/status_effect/direction_lock/proc/on_owner_knocked_out(datum/source)
	SIGNAL_HANDLER
	cancel_lock()

/datum/status_effect/direction_lock/proc/on_owner_buckled(datum/source, atom/movable/new_buckled)
	SIGNAL_HANDLER
	if(new_buckled)
		cancel_lock("фиксация взгляда снята")

/datum/status_effect/direction_lock/proc/on_target_moved(datum/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	update_tracked_direction()

/datum/status_effect/direction_lock/proc/on_target_deleted(datum/source)
	SIGNAL_HANDLER
	cancel_lock("цель потеряна из виду")

/// Returns whether this living mob meets the state prerequisites to lock its facing direction.
/mob/living/proc/can_use_direction_lock()
	if(IS_UNCONSCIOUS_OR_CRIT(src))
		return FALSE
	if(!isturf(loc) || buckled)
		return FALSE
	if(!(mobility_flags & MOBILITY_MOVE))
		return FALSE
	return TRUE

/// Returns a deterministic cardinal direction from src toward target, or NONE when centered on the same tile.
/mob/proc/get_cardinal_dir_to(atom/target)
	if(!target || !x || !y || !target.x || !target.y || target.z != z)
		return NONE
	var/dx = target.x - x
	var/dy = target.y - y
	if(!dx && !dy)
		if(target.pixel_y > 16)
			return NORTH
		if(target.pixel_y < -16)
			return SOUTH
		if(target.pixel_x > 16)
			return EAST
		if(target.pixel_x < -16)
			return WEST
		return NONE
	if(abs(dx) < abs(dy))
		return dy > 0 ? NORTH : SOUTH
	return dx > 0 ? EAST : WEST

/// Returns a lowercase Russian label for a cardinal direction.
/proc/dir_to_ru_name(direction)
	switch(direction)
		if(NORTH)
			return "север"
		if(SOUTH)
			return "юг"
		if(EAST)
			return "восток"
		if(WEST)
			return "запад"
	return "вперёд"
