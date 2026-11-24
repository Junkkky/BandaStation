#define MALICE_RECALL_STEP_TIME (0.15 SECONDS)

/datum/action/cooldown/malice_recall
	name = "Зов Злобы"
	desc = "Призовите связанный с вами меч. Злоба раскрывается, вращается в полёте и рассекает встречных на пути к вам. Преграда остановит клинок."
	button_icon = 'modular_bandastation/weapon/icons/melee/malice_recall.dmi'
	button_icon_state = "recall_action"
	cooldown_time = 30 SECONDS
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_HANDS_BLOCKED
	can_be_shared = FALSE
	/// Only this blade answers the call; the action target is the owner's mind.
	var/obj/item/dualsaber/legendary_saber/saber
	var/in_flight = FALSE
	var/datum/sound_token/flight_sound
	var/previous_layer
	var/previous_glide

/datum/action/cooldown/malice_recall/New(datum/mind/bonded_owner, obj/item/dualsaber/legendary_saber/blade)
	saber = blade
	return ..(bonded_owner)

/datum/action/cooldown/malice_recall/Destroy()
	end_flight()
	if(saber?.recall == src)
		saber.recall = null
	saber = null
	return ..()

/datum/action/cooldown/malice_recall/Activate(atom/target)
	var/mob/living/user = owner
	if(target != user || !isliving(user) || user.mind != src.target || in_flight || !IsAvailable() || !saber?.can_use_legendary_ability(user, 25, require_wielded = FALSE))
		return FALSE
	if(user.is_holding(saber))
		saber.balloon_alert(user, "меч уже в руке!")
		return FALSE
	var/turf/origin = get_turf(saber)
	if(!origin || !isturf(user.loc) || origin.z != user.z)
		user.balloon_alert(user, "меч слишком далеко!")
		return FALSE
	var/from_ground = saber.loc == origin && !saber.throwing
	if(!release_blade(origin))
		user.balloon_alert(user, "мечу что-то мешает!")
		return FALSE
	in_flight = TRUE
	previous_layer = saber.layer
	previous_glide = saber.glide_size
	saber.layer = ABOVE_MOB_LAYER
	saber.update_appearance(UPDATE_ICON_STATE)
	saber.set_light_on(TRUE)
	saber.SpinAnimation(0.45 SECONDS, tag = "malice_recall")
	new /obj/effect/temp_visual/malice_recall_departure(origin)
	if(from_ground)
		playsound(origin, saber.wieldsound, 17.5, FALSE)
	else
		playsound(origin, 'modular_bandastation/weapon/sound/melee/malice_recall_launch.ogg', 31, FALSE)
	flight_sound = new(saber, 'modular_bandastation/weapon/sound/melee/malice_recall_flight.ogg', SOUND_RANGE, 24, _repeating = TRUE)
	StartCooldown()
	INVOKE_ASYNC(src, PROC_REF(fly_to_owner), user, origin)
	return TRUE

/// Extract only the hilt; a closed outer enclosure still blocks a physical launch.
/datum/action/cooldown/malice_recall/proc/release_blade(turf/origin)
	for(var/atom/container = saber.loc; !isturf(container); container = container.loc)
		if(iscloset(container))
			var/obj/structure/closet/closet = container
			if(!closet.opened)
				return FALSE
		else if(!ismob(container) && !container.atom_storage)
			return FALSE
	if(saber.throwing)
		saber.throwing.finalize(FALSE)
		if(QDELETED(saber) || get_turf(saber) != origin)
			return FALSE
	if(ismob(saber.loc))
		var/mob/holder = saber.loc
		holder.transferItemToLoc(saber, origin, force = TRUE, silent = TRUE, animated = FALSE)
	else if(saber.loc.atom_storage)
		saber.loc.atom_storage.attempt_remove(saber, origin, silent = TRUE)
	else if(saber.loc != origin)
		saber.forceMove(origin)
	return !QDELETED(saber) && saber.loc == origin

/// Each step moves the real item. Another mover, an obstacle, or losing the bond ends its flight.
/datum/action/cooldown/malice_recall/proc/fly_to_owner(mob/living/user, turf/current)
	var/list/struck = list()
	for(var/step_number in 1 to max(world.maxx, world.maxy) + 1)
		sleep(MALICE_RECALL_STEP_TIME)
		if(QDELETED(src) || QDELETED(saber) || QDELETED(user) || user != owner || !saber.can_use_legendary_ability(user, 25, require_wielded = FALSE) || saber.loc != current || !isturf(user.loc) || user.z != current.z)
			break
		if(current == user.loc)
			break
		var/turf/next = get_step_towards(current, user)
		var/turf/previous = current
		if(!next || next.density)
			break
		var/advanced = saber.Move(next, get_dir(current, next), DELAY_TO_GLIDE_SIZE(MALICE_RECALL_STEP_TIME))
		if(QDELETED(saber) || !isturf(saber.loc) || saber.loc == previous || get_dist(previous, saber) != 1 || saber.z != previous.z)
			break
		current = saber.loc
		var/impact_delay = 0
		for(var/mob/living/victim in current)
			if(victim == user || victim.stat == DEAD || struck[victim] || HAS_TRAIT(user, TRAIT_PACIFISM))
				continue
			struck[victim] = TRUE
			var/list/modifiers = list(FORCE_OVERRIDE = saber.two_hand_force, MELEE_EFFECT_ORIGIN = previous, SILENCE_HITSOUND = TRUE)
			victim.attackby(saber, user, null, modifiers)
			if(QDELETED(src) || QDELETED(saber) || QDELETED(user) || saber.loc != current)
				break
			if(modifiers[DAMAGE_DONE] > 0)
				impact_delay = play_malice_sweep_hit(current, impact_delay, 'modular_bandastation/weapon/sound/melee/malice_recall_hit.ogg', 33)
		if(!advanced || current != next || QDELETED(user) || current == user.loc)
			break
	if(QDELETED(src) || QDELETED(saber))
		return
	end_flight()
	if(QDELETED(user) || user != owner || saber.loc != user.loc || !isturf(user.loc) || !saber.can_use_legendary_ability(user, 25, require_wielded = FALSE))
		return
	new /obj/effect/temp_visual/malice_recall_arrival(user.loc)
	if(HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || !length(user.get_empty_held_indexes()) || !user.put_in_hands(saber))
		return
	playsound(user, 'modular_bandastation/weapon/sound/melee/malice_recall_catch.ogg', 28, FALSE)
	if(iscarbon(user) && user.get_active_held_item() == saber && !user.get_inactive_held_item())
		var/datum/component/two_handed/grip = saber.GetComponent(/datum/component/two_handed)
		grip.wield(user, play_sound = FALSE)

/datum/action/cooldown/malice_recall/proc/end_flight()
	if(!in_flight)
		return
	in_flight = FALSE
	QDEL_NULL(flight_sound)
	if(!QDELETED(saber))
		animate(saber, tag = "malice_recall")
		if(saber.layer == ABOVE_MOB_LAYER)
			saber.layer = previous_layer
		saber.set_glide_size(previous_glide)
		saber.update_appearance(UPDATE_ICON_STATE)
		saber.set_light_on(HAS_TRAIT(saber, TRAIT_WIELDED))

#undef MALICE_RECALL_STEP_TIME
