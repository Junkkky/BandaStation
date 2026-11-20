#define BOND_FIRST_STAGE (45 SECONDS)
#define BOND_SECOND_STAGE (BOND_FIRST_STAGE + 90 SECONDS)
#define BOND_FULL_STAGE (BOND_SECOND_STAGE + 3 MINUTES)

/obj/item/dualsaber/legendary_saber
	/// Mind that first meditated with this sword.
	var/datum/weakref/bonded_mind
	/// Total meditation time earned this round, including interrupted sessions.
	var/bond_meditation_time = 0
	/// Whether a meditation session is currently running.
	var/meditating = FALSE
	/// Time of incoming damage during the active meditation.
	var/meditation_damage_time
	/// Last bond milestone addressed in prayer, so resuming a session does not repeat its verse.
	var/last_prayer_milestone = 0
	COOLDOWN_DECLARE(bond_rest)

/// Checks the original wielding permissions and the individual bond, if established.
/obj/item/dualsaber/legendary_saber/proc/has_legendary_bond_access(mob/living/user)
	if(!length(legendary_abilities) || QDELETED(user) || !istype(user))
		return FALSE
	if(bonded_mind && bonded_mind.resolve() != user.mind)
		return FALSE
	var/datum/component/ckey_and_role_locked_pickup/lock = GetComponent(/datum/component/ckey_and_role_locked_pickup)
	return lock?.check_role_and_ckey(user)

/// Checks the current owner, bond tier, and whether the blade can be used.
/obj/item/dualsaber/legendary_saber/proc/can_use_legendary_ability(mob/living/user, required_bond = 0, require_wielded = TRUE)
	if(QDELETED(src) || !has_legendary_bond_access(user) || IS_UNCONSCIOUS_OR_CRIT(user) || HAS_TRAIT(user, TRAIT_INCAPACITATED))
		return FALSE
	if(require_wielded && (!user.is_holding(src) || !HAS_TRAIT(src, TRAIT_WIELDED) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED)))
		return FALSE
	return get_legendary_bond() >= required_bond

/// Converts earned time to bond percent with a different pace for each stage.
/obj/item/dualsaber/legendary_saber/proc/get_legendary_bond(elapsed = bond_meditation_time)
	if(elapsed < BOND_FIRST_STAGE)
		return FLOOR(25 * elapsed / BOND_FIRST_STAGE, 1)
	if(elapsed < BOND_SECOND_STAGE)
		return 25 + FLOOR(25 * (elapsed - BOND_FIRST_STAGE) / (BOND_SECOND_STAGE - BOND_FIRST_STAGE), 1)
	return min(100, 50 + FLOOR(50 * (elapsed - BOND_SECOND_STAGE) / (BOND_FULL_STAGE - BOND_SECOND_STAGE), 1))

/obj/item/dualsaber/legendary_saber/examine(mob/user)
	. = ..()
	if(!has_legendary_bond_access(user))
		return
	var/bond_percent = get_legendary_bond()
	. += span_notice("Узы с клинком: [bond_percent]%.")
	if(bond_percent < 100)
		. += span_notice("Погасите меч, положите рядом и нажмите Alt + ЛКМ по мечу, чтобы медитировать.")

/obj/item/dualsaber/legendary_saber/click_alt(mob/user)
	if(!has_legendary_bond_access(user))
		return ..()
	var/mob/living/meditator = user
	if(!meditator.mind || !can_meditate(meditator, meditator.loc, loc))
		to_chat(user, span_warning("Для медитации положите погашенный меч рядом с собой."))
		return CLICK_ACTION_BLOCKING
	if(meditating)
		return CLICK_ACTION_BLOCKING
	if(bond_meditation_time >= BOND_FULL_STAGE)
		to_chat(user, span_notice("Узы с клинком уже достигли 100%."))
		return CLICK_ACTION_BLOCKING
	if(!COOLDOWN_FINISHED(src, bond_rest))
		to_chat(user, span_notice("До следующей медитации: [CEILING(COOLDOWN_TIMELEFT(src, bond_rest) / (1 SECONDS), 1)] сек."))
		return CLICK_ACTION_BLOCKING
	INVOKE_ASYNC(src, PROC_REF(meditate), meditator)
	return CLICK_ACTION_SUCCESS

/// Validates that the wielder and the inactive sword are still where the meditation began.
/obj/item/dualsaber/legendary_saber/proc/can_meditate(mob/living/user, turf/user_start, turf/sword_start)
	return can_use_legendary_ability(user, require_wielded = FALSE) && isturf(loc) && isturf(user.loc) && loc == sword_start && user.loc == user_start && !HAS_TRAIT(src, TRAIT_WIELDED) && IsReachableBy(user)

/// Saves partial time and enforces a rest between completed stages.
/obj/item/dualsaber/legendary_saber/proc/meditate(mob/living/user)
	if(meditating || !COOLDOWN_FINISHED(src, bond_rest) || bond_meditation_time >= BOND_FULL_STAGE || !can_meditate(user, user?.loc, loc) || !user.mind)
		return
	bonded_mind ||= WEAKREF(user.mind)
	meditating = TRUE
	meditation_damage_time = null
	var/stage_end = BOND_FULL_STAGE
	if(bond_meditation_time < BOND_FIRST_STAGE)
		stage_end = BOND_FIRST_STAGE
	else if(bond_meditation_time < BOND_SECOND_STAGE)
		stage_end = BOND_SECOND_STAGE
	var/start_time = world.time
	var/remaining_time = stage_end - bond_meditation_time
	var/datum/progressbar/bond_bar = new(user, 100, src, get_legendary_bond())
	var/datum/callback/validate = CALLBACK(src, PROC_REF(update_meditation), user, user.loc, loc, bond_bar, start_time, user.health)
	RegisterSignal(user, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_meditation_damage))
	to_chat(user, span_notice("Вы сосредотачиваетесь на клинке."))
	if(type == /obj/item/dualsaber/legendary_saber)
		if(ishuman(user) && user.body_position == STANDING_UP && !user.buckled)
			user.face_atom(src)
		if(stage_end > last_prayer_milestone)
			last_prayer_milestone = stage_end
			speak_malice_prayer(user, stage_end)
	var/completed = do_after(user, remaining_time, src, IGNORE_HELD_ITEM | IGNORE_SLOWDOWNS | DO_AFTER_CHECK_NEXT_MOVE, show_progress = FALSE, extra_checks = validate)
	if(user)
		UnregisterSignal(user, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	qdel(bond_bar)
	if(QDELETED(src))
		return
	var/end_time = isnull(meditation_damage_time) ? world.time : meditation_damage_time
	var/elapsed = end_time - start_time
	bond_meditation_time += completed ? remaining_time : clamp(elapsed, 0, remaining_time - 1)
	meditation_damage_time = null
	meditating = FALSE
	if(completed)
		COOLDOWN_START(src, bond_rest, 1 MINUTES)
	if(!QDELETED(user))
		var/bond_percent = get_legendary_bond()
		to_chat(user, span_notice("[completed ? "Ступень медитации завершена." : "Медитация прервана."] Узы с клинком: [bond_percent]%."))

/// Each stage addresses the anger sleeping in Malice, even when the wielder cannot speak aloud.
/obj/item/dualsaber/legendary_saber/proc/speak_malice_prayer(mob/living/user, milestone)
	var/verse
	switch(milestone)
		if(BOND_FIRST_STAGE)
			verse = "Злоба, ты помнишь руку, что тебя выковала. Запомни и мою. Я узнаю в тебе свой гнев. Он тоже умеет ждать."
		if(BOND_SECOND_STAGE)
			verse = "Я слышу твой гнев и в погасшем клинке. Ты рвёшься на волю. Тише, Злоба. Пока моя ладонь раскрыта, пусть твой кровавый свет спит в рукояти."
		if(BOND_FULL_STAGE)
			verse = "Когда нас разделят время и пустота, узнай мой голос, Злоба. Вернись в мою руку. Клянусь обуздать наш гнев. По моему слову вспыхни, по моему слову угасни."
		else
			return
	if(user.can_speak() && !HAS_TRAIT(user, TRAIT_SIGN_LANG))
		user.whisper(verse)
	else
		to_chat(user, span_notice("Вы произносите про себя: «[verse]»"))

/// Advances the displayed bond percentage while the current meditation remains valid.
/obj/item/dualsaber/legendary_saber/proc/update_meditation(mob/living/user, turf/user_start, turf/sword_start, datum/progressbar/bond_bar, start_time, start_health)
	if(!isnull(meditation_damage_time) || !can_meditate(user, user_start, sword_start) || user.health < start_health)
		return FALSE
	bond_bar.update(get_legendary_bond(bond_meditation_time + world.time - start_time))
	return TRUE

/// Interrupts meditation when the user takes damage.
/obj/item/dualsaber/legendary_saber/proc/on_meditation_damage(datum/source, damage_dealt)
	SIGNAL_HANDLER
	if(damage_dealt > 0 && isnull(meditation_damage_time))
		meditation_damage_time = world.time

/datum/action/cooldown/legendary_sword
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_HANDS_BLOCKED
	button_icon = 'modular_bandastation/weapon/icons/melee/legendary_abilities.dmi'
	transparent_when_unavailable = TRUE
	/// Sword that grants this action.
	var/obj/item/dualsaber/legendary_saber/saber
	/// Bond percentage required to use this action.
	var/required_bond = 0

/datum/action/cooldown/legendary_sword/New(Target)
	saber = Target
	return ..()

/datum/action/cooldown/legendary_sword/Destroy()
	saber = null
	return ..()

/datum/action/cooldown/legendary_sword/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	if(saber?.can_use_legendary_ability(owner, required_bond))
		return TRUE
	if(feedback && owner && !QDELETED(saber))
		to_chat(owner, span_notice("Возьмите погашенный меч в обе руки, чтобы зажечь его. Требуемые узы: [required_bond]%."))
	return FALSE

/datum/action/cooldown/legendary_sword/Trigger(mob/clicker, trigger_flags, atom/target)
	if(clicker && clicker != owner)
		return FALSE
	return ..()

/datum/action/cooldown/legendary_sword/PreActivate(atom/target)
	if(!IsAvailable(feedback = TRUE))
		return FALSE
	return ..()

/// The wielder reached a target using the sword's ordinary dash.
/datum/action/cooldown/legendary_sword/proc/OnSwordDash(mob/living/user, turf/origin)
	return

/// Owns the temporary attack lock and stops the sequence when the sword or bearer becomes unavailable.
/datum/status_effect/legendary_sword_sequence
	id = "legendary_sword_sequence"
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Sword responsible for this sequence.
	var/obj/item/dualsaber/legendary_saber/saber
	/// Required attunement, retained for revalidation on each strike.
	var/required_bond
	/// Prevents our pre-attack signal from canceling the sequence's own strike.
	var/performing_strike = FALSE

/datum/status_effect/legendary_sword_sequence/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond)
	src.saber = saber
	src.required_bond = required_bond
	if(!can_continue())
		return FALSE
	RegisterSignals(owner, list(COMSIG_USER_PRE_ITEM_ATTACK, COMSIG_USER_PRE_ITEM_ATTACK_SECONDARY), PROC_REF(block_manual_attack))
	RegisterSignal(owner, COMSIG_MOB_STATCHANGE, PROC_REF(check_stat))
	RegisterSignals(owner, list(SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), SIGNAL_ADDTRAIT(TRAIT_IMMOBILIZED), SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED)), PROC_REF(stop_sequence))
	RegisterSignals(saber, list(COMSIG_TWOHANDED_UNWIELD, COMSIG_ITEM_DROPPED, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(stop_sequence))
	return TRUE

/datum/status_effect/legendary_sword_sequence/on_remove()
	UnregisterSignal(owner, list(
		COMSIG_USER_PRE_ITEM_ATTACK,
		COMSIG_USER_PRE_ITEM_ATTACK_SECONDARY,
		COMSIG_MOB_STATCHANGE,
		SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
		SIGNAL_ADDTRAIT(TRAIT_IMMOBILIZED),
		SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED),
	))
	if(saber)
		UnregisterSignal(saber, list(COMSIG_TWOHANDED_UNWIELD, COMSIG_ITEM_DROPPED, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		saber = null
	return ..()

/datum/status_effect/legendary_sword_sequence/proc/can_continue()
	if(QDELETED(src) || QDELETED(owner) || QDELETED(saber) || !isturf(owner.loc) || owner.buckled || saber.loc != owner)
		return FALSE
	return !HAS_TRAIT(owner, TRAIT_IMMOBILIZED) && !HAS_TRAIT(owner, TRAIT_PACIFISM) && saber.can_use_legendary_ability(owner, required_bond)

/datum/status_effect/legendary_sword_sequence/proc/strike(mob/living/victim, damage, silence_hitsound = FALSE)
	performing_strike = TRUE
	. = saber.legendary_strike(owner, victim, damage, silence_hitsound)
	performing_strike = FALSE

/datum/status_effect/legendary_sword_sequence/proc/block_manual_attack()
	SIGNAL_HANDLER
	if(!performing_strike)
		return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/status_effect/legendary_sword_sequence/proc/check_stat(datum/source, new_stat)
	SIGNAL_HANDLER
	if(new_stat >= SOFT_CRIT)
		qdel(src)

/datum/status_effect/legendary_sword_sequence/proc/stop_sequence()
	SIGNAL_HANDLER
	qdel(src)

#undef BOND_FIRST_STAGE
#undef BOND_SECOND_STAGE
#undef BOND_FULL_STAGE
