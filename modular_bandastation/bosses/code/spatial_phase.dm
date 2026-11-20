/// Independently granted administrative ability reusing only the Crooked Man's phase mechanics.
/datum/action/cooldown/spell/spatial_phase
	parent_type = /datum/action/cooldown/spell/crooked_phase
	name = "Пространственная фаза"
	desc = "Переход в фазу с фиолетовой вспышкой. Повторное нажатие вернёт вас в реальность."

/datum/action/cooldown/spell/spatial_phase/play_phase_entry(mob/living/cast_on, turf/entry_turf)
	cast_on.visible_message(span_notice("Силуэт [cast_on] мерцает и исчезает."))
	new /obj/effect/temp_visual/spatial_phase(entry_turf)
	playsound(entry_turf, 'sound/effects/phasein.ogg', 40, FALSE, frequency = 0.8)

/datum/action/cooldown/spell/spatial_phase/play_phase_exit(mob/living/unjaunter)
	new /obj/effect/temp_visual/spatial_phase(get_turf(unjaunter))
	playsound(get_turf(unjaunter), 'sound/effects/phasein.ogg', 40, FALSE, frequency = 0.8)

/// Half-second violet flash for entering and leaving the administrative phase.
/obj/effect/temp_visual/spatial_phase
	parent_type = /obj/effect/temp_visual/cosmic_explosion
	color = COLOR_VIOLET
	light_range = 2
	light_color = LIGHT_COLOR_PURPLE
