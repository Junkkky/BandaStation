/datum/action/cooldown/legendary_sword/malice_dance
	name = "Танец Злобы"
	desc = "Пять секунд вы можете двигаться, вращая Злобу. Каждые полсекунды все в пределах одной клетки, включая союзников, получают удар силой в 2/7 от базового урона раскрытого меча."
	button_icon_state = "malice_dance"
	cooldown_time = 12 SECONDS

/datum/action/cooldown/legendary_sword/malice_dance/Activate(atom/target)
	var/mob/living/user = owner
	if(!user?.apply_status_effect(/datum/status_effect/malice_dance, saber, required_bond))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/malice_dance
	parent_type = /datum/status_effect/legendary_sword_sequence
	id = "malice_sequence"
	tick_interval = STATUS_EFFECT_NO_TICK
	/// Elapsed deciseconds; each half-second revolution deals one melee hit per target.
	var/spin_time = 0
	var/start_direction
	var/mutable_appearance/blade_trail
	/// Follows the wielder until the recording ends or the spin is interrupted.
	var/datum/sound_token/dance_sound

/datum/status_effect/malice_dance/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond)
	if(!..())
		return FALSE
	start_direction = owner.dir
	blade_trail = mutable_appearance('modular_bandastation/weapon/icons/melee/malice_spin.dmi', "malice_spin", ABOVE_MOB_LAYER)
	blade_trail.pixel_x = -16
	blade_trail.pixel_y = -16
	owner.add_overlay(blade_trail)
	dance_sound = playsoundtoken(owner, 'modular_bandastation/weapon/sound/melee/malice_dance.ogg', volume = 45, range = SOUND_RANGE)
	owner.visible_message(span_warning("[capitalize(owner.declent_ru(NOMINATIVE))] раскручивает багровые лезвия Злобы!"))
	addtimer(CALLBACK(src, PROC_REF(advance_spin)), 1 DECISECONDS, TIMER_LOOP | TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/malice_dance/on_remove()
	QDEL_NULL(dance_sound)
	if(blade_trail)
		owner.cut_overlay(blade_trail)
		blade_trail = null
	return ..()

/datum/status_effect/malice_dance/proc/advance_spin()
	if(!can_continue())
		qdel(src)
		return
	spin_time += 1 DECISECONDS
	owner.setDir(turn(start_direction, -90 * round(4 * spin_time / (0.5 SECONDS))))
	if(spin_time % (0.5 SECONDS))
		return
	var/impact_delay = 0
	for(var/mob/living/victim in view(1, owner))
		if(!can_continue())
			break
		if(victim == owner || QDELETED(victim) || victim.stat == DEAD || !isturf(victim.loc) || !owner.Adjacent(victim))
			continue
		var/turf/victim_turf = victim.loc
		if(strike(victim, round(saber.two_hand_force * 2 / 7, 1), silence_hitsound = TRUE) <= 0)
			continue
		impact_delay = play_malice_sweep_hit(victim_turf, impact_delay)
	if(spin_time >= 5 SECONDS)
		// Let the last blade sweep decay naturally after a completed spin.
		dance_sound = null
		qdel(src)

/// Staggers the sound, but never the damage, when two blades sweep through a group.
/proc/play_malice_sweep_hit(turf/victim_turf, delay)
	var/datum/callback/impact = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), victim_turf, 'modular_bandastation/weapon/sound/melee/malice_dance_hit.ogg', 40, FALSE)
	if(delay)
		addtimer(impact, delay)
	else
		impact.Invoke()
	return (delay + 1 DECISECONDS) % (4 DECISECONDS)

/datum/action/cooldown/legendary_sword/malice_shadow
	name = "Тень Злобы"
	desc = "Следующий рывок оставляет тень на клетке старта. Через 0,6 секунды она наносит круговой удар с полной силой раскрытого меча по всем в радиусе одной клетки, кроме самого мечника."
	button_icon_state = "malice_shadow"
	required_bond = 50
	cooldown_time = 25 SECONDS
	/// True after activation until the next successful ordinary dash.
	var/primed = FALSE

/datum/action/cooldown/legendary_sword/malice_shadow/Activate(atom/target)
	if(primed)
		to_chat(owner, span_notice("Злоба ждёт вашего следующего рывка."))
		return FALSE
	primed = TRUE
	to_chat(owner, span_notice("Злоба готова оставить тень после рывка."))
	return TRUE

/datum/action/cooldown/legendary_sword/malice_shadow/Remove(mob/removed_from)
	primed = FALSE
	return ..()

/datum/action/cooldown/legendary_sword/malice_shadow/OnSwordDash(mob/living/user, turf/origin)
	if(!primed || !origin)
		return
	primed = FALSE
	StartCooldown()
	var/obj/effect/temp_visual/decoy/shadow = new(origin, user)
	animate(shadow, color = COLOR_DARK_RED, alpha = 150, time = 6 DECISECONDS)
	addtimer(CALLBACK(src, PROC_REF(shadow_strike), WEAKREF(user), origin, WEAKREF(shadow)), 6 DECISECONDS)

/// The shadow swings from the dash's origin while the same owner still wields the sword.
/datum/action/cooldown/legendary_sword/malice_shadow/proc/shadow_strike(datum/weakref/user_ref, turf/origin, datum/weakref/shadow_ref)
	var/mob/living/user = user_ref.resolve()
	var/obj/effect/temp_visual/decoy/shadow = shadow_ref.resolve()
	if(QDELETED(shadow) || QDELETED(origin) || !can_shadow_strike(user, origin))
		return
	new /obj/effect/temp_visual/malice_shadow_sweep(origin)
	animate(shadow, alpha = 0, time = 4 DECISECONDS)
	var/impact_delay = 0
	for(var/mob/living/victim in range(1, origin))
		if(victim == user || QDELETED(victim) || victim.stat == DEAD || !isturf(victim.loc) || !origin.Adjacent(victim))
			continue
		var/turf/victim_turf = victim.loc
		var/list/attack_modifiers = list(FORCE_OVERRIDE = saber.two_hand_force, MELEE_EFFECT_ORIGIN = origin, SILENCE_HITSOUND = TRUE)
		victim.attackby(saber, user, null, attack_modifiers)
		if(attack_modifiers[DAMAGE_DONE] > 0)
			impact_delay = play_malice_sweep_hit(victim_turf, impact_delay)
		if(!can_shadow_strike(user, origin))
			break

/datum/action/cooldown/legendary_sword/malice_shadow/proc/can_shadow_strike(mob/living/user, turf/origin)
	return !QDELETED(user) && user == owner && user.z == origin.z && get_dist(user, origin) <= 5 && saber?.can_use_legendary_ability(user, required_bond) && !HAS_TRAIT(user, TRAIT_PACIFISM)

/obj/effect/temp_visual/malice_shadow_sweep
	icon = 'modular_bandastation/weapon/icons/melee/malice_spin.dmi'
	icon_state = "malice_spin"
	pixel_x = -16
	pixel_y = -16
	color = "#c68ca8"
	randomdir = FALSE
	duration = 0.5 SECONDS

/datum/action/cooldown/legendary_sword/malice_rage
	name = "Последняя ярость"
	desc = "На 5 секунд заряжает Злобу. Первое успешное попадание наносит двойной урон, лечит до 10 ед. физического урона и возвращает до 15 ед. выносливости. Попадание по плоти вызывает сильное кровотечение."
	button_icon_state = "malice_rage"
	required_bond = 100
	cooldown_time = 45 SECONDS
	/// Deadline for the follow-up hit.
	var/rage_until = 0
	/// Keep a counterattack triggered inside this swing from claiming the same charge.
	var/resolving_critical = FALSE
	/// Actual limb hit by this swing after melee accuracy and damage resolution.
	var/obj/item/bodypart/critical_limb
	/// Red glow for the short window during which rage can be discharged.
	var/datum/weakref/rage_light_ref

/datum/action/cooldown/legendary_sword/malice_rage/Activate(atom/target)
	var/mob/living/user = owner
	rage_until = world.time + 5 SECONDS
	rage_light_ref = WEAKREF(new /obj/effect/dummy/lighting_obj/moblight/malice_rage(user, saber))
	playsoundtoken(user, 'modular_bandastation/weapon/sound/melee/malice_rage_cry.ogg', volume = 50, range = SOUND_RANGE)
	user.visible_message(span_warning("Злоба в руках [user.declent_ru(GENITIVE)] вспыхивает багровым светом."), span_notice("Следующее попадание Злобы будет критическим!"))
	StartCooldown()
	return TRUE

/datum/action/cooldown/legendary_sword/malice_rage/Remove(mob/removed_from)
	clear_rage()
	return ..()

/// Only a swing by the wielder enters the melee chain; the shadow attacks separately.
/obj/item/dualsaber/legendary_saber/melee_attack_chain(mob/user, atom/target, list/modifiers, list/attack_modifiers = list())
	var/datum/action/cooldown/legendary_sword/malice_rage/rage = locate() in actions
	var/mob/living/victim = target
	if(!rage || world.time >= rage.rage_until || rage.resolving_critical || rage.owner != user || !istype(victim) || victim == user || victim.stat == DEAD || !can_use_legendary_ability(user, rage.required_bond))
		return ..()

	attack_modifiers ||= list()
	var/previous_multiplier = attack_modifiers[FORCE_MULTIPLIER]
	var/previous_hit_effects = attack_modifiers[REPLACE_MELEE_HIT_EFFECTS]
	var/strike_direction = get_dir(user, victim) || user.dir
	var/turf/impact_turf = get_turf(victim)
	attack_modifiers -= DAMAGE_DONE
	attack_modifiers[REPLACE_MELEE_HIT_EFFECTS] = TRUE
	MODIFY_ATTACK_FORCE_MULTIPLIER(attack_modifiers, 2)
	rage.resolving_critical = TRUE
	rage.RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, TYPE_PROC_REF(/datum/action/cooldown/legendary_sword/malice_rage, record_critical_limb))
	. = ..(user, target, modifiers, attack_modifiers)
	if(isnull(previous_multiplier))
		attack_modifiers -= FORCE_MULTIPLIER
	else
		attack_modifiers[FORCE_MULTIPLIER] = previous_multiplier
	if(isnull(previous_hit_effects))
		attack_modifiers -= REPLACE_MELEE_HIT_EFFECTS
	else
		attack_modifiers[REPLACE_MELEE_HIT_EFFECTS] = previous_hit_effects
	if(QDELETED(rage))
		return
	if(!QDELETED(victim))
		rage.UnregisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	rage.resolving_critical = FALSE
	var/obj/item/bodypart/limb = rage.critical_limb
	rage.critical_limb = null
	if(attack_modifiers[DAMAGE_DONE] > 0)
		rage.clear_rage()
		var/mob/living/wielder = user
		if(!QDELETED(victim))
			impact_turf = get_turf(victim) || impact_turf
			if(!QDELETED(wielder))
				strike_direction = get_dir(wielder, victim) || strike_direction
			new /obj/effect/temp_visual/malice_rage/impact(victim, strike_direction)
			play_fov_effect(victim, 5, "attack")
		if(impact_turf && !attack_modifiers[SILENCE_HITSOUND])
			// Frame four of the critical strike is the instant the blade makes contact.
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), impact_turf, 'modular_bandastation/weapon/sound/melee/malice_rage_hit.ogg', 80, FALSE), 0.15 SECONDS)
		if(!QDELETED(wielder) && wielder.stat != DEAD)
			new /obj/effect/temp_visual/malice_rage/release(wielder, strike_direction, src)
			wielder.adjust_brute_loss(-10)
			wielder.adjust_stamina_loss(-15)
			to_chat(wielder, span_danger("Критический удар! Злоба возвращает вам силы."))
		if(!QDELETED(victim) && !QDELETED(limb) && limb.owner == victim && limb.can_bleed())
			limb.force_wound_upwards(/datum/wound/slash/flesh/critical, wound_source = src)
			var/datum/wound/slash/flesh/critical/cut = locate() in limb.wounds
			if(cut)
				cut.set_blood_flow(WOUND_MAX_BLOODFLOW)

/datum/action/cooldown/legendary_sword/malice_rage/proc/record_critical_limb(datum/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, obj/item/attacking_item)
	SIGNAL_HANDLER
	if(damage_dealt > 0 && attacking_item == saber && isbodypart(def_zone))
		critical_limb = def_zone

/// Removes the telegraph as soon as the prepared strike is used or the sword leaves the owner.
/datum/action/cooldown/legendary_sword/malice_rage/proc/clear_rage()
	rage_until = 0
	var/obj/effect/dummy/lighting_obj/glow = rage_light_ref?.resolve()
	rage_light_ref = null
	qdel(glow)

/obj/effect/dummy/lighting_obj/moblight/malice_rage
	icon = 'modular_bandastation/weapon/icons/melee/malice_rage.dmi'
	icon_state = "charge"
	layer = ABOVE_MOB_LAYER
	vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_PLANE
	pixel_x = -16
	pixel_y = -16
	/// Tiles under the last pulse may differ from the wielder's current location.
	var/turf/ripple_origin

/obj/effect/dummy/lighting_obj/moblight/malice_rage/Initialize(mapload, obj/item/dualsaber/legendary_saber/saber)
	. = ..(mapload, 2, 1, LIGHT_COLOR_INTENSE_RED, 5 SECONDS)
	if(. == INITIALIZE_HINT_QDEL || !saber)
		return INITIALIZE_HINT_QDEL
	var/mob/wielder = loc
	wielder.vis_contents += src
	flick("charge", src)
	RegisterSignal(saber, COMSIG_TWOHANDED_UNWIELD, PROC_REF(hide_blade))
	RegisterSignal(saber, SIGNAL_ADDTRAIT(TRAIT_WIELDED), PROC_REF(show_blade))
	addtimer(CALLBACK(src, PROC_REF(ripple_floor)), 0.2 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(ripple_floor)), 0.55 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(clear_floor_ripple)), 1.1 SECONDS)

/obj/effect/dummy/lighting_obj/moblight/malice_rage/Destroy()
	clear_floor_ripple()
	return ..()

/obj/effect/dummy/lighting_obj/moblight/malice_rage/proc/ripple_floor()
	clear_floor_ripple()
	var/mob/wielder = loc
	if(!isturf(wielder?.loc) || !(src in wielder.vis_contents))
		return
	ripple_origin = wielder.loc
	var/filter_name = "malice_ripple_[REF(src)]"
	for(var/turf/open/tile in RANGE_TURFS(1, ripple_origin))
		if(!is_anchorable_floor(tile))
			continue
		var/offset_x = (ripple_origin.x - tile.x) * ICON_SIZE_ALL
		var/offset_y = (ripple_origin.y - tile.y) * ICON_SIZE_ALL
		tile.add_filter(filter_name, 2, ripple_filter(x = offset_x, y = offset_y, radius = 9, size = 2, flags = WAVE_BOUNDED))
		animate(tile.get_filter(filter_name), radius = 28, size = 0, time = 0.45 SECONDS)

/obj/effect/dummy/lighting_obj/moblight/malice_rage/proc/clear_floor_ripple()
	if(ripple_origin)
		var/filter_name = "malice_ripple_[REF(src)]"
		for(var/turf/open/tile in RANGE_TURFS(1, ripple_origin))
			tile.remove_filter(filter_name)
		ripple_origin = null

/obj/effect/dummy/lighting_obj/moblight/malice_rage/proc/hide_blade(datum/source, mob/wielder)
	SIGNAL_HANDLER
	wielder.vis_contents -= src
	set_light_on(FALSE)
	clear_floor_ripple()

/obj/effect/dummy/lighting_obj/moblight/malice_rage/proc/show_blade(obj/item/saber)
	SIGNAL_HANDLER
	var/mob/wielder = loc
	if(saber.loc == wielder)
		wielder.vis_contents |= src
		set_light_on(TRUE)

/obj/effect/temp_visual/malice_rage
	icon = 'modular_bandastation/weapon/icons/melee/malice_critical_strike.dmi'
	icon_state = "strike"
	randomdir = FALSE
	vis_flags = VIS_INHERIT_PLANE
	pixel_x = -32
	pixel_y = -32
	duration = 0.65 SECONDS

/obj/effect/temp_visual/malice_rage/Initialize(mapload, strike_direction)
	. = ..()
	if(!ismob(loc))
		return INITIALIZE_HINT_QDEL
	var/mob/recipient = loc
	setDir(strike_direction)
	recipient.vis_contents += src
	flick(icon_state, src)

/obj/effect/temp_visual/malice_rage/release
	/// The moving blade replaces only this item's in-hand appearance during the swing.
	var/obj/item/dualsaber/legendary_saber/swing_saber

/obj/effect/temp_visual/malice_rage/release/Initialize(mapload, strike_direction, obj/item/dualsaber/legendary_saber/saber)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	var/mob/living/wielder = loc
	var/list/offset = dir2offset(strike_direction)
	animate(wielder, pixel_w = -2 * offset[1], pixel_z = -2 * offset[2], time = 0.1 SECONDS, flags = ANIMATION_PARALLEL | ANIMATION_RELATIVE)
	animate(pixel_w = 7 * offset[1], pixel_z = 7 * offset[2], time = 0.05 SECONDS, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_RELATIVE)
	animate(pixel_w = -5 * offset[1], pixel_z = -5 * offset[2], time = 0.25 SECONDS, easing = SINE_EASING, flags = ANIMATION_RELATIVE)
	if(QDELETED(saber) || saber.loc != wielder || !HAS_TRAIT(saber, TRAIT_WIELDED))
		return
	swing_saber = saber
	RegisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS, PROC_REF(hide_resting_blade))
	RegisterSignal(saber, COMSIG_TWOHANDED_UNWIELD, PROC_REF(end_swing))
	wielder.update_held_items()
	addtimer(CALLBACK(src, PROC_REF(restore_resting_blade)), 0.4 SECONDS)

/obj/effect/temp_visual/malice_rage/release/proc/hide_resting_blade(obj/item/source, list/overlays, mutable_appearance/draw_target, isinhands)
	SIGNAL_HANDLER
	if(isinhands && source.loc == loc)
		draw_target.icon = null
		overlays.Cut()

/obj/effect/temp_visual/malice_rage/release/proc/end_swing()
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/temp_visual/malice_rage/release/proc/restore_resting_blade()
	if(!QDELETED(swing_saber))
		UnregisterSignal(swing_saber, list(COMSIG_ITEM_GET_WORN_OVERLAYS, COMSIG_TWOHANDED_UNWIELD))
		var/mob/living/wielder = loc
		if(!QDELETED(wielder) && swing_saber.loc == wielder)
			wielder.update_held_items()
	swing_saber = null

/obj/effect/temp_visual/malice_rage/release/Destroy()
	restore_resting_blade()
	return ..()

/obj/effect/temp_visual/malice_rage/impact
	icon_state = "impact"
