/** Per-character profession allocations; kept separate from TG's experience skills. */
/datum/preference/stationtrauma_training
	savefile_key = "stationtrauma_training"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	can_randomize = FALSE
	should_update_preview = FALSE

/datum/preference/stationtrauma_training/create_default_value()
	return list()

/datum/preference/stationtrauma_training/deserialize(input, datum/preferences/preferences)
	var/list/result = list()
	if(!islist(input))
		return result
	for(var/profile_id in input)
		if(!istext(profile_id))
			continue
		var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
		if(profile && !profile.allocation_error(input[profile_id]))
			var/list/levels = input[profile_id]
			result[profile_id] = levels.Copy()
	return result

/datum/preference/stationtrauma_training/is_valid(value, datum/preferences/preferences)
	if(!islist(value))
		return FALSE
	for(var/profile_id in value)
		if(!istext(profile_id))
			return FALSE
		var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
		if(!profile || profile.allocation_error(value[profile_id]))
			return FALSE
	return TRUE

/datum/preference/stationtrauma_training/is_accessible(datum/preferences/preferences)
	return ..() && SSstationtrauma_training.can_edit(preferences.parent, preferences.parent?.mob, preferences.default_slot, SSstationtrauma_training.revision)

// The separate lobby editor must also work while the main preferences window is on another tab.
/datum/preference/stationtrauma_training/should_show_on_page(preference_tab)
	return TRUE

/// Snapshot the actual spawning slot before job preferences switch or the player changes bodies.
/mob/living/carbon/human/var/list/stationtrauma_pending_training

/datum/preference/stationtrauma_training/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(!SSstationtrauma_training.enabled || !isnewplayer(preferences?.parent?.mob))
		return
	var/mob/dead/new_player/player = preferences.parent.mob
	if(player.spawning)
		target.stationtrauma_pending_training = deserialize(value, preferences)
