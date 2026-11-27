#define MAX_BOOK_ILLUSTRATION_SIDE 144
#define BOOK_COVER_TARGET "cover"

/obj/item/book
	name = "book"
	desc = "Crack it open, inhale the musk of its pages, and learn something new."
	icon = 'icons/obj/service/library.dmi'
	icon_state ="book"
	worn_icon_state = "book"
	throw_speed = 1
	throw_range = 5
	w_class = WEIGHT_CLASS_NORMAL  //upped to three because books are, y'know, pretty big. (and you could hide them inside eachother recursively forever)
	attack_verb_continuous = list("bashes", "whacks", "educates")
	attack_verb_simple = list("bash", "whack", "educate")
	resistance_flags = FLAMMABLE
	drop_sound = 'sound/items/handling/book_drop.ogg'
	pickup_sound = 'sound/items/handling/book_pickup.ogg'
	/// Maximum icon state number
	var/maximum_book_state = 8
	/// Game time in 1/10th seconds
	var/due_date = 0
	/// false - Normal book, true - Should not be treated as normal book, unable to be copied, unable to be modified
	var/unique = FALSE
	/// Whether or not we have been carved out.
	var/carved = FALSE
	/// The typepath for the storage datum we use when carved out.
	var/carved_storage_type = /datum/storage/carved_book

	/// The initial title, for use in var editing and such
	var/starting_title
	/// The initial author, for use in var editing and such
	var/starting_author
	/// The initial bit of content, for use in var editing and such
	var/starting_content
	/// The packet of information that describes this book
	var/datum/book_info/book_data
	/// A preview belongs to the reader who requested it and expires when their book window closes.
	var/list/illustration_previews
	/// The reader and page belong to the physical copy until the last phrase finishes.
	var/mob/living/aloud_reader
	var/aloud_page
	var/aloud_revision
	var/list/aloud_phrases
	var/aloud_timer
	COOLDOWN_DECLARE(page_sound_cooldown)

/obj/item/book/Initialize(mapload)
	. = ..()
	book_data = new(starting_title, starting_author, starting_content)

	AddElement(/datum/element/falling_hazard, damage = 5, wound_bonus = 0, hardhat_safety = TRUE, crushes = FALSE, impact_sound = drop_sound)
	AddElement(/datum/element/burn_on_item_ignition)
	register_context()

/obj/item/book/examine(mob/user)
	. = ..()
	if(carved)
		. += span_notice("[src] has been hollowed out.")
	else if(!unique)
		. += span_notice("Ручкой можно редактировать страницы. Возьмите фотографию или законченный холст, чтобы вклеить иллюстрацию в выбранный разворот.")

/obj/item/book/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	if(isnull(held_item))
		return NONE

	if(held_item == src)
		var/attack_self_context = get_attack_self_context(user)
		if(!attack_self_context)
			return NONE
		context[SCREENTIP_CONTEXT_LMB] = attack_self_context
		return CONTEXTUAL_SCREENTIP_SET

	if(IS_WRITING_UTENSIL(held_item))
		context[SCREENTIP_CONTEXT_LMB] = "Редактировать"
		if(is_carving_tool(held_item))
			context[SCREENTIP_CONTEXT_RMB] = "Carve out"
		return CONTEXTUAL_SCREENTIP_SET

	if(!unique && (istype(held_item, /obj/item/photo) || istype(held_item, /obj/item/canvas)))
		context[SCREENTIP_CONTEXT_LMB] = "Иллюстрировать"
		return CONTEXTUAL_SCREENTIP_SET

	if(is_carving_tool(held_item))
		context[SCREENTIP_CONTEXT_LMB] = "Carve out"
		return CONTEXTUAL_SCREENTIP_SET
	return NONE

/// Gets the context to add for clicking the book inhand. Returns null if none.
/obj/item/book/proc/get_attack_self_context(mob/living/user)
	return "Read"

/obj/item/book/ui_static_data(mob/user)
	var/list/data = list()
	data["author"] = book_data.get_author(unique ? "N/A" : "Автор неизвестен")
	data["title"] = book_data.get_title(unique ? "N/A" : "Без названия")
	if(unique)
		data["content"] = book_data.get_content()
		return data
	data["pages"] = book_data.get_pages()
	data["hasBookCover"] = TRUE
	data["coverImage"] = book_data.cover_image
	data["bindingColor"] = book_data.binding_color
	data["revision"] = book_data.revision
	data["maxPages"] = MAX_LIBRARY_BOOK_PAGES
	data["maxTextLength"] = MAX_LIBRARY_PAGE_LENGTH
	data["maxCaptionLength"] = MAX_LIBRARY_CAPTION_LENGTH
	data["canImportIllustration"] = TRUE
	data["illustrationPreview"] = LAZYACCESS(illustration_previews, REF(user))
	return data

/obj/item/book/ui_close(mob/user)
	. = ..()
	LAZYREMOVE(illustration_previews, REF(user))
	if(aloud_reader == user)
		stop_reading_aloud()

/obj/item/book/ui_state(mob/user)
	if(unique)
		return ..()
	return GLOB.book_state

/obj/item/book/ui_data(mob/user)
	. = ..()
	if(unique || carved || !isliving(user))
		return
	.["canEdit"] = !isnull(held_writing_tool(user))
	.["canIllustrate"] = !isnull(held_illustration(user))
	.["canReadAloud"] = can_read_aloud(user)
	.["readingPage"] = aloud_reader == user ? aloud_page : 0
	.["readAloudVoiceEnabled"] = SStts220.is_enabled

/obj/item/book/ui_interact(mob/living/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, unique ? "MarkdownViewer" : "IllustratedBook", name)
		ui.open()

/// Proc that handles sending the book information to the user, as well as some housekeeping stuff.
/obj/item/book/proc/display_content(mob/living/user)
	ui_interact(user)

/// Proc that checks if the user is capable of reading the book, for UI interactions and otherwise. Returns TRUE if they can, FALSE if they can't.
/obj/item/book/proc/can_read_book(mob/living/user)
	if(user.is_blind())
		to_chat(user, span_warning("You are blind and can't read anything!"))
		return FALSE

	if(!user.can_read(src))
		return FALSE

	if(carved)
		balloon_alert(user, "book is carved out!")
		return FALSE

	if(unique && !length(book_data.get_content()))
		balloon_alert(user, "book is blank!")
		return FALSE

	return TRUE

/// Proc that adds the book to a list on the user's mind so we know what works of art they've been catching up on.
/obj/item/book/proc/credit_book_to_reader(mob/living/user)
	if(!isliving(user) || isnull(user.mind))
		return

	LAZYINITLIST(user.mind.book_titles_read)
	if(starting_title in user.mind.book_titles_read)
		return

	user.add_mood_event("book_nerd", /datum/mood_event/book_nerd)
	user.mind.book_titles_read[starting_title] = TRUE

/obj/item/book/attack_self(mob/user)
	if(!can_read_book(user))
		return

	playsound(user, 'sound/items/handling/paper_pickup.ogg', 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	user.visible_message(span_notice("[user] opens a book titled \"[book_data.title]\" and begins reading intently."))
	credit_book_to_reader(user)
	display_content(user)

/obj/item/book/proc/is_carving_tool(obj/item/tool)
	PRIVATE_PROC(TRUE)
	if(tool.get_sharpness() & SHARP_EDGED)
		return TRUE
	if(tool.tool_behaviour == TOOL_WIRECUTTER)
		return TRUE
	return FALSE

/// Checks the physical book and actor again at the moment a change is applied.
/obj/item/book/proc/can_change_book(mob/living/user)
	if(!istype(user) || QDELETED(user) || QDELETED(src) || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH) || !user.can_read(src) || user.is_blind())
		return FALSE
	if(unique)
		balloon_alert(user, "эту книгу нельзя править!")
		return FALSE
	if(carved)
		balloon_alert(user, "страницы вырезаны!")
		return FALSE
	return TRUE

/// A reader may hold their book in either hand or leave it on the desk.
/obj/item/book/proc/held_writing_tool(mob/user)
	for(var/obj/item/tool as anything in user.get_held_items())
		if(IS_WRITING_UTENSIL(tool))
			return tool
	return null

/// Only physical photographs and finished paintings supply page images.
/obj/item/book/proc/held_illustration(mob/user)
	// When both hands contain artwork, using one on a book selects that hand's image.
	var/list/sources = list(user.get_active_held_item()) | user.get_held_items()
	for(var/obj/item/source as anything in sources)
		if(istype(source, /obj/item/photo))
			var/obj/item/photo/photo = source
			if(photo.picture?.picture_image)
				return photo.picture.picture_image
		if(istype(source, /obj/item/canvas))
			var/obj/item/canvas/painting = source
			if(painting.finalized && painting.generated_icon)
				return painting.generated_icon
	return null

/// Captures one still frame so the page stays independent of the original photograph or painting.
/obj/item/book/proc/illustration_png(icon/source)
	var/icon/copy = icon(source, dir = SOUTH, frame = 1)
	var/long_side = max(copy.Width(), copy.Height())
	if(long_side > MAX_BOOK_ILLUSTRATION_SIDE)
		var/scale = MAX_BOOK_ILLUSTRATION_SIDE / long_side
		copy.Scale(max(1, round(copy.Width() * scale)), max(1, round(copy.Height() * scale)))
	return icon2base64(copy)

/obj/item/book/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Items can both be carving tools and writing utensils.
	// Because of this, we flip interaction priority on secondary.
	// This means pure writing utensils have writing as their primary action,
	// pure carving tools have carving as their primary action,
	// but items with both have primary write secondary carve.
	if(IS_WRITING_UTENSIL(tool))
		return writing_utensil_act(user, tool)
	if(!unique && (istype(tool, /obj/item/photo) || istype(tool, /obj/item/canvas)))
		if(can_change_book(user))
			ui_interact(user)
		return ITEM_INTERACT_SUCCESS
	if(is_carving_tool(tool))
		return carving_act(user, tool)
	return NONE

/obj/item/book/item_interaction_secondary(mob/living/user, obj/item/tool, list/modifiers)
	if(is_carving_tool(tool))
		return carving_act(user, tool)
	if(IS_WRITING_UTENSIL(tool))
		return writing_utensil_act(user, tool)
	return NONE

/// Opens the spread editor when a reader uses a pen on a manuscript.
/obj/item/book/proc/writing_utensil_act(mob/living/user, obj/item/tool)
	if(!can_change_book(user) || !user.can_write(tool))
		return ITEM_INTERACT_BLOCKING
	ui_interact(user)
	return ITEM_INTERACT_SUCCESS

/// Bind a private snapshot to its numbered page or the cover so it can only be saved there.
/obj/item/book/proc/preview_illustration(mob/living/user, datum/tgui/ui, target, url, request_id)
	if(!istext(request_id) || !length(request_id) || length(request_id) > 64)
		return
	var/reader = REF(user)
	var/list/preview = list("requestId" = request_id, "page" = target, "revision" = book_data.revision)
	LAZYSET(illustration_previews, reader, preview)
	if(!is_valid_portrait_image_url(url))
		preview["error"] = "Нужна прямая HTTPS-ссылка на PNG или JPEG с Gyazo, Lensdump, Imgbox, Catbox или File Garden."
	else
		var/list/result = import_illustration(url, user)
		if(QDELETED(src) || QDELETED(user) || QDELETED(ui) || LAZYACCESS(illustration_previews, reader) != preview)
			return
		if(book_data.revision != preview["revision"] || !can_change_book(user) || !held_writing_tool(user))
			preview["error"] = "Книга или условия редактирования изменились. Проверьте книгу и ручку."
		else if(result?["image"])
			preview["image"] = result["image"]
		else
			preview["error"] = result?["error"] || "Не удалось загрузить иллюстрацию."
	update_static_data(user, ui)

/obj/item/book/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || unique || carved || !isliving(ui.user))
		return
	var/mob/living/user = ui.user
	if(action == "stop_reading")
		if(aloud_reader == user)
			stop_reading_aloud()
			return TRUE
		return
	if(action == "read_aloud")
		return start_reading_aloud(user, params["page"], params["revision"])
	if(action == "play_flip_sound")
		if(COOLDOWN_FINISHED(src, page_sound_cooldown))
			COOLDOWN_START(src, page_sound_cooldown, 0.4 SECONDS)
			playsound(src, SFX_PAGE_TURN, 30, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		return
	if(!can_change_book(user))
		return
	var/revision = params["revision"]
	if(!isnum(revision) || revision != book_data.revision)
		balloon_alert(user, "книгу уже изменили!")
		return
	var/page_index = params["page"]
	var/changed = FALSE
	if(action == "attach_image" || (action == "preview_illustration" && page_index != BOOK_COVER_TARGET))
		var/number_of_pages = isnull(book_data.pages) ? length(book_data.get_pages()) : length(book_data.pages)
		if(!isnum(page_index) || !ISINTEGER(page_index) || !ISINRANGE(page_index, 1, number_of_pages))
			return
	if(action == "attach_image" || action == "attach_cover")
		var/icon/illustration = held_illustration(user)
		if(!illustration)
			balloon_alert(user, "нужен снимок или готовый холст!")
			return
		var/png = illustration_png(illustration)
		if(png)
			changed = action == "attach_cover" ? book_data.set_cover_image(png) : book_data.set_page_image(page_index, png)
	else
		var/obj/item/pen = held_writing_tool(user)
		if(!pen)
			balloon_alert(user, "нужна ручка!")
			return
		if(!user.can_write(pen))
			return
		switch(action)
			if("preview_illustration")
				preview_illustration(user, ui, page_index, params["url"], params["requestId"])
				return
			if("save_page", "save_cover")
				var/saving_cover = action == "save_cover"
				var/image
				if("illustrationRequestId" in params)
					var/list/preview = LAZYACCESS(illustration_previews, REF(user))
					var/target = saving_cover ? BOOK_COVER_TARGET : page_index
					if(!preview?["image"] || preview["requestId"] != params["illustrationRequestId"] || preview["page"] != target || preview["revision"] != revision)
						balloon_alert(user, "загрузите предпросмотр заново!")
						return
					image = preview["image"]
				if(saving_cover)
					var/new_binding = book_data.binding_color
					if("bindingColor" in params)
						new_binding = params["bindingColor"]
						if(!istext(new_binding))
							return
					else if(!image)
						return
					changed = book_data.set_cover_image(image || book_data.cover_image, new_binding)
					if(changed && new_binding)
						apply_binding_icon()
				else
					changed = book_data.set_page_text(page_index, params["text"], params["caption"], image)
			if("insert_page")
				changed = book_data.add_page(page_index)
			if("delete_page")
				changed = book_data.remove_page(page_index)
			if("remove_image")
				changed = book_data.set_page_image(page_index, null)
			if("remove_cover")
				changed = book_data.set_cover_image(null)
			if("edit_title", "edit_author")
				var/editing_title = action == "edit_title"
				var/current_value = html_decode(editing_title ? book_data.title : book_data.author)
				var/value = tgui_input_text(user, editing_title ? "Название книги" : "Имя автора", "Редактирование книги", default = current_value, max_length = editing_title ? 30 : MAX_NAME_LEN, encode = FALSE)
				if(!length(value) || !can_change_book(user) || QDELETED(pen) || !user.is_holding(pen) || !user.can_write(pen))
					return
				if(revision != book_data.revision)
					balloon_alert(user, "книгу уже изменили!")
					return
				if(editing_title)
					if(!book_data.set_title(value, from_editor = TRUE))
						balloon_alert(user, "недопустимое название!")
						return
					name = book_data.title
				else
					if(!book_data.set_author(value, from_editor = TRUE))
						balloon_alert(user, "недопустимое имя!")
						return
				changed = TRUE
			else
				return

	if(!changed)
		balloon_alert(user, "изменение не поместилось!")
		return
	// Every pending preview was made against the preceding revision.
	illustration_previews = null
	playsound(src, SFX_WRITING_PEN, 30, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	update_static_data_for_all_viewers()
	return TRUE

/// Called when user clicks on the book with a carving utensil. Attempts to carve the book.
/obj/item/book/proc/carving_act(mob/living/user, obj/item/tool)
	if(carved)
		balloon_alert(user, "already carved!")
		return ITEM_INTERACT_BLOCKING

	balloon_alert(user, "carving out...")
	if(!do_after(user, 3 SECONDS, target = src))
		balloon_alert(user, "interrupted!")
		return ITEM_INTERACT_BLOCKING

	balloon_alert(user, "carved out")
	playsound(src, 'sound/effects/cloth_rip.ogg', vol = 75, vary = TRUE)
	carve_out()
	return ITEM_INTERACT_SUCCESS

/// Handles setting everything a carved book needs.
/obj/item/book/proc/carve_out()
	carved = TRUE
	SStgui.close_uis(src)
	create_storage(storage_type = carved_storage_type)

/// Uses the edition's chosen binding, or a random stock cover for uncustomized books.
/obj/item/book/proc/apply_binding_icon()
	icon_state = GLOB.book_binding_icons[book_data.binding_color] || "book[rand(1, maximum_book_state)]"

#undef MAX_BOOK_ILLUSTRATION_SIDE
#undef BOOK_COVER_TARGET

/// Base type for a book that opens a bespoke TUGI
/// Does not inherit from /obj/item/book because the only similarities between the two are the concept of "being a book"
/// When designing a UI book you can send a "play_flip_sound" act to play the page turn sound
/obj/item/tgui_book
	name = "book"
	desc = "Must be one of those new fangled electronic books."
	icon = 'icons/obj/service/library.dmi'
	icon_state ="book"
	worn_icon_state = "book"
	throw_speed = 1
	throw_range = 5
	w_class = WEIGHT_CLASS_NORMAL  //upped to three because books are, y'know, pretty big. (and you could hide them inside eachother recursively forever)
	attack_verb_continuous = list("bashes", "whacks", "educates")
	attack_verb_simple = list("bash", "whack", "educate")
	resistance_flags = FLAMMABLE
	drop_sound = 'sound/items/handling/book_drop.ogg'
	pickup_sound = 'sound/items/handling/book_pickup.ogg'
	/// The name of the UI to open
	var/ui_name

/obj/item/tgui_book/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, ui_name)
		ui.open()
		playsound(src, SFX_PAGE_TURN, 30, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)

/obj/item/tgui_book/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "play_flip_sound")
		playsound(src, SFX_PAGE_TURN, 30, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)

/obj/item/tgui_book/manual/ui_state(mob/user)
	return GLOB.book_state

// For guides
/obj/item/tgui_book/manual
	abstract_type = /obj/item/tgui_book/manual

/// Asserts a field is present in a list, stack traces if not
#define ASSERT_DATA(data_list, data_field) \
	if(!data_list[data_field]) { stack_trace("[type] - [data_list["id"]] lacks [data_field] information!"); }

/obj/item/tgui_book/manual/dsm
	name = "\improper SDSM-35" // 35 was picked based on the current edition plus the average years between edition divided by 500
	desc = "The Space Diagnostic and Statistical Manual of Mental Disorders, \
		a comprehensive book on all known mental disorders. \
		On its 35th edition - though it's due for an update..."
	icon_state = "book8"
	ui_name = "DSMBook"

/obj/item/tgui_book/manual/dsm/ui_static_data(mob/user)
	var/list/data = list()

	var/static/list/trauma_info
	if(!trauma_info)
		trauma_info = list()

		var/list/blacklist = list()
		// phobias need some special handing thanks to all their funky types
		blacklist += typesof(/datum/brain_trauma/mild/phobia)

		for(var/datum/brain_trauma/trauma_type as anything in valid_subtypesof(/datum/brain_trauma) - blacklist)
			if(!trauma_type::known_trauma)
				continue

			var/list/trauma_data = list()
			trauma_data["full_name"] = trauma_type::name
			trauma_data["scan_name"] = trauma_type::scan_desc
			trauma_data["desc"] = trauma_type::desc
			trauma_data["symptoms"] = trauma_type::symptoms
			trauma_data["id"] = trauma_type
			trauma_info += list(trauma_data)

		for(var/datum/quirk/quirk_type as anything in valid_subtypesof(/datum/quirk))
			if(!(quirk_type::quirk_flags & QUIRK_TRAUMALIKE))
				continue

			var/list/trauma_data = list()
			trauma_data["full_name"] = quirk_type::name
			trauma_data["scan_name"] = LOWER_TEXT(quirk_type::name)
			trauma_data["desc"] = quirk_type::medical_record_text
			trauma_data["symptoms"] = quirk_type::medical_symptom_text
			trauma_data["id"] = quirk_type
			trauma_info += list(trauma_data)

		for(var/datum/addiction/addiction_type as anything in GLOB.addictions)
			var/list/trauma_data = list()
			trauma_data["full_name"] = "[capitalize(addiction_type::name)] Addiction"
			trauma_data["scan_name"] = "[addiction_type::name] addiction"
			trauma_data["desc"] = addiction_type::description
			trauma_data["symptoms"] = addiction_type::symptoms
			trauma_data["id"] = addiction_type
			trauma_info += list(trauma_data)

		for(var/phobia_type, phobia_name in GLOB.phobia_types)
			var/list/trauma_data = list()
			trauma_data["full_name"] = phobia_name
			trauma_data["scan_name"] = "[/datum/brain_trauma/mild/phobia::scan_desc] of [phobia_type]"
			trauma_data["desc"] = "Patient is irrationally afraid of [phobia_type]."
			trauma_data["symptoms"] = /datum/brain_trauma/mild/phobia::symptoms
			trauma_data["id"] = "[/datum/brain_trauma/mild/phobia]/[phobia_type]"
			trauma_info += list(trauma_data)

		// validate
		for(var/list/trauma_data as anything in trauma_info)
			// these are asserted to be present, no matter what
			ASSERT_DATA(trauma_data, "full_name")
			ASSERT_DATA(trauma_data, "scan_name")
			ASSERT_DATA(trauma_data, "id")
			// these start as null, so there is a chance they are missing
			if(!trauma_data["desc"])
				trauma_data["desc"] = "No description recorded - this is an error. Report this lack of research."
				stack_trace("[type] - [trauma_data["id"]] lacks a description!")
			if(!trauma_data["symptoms"])
				trauma_data["symptoms"] = "No symptoms recorded - this is an error. Report this lack of research."
				stack_trace("[type] - [trauma_data["id"]] lacks symptom information!")

	data["traumas"] = trauma_info
	return data

/obj/item/tgui_book/manual/idc
	name = "\improper IDC-27" // 27 was picked based on the current edition plus the average years between edition divided by 500
	desc = "The Interplanetary Classification of Diseases, \
		a comprehensive book on all known diseases and ailments. \
		On its 27th edition - though it's due for an update..."
	icon_state = "book7"
	ui_name = "IDCBook"

/obj/item/tgui_book/manual/idc/ui_static_data(mob/user)
	var/list/data = list()

	var/static/list/disease_info
	if(!disease_info)
		disease_info = list()

		for(var/datum/disease/disease_type as anything in valid_subtypesof(/datum/disease))
			if(disease_type::visibility_flags & HIDDEN_BOOK)
				continue

			var/list/disease_data = list()
			disease_data["form"] = disease_type::form
			disease_data["agent"] = disease_type::agent
			disease_data["name"] = disease_type::name
			disease_data["desc"] = disease_type::desc
			disease_data["illness"] = "N/A"
			disease_data["spread_by"] = disease_type::spread_text || get_disease_spread_text(disease_type::spread_flags)
			disease_data["cured_by"] = disease_type::cure_text
			disease_data["id"] = disease_type
			disease_data["level"] = "N/A"
			disease_info += list(disease_data)

		for(var/datum/symptom/symptom_type as anything in valid_subtypesof(/datum/symptom))
			var/list/symptom_data = list()
			symptom_data["form"] = "Symptom"
			symptom_data["agent"] = "N/A"
			symptom_data["name"] = symptom_type::name
			symptom_data["desc"] = symptom_type::desc
			symptom_data["illness"] = symptom_type::illness
			symptom_data["spread_by"] = "N/A"
			symptom_data["cured_by"] = symptom_type::symptom_cure::name
			symptom_data["id"] = symptom_type
			symptom_data["level"] = "[symptom_type::level]"
			disease_info += list(symptom_data)

		var/list/advanced_virus_info = list(
			"form" = "Virus",
			"agent" = "Microbes",
			"name" = "Advanced Disease",
			"desc" = "A catch-all category for diseases that are too complex to document in their entirety. \
				The Virology department is known for bio-engineering these diseases, as such their danger can vary wildly. \
				These diseases are often a combination of various symptoms, each cataloged in this book individually.",
			"illness" = "N/A",
			"spread_by" = "Varies by symptom combination",
			"cured_by" = "Varies by symptom combination",
			"id" = /datum/disease/advance,
		)
		disease_info += list(advanced_virus_info)

		// validate
		for(var/list/disease_data as anything in disease_info)
			// these are asserted to be present, no matter what
			ASSERT_DATA(disease_data, "form")
			ASSERT_DATA(disease_data, "agent")
			ASSERT_DATA(disease_data, "name")
			ASSERT_DATA(disease_data, "spread_by")
			ASSERT_DATA(disease_data, "illness")
			ASSERT_DATA(disease_data, "id")
			// these start as null, so there is a chance they are missing
			if(!disease_data["desc"])
				disease_data["desc"] = "No description recorded - this is an error. Report this lack of research."
				stack_trace("[type] - [disease_data["id"]] lacks a description!")
			if(!disease_data["cured_by"] && !ispath(disease_data["id"], /datum/symptom))
				disease_data["cured_by"] = "Unknown"
				stack_trace("[type] - [disease_data["id"]] lacks cure information!")

	data["diseases"] = disease_info
	return data

#undef ASSERT_DATA
