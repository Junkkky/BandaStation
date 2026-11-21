/datum/action/cooldown/legendary_sword/malice_guard
	name = "Заслон Злобы"
	desc = "Восемь секунд вы вращаете клинок перед собой. Он блокирует атаки спереди и по передним диагоналям. Можно двигаться и поворачиваться. Бока и спина открыты."
	button_icon_state = "malice_guard"
	required_bond = 100
	cooldown_time = 30 SECONDS

/datum/action/cooldown/legendary_sword/malice_guard/Activate(atom/target)
	var/mob/living/user = owner
	if(!user?.apply_status_effect(/datum/status_effect/malice_guard, saber, required_bond))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/malice_guard
	parent_type = /datum/status_effect/legendary_sword_sequence
	id = "malice_sequence"
	duration = 8 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	/// The animated blade replaces its resting in-hand pose for this stance.
	var/mutable_appearance/spinning_blade
	/// Tracks the spinning blade independently of individual parry sounds.
	var/datum/sound_token/spin_sound

/datum/status_effect/malice_guard/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond)
	if(!..())
		return FALSE
	animate(owner, tag = "malice_flip")
	saber.in_malice_guard = TRUE
	RegisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS, PROC_REF(hide_resting_blade))
	RegisterSignal(owner, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_attack))
	RegisterSignal(owner, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(block_projectile))
	RegisterSignal(owner, COMSIG_ATOM_PREHITBY, PROC_REF(block_throw))
	RegisterSignal(owner, COMSIG_ATOM_PRE_EX_ACT, PROC_REF(block_blast))
	RegisterSignal(owner, COMSIG_LIVING_ELECTROCUTE_ACT, PROC_REF(block_shock))
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(block_directed_damage))
	spinning_blade = mutable_appearance('modular_bandastation/weapon/icons/melee/malice_guard.dmi', "guard", ABOVE_MOB_LAYER)
	spinning_blade.pixel_x = -16
	spinning_blade.pixel_y = -16
	owner.add_overlay(spinning_blade)
	spin_sound = new(owner, 'modular_bandastation/weapon/sound/melee/malice_guard_spin.ogg', SOUND_RANGE, 38, _repeating = TRUE)
	owner.update_held_items()
	owner.visible_message(span_warning("[capitalize(owner.declent_ru(NOMINATIVE))] раскручивает Злобу перед собой, прикрываясь клинком!"))
	return TRUE

/datum/status_effect/malice_guard/on_remove()
	QDEL_NULL(spin_sound)
	if(spinning_blade)
		UnregisterSignal(owner, list(COMSIG_LIVING_CHECK_BLOCK, COMSIG_ATOM_PRE_BULLET_ACT, COMSIG_ATOM_PREHITBY, COMSIG_ATOM_PRE_EX_ACT, COMSIG_LIVING_ELECTROCUTE_ACT, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS))
		UnregisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS)
		saber.in_malice_guard = FALSE
		owner.cut_overlay(spinning_blade)
		spinning_blade = null
		owner.update_held_items()
	return ..()

/datum/status_effect/malice_guard/proc/hide_resting_blade(obj/item/source, list/overlays, mutable_appearance/draw_target, isinhands)
	SIGNAL_HANDLER
	if(isinhands && source.loc == owner)
		draw_target.icon = null
		overlays.Cut()

/// Find the side the hit arrived from. A reflected shot can come from behind its original firer.
/datum/status_effect/malice_guard/proc/incoming_side(atom/threat)
	if(!isatom(threat))
		return NONE
	var/turf/origin = get_turf(threat)
	if(isprojectile(threat))
		var/obj/projectile/shot = threat
		if(shot.firer == owner && shot.original == owner)
			return NONE
		if(!isnull(shot.angle))
			return REVERSE_DIR(angle2dir(shot.angle))
		if(!origin || origin == owner.loc)
			origin = shot.starting || get_turf(shot.firer)
	return origin?.z == owner.z ? get_dir(owner, origin) : NONE

/datum/status_effect/malice_guard/proc/covers(side)
	return side && (side == owner.dir || side == turn(owner.dir, 45) || side == turn(owner.dir, -45)) && can_continue()

/datum/status_effect/malice_guard/proc/deflect(side)
	if(!covers(side))
		return FALSE
	playsound(owner, 'modular_bandastation/weapon/sound/melee/malice_guard_block.ogg', BLOCK_SOUND_VOLUME, FALSE)
	return TRUE

/datum/status_effect/malice_guard/proc/block_attack(datum/source, atom/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type, attack_flag, atom/attack_origin)
	SIGNAL_HANDLER
	if(deflect(incoming_side(attack_origin || hit_by)))
		return SUCCESSFUL_BLOCK

/datum/status_effect/malice_guard/proc/block_projectile(datum/source, obj/projectile/shot)
	SIGNAL_HANDLER
	if(deflect(incoming_side(shot)))
		return COMPONENT_BULLET_BLOCKED

/datum/status_effect/malice_guard/proc/block_throw(datum/source, atom/movable/thrown, datum/thrownthing/throw_info)
	SIGNAL_HANDLER
	if(deflect(incoming_side(throw_info?.starting_turf || thrown)))
		return COMSIG_HIT_PREVENTED

/datum/status_effect/malice_guard/proc/block_blast(datum/source, severity, atom/target, atom/origin)
	SIGNAL_HANDLER
	if(!origin)
		// Queued explosions store their epicenter on the turf until throws are processed.
		var/turf/tile = get_turf(owner)
		if(tile?.explosion_throw_details?[4] == severity)
			origin = tile.explosion_throw_details[2]
	if(deflect(incoming_side(origin)))
		return COMPONENT_CANCEL_EX_ACT

/datum/status_effect/malice_guard/proc/block_shock(datum/source, shock_damage, atom/shock_source)
	SIGNAL_HANDLER
	if(deflect(incoming_side(shock_source)))
		return COMPONENT_LIVING_BLOCK_SHOCK

/datum/status_effect/malice_guard/proc/block_directed_damage(datum/source, list/modifiers, damage, damage_type, def_zone, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	// Projectile damage passes a direction from the original firing tile, even after a ricochet.
	var/side = !isnull(attack_direction) && !isprojectile(attacking_item) ? REVERSE_DIR(attack_direction) : incoming_side(attacking_item)
	if(damage > 0 && covers(side))
		modifiers += 0

/obj/item/dualsaber/legendary_saber
	/// While the blade is spinning in front, it cannot also perform its usual all-around parry.
	var/in_malice_guard = FALSE

/obj/item/dualsaber/legendary_saber/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, final_block_chance, damage, attack_type, damage_type)
	if(in_malice_guard)
		return FALSE
	return ..()

/obj/item/dualsaber/legendary_saber/IsReflect()
	if(in_malice_guard)
		return FALSE
	return ..()
