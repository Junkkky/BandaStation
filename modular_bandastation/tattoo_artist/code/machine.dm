/// The cartridge and dispensed ink stay with one customer across individual designs.
/obj/item/tattoo_machine
	var/needle_loaded = FALSE
	var/list/ink_doses = list("#262638" = 4, "#aa264b" = 4, "#176b78" = 4)
	var/datum/weakref/supply_customer
	var/list/used_inks = list()
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
	if(needle_loaded && supply_customer)
		var/mob/living/carbon/human/customer = supply_customer.resolve()
		. += span_notice(customer ? "Картридж закреплён за клиентом [customer]. Для нового сеанса вставьте чистый картридж." : "Картридж использован. Вставьте чистый картридж.")
	else
		. += span_notice(needle_loaded ? "Установлен чистый картридж." : "Картридж с иглой не установлен.")
	for(var/pigment in ink_doses)
		. += span_notice("Пигмент <font color='[pigment]'>■</font> [pigment] — порций на новые сеансы: [ink_doses[pigment]].")
	. += span_notice("Перед первым нанесением обработайте кожу клиента салфеткой. Один картридж и одна порция каждого цвета рассчитаны на весь сеанс с этим клиентом.")
	. += span_notice("Выберите открытый участок кожи и примените машинку. Тренироваться в одиночку можно на учебном тату-манекене.")

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
		if(needle_loaded && !supply_customer)
			balloon_alert(user, "картридж уже установлен")
			return ITEM_INTERACT_BLOCKING
		needle_loaded = TRUE
		supply_customer = null
		used_inks.Cut()
		qdel(tool)
		balloon_alert(user, "картридж установлен")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/tattoo_ink))
		var/obj/item/tattoo_ink/vial = tool
		var/pigment = vial.pigment_color
		if(session)
			balloon_alert(user, "сначала завершите сеанс")
			return ITEM_INTERACT_BLOCKING
		var/list/reservoirs = ink_doses | used_inks
		if(!(pigment in reservoirs) && length(reservoirs) >= 15)
			balloon_alert(user, "все резервуары заняты")
			return ITEM_INTERACT_BLOCKING
		ink_doses[pigment] += 4
		qdel(vial)
		balloon_alert(user, "добавлено 4 порции")
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Only designated training targets that have never belonged to a player support solo approval.
/proc/is_tattoo_practice_target(mob/living/carbon/human/target)
	if(!ishuman(target) || GET_CLIENT(target) || target.key || target.mind || target.last_mind)
		return FALSE
	return istype(target, /mob/living/carbon/human/tattoo_mannequin) || !!(target.flags_1 & ADMIN_SPAWNED_1)

/// Pigment already dispensed for this customer can be used even when the reservoir is empty.
/obj/item/tattoo_machine/proc/tattoo_palette(mob/living/carbon/human/target)
	var/list/palette = list()
	for(var/pigment in ink_doses)
		palette += pigment
	if(supply_customer?.resolve() == target)
		palette |= used_inks
	return palette

/obj/item/tattoo_machine/proc/tattoo_supply_error(mob/living/carbon/human/target)
	var/same_customer = supply_customer?.resolve() == target
	if(needle_loaded && supply_customer && !same_customer)
		return "замените картридж для другого клиента"
	if(!length(ink_doses) && !(same_customer && length(used_inks)))
		return "загрузите пигмент"
	// Empty test bodies created through the admin spawn tools can be used straight away.
	if((target.flags_1 & ADMIN_SPAWNED_1) && is_tattoo_practice_target(target))
		return null
	if(!needle_loaded)
		return "установите картридж"
	if(!same_customer && !target.tattoo_prepared)
		return "подготовьте кожу салфеткой"

/obj/item/tattoo_machine/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(user.combat_mode || !ishuman(target))
		return ..()
	if(session && !session.can_continue())
		QDEL_NULL(session)
	if(session)
		if(user == session.artist && target == session.customer)
			session.open_participant_windows()
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
		if(limb.has_drawn_tattoo())
			balloon_alert(user, "на этом участке уже есть татуировка")
			return TRUE
		var/supply_error = tattoo_supply_error(target)
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
	session.open_participant_windows(invite_customer = TRUE)
	return TRUE

/mob/living/carbon/human
	/// Set by one prep swab and used when a fresh cartridge first touches this customer.
	var/tattoo_prepared = FALSE

/// Fresh tattoos and protective film are still tracked by limb.
/datum/component/tattoo_care
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/fresh = FALSE
	var/covered_with_film = FALSE

/datum/component/tattoo_care/Initialize()
	if(!isbodypart(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/tattoo_care/proc/remove_film()
	covered_with_film = FALSE

/obj/item/tattoo_wipe/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(user.combat_mode || !ishuman(target))
		return ..()
	var/mob/living/carbon/human/customer = target
	var/obj/item/bodypart/limb = target.get_bodypart(check_zone(user.zone_selected))
	if(!limb?.tattoo_is_exposed() || !IS_ORGANIC_LIMB(limb))
		balloon_alert(user, "откройте выбранный участок кожи")
		return TRUE
	if(customer.tattoo_prepared)
		balloon_alert(user, "кожа уже подготовлена")
		return TRUE
	customer.tattoo_prepared = TRUE
	target.visible_message(span_notice("[user] подготавливает кожу [target] к тату-сеансу стерильной салфеткой."))
	qdel(src)
	return TRUE

/obj/item/tattoo_dressing/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(user.combat_mode || !ishuman(target))
		return ..()
	var/mob/living/carbon/human/customer = target
	var/obj/item/bodypart/limb = target.get_bodypart(check_zone(user.zone_selected))
	var/datum/component/tattoo_care/care = limb?.GetComponent(/datum/component/tattoo_care)
	if(!care?.fresh || !limb.tattoo_is_exposed())
		balloon_alert(user, "нужна открытая свежая татуировка")
		return TRUE
	for(var/obj/item/bodypart/part as anything in customer.bodyparts)
		var/datum/component/tattoo_care/part_care = part.GetComponent(/datum/component/tattoo_care)
		if(!part_care?.fresh || !part.tattoo_is_exposed())
			continue
		part_care.fresh = FALSE
		part_care.covered_with_film = TRUE
		addtimer(CALLBACK(part_care, TYPE_PROC_REF(/datum/component/tattoo_care, remove_film)), 10 MINUTES, TIMER_UNIQUE | TIMER_OVERRIDE)
	target.visible_message(span_notice("[user] закрывает открытые свежие татуировки у [target] прозрачной плёнкой."))
	qdel(src)
	return TRUE
