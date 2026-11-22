/// Tests strip_outer_punctuation()
/datum/unit_test/strip_outer_punctuation

/datum/unit_test/strip_outer_punctuation/Run()
	var/list/sample_to_expected = list(
		"Hello, world!" = "Hello, world",
		"|Who are you?|" = "Who are you",
		"Oh wow..." = "Oh wow",
		"My name is E.T, the alien!" = "My name is E.T, the alien",
		"I'm +YELLING+ at you!" = "I'm +YELLING+ at you",
		"+I'm REALLY yelling!+" = "I'm REALLY yelling",
	)

	for(var/sample in sample_to_expected)
		TEST_ASSERT_EQUAL(strip_outer_punctuation(sample), sample_to_expected[sample], "Strip punctuation failed for sample text: [sample]")

/// Tests find_last_punctuation()
/datum/unit_test/find_last_punctuation

/datum/unit_test/find_last_punctuation/Run()
	var/list/sample_to_expected = list(
		"Hello, world!" = "!",
		"|Who are you?|" = "?",
		"Really, |WHO are you|?" = "?",
		"Oh wow..." = "...",
		"My name is E.T, the alien!" = "!",
	)

	for(var/sample in sample_to_expected)
		TEST_ASSERT_EQUAL(find_last_punctuation(sample), sample_to_expected[sample], "Find punctuation failed for sample text: [sample]")

/// Capitalizing translated names must remove proper/improper macros without losing Cyrillic letters.
/datum/unit_test/capitalize_unicode/Run()
	TEST_ASSERT_EQUAL(capitalize("\proper test name"), "Test name", "Proper macro was not removed before capitalization.")
	TEST_ASSERT_EQUAL(capitalize("\improper test name"), "Test name", "Improper macro was not removed before capitalization.")
	TEST_ASSERT_EQUAL(capitalize("\proper ёлка"), "Ёлка", "A proper Cyrillic name was not capitalized.")
	TEST_ASSERT_EQUAL(capitalize("\improper аварийный лом"), "Аварийный лом", "A translated item name lost Cyrillic capitalization.")
	TEST_ASSERT_EQUAL(full_capitalize("\proper test name"), "\proper Test Name", "Full capitalization corrupted the proper macro.")
	TEST_ASSERT_EQUAL(full_capitalize("\improper test name"), "\improper Test Name", "Full capitalization corrupted the improper macro.")

/// A permissive name can contain ordinary punctuation, but must remain a single line without angle brackets.
/datum/unit_test/permissive_names/Run()
	TEST_ASSERT_EQUAL(permissive_sanitize_name("Ada & Bea"), "Ada & Bea", "An ampersand should remain valid in a permissive name.")
	TEST_ASSERT_NULL(permissive_sanitize_name("Ada < Bea"), "An opening angle bracket should be rejected.")
	TEST_ASSERT_NULL(permissive_sanitize_name("Ada > Bea"), "A closing angle bracket should be rejected.")
	TEST_ASSERT_NULL(permissive_sanitize_name("Ada\nBea"), "A newline should be rejected.")
	TEST_ASSERT_NULL(permissive_sanitize_name("Ada\tBea"), "A tab should be rejected.")

/// Admin HTML needs escaped names, while raw output remains suitable for plain text.
/datum/unit_test/admin_name_escaping/Run()
	var/mob/subject = allocate(/mob/living/carbon/human/consistent)
	subject.real_name = "Ada & Bea"

	TEST_ASSERT(findtext(key_name_admin(subject), "Ada &amp; Bea"), "The HTML formatter should escape a name even when no PM link can be made.")
	TEST_ASSERT(findtext(key_name(subject), "Ada & Bea"), "The plain-text formatter should preserve the name.")
