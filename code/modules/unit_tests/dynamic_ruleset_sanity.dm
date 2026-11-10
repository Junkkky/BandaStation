/// Verifies that dynamic rulesets are setup properly without external configuration.
/datum/unit_test/dynamic_ruleset_sanity

/datum/unit_test/dynamic_ruleset_sanity/Run()
	for (var/datum/dynamic_ruleset/midround/ruleset as anything in subtypesof(/datum/dynamic_ruleset/midround))
		if(!initial(ruleset.config_tag))
			continue
		var/midround_ruleset_style = initial(ruleset.midround_type)
		if (midround_ruleset_style != HEAVY_MIDROUND && midround_ruleset_style != LIGHT_MIDROUND)
			TEST_FAIL("[ruleset] has an invalid midround_ruleset_style, it should be HEAVY_MIDROUND or LIGHT_MIDROUND")

/// Verifies that dynamic rulesets have unique antag_flag.
/datum/unit_test/dynamic_unique_antag_flags

/datum/unit_test/dynamic_unique_antag_flags/Run()
	var/list/known_antag_flags = list()

	for (var/datum/dynamic_ruleset/ruleset as anything in subtypesof(/datum/dynamic_ruleset))
		if(!initial(ruleset.config_tag))
			continue

		var/antag_flag = initial(ruleset.pref_flag)

		// null antag flag is valid for rulesets with no associated preferecne
		if (isnull(antag_flag))
			// however if you set preview_antag_datum, it is assumed you do have a preference, and thus should have a flag
			if (initial(ruleset.preview_antag_datum))
				TEST_FAIL("[ruleset] sets preview_antag_datum, but has no pref_flag! \
					If you want to use a preview antag datum, you must set a pref_flag.")
			continue

		if (antag_flag in known_antag_flags)
			if(!(initial(ruleset.ruleset_flags) & RULESET_VARIATION))
				TEST_FAIL("[ruleset] has a non-unique antag_flag [antag_flag] (used by [known_antag_flags[antag_flag]])!")
			continue

		known_antag_flags[antag_flag] = ruleset

/datum/unit_test/dynamic_roundstart_preparation_rollback
	var/list/saved_queue
	var/list/saved_forced_jobs
	var/list/saved_blocked_jobs

/datum/unit_test/dynamic_roundstart_preparation_rollback/Run()
	saved_queue = SSdynamic.queued_rulesets
	saved_forced_jobs = SSjob.forced_occupations
	saved_blocked_jobs = SSjob.prevented_occupations

	var/datum/dynamic_ruleset/roundstart/wizard/admin_ruleset = allocate(/datum/dynamic_ruleset/roundstart/wizard)
	var/datum/dynamic_ruleset/roundstart/wizard/rolled_ruleset = allocate(/datum/dynamic_ruleset/roundstart/wizard)
	var/datum/mind/admin_candidate = allocate(/datum/mind)
	var/datum/mind/rolled_candidate = allocate(/datum/mind)
	SSdynamic.queued_rulesets = list(admin_ruleset, rolled_ruleset)
	SSjob.forced_occupations = list()
	SSjob.forced_occupations[admin_candidate] = /datum/job/assistant
	SSjob.prevented_occupations = list()
	SSjob.prevented_occupations[admin_candidate] = list(JOB_SECURITY_OFFICER)

	admin_ruleset.prepare_job_constraints(admin_candidate)
	admin_ruleset.selected_minds += admin_candidate
	rolled_ruleset.prepare_job_constraints(rolled_candidate)
	rolled_ruleset.selected_minds += rolled_candidate
	var/datum/roundstart_job_changes/rolled_selection = SSdynamic.get_roundstart_job_changes(rolled_candidate)
	TEST_ASSERT_NOTNULL(rolled_selection, "Prepared selection has no job constraints receipt.")
	TEST_ASSERT(!SSdynamic.cancel_roundstart_assignment(admin_candidate, rolled_selection), "An unrelated receipt cancelled a selection.")
	TEST_ASSERT_EQUAL(SSjob.forced_occupations[admin_candidate], /datum/job/space_wizard, "The wizard's forced role was not set.")
	TEST_ASSERT(JOB_AI in SSjob.prevented_occupations[admin_candidate], "The wizard's job restrictions were not set.")

	SSdynamic.finish_roundstart_preparation(list(rolled_ruleset), list(), FALSE)
	TEST_ASSERT_EQUAL(length(SSdynamic.queued_rulesets), 1, "An aborted attempt left automatic rulesets queued.")
	TEST_ASSERT_EQUAL(SSdynamic.queued_rulesets[1], admin_ruleset, "An aborted attempt lost the admin's queued ruleset.")
	TEST_ASSERT_EQUAL(length(admin_ruleset.selected_minds), 0, "The admin's queued ruleset retained its previous selection.")
	TEST_ASSERT_EQUAL(SSjob.forced_occupations[admin_candidate], /datum/job/assistant, "An aborted attempt did not restore the prior forced job.")
	var/list/remaining_blocks = SSjob.prevented_occupations[admin_candidate]
	TEST_ASSERT_EQUAL(length(remaining_blocks), 1, "An aborted attempt retained temporary restrictions.")
	TEST_ASSERT(JOB_SECURITY_OFFICER in remaining_blocks, "An aborted attempt removed a prior restriction.")
	TEST_ASSERT_NULL(SSjob.forced_occupations[rolled_candidate], "The automatic ruleset left a forced job behind.")
	TEST_ASSERT_NULL(SSjob.prevented_occupations[rolled_candidate], "The automatic ruleset left job restrictions behind.")

	var/datum/dynamic_ruleset/roundstart/blood_worm/blood_worm = allocate(/datum/dynamic_ruleset/roundstart/blood_worm)
	var/datum/job/assistant/crew_job = SSjob.get_job_type(/datum/job/assistant)
	var/mob/living/carbon/human/bloodless_body = allocate(/mob/living/carbon/human/consistent)
	bloodless_body.set_species(/datum/species/ipc)
	rolled_candidate.set_assigned_role(crew_job)
	SSdynamic.queued_rulesets += blood_worm
	blood_worm.prepare_job_constraints(rolled_candidate)
	blood_worm.selected_minds += rolled_candidate
	SSdynamic.validate_roundstart_body(rolled_candidate, bloodless_body, SSdynamic.get_roundstart_job_changes(rolled_candidate))
	TEST_ASSERT_NULL(SSdynamic.get_roundstart_job_changes(rolled_candidate), "A bloodless body retained a Blood Worm assignment.")
	TEST_ASSERT_EQUAL(rolled_candidate.assigned_role, crew_job, "Rejecting a Blood Worm host revoked the player's crew job.")

	admin_ruleset.prepare_job_constraints(rolled_candidate)
	admin_ruleset.selected_minds += rolled_candidate
	SSjob.assign_priority_positions()
	TEST_ASSERT_NULL(SSdynamic.get_roundstart_job_changes(rolled_candidate), "A rejected forced job retained its Dynamic assignment.")
	TEST_ASSERT_NULL(SSjob.forced_occupations[rolled_candidate], "A rejected Dynamic assignment retained its forced job.")
	TEST_ASSERT_EQUAL(SSjob.forced_occupations[admin_candidate], /datum/job/assistant, "Rejection removed an unrelated forced job.")

/datum/unit_test/dynamic_roundstart_preparation_rollback/Destroy()
	. = ..()
	SSdynamic.queued_rulesets = saved_queue
	SSjob.forced_occupations = saved_forced_jobs
	SSjob.prevented_occupations = saved_blocked_jobs
