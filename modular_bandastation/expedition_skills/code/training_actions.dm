/** Return preparation for a known discipline; only opted-in equipment uses this API. */
/proc/stationtrauma_training_level(mob/living/user, skill_id)
	if(!istext(skill_id) || !(skill_id in GLOB.stationtrauma_training_skills))
		return null
	var/datum/component/stationtrauma_training/training = user?.mind?.GetComponent(/datum/component/stationtrauma_training)
	return training?.get_level(skill_id) || ST_TRAINING_UNSKILLED

/** Deny an opted-in action with a specific, readable preparation requirement. */
/proc/stationtrauma_check_training(mob/living/user, skill_id, required_level)
	var/level = stationtrauma_training_level(user, skill_id)
	if(isnull(level))
		return FALSE
	if(!SSstationtrauma_training.enabled || level >= required_level)
		return TRUE
	var/datum/stationtrauma_training_skill/skill = GLOB.stationtrauma_training_skills[skill_id]
	to_chat(user, span_warning("Требуется навык: [skill.name] — [GLOB.stationtrauma_training_levels[required_level]]."))
	return FALSE

/** Starting balance: experienced/master operators finish opted-in work 15/30% faster. */
/proc/stationtrauma_training_delay(mob/living/user, skill_id, base_delay)
	if(!SSstationtrauma_training.enabled)
		return base_delay
	switch(stationtrauma_training_level(user, skill_id))
		if(ST_TRAINING_EXPERIENCED)
			return base_delay * 0.85
		if(ST_TRAINING_MASTER)
			return base_delay * 0.7
	return base_delay
