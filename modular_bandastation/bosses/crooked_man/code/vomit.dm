/// Four-tile acid cone with temporary, damaging puddles.
/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone
	name = "Извержение желчи"
	desc = "Изрыгает конус кислоты, заливающий всё впереди."
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	button_icon_state = "alien_neurotoxin"
	cooldown_time = 5 SECONDS
	spell_requirements = NONE
	cone_levels = 4
	respect_density = TRUE
	delay_between_level = 0.1 SECONDS
	/// Colour of the plume in front of the caster.
	var/plume_color = "#4cff00"
	/// Sound of the eruption.
	var/cast_sound = 'modular_bandastation/bosses/crooked_man/sounds/vomit.ogg'

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/cast(atom/cast_on)
	var/turf/spawn_turf = get_step(cast_on, cast_on.dir)
	if(spawn_turf)
		var/obj/effect/temp_visual/plume = new /obj/effect/temp_visual/dir_setting/crooked_vomit(spawn_turf, cast_on.dir)
		plume.color = plume_color
	playsound(cast_on, cast_sound, 80, TRUE)
	return ..()

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/do_turf_cone_effect(turf/target_turf, atom/caster, level)
	if(!isopenturf(target_turf) || locate(/obj/effect/decal/cleanable/vomit/toxic/crooked) in target_turf)
		return
	if(prob(100 - level * 15))
		new /obj/effect/decal/cleanable/vomit/toxic/crooked(target_turf)

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/do_mob_cone_effect(mob/living/victim, atom/caster, level)
	if(victim == caster || QDELETED(caster))
		return
	victim.apply_damage(max(7.5, 17.5 - level * 2.5), TOX)
	victim.adjust_disgust(50)
	new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(victim), turn(caster.dir, 180))
	to_chat(victim, span_danger("Вас окатило зловонной желудочной кислотой!"))

/// Green splash using the existing large plume animation.
/obj/effect/temp_visual/dir_setting/crooked_vomit
	parent_type = /obj/effect/temp_visual/dir_setting/entropic
	color = "#4cff00"
	duration = 0.5 SECONDS

/// Acid underfoot that expires after ten seconds through normal qdel cleanup.
/obj/effect/decal/cleanable/vomit/toxic/crooked
	name = "желудочный сок"
	desc = "Шипящая и вонючая лужа. Она разъедает даже металл."
	color = "#4cff00"

/obj/effect/decal/cleanable/vomit/toxic/crooked/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))
	AddElement(/datum/element/connect_loc, loc_connections)
	QDEL_IN(src, 10 SECONDS)

/obj/effect/decal/cleanable/vomit/toxic/crooked/proc/on_entered(datum/source, atom/movable/entered)
	SIGNAL_HANDLER
	if(!isliving(entered))
		return
	var/mob/living/victim = entered
	if(victim.movement_type & MOVETYPES_NOT_TOUCHING_GROUND || !prob(85))
		return
	var/obj/item/bodypart/leg
	if(ishuman(victim))
		var/mob/living/carbon/human/human_victim = victim
		leg = human_victim.get_bodypart(pick(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
	victim.apply_damage(5, BURN, leg)
	playsound(victim, 'sound/effects/wounds/splatter.ogg', 50, TRUE)
	to_chat(victim, span_danger("Кислота обжигает ваши ноги!"))

/// The final fight's eruption: the cone is marked before it comes, so whoever holds him can turn him away.
/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/crooked
	cooldown_time = 10 SECONDS
	/// Wind-up during which the cone is marked on the floor.
	var/windup = 0.6 SECONDS

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/crooked/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	for(var/list/level in get_cone_turfs(get_turf(owner), owner.dir, cone_levels))
		// Steps past the map edge come back null.
		for(var/turf/marked in level)
			new /obj/effect/temp_visual/cult/sparks/crooked/acid(marked)
	if(!crooked_windup(owner, windup, src))
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/crooked/do_mob_cone_effect(mob/living/victim, atom/caster, level)
	if(victim == caster || QDELETED(caster))
		return
	victim.apply_damage(max(6, 13.5 - level * 1.5), TOX)
	victim.adjust_disgust(30)
	new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(victim), turn(caster.dir, 180))
	to_chat(victim, span_danger("Вас окатило зловонной желудочной кислотой!"))
