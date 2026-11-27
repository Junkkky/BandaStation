/datum/tattoo_session
	var/static/stencil_limit = 12
	var/stencil_error

/// Stencils belong to the artist's account across character slots.
/datum/tattoo_session/proc/get_stencil_savefile()
	if(QDELETED(artist))
		return null
	var/client/player = GET_CLIENT(artist)
	var/datum/preferences/preferences = player?.prefs
	if(player?.mob == artist && preferences?.parent == player && preferences?.load_and_save && preferences.savefile?.path)
		return preferences.savefile

/datum/tattoo_session/proc/get_stencil_library()
	var/datum/json_savefile/savefile = get_stencil_savefile()
	if(!savefile)
		return null
	var/list/entries = list()
	var/list/records = savefile.get_entry("tattoo_stencils")
	if(islist(records))
		for(var/i in 1 to min(stencil_limit, length(records)))
			var/id = records[i]
			if(!istext(id) || length(id) > 64)
				continue
			var/list/record = records[id]
			if(islist(record) && istext(record["name"]) && ISINRANGE(length_char(record["name"]), 1, 32))
				entries += list(list("id" = id, "name" = record["name"]))
	return entries

/// The editor mask can be older than a newly worn glove or shoe.
/datum/tattoo_session/proc/stencil_fits(pixels)
	if(!side || !mask_bits || pixels == empty_bitmap || limb.has_drawn_tattoo() || !valid_draft(pixels))
		return FALSE
	var/datum/tattoo_design/check = new
	var/fits = check.prepare(limb, side, pixels, palette)
	qdel(check)
	return fits

/// Map the stored ink indices to the editor's current palette without changing the saved drawing.
/datum/tattoo_session/proc/apply_stencil(list/record)
	if(bitmap != empty_bitmap)
		return "Для переноса трафарета нужен чистый холст."
	var/pixels = record["bitmap"]
	var/list/inks = record["palette"]
	if(!istext(pixels) || length(pixels) != 4096 || pixels == empty_bitmap || !islist(inks) || !ISINRANGE(length(inks), 1, 15))
		return "Данные трафарета повреждены."
	pixels = LOWER_TEXT(pixels)
	var/digits = "0123456789abcdef"
	var/list/loaded = list()
	for(var/i in 1 to length(palette))
		var/ink = palette[i]
		loaded[LOWER_TEXT(ink)] = copytext(digits, i + 1, i + 2)
	var/list/remap = list("0" = "0")
	for(var/i in 1 to length(inks))
		var/color = inks[i]
		if(!istext(color) || length(color) != 7 || !findtext(color, GLOB.is_color) || !isnull(inks[color]))
			return "Данные трафарета повреждены."
		var/digit = copytext(digits, i + 1, i + 2)
		if(!findtextEx(pixels, digit))
			continue
		remap[digit] = loaded[LOWER_TEXT(color)]
		if(!remap[digit])
			return "В машинке отсутствует пигмент [color]."
	var/list/mapped = splittext(pixels, "")
	for(var/i in 1 to length(mapped))
		var/replacement = remap[mapped[i]]
		if(!replacement)
			return "Данные трафарета повреждены."
		mapped[i] = replacement
	var/new_bitmap = jointext(mapped, "")
	if(!stencil_fits(new_bitmap))
		return "Трафарет не помещается на открытой коже в этом ракурсе."
	bitmap = new_bitmap
	revision++
	return null

/// Caller checks the UI role and phase. All artwork and IDs resolve within the artist's savefile.
/datum/tattoo_session/proc/handle_stencil_action(action, list/params)
	stencil_error = null
	var/datum/json_savefile/savefile = get_stencil_savefile()
	if(!savefile)
		stencil_error = "Личная библиотека недоступна."
		return TRUE
	if(!isnum(params["revision"]) || params["revision"] != revision)
		stencil_error = "Эскиз изменился. Повторите действие."
		return TRUE
	var/list/records = savefile.get_entry("tattoo_stencils", list())
	if(!islist(records))
		stencil_error = "Не удалось прочитать личную библиотеку."
		return TRUE
	switch(action)
		if("save_stencil")
			var/name = params["name"]
			name = istext(name) && length(name) <= MAX_MESSAGE_LEN ? reject_bad_text(htmlrendertext(trim(name)), 32, ascii_only = FALSE) : null
			if(!length(name))
				stencil_error = "Введите название длиной от 1 до 32 символов без угловых скобок и косых черт."
				return TRUE
			if(length(records) >= stencil_limit)
				stencil_error = "В библиотеке уже [stencil_limit] трафаретов."
				return TRUE
			for(var/id in records)
				if(!istext(id))
					continue
				var/list/record = records[id]
				if(islist(record) && istext(record["name"]) && LOWER_TEXT(record["name"]) == LOWER_TEXT(name))
					stencil_error = "Трафарет с таким названием уже есть."
					return TRUE
			if(!stencil_fits(bitmap))
				stencil_error = "Для сохранения нужен рисунок на открытой коже."
				return TRUE
			records[GUID()] = list("name" = name, "bitmap" = bitmap, "palette" = palette.Copy())
		if("apply_stencil", "delete_stencil")
			var/id = params["id"]
			if(!istext(id) || !islist(records[id]))
				stencil_error = "Трафарет не найден в вашей библиотеке."
				return TRUE
			if(action == "apply_stencil")
				stencil_error = apply_stencil(records[id])
				return TRUE
			records -= id
		else
			return FALSE
	savefile.set_entry("tattoo_stencils", records)
	if(!savefile.auto_save)
		savefile.save()
	return TRUE
