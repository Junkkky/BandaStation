/// The limb owns the selected tattoo throughout review and the timed procedure.
/datum/tattoo_session/removal
	var/datum/bodypart_overlay/drawn_tattoo/selected

/datum/tattoo_session/removal/Destroy()
	selected = null
	return ..()

/datum/tattoo_session/removal/proc/is_removable(datum/bodypart_overlay/drawn_tattoo/tattoo)
	return !QDELETED(tattoo) && tattoo.marked_limb == limb && (tattoo in limb.bodypart_overlays) && tattoo.can_examine(customer, artist)

/datum/tattoo_session/removal/proc/has_removable_tattoos()
	if(!can_continue())
		return FALSE
	for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in limb.bodypart_overlays)
		if(is_removable(tattoo))
			return TRUE
	return FALSE

/datum/tattoo_session/removal/can_continue()
	return ..() && !artist.is_blind() && HAS_TRAIT_FROM_ONLY(customer, TRAIT_IN_TATTOO_SESSION, REF(src)) && (phase == "draft" || is_removable(selected))

/datum/tattoo_session/removal/ui_data(mob/user)
	var/list/tattoos = list()
	for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in limb.bodypart_overlays)
		if(is_removable(tattoo))
			tattoos += list(list("id" = REF(tattoo), "side" = tattoo.design.side_label(), "image" = tattoo.design.examine_image_url))
	return list(
		"mode" = "removal",
		"role" = user == artist ? "artist" : "client",
		"practice" = practice,
		"phase" = phase,
		"targetName" = customer.name,
		"zone" = ru_parse_zone(limb.body_zone, declent = NOMINATIVE),
		"tattoos" = tattoos,
		"selected" = selected ? REF(selected) : null,
		"revision" = revision,
	)

/datum/tattoo_session/removal/handle_action(mob/user, action, list/params)
	if(user != artist && user != customer)
		return FALSE
	if(action == "cancel")
		qdel(src)
		return FALSE
	if(!can_continue() || !isnum(params["revision"]) || params["revision"] != revision)
		return FALSE
	switch(action)
		if("select")
			if(user != artist || phase != "draft" || !istext(params["id"]))
				return FALSE
			for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in limb.bodypart_overlays)
				if(REF(tattoo) != params["id"] || !is_removable(tattoo))
					continue
				selected = tattoo
				phase = "review"
				revision++
				return TRUE
			return FALSE
		if("revise")
			if(phase != "review")
				return FALSE
			selected = null
			phase = "draft"
			revision++
		if("approve")
			var/mob/approver = practice ? artist : customer
			if(user != approver || phase != "review")
				return FALSE
			phase = "applying"
			INVOKE_ASYNC(src, PROC_REF(apply_design))
		else
			return FALSE
	return TRUE

/datum/tattoo_session/removal/start_application()
	if(phase != "applying" || motor_sound || !can_continue())
		return FALSE
	motor_sound = new(machine, 'modular_bandastation/tattoo_artist/sound/tattoo_machine.ogg', _range = 4, _volume = 38, _repeating = TRUE)
	customer.visible_message(span_notice("[artist] начинает сводить выбранную татуировку у [customer]."))
	return TRUE

/datum/tattoo_session/removal/finish_application()
	if(phase != "applying" || !motor_sound || !can_continue())
		return FALSE
	// Forget the matching record while the exact design is still attached and can be authenticated.
	if(customer.get_tattoo_preferences() && !customer.set_tattoo_persistent(limb, selected.design, FALSE))
		to_chat(customer, span_warning("Не удалось обновить сохранение персонажа. Татуировка осталась на месте."))
		to_chat(artist, span_warning("Сведение прервано из-за ошибки сохранения персонажа."))
		return FALSE
	artist.log_message("removed a [practice ? "practice" : "consented"] tattoo from [key_name(customer)] ([limb.body_zone], [dir2text(selected.design.side)]).", LOG_GAME)
	limb.remove_bodypart_overlay(selected)
	selected = null
	if(!(locate(/datum/bodypart_overlay/drawn_tattoo) in limb.bodypart_overlays))
		var/datum/component/tattoo_care/care = limb.GetComponent(/datum/component/tattoo_care)
		if(care)
			care.fresh = FALSE
			care.covered_with_film = FALSE
	customer.visible_message(span_notice("[artist] заканчивает сведение татуировки у [customer]."))
	return TRUE
