#define MALICE_OPENING_RANGE 4
#define MALICE_FOLLOWUP_RANGE 3

/datum/action/cooldown/legendary_sword/malice_omnislash
	name = "Злоба высвобожденная"
	desc = "Выберите цель в пределах четырёх клеток. Злоба переносит вас от цели к цели и наносит до десяти ударов с интервалом 0,3 секунды. Каждый удар наносит полный урон клинка. При одной цели вы атакуете её с разных сторон. Серия снижает прямой урон на 95% и обрывается при крите, потере меча или отсутствии целей."
	button_icon_state = "malice_omnislash"
	cooldown_time = 2 MINUTES
	required_bond = 100
	click_to_activate = TRUE

/datum/action/cooldown/legendary_sword/malice_omnislash/Activate(atom/target)
	var/mob/living/user = owner
	var/mob/living/victim = target
	if(!saber.can_use_legendary_ability(user, required_bond) || HAS_TRAIT(user, TRAIT_PACIFISM) || !isturf(user.loc) || user.buckled)
		return FALSE
	if(!istype(victim) || !(victim in view(MALICE_OPENING_RANGE, user)))
		return FALSE
	var/datum/status_effect/malice_omnislash/sequence = user.apply_status_effect(/datum/status_effect/malice_omnislash, saber, required_bond, victim)
	if(!sequence)
		return FALSE
	StartCooldown()
	sequence.tick(0)
	return TRUE

/datum/status_effect/malice_omnislash
	parent_type = /datum/status_effect/legendary_sword_sequence
	id = "malice_sequence"
	tick_interval = STATUS_EFFECT_NO_TICK
	duration = STATUS_EFFECT_PERMANENT
	/// The chosen victim of the first strike.
	var/datum/weakref/first_target
	/// Strikes already attempted against each victim, keyed by weak reference.
	var/list/strike_counts = list()
	/// Number of strikes still available in this sequence.
	var/strikes_left = 10
	/// Stun signals have no attack source, so use the tick of the preceding direct hit.
	var/last_direct_attack = -1

/datum/status_effect/malice_omnislash/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, mob/living/victim)
	if(!can_reach_target(victim, MALICE_OPENING_RANGE) || !..())
		return FALSE
	first_target = WEAKREF(victim)
	RegisterSignals(owner, list(COMSIG_LIVING_CHECK_BLOCK, COMSIG_ATOM_BULLET_ACT), PROC_REF(note_direct_attack))
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(reduce_direct_damage))
	RegisterSignal(owner, COMSIG_LIVING_GENERIC_STUN_CHECK, PROC_REF(block_attack_stun))
	RegisterSignal(owner, COMSIG_LIVING_STATUS_UNCONSCIOUS, PROC_REF(block_attack_unconsciousness))
	RegisterSignal(owner, COMSIG_MOB_CLIENT_PRE_LIVING_MOVE, PROC_REF(block_manual_movement))
	// Fast processing would round a 0.3s interval up to 0.4s.
	addtimer(CALLBACK(src, PROC_REF(tick)), 0.3 SECONDS, TIMER_LOOP | TIMER_DELETE_ME)
	owner.visible_message(span_warning("[capitalize(owner.declent_ru(NOMINATIVE))] вскидывает Злобу и срывается с места багровой тенью!"))
	return TRUE

/datum/status_effect/malice_omnislash/on_remove()
	UnregisterSignal(owner, list(
		COMSIG_MOB_CLIENT_PRE_LIVING_MOVE,
		COMSIG_LIVING_CHECK_BLOCK,
		COMSIG_ATOM_BULLET_ACT,
		COMSIG_MOB_APPLY_DAMAGE_MODIFIERS,
		COMSIG_LIVING_GENERIC_STUN_CHECK,
		COMSIG_LIVING_STATUS_UNCONSCIOUS,
	))
	first_target = null
	strike_counts = null
	return ..()

/datum/status_effect/malice_omnislash/proc/block_manual_movement()
	SIGNAL_HANDLER
	return COMSIG_MOB_CLIENT_BLOCK_PRE_LIVING_MOVE

/datum/status_effect/malice_omnislash/proc/note_direct_attack()
	SIGNAL_HANDLER
	last_direct_attack = world.time

/datum/status_effect/malice_omnislash/proc/reduce_direct_damage(datum/source, list/damage_modifiers, damage, damage_type, def_zone, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(isprojectile(attacking_item) || !isnull(attack_direction) || (last_direct_attack == world.time && (damage_type == BRUTE || damage_type == STAMINA)))
		damage_modifiers.Add(0.05)

/datum/status_effect/malice_omnislash/proc/block_attack_stun()
	SIGNAL_HANDLER
	if(last_direct_attack == world.time)
		return COMPONENT_NO_STUN

/datum/status_effect/malice_omnislash/proc/block_attack_unconsciousness(datum/source, duration, ignore_canstun)
	SIGNAL_HANDLER
	if(last_direct_attack == world.time && duration > 0 && !ignore_canstun)
		return COMPONENT_NO_STUN

/datum/status_effect/malice_omnislash/tick(seconds_between_ticks)
	if(!can_continue())
		qdel(src)
		return

	var/mob/living/victim
	var/reach = first_target ? MALICE_OPENING_RANGE : MALICE_FOLLOWUP_RANGE
	if(first_target)
		victim = first_target.resolve()
		first_target = null
	else
		victim = find_next_target()
	if(!can_reach_target(victim, reach) || !dash_to(victim))
		qdel(src)
		return
	var/datum/weakref/victim_ref = WEAKREF(victim)
	strike_counts[victim_ref] = (strike_counts[victim_ref] || 0) + 1
	slash_target(victim)
	if(QDELETED(src))
		return
	strikes_left--
	if(!strikes_left)
		qdel(src)

/datum/status_effect/malice_omnislash/proc/can_reach_target(mob/living/victim, reach = MALICE_FOLLOWUP_RANGE)
	return !QDELETED(victim) && victim != owner && isturf(victim.loc) && victim.stat != DEAD && victim.z == owner.z && get_dist(victim, owner) <= reach && !owner.has_ally(victim) && !victim.has_ally(owner) && find_landing(victim)

/datum/status_effect/malice_omnislash/proc/find_next_target()
	var/list/candidates = list()
	var/fewest_strikes = INFINITY
	for(var/mob/living/candidate in view(MALICE_FOLLOWUP_RANGE, owner))
		var/strikes = strike_counts[WEAKREF(candidate)] || 0
		if(strikes > fewest_strikes || !can_reach_target(candidate))
			continue
		if(strikes < fewest_strikes)
			candidates.Cut()
			fewest_strikes = strikes
		candidates += candidate
	return length(candidates) ? pick(candidates) : null

/// A sword leap clears people, but its landing and the line to it must be free of dense terrain.
/proc/legendary_sword_can_leap(mob/living/user, turf/destination)
	var/turf/origin = user.loc
	if(!istype(origin) || !isopenturf(destination) || origin.z != destination.z || user.buckled)
		return FALSE
	if(origin == destination)
		return TRUE
	if(destination.is_blocked_turf())
		return FALSE
	var/turf/previous = origin
	for(var/turf/line_tile in get_line(origin, destination) - origin)
		if(line_tile.is_blocked_turf(exclude_mobs = TRUE) || !line_tile.Adjacent(previous, mover = user))
			return FALSE
		previous = line_tile
	return previous == destination

/// Cross the target when possible. In a tight space the wielder can still strike from an adjacent tile.
/datum/status_effect/malice_omnislash/proc/find_landing(mob/living/victim)
	var/across = get_dir(owner, victim) || owner.dir
	for(var/angle in list(0, 45, -45, 90, -90, 135, -135, 180))
		var/turf/tile = get_step(victim, turn(across, angle))
		if(tile?.Adjacent(victim, mover = owner) && legendary_sword_can_leap(owner, tile))
			return tile
	if(owner.Adjacent(victim))
		return get_turf(owner)
	return null

/datum/status_effect/malice_omnislash/proc/dash_to(mob/living/victim)
	var/turf/landing = find_landing(victim)
	if(!landing)
		return FALSE
	var/turf/origin = owner.loc
	if(origin != landing)
		var/obj/effect/temp_visual/decoy/fading/halfsecond/echo = new(origin, owner, 150)
		echo.color = COLOR_DARK_RED
		owner.forceMove(landing)
	if(!can_continue() || owner.loc != landing || QDELETED(victim) || victim.stat == DEAD || !isturf(victim.loc) || !owner.Adjacent(victim))
		return FALSE
	owner.setDir(get_dir(owner, victim) || owner.dir)
	return TRUE

/datum/status_effect/malice_omnislash/proc/slash_target(mob/living/victim)
	// Strike from the landing without spending a primed Last Rage or triggering the ordinary sword dash.
	var/cut_direction = owner.dir
	var/turf/impact_turf = get_turf(victim)
	var/list/modifiers = list(FORCE_OVERRIDE = saber.two_hand_force, SILENCE_HITSOUND = TRUE)
	victim.attackby(saber, owner, null, modifiers)
	if(!(modifiers[DAMAGE_DONE] > 0))
		return
	var/impact_sound = 'modular_bandastation/weapon/sound/melee/malice_harvest_hit1.ogg'
	var/impact_type = /obj/effect/temp_visual/malice_rage/harvest
	if(strikes_left == 1)
		impact_sound = 'modular_bandastation/weapon/sound/melee/malice_harvest_hit3.ogg'
		impact_type = /obj/effect/temp_visual/malice_rage/harvest/finish
	else if(strikes_left % 2)
		impact_sound = 'modular_bandastation/weapon/sound/melee/malice_harvest_hit2.ogg'
		impact_type = /obj/effect/temp_visual/malice_rage/harvest/falling
	playsound(impact_turf, impact_sound, 55, FALSE)
	if(!QDELETED(victim))
		new impact_type(victim, cut_direction)

/obj/effect/temp_visual/malice_rage/harvest
	icon = 'modular_bandastation/weapon/icons/melee/malice_harvest.dmi'
	icon_state = "rising"
	duration = 0.3 SECONDS

/obj/effect/temp_visual/malice_rage/harvest/falling
	icon_state = "falling"

/obj/effect/temp_visual/malice_rage/harvest/finish
	icon_state = "finish"
	duration = 0.6 SECONDS

#undef MALICE_OPENING_RANGE
#undef MALICE_FOLLOWUP_RANGE
