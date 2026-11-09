/datum/unit_test/character_portrait_url/Run()
	var/datum/preference/text/character_portrait_url/preference = GLOB.preference_entries[/datum/preference/text/character_portrait_url]
	var/list/slot_data = list()
	var/url = "https://i.gyazo.com/portrait.PNG"
	TEST_ASSERT(preference.write(slot_data, url), "A direct image URL on a permitted host must be saved")
	TEST_ASSERT_EQUAL(preference.read(slot_data), url, "The character slot must keep the original URL")
	var/query_url = "https://file.garden/user/portrait.jpg?v=1&name=a%20b"
	TEST_ASSERT_EQUAL(preference.deserialize(query_url), query_url, "A safe query must preserve the original URL")
	var/imgbox_url = "https://images4.imgbox.com/example/portrait.png"
	TEST_ASSERT_EQUAL(preference.deserialize(imgbox_url), imgbox_url, "Imgbox can host original images on another numbered file domain")
	var/list/invalid_urls = list(
		"http://i.gyazo.com/portrait.png",
		"https://i.gyazo.com.example.com/portrait.png",
		"https://images4.imgbox.com.example.com/portrait.png",
		"https://i.gyazo.com@example.com/portrait.png",
		"https://i.gyazo.com:443/portrait.png",
		"https://i.gyazo.com/portrait.gif",
		"https://i.gyazo.com/portrait.png\n",
		"https://i.gyazo.com/a'b.png",
		"https://i.gyazo.com/[repeat_string(400, "a")].png",
	)
	for(var/invalid_url in invalid_urls)
		var/invalid_value = preference.deserialize(invalid_url)
		TEST_ASSERT_NULL(invalid_value, "Malformed or unsafe image URLs must be rejected")
		TEST_ASSERT(!preference.write(slot_data, invalid_value), "An invalid change must not write to the character slot")
	TEST_ASSERT_NULL(preference.deserialize(list("https://i.gyazo.com/portrait.png")), "Non-text input must be rejected")
	TEST_ASSERT_EQUAL(preference.read(slot_data), url, "Invalid input must retain the previous URL")
	TEST_ASSERT(preference.write(slot_data, ""), "Clearing the URL must be allowed")
	TEST_ASSERT_EQUAL(preference.read(slot_data), "", "Clearing the URL must remove the portrait")

/datum/unit_test/character_portrait_slots/Run()
	var/list/urls = list(
		"character_portrait_url" = "https://i.gyazo.com/first.png",
		"character_portrait_url_2" = "https://file.garden/user/second.jpg",
		"character_portrait_url_3" = "https://files.catbox.moe/third.png",
	)
	var/list/slot_data = list("character_portrait_url" = urls["character_portrait_url"])
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	for(var/portrait_key in urls)
		var/datum/preference/text/character_portrait_url/preference = GLOB.preference_entries_by_key[portrait_key]
		TEST_ASSERT_NOTNULL(preference, "Each portrait key must have a registered preference")
		if(portrait_key != "character_portrait_url")
			TEST_ASSERT_NULL(preference.read(slot_data), "An old character slot must leave extra portraits unset")
			TEST_ASSERT(preference.write(slot_data, urls[portrait_key]), "Each new slot must accept a valid portrait URL")
		preference.apply_to_human(target, preference.read(slot_data), null)
	for(var/portrait_key in urls)
		TEST_ASSERT_EQUAL(slot_data[portrait_key], urls[portrait_key], "Each URL must be saved separately")
		TEST_ASSERT_EQUAL(target.dna.features[portrait_key], urls[portrait_key], "Each URL must apply to its own DNA feature")
