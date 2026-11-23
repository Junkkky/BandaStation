/datum/status_effect/grouped/heretic_dreams
	id = "heretic_dreams"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Cooldown between allowed dreams
	COOLDOWN_DECLARE(dreaming_cooldown)
	/// The influence currently used as the dreamer's camera.
	var/obj/effect/heretic_influence/dream_rift
	/// The temporary rift image when its normal HUD image is out of range.
	var/image/dream_rift_image
	/// Signals that immediately end the remote view.
	var/static/list/end_vision_signals = list(
		COMSIG_END_DREAMING,
		COMSIG_MOB_LOGOUT,
		SIGNAL_REMOVETRAIT(TRAIT_KNOCKEDOUT),
	)

/datum/status_effect/grouped/heretic_dreams/on_apply()
	. = ..()
	RegisterSignal(owner, COMSIG_PRE_DREAMING, PROC_REF(add_heretic_dream))
	RegisterSignal(owner, COMSIG_START_DREAMING, PROC_REF(start_heretic_dream))

/datum/status_effect/grouped/heretic_dreams/on_remove()
	. = ..()
	UnregisterSignal(owner, list(COMSIG_PRE_DREAMING, COMSIG_START_DREAMING))
	end_heretic_vision()

/datum/status_effect/grouped/heretic_dreams/source_removed(source, removing)
	if(ispath(source, /datum/antagonist/heretic))
		end_heretic_vision()

/datum/status_effect/grouped/heretic_dreams/proc/add_heretic_dream(mob/living/dreamer, list/dream_pool)
	SIGNAL_HANDLER

	if(!COOLDOWN_FINISHED(src, dreaming_cooldown))
		return

	var/atom/dream_center = get_dream_center(dreamer)
	if(isnull(dream_center))
		return

	dream_pool[new /datum/dream/heretic(dream_center)] = 200

/datum/status_effect/grouped/heretic_dreams/proc/start_heretic_dream(mob/living/dreamer, datum/dream/heretic/current_dream)
	SIGNAL_HANDLER

	if(!istype(current_dream))
		return
	COOLDOWN_START(src, dreaming_cooldown, /datum/mood_event/mansus_dream_fatigue::timeout)
	dreamer.add_mood_event("mansus_dream_fatigue", /datum/mood_event/mansus_dream_fatigue)

	var/obj/effect/heretic_influence/rift = current_dream.dream_center
	if(!GET_HERETIC(dreamer) || !istype(rift) || QDELETED(rift) || !get_turf(rift))
		return
	if(!dreamer.client || !dreamer.IsSleeping() || !IS_UNCONSCIOUS(dreamer) || dreamer.stat >= HARD_CRIT)
		return
	if(dreamer.client.eye != dreamer && dreamer.client.eye != dreamer.loc)
		return

	dreamer.reset_perspective(rift)
	if(dreamer.client?.eye != rift)
		return
	dream_rift = rift

	// Alternate appearance HUDs use the body's z-level, so the distant rift may need its own image.
	var/image/hud_image = rift.active_hud_list?["reality_smash"]
	if(hud_image && !(hud_image in dreamer.client.images))
		dream_rift_image = image(hud_image.appearance, rift)
		dreamer.client.images += dream_rift_image

	RegisterSignal(rift, COMSIG_QDELETING, PROC_REF(end_heretic_vision))
	RegisterSignals(dreamer, end_vision_signals, PROC_REF(end_heretic_vision))
	RegisterSignal(dreamer, COMSIG_MOB_STATCHANGE, PROC_REF(check_vision_stat))
	RegisterSignal(dreamer, COMSIG_LIVING_STATUS_REMOVED, PROC_REF(check_vision_sleep))
	RegisterSignal(dreamer, COMSIG_MOB_CLICKON, PROC_REF(block_vision_click))

/// Hard critical condition and death interrupt the dream even if the owner stays unconscious.
/datum/status_effect/grouped/heretic_dreams/proc/check_vision_stat(mob/living/dreamer, new_stat)
	SIGNAL_HANDLER

	if(new_stat >= HARD_CRIT)
		end_heretic_vision()

/// Sleep can end while another effect still keeps the owner unconscious.
/datum/status_effect/grouped/heretic_dreams/proc/check_vision_sleep(mob/living/dreamer, datum/status_effect/incapacitating/sleeping/sleep_status)
	SIGNAL_HANDLER

	if(istype(sleep_status))
		end_heretic_vision()

/// Keep the remote view read-only.
/datum/status_effect/grouped/heretic_dreams/proc/block_vision_click(mob/living/dreamer)
	SIGNAL_HANDLER

	if(dreamer.client?.eye == dream_rift)
		return COMSIG_MOB_CANCEL_CLICKON

/// Release the dream camera without replacing a perspective already set by another effect.
/datum/status_effect/grouped/heretic_dreams/proc/end_heretic_vision()
	SIGNAL_HANDLER

	if(!dream_rift)
		return
	var/obj/effect/heretic_influence/rift = dream_rift
	dream_rift = null
	UnregisterSignal(rift, COMSIG_QDELETING)
	UnregisterSignal(owner, end_vision_signals + list(COMSIG_MOB_STATCHANGE, COMSIG_LIVING_STATUS_REMOVED, COMSIG_MOB_CLICKON))
	if(dream_rift_image)
		owner.canon_client?.images -= dream_rift_image
		QDEL_NULL(dream_rift_image)
	if(owner.client?.eye == rift && !QDELETED(owner))
		owner.reset_perspective()

/datum/status_effect/grouped/heretic_dreams/proc/get_dream_center(mob/living/dreamer)
	// Select a random influence as the center of the dream
	if(length(GLOB.reality_smash_track.smashes))
		return pick(GLOB.reality_smash_track.smashes)

	// If there are no influences, either don't trigger the dream (if we are a heretic) or pick a completely random locale (if we aren't)
	if(IS_HERETIC(dreamer))
		return null

	return get_safe_random_station_turf_equal_weight()

/// Heretics can see dreams about random machinery from the perspective of a random unused influence
/datum/dream/heretic
	sleep_until_finished = TRUE
	/// The location of the influence (or lack thereof in the case of a fake dream) we will be dreaming about
	var/atom/dream_center
	/// The distance to the objects visible from the influence during the dream
	var/dream_view_range = 5
	var/list/what_you_can_see = list(
		/obj/item,
		/obj/structure,
		/obj/machinery,
	)
	var/static/list/what_you_cant_see = typecacheof(list(
		// Underfloor stuff and default wallmounts
		/obj/item/radio/intercom,
		/obj/structure/cable,
		/obj/structure/disposalpipe/segment,
		/obj/machinery/atmospherics/pipe/smart/manifold4w,
		/obj/machinery/atmospherics/components/unary/vent_scrubber,
		/obj/machinery/atmospherics/components/unary/vent_pump,
		/obj/machinery/duct,
		/obj/machinery/navbeacon,
		/obj/machinery/power/terminal,
		/obj/machinery/power/apc,
		/obj/machinery/light_switch,
		/obj/machinery/light,
		/obj/machinery/camera,
		/obj/machinery/door/firedoor,
		/obj/machinery/firealarm,
		/obj/machinery/airalarm,
		/obj/structure/window/fulltile,
		/obj/structure/window/reinforced/fulltile,
	))
	/// Cached list of allowed typecaches for each type in what_you_can_see
	var/static/list/allowed_typecaches_by_root_type = null

/datum/dream/heretic/New(atom/dream_center)
	src.dream_center = dream_center

/datum/dream/heretic/GenerateDream(mob/living/carbon/dreamer)
	. = list()
	. += "you wander through the forest of Mansus"
	. += "there is a " + pick("pond", "well", "lake", "puddle", "stream", "spring", "brook", "marsh")

	if(isnull(allowed_typecaches_by_root_type))
		allowed_typecaches_by_root_type = list()
		for(var/type in what_you_can_see)
			allowed_typecaches_by_root_type[type] = typecacheof(type) - what_you_cant_see

	var/list/all_objects = oview(dream_view_range, dream_center)
	var/something_found = FALSE
	for(var/object_type in allowed_typecaches_by_root_type)
		var/list/filtered_objects = typecache_filter_list(all_objects, allowed_typecaches_by_root_type[object_type])
		if(filtered_objects.len)
			if (!something_found)
				. += "its waters reflect"
				something_found = TRUE
			var/obj/found_object = pick(filtered_objects)
			. += initial(found_object.name)
	if(!something_found)
		. += pick("it's pitch black", "ihe reflections are vague", "you stroll aimlessly")
	else
		. += "the images fade in the ripples"
	. += "you feel exhausted"

/datum/mood_event/mansus_dream_fatigue
	description = "I must recover before I can dream of Mansus again."
	mood_change = -2
	timeout = 5 MINUTES
