/// The bartender's monkey, playable with T2 or on Monkey Day.
/datum/job/pun_pun
	title = JOB_PUN_PUN
	description = "Помогайте бармену подавать напитки и еду, развлекайте гостей бара."
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	required_donator_level = DONATOR_TIER_2
	donor_unlock_trait = /datum/station_trait/job/pun_pun
	supervisors = "барменом"
	spawn_type = /mob/living/carbon/human/species/monkey/punpun
	outfit = /datum/outfit/job/pun_pun
	config_tag = "PUN_PUN"
	random_spawns_possible = FALSE
	paycheck = PAYCHECK_LOWER
	paycheck_department = ACCOUNT_CIV
	display_order = JOB_DISPLAY_ORDER_PUN_PUN
	departments_list = list(/datum/job_department/service)
	exclusive_mail_goodies = TRUE
	mail_goodies = list(
		/obj/item/food/grown/banana = 4,
		/obj/effect/spawner/random/entertainment/money_medium = 3,
		/obj/item/clothing/head/helmet/monkey_sentience = 1,
		/obj/item/book/granter/sign_language = 1,
		/obj/item/food/monkeycube = 1,
	)
	rpg_title = "Homunculus"
	allow_bureaucratic_error = FALSE
	job_flags = (STATION_JOB_FLAGS|STATION_TRAIT_JOB_FLAGS) & ~(JOB_ASSIGN_QUIRKS|JOB_REOPEN_ON_ROUNDSTART_LOSS)
	tgui_icon = FA_ICON_PAW

/datum/job/pun_pun/config_check()
	return !HAS_TRAIT(SSstation, STATION_TRAIT_PUN_PUN_GYM_DAY) && !(locate(/datum/station_trait/revenge_of_pun_pun) in SSstation.station_traits)

/datum/job/pun_pun/get_roundstart_spawn_point()
	return GLOB.the_one_and_only_punpun || ..()

/datum/job/pun_pun/get_latejoin_spawn_point()
	return GLOB.the_one_and_only_punpun || ..()

/datum/job/pun_pun/special_check_latejoin(client/latejoin)
	var/mob/living/pun_pun = GLOB.the_one_and_only_punpun
	if(!pun_pun)
		return TRUE
	return istype(pun_pun, /mob/living/carbon/human/species/monkey/punpun) && !QDELETED(pun_pun) && pun_pun.stat != DEAD && !pun_pun.key && !pun_pun.mind?.key

/datum/job/pun_pun/get_spawn_mob(client/player_client, atom/spawn_point)
	if(!player_client || !can_access_donor_job(player_client) || !special_check_latejoin(player_client))
		return
	if(GLOB.the_one_and_only_punpun)
		return spawn_point == GLOB.the_one_and_only_punpun ? spawn_point : null
	var/turf/spawn_turf = get_turf(spawn_point)
	if(spawn_turf)
		return new spawn_type(spawn_turf)

/datum/job/pun_pun/after_spawn(mob/living/carbon/human/monkey, client/player_client)
	if(!GLOB.the_one_and_only_punpun && istype(monkey, /mob/living/carbon/human/species/monkey/punpun))
		GLOB.the_one_and_only_punpun = monkey
	. = ..()
	monkey.crewlike_monkify()

/datum/job/pun_pun/get_outfit(consistent)
	if(locate(donor_unlock_trait) in SSstation.station_traits)
		return /datum/outfit/job/pun_pun/monkey_day
	return ..()

/datum/outfit/job/pun_pun
	name = "Pun Pun"
	jobtype = /datum/job/pun_pun

	id_trim = /datum/id_trim/job/pun_pun
	belt = /obj/item/modular_computer/pda/pun_pun
	uniform = /obj/item/clothing/under/suit/waiter
	shoes = null //monkeys cannot equip shoes

/datum/outfit/job/pun_pun/monkey_day
	name = "Pun Pun (Monkey Day)"
	backpack_contents = list(
		/obj/item/gun/ballistic/shotgun/monkey = 1,
		/obj/item/storage/box/beanbag = 1,
	)
