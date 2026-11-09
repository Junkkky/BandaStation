/datum/unit_test/character_portrait_urls/Run()
	var/datum/preference/preference = GLOB.preference_entries_by_key["character_portrait_urls"]
	TEST_ASSERT_NOTNULL(preference, "Portraits must use one registered list preference")
	var/list/urls = list("https://i.gyazo.com/portrait.PNG", "https://file.garden/user/portrait.jpg?v=1&name=a%20b", "https://images4.imgbox.com/example/portrait.png")
	var/list/slot_data = list()
	TEST_ASSERT(preference.write(slot_data, urls), "Three allowed URLs must save as one value")
	var/list/restored = preference.read(slot_data)
	TEST_ASSERT_EQUAL(json_encode(restored), json_encode(urls), "URL order and spelling must survive saving")
	restored[1] = ""
	TEST_ASSERT_EQUAL(slot_data["character_portrait_urls"][1], urls[1], "Reading must not expose the saved list for mutation")
	urls[2] = ""
	TEST_ASSERT_EQUAL(slot_data["character_portrait_urls"][2], "https://file.garden/user/portrait.jpg?v=1&name=a%20b", "Saving must not retain the caller's list")
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
		TEST_ASSERT_NULL(preference.deserialize(list(invalid_url)), "Malformed or unsafe URLs must reject the whole update")
	TEST_ASSERT_NULL(preference.deserialize("https://i.gyazo.com/portrait.png"), "A scalar cannot replace the list")
	TEST_ASSERT_NULL(preference.deserialize(list(42)), "Every entry must be a string")
	TEST_ASSERT_NULL(preference.deserialize(list(list("https://i.gyazo.com/portrait.png"))), "Nested lists must be rejected")
	TEST_ASSERT_NULL(preference.deserialize(list("", "", "", "")), "A fourth entry must be rejected")
	TEST_ASSERT_NULL(preference.deserialize(list("https://i.gyazo.com/portrait.png" = FALSE)), "Associative payloads must be rejected even with false values")
	TEST_ASSERT(!preference.write(slot_data, null), "An invalid deserialized update must not overwrite the stored list")
	TEST_ASSERT_EQUAL(length(slot_data["character_portrait_urls"]), 3, "Invalid input must preserve the previous portraits")
	var/list/blank_rows = list("", "https://i.gyazo.com/portrait.png")
	TEST_ASSERT(preference.write(slot_data, blank_rows), "An editable blank row must be allowed alongside a URL")
	TEST_ASSERT_EQUAL(json_encode(preference.read(slot_data)), json_encode(blank_rows), "Blank rows must preserve their positions during editing")
	TEST_ASSERT(preference.write(slot_data, list()), "An empty list must clear all portraits")
	TEST_ASSERT_EQUAL(length(preference.read(slot_data)), 0, "An explicitly empty list must round trip")

/// Exercise the real JSON preference lifecycle without accessing player save directories.
/datum/preferences/character_portrait_test/load_path(ckey, filename = "preferences.json")
	path = "data/character_portrait_tests/[REF(src)]-[filename]"

/datum/preferences/character_portrait_test/Destroy(force)
	var/save_path = path
	if(parent?.prefs == src)
		parent.prefs = null
	parent = null
	. = ..()
	fdel(save_path)
	fdel(PREFS_BACKUP_PATH(save_path))

/datum/unit_test/character_portrait_persistence/Run()
	var/datum/preference/preference = GLOB.preference_entries_by_key["character_portrait_urls"]
	TEST_ASSERT_NOTNULL(preference, "Portraits must use one registered list preference")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/character_portrait_test, mock_client)
	var/list/save_data = preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
	save_data -= preference.savefile_key
	preferences.value_cache -= preference.type
	save_data["character_portrait_url"] = "https://i.gyazo.com/first.png"
	save_data["character_portrait_url_2"] = ""
	save_data["character_portrait_url_3"] = "https://files.catbox.moe/third.png"
	var/list/migrated = preferences.read_preference(preference.type)
	TEST_ASSERT_EQUAL(json_encode(migrated), json_encode(list("https://i.gyazo.com/first.png", "https://files.catbox.moe/third.png")), "Existing nonempty slots must migrate in order")
	TEST_ASSERT(!preferences.update_preference(preference, list("javascript:alert(1)")), "The real UI update boundary must reject invalid lists")
	TEST_ASSERT_EQUAL(length(preferences.read_preference(preference.type)), 2, "Rejected UI updates must preserve prior values")
	var/list/updated = list("https://file.garden/user/updated.jpg")
	TEST_ASSERT(preferences.update_preference(preference, updated), "The UI must update the entire list through one key")
	TEST_ASSERT(preferences.save_character(), "The character slot must save")
	preferences.savefile.save()
	var/list/disk_data = json_decode(file2text(preferences.path))
	TEST_ASSERT_EQUAL(json_encode(disk_data["character1"][preference.savefile_key]), json_encode(updated), "The complete list must reach the real JSON savefile")
	TEST_ASSERT(preferences.load_character(), "The character slot must reload")
	TEST_ASSERT_EQUAL(json_encode(preferences.read_preference(preference.type)), json_encode(updated), "The new key must take precedence over legacy fields")
	preferences.max_save_slots = max(preferences.max_save_slots, 2)
	preferences.savefile.set_entry("character2", list("version" = save_data["version"], "character_portrait_urls" = list("https://files.catbox.moe/other.png")))
	TEST_ASSERT(preferences.load_character(2), "A second character slot must load")
	TEST_ASSERT_EQUAL(json_encode(preferences.read_preference(preference.type)), json_encode(list("https://files.catbox.moe/other.png")), "Each character slot must retain its own list")
	TEST_ASSERT(preferences.load_character(1), "The first character slot must load again")
	TEST_ASSERT_EQUAL(json_encode(preferences.read_preference(preference.type)), json_encode(updated), "Switching slots must not share portrait lists")
	TEST_ASSERT(preferences.update_preference(preference, list()), "The UI must allow clearing the list")
	preferences.save_character()
	preferences.load_character()
	TEST_ASSERT_EQUAL(length(preferences.read_preference(preference.type)), 0, "Clearing must not resurrect legacy portraits on reload")
	save_data[preference.savefile_key] = "corrupt"
	preferences.value_cache -= preference.type
	TEST_ASSERT_EQUAL(length(preferences.read_preference(preference.type)), 0, "A corrupt new value must not resurrect legacy portraits either")

/datum/unit_test/character_portrait_visibility/Run()
	var/datum/preference/preference = GLOB.preference_entries_by_key["character_portrait_urls"]
	TEST_ASSERT_NOTNULL(preference, "Portraits must use one registered list preference")
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/list/urls = list("", "https://i.gyazo.com/second.png", "https://files.catbox.moe/third.png")
	preference.apply_to_human(target, urls, null)
	urls[2] = ""
	var/datum/component/examine_panel/panel = target.AddComponent(/datum/component/examine_panel)
	TEST_ASSERT_EQUAL(json_encode(panel.get_portrait_urls(target)), json_encode(list("https://i.gyazo.com/second.png", "https://files.catbox.moe/third.png")), "Consumers must omit blank rows and keep a detached ordered copy")
	ADD_TRAIT(target, TRAIT_UNKNOWN_APPEARANCE, REF(src))
	TEST_ASSERT_NULL(panel.get_portrait_urls(target), "An obscured face must not disclose any portrait URLs")
