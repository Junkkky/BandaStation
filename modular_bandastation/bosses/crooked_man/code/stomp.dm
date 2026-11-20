/// Destructive shockwave affecting nearby mobs, structures and walls.
/datum/action/cooldown/spell/aoe/ability_stomp
	name = "Топот"
	desc = "Отбрасывает стоящих рядом и сокрушает стены."
	button_icon = 'modular_bandastation/bosses/crooked_man/icons/abilities.dmi'
	button_icon_state = "destructive_wail"
	cooldown_time = 3 SECONDS
	spell_requirements = NONE
	/// Effect shown under the caster.
	var/stomp_visual = /obj/effect/temp_visual/crooked_stomp

/datum/action/cooldown/spell/aoe/ability_stomp/cast(atom/cast_on)
	. = ..()
	new stomp_visual(get_turf(cast_on))
	playsound(cast_on, 'sound/effects/magic/repulse.ogg', 80, TRUE)

/datum/action/cooldown/spell/aoe/ability_stomp/cast_on_thing_in_aoe(atom/victim, atom/caster)
	if(QDELETED(victim) || victim == caster)
		return
	if(isliving(victim))
		var/mob/living/living_victim = victim
		living_victim.take_overall_damage(20, 0)
		living_victim.throw_at(get_edge_target_turf(living_victim, get_dir(caster, living_victim)), 3, 2)
	else if(isstructure(victim))
		var/obj/structure/structure_victim = victim
		structure_victim.take_damage(60, BRUTE, BOMB, 0)
	else if(iswallturf(victim) && prob(40))
		var/turf/closed/wall/wall_victim = victim
		wall_victim.dismantle_wall(TRUE)

/// A one-second stomp flash; duration is set before Initialize schedules deletion.
/obj/effect/temp_visual/crooked_stomp
	parent_type = /obj/effect/temp_visual/mech_attack_aoe_attack
	color = COLOR_RED
	duration = 1 SECONDS
