/** Character-preference tab, using the same middleware contract as quirks and augmentations. */
/datum/preference_middleware/stationtrauma_training
	action_delegations = list(
		"select_expedition_profile" = PROC_REF(select_profile),
		"set_expedition_skill" = PROC_REF(set_level),
		"reset_expedition_profile" = PROC_REF(reset_profile),
	)
	/// UI selection only; each character slot independently stores allocations for every profession.
	var/selected_profile = "explorer"

/datum/preference_middleware/stationtrauma_training/get_ui_static_data(mob/user)
	var/list/profiles = list()
	for(var/profile_id in GLOB.stationtrauma_training_profiles)
		var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
		profiles += list(list("id" = profile_id, "name" = profile.name))
	return list("expedition_training_profiles" = profiles, "expedition_training_levels" = GLOB.stationtrauma_training_levels)

/datum/preference_middleware/stationtrauma_training/get_ui_data(mob/user)
	if(preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		return list()
	var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[selected_profile]
	var/list/saved = preferences.read_preference(/datum/preference/stationtrauma_training)
	var/list/levels = saved[selected_profile] || profile.starting_levels()
	var/list/skills = list()
	for(var/skill_id in GLOB.stationtrauma_training_skills)
		var/datum/stationtrauma_training_skill/skill = GLOB.stationtrauma_training_skills[skill_id]
		var/list/proposed = levels.Copy()
		proposed[skill_id]++
		var/increase_error = profile.allocation_error(proposed)
		proposed[skill_id] -= 2
		skills += list(list(
			"id" = skill_id, "name" = skill.name, "description" = skill.description, "level" = levels[skill_id],
			"increase_error" = increase_error, "decrease_error" = profile.allocation_error(proposed),
		))
	return list("expedition_training" = list(
		"enabled" = SSstationtrauma_training.enabled,
		"editable" = SSstationtrauma_training.can_edit(preferences.parent, user, preferences.default_slot, SSstationtrauma_training.revision),
		"revision" = SSstationtrauma_training.revision,
		"profile" = selected_profile,
		"points" = profile.points,
		"remaining" = profile.points - profile.spent_points(levels),
		"skills" = skills,
	))

/** Reject delayed requests from another slot, event revision or preferences owner. */
/datum/preference_middleware/stationtrauma_training/proc/context_valid(list/params, mob/user, editing = TRUE)
	if(!islist(params) || !user?.client || user.client != preferences.parent || user.client.prefs != preferences || params["slot"] != preferences.default_slot || params["revision"] != SSstationtrauma_training.revision)
		return FALSE
	return !editing || SSstationtrauma_training.can_edit(preferences.parent, user, preferences.default_slot, SSstationtrauma_training.revision)

/** Viewing another profession does not change the character's assigned job or live preparation. */
/datum/preference_middleware/stationtrauma_training/proc/select_profile(list/params, mob/user)
	if(!context_valid(params, user, FALSE))
		return FALSE
	var/profile_id = params["profile"]
	if(!istext(profile_id) || !(profile_id in GLOB.stationtrauma_training_profiles))
		return FALSE
	selected_profile = profile_id
	return TRUE

/** Validate the complete resulting allocation before changing any saved values. */
/datum/preference_middleware/stationtrauma_training/proc/set_level(list/params, mob/user)
	if(!context_valid(params, user))
		return FALSE
	var/profile_id = params["profile"]
	var/skill_id = params["skill"]
	if(!istext(profile_id) || !istext(skill_id) || !(profile_id in GLOB.stationtrauma_training_profiles) || !(skill_id in GLOB.stationtrauma_training_skills))
		return FALSE
	var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
	var/list/saved = preferences.read_preference(/datum/preference/stationtrauma_training)
	var/list/levels = saved[profile_id]
	levels = levels ? levels.Copy() : profile.starting_levels()
	if(params["from_level"] != levels[skill_id])
		return TRUE
	levels[skill_id] = params["level"]
	var/error = profile.allocation_error(levels)
	if(error)
		to_chat(user, span_warning(error))
		return TRUE
	return commit_profile(profile_id, levels)

/** Reset only the selected profession, keeping all other allocations in this character slot. */
/datum/preference_middleware/stationtrauma_training/proc/reset_profile(list/params, mob/user)
	if(!context_valid(params, user))
		return FALSE
	var/profile_id = params["profile"]
	if(!istext(profile_id) || !(profile_id in GLOB.stationtrauma_training_profiles))
		return FALSE
	var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
	return commit_profile(profile_id, profile.starting_levels())

/** Use the native preference cache and save-on-close lifecycle, like the other character tabs. */
/datum/preference_middleware/stationtrauma_training/proc/commit_profile(profile_id, list/levels)
	var/list/saved = preferences.read_preference(/datum/preference/stationtrauma_training)
	var/list/updated = saved.Copy()
	updated[profile_id] = levels
	return preferences.update_preference(GLOB.preference_entries[/datum/preference/stationtrauma_training], updated)
