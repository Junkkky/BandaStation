#define ST_TRAINING_MELEE_APPLIED "stationtrauma_training_melee_applied"

/// Combat listeners follow the mind; weapon properties and ordinary unprepared mobs are unchanged.
/datum/component/stationtrauma_training/var/datum/weakref/combat_body

/** Bind existing TG attack signals, without overriding the global attack or gun procedures. */
/datum/component/stationtrauma_training/proc/bind_combat(mob/living/new_body)
	var/mob/living/old_body = combat_body?.resolve()
	if(old_body)
		UnregisterSignal(old_body, list(COMSIG_USER_PRE_ITEM_ATTACK, COMSIG_MOB_FIRED_GUN, COMSIG_HUMAN_PUNCHED))
	combat_body = new_body ? WEAKREF(new_body) : null
	if(!new_body)
		return
	RegisterSignal(new_body, COMSIG_USER_PRE_ITEM_ATTACK, PROC_REF(melee_attack))
	RegisterSignal(new_body, COMSIG_MOB_FIRED_GUN, PROC_REF(gun_fired))
	RegisterSignal(new_body, COMSIG_HUMAN_PUNCHED, PROC_REF(punched))

/** Starting balance: untrained/basic/trained/experienced/master melee force and recovery. */
/datum/component/stationtrauma_training/proc/combat_multiplier()
	switch(get_level("combat"))
		if(ST_TRAINING_UNSKILLED)
			return 0.75
		if(ST_TRAINING_BASIC)
			return 0.9
		if(ST_TRAINING_EXPERIENCED)
			return 1.05
		if(ST_TRAINING_MASTER)
			return 1.1
	return 1

/** Modify only this attack's force; shared weapons and repeated area-hit lists never stack it. */
/datum/component/stationtrauma_training/proc/melee_attack(mob/living/body, obj/item/weapon, atom/target, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!SSstationtrauma_training.enabled || body.mind != parent || !body.combat_mode || !isliving(target) || target == body || !islist(attack_modifiers) || (weapon.item_flags & NOBLUDGEON) || attack_modifiers[ST_TRAINING_MELEE_APPLIED])
		return
	attack_modifiers[ST_TRAINING_MELEE_APPLIED] = TRUE
	MODIFY_ATTACK_FORCE_MULTIPLIER(attack_modifiers, combat_multiplier())

/** Add an operator-dependent cone; native gun spread, dual wielding and other modifiers remain. */
/datum/component/stationtrauma_training/proc/gun_fired(mob/living/body, obj/item/gun/gun, atom/target, params, zone_override, list/bonus_spread_values)
	SIGNAL_HANDLER
	if(!SSstationtrauma_training.enabled || body.mind != parent || !islist(bonus_spread_values))
		return
	var/penalty = 0
	switch(get_level("weapons"))
		if(ST_TRAINING_UNSKILLED)
			penalty = 18
		if(ST_TRAINING_BASIC)
			penalty = 8
		if(ST_TRAINING_TRAINED)
			penalty = 3
		if(ST_TRAINING_EXPERIENCED)
			penalty = 1
	bonus_spread_values[MIN_BONUS_SPREAD_INDEX] += penalty
	bonus_spread_values[MAX_BONUS_SPREAD_INDEX] += penalty

/** Successful unarmed strikes adjust recovery; harm, armor, martial arts and injury stay native. */
/datum/component/stationtrauma_training/proc/punched(mob/living/body, mob/living/target, damage)
	SIGNAL_HANDLER
	if(!SSstationtrauma_training.enabled || body.mind != parent || !body.combat_mode || target == body || damage <= 0)
		return
	var/recovery = max(0, body.next_move - world.time)
	body.next_move = world.time + recovery / combat_multiplier()

#undef ST_TRAINING_MELEE_APPLIED
