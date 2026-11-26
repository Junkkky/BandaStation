/// A machine holds one unopened cartridge and a separate reservoir for each pigment.
/obj/item/tattoo_machine
	var/needle_loaded = FALSE
	var/list/ink_doses = list("#262638" = 4, "#aa264b" = 4, "#176b78" = 4)
	var/datum/tattoo_session/session
	/// Self-use switches between the needle and the pigment removal mode.
	var/removal_mode = FALSE

/obj/item/tattoo_machine/Destroy()
	QDEL_NULL(session)
	return ..()

/obj/item/tattoo_machine/examine(mob/user)
	. = ..()
	. += span_notice("Режим — [removal_mode ? "сведение" : "нанесение"]. Чтобы переключиться, активируйте машинку в руке.")
	if(removal_mode)
		. += span_notice("Выберите открытый участок с татуировкой и примените машинку. Для сведения нужны согласие клиента и время, расходники не требуются.")
		return
	. += span_notice(needle_loaded ? "Установлен чистый картридж." : "Картридж с иглой не установлен.")
	for(var/pigment in ink_doses)
		. += span_notice("Пигмент <font color='[pigment]'>■</font> [pigment] — [ink_doses[pigment]] доз.")
	. += span_notice("Выберите открытый участок кожи, протрите его салфеткой и примените машинку. Тренироваться в одиночку можно на учебном тату-манекене.")

/obj/item/tattoo_machine/attack_self(mob/user)
	if(..())
		return TRUE
	if(session)
		balloon_alert(user, "сначала завершите сеанс")
		return TRUE
	removal_mode = !removal_mode
	balloon_alert(user, removal_mode ? "режим сведения" : "режим нанесения")
	return TRUE

/obj/item/tattoo_machine/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/tattoo_needle))
		if(session)
			balloon_alert(user, "сначала завершите сеанс")
			return ITEM_INTERACT_BLOCKING
		if(needle_loaded)
			balloon_alert(user, "картридж уже установлен")
			return ITEM_INTERACT_BLOCKING
		needle_loaded = TRUE
		qdel(tool)
		balloon_alert(user, "картридж установлен")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/tattoo_ink))
		var/obj/item/tattoo_ink/vial = tool
		var/pigment = vial.pigment_color
		if(session)
			balloon_alert(user, "сначала завершите сеанс")
			return ITEM_INTERACT_BLOCKING
		if(!(pigment in ink_doses) && length(ink_doses) >= 15)
			balloon_alert(user, "все резервуары заняты")
			return ITEM_INTERACT_BLOCKING
		ink_doses[pigment] += 4
		qdel(vial)
		balloon_alert(user, "добавлено 4 дозы")
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Only designated training targets that have never belonged to a player support solo approval.
/proc/is_tattoo_practice_target(mob/living/carbon/human/target)
	if(!ishuman(target) || GET_CLIENT(target) || target.key || target.mind || target.last_mind)
		return FALSE
	return istype(target, /mob/living/carbon/human/tattoo_mannequin) || !!(target.flags_1 & ADMIN_SPAWNED_1)

/// Empty test bodies created through the admin spawn tools can be used straight away.
/obj/item/tattoo_machine/proc/tattoo_supply_error(mob/living/carbon/human/target, obj/item/bodypart/limb)
	if(!length(ink_doses))
		return "загрузите пигмент"
	if((target.flags_1 & ADMIN_SPAWNED_1) && is_tattoo_practice_target(target))
		return null
	if(!needle_loaded)
		return "установите картридж"
	var/datum/component/tattoo_care/care = limb.GetComponent(/datum/component/tattoo_care)
	if(!care?.prepared)
		return "подготовьте кожу салфеткой"

/obj/item/tattoo_machine/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(user.combat_mode || !ishuman(target))
		return ..()
	if(session && !session.can_continue())
		QDEL_NULL(session)
	if(session)
		if(user == session.artist && target == session.customer)
			session.ui_interact(user)
		else
			balloon_alert(user, "машинка занята")
		return TRUE
	if(target == user || (!GET_CLIENT(target) && !is_tattoo_practice_target(target)))
		balloon_alert(user, "выберите другого игрока или учебный манекен")
		return TRUE
	if(!GET_CLIENT(user) || target.stat != STABLE || user.stat != STABLE \
		|| target.incapacitated || user.incapacitated || !user.Adjacent(target) || !user.is_holding(src))
		balloon_alert(user, "для сеанса нужно быть в сознании и рядом")
		return TRUE
	var/obj/item/bodypart/limb = target.get_bodypart(check_zone(user.zone_selected))
	if(!limb?.tattoo_is_exposed() || !IS_ORGANIC_LIMB(limb))
		balloon_alert(user, "откройте выбранный участок кожи")
		return TRUE
	// A given client can work with only one artist at a time.
	if(HAS_TRAIT(target, TRAIT_IN_TATTOO_SESSION))
		balloon_alert(user, "у клиента уже идёт сеанс")
		return TRUE
	if(removal_mode)
		var/datum/tattoo_session/removal/removal_session = new(src, user, target, limb)
		session = removal_session
		if(!removal_session.has_removable_tattoos())
			balloon_alert(user, "на участке нет видимых татуировок")
			QDEL_NULL(session)
			return TRUE
	else
		var/supply_error = tattoo_supply_error(target, limb)
		if(supply_error)
			balloon_alert(user, supply_error)
			return TRUE
		session = new(src, user, target, limb)
		for(var/direction in list(SOUTH, NORTH, EAST, WEST))
			if(session.set_view(direction))
				break
		if(!session.side)
			balloon_alert(user, "нет свободного ракурса")
			QDEL_NULL(session)
			return TRUE
	session.ui_interact(user)
	if(session && !session.practice)
		session.ui_interact(target)
	return TRUE

/// Per-limb preparation and aftercare are created only when supplies are actually used.
/datum/component/tattoo_care
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/prepared = FALSE
	var/fresh = FALSE
	var/covered_with_film = FALSE

/datum/component/tattoo_care/Initialize()
	if(!isbodypart(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/tattoo_care/RegisterWithParent()
	RegisterSignal(parent, COMSIG_BODYPART_CHANGED_OWNER, PROC_REF(clear_preparation))

/datum/component/tattoo_care/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_BODYPART_CHANGED_OWNER)

/datum/component/tattoo_care/proc/clear_preparation()
	SIGNAL_HANDLER
	prepared = FALSE

/datum/component/tattoo_care/proc/remove_film()
	covered_with_film = FALSE

/obj/item/tattoo_wipe/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(user.combat_mode || !ishuman(target))
		return ..()
	var/obj/item/bodypart/limb = target.get_bodypart(check_zone(user.zone_selected))
	if(!limb?.tattoo_is_exposed() || !IS_ORGANIC_LIMB(limb))
		balloon_alert(user, "откройте выбранный участок кожи")
		return TRUE
	var/datum/component/tattoo_care/care = limb.AddComponent(/datum/component/tattoo_care)
	if(care.prepared)
		balloon_alert(user, "кожа уже подготовлена")
		return TRUE
	care.prepared = TRUE
	target.visible_message(span_notice("[user] протирает участок кожи у [target] стерильной салфеткой."))
	qdel(src)
	return TRUE

/obj/item/tattoo_dressing/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(user.combat_mode || !ishuman(target))
		return ..()
	var/obj/item/bodypart/limb = target.get_bodypart(check_zone(user.zone_selected))
	var/datum/component/tattoo_care/care = limb?.GetComponent(/datum/component/tattoo_care)
	if(!care?.fresh || !limb.tattoo_is_exposed())
		balloon_alert(user, "нужна открытая свежая татуировка")
		return TRUE
	care.fresh = FALSE
	care.covered_with_film = TRUE
	addtimer(CALLBACK(care, TYPE_PROC_REF(/datum/component/tattoo_care, remove_film)), 10 MINUTES, TIMER_UNIQUE | TIMER_OVERRIDE)
	target.visible_message(span_notice("[user] закрывает свежую татуировку у [target] прозрачной плёнкой."))
	qdel(src)
	return TRUE
