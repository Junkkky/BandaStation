/// One targetable portion of the dome. All segments draw on the same light.
/obj/structure/sister_dome_barrier
	name = "световой купол"
	desc = "По светящейся поверхности разбегаются волны от ударов."
	icon = 'icons/effects/effects.dmi'
	icon_state = "nothing"
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	layer = ABOVE_NORMAL_TURF_LAYER
	blocks_emissive = EMISSIVE_BLOCK_NONE
	anchored = TRUE
	move_resist = INFINITY
	density = TRUE
	can_atmos_pass = ATMOS_PASS_YES
	pass_flags_self = NONE
	flags_ricochet = NONE
	// ClickCross treats a diagonal border object as covering all sides, including for point-blank shots.
	flags_1 = ON_BORDER_1
	dir = NORTHEAST
	/// The field redirects damage from this segment to the caster's stamina.
	var/obj/effect/sister_light_dome/dome

/obj/structure/sister_dome_barrier/Initialize(mapload, obj/effect/sister_light_dome/source_dome)
	. = ..()
	if(QDELETED(source_dome))
		return INITIALIZE_HINT_QDEL
	dome = source_dome
	for(var/turf/neighbor as anything in RANGE_TURFS(1, src))
		if(!dome.contains_turf(neighbor))
			RegisterSignal(neighbor, COMSIG_ATOM_EXIT, PROC_REF(on_exterior_exit))

/obj/structure/sister_dome_barrier/Destroy()
	// Removing a segment directly (e.g. a singularity) must not leave a hole in a live field.
	if(!QDELETED(dome))
		qdel(dome)
	dome = null
	return ..()

/obj/structure/sister_dome_barrier/CanAllowThrough(atom/movable/mover, border_dir)
	return ..() || QDELETED(dome) || dome.contains_turf(get_turf(mover)) || isobserver(mover) || dome.is_admitted(mover)

/obj/structure/sister_dome_barrier/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return ..() || QDELETED(dome) || pass_info.is_observer || dome.is_admitted(pass_info.requester_ref?.resolve())

/// Intercept entry before turf.Enter chooses between an occupant and a projectile's other collision targets.
/obj/structure/sister_dome_barrier/proc/on_exterior_exit(turf/source, atom/movable/mover, direction)
	SIGNAL_HANDLER
	if(QDELETED(dome) || QDELETED(mover) || get_step(source, direction) != loc)
		return NONE
	if(isobserver(mover) || dome.is_admitted(mover))
		return NONE
	if(isprojectile(mover))
		var/obj/projectile/shot = mover
		if(shot.fired && !shot.deletion_queued)
			dome.absorb_projectile(shot, loc)
	else
		mover.Bump(src)
	return COMPONENT_ATOM_BLOCK_EXIT

/obj/structure/sister_dome_barrier/projectile_hit(obj/projectile/shot, def_zone, piercing_hit, blocked)
	if(QDELETED(dome))
		return ..()
	dome.absorb_projectile(shot, loc)
	return BULLET_ACT_BLOCK

/obj/structure/sister_dome_barrier/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	if(QDELETED(dome) || damage_amount <= 0)
		return 0
	if(sound_effect)
		playsound(src, SFX_SPARKS, 35, TRUE)
	new /obj/effect/temp_visual/impact_effect/ion/sister_dome(loc)
	dome.apply_impact(damage_amount)
	return damage_amount

/obj/structure/sister_dome_barrier/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !user.combat_mode || HAS_TRAIT(user, TRAIT_PACIFISM))
		return
	var/obj/item/bodypart/hand = user.get_active_hand()
	if(hand)
		attack_generic(user, rand(hand.unarmed_damage_low, hand.unarmed_damage_high), BRUTE, MELEE)
