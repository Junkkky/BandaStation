/// One machine and the exact limb selected on a customer or a training mannequin.
/datum/tattoo_session
	var/obj/item/tattoo_machine/machine
	var/mob/living/artist
	var/mob/living/carbon/human/customer
	var/obj/item/bodypart/limb
	/// The artist can approve a sketch only when this session began on an empty practice target.
	var/practice = FALSE
	/// The customer may opt in for this exact approved drawing.
	var/save_for_character = FALSE
	var/phase = "draft"
	var/side
	var/revision = 0
	var/draw_rejected = 0
	var/list/palette = list()
	var/bitmap
	var/static/empty_bitmap
	var/body_png
	var/mask_png
	var/mask_bits
	var/regex/invalid_ink
	var/datum/tattoo_design/reviewed
	/// A bead of blood at the needle tip, visible while the artist is working.
	var/mutable_appearance/blood_bead
	/// The motor is audible only while the needle is working on the customer.
	var/datum/sound_token/motor_sound

/datum/tattoo_session/New(obj/item/tattoo_machine/machine, mob/living/artist, mob/living/carbon/human/customer, obj/item/bodypart/limb)
	. = ..()
	src.machine = machine
	src.artist = artist
	src.customer = customer
	src.limb = limb
	practice = is_tattoo_practice_target(customer)
	for(var/pigment in machine.ink_doses)
		palette += pigment
	invalid_ink = regex(@"[^" + copytext("0123456789abcdef", 1, length(palette) + 2) + "]")
	if(isnull(empty_bitmap))
		empty_bitmap = repeat_string(4096, "0")
	bitmap = empty_bitmap
	ADD_TRAIT(customer, TRAIT_IN_TATTOO_SESSION, REF(src))
	RegisterSignal(machine, COMSIG_ITEM_DROPPED, PROC_REF(end_session))
	RegisterSignals(artist, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(end_session))
	RegisterSignals(customer, list(COMSIG_QDELETING, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_MOB_MIND_TRANSFERRED_INTO), PROC_REF(end_session))
	RegisterSignals(limb, list(COMSIG_QDELETING, COMSIG_BODYPART_CHANGED_OWNER), PROC_REF(end_session))

/datum/tattoo_session/Destroy()
	QDEL_NULL(motor_sound)
	if(machine)
		UnregisterSignal(machine, COMSIG_ITEM_DROPPED)
		if(machine.session == src)
			machine.session = null
	if(artist)
		UnregisterSignal(artist, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT))
	if(customer)
		if(blood_bead)
			customer.cut_overlay(blood_bead)
			blood_bead = null
		REMOVE_TRAIT(customer, TRAIT_IN_TATTOO_SESSION, REF(src))
		UnregisterSignal(customer, list(COMSIG_QDELETING, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_MOB_MIND_TRANSFERRED_INTO))
	if(limb)
		UnregisterSignal(limb, list(COMSIG_QDELETING, COMSIG_BODYPART_CHANGED_OWNER))
	SStgui.close_uis(src)
	machine = null
	artist = null
	customer = null
	limb = null
	QDEL_NULL(reviewed)
	return ..()

/datum/tattoo_session/proc/end_session()
	SIGNAL_HANDLER
	qdel(src)

/// Rechecked on UI actions, throughout the procedure and immediately before applying pigment.
/datum/tattoo_session/proc/can_continue()
	return !QDELETED(src) && !QDELETED(machine) && machine.session == src \
		&& !QDELETED(artist) && !QDELETED(customer) && GET_CLIENT(artist) \
		&& (practice ? is_tattoo_practice_target(customer) : GET_CLIENT(customer)) \
		&& !artist.incapacitated && !customer.incapacitated \
		&& artist.stat == STABLE && customer.stat == STABLE && artist.is_holding(machine) \
		&& artist.Adjacent(customer) && limb?.owner == customer && limb.tattoo_is_exposed() && IS_ORGANIC_LIMB(limb)

/// Build a same-size binary mask once per view, in the editor's top-left row order.
/datum/tattoo_session/proc/set_view(new_side)
	if(!(new_side in GLOB.cardinals) || bitmap != empty_bitmap || limb.has_drawn_tattoo(new_side))
		return FALSE
	var/icon/mask = limb.tattoo_skin_icon(new_side)
	if(!mask)
		return FALSE
	var/list/rows = list()
	for(var/y in 1 to 32)
		var/list/row = list()
		for(var/x in 1 to 32)
			row += mask.GetPixel(x, 33 - y) ? "11" : "00"
		var/detail_row = jointext(row, "")
		rows += detail_row
		rows += detail_row
	mask_bits = jointext(rows, "")
	var/image/portrait = image(customer.appearance)
	portrait.dir = SOUTH
	var/icon/body = getFlatIcon(portrait, defdir = new_side, no_anim = TRUE)
	body.Crop(1, 1, 32, 32)
	body_png = "data:image/png;base64,[icon2base64(body)]"
	mask_png = "data:image/png;base64,[icon2base64(mask)]"
	side = new_side
	revision++
	return TRUE

/// Check only the painted runs against the skin mask, including strokes sent before approval.
/datum/tattoo_session/proc/valid_draft(pixels)
	if(!istext(pixels) || length(pixels) != 4096 || invalid_ink.Find(pixels))
		return FALSE
	var/static/regex/ink_run = regex(@"[^0]+")
	var/start = 1
	while(start <= 4096 && ink_run.Find(pixels, start))
		start = ink_run.index + length(ink_run.match)
		if(findtextEx(mask_bits, "0", ink_run.index, start))
			return FALSE
	return TRUE

/datum/tattoo_session/ui_host(mob/user)
	return machine

/datum/asset/simple/tattoo_studio_audio
	assets = list("tattoo_machine.ogg" = 'modular_bandastation/tattoo_artist/sound/tattoo_machine.ogg')

/datum/tattoo_session/ui_assets(mob/user)
	if(user == artist && !istype(src, /datum/tattoo_session/removal))
		return list(get_asset_datum(/datum/asset/simple/tattoo_studio_audio))
	return ..()

/datum/tattoo_session/ui_status(mob/user, datum/ui_state/state)
	return ((user == artist || user == customer) && can_continue()) ? UI_INTERACTIVE : UI_CLOSE

/datum/tattoo_session/ui_interact(mob/user, datum/tgui/ui)
	if((user != artist && user != customer) || !can_continue())
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooStudio", "Тату-сеанс")
		ui.set_autoupdate(FALSE)
		if(!ui.open())
			qdel(ui)
			qdel(src)

/datum/tattoo_session/ui_close(mob/user)
	. = ..()
	if(!QDELETED(src))
		qdel(src)

/datum/tattoo_session/ui_data(mob/user)
	var/can_save = !practice && user == customer && !isnull(customer.get_tattoo_preferences())
	var/can_edit_stencils = user == artist && phase == "draft"
	var/list/occupied = list()
	for(var/direction in GLOB.cardinals)
		if(limb.has_drawn_tattoo(direction))
			occupied += direction
	return list(
		"role" = user == artist ? "artist" : "client",
		"practice" = practice,
		"canSave" = can_save,
		"saveByDefault" = can_save && customer.tattoo_save_by_default(),
		"phase" = phase,
		"zone" = ru_parse_zone(limb.body_zone, declent = NOMINATIVE),
		"direction" = side,
		"targetName" = customer.name,
		"body" = body_png,
		"mask" = mask_png,
		"draft" = bitmap,
		"palette" = palette,
		"revision" = revision,
		"drawRejected" = draw_rejected,
		"occupied" = occupied,
		"stencils" = can_edit_stencils ? get_stencil_library() : null,
		"stencilLimit" = stencil_limit,
		"stencilError" = can_edit_stencils ? stencil_error : null,
	)

/datum/tattoo_session/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!can_continue())
		return FALSE
	return handle_action(ui.user, action, params)

/// Role and phase checks are shared by both windows.
/datum/tattoo_session/proc/handle_action(mob/user, action, list/params)
	if(user != artist && user != customer)
		return FALSE
	switch(action)
		if("cancel")
			qdel(src)
			return FALSE
		if("direction")
			if(user == artist && phase == "draft")
				if(set_view(params["direction"]))
					stencil_error = null
				else
					machine.balloon_alert(user, "ракурс недоступен")
		if("draw")
			if(user != artist || phase != "draft")
				return FALSE
			var/pixels = params["pixels"]
			if(params["revision"] == revision && valid_draft(pixels))
				bitmap = pixels
				revision++
				stencil_error = null
			else
				draw_rejected++
		if("save_stencil", "apply_stencil", "delete_stencil")
			if(user != artist || phase != "draft")
				return FALSE
			return handle_stencil_action(action, params)
		if("review")
			if(user != artist || phase != "draft" || bitmap == empty_bitmap)
				return FALSE
			if(limb.has_drawn_tattoo(side))
				machine.balloon_alert(user, "здесь уже есть татуировка")
				return FALSE
			var/datum/tattoo_design/design = new
			if(!design.prepare(limb, side, bitmap, palette))
				qdel(design)
				machine.balloon_alert(user, "эскиз не подходит участку")
				return FALSE
			reviewed = design
			phase = "review"
			revision++
		if("revise")
			if(phase != "review" || params["revision"] != revision)
				return FALSE
			QDEL_NULL(reviewed)
			phase = "draft"
			revision++
		if("approve")
			var/mob/approver = practice ? artist : customer
			if(user != approver || phase != "review" || !reviewed || params["revision"] != revision || machine.tattoo_supply_error(customer, limb))
				return FALSE
			if(!practice && user == customer && customer.get_tattoo_preferences())
				save_for_character = ("save" in params) ? params["save"] == TRUE : customer.tattoo_save_by_default()
			phase = "applying"
			INVOKE_ASYNC(src, PROC_REF(apply_design))
		else
			return FALSE
	return TRUE

/// Opening the editor uses no cartridge. Once the needle touches skin it cannot be used for another client.
/datum/tattoo_session/proc/apply_design()
	if(!can_continue())
		qdel(src)
		return
	if(!start_application())
		qdel(src)
		return
	if(!do_after(artist, 5 SECONDS, target = customer, extra_checks = CALLBACK(src, PROC_REF(can_continue))) || !can_continue())
		qdel(src)
		return
	finish_application()
	qdel(src)

/// Starting an approved procedure consumes the cartridge and the preparation even if the customer walks away.
/datum/tattoo_session/proc/start_application()
	if(phase != "applying" || !reviewed || motor_sound || limb.owner != customer)
		return FALSE
	if(machine.tattoo_supply_error(customer, limb) || !reviewed.ink_is_exposed(limb) || limb.has_drawn_tattoo(side))
		return FALSE
	var/datum/component/tattoo_care/care = limb.LoadComponent(/datum/component/tattoo_care)
	care.prepared = FALSE
	machine.needle_loaded = FALSE
	motor_sound = new(machine, 'modular_bandastation/tattoo_artist/sound/tattoo_machine.ogg', _range = 4, _volume = 38, _repeating = TRUE)
	if(limb.can_bleed() && customer.get_blood_volume() > 0 && !HAS_TRAIT(customer, TRAIT_GODMODE))
		limb.adjustBleedStacks(2)
		show_blood_bead()
	customer.visible_message(span_notice("[artist] начинает наносить согласованный рисунок на кожу [customer]."))
	return TRUE

/// The smallest native bleed rate is below the wound sprite threshold. Put one pixel on the actual design.
/datum/tattoo_session/proc/show_blood_bead()
	var/location = reviewed.ink_locations[CEILING(length(reviewed.ink_locations) / 2, 1)]
	var/x = (location - 1) % 32 + 1
	var/y = FLOOR((location - 1) / 32, 1) + 1
	var/static/icon/blank = icon('icons/blanks/32x32.dmi', "nothing", SOUTH)
	var/icon/drop = icon(blank)
	drop.DrawBox(COLOR_WHITE, x, y)
	var/icon/views = icon(blank)
	for(var/direction in GLOB.cardinals)
		views.Insert(direction == side ? drop : blank, icon_state = "", dir = direction)
	var/icon/hand = limb.tattoo_hand_icon(side)
	var/drop_layer = hand?.GetPixel(x, y) ? -limb.aux_layer + 0.01 : -DAMAGE_LAYER
	blood_bead = mutable_appearance(views, "", layer = drop_layer)
	blood_bead.color = customer.get_bloodtype()?.get_wound_color(customer) || BLOOD_COLOR_RED
	customer.apply_height(blood_bead, ENTIRE_BODY)
	customer.add_overlay(blood_bead)

/// Atomically transfers the reviewed drawing to the original limb and accounts for the selected pigments.
/datum/tattoo_session/proc/finish_application()
	if(phase != "applying" || !reviewed || !motor_sound || limb.owner != customer)
		return FALSE
	var/datum/component/tattoo_care/care = limb.GetComponent(/datum/component/tattoo_care)
	if(!care || !limb.apply_drawn_tattoo(reviewed))
		machine.balloon_alert(artist, "участок изменился, сеанс прерван")
		return FALSE
	var/datum/tattoo_design/applied_design = reviewed
	reviewed = null // The limb now owns it.
	for(var/i in 1 to length(palette))
		if(!findtextEx(bitmap, copytext("123456789abcdef", i, i + 1)))
			continue
		var/pigment = palette[i]
		if(--machine.ink_doses[pigment] <= 0)
			machine.ink_doses -= pigment
	care.fresh = TRUE
	care.covered_with_film = FALSE
	artist.log_message("applied a [practice ? "practice" : "consented"] tattoo to [key_name(customer)] ([limb.body_zone], [dir2text(side)]).", LOG_GAME)
	customer.visible_message(span_notice("[artist] заканчивает татуировку. Её можно закрыть защитной плёнкой."))
	if(save_for_character)
		if(customer.set_tattoo_persistent(limb, applied_design, TRUE))
			to_chat(customer, span_notice("Татуировка сохранена для следующих раундов."))
		else
			to_chat(customer, span_warning("Татуировка нанесена, но сохранить её для следующих раундов не удалось."))
	return TRUE
