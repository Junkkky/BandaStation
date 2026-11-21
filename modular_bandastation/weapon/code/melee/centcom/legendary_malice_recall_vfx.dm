/obj/effect/temp_visual/malice_recall_departure
	icon = 'modular_bandastation/weapon/icons/melee/malice_recall.dmi'
	icon_state = "departure"
	randomdir = FALSE
	duration = 0.6 SECONDS

/obj/effect/temp_visual/malice_recall_departure/Initialize(mapload)
	. = ..()
	flick(icon_state, src)

/obj/effect/temp_visual/malice_recall_arrival
	icon = 'modular_bandastation/weapon/icons/melee/malice_recall.dmi'
	icon_state = "arrival"
	randomdir = FALSE
	duration = 0.6 SECONDS

/obj/effect/temp_visual/malice_recall_arrival/Initialize(mapload)
	. = ..()
	flick(icon_state, src)
