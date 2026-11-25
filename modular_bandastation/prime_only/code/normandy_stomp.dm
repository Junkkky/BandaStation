/// A short, ground-level stun wave centered on the Wolf's Doom wearer's boot.
/datum/action/cooldown/normandy_stomp
	name = "Топот"
	desc = "Ударьте бронесапогом по полу. Волна собьёт с ног и оглушит окружающих в радиусе двух клеток на две секунды."
	button_icon = 'modular_bandastation/prime_only/icons/centcom/normandy_actions.dmi'
	button_icon_state = "stomp"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_LYING | AB_CHECK_IMMOBILE
	cooldown_time = 35 SECONDS

/datum/action/cooldown/normandy_stomp/Activate(atom/selected)
	var/mob/living/carbon/human/wearer = owner
	if(!IsAvailable() || !istype(wearer) || wearer.wear_suit != target)
		return FALSE
	var/obj/item/clothing/shoes/combat/normandy/boots = wearer.shoes
	if(!istype(boots) || !can_plant_foot(wearer))
		wearer.balloon_alert(wearer, "нужны бронесапоги и твёрдая опора!")
		return FALSE
	if(HAS_TRAIT(wearer, TRAIT_PACIFISM))
		wearer.balloon_alert(wearer, "вы не хотите причинять вред!")
		return FALSE

	StartCooldown()
	wearer.changeNext_move(CLICK_CD_MELEE)
	// Only the wearer's cached overlay holds the raised foot; the boots may change hands.
	var/resting_state = boots.worn_icon_state
	boots.worn_icon_state = "stomp_boots"
	wearer.update_worn_shoes()
	boots.worn_icon_state = resting_state
	var/landed = do_after(wearer, 0.3 SECONDS, wearer, timed_action_flags = IGNORE_HELD_ITEM | IGNORE_SLOWDOWNS, show_progress = FALSE)
	if(QDELETED(wearer))
		return TRUE
	wearer.update_worn_shoes()
	if(!landed || QDELETED(src) || owner != wearer || wearer.wear_suit != target || wearer.shoes != boots || !can_plant_foot(wearer) || HAS_TRAIT(wearer, TRAIT_PACIFISM))
		return TRUE
	wearer.visible_message(span_danger("[capitalize(wearer.declent_ru(NOMINATIVE))] с грохотом бьёт бронесапогом по полу!"), span_notice("Вы с силой бьёте бронесапогом по полу."))
	playsound(wearer, 'sound/effects/meteorimpact.ogg', 70, TRUE)
	new /obj/effect/temp_visual/circle_wave/normandy_stomp(wearer.loc, wearer)
	return TRUE

/datum/action/cooldown/normandy_stomp/proc/can_plant_foot(mob/living/carbon/human/wearer)
	return wearer.num_legs >= 2 && wearer.usable_legs && !wearer.legcuffed && !wearer.buckled && wearer.body_position == STANDING_UP \
		&& !(wearer.movement_type & (FLYING | FLOATING)) && isopenturf(wearer.loc) && !isgroundlessturf(wearer.loc) && wearer.has_gravity()

/// Each visible ring hits once as it reaches that distance from the original impact.
/obj/effect/temp_visual/circle_wave/normandy_stomp
	layer = BELOW_MOB_LAYER

/obj/effect/temp_visual/circle_wave/normandy_stomp/Initialize(mapload, mob/living/wearer)
	. = ..(mapload)
	var/list/already_hit = list(wearer)
	stun_ring(0, wearer, already_hit)
	for(var/radius in 1 to 2)
		addtimer(CALLBACK(src, PROC_REF(stun_ring), radius, wearer, already_hit), radius * 0.2 SECONDS)

/obj/effect/temp_visual/circle_wave/normandy_stomp/proc/stun_ring(radius, mob/living/wearer, list/already_hit)
	var/turf/origin = get_turf(src)
	for(var/mob/living/victim in view(radius, origin))
		if(victim.stat == DEAD || (victim in already_hit) || !isopenturf(victim.loc) || isgroundlessturf(victim.loc) || get_dist(origin, victim) != radius)
			continue
		already_hit += victim
		if(victim.Paralyze(2 SECONDS))
			to_chat(victim, span_userdanger("Ударная волна сбивает вас с ног!"))
			if(!QDELETED(wearer))
				log_combat(wearer, victim, "stunned with an armored stomp")
