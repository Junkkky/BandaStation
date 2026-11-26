#define SISTER_DOME_DAMAGE_PER_100_STAMINA 220

/datum/action/cooldown/legendary_sword/sister_dome
	name = "Световой купол"
	desc = "Пустите свет по лезвию, чтобы укрыть всех в радиусе двух клеток. Те, кто был внутри, могут выйти и вернуться. 100 единиц выносливости хватает на 220 единиц поглощённого урона. Когда выносливость иссякнет, купол лопнет. Нажмите ещё раз, чтобы рассеять купол."
	button_icon = 'modular_bandastation/weapon/icons/melee/sister_dome_action.dmi'
	button_icon_state = "sister_dome"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_HANDS_BLOCKED | AB_CHECK_LYING | AB_CHECK_OPEN_TURF
	cooldown_time = 30 SECONDS
	/// The field currently sustained by this sword. Recovery starts when the field goes down.
	var/obj/effect/sister_light_dome/active_dome

/// The wielder can sustain the field up to stamcrit or the maximum payable stamina loss.
/datum/action/cooldown/legendary_sword/sister_dome/proc/has_stamina()
	var/mob/living/wielder = owner
	return wielder.get_stamina_loss() < min(wielder.max_stamina, wielder.maxHealth - wielder.crit_threshold)

/datum/action/cooldown/legendary_sword/sister_dome/Activate(atom/target)
	if(active_dome)
		qdel(active_dome)
		return TRUE
	var/mob/living/user = owner
	if(!isopenturf(user?.loc) || user.buckled)
		return FALSE
	if(!has_stamina())
		to_chat(user, span_warning("У вас не хватает выносливости, чтобы поднять купол."))
		return FALSE
	active_dome = new(user.loc, src)
	return TRUE

/datum/action/cooldown/legendary_sword/sister_dome/Remove(mob/removed_from)
	qdel(active_dome)
	return ..()

/datum/action/cooldown/legendary_sword/sister_dome/Destroy()
	qdel(active_dome)
	return ..()

/// All segments of the field draw on its caster's stamina and admit the original occupants.
/obj/effect/sister_light_dome
	name = "световой купол"
	anchored = TRUE
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/datum/action/cooldown/legendary_sword/sister_dome/ability
	var/mob/living/caster
	var/obj/item/dualsaber/legendary_saber/saber
	var/obj/effect/sister_dome_visual/visual
	/// Fraction left over when converting an impact into a payable stamina cost.
	var/stamina_cost_remainder = 0
	var/list/admitted = list()
	var/list/barriers = list()

/obj/effect/sister_light_dome/Initialize(mapload, datum/action/cooldown/legendary_sword/sister_dome/ability)
	. = ..()
	if(!ability?.owner || !ability.saber)
		return INITIALIZE_HINT_QDEL
	src.ability = ability
	caster = ability.owner
	saber = ability.saber
	for(var/turf/tile as anything in RANGE_TURFS(2, src))
		if(!contains_turf(tile))
			continue
		RegisterSignal(tile, COMSIG_ATOM_INTERCEPT_TELEPORTING, PROC_REF(block_teleport))
		for(var/mob/living/occupant as anything in tile.get_all_contents_type(/mob/living))
			admitted[occupant] = TRUE
			RegisterSignal(occupant, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(shield_occupant))
			RegisterSignal(occupant, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(shield_point_blank))
			RegisterSignal(occupant, COMSIG_QDELETING, PROC_REF(forget_occupant))
		if(abs(tile.x - x) + abs(tile.y - y) >= 2)
			barriers += new /obj/structure/sister_dome_barrier(tile, src)

	RegisterSignals(caster, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED)), PROC_REF(lower_dome))
	RegisterSignal(caster, COMSIG_MOB_STATCHANGE, PROC_REF(check_stat))
	// Batched stamina damage can enter stamcrit before the next stamina HUD update.
	RegisterSignals(caster, list(COMSIG_LIVING_STAMINA_UPDATE, COMSIG_LIVING_ENTER_STAMCRIT), PROC_REF(check_stamina))
	RegisterSignals(caster, list(COMSIG_USER_PRE_ITEM_ATTACK, COMSIG_USER_PRE_ITEM_ATTACK_SECONDARY), PROC_REF(block_attack))
	RegisterSignal(caster, COMSIG_MOB_ABILITY_STARTED, PROC_REF(block_sword_ability))
	RegisterSignals(saber, list(COMSIG_TWOHANDED_UNWIELD, COMSIG_ITEM_DROPPED, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(lower_dome))
	ADD_TRAIT(caster, TRAIT_IMMOBILIZED, REF(src))
	visual = new(loc, caster, saber)
	caster.visible_message(span_notice("По лезвию Светлой Сестры в руках [caster.declent_ru(GENITIVE)] пробегает серебряный блик. От острия расходится купол света!"), span_notice("По вашему клинку пробегает серебряный блик, и вокруг вас раскрывается купол."))
	playsound(src, 'modular_bandastation/weapon/sound/melee/sister_dome_open.ogg', 55, FALSE)

/obj/effect/sister_light_dome/Destroy()
	if(caster)
		REMOVE_TRAIT(caster, TRAIT_IMMOBILIZED, REF(src))
		caster = null
	if(ability?.active_dome == src)
		ability.active_dome = null
		if(!QDELETED(ability))
			ability.StartCooldown()
	ability = null
	saber = null
	admitted.Cut()
	QDEL_LIST(barriers)
	QDEL_NULL(visual)
	return ..()

/// The 5-by-5 footprint omits the four corners. Movement and protection use the same boundary.
/obj/effect/sister_light_dome/proc/contains_turf(turf/tile)
	if(!tile || tile.z != z)
		return FALSE
	var/dx = abs(tile.x - x)
	var/dy = abs(tile.y - y)
	return max(dx, dy) <= 2 && dx + dy <= 3

/// Occupants may return in a wheelchair or vehicle as long as everyone it carries was admitted.
/obj/effect/sister_light_dome/proc/is_admitted(atom/movable/mover)
	if(!admitted[mover] && !isvehicle(mover))
		return FALSE
	var/list/passengers = mover.get_all_contents_type(/mob/living)
	for(var/mob/living/rider as anything in mover.buckled_mobs)
		passengers |= rider.get_all_contents_type(/mob/living)
	for(var/mob/living/passenger as anything in passengers)
		if(!admitted[passenger])
			return FALSE
	return length(passengers) > 0

/// Redirects external contact attacks aimed directly at someone standing on the rim.
/obj/effect/sister_light_dome/proc/shield_occupant(mob/living/occupant, atom/hit_by, damage, attack_text, attack_type)
	SIGNAL_HANDLER
	if(attack_type != MELEE_ATTACK && attack_type != UNARMED_ATTACK)
		return NONE
	var/turf/origin = get_turf(hit_by)
	if(origin && !contains_turf(origin) && contains_turf(get_turf(occupant)))
		apply_impact(damage)
		return SUCCESSFUL_BLOCK

/// A point-blank shot resolves against the target before the projectile starts moving.
/obj/effect/sister_light_dome/proc/shield_point_blank(mob/living/occupant, obj/projectile/shot)
	SIGNAL_HANDLER
	if(!QDELETED(shot) && !shot.fired && !contains_turf(get_turf(shot)) && contains_turf(get_turf(occupant)))
		absorb_projectile(shot, get_turf(occupant))
		return COMPONENT_BULLET_BLOCKED

/// Consume the projectile before shattering so even a piercing round stops at this hit.
/obj/effect/sister_light_dome/proc/absorb_projectile(obj/projectile/shot, turf/impact_tile)
	var/damage = shot.damage
	qdel(shot)
	new /obj/effect/temp_visual/impact_effect/ion/sister_dome(impact_tile)
	apply_impact(damage)

/// Catch the projectile in a brief silver flash matching the blade.
/obj/effect/temp_visual/impact_effect/ion/sister_dome
	color = COLOR_MATRIX_GRAYSCALE

/obj/effect/sister_light_dome/proc/block_teleport(turf/source, channel, turf/origin, turf/destination, atom/movable/traveller)
	SIGNAL_HANDLER
	if(!contains_turf(origin) && !isobserver(traveller) && !is_admitted(traveller))
		return COMPONENT_INTERCEPT_TELEPORT

/obj/effect/sister_light_dome/proc/forget_occupant(mob/living/occupant)
	SIGNAL_HANDLER
	admitted -= occupant
	if(occupant == caster)
		qdel(src)

/obj/effect/sister_light_dome/proc/block_attack()
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_ATTACK_CHAIN | COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN

/obj/effect/sister_light_dome/proc/block_sword_ability(mob/source, datum/action/cooldown/other)
	SIGNAL_HANDLER
	if(other != ability && istype(other, /datum/action/cooldown/legendary_sword))
		return COMPONENT_BLOCK_ABILITY_START

/obj/effect/sister_light_dome/proc/check_stat(mob/living/source, new_stat)
	SIGNAL_HANDLER
	if(new_stat >= SOFT_CRIT)
		qdel(src)

/obj/effect/sister_light_dome/proc/lower_dome()
	SIGNAL_HANDLER
	qdel(src)

/// The field absorbs the entire hit, including the one that exhausts the wielder.
/obj/effect/sister_light_dome/proc/apply_impact(damage)
	if(QDELETED(src) || damage <= 0)
		return
	var/stamina_due = damage * 100 / SISTER_DOME_DAMAGE_PER_100_STAMINA + stamina_cost_remainder
	// Binary fractions add exactly to the stamina pool even across many small hits.
	var/stamina_cost = round(stamina_due, 1 / 1024)
	stamina_cost_remainder = stamina_due - stamina_cost
	caster.adjust_stamina_loss(stamina_cost)

/obj/effect/sister_light_dome/proc/check_stamina()
	SIGNAL_HANDLER
	if(QDELETED(src) || ability.has_stamina())
		return
	visual.burst()
	visible_message(span_warning("По световому куполу пробегают трещины. Купол лопается!"))
	playsound(src, 'modular_bandastation/weapon/sound/melee/sister_dome_break.ogg', 65, FALSE)
	qdel(src)

#undef SISTER_DOME_DAMAGE_PER_100_STAMINA

#define SISTER_DAWN_BLADE_ICON 'modular_bandastation/weapon/icons/melee/sister_dawn_blade.dmi'

/datum/action/cooldown/legendary_sword/sister_dawn
	name = "Рассвет"
	desc = "На 8 секунд вас и клинок окутывает белое сияние. Удары Светлой Сестры наносят на 40% больше урона, а пауза между взмахами сокращается на 0,2 секунды. Если выпустить или погасить клинок, сияние исчезнет."
	button_icon = 'modular_bandastation/weapon/icons/melee/sister_dawn_action.dmi'
	button_icon_state = "sister_dawn"
	required_bond = 100
	cooldown_time = 90 SECONDS

/datum/action/cooldown/legendary_sword/sister_dawn/Activate(atom/target)
	var/mob/living/user = owner
	if(!user?.apply_status_effect(/datum/status_effect/sister_dawn, src))
		return FALSE
	playsound(user, 'modular_bandastation/weapon/sound/melee/sister_dawn.ogg', 60, FALSE)
	user.visible_message(span_notice("От клинка по рукам [user.declent_ru(GENITIVE)] разливается белый свет и окутывает всю фигуру."), span_notice("Свет Сестры окутывает вас. Клинок в ваших руках становится легче."))
	StartCooldown()
	return TRUE

/// The extra force and shorter swing delay belong to the wielded blade for the life of its aura.
/datum/status_effect/sister_dawn
	id = "sister_dawn"
	duration = 8 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Blade to restore even if its action has already been removed from the wielder.
	var/obj/item/dualsaber/legendary_saber/sister/saber
	/// The same object provides both the visible aura and its moving light source.
	var/obj/effect/dummy/lighting_obj/moblight/sister_dawn/aura
	/// Record only our adjustments so other changes to the blade survive the effect.
	var/bonus_force
	var/swing_delay_reduction

/datum/status_effect/sister_dawn/on_apply(datum/action/cooldown/legendary_sword/sister_dawn/ability)
	if(!istype(ability) || ability.owner != owner || !ability.saber?.can_use_legendary_ability(owner, ability.required_bond))
		return FALSE
	saber = ability.saber
	bonus_force = saber.force * 0.4
	swing_delay_reduction = clamp(saber.attack_speed - world.tick_lag, 0, 0.2 SECONDS)
	saber.force += bonus_force
	saber.attack_speed -= swing_delay_reduction
	RegisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS, PROC_REF(add_blade_aura))
	RegisterSignal(saber, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(add_swing_aura))
	RegisterSignals(saber, list(COMSIG_TWOHANDED_UNWIELD, COMSIG_ITEM_DROPPED, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(end_dawn))
	RegisterSignal(ability, COMSIG_ACTION_REMOVED, PROC_REF(end_dawn))
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(end_dawn))
	aura = new(owner)
	owner.update_held_items()
	return TRUE

/// Match the aura to the hand sprite chosen by the sword, including the Normandy gauntlet grip.
/datum/status_effect/sister_dawn/proc/add_blade_aura(obj/item/source, list/overlays, mutable_appearance/draw_target, isinhands, icon_file)
	SIGNAL_HANDLER
	if(!isinhands || source.loc != owner)
		return
	var/grip = draw_target.icon == 'modular_bandastation/weapon/icons/melee/sister_gauntlet.dmi' ? "gauntlet" : "blade"
	var/hand = icon_file == source.lefthand_file ? "left" : "right"
	var/aura_state = "[grip]_[hand]"
	overlays += mutable_appearance(SISTER_DAWN_BLADE_ICON, aura_state)
	overlays += emissive_appearance(SISTER_DAWN_BLADE_ICON, aura_state, source, alpha = 160)

/// Melee swings display the world sprite at the target, which has a different blade silhouette.
/datum/status_effect/sister_dawn/proc/add_swing_aura(obj/item/source, atom/movable/attacker, atom/target, animation_type, list/image_override)
	SIGNAL_HANDLER
	if(attacker != owner || length(image_override) || source.attack_icon)
		return
	var/image/swing = image(icon = source)
	swing.overlays += mutable_appearance(SISTER_DAWN_BLADE_ICON, "swing")
	image_override += swing

/datum/status_effect/sister_dawn/proc/end_dawn()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/sister_dawn/on_remove()
	if(saber)
		UnregisterSignal(saber, list(COMSIG_ITEM_GET_WORN_OVERLAYS, COMSIG_ITEM_ATTACK_ANIMATION))
		saber.force -= bonus_force
		saber.attack_speed += swing_delay_reduction
		saber = null
		if(!QDELETED(owner))
			owner.update_held_items()
	QDEL_NULL(aura)
	return ..()

#undef SISTER_DAWN_BLADE_ICON
