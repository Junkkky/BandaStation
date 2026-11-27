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

#define MAX_PORTRAIT_IMAGE_URL_LENGTH 400

/// Ordered external portrait URLs associated with one character slot.
/datum/preference/character_portrait_urls
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "character_portrait_urls"
	can_randomize = FALSE
	should_update_preview = FALSE
	/// Maximum number of editable portrait rows.
	var/maximum_entries = 3

/datum/preference/character_portrait_urls/create_default_value()
	return list()

/datum/preference/character_portrait_urls/deserialize(input, datum/preferences/preferences)
	if(!is_valid(input, preferences))
		return null
	var/list/portrait_urls = list()
	for(var/portrait_url in input)
		portrait_urls += portrait_url
	return portrait_urls

/datum/preference/character_portrait_urls/serialize(list/input)
	return input.Copy()

/datum/preference/character_portrait_urls/is_valid(value, datum/preferences/preferences)
	if(!islist(value) || length(value) > maximum_entries)
		return FALSE
	for(var/portrait_url in value)
		if(!istext(portrait_url) || (length(portrait_url) && !is_valid_portrait_image_url(portrait_url)) || !isnull(value[portrait_url]))
			return FALSE
	return TRUE

/// True for direct HTTPS PNG/JPEG links permitted for character portraits and book illustrations.
/proc/is_valid_portrait_image_url(value)
	if(!istext(value) || !length(value) || length(value) > MAX_PORTRAIT_IMAGE_URL_LENGTH)
		return FALSE
	var/static/regex/allowed_url = regex(@"^https://(?:i\.gyazo\.com|[a-z0-9]\.l3n\.co|(?:images|thumbs)[0-9]+\.imgbox\.com|files\.catbox\.moe|file\.garden)/[a-z0-9._~%/-]+\.(?:png|jpe?g)(?:\?[a-z0-9._~%&=+/-]+)?$", "i")
	return allowed_url.Find(value) && allowed_url.match == value

/datum/preference/character_portrait_urls/apply_to_human(mob/living/carbon/human/target, list/value, datum/preferences/preferences)
	target.dna.features[savefile_key] = value.Copy()

/datum/preference/character_portrait_urls/compile_constant_data()
	return list("maximum_entries" = maximum_entries, "maximum_length" = MAX_PORTRAIT_IMAGE_URL_LENGTH)

#undef MAX_PORTRAIT_IMAGE_URL_LENGTH

/// Controls portrait previews in the examine message for this viewer.
/datum/preference/toggle/show_character_portraits_in_chat
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "show_character_portraits_in_chat"
