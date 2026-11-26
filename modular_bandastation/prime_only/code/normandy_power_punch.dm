/// The Wolf's Doom gauntlet delivers a punch that launches an adjacent target.
/datum/action/cooldown/normandy_power_punch
	name = "Усиленный удар"
	desc = "Освободите активную руку и ударьте цель на соседней клетке кулаком. На свободном полу цель отлетит на пять клеток."
	button_icon = 'modular_bandastation/prime_only/icons/centcom/normandy_actions.dmi'
	button_icon_state = "power_punch"
	check_flags = AB_CHECK_HANDS_BLOCKED | AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_LYING | AB_CHECK_IMMOBILE
	click_to_activate = TRUE
	cooldown_time = 12 SECONDS

/datum/action/cooldown/normandy_power_punch/Activate(atom/selected)
	var/mob/living/carbon/human/wearer = owner
	if(!IsAvailable() || !istype(wearer) || wearer.wear_suit != target || !isturf(wearer.loc) || wearer.buckled)
		return FALSE
	if(!istype(wearer.gloves, /obj/item/clothing/gloves/combat/normandy) || !wearer.has_active_hand() || wearer.get_active_held_item())
		wearer.balloon_alert(wearer, "нужна свободная рука в перчатке костюма!")
		return FALSE
	if(HAS_TRAIT(wearer, TRAIT_PACIFISM))
		wearer.balloon_alert(wearer, "вы не хотите причинять вред!")
		return FALSE
	var/mob/living/victim = selected
	if(!istype(victim) || !isturf(victim.loc) || wearer.loc == victim.loc || !wearer.Adjacent(victim))
		wearer.balloon_alert(wearer, "выберите цель на соседней клетке!")
		return FALSE
	if(victim.anchored || victim.buckled)
		wearer.balloon_alert(wearer, "цель закреплена!")
		return FALSE

	var/const/knockback_range = 5
	var/turf/destination = get_ranged_target_turf(victim, get_dir(wearer, victim), knockback_range)
	StartCooldown()
	wearer.changeNext_move(CLICK_CD_MELEE)
	var/datum/action/cooldown/normandy_iron_grip/grip = locate() in wearer.actions
	if(grip?.lifted_victim)
		wearer.stop_pulling()
	wearer.face_atom(victim)
	wearer.do_attack_animation(victim, ATTACK_EFFECT_PUNCH)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	playsound(victim, (chest?.bodytype & BODYTYPE_ROBOTIC) ? 'sound/effects/bang.ogg' : 'sound/items/weapons/punch1.ogg', 25, TRUE, -1)
	victim.visible_message(
		span_danger("[capitalize(wearer.declent_ru(NOMINATIVE))] бьёт [victim.declent_ru(ACCUSATIVE)] бронированным кулаком!"),
		span_userdanger("[capitalize(wearer.declent_ru(NOMINATIVE))] бьёт вас бронированным кулаком!"),
		vision_distance = COMBAT_MESSAGE_RANGE, ignored_mobs = wearer,
	)
	to_chat(wearer, span_notice("Вы бьёте [victim.declent_ru(ACCUSATIVE)] бронированным кулаком."))
	log_combat(wearer, victim, "struck with a powered punch", wearer.gloves)
	victim.apply_damage(15, BRUTE, BODY_ZONE_CHEST, blocked = victim.run_armor_check(BODY_ZONE_CHEST, MELEE), wound_bonus = CANT_WOUND)
	if(!QDELETED(victim))
		victim.safe_throw_at(destination, knockback_range, 2, wearer, spin = FALSE)
	return TRUE
