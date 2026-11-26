#define SISTER_STING_RANGE 7
#define SISTER_STING_ICON 'modular_bandastation/weapon/icons/melee/sister_sting.dmi'

/datum/action/cooldown/legendary_sword/sister_sting
	name = "Серебряное жало"
	desc = "Бросьте Светлую Сестру на расстояние до семи клеток. Клинок можно отбить. Застрявший меч замедляет цель и каждые две секунды наносит урон и вызывает кровотечение. Пострадавший может вытащить его за четыре секунды."
	button_icon = 'modular_bandastation/weapon/icons/melee/sister_sting_action.dmi'
	button_icon_state = "sister_sting"
	required_bond = 50
	click_to_activate = TRUE
	cooldown_time = 25 SECONDS

/datum/action/cooldown/legendary_sword/sister_sting/Activate(atom/target)
	var/mob/living/user = owner
	if(!saber?.can_use_legendary_ability(user, required_bond) || HAS_TRAIT(user, TRAIT_PACIFISM))
		return FALSE
	if(!isturf(user.loc) || !(isturf(target) || (isliving(target) && isturf(target.loc))))
		return FALSE
	if(target.z != user.z || !get_dist(user, target) || get_dist(user, target) > SISTER_STING_RANGE || !is_in_sight(user, target))
		to_chat(user, span_warning("Выберите видимую цель в пределах семи клеток."))
		return FALSE
	var/hand_index = user.get_held_index_of_item(saber)
	// The release cue includes this blade's power-down. Dropping it normally still plays its own sound.
	var/datum/component/two_handed/grip = saber.GetComponent(/datum/component/two_handed)
	var/unwield_sound = grip.unwieldsound
	grip.unwieldsound = null
	var/released = user.transfer_item_to_turf(saber, user.loc, silent = TRUE)
	grip.unwieldsound = unwield_sound
	if(!released)
		return FALSE
	if(!saber.throw_at(target, SISTER_STING_RANGE, 1.5, user, spin = FALSE, quickstart = FALSE, throw_type_path = /datum/thrownthing/sister_sting))
		if(saber.loc == user.loc && user.put_in_hand(saber, hand_index))
			saber.attack_self(user)
		return FALSE
	playsound(user, 'modular_bandastation/weapon/sound/melee/sister_sting_throw.ogg', 55, FALSE)
	StartCooldown()
	return TRUE

/obj/item/dualsaber/legendary_saber/sister
	embed_type = /datum/embedding/sister_sting
	/// Kept until landing finishes, including the native zero-gravity drift check.
	var/datum/thrownthing/sister_sting/sting_flight

/// Native throws can fly past their destination in zero gravity. Stop before the next collision check.
/obj/item/dualsaber/legendary_saber/sister/Move(atom/newloc, direct, glide_size_override = 0, update_dir = TRUE)
	if(sting_flight && throwing == sting_flight && (loc == sting_flight.target_turf || sting_flight.dist_travelled >= sting_flight.maxrange))
		return FALSE
	return ..()

/// Landing a charged throw produces no residual impulse. Gravity still handles falls normally.
/obj/item/dualsaber/legendary_saber/sister/newtonian_move(inertia_angle, instant = FALSE, start_delay = 0, drift_force = 1 NEWTONS, controlled_cap = null, force_loop = TRUE)
	if(sting_flight)
		return FALSE
	return ..()

/// Embedding already played the Sting impact. Other throws retain their usual hit sound.
/obj/item/dualsaber/legendary_saber/sister/mob_throw_hit_sound_chain(target, volume)
	if(sting_flight && get_embed()?.owner == target)
		return TRUE
	return ..()

/// The actual weapon travels through the map and uses the normal hitby/block pipeline.
/datum/thrownthing/sister_sting
	var/original_icon
	var/original_throwforce
	var/original_turn_on_move

/datum/thrownthing/sister_sting/New(obj/item/dualsaber/legendary_saber/sister/sword, target, init_dir, maxrange, speed, thrower, diagonals_first, force, gentle, callback, target_zone)
	. = ..()
	src.maxrange = min(src.maxrange, SISTER_STING_RANGE)
	sword.sting_flight = src
	original_icon = sword.icon
	original_throwforce = sword.throwforce
	original_turn_on_move = sword.set_dir_on_move
	sword.set_dir_on_move = FALSE
	sword.setDir(init_dir)
	sword.icon = SISTER_STING_ICON
	sword.icon_state = "flight"
	sword.pixel_w -= 16
	sword.pixel_z -= 16
	sword.throwforce = 15
	ADD_TRAIT(sword, TRAIT_UNCATCHABLE, REF(src))

/datum/thrownthing/sister_sting/Destroy()
	var/obj/item/dualsaber/legendary_saber/sister/sword = thrownthing
	if(!QDELETED(sword))
		REMOVE_TRAIT(sword, TRAIT_UNCATCHABLE, REF(src))
		sword.sting_flight = null
		sword.icon = original_icon
		sword.throwforce = original_throwforce
		sword.set_dir_on_move = original_turn_on_move
		sword.pixel_w += 16
		sword.pixel_z += 16
		sword.update_appearance(UPDATE_ICON_STATE)
	return ..()

/// A physical shard for examine, surgery and removal, armed only by a Silver Sting throw.
/datum/embedding/sister_sting
	embed_chance = 100
	embedded_bleed_rate = 3.5
	ignore_throwspeed_threshold = TRUE
	fall_chance = 0
	pain_chance = 0
	jostle_chance = 0
	impact_pain_mult = 0
	remove_pain_mult = 1
	rip_time = 2 SECONDS // The extinguished sword has weight class two.
	var/flight_dir
	var/seconds_embedded = 0
	var/obj/effect/sister_sting_embedded/blade_visual

/datum/embedding/sister_sting/try_embed(obj/item/weapon, mob/living/carbon/victim, hit_zone, blocked, datum/thrownthing/throwingdatum)
	if(!istype(throwingdatum, /datum/thrownthing/sister_sting) || !istype(victim) || victim.stat == DEAD || owner)
		return
	flight_dir = throwingdatum.init_dir
	return ..()

/datum/embedding/sister_sting/on_successful_embed(mob/living/carbon/victim, obj/item/bodypart/target_limb)
	seconds_embedded = 0
	victim.apply_status_effect(/datum/status_effect/grouped/sister_sting, REF(src))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(drop_from_victim))
	blade_visual = new(victim)
	blade_visual.setDir(flight_dir)
	victim.vis_contents += blade_visual
	playsound(victim, 'modular_bandastation/weapon/sound/melee/sister_sting_hit.ogg', 55, FALSE)

/datum/embedding/sister_sting/process_effect(seconds_per_tick)
	if(owner.stat == DEAD)
		return TRUE
	seconds_embedded += seconds_per_tick
	if(seconds_embedded >= 2)
		seconds_embedded -= 2
		owner.apply_damage(4, BRUTE, owner_limb, wound_bonus = CANT_WOUND, attacking_item = parent)
		// Non-human carbons have no blood life tick to drain the embedded limb's bleed rate.
		if(!QDELETED(owner) && !ishuman(owner) && owner_limb?.can_bleed())
			owner.bleed(2 * embedded_bleed_rate)
	return TRUE

/datum/embedding/sister_sting/stop_embedding()
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
	owner?.remove_status_effect(/datum/status_effect/grouped/sister_sting, REF(src))
	QDEL_NULL(blade_visual)
	return ..()

/datum/embedding/sister_sting/proc/drop_from_victim(mob/living/carbon/victim)
	SIGNAL_HANDLER
	if(!stop_embedding())
		parent.forceMove(victim.drop_location())

/// Pulling it free drops the sword; only a deliberate pickup should test its ownership lock.
/datum/embedding/sister_sting/remove_embedding(mob/living/to_hands)
	return ..(null)

/datum/status_effect/grouped/sister_sting
	id = "sister_sting"
	tick_interval = STATUS_EFFECT_NO_TICK

/datum/status_effect/grouped/sister_sting/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/sister_sting)
	return TRUE

/datum/status_effect/grouped/sister_sting/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/sister_sting)
	return ..()

/datum/movespeed_modifier/sister_sting
	multiplicative_slowdown = 1

/// Shows the guard and point on opposite sides of the body in the direction of impact.
/obj/effect/sister_sting_embedded
	name = "пронзивший клинок"
	icon = SISTER_STING_ICON
	icon_state = "embedded"
	pixel_x = -16
	pixel_y = -16
	layer = ABOVE_MOB_LAYER
	vis_flags = VIS_INHERIT_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE

#undef SISTER_STING_ICON
#undef SISTER_STING_RANGE
