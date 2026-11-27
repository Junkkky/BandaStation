/**
 * Ctrl click
 */
/mob/proc/CtrlClickOn(atom/A)
	base_click_ctrl(A)

/**
 * ### Base proc for ctrl click interaction left click.
 *
 * If you wish to add custom `click_ctrl` behavior for a single type, use that proc.
 */
/mob/proc/base_click_ctrl(atom/target)
	SHOULD_NOT_OVERRIDE(TRUE)

	// Check if they've hooked in to prevent src from ctrl clicking anything
	if(SEND_SIGNAL(src, COMSIG_MOB_CTRL_CLICKED, target) & COMSIG_MOB_CANCEL_CLICKON)
		return TRUE

	// If it has a signal handler that returns a click action, done.
	if(SEND_SIGNAL(target, COMSIG_CLICK_CTRL, src) & CLICK_ACTION_ANY)
		return TRUE

	// If it has a custom click_alt that returns success/block, done.
	if(can_perform_action(target, target.interaction_flags_click | SILENT_ADJACENCY))
		return target.click_ctrl(src) & CLICK_ACTION_ANY

	return FALSE

/**
 * Ctrl click
 * For most objects, pull
 */
/mob/living/base_click_ctrl(atom/target)
	SHOULD_NOT_OVERRIDE(TRUE)

	. = ..()
	if(. || !ismovable(target) || world.time < next_move || !can_perform_action(target, NOT_INSIDE_TARGET | SILENT_ADJACENCY | ALLOW_RESTING | FORBID_TELEKINESIS_REACH))
		return

	. = TRUE
	if(grab(target) != GRAB_SKIP)
		changeNext_move(CLICK_CD_MELEE)
		return
	pulled(target)

/**
 * Ctrl mouse wheel click
 * Except for tagging datumns same as control click
 */
/mob/proc/CtrlMiddleClickOn(atom/A)
	if(check_rights_for(client, R_ADMIN))
		client.toggle_tag_datum(A)
		return
	CtrlClickOn(A)

/**
 * ## Custom ctrl click interaction
 * Override this to change default ctrl click behavior. Return `CLICK_ACTION_SUCCESS`, `CLICK_ACTION_BLOCKING` or `NONE`.
 *
 * ### Guard clauses
 * Consider adding `interaction_flags_click` before adding unique guard clauses.
 *
 * ### Return flags
 * Forgetting your return will cause the default ctrl click behavior to occur thereafter.
 *
 * Returning any value besides NONE will stop the attack chain and thus stop the object from getting pulled/grabbed
 **/
/atom/proc/click_ctrl(mob/user)
	SHOULD_CALL_PARENT(FALSE)
	return NONE


/**
 * Control+Shift click
 * Unused except for AI
 */
/mob/proc/CtrlShiftClickOn(atom/A)
	base_click_ctrl_shift(A)

/**
 * ### Base proc for ctrl shift click interaction left click.
 *
 * If you wish to add custom `click_ctrl_shift` behavior for a single type, use that proc.
 */
/mob/proc/base_click_ctrl_shift(atom/target)
	SHOULD_NOT_OVERRIDE(TRUE)

	// Check if they've hooked in to prevent src from ctrl clicking anything
	if(SEND_SIGNAL(src, COMSIG_MOB_CTRL_SHIFT_CLICKED, target) & COMSIG_MOB_CANCEL_CLICKON)
		return

	// If it has a signal handler that returns a click action, done.
	if(SEND_SIGNAL(target, COMSIG_CLICK_CTRL_SHIFT, src) & CLICK_ACTION_ANY)
		return

	// Proceed with ctrl shift click
	if(can_perform_action(target, target.interaction_flags_click | SILENT_ADJACENCY))
		target.click_ctrl_shift(src)

/**
 * ## Custom ctrl shift click interaction
 *
 * ### Guard clauses
 * Consider adding `interaction_flags_click` before adding unique guard clauses.
 **/
/atom/proc/click_ctrl_shift(mob/user)
	SHOULD_CALL_PARENT(FALSE)
	return NONE

/**
 * Control+Alt left click
 *
 * Toggles direction lock or target-facing mode for living mobs.
 */
/mob/proc/ctrl_alt_click_on(atom/target)
	return

/mob/living/ctrl_alt_click_on(atom/target)
	var/datum/status_effect/direction_lock/existing_lock = has_status_effect(/datum/status_effect/direction_lock)
	if(existing_lock)
		existing_lock.cancel_lock("фиксация взгляда снята")
		return

	if(!target || target == src || !can_use_direction_lock())
		return

	if(isliving(target))
		var/mob/living/living_target = target
		var/datum/status_effect/direction_lock/applied = apply_status_effect(/datum/status_effect/direction_lock, NONE, living_target)
		if(applied)
			balloon_alert(src, "слежение: [living_target.name]")
		return

	if(target in get_all_contents())
		return

	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf.z != z)
		return

	var/cardinal_dir = get_cardinal_dir_to(target)
	if(!(cardinal_dir in GLOB.cardinals))
		return

	var/datum/status_effect/direction_lock/applied = apply_status_effect(/datum/status_effect/direction_lock, cardinal_dir)
	if(applied)
		balloon_alert(src, "взгляд: [dir_to_ru_name(cardinal_dir)]")
