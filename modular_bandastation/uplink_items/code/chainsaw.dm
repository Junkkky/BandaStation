/obj/item/chainsaw/syndie
	name = "syndicate chainsaw"
	desc = "Боевая бензопила Синдиката. Рукоять фиксируется при запуске двигателя. Удары по живой цели вводят владельца в состояние резни, а в боевом режиме пила может разделать труп."
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	block_sound = 'sound/items/weapons/chainsawhit.ogg'
	force = 15
	throwforce = 15
	force_on = 40
	throw_speed = 1
	throw_range = 5

/obj/item/chainsaw/syndie/Initialize(mapload)
	. = ..()
	RegisterSignals(src, list(SIGNAL_ADDTRAIT(TRAIT_TRANSFORM_ACTIVE), SIGNAL_REMOVETRAIT(TRAIT_TRANSFORM_ACTIVE)), PROC_REF(update_grip))
	RegisterSignal(src, COMSIG_ITEM_ATTACK_ZONE, PROC_REF(on_hit))

/obj/item/chainsaw/syndie/proc/update_grip(datum/source)
	SIGNAL_HANDLER
	if(HAS_TRAIT(src, TRAIT_TRANSFORM_ACTIVE))
		ADD_TRAIT(src, TRAIT_NODROP, type)
	else
		REMOVE_TRAIT(src, TRAIT_NODROP, type)

/obj/item/chainsaw/syndie/get_melee_armor_block(mob/living/target, hit_zone, zone_name)
	var/armor = target.getarmor(hit_zone, MELEE)
	if(armor <= 0)
		return armor
	var/remaining_armor = max(0, armor * 0.5 - 10)
	if(remaining_armor)
		to_chat(target, span_warning("Ваша броня смягчила удар в [zone_name]!"))
	else
		to_chat(target, span_userdanger("Пила пробила вашу броню!"))
	return remaining_armor

/obj/item/chainsaw/syndie/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(ishuman(target_mob) && target_mob.stat == DEAD && user.combat_mode && HAS_TRAIT(src, TRAIT_TRANSFORM_ACTIVE))
		user.do_attack_animation(target_mob)
		play_melee_hit_sound(src, force)
		add_fingerprint(user)
		log_combat(user, target_mob, "butchered the corpse of", src)
		target_mob.gib(DROP_ORGANS | DROP_ITEMS)
		return TRUE
	return ..()

/obj/item/chainsaw/syndie/proc/on_hit(obj/item/source, mob/living/victim, mob/living/user, hit_zone)
	SIGNAL_HANDLER
	if(victim.stat == DEAD || !HAS_TRAIT(src, TRAIT_TRANSFORM_ACTIVE))
		return
	victim.Knockdown(12 SECONDS)
	if(!iscyborg(victim))
		user.apply_status_effect(/datum/status_effect/chainsaw_slaying)

/obj/item/chainsaw/syndie/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, final_block_chance, damage, attack_type, damage_type)
	if((attack_type == MELEE_ATTACK || attack_type == UNARMED_ATTACK) && HAS_TRAIT(src, TRAIT_TRANSFORM_ACTIVE) && owner.has_status_effect(/datum/status_effect/chainsaw_slaying))
		final_block_chance = 80
	return ..()

/datum/status_effect/chainsaw_slaying
	id = "chainsaw_slaying"
	duration = 5 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/chainsaw_slaying
	show_duration = TRUE

/datum/status_effect/chainsaw_slaying/on_apply()
	ADD_TRAIT(owner, TRAIT_STUNIMMUNE, TRAIT_STATUS_EFFECT(id))
	ADD_TRAIT(owner, TRAIT_PUSHIMMUNE, TRAIT_STATUS_EFFECT(id))
	MODIFY_PHYSIOLOGY(owner, BRUTE, 0.8)
	MODIFY_PHYSIOLOGY(owner, BURN, 0.8)
	MODIFY_PHYSIOLOGY(owner, STAMINA, 0.8)
	return TRUE

/datum/status_effect/chainsaw_slaying/on_remove()
	REMOVE_TRAIT(owner, TRAIT_STUNIMMUNE, TRAIT_STATUS_EFFECT(id))
	REMOVE_TRAIT(owner, TRAIT_PUSHIMMUNE, TRAIT_STATUS_EFFECT(id))
	MODIFY_PHYSIOLOGY(owner, BRUTE, 1 / 0.8)
	MODIFY_PHYSIOLOGY(owner, BURN, 1 / 0.8)
	MODIFY_PHYSIOLOGY(owner, STAMINA, 1 / 0.8)

/atom/movable/screen/alert/status_effect/chainsaw_slaying
	name = "Резня"
	desc = "Вы невосприимчивы к оглушению и получаете на 20% меньше физического урона, ожогов и урона выносливости. Работающая бензопила блокирует 80% атак ближнего боя."
	use_user_hud_icon = USER_HUD_STYLE_INHERIT
	overlay_icon = 'icons/obj/weapons/chainsaw.dmi'
	overlay_state = "chainsaw_on"
