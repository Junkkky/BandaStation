/// Powered compartments of the standard M patrol destroyer.
/area/shuttle/stationtrauma_space/nt_patrol
	name = "Патрульный эсминец НТ"
	icon = 'modular_bandastation/space_overmap/icons/nt_patrol_areas.dmi'
	icon_state = "hull"
	requires_power = TRUE

/// Bridge and communications.
/area/shuttle/stationtrauma_space/nt_patrol/bridge
	name = "Эсминец НТ: мостик"
	icon_state = "bridge"

/// Treatment and medical supplies.
/area/shuttle/stationtrauma_space/nt_patrol/medbay
	name = "Эсминец НТ: медотсек"
	icon_state = "medbay"

/// Patrol muster and bunks.
/area/shuttle/stationtrauma_space/nt_patrol/barracks
	name = "Эсминец НТ: казарма"
	icon_state = "barracks"

/// Shared crew mess.
/area/shuttle/stationtrauma_space/nt_patrol/mess
	name = "Эсминец НТ: кают-компания"
	icon_state = "mess"

/// Patrol equipment kept behind the armory airlock.
/area/shuttle/stationtrauma_space/nt_patrol/armory
	name = "Эсминец НТ: оружейная"
	icon_state = "armory"

/obj/item/encryptionkey/nt_patrol
	name = "NT patrol encryption key"
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1
	channels = list(RADIO_CHANNEL_NT_PATROL = 1)
	special_channels = RADIO_SPECIAL_NT_PATROL

/obj/item/radio/headset/nt_patrol
	name = "NT patrol headset"
	keyslot = /obj/item/encryptionkey/nt_patrol

/// Crew movement and standard boarding hatches.
/area/shuttle/stationtrauma_space/nt_patrol/passage
	name = "Эсминец НТ: коридор"
	icon_state = "passage"

/// Power, atmosphere and drive machinery.
/area/shuttle/stationtrauma_space/nt_patrol/engineering
	name = "Эсминец НТ: машинное отделение"
	icon_state = "engineering"

/// EVA storage and the separate surface airlock.
/area/shuttle/stationtrauma_space/nt_patrol/eva
	name = "Эсминец НТ: шлюз"
	icon_state = "eva"

/// Exterior engine mounts travel with the hull and remain in vacuum.
/area/shuttle/stationtrauma_space/nt_patrol/exterior
	name = "Эсминец НТ: наружная обшивка"
	icon_state = "exterior"
	requires_power = FALSE
	monitored_compartment = FALSE
	vacuum_by_design = TRUE

/// The reactor's lateral fitting transfers heat into the independent nitrogen loop.
/obj/machinery/atmospherics/components/unary/heat_exchanger/nt_patrol_coolant
	name = "теплообменник реактора"
	piping_layer = PIPING_LAYER_MAX

/// The powered chiller keeps the coolant below the heat transfer limit.
/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/nt_patrol_coolant
	name = "охладитель реактора"
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1
	piping_layer = PIPING_LAYER_MAX
	target_temperature = 230

/// A reserve of nitrogen independent from both the crew air and the reactor's fuel.
/obj/machinery/atmospherics/components/tank/nitrogen/nt_patrol_coolant
	name = "бак теплоносителя (азот)"
	piping_layer = PIPING_LAYER_MAX
	starting_pressure_percent = 0.02

/// Cryogenic chamber whose front tile is the ship's latejoin arrival point.
/obj/machinery/cryopod/away_mission

/obj/machinery/cryopod/away_mission/erase_crew_manifest_record(mob/living/target)
	if(target.mind?.assigned_role.job_flags & JOB_CREW_MANIFEST)
		return ..()

/// Transponder identity carried by the controller board.
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/patrol
	callsign = "Патруль НТ"
	build_path = /obj/machinery/computer/stationtrauma_transponder/nt_patrol

/// Installed Nanotrasen patrol transponder.
/obj/machinery/computer/stationtrauma_transponder/nt_patrol
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/nt/patrol
