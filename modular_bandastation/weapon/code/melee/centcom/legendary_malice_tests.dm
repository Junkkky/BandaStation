// The fork's role defines are loaded after the base unit-test includes.
#define LEGENDARY_TEST_OFFICER_ROLE "centcom_role_officer"

/datum/unit_test/legendary_sword_malice_registry/Run()
	var/list/bond_by_icon = list(
		"malice_dance" = 0,
		"malice_shadow" = 50,
		"malice_rage" = 100,
		"malice_omnislash" = 100,
		"malice_guard" = 100,
	)
	var/obj/item/dualsaber/legendary_saber/malice = EASY_ALLOCATE()
	TEST_ASSERT_EQUAL(length(malice.actions), length(bond_by_icon), "Malice granted the wrong number of actions.")
	for(var/datum/action/cooldown/legendary_sword/ability in malice.actions)
		var/state = ability.button_icon_state
		TEST_ASSERT(state in bond_by_icon, "Unexpected or duplicate Malice ability: [state].")
		TEST_ASSERT_EQUAL(ability.required_bond, bond_by_icon[state], "Wrong bond requirement for [state].")
		TEST_ASSERT(state in icon_states(ability.button_icon), "Missing icon for [state].")
		bond_by_icon -= state
	TEST_ASSERT_EQUAL(length(bond_by_icon), 0, "Malice did not grant all five abilities.")

	for(var/sword_type in subtypesof(/obj/item/dualsaber/legendary_saber))
		var/obj/item/dualsaber/legendary_saber/other = allocate(sword_type)
		TEST_ASSERT(istype(other.enchant, /datum/enchantment/dash), "[sword_type] lost its original dash.")
		TEST_ASSERT_EQUAL(other.reach, 5, "[sword_type] lost its original dash reach.")
		TEST_ASSERT_EQUAL(length(other.actions), 1, "[sword_type] inherited Malice's actions.")
		TEST_ASSERT(locate(/datum/action/item_action/legendary_saber/rage) in other.actions, "[sword_type] lost Swordsman Rage.")

/datum/unit_test/legendary_sword_malice_bond/Run()
	var/mob/living/carbon/human/consistent/wielder = EASY_ALLOCATE()
	var/mob/living/carbon/human/consistent/other_officer = EASY_ALLOCATE()
	var/obj/item/dualsaber/legendary_saber/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	other_officer.mind_initialize()
	other_officer.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	TEST_ASSERT(sword.can_use_legendary_ability(wielder, require_wielded = FALSE), "Officer could not start an unbound sword.")
	TEST_ASSERT(!sword.can_use_legendary_ability(wielder), "Grounded sword could use abilities.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(45 SECONDS), 25, "First stage has the wrong progress.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(45 SECONDS + 90 SECONDS - 1), 49, "Second tier unlocked early.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(45 SECONDS + 90 SECONDS), 50, "Second tier was not unlocked.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(45 SECONDS + 90 SECONDS + 3 MINUTES), 100, "Final tier was not unlocked.")

	sword.bond_meditation_time = 45 SECONDS - world.tick_lag
	sword.meditate(wielder)
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(), 25, "Meditating next to the inactive sword did not complete the stage.")
	TEST_ASSERT(sword.bond_rest > world.time, "Completing a stage did not start the rest interval.")
	TEST_ASSERT_EQUAL(sword.bonded_mind.resolve(), wielder.mind, "Meditation did not bind the sword to the owner.")
	TEST_ASSERT(!sword.has_legendary_bond_access(other_officer), "A second officer inherited someone else's bond.")

	TEST_ASSERT(wielder.put_in_active_hand(sword), "Valid owner could not draw the sword.")
	sword.attack_self(wielder)
	TEST_ASSERT(sword.can_use_legendary_ability(wielder), "Wielded sword could not use its starting ability.")
	TEST_ASSERT(!sword.can_use_legendary_ability(wielder, 50), "Second ability unlocked at 25%.")
	other_officer.forceMove(get_ranged_target_turf(run_loc_floor_bottom_left, EAST, 3))
	wielder.set_combat_mode(TRUE)
	TEST_ASSERT(!other_officer.IsReachableBy(wielder), "Dash target started within ordinary melee reach.")
	sword.melee_attack_chain(wielder, other_officer)
	TEST_ASSERT(other_officer.IsReachableBy(wielder), "The common dash did not bring the wielder into melee reach.")
	TEST_ASSERT(other_officer.get_brute_loss() > 0, "The dash did not hit after reaching its target.")
	wielder.dropItemToGround(sword)
	TEST_ASSERT(!sword.can_use_legendary_ability(wielder), "Dropped sword remained usable.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(), 25, "Dropping the sword lost bond progress.")


/datum/unit_test/legendary_sword_malice_meditation
	var/list/whispered_lines = list()

/datum/unit_test/legendary_sword_malice_meditation/proc/record_whisper(datum/source, list/speech_args)
	SIGNAL_HANDLER
	var/list/mods = speech_args[SPEECH_MODS]
	if(mods[WHISPER_MODE] == MODE_WHISPER)
		whispered_lines += speech_args[SPEECH_MESSAGE]

/datum/unit_test/legendary_sword_malice_meditation/Run()
	var/turf/start = run_loc_floor_bottom_left
	// The consistent unit-test dummy completes timed actions immediately.
	var/mob/living/carbon/human/wielder = allocate(/mob/living/carbon/human, start)
	var/obj/item/dualsaber/legendary_saber/sword = allocate(/obj/item/dualsaber/legendary_saber, get_step(start, EAST))
	wielder.mind_initialize()
	wielder.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	wielder.setDir(WEST)
	wielder.add_filter("unrelated_meditation_test", 1, outline_filter(size = 1, color = COLOR_WHITE))
	var/previous_filters = json_encode(wielder.filter_data)
	var/previous_filter_count = length(wielder.filters)
	var/list/previous_transform = matrix(wielder.transform).tolist()
	RegisterSignal(wielder, COMSIG_MOB_SAY, PROC_REF(record_whisper))

	wielder.ClickOn(sword, "left=1;alt=1")
	var/deadline = world.time + 5 SECONDS
	UNTIL(LAZYACCESS(wielder.do_afters, sword) || world.time >= deadline)
	TEST_ASSERT(LAZYACCESS(wielder.do_afters, sword), "Alt-clicking the adjacent grounded blade did not start a timed meditation.")
	TEST_ASSERT_EQUAL(wielder.dir, EAST, "The wielder did not turn toward the grounded sword.")
	TEST_ASSERT_EQUAL(wielder.body_position, STANDING_UP, "The standing wielder changed posture while praying.")
	TEST_ASSERT_EQUAL(length(wielder.filters), previous_filter_count, "Meditation changed the wielder's active filters.")
	TEST_ASSERT_EQUAL(json_encode(wielder.filter_data), previous_filters, "Meditation changed the order or parameters of an existing filter.")
	TEST_ASSERT(compare_list(matrix(wielder.transform).tolist(), previous_transform), "Meditation altered the standing character's transform.")
	TEST_ASSERT_EQUAL(length(whispered_lines), 1, "Starting the first stage should produce one actual whisper.")
	var/datum/progressbar/bar = locate() in wielder.progressbars[sword]
	TEST_ASSERT_NOTNULL(bar, "An Alt-click meditation has no progress bar.")
	UNTIL(bar.last_progress > 0 || world.time >= deadline)
	TEST_ASSERT(bar.last_progress > 0, "The visible bond progress never advanced.")

	wielder.forceMove(get_step(start, NORTH))
	deadline = world.time + 5 SECONDS
	UNTIL(!sword.meditating || world.time >= deadline)
	TEST_ASSERT(!sword.meditating && sword.bond_meditation_time > 0, "Moving did not interrupt meditation and preserve the earned time.")
	TEST_ASSERT_EQUAL(wielder.body_position, STANDING_UP, "Interrupting meditation changed the wielder's posture.")
	TEST_ASSERT_EQUAL(length(wielder.filters), previous_filter_count, "Ending meditation changed the active filter count.")
	TEST_ASSERT_EQUAL(json_encode(wielder.filter_data), previous_filters, "Ending meditation changed the order or parameters of an existing filter.")
	TEST_ASSERT(compare_list(matrix(wielder.transform).tolist(), previous_transform), "Ending meditation changed the standing character's transform.")

	// Skip only the waiting time; the click, stage transition and cooldown all run normally.
	wielder.forceMove(start)
	sword.bond_meditation_time = 45 SECONDS - world.tick_lag
	wielder.ClickOn(sword, "left=1;alt=1")
	deadline = world.time + 5 SECONDS
	UNTIL(sword.get_legendary_bond() == 25 || world.time >= deadline)
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(), 25, "Resuming the interrupted stage did not complete it.")
	TEST_ASSERT_EQUAL(length(whispered_lines), 1, "Resuming the same stage repeated its whisper.")
	TEST_ASSERT(!COOLDOWN_FINISHED(sword, bond_rest), "Completing the stage skipped the rest.")

	COOLDOWN_RESET(sword, bond_rest)
	UNTIL(world.time > wielder.next_click)
	wielder.ClickOn(sword, "left=1;alt=1")
	deadline = world.time + 5 SECONDS
	UNTIL(LAZYACCESS(wielder.do_afters, sword) || world.time >= deadline)
	TEST_ASSERT(LAZYACCESS(wielder.do_afters, sword), "The second meditation did not start.")
	TEST_ASSERT_EQUAL(length(whispered_lines), 2, "The next stage did not produce its own whisper.")
	TEST_ASSERT_NOTEQUAL(whispered_lines[1], whispered_lines[2], "The first two stages used the same whisper.")
	wielder.apply_damage(1, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	UNTIL(!sword.meditating || world.time >= deadline)
	TEST_ASSERT(!sword.meditating, "Taking damage did not interrupt the second stage.")

	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS
	UNTIL(world.time > wielder.next_click)
	wielder.ClickOn(sword, "left=1;alt=1")
	deadline = world.time + 5 SECONDS
	UNTIL(LAZYACCESS(wielder.do_afters, sword) || world.time >= deadline)
	TEST_ASSERT(LAZYACCESS(wielder.do_afters, sword), "The final meditation did not start.")
	TEST_ASSERT_EQUAL(length(whispered_lines), 3, "The final stage did not produce one whisper.")
	TEST_ASSERT_EQUAL(length(unique_list(whispered_lines)), 3, "The three stages should have distinct whispers.")
	qdel(sword)

	// A resting mob may be unable to Alt-click. Exercise posture and speech inside the session itself.
	var/obj/item/dualsaber/legendary_saber/second_sword = allocate(/obj/item/dualsaber/legendary_saber, get_step(start, EAST))
	wielder.set_resting(TRUE, instant = TRUE)
	ADD_TRAIT(wielder, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	INVOKE_ASYNC(second_sword, TYPE_PROC_REF(/obj/item/dualsaber/legendary_saber, meditate), wielder)
	deadline = world.time + 5 SECONDS
	UNTIL(LAZYACCESS(wielder.do_afters, second_sword) || world.time >= deadline)
	TEST_ASSERT(LAZYACCESS(wielder.do_afters, second_sword), "A silent, resting owner could not meditate.")
	TEST_ASSERT_EQUAL(wielder.body_position, LYING_DOWN, "Meditation stood a resting person up.")
	TEST_ASSERT_EQUAL(length(whispered_lines), 3, "A mute owner sent an audible prayer.")
	qdel(second_sword)

	wielder.set_resting(FALSE, instant = TRUE)
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, start)
	TEST_ASSERT(chair.buckle_mob(wielder, force = TRUE), "The seated wielder could not be buckled to the test chair.")
	var/obj/item/dualsaber/legendary_saber/seated_sword = allocate(/obj/item/dualsaber/legendary_saber, get_step(start, EAST))
	var/seated_direction = wielder.dir
	INVOKE_ASYNC(seated_sword, TYPE_PROC_REF(/obj/item/dualsaber/legendary_saber, meditate), wielder)
	deadline = world.time + 5 SECONDS
	UNTIL(LAZYACCESS(wielder.do_afters, seated_sword) || world.time >= deadline)
	TEST_ASSERT(LAZYACCESS(wielder.do_afters, seated_sword), "The seated wielder could not meditate.")
	TEST_ASSERT_EQUAL(wielder.buckled, chair, "Meditation unbuckled the wielder.")
	TEST_ASSERT_EQUAL(wielder.dir, seated_direction, "Meditation turned a buckled wielder away from the chair's orientation.")
	qdel(seated_sword)

/datum/unit_test/legendary_sword_malice_dance
	/// Damage delivered by Malice before natural healing can change the target's health.
	var/list/sword_damage = list()
	/// Stationary listener registered with the same spatial grid used by player audio.
	var/mob/living/carbon/human/consistent/malice_audio_listener/alongside

/datum/unit_test/legendary_sword_malice_dance/Destroy()
	alongside?.clear_important_client_contents()
	alongside = null
	return ..()

/mob/living/carbon/human/consistent/malice_audio_listener
	var/impact_sound = 'modular_bandastation/weapon/sound/melee/malice_dance_hit.ogg'
	var/list/impact_origins = list()
	var/list/impact_times = list()
	var/ordinary_hit_sound
	var/ordinary_impacts = 0

/mob/living/carbon/human/consistent/malice_audio_listener/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff_exponent = SOUND_FALLOFF_EXPONENT, channel = 0, pressure_affected = TRUE, sound/sound_to_use, max_distance, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, distance_multiplier = 1, use_reverb = TRUE, wait = FALSE, datum/preference/numeric/volume/volume_preference = null, min_volume = 5)
	if(soundin == impact_sound)
		impact_origins += turf_source
		impact_times += world.time
	else if(soundin == ordinary_hit_sound)
		ordinary_impacts++
	return ..()

/datum/unit_test/legendary_sword_malice_dance/Run()
	var/turf/start = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/next_tile = get_step(start, EAST)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/consistent/behind = EASY_ALLOCATE()
	alongside = allocate(/mob/living/carbon/human/consistent/malice_audio_listener, start)
	alongside.enable_client_mobs_in_contents()
	var/mob/living/carbon/human/consistent/ahead = allocate(/mob/living/carbon/human/consistent, get_step(next_tile, EAST))
	var/obj/item/dualsaber/legendary_saber/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Malice.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	for(var/mob/living/participant as anything in list(behind, alongside, ahead, wielder))
		sword_damage[participant] = 0
		RegisterSignal(participant, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_sword_damage))
	var/datum/action/cooldown/legendary_sword/malice_dance/dance = locate() in sword.actions
	TEST_ASSERT(dance?.Trigger(wielder), "The first ability could not be activated with zero bond.")
	var/datum/status_effect/malice_dance/spin = wielder.has_status_effect(/datum/status_effect/malice_dance)
	var/datum/sound_token/spin_sound = spin?.dance_sound
	TEST_ASSERT_EQUAL(spin_sound?.source, wielder, "The spin sound should follow the wielder.")
	TEST_ASSERT_EQUAL(spin_sound.sound.file, 'modular_bandastation/weapon/sound/melee/malice_dance.ogg', "The spin started the wrong recording.")
	TEST_ASSERT(spin_sound.sound_duration > 5 SECONDS, "The recording should cover the five-second spin and the last sweep's decay.")
	TEST_ASSERT_EQUAL(dance.next_use_time, world.time + 12 SECONDS, "The spin started the wrong cooldown.")
	sword.melee_attack_chain(wielder, behind)
	TEST_ASSERT_EQUAL(sword_damage[behind], 0, "The wielder could still attack manually during the spin.")

	var/started_at = world.time
	var/deadline = started_at + 8 SECONDS
	UNTIL(sword_damage[behind] || world.time >= deadline)
	TEST_ASSERT_EQUAL(sword_damage[behind], 10, "The first pulse missed the adjacent target or dealt the wrong damage.")
	TEST_ASSERT_EQUAL(sword_damage[alongside], 10, "The first pulse missed a second target on the wielder's tile.")
	TEST_ASSERT_EQUAL(sword_damage[ahead], 0, "The first pulse hit outside its one-tile radius.")
	TEST_ASSERT(wielder.Move(next_tile, EAST), "The spin prevented the wielder from moving.")
	var/impact_deadline = world.time + 0.4 SECONDS
	UNTIL(length(alongside.impact_origins) >= 2 || world.time >= impact_deadline)
	TEST_ASSERT_EQUAL(length(alongside.impact_origins), 2, "The first pulse should play one impact for each of its two targets.")
	TEST_ASSERT((behind.loc in alongside.impact_origins) && (alongside.loc in alongside.impact_origins), "Each impact should come from the target it struck.")
	TEST_ASSERT(ISINRANGE(alongside.impact_times[2] - alongside.impact_times[1], 1 DECISECONDS, 0.4 SECONDS), "The second impact should sound after the first and before the next sweep.")
	UNTIL(!wielder.has_status_effect(/datum/status_effect/malice_dance) || world.time >= deadline)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_dance), "The spin did not finish.")
	TEST_ASSERT(world.time >= started_at + 5 SECONDS, "The spin ended before five seconds elapsed.")
	TEST_ASSERT_EQUAL(sword_damage[behind], 10, "The spin kept striking its original location.")
	TEST_ASSERT_EQUAL(sword_damage[alongside], 100, "The target in reach throughout did not take exactly ten pulses.")
	TEST_ASSERT_EQUAL(sword_damage[ahead], 90, "The spin did not follow its wielder for the remaining nine pulses.")
	impact_deadline = world.time + 0.4 SECONDS
	UNTIL(length(alongside.impact_origins) >= 20 || world.time >= impact_deadline)
	TEST_ASSERT_EQUAL(length(alongside.impact_origins), 20, "Ten pulses hitting two targets each should play twenty impacts.")
	TEST_ASSERT(alongside.impact_origins.Find(alongside.loc, 19) && alongside.impact_origins.Find(ahead.loc, 19), "The last two impacts should come from the two targets still in reach.")
	TEST_ASSERT_EQUAL(sword_damage[wielder], 0, "The wielder was hit by their own spin.")
	UNTIL(QDELETED(spin_sound) || world.time >= deadline)
	TEST_ASSERT(QDELETED(spin_sound), "The sound channel remained active after the recording finished.")

	sword_damage[alongside] = 0
	sword_damage[ahead] = 0
	alongside.impact_origins.Cut()
	alongside.impact_times.Cut()
	sword.two_hand_force = 70
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS + 3 MINUTES
	wielder.set_tox_loss(70)
	var/datum/action/cooldown/legendary_sword/malice_rage/rage = locate() in sword.actions
	TEST_ASSERT(rage?.Trigger(wielder), "Could not prime a critical strike for the second spin.")
	wielder.forceMove(get_ranged_target_turf(next_tile, NORTH, 3))
	dance.ResetCooldown()
	TEST_ASSERT(dance.Trigger(wielder), "The spin could not be used again after its cooldown.")
	spin = wielder.has_status_effect(/datum/status_effect/malice_dance)
	spin_sound = spin?.dance_sound
	TEST_ASSERT_NOTNULL(spin_sound, "Reactivating the spin did not start a fresh recording.")
	deadline = world.time + 4 SECONDS
	UNTIL(spin.spin_time >= 0.5 SECONDS || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(alongside.impact_origins), 0, "An empty sweep played an impact.")
	wielder.forceMove(next_tile)
	for(var/mob/living/defender as anything in list(alongside, ahead))
		RegisterSignal(defender, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_hit))
	UNTIL(spin.spin_time >= 1 SECONDS || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(alongside.impact_origins), 0, "A fully blocked sweep played an impact.")
	for(var/mob/living/defender as anything in list(alongside, ahead))
		UnregisterSignal(defender, COMSIG_LIVING_CHECK_BLOCK)
	ahead.forceMove(alongside.loc)
	UNTIL(sword_damage[ahead] || world.time >= deadline)
	TEST_ASSERT_EQUAL(sword_damage[alongside] + sword_damage[ahead], 60, "A scaled pulse should deal 20 to one target and 40 to the other.")
	impact_deadline = world.time + 0.4 SECONDS
	UNTIL(length(alongside.impact_origins) >= 2 || world.time >= impact_deadline)
	TEST_ASSERT_EQUAL(length(alongside.impact_origins), 2, "Two targets on the same tile should still play two impacts.")
	TEST_ASSERT(alongside.impact_origins[1] == alongside.loc && alongside.impact_origins[2] == alongside.loc, "Both impacts should come from the shared target tile.")
	TEST_ASSERT(ISINRANGE(alongside.impact_times[2] - alongside.impact_times[1], 1 DECISECONDS, 0.4 SECONDS), "Overlapping targets should produce distinct impact times after a blocked sweep.")
	wielder.dropItemToGround(sword)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_dance), "Dropping the sword left the spin active.")
	TEST_ASSERT(QDELETED(spin_sound), "Dropping the sword left its recording playing.")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(sword_damage[alongside] + sword_damage[ahead], 60, "A queued pulse hit after the sword was dropped.")

/datum/unit_test/legendary_sword_malice_dance/proc/record_sword_damage(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber))
		sword_damage[source] += damage

/datum/unit_test/legendary_sword_malice_dance/proc/block_hit()
	SIGNAL_HANDLER
	return SUCCESSFUL_BLOCK

/datum/unit_test/legendary_sword_malice_rage
	/// Incoming blade damage before bodypart saturation or passive healing.
	var/list/hits = list()
	var/list/targets_hit = list()
	var/list/ordinary_swings = list()
	var/obj/item/bodypart/last_hit_limb
	var/mob/living/carbon/human/consistent/malice_audio_listener/victim

/datum/unit_test/legendary_sword_malice_rage/Destroy()
	victim?.clear_important_client_contents()
	victim = null
	return ..()

/datum/unit_test/legendary_sword_malice_rage/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/wielder = EASY_ALLOCATE()
	var/mob/living/carbon/human/consistent/pursuer = EASY_ALLOCATE()
	var/mob/living/carbon/human/consistent/side = allocate(/mob/living/carbon/human/consistent, get_step(start, NORTH))
	var/mob/living/carbon/human/consistent/diagonal = allocate(/mob/living/carbon/human/consistent, get_step(start, NORTHEAST))
	var/mob/living/carbon/human/consistent/guard = allocate(/mob/living/carbon/human/consistent, get_step(start, NORTH))
	victim = allocate(/mob/living/carbon/human/consistent/malice_audio_listener, get_ranged_target_turf(start, EAST, 2))
	var/obj/item/dualsaber/legendary_saber/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS + 3 MINUTES
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Malice.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	var/datum/action/cooldown/legendary_sword/malice_rage/rage = locate() in sword.actions
	var/datum/action/cooldown/legendary_sword/malice_shadow/shadow = locate() in sword.actions
	sword.wound_bonus = CANT_WOUND // Isolate the critical's guaranteed bleed from random melee wounds.
	TEST_ASSERT(shadow.Trigger(wielder), "Could not prime the shadow.")
	var/dash_time = world.time
	sword.melee_attack_chain(wielder, victim)
	victim.ordinary_hit_sound = sword.hitsound
	victim.enable_client_mobs_in_contents()
	TEST_ASSERT(wielder.Adjacent(victim), "The wielder did not dash to the victim.")
	TEST_ASSERT_EQUAL(get_dist(wielder, start), 1, "The wielder must end the dash inside the shadow's radius.")
	for(var/mob/living/participant as anything in list(pursuer, side, diagonal, guard, victim, wielder))
		RegisterSignal(participant, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_hit))
	RegisterSignal(guard, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_hit))
	TEST_ASSERT_EQUAL(wielder.health, wielder.maxHealth, "The wielder should be at full health for activation.")
	TEST_ASSERT(rage.Trigger(wielder), "Last Rage did not activate at full health.")
	var/obj/effect/dummy/lighting_obj/moblight/malice_rage/charge = locate() in wielder.vis_contents
	TEST_ASSERT_NOTNULL(charge, "Last Rage did not attach the charge animation to the wielder.")
	TEST_ASSERT_EQUAL(rage.next_use_time, world.time + 45 SECONDS, "Last Rage started the wrong cooldown.")
	wielder.set_brute_loss(40)
	var/deadline = world.time + 2 SECONDS
	UNTIL(length(hits) || world.time >= deadline)
	TEST_ASSERT(world.time >= dash_time + 0.6 SECONDS, "The shadow struck before its telegraph ended.")
	TEST_ASSERT_EQUAL(length(hits), 3, "The shadow should hit the three unblocked targets in range once each.")
	for(var/mob/living/expected as anything in list(pursuer, side, diagonal))
		TEST_ASSERT(expected in targets_hit, "The shadow missed a target at [get_turf(expected)].")
	for(var/damage in hits)
		TEST_ASSERT_EQUAL(damage, 35, "A shadow hit did not use the open blade's base damage.")
	sleep(0.4 SECONDS) // Include the last possible staggered sound, even if the blocked target played one.
	TEST_ASSERT_EQUAL(length(victim.impact_origins), 3, "The shadow should play one impact per damaged target.")
	for(var/mob/living/expected as anything in list(pursuer, side, diagonal))
		TEST_ASSERT(expected.loc in victim.impact_origins, "The shadow was silent at [get_turf(expected)].")
	TEST_ASSERT(victim.impact_times[1] < victim.impact_times[2] && victim.impact_times[2] < victim.impact_times[3], "The three shadow impacts should be staggered.")
	TEST_ASSERT_EQUAL(victim.ordinary_impacts, 0, "The shadow also played the ordinary saber hit.")
	victim.impact_sound = 'modular_bandastation/weapon/sound/melee/malice_rage_hit.ogg'
	victim.impact_origins.Cut()
	victim.impact_times.Cut()
	TEST_ASSERT_EQUAL(pursuer.get_bleed_rate(), 0, "The shadow applied Last Rage's bleeding.")
	hits.Cut()

	var/brute_before_crit = wielder.get_brute_loss()
	wielder.set_stamina_loss(40)
	var/stamina_before_crit = wielder.get_stamina_loss()
	sword.melee_attack_chain(wielder, get_turf(wielder))
	var/ordinary_before_block = victim.ordinary_impacts
	RegisterSignal(sword, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(record_ordinary_swing))
	RegisterSignal(victim, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_hit))
	sword.melee_attack_chain(wielder, victim)
	TEST_ASSERT_EQUAL(length(hits), 0, "A fully blocked hit reached the victim.")
	TEST_ASSERT_EQUAL(length(ordinary_swings), 1, "A blocked charged strike should show one ordinary swing.")
	TEST_ASSERT_EQUAL(ordinary_swings[1], victim, "The blocked swing animated on the wrong target.")
	TEST_ASSERT(charge in wielder.vis_contents, "A miss or block consumed the charge animation.")
	TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/malice_rage/impact) in victim.vis_contents, "A block triggered the critical impact animation.")
	TEST_ASSERT_EQUAL(wielder.get_brute_loss(), brute_before_crit, "A miss or a fully blocked hit healed the wielder.")
	TEST_ASSERT_EQUAL(wielder.get_stamina_loss(), stamina_before_crit, "A miss or a fully blocked hit refunded stamina.")
	TEST_ASSERT_EQUAL(victim.get_bleed_rate(), 0, "The blocked critical caused bleeding.")
	sleep(0.3 SECONDS)
	TEST_ASSERT_EQUAL(length(victim.impact_origins), 0, "A miss or block played the critical impact.")
	TEST_ASSERT_EQUAL(victim.ordinary_impacts, ordinary_before_block + 1, "A charged block should play the ordinary blade sound once.")
	UnregisterSignal(victim, COMSIG_LIVING_CHECK_BLOCK)
	victim.damage_resistance = 50
	victim.set_body_position(STANDING_UP)
	var/strike_dir = get_dir(wielder, victim)
	victim.setDir(turn(strike_dir, 180))
	var/strike_time = world.time
	sword.melee_attack_chain(wielder, victim)
	TEST_ASSERT_EQUAL(length(hits), 1, "The critical strike should resolve as one hit.")
	TEST_ASSERT_EQUAL(length(ordinary_swings), 1, "The critical strike also showed an ordinary swing.")
	TEST_ASSERT_EQUAL(hits[1], 35, "The first unblocked hit should deal double damage before resistance.")
	TEST_ASSERT(QDELETED(charge), "The charge animation survived discharge.")
	var/obj/effect/temp_visual/malice_rage/release/release = locate() in wielder.vis_contents
	var/obj/effect/temp_visual/malice_rage/impact/impact = locate() in victim.vis_contents
	TEST_ASSERT_NOTNULL(release, "The attacking wielder did not show the release animation.")
	TEST_ASSERT_NOTNULL(impact, "The struck target did not show the impact animation.")
	TEST_ASSERT_EQUAL(release.icon_state, "strike", "The wielder did not show the special blade strike.")
	TEST_ASSERT_EQUAL(impact.icon_state, "impact", "The target did not show the critical impact.")
	for(var/obj/effect/temp_visual/effect as anything in list(release, impact))
		TEST_ASSERT_EQUAL(effect.dir, strike_dir, "The special strike was not aimed at the victim.")
		TEST_ASSERT(!(effect.vis_flags & VIS_INHERIT_DIR), "Turning during the special strike would redirect its effect.")
	var/mutable_appearance/held_blade = sword.build_worn_icon(default_icon_file = sword.lefthand_file, isinhands = TRUE)
	TEST_ASSERT_NULL(held_blade.icon, "The stationary in-hand blade was visible during the special strike.")
	var/datum/wound/slash/flesh/critical/gash = locate() in victim.all_wounds
	TEST_ASSERT_NOTNULL(gash, "The damaging critical did not cause a critical slash wound.")
	TEST_ASSERT_EQUAL(gash.limb, last_hit_limb, "The critical wounded a different limb than the blade hit.")
	var/bleed_rate = victim.get_bleed_rate()
	TEST_ASSERT(gash.blood_flow == WOUND_MAX_BLOODFLOW && bleed_rate >= BLEED_OVERLAY_GUSH, "Expected maximum wound flow and gushing blood. Wound flow [gash.blood_flow], victim rate [bleed_rate], limb [gash.limb.body_zone], body position [victim.body_position].")
	var/brute_after_crit = wielder.get_brute_loss()
	TEST_ASSERT_EQUAL(brute_after_crit, brute_before_crit - 10, "The damaging critical should heal 10 brute damage.")
	var/stamina_after_crit = wielder.get_stamina_loss()
	TEST_ASSERT_EQUAL(stamina_after_crit, stamina_before_crit - 15, "The damaging critical should restore 15 stamina.")
	TEST_ASSERT_EQUAL(victim.ordinary_impacts, ordinary_before_block + 1, "The critical strike also played the ordinary blade sound.")
	pursuer.forceMove(victim.loc)
	pursuer.damage_resistance = 50
	sword.melee_attack_chain(wielder, pursuer)
	TEST_ASSERT_EQUAL(length(ordinary_swings), 2, "The next ordinary sword swing lost its animation.")
	TEST_ASSERT_EQUAL(ordinary_swings[2], pursuer, "The ordinary swing after the critical animated on the wrong target.")
	TEST_ASSERT_EQUAL(length(hits), 2, "The next ordinary strike did not land once.")
	TEST_ASSERT_EQUAL(hits[2], 17.5, "A second hit received the same critical bonus.")
	TEST_ASSERT_EQUAL(wielder.get_brute_loss(), brute_after_crit, "A second hit healed the wielder again.")
	TEST_ASSERT_EQUAL(wielder.get_stamina_loss(), stamina_after_crit, "A second hit refunded stamina again.")
	TEST_ASSERT_EQUAL(pursuer.get_bleed_rate(), 0, "A second target received the critical's bleeding.")
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(victim.ordinary_impacts, ordinary_before_block + 2, "The swing after the critical should play the ordinary blade sound once.")
	TEST_ASSERT_EQUAL(length(victim.impact_origins), 1, "The critical and subsequent ordinary hit should produce one critical impact.")
	TEST_ASSERT_EQUAL(victim.impact_origins[1], victim.loc, "The critical impact sound did not come from the struck target.")
	TEST_ASSERT(ISINRANGE(victim.impact_times[1] - strike_time, 0.15 SECONDS, 0.25 SECONDS), "The critical impact missed the blade's contact frame.")
	held_blade = sword.build_worn_icon(default_icon_file = sword.lefthand_file, isinhands = TRUE)
	TEST_ASSERT_EQUAL(held_blade.icon, sword.lefthand_file, "The stationary blade did not return after the strike.")

	rage.ResetCooldown()
	TEST_ASSERT(rage.Trigger(wielder), "Last Rage could not be primed again.")
	charge = locate() in wielder.vis_contents
	var/turf/charge_tile = get_turf(wielder)
	var/ripple_name = "malice_ripple_[REF(charge)]"
	deadline = world.time + 1 SECONDS
	UNTIL(charge_tile.get_filter(ripple_name) || world.time >= deadline)
	TEST_ASSERT_NOTNULL(charge_tile.get_filter(ripple_name), "The charge did not ripple the floor under the wielder.")
	sword.attack_self(wielder)
	TEST_ASSERT(!(charge in wielder.vis_contents), "The folded blade still showed the charge animation.")
	TEST_ASSERT_NULL(charge_tile.get_filter(ripple_name), "Folding the blade left its ripple on the floor.")
	sword.attack_self(wielder)
	TEST_ASSERT(charge in wielder.vis_contents, "Reopening the charged blade did not restore the animation.")
	sleep(5.1 SECONDS)
	TEST_ASSERT_NULL(locate(/obj/effect/dummy/lighting_obj/moblight/malice_rage) in wielder.vis_contents, "The charge animation outlasted its five-second window.")
	TEST_ASSERT(QDELETED(release) && QDELETED(impact), "The critical's transient animations did not finish.")
	brute_before_crit = wielder.get_brute_loss()
	sword.melee_attack_chain(wielder, pursuer)
	TEST_ASSERT_EQUAL(length(hits), 3, "The strike after the expired window did not land once.")
	TEST_ASSERT_EQUAL(hits[3], 17.5, "The critical bonus survived the five-second window.")
	TEST_ASSERT_EQUAL(wielder.get_brute_loss(), brute_before_crit, "An expired charge healed the wielder.")
	TEST_ASSERT_EQUAL(pursuer.get_bleed_rate(), 0, "An expired charge inflicted bleeding.")

	ADD_TRAIT(pursuer, TRAIT_NOBLOOD, TRAIT_SOURCE_UNIT_TESTS)
	rage.ResetCooldown()
	TEST_ASSERT(rage.Trigger(wielder), "Last Rage failed to prime against a bloodless target.")
	sword.melee_attack_chain(wielder, pursuer)
	TEST_ASSERT_EQUAL(length(hits), 4, "The bloodless target did not receive a single critical strike.")
	TEST_ASSERT_EQUAL(hits[4], 35, "A bloodless target lost the double-damage critical.")
	TEST_ASSERT_EQUAL(wielder.get_brute_loss(), brute_before_crit - 10, "A critical on a bloodless target did not heal the wielder.")
	TEST_ASSERT_NULL(locate(/datum/wound/slash/flesh/critical) in pursuer.all_wounds, "The bloodless target received a bleeding wound.")

/datum/unit_test/legendary_sword_malice_rage/proc/block_hit()
	SIGNAL_HANDLER
	return SUCCESSFUL_BLOCK

/datum/unit_test/legendary_sword_malice_rage/proc/record_ordinary_swing(datum/source, atom/movable/attacker, atom/target)
	SIGNAL_HANDLER
	ordinary_swings += target

/datum/unit_test/legendary_sword_malice_rage/proc/record_hit(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber))
		hits += damage
		targets_hit += source
		last_hit_limb = def_zone

/datum/unit_test/legendary_sword_malice_omnislash
	var/list/victims = list()
	var/list/strike_tiles = list()
	var/list/strike_damage = list()
	var/list/strike_times = list()

/datum/unit_test/legendary_sword_malice_omnislash/Run()
	var/turf/start = get_ranged_target_turf(run_loc_floor_bottom_left, NORTH, 2)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent, get_ranged_target_turf(start, EAST, 4))
	var/obj/item/dualsaber/legendary_saber/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Malice.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	var/datum/action/cooldown/legendary_sword/malice_omnislash/ultimate = locate() in sword.actions
	var/datum/action/cooldown/legendary_sword/malice_dance/dance = locate() in sword.actions
	var/datum/action/cooldown/legendary_sword/malice_rage/rage = locate() in sword.actions
	TEST_ASSERT_NOTNULL(ultimate, "Malice did not grant its fourth action.")
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS + 3 MINUTES - 1
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(), 99, "Invalid pre-unlock bond for the test.")
	TEST_ASSERT(!ultimate.Trigger(wielder, target = first), "The ultimate activated before full bond.")
	sword.bond_meditation_time++
	var/list/walls = list()
	for(var/turf/tile in block(get_step(run_loc_floor_bottom_left, EAST), get_ranged_target_turf(get_step(run_loc_floor_bottom_left, EAST), NORTH, 4)))
		walls += allocate(/obj/structure/falsewall, tile)
	TEST_ASSERT(!ultimate.Trigger(wielder, target = first), "Malice began its sequence through a sealed wall.")
	QDEL_LIST(walls)
	var/mob/living/carbon/human/consistent/ally = allocate(/mob/living/carbon/human/consistent, get_step(first, NORTH))
	ally.add_ally(wielder)
	RegisterSignal(ally, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_strike))
	TEST_ASSERT(!ultimate.Trigger(wielder, target = ally), "Malice accepted a registered ally as its first target.")
	TEST_ASSERT(dance.Trigger(wielder), "Could not start the dance.")
	TEST_ASSERT(!ultimate.Trigger(wielder, target = first), "The ultimate overlapped an active dance.")
	qdel(wielder.has_status_effect(/datum/status_effect/malice_dance))
	dance.ResetCooldown()

	// A modified sword and partial resistance expose fixed damage and accidental Rage crits.
	sword.two_hand_force = 32
	sword.wound_bonus = CANT_WOUND
	first.damage_resistance = 87.5
	ADD_TRAIT(first, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	RegisterSignal(first, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_strike))
	TEST_ASSERT(rage.Trigger(wielder), "Could not prepare Last Rage before the ultimate.")
	var/original_rage_deadline = rage.rage_until
	TEST_ASSERT(ultimate.Trigger(wielder, target = first), "A reachable target four tiles away could not be selected.")
	TEST_ASSERT_EQUAL(ultimate.next_use_time, world.time + 120 SECONDS, "Wrong ultimate cooldown.")
	TEST_ASSERT_EQUAL(length(victims), 1, "The first cut did not land immediately.")
	TEST_ASSERT_EQUAL(victims[1], first, "The first cut missed the selected target.")
	var/obj/effect/temp_visual/malice_rage/harvest/opening_cut = locate() in first.vis_contents
	TEST_ASSERT_EQUAL(opening_cut?.icon_state, "rising", "The opening cut did not show its rising arc on the target.")
	TEST_ASSERT_EQUAL(opening_cut?.dir, wielder.dir, "The opening arc faced away from the cut.")
	TEST_ASSERT(!dance.Trigger(wielder), "The dance overlapped an active ultimate.")
	sword.melee_attack_chain(wielder, first)
	TEST_ASSERT_EQUAL(length(victims), 1, "The bearer could add manual attacks during the ultimate.")
	var/direct_damage = wielder.apply_damage(20, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = WEST, attacking_item = sword)
	TEST_ASSERT_EQUAL(direct_damage, 1, "The active ultimate did not reduce a direct hit to 5%.")
	var/deadline = world.time + 7 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/malice_omnislash) || world.time >= deadline)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_omnislash), "The sequence did not finish.")
	TEST_ASSERT_EQUAL(length(victims), 10, "A lone target should receive all ten cuts.")
	TEST_ASSERT(!(ally in victims), "The sequence bounced to the friendly bystander.")
	TEST_ASSERT(length(strike_tiles) > 1, "Malice never changed sides during its duel.")
	var/series_time = strike_times[10] - strike_times[1]
	TEST_ASSERT(series_time >= 2.5 SECONDS && series_time <= 3.2 SECONDS, "Ten cuts at 0.3s intervals took [series_time / 10]s.")
	TEST_ASSERT(locate(/obj/effect/temp_visual/malice_rage/harvest/finish) in first.vis_contents, "The tenth cut did not show the finisher on the target.")
	for(var/damage in strike_damage)
		TEST_ASSERT_EQUAL(damage, 4, "An automatic cut did not use the current blade force and target resistance.")
	TEST_ASSERT_EQUAL(rage.rage_until, original_rage_deadline, "An automatic cut consumed the prepared Last Rage.")

	victims.Cut()
	first.set_brute_loss(0)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent, get_step(first, NORTH))
	RegisterSignal(second, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_strike))
	ultimate.ResetCooldown()
	TEST_ASSERT(ultimate.Trigger(wielder, target = second), "Could not start the second sequence.")
	TEST_ASSERT_EQUAL(length(victims), 1, "The second sequence did not land its first hit.")
	TEST_ASSERT_EQUAL(victims[1], second, "The group sequence did not start on the clicked target.")
	deadline = world.time + 1 SECONDS
	UNTIL(length(victims) >= 2 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(victims), 2, "The second slash did not occur.")
	TEST_ASSERT_EQUAL(victims[2], first, "The sequence did not jump to the other nearby target.")
	TEST_ASSERT(locate(/obj/effect/temp_visual/malice_rage/harvest/falling) in first.vis_contents, "The second cut did not show its falling arc on the new target.")
	wielder.dropItemToGround(sword)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_omnislash), "Disarming Malice left the sequence active.")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(length(victims), 2, "A pending cut landed after disarm.")
	direct_damage = wielder.apply_damage(20, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = WEST, attacking_item = sword)
	TEST_ASSERT_EQUAL(direct_damage, 20, "The bearer retained protection after disarm.")

	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not reequip the disarmed sword.")
	sword.attack_self(wielder)
	ultimate.ResetCooldown()
	TEST_ASSERT(ultimate.Trigger(wielder, target = first), "Could not start the sequence for the critical-state check.")
	wielder.set_stat(SOFT_CRIT)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_omnislash), "Entering soft critical did not stop the ultimate immediately.")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(length(victims), 3, "Another cut landed after entering soft critical.")

/datum/unit_test/legendary_sword_malice_omnislash/proc/record_strike(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber))
		victims += source
		strike_tiles |= get_turf(attacking_item)
		strike_damage += damage
		strike_times += world.time

/datum/unit_test/legendary_sword_malice_guard/Run()
	var/turf/start = get_step(get_step(run_loc_floor_bottom_left, NORTHEAST), NORTHEAST)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent, get_step(start, NORTH))
	var/obj/item/dualsaber/legendary_saber/sword = EASY_ALLOCATE()
	// A blunt blow to the chest can knock down and turn the wielder between direction checks.
	var/obj/item/knife/weapon = EASY_ALLOCATE()
	weapon.force = 5
	weapon.wound_bonus = CANT_WOUND
	TEST_ASSERT(attacker.put_in_active_hand(weapon), "Could not equip the attacker's weapon.")
	attacker.set_combat_mode(TRUE)
	wielder.mind_initialize()
	wielder.mind.centcom_role = LEGENDARY_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Malice.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	sword.block_chance = 0 // Only the guard can block the opening cuts.
	var/datum/action/cooldown/legendary_sword/malice_guard/guard = locate() in sword.actions
	var/datum/action/cooldown/legendary_sword/malice_dance/dance = locate() in sword.actions
	TEST_ASSERT_NOTNULL(guard, "Malice did not grant its guard action.")
	TEST_ASSERT_EQUAL(guard.button_icon_state, "malice_guard", "Malice's guard uses the wrong icon.")
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS + 3 MINUTES - 1
	TEST_ASSERT(!guard.Trigger(wielder), "The guard activated before reaching full bond.")
	sword.bond_meditation_time++
	TEST_ASSERT(guard.Trigger(wielder), "The guard did not activate at full bond.")
	var/started = world.time
	var/datum/status_effect/malice_guard/stance = wielder.has_status_effect(/datum/status_effect/malice_guard)
	var/datum/sound_token/guard_sound = stance?.spin_sound
	TEST_ASSERT_EQUAL(guard_sound?.source, wielder, "The guard's rotation sound did not start on the bearer before the first block.")
	TEST_ASSERT_EQUAL(guard_sound.sound.file, 'modular_bandastation/weapon/sound/melee/malice_guard_spin.ogg', "The guard started the wrong rotation sound.")
	TEST_ASSERT_EQUAL(guard.next_use_time, started + 30 SECONDS, "Wrong cooldown for the guard.")
	TEST_ASSERT(!dance.Trigger(wielder), "The offensive spin overlapped the guard.")
	sword.melee_attack_chain(wielder, attacker)
	TEST_ASSERT_EQUAL(attacker.get_brute_loss(), 0, "The bearer attacked while guarding.")
	wielder.setDir(NORTH)
	for(var/direction in list(NORTHWEST, NORTH, NORTHEAST, EAST, WEST, SOUTHWEST, SOUTH, SOUTHEAST))
		attacker.forceMove(get_step(start, direction))
		var/brute_before = wielder.get_brute_loss()
		weapon.melee_attack_chain(attacker, wielder)
		if(direction in list(NORTHWEST, NORTH, NORTHEAST))
			TEST_ASSERT_EQUAL(wielder.get_brute_loss(), brute_before, "Melee from [dir2text(direction)] bypassed the front of the guard.")
		else
			TEST_ASSERT(wielder.get_brute_loss() > brute_before, "The guard stopped melee from [dir2text(direction)] while facing north.")

	// SSexplosions keeps the epicenter on the turf until after the movable EX_ACT pass.
	var/list/previous_blast = start.explosion_throw_details
	start.explosion_throw_details = list(1, get_step(start, NORTH), 2, EXPLODE_LIGHT)
	var/front_blast = SEND_SIGNAL(wielder, COMSIG_ATOM_PRE_EX_ACT, EXPLODE_LIGHT)
	start.explosion_throw_details[2] = get_step(start, SOUTH)
	var/rear_blast = SEND_SIGNAL(wielder, COMSIG_ATOM_PRE_EX_ACT, EXPLODE_LIGHT)
	start.explosion_throw_details = previous_blast
	TEST_ASSERT(front_blast & COMPONENT_CANCEL_EX_ACT, "The guard allowed a blast from an epicenter ahead.")
	TEST_ASSERT(!(rear_blast & COMPONENT_CANCEL_EX_ACT), "The guard stopped a blast from an epicenter behind.")
	wielder.electrocute_act(5, get_step(start, NORTH))
	TEST_ASSERT_EQUAL(wielder.get_fire_loss(), 0, "The guard allowed a shock from its front.")

	// The laser started behind the bearer but is travelling south into their front after a ricochet.
	var/obj/projectile/beam/laser/laser = allocate(/obj/projectile/beam/laser, start)
	laser.starting = get_step(start, SOUTH)
	laser.set_angle(dir2angle(SOUTH))
	laser.damage = 5
	laser.wound_bonus = CANT_WOUND
	TEST_ASSERT_EQUAL(wielder.projectile_hit(laser, BODY_ZONE_CHEST), BULLET_ACT_BLOCK, "A returning laser pierced the guard.")
	TEST_ASSERT_EQUAL(stance.spin_sound, guard_sound, "A parry restarted the guard's rotation sound.")
	TEST_ASSERT_EQUAL(wielder.get_fire_loss(), 0, "The blocked laser still burned the bearer.")
	TEST_ASSERT_EQUAL(wielder.apply_damage(3, TOX), 3, "The guard absorbed damage with no incoming direction.")
	wielder.setDir(SOUTH)
	wielder.projectile_hit(laser, BODY_ZONE_CHEST)
	TEST_ASSERT(wielder.get_fire_loss() > 0, "Turning away from the laser did not expose the back.")

	var/deadline = started + 4 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/malice_guard) || world.time >= deadline)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_guard), "The guard did not expire.")
	TEST_ASSERT(QDELETED(guard_sound), "The rotation sound continued after the guard expired.")
	TEST_ASSERT(world.time >= started + 2.7 SECONDS, "The guard ended early.")
	attacker.forceMove(get_step(start, SOUTH))
	var/brute_after_guard = wielder.get_brute_loss()
	weapon.melee_attack_chain(attacker, wielder)
	TEST_ASSERT(wielder.get_brute_loss() > brute_after_guard, "Melee from the front stayed blocked after the guard ended.")

	sword.block_chance = 100 // The normal saber would always reflect this laser.
	TEST_ASSERT(wielder.check_reflect(BODY_ZONE_CHEST), "The control saber did not reflect before guarding.")
	guard.ResetCooldown()
	TEST_ASSERT(guard.Trigger(wielder), "Could not restart the guard.")
	stance = wielder.has_status_effect(/datum/status_effect/malice_guard)
	guard_sound = stance?.spin_sound
	TEST_ASSERT_NOTNULL(guard_sound, "Restarting the guard did not start a fresh rotation sound.")
	var/burn_before = wielder.get_fire_loss()
	wielder.projectile_hit(laser, BODY_ZONE_CHEST)
	TEST_ASSERT(wielder.get_fire_loss() > burn_before, "Ordinary saber reflection protected the bearer's back while guarding.")
	wielder.dropItemToGround(sword)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/malice_guard), "Disarming the bearer left the guard active.")
	TEST_ASSERT(QDELETED(guard_sound), "The guard's rotation sound continued after disarm.")
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not reequip Malice after disarm.")
	sword.attack_self(wielder)
	TEST_ASSERT(wielder.check_reflect(BODY_ZONE_CHEST), "The saber lost its ordinary reflection after the guard ended.")

#undef LEGENDARY_TEST_OFFICER_ROLE
