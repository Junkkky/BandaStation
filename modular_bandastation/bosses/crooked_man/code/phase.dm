/// Free, indefinite phasing on any terrain, with the boss's original bloody entrance.
/datum/action/cooldown/spell/crooked_phase
	parent_type = /datum/action/cooldown/spell/jaunt
	name = "Фаза Искажения"
	desc = "Позволяет перемещаться сквозь стены. Повторное нажатие вернёт вас в реальность."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "space_crawl"
	cooldown_time = 2 SECONDS
	spell_requirements = NONE
	jaunt_type = /obj/effect/dummy/phased_mob/spell_jaunt/k13

/datum/action/cooldown/spell/crooked_phase/can_cast_spell(feedback = TRUE)
	// Event phasing ignores teleport restrictions, including the boss's own teleport immunity.
	return isliving(owner) && get_turf(owner) && !(SEND_SIGNAL(src, COMSIG_SPELL_CAN_CAST_CHECK, feedback) & SPELL_CANCEL_CAST)

/datum/action/cooldown/spell/crooked_phase/get_caster_from_target(atom/target)
	return target

/datum/action/cooldown/spell/crooked_phase/cast(mob/living/cast_on)
	. = ..()
	if(istype(cast_on.loc, jaunt_type))
		exit_jaunt(cast_on)
		return
	var/turf/entry_turf = get_turf(cast_on)
	if(!entry_turf)
		return
	play_phase_entry(cast_on, entry_turf)
	enter_jaunt(cast_on)

/// The Crooked Man's original bloody disappearance; other phase abilities may replace the presentation.
/datum/action/cooldown/spell/crooked_phase/proc/play_phase_entry(mob/living/cast_on, turf/entry_turf)
	cast_on.visible_message(span_danger("[cast_on] издаёт жуткий хруст и рассыпается!"))
	new /obj/effect/gibspawner/generic(entry_turf)
	playsound(entry_turf, 'sound/effects/splat.ogg', 100, TRUE)
	playsound(entry_turf, 'modular_bandastation/bosses/crooked_man/sounds/sinkhole_exit.ogg', 100, TRUE)

/datum/action/cooldown/spell/crooked_phase/on_jaunt_exited(obj/effect/dummy/phased_mob/jaunt, mob/living/unjaunter)
	. = ..()
	play_phase_exit(unjaunter)
	unjaunter.update_mob_action_buttons()

/// The Crooked Man's original reappearance.
/datum/action/cooldown/spell/crooked_phase/proc/play_phase_exit(mob/living/unjaunter)
	playsound(get_turf(unjaunter), 'sound/effects/magic/cosmic_energy.ogg', 50, TRUE)
	new /obj/effect/temp_visual/space_explosion(get_turf(unjaunter))

/// Unrestricted cardinal phasing with native jaunt perspective and safe holder deletion.
/obj/effect/dummy/phased_mob/spell_jaunt/k13
	name = "искажение"
	phased_mob_icon_state = "red_1"
	movespeed = 0

/obj/effect/dummy/phased_mob/spell_jaunt/k13/Destroy()
	// A shuttle or administrator may delete the holder without calling eject_jaunter().
	if(!QDELETED(jaunter))
		jaunter.forceMove(get_turf(src) || find_safe_turf())
	return ..()

/obj/effect/dummy/phased_mob/spell_jaunt/k13/relaymove(mob/living/user, direction)
	if(user != jaunter)
		return
	var/turf/next_step = get_step(src, direction)
	if(next_step)
		forceMove(next_step)

/obj/effect/dummy/phased_mob/spell_jaunt/k13/eject_jaunter()
	// This administrative ability must also exit in teleport-restricted areas.
	if(!jaunter || !get_turf(src))
		return
	jaunter.forceMove(get_turf(src))
	qdel(src)
