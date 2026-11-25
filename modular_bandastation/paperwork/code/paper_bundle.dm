/// Whether this sheet or photo can be clipped into a bundle.
/proc/can_clip_paper_bundle_page(obj/item/page, mob/living/user)
	if(page.resistance_flags & ON_FIRE)
		return FALSE
	if(istype(page, /obj/item/paper/carbon))
		var/obj/item/paper/carbon/carbon_paper = page
		if(!carbon_paper.copied)
			to_chat(user, span_notice("Сначала снимите копировальную бумагу."))
			return FALSE
	return TRUE

/obj/item/paper_bundle
	name = "paper bundle"
	desc = "Листы бумаги и фотографии, скреплённые вместе."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper_stack"
	inhand_icon_state = "paper"
	w_class = WEIGHT_CLASS_TINY
	throwforce = 0
	throw_range = 2
	throw_speed = 1
	resistance_flags = FLAMMABLE
	drop_sound = 'sound/items/handling/paper_drop.ogg'
	pickup_sound = 'sound/items/handling/paper_pickup.ogg'
	interaction_flags_click = NEED_DEXTERITY | NEED_HANDS | ALLOW_RESTING | FORBID_TELEKINESIS_REACH
	/// Index of the open page in contents.
	var/page_index = 1

/obj/item/paper_bundle/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/burn_on_item_ignition)
	RegisterSignals(src, list(COMSIG_ITEM_ENTERED_HANDS, COMSIG_ITEM_POST_UNEQUIP), PROC_REF(on_bundle_inventory_changed))

/obj/item/paper_bundle/proc/on_bundle_inventory_changed()
	SIGNAL_HANDLER
	if(!QDELETED(src))
		SStgui.update_uis(src)

/obj/item/paper_bundle/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	RegisterSignal(arrived, COMSIG_ATOM_UPDATED_ICON, PROC_REF(on_page_appearance_changed))
	update_appearance()
	SStgui.update_uis(src)

/obj/item/paper_bundle/Exited(atom/movable/gone, direction)
	. = ..()
	UnregisterSignal(gone, COMSIG_ATOM_UPDATED_ICON)
	if(QDELETED(src))
		return
	page_index = clamp(page_index, 1, max(1, length(contents)))
	update_appearance()
	SStgui.update_uis(src)

/obj/item/paper_bundle/proc/on_page_appearance_changed(atom/source)
	SIGNAL_HANDLER
	if(!length(contents))
		return
	if(source == contents[1])
		update_appearance()
	if(source == contents[page_index])
		SStgui.update_uis(src)

/obj/item/paper_bundle/update_icon_state()
	. = ..()
	var/obj/item/paper/cover = length(contents) ? contents[1] : null
	icon_state = istype(cover) && cover.get_total_length() ? "paper_stack_words" : "paper_stack"

/obj/item/paper_bundle/update_overlays()
	. = ..()
	var/obj/item/cover = length(contents) ? contents[1] : null
	if(istype(cover, /obj/item/paper))
		. += cover.overlays
	else if(istype(cover, /obj/item/photo))
		var/mutable_appearance/photo_cover = mutable_appearance(cover.icon, cover.icon_state)
		photo_cover.pixel_x = 2
		photo_cover.pixel_y = 2
		. += photo_cover

/obj/item/paper_bundle/examine(mob/user)
	. = ..()
	. += span_notice("Всего страниц: [length(contents)]. Нажмите <b>Alt + ПКМ</b>, чтобы разобрать пачку, или <b>Alt + ЛКМ</b> с ручкой, чтобы подписать её.")
	if(can_view_bundle(user))
		ui_interact(user)

/obj/item/paper_bundle/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/paper) || istype(tool, /obj/item/photo))
		if(!user.is_holding(tool) || !can_clip_paper_bundle_page(tool, user) || !user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		add_fingerprint(user)
		to_chat(user, span_notice("Вы добавляете страницу в пачку."))
		return ITEM_INTERACT_SUCCESS

	if(istype(tool, /obj/item/paper_bundle))
		if(tool == src || !user.is_holding(tool) || !user.transferItemToLoc(tool, drop_location()))
			return ITEM_INTERACT_BLOCKING
		for(var/obj/item/loose_page as anything in tool.contents.Copy())
			loose_page.forceMove(src)
		qdel(tool)
		add_fingerprint(user)
		to_chat(user, span_notice("Вы объединяете две пачки."))
		return ITEM_INTERACT_SUCCESS

	if(istype(tool, /obj/item/folder) || istype(tool, /obj/item/clipboard))
		return tool.item_interaction(user, src)

	if(tool.get_writing_implement_details() && length(contents))
		var/obj/item/selected_page = contents[page_index]
		return selected_page.item_interaction(user, tool, modifiers)
	return ..()

/obj/item/paper_bundle/attack_self(mob/user, list/modifiers)
	add_fingerprint(user)
	ui_interact(user)

/obj/item/paper_bundle/click_alt(mob/living/user)
	if(!istype(user.get_active_held_item(), /obj/item/pen))
		return NONE
	rename_bundle(user)
	return CLICK_ACTION_SUCCESS

/// Label the bundle with the pen the user is holding.
/obj/item/paper_bundle/proc/rename_bundle(mob/living/user)
	var/obj/item/pen/pen = user.get_active_held_item()
	if(!istype(pen))
		return
	var/label = tgui_input_text(user, "Введите название пачки.", "Подписать пачку", name, max_length = MAX_NAME_LEN)
	if(isnull(label) || QDELETED(src) || user.get_active_held_item() != pen || !user.can_perform_action(src, interaction_flags_click))
		return
	name = length(label) ? label : initial(name)
	add_fingerprint(user)
	SStgui.update_uis(src)

/obj/item/paper_bundle/click_alt_secondary(mob/living/user)
	var/turf/release_turf = get_turf(user)
	if(!release_turf)
		return CLICK_ACTION_BLOCKING
	for(var/obj/item/loose_page as anything in contents.Copy())
		loose_page.forceMove(release_turf)
		loose_page.add_fingerprint(user)
	to_chat(user, span_notice("Вы разбираете пачку."))
	qdel(src)
	return CLICK_ACTION_SUCCESS

/// Only expose pages from a nearby bundle or an accessible folder or clipboard.
/obj/item/paper_bundle/proc/can_view_bundle(mob/user)
	if(!length(contents) || (resistance_flags & ON_FIRE) || user.is_blind() || !in_range(user, src))
		return FALSE
	if(loc == user || isturf(loc))
		return IsReachableBy(user)
	if(istype(loc, /obj/item/folder) || istype(loc, /obj/item/clipboard))
		return (loc.loc == user || isturf(loc.loc)) && loc.IsReachableBy(user)
	return FALSE

/obj/item/paper_bundle/IsContainedAtomAccessible(atom/contained, atom/movable/user)
	return contained.loc == src && ismob(user) && can_view_bundle(user)

/obj/item/paper_bundle/ui_host(mob/user)
	if(istype(loc, /obj/item/folder) || istype(loc, /obj/item/clipboard))
		return loc
	return ..()

/obj/item/paper_bundle/ui_status(mob/user, datum/ui_state/state)
	if(!can_view_bundle(user))
		return UI_CLOSE
	return ..()

/obj/item/paper_bundle/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PaperBundle")
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/item/paper_bundle/ui_assets(mob/user)
	return list(
		get_asset_datum(/datum/asset/spritesheet/simple/stamps),
		get_asset_datum(/datum/asset/simple/logos),
		get_asset_datum(/datum/asset/simple/paper_logos),
	)

/obj/item/paper_bundle/ui_data(mob/user)
	var/obj/item/selected_page = length(contents) ? contents[page_index] : null
	var/list/data = list(
		"bundle_name" = (name == initial(name) ? "Скреплённая пачка" : name),
		"page" = page_index,
		"page_count" = length(contents),
		"page_name" = selected_page?.name,
		"page_ref" = selected_page ? REF(selected_page) : null,
		"can_remove" = selected_page && user.is_holding(src),
		"paper" = null,
		"photo" = null,
		"photo_caption" = null,
		LIST_PAPER_RAW_STAMP_INPUT = list(),
	)
	if(istype(selected_page, /obj/item/paper) && user.can_read(selected_page, silent = TRUE))
		var/obj/item/paper/sheet = selected_page
		var/list/paper_data = sheet.convert_to_data(include_ref = TRUE)
		paper_data["default_pen_font"] = PEN_FONT
		paper_data["default_pen_color"] = COLOR_BLACK
		data["paper"] = paper_data
		data[LIST_PAPER_RAW_STAMP_INPUT] = paper_data[LIST_PAPER_RAW_STAMP_INPUT]
	else if(istype(selected_page, /obj/item/photo))
		var/obj/item/photo/photograph = selected_page
		if(photograph.picture?.picture_image)
			data["photo"] = icon2base64(photograph.picture.picture_image)
		data["photo_caption"] = photograph.scribble
	return data

/obj/item/paper_bundle/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !length(contents) || !can_view_bundle(usr))
		return
	var/obj/item/selected_page = contents[page_index]
	if(params["page"] != page_index || params["ref"] != REF(selected_page))
		return FALSE

	switch(action)
		if("previous", "next")
			var/new_index = page_index + (action == "next" ? 1 : -1)
			if(new_index < 1 || new_index > length(contents))
				return FALSE
			page_index = new_index
			playsound(src, SFX_PAGE_TURN, 35, vary = TRUE)
		if("open")
			usr.examinate(selected_page)
		if("remove")
			if(!usr.is_holding(src) || !usr.can_perform_action(src, interaction_flags_click))
				return FALSE
			remove_page(selected_page, usr)
		else
			return FALSE
	return TRUE

/// Removing a page from a two-page bundle frees the other page as well.
/obj/item/paper_bundle/proc/remove_page(obj/item/selected_page, mob/user)
	if(selected_page.loc != src)
		return
	user.put_in_hands(selected_page)
	selected_page.add_fingerprint(user)
	if(length(contents) == 1)
		var/obj/item/last_page = contents[1]
		last_page.forceMove(user.drop_location())
		qdel(src)
		user.put_in_hands(last_page)
