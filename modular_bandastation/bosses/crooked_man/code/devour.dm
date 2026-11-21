/// Swallows one living victim; a second activation releases them.
/datum/action/cooldown/spell/crooked_devour
	name = "Поглощение"
	desc = "Поглощает цель перед собой. Повторное использование выплюнет жертву."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "absorb_dna"
	cooldown_time = 10 SECONDS
	spell_requirements = NONE
	/// Owned container, released when the ability is removed or its owner is deleted.
	var/obj/item/storage/devour_stomach/stomach
	/// Digestion rate supplied to this ability's owned stomach.
	var/digestion_rate = 0.75

/datum/action/cooldown/spell/crooked_devour/Remove(mob/living/remove_from)
	QDEL_NULL(stomach)
	return ..()

/datum/action/cooldown/spell/crooked_devour/cast(atom/cast_on)
	. = ..()
	if(stomach)
		stomach.release_victim()
		return
	var/mob/living/victim
	for(var/mob/living/candidate in get_step(owner, owner.dir))
		if(candidate != owner && candidate.stat != DEAD)
			victim = candidate
			break
	if(!victim)
		to_chat(owner, span_warning("Перед вами нет подходящей цели!"))
		return
	owner.visible_message(span_danger("[owner] хватает [victim] и затягивает внутрь себя!"), span_notice("Вы поглощаете [victim]."))
	playsound(owner, 'sound/effects/goresplat.ogg', 75, TRUE)
	playsound(victim, 'sound/effects/blob/blobattack.ogg', 50, TRUE)
	stomach = new(owner, src, victim)
	stomach.damage_per_second = digestion_rate
	to_chat(victim, span_userdanger("Вас затягивает в искажённое пространство! Желудочный сок медленно разъедает вас изнутри!"))

/// Private victim container; deletion must eject its contents instead of deleting the player.
/obj/item/storage/devour_stomach
	name = "искажённое пространство"
	desc = "Вы не должны этого видеть."
	icon = 'icons/effects/effects.dmi'
	icon_state = "nothing"
	/// Ability owning this container; cleared in Destroy on either teardown path.
	var/datum/action/cooldown/spell/crooked_devour/ability
	/// Swallowed mob; administrative relocation ends digestion.
	var/mob/living/victim
	/// Toxin damage per second, independent of processing frequency.
	var/damage_per_second = 0.75

/obj/item/storage/devour_stomach/Initialize(mapload, datum/action/cooldown/spell/crooked_devour/ability, mob/living/victim)
	. = ..()
	src.ability = ability
	src.victim = victim
	// Only the ability creates a working stomach; a bare one has nobody to digest.
	if(isnull(victim))
		return
	victim.forceMove(src)
	START_PROCESSING(SSobj, src)

/obj/item/storage/devour_stomach/Destroy()
	STOP_PROCESSING(SSobj, src)
	// Container deletion must never take a swallowed player with it.
	if(!QDELETED(victim) && victim.loc == src)
		victim.forceMove(get_turf(src) || find_safe_turf())
	victim = null
	if(ability?.stomach == src)
		ability.stomach = null
	ability = null
	return ..()

/obj/item/storage/devour_stomach/process(seconds_per_tick)
	if(QDELETED(victim) || QDELETED(ability) || QDELETED(ability.owner) || victim.loc != src)
		qdel(src)
		return PROCESS_KILL
	if(victim.stat == DEAD)
		addtimer(CALLBACK(src, PROC_REF(release_victim)), 10 SECONDS)
		return PROCESS_KILL
	victim.apply_damage(damage_per_second * seconds_per_tick, TOX)
	to_chat(victim, span_danger("Желудочный сок разъедает ваше тело!"))
	victim.playsound_local(get_turf(src), 'sound/effects/wounds/splatter.ogg', 30, TRUE)
	if(victim.stat == DEAD)
		ability.owner.visible_message(span_danger("[ability.owner] издаёт звук, похожий на смех."))
		playsound(ability.owner, 'modular_bandastation/bosses/crooked_man/sounds/lauth.ogg', 80, TRUE)

/// Spits the victim out with the original sound and vomit effect.
/obj/item/storage/devour_stomach/proc/release_victim()
	if(!QDELETED(victim) && victim.loc == src)
		var/turf/release_turf = get_turf(src)
		victim.forceMove(release_turf)
		ability?.owner?.visible_message(span_danger("[ability.owner] изрыгает [victim]!"), span_notice("Вы выплёвываете [victim]."))
		playsound(release_turf, 'sound/effects/goresplat.ogg', 75, TRUE)
		new /obj/effect/decal/cleanable/vomit(release_turf)
		to_chat(victim, span_notice("Вас выплюнули наружу!"))
	qdel(src)

/// The final fight's devour: the jaws open a second before they close on the tile in front, and the group can
/// free the victim by hurting him enough; otherwise the victim is spat out after a while.
/datum/action/cooldown/spell/crooked_devour/crooked
	name = "Голодное поглощение"
	button_icon = 'modular_bandastation/bosses/icons/action_buttons.dmi'
	button_icon_state = "crooked_devour"
	cooldown_time = 30 SECONDS
	digestion_rate = 3
	/// Wind-up during which the tile in front is marked.
	var/windup = 1 SECONDS
	/// Damage the group must deal to him while he holds someone to free them.
	var/rescue_damage = 150
	/// How long a victim stays inside at most.
	var/hold_time = 8 SECONDS
	/// Damage taken since the current victim was swallowed.
	var/damage_taken = 0
	/// Timer that spits the current victim out.
	var/release_timer

/datum/action/cooldown/spell/crooked_devour/crooked/Remove(mob/living/remove_from)
	stop_holding()
	return ..()

/datum/action/cooldown/spell/crooked_devour/crooked/before_cast(atom/cast_on)
	. = ..()
	// Spitting out needs no wind-up.
	if((. & SPELL_CANCEL_CAST) || stomach)
		return
	var/turf/front = get_step(owner, owner.dir)
	if(front)
		new /obj/effect/temp_visual/cult/sparks/crooked(front)
	owner.visible_message(span_danger("[owner] раскрывает огромную пасть!"))
	playsound(owner, 'sound/effects/blob/blobattack.ogg', 70, TRUE)
	if(!crooked_windup(owner, windup, src))
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/crooked_devour/crooked/cast(atom/cast_on)
	var/was_holding = !!stomach
	. = ..()
	if(was_holding)
		stop_holding()
		return
	if(!stomach)
		return
	damage_taken = 0
	RegisterSignal(owner, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_owner_damaged))
	release_timer = addtimer(CALLBACK(src, PROC_REF(release)), hold_time, TIMER_STOPPABLE)

/datum/action/cooldown/spell/crooked_devour/crooked/proc/on_owner_damaged(datum/source, damage)
	SIGNAL_HANDLER
	damage_taken += damage
	if(damage_taken >= rescue_damage)
		owner.visible_message(span_danger("[owner] не выдерживает ран и изрыгает добычу!"))
		release()

/datum/action/cooldown/spell/crooked_devour/crooked/proc/release()
	stop_holding()
	stomach?.release_victim()

/datum/action/cooldown/spell/crooked_devour/crooked/proc/stop_holding()
	if(owner)
		UnregisterSignal(owner, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	deltimer(release_timer)
	release_timer = null
