/// The Wolf's Doom armor lifts a victim by the neck, then crushes their head.
/datum/action/cooldown/normandy_iron_grip
	name = "Железный хват"
	desc = "Освободите активную руку и выберите персонажа рядом. Вы поднимете его за шею, затем перехватите за голову и раздавите её. Захват занимает три секунды."
	button_icon = 'modular_bandastation/prime_only/icons/centcom/normandy_actions.dmi'
	button_icon_state = "iron_grip"
	check_flags = AB_CHECK_HANDS_BLOCKED | AB_CHECK_INCAPACITATED | AB_CHECK_CONSCIOUS | AB_CHECK_LYING
	click_to_activate = TRUE
	unset_after_click = FALSE
	cooldown_time = 30 SECONDS
	/// The victim whose raised pose and grab this action owns.
	var/mob/living/carbon/human/lifted_victim
	/// The gauntlets in use and their original worn state, restored on release.
	var/obj/item/clothing/gloves/combat/normandy/gripping_gloves
	/// Custom worn states must survive a change of pose.
	var/resting_glove_state
	/// The lowered gauntlets return to their original equipment layer.
	var/resting_glove_layer
	/// The fingers currently drawn over the victim's neck or head.
	var/mutable_appearance/grip_overlay

/datum/action/cooldown/normandy_iron_grip/Activate(atom/selected)
	var/mob/living/carbon/human/wearer = owner
	var/mob/living/carbon/human/victim = selected
	if(!IsAvailable() || lifted_victim || !istype(wearer) || wearer.wear_suit != target)
		return FALSE
	if(!can_use_gauntlet(wearer))
		wearer.balloon_alert(wearer, HAS_TRAIT(wearer, TRAIT_PACIFISM) ? "вы не хотите причинять вред!" : "нужна свободная рука в перчатке костюма!")
		return FALSE
	if(!istype(victim) || victim == wearer || !isturf(wearer.loc) || !isturf(victim.loc) || !wearer.Adjacent(victim))
		wearer.balloon_alert(wearer, "выберите персонажа рядом!")
		return FALSE
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head || victim.stat == DEAD || victim.buckled)
		wearer.balloon_alert(wearer, "невозможно взять за шею!")
		return FALSE

	var/already_pulling = wearer.pulling == victim
	if(!already_pulling && (!wearer.grab(victim) || wearer.pulling != victim))
		return FALSE
	if(wearer.grab_state < GRAB_AGGRESSIVE)
		victim.grabbedby(wearer)
	if(wearer.pulling != victim || wearer.grab_state < GRAB_AGGRESSIVE)
		if(!already_pulling && wearer.pulling == victim)
			wearer.stop_pulling()
		return FALSE

	if(wearer.click_intercept == src)
		unset_click_ability(wearer, refund_cooldown = FALSE)
	StartCooldown()
	lifted_victim = victim
	gripping_gloves = wearer.gloves
	resting_glove_state = gripping_gloves.worn_icon_state
	resting_glove_layer = gripping_gloves.alternate_worn_layer
	// The raised forearm passes in front of the breastplate and behind the cloak.
	gripping_gloves.alternate_worn_layer = HEAD_LAYER - 0.15
	RegisterSignals(victim, list(COMSIG_ATOM_NO_LONGER_PULLED, COMSIG_QDELETING), PROC_REF(release_grip))
	RegisterSignals(gripping_gloves, list(COMSIG_ITEM_POST_UNEQUIP, COMSIG_QDELETING), PROC_REF(release_grip))
	wearer.face_atom(victim)
	victim.setDir(turn(wearer.dir, 180))
	RegisterSignal(wearer, COMSIG_ATOM_PRE_DIR_CHANGE, PROC_REF(keep_grip_facing))
	RegisterSignal(victim, COMSIG_ATOM_PRE_DIR_CHANGE, PROC_REF(keep_grip_facing))
	ADD_TRAIT(victim, TRAIT_FORCED_STANDING, REF(src))
	// The raised gauntlet meets the collar half a tile from the center of the armor.
	var/hand_side = (wearer.dir & (SOUTH | EAST)) ? 1 : -1
	var/grip_x = (wearer.x - victim.x) * world.icon_size + hand_side * (world.icon_size / 2)
	victim.add_offsets(REF(src),
		x_add = grip_x - victim.has_offset(GRABBING_TRAIT, PIXEL_X_OFFSET),
		y_add = (wearer.y - victim.y) * world.icon_size - victim.has_offset(GRABBING_TRAIT, PIXEL_Y_OFFSET),
		z_add = wearer.has_offset(REF(target), PIXEL_Y_OFFSET),
	)
	set_grip_pose(wearer, victim, "raised_gloves", "grip")
	wearer.visible_message(span_danger("[capitalize(wearer.declent_ru(NOMINATIVE))] хватает [victim.declent_ru(ACCUSATIVE)] за шею и поднимает над полом!"),
		span_notice("Вы поднимаете [victim.declent_ru(ACCUSATIVE)] за шею."), ignored_mobs = list(victim))
	to_chat(victim, span_userdanger("Стальная перчатка смыкается на вашей шее. Ноги отрываются от пола! Сопротивляйтесь!"))
	log_combat(wearer, victim, "lifted by the neck", target)

	var/datum/callback/still_holding = CALLBACK(src, PROC_REF(can_finish_grip), wearer, victim, head)
	var/held_neck = do_after(wearer, 2.5 SECONDS, victim, timed_action_flags = DO_AFTER_CHECK_NEXT_MOVE, extra_checks = still_holding)
	var/held_head = FALSE
	if(held_neck && still_holding.Invoke())
		set_grip_pose(wearer, victim, "crushing_gloves", "crush")
		wearer.visible_message(span_danger("[capitalize(wearer.declent_ru(NOMINATIVE))] перехватывает жертву за голову!"), span_notice("Вы перехватываете жертву за голову."))
		held_head = do_after(wearer, 0.5 SECONDS, victim, timed_action_flags = DO_AFTER_CHECK_NEXT_MOVE, extra_checks = still_holding)
	if(QDELETED(src) || lifted_victim != victim)
		return TRUE
	if(held_head && still_holding.Invoke())
		if(head.dismember(wounding_type = WOUND_BLUNT))
			wearer.do_attack_animation(victim, ATTACK_EFFECT_SMASH)
			if(!QDELETED(head))
				head.drop_organs()
				qdel(head)
			new /obj/effect/gibspawner/human/bodypartless(get_turf(victim), victim)
			wearer.visible_message(span_danger("[capitalize(wearer.declent_ru(NOMINATIVE))] сжимает перчатку, и голова жертвы лопается!"), span_notice("Вы раздавили голову жертвы."))
			log_combat(wearer, victim, "crushed the head of", target)
		else
			wearer.balloon_alert(wearer, "голова выдержала!")
	release_grip()
	return TRUE

/// Move the sleeve and fingers together so the hand stays connected in both poses.
/datum/action/cooldown/normandy_iron_grip/proc/set_grip_pose(mob/living/carbon/human/wearer, mob/living/carbon/human/victim, glove_state, finger_state)
	gripping_gloves.worn_icon_state = glove_state
	wearer.update_worn_gloves()
	if(grip_overlay)
		victim.cut_overlay(grip_overlay)
	grip_overlay = mutable_appearance('modular_bandastation/prime_only/icons/centcom/normandy_iron_grip.dmi', finger_state, -ABOVE_BODY_FRONT_HEAD_LAYER)
	victim.add_overlay(grip_overlay)

/// The gripping hand must remain usable and wear the matching armor's gauntlet.
/datum/action/cooldown/normandy_iron_grip/proc/can_use_gauntlet(mob/living/carbon/human/wearer)
	return istype(wearer.gloves, /obj/item/clothing/gloves/combat/normandy) && wearer.has_active_hand() && !wearer.get_active_held_item() && !HAS_TRAIT(wearer, TRAIT_PACIFISM)

/// Recheck the original victim and head while the wearer is holding them aloft.
/datum/action/cooldown/normandy_iron_grip/proc/can_finish_grip(mob/living/carbon/human/wearer, mob/living/carbon/human/victim, obj/item/bodypart/head/head)
	if(lifted_victim != victim || owner != wearer || QDELETED(wearer) || QDELETED(victim) || QDELETED(head))
		return FALSE
	if(wearer.wear_suit != target || !can_use_gauntlet(wearer) || wearer.body_position != STANDING_UP || IS_UNCONSCIOUS_OR_CRIT(wearer) || HAS_TRAIT(wearer, TRAIT_HANDS_BLOCKED))
		return FALSE
	return wearer.pulling == victim && wearer.grab_state >= GRAB_AGGRESSIVE && wearer.Adjacent(victim) \
		&& !victim.buckled && victim.stat != DEAD && head.owner == victim

/datum/action/cooldown/normandy_iron_grip/Remove(mob/removed_from)
	if(owner == removed_from)
		release_grip()
	return ..()

/// Keep the sleeve and the hand aligned if either player clicks elsewhere during the lift.
/datum/action/cooldown/normandy_iron_grip/proc/keep_grip_facing()
	SIGNAL_HANDLER
	return COMPONENT_ATOM_BLOCK_DIR_CHANGE

/// Restore the victim's pose on completion, escape, deletion, or removal of the armor.
/datum/action/cooldown/normandy_iron_grip/proc/release_grip()
	SIGNAL_HANDLER
	var/mob/living/carbon/human/victim = lifted_victim
	if(!victim)
		return
	lifted_victim = null
	var/mob/living/carbon/human/wearer = owner
	UnregisterSignal(wearer, COMSIG_ATOM_PRE_DIR_CHANGE)
	UnregisterSignal(gripping_gloves, list(COMSIG_ITEM_POST_UNEQUIP, COMSIG_QDELETING))
	gripping_gloves.worn_icon_state = resting_glove_state
	gripping_gloves.alternate_worn_layer = resting_glove_layer
	if(!QDELETED(wearer) && wearer.gloves == gripping_gloves && !QDELETED(gripping_gloves))
		wearer.update_worn_gloves()
	gripping_gloves = null
	resting_glove_state = null
	resting_glove_layer = null
	UnregisterSignal(victim, list(COMSIG_ATOM_NO_LONGER_PULLED, COMSIG_QDELETING, COMSIG_ATOM_PRE_DIR_CHANGE))
	victim.cut_overlay(grip_overlay)
	grip_overlay = null
	victim.remove_offsets(REF(src))
	REMOVE_TRAIT(victim, TRAIT_FORCED_STANDING, REF(src))
	if(owner?.pulling == victim)
		owner.stop_pulling()
