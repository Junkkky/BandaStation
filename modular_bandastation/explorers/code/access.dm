/datum/id_trim/job/explorer
	assignment = JOB_EXPLORER_RU
	trim_state = "trim_explorer"
	department_color = "#665374"
	subdepartment_color = RADIO_COLOR_EXPEDITION
	sechud_icon_state = SECHUD_EXPLORER
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	template_access = list(ACCESS_CAPTAIN, ACCESS_CHANGE_IDS, ACCESS_EXPEDITION_LEADER)
	job = /datum/job/explorer

/datum/id_trim/job/explorer/leader
	assignment = JOB_EXPEDITION_LEADER_RU
	trim_state = "trim_expedition_leader"
	department_state = "departmenthead"
	sechud_icon_state = "hudexpedition_leader"
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_LEADER,
		ACCESS_EXPEDITION_PILOT,
		ACCESS_EXPEDITION_MEDIC,
		ACCESS_EXPEDITION_ENGINEER,
		ACCESS_COMMAND,
		ACCESS_RC_ANNOUNCE,
		ACCESS_KEYCARD_AUTH,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	template_access = list(ACCESS_CAPTAIN, ACCESS_CHANGE_IDS)
	job = /datum/job/explorer/leader

/datum/id_trim/job/explorer/pilot
	assignment = JOB_EXPEDITION_PILOT_RU
	trim_state = "trim_expedition_pilot"
	sechud_icon_state = "hudexpedition_pilot"
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_PILOT,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	job = /datum/job/explorer/pilot

/datum/id_trim/job/explorer/medic
	assignment = JOB_EXPEDITION_MEDIC_RU
	trim_state = "trim_expedition_medic"
	subdepartment_color = COLOR_MEDICAL_BLUE
	sechud_icon_state = "hudexpedition_medic"
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_MEDIC,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	job = /datum/job/explorer/medic

/datum/id_trim/job/explorer/engineer
	assignment = JOB_EXPEDITION_ENGINEER_RU
	trim_state = "trim_expedition_engineer"
	subdepartment_color = COLOR_ENGINEERING_ORANGE
	sechud_icon_state = "hudexpedition_engineer"
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_ENGINEER,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	job = /datum/job/explorer/engineer
