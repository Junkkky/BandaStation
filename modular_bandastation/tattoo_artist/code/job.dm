/datum/job/tattoo_artist
	title = JOB_TATTOO_ARTIST
	alternate_titles = list(JOB_TATTOO_ARTIST_RU)
	description = "Обсудите эскиз с клиентом, подготовьте кожу и нанесите рисунок тату-машинкой. В конце сеанса закройте татуировку защитной плёнкой."
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	required_donator_level = DONATOR_TIER_1
	supervisors = JOB_HEAD_OF_PERSONNEL_RU
	config_tag = "TATTOO_ARTIST"
	exp_granted_type = EXP_TYPE_CREW
	outfit = /datum/outfit/job/tattoo_artist
	plasmaman_outfit = /datum/outfit/plasmaman/curator
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_SRV
	display_order = JOB_DISPLAY_ORDER_TATTOO_ARTIST
	departments_list = list(/datum/job_department/service)
	job_flags = STATION_JOB_FLAGS
	tgui_icon = FA_ICON_PEN_NIB

/datum/job/tattoo_artist/get_default_roundstart_spawn_point()
	return get_latejoin_spawn_point()

/datum/outfit/job/tattoo_artist
	name = JOB_TATTOO_ARTIST
	jobtype = /datum/job/tattoo_artist
	id_trim = /datum/id_trim/job/tattoo_artist
	uniform = /obj/item/clothing/under/color/black
	suit = /obj/item/clothing/suit/apron
	gloves = /obj/item/clothing/gloves/latex/nitrile
	ear_right = /obj/item/radio/headset/headset_srv
	l_pocket = /obj/item/tattoo_machine
	backpack_contents = list(/obj/item/storage/box/tattoo_studio = 1, /obj/item/tattoo_mannequin = 1)

/datum/id_trim/job/tattoo_artist
	assignment = JOB_TATTOO_ARTIST_RU
	job = /datum/job/tattoo_artist
	trim_state = "trim_assistant"
	department_color = COLOR_SERVICE_LIME
	subdepartment_color = COLOR_SERVICE_LIME
	sechud_icon_state = SECHUD_ASSISTANT
	minimal_access = list(ACCESS_SERVICE)
	template_access = list(ACCESS_CAPTAIN, ACCESS_CHANGE_IDS, ACCESS_HOP)
