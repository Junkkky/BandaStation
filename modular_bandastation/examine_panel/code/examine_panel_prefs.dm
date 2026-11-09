/datum/preference/text/flavor_text
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "flavor_text"
	maximum_value_length = MAX_FLAVOR_LEN

/datum/preference/text/flavor_text/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features["flavor_text"] = value

/datum/preference/text/silicon_flavor_text
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "silicon_flavor_text"
	maximum_value_length = MAX_FLAVOR_LEN
	// This does not get a apply_to_human proc, this is read directly in silicon/robot/examine.dm

/datum/preference/text/silicon_flavor_text/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE // To prevent the not-implemented runtime

/// Optional external portrait associated with one character slot.
/datum/preference/text/character_portrait_url
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "character_portrait_url"
	maximum_value_length = 400
	can_randomize = FALSE
	should_update_preview = FALSE

/datum/preference/text/character_portrait_url/deserialize(input, datum/preferences/preferences)
	return is_valid(input, preferences) ? input : null

/datum/preference/text/character_portrait_url/is_valid(value, datum/preferences/preferences)
	if(!istext(value) || length(value) > maximum_value_length)
		return FALSE
	if(value == "")
		return TRUE
	var/static/regex/allowed_url = regex(@"^https://(?:i\.gyazo\.com|[a-z0-9]\.l3n\.co|(?:images|thumbs)[0-9]+\.imgbox\.com|files\.catbox\.moe|file\.garden)/[a-z0-9._~%/-]+\.(?:png|jpe?g)(?:\?[a-z0-9._~%&=+/-]+)?$", "i")
	return allowed_url.Find(value) && allowed_url.match == value

/datum/preference/text/character_portrait_url/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[savefile_key] = value

/datum/preference/text/character_portrait_url/second
	savefile_key = "character_portrait_url_2"

/datum/preference/text/character_portrait_url/third
	savefile_key = "character_portrait_url_3"

/// Controls portrait previews in the examine message for this viewer.
/datum/preference/toggle/show_character_portraits_in_chat
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "show_character_portraits_in_chat"
