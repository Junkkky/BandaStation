/// Binding choices correspond to existing physical book sprites in library.dmi.
GLOBAL_LIST_INIT(book_binding_icons, list(
	"green" = "book5",
	"red" = "book2",
	"amber" = "book3",
	"blue" = "book4",
	"purple" = "book6",
	"black" = "book",
))

//Some information about how html sanitization is handled
//All book info datums should store sanitized data. This cannot be worked around
//All inputs and outputs from the round (DB calls) need to use sanitized data
//All tgui menus should get unsanitized data, since jsx handles that on its own
//Everything else should use sanitized data. Yes including names, it's an xss vuln because of how chat works
///A datum which contains all the metadata of a book
/datum/book_info
	///The title of the book
	var/title
	///The "author" of the book
	var/author
	///The info inside the book
	var/content
	/// Ordered page records with HTML-encoded text and an optional server-generated PNG in base64.
	/// Null identifies an edition that still uses the original single content field.
	var/list/pages
	/// Optional embedded PNG on the binding, independent of the numbered pages.
	var/cover_image
	/// Null preserves the original appearance of books that never had a binding chosen.
	var/binding_color
	/// Used to reject edits made against an older version of a manuscript.
	var/revision = 0

/datum/book_info/New(_title, _author, _content)
	title = _title
	author = _author
	content = _content

/datum/book_info/proc/set_title(_title, trusted = FALSE, from_editor = FALSE)  //Trusted should only be used for books read from the db, or in cases that we can be sure the info has already been sanitized
	if(from_editor)
		if(!istext(_title))
			return FALSE
		_title = reject_bad_text(trim(_title), 30, ascii_only = FALSE)
		if(!_title)
			return FALSE
		_title = html_encode(_title)
		if(length_char(_title) > MAX_LIBRARY_METADATA_LENGTH)
			return FALSE
	else if(!trusted)
		_title = reject_bad_text(trim(html_encode(_title), 30))
	title = _title
	revision++
	return TRUE

/datum/book_info/proc/get_title(default="N/A") //Loads in an html decoded version of the title. Only use this for tgui menus, absolutely nothing else.
	return html_decode(title) || default

/datum/book_info/proc/set_author(_author, trusted = FALSE, from_editor = FALSE)
	if(from_editor)
		if(!istext(_author))
			return FALSE
		_author = trim(_author)
		if(!length(_author) || length_char(_author) > MAX_NAME_LEN)
			return FALSE
		_author = html_encode(_author)
		if(length_char(_author) > MAX_LIBRARY_METADATA_LENGTH)
			return FALSE
	else if(!trusted)
		_author = trim(html_encode(_author), MAX_NAME_LEN)
	author = _author
	revision++
	return TRUE

/datum/book_info/proc/get_author(default="N/A")
	return html_decode(author) || default

/datum/book_info/proc/set_content(_content, trusted = FALSE)
	pages = null
	revision++
	if(trusted)
		content = _content
		return
	content = trim(html_encode(trim(_content, MAX_PAPER_LENGTH)), MAX_BOOK_LENGTH)

/datum/book_info/proc/set_content_using_paper(obj/item/paper/paper)
	pages = null
	revision++
	// Just the paper's raw data.
	var/raw_content = ""
	for(var/datum/paper_input/text_input as anything in paper.raw_text_inputs)
		raw_content += text_input.to_raw_html()
		raw_content += (text_input.raw_text[length(text_input.raw_text)] == "\n") ? "\n" : "\n\n"

	// Paper raw inputs should already be trimmed to maximum paper length,
	// so we don't trim here again to avoid cutting into the expanded html.
	// We still trim to a more lenient length to avoid abuse.
	content = trim(html_encode(raw_content), MAX_BOOK_LENGTH)

/datum/book_info/proc/get_content(default="N/A")
	return html_decode(content) || "N/A"

/// Returns independent page records for the UI or for editing. Old books stay in their original format until edited.
/datum/book_info/proc/get_pages(encoded = FALSE)
	var/list/result = list()
	if(pages)
		for(var/list/page as anything in pages)
			result += list(list(
				"text" = encoded ? page["text"] : html_decode(page["text"]),
				"image" = page["image"],
				"caption" = encoded ? page["caption"] : html_decode(page["caption"]),
			))
		return result

	var/old_text = html_decode(content) || ""
	var/count = length_char(old_text)
	var/start = 1
	while(start <= count)
		var/chunk = copytext_char(old_text, start, start + MAX_LIBRARY_PAGE_LENGTH)
		if(start + MAX_LIBRARY_PAGE_LENGTH <= count)
			// Keep the separator on the preceding page so the original can always be reconstructed.
			var/break_at = max(findlasttext(chunk, " "), findlasttext(chunk, "\n"))
			if(break_at > length(chunk) / 2)
				chunk = copytext(chunk, 1, break_at + 1)
		result += list(list("text" = encoded ? html_encode(chunk) : chunk, "image" = null, "caption" = ""))
		start += length_char(chunk)
	if(!length(result))
		result += list(list("text" = "", "image" = null, "caption" = ""))
	return result

/// Illustrated editions can be readable even if the author supplied no text.
/datum/book_info/proc/has_content()
	if(cover_image)
		return TRUE
	if(isnull(pages))
		return !!length(trim(content))
	for(var/list/page as anything in pages)
		if(length(trim(page["text"])) || page["image"])
			return TRUE
	return FALSE

/// Checks an index without allowing fractional or out-of-range subscripts.
/datum/book_info/proc/valid_page_index(index, list/book_pages)
	PRIVATE_PROC(TRUE)
	return isnum(index) && ISINTEGER(index) && index >= 1 && index <= length(book_pages)

/// The archive and clients accept only a bounded PNG payload, without paths or URL schemes.
/datum/book_info/proc/valid_page_image(png)
	PRIVATE_PROC(TRUE)
	if(isnull(png))
		return TRUE
	if(!istext(png) || length(png) > MAX_LIBRARY_IMAGE_LENGTH || length(png) % 4)
		return FALSE
	var/static/regex/base64_png = regex(@"\AiVBORw0KGgo[A-Za-z0-9+/]*={0,2}\z")
	return !!base64_png.Find(png)

/// Commits a complete edit only when both the illustrated edition and its text-only projection fit.
/datum/book_info/proc/commit_pages(list/new_pages, new_cover, new_binding)
	PRIVATE_PROC(TRUE)
	if(!isnull(new_binding) && (!istext(new_binding) || !(new_binding in GLOB.book_binding_icons)))
		return FALSE
	var/list/texts = list()
	var/image_bytes = length(new_cover)
	for(var/list/page as anything in new_pages)
		var/page_text = page["text"]
		if(page["image"])
			var/legend = page["caption"] || "Иллюстрация"
			page_text = page_text ? "[page_text]\n\n[legend]" : legend
		texts += page_text
		image_bytes += length(page["image"])
	if(image_bytes > MAX_LIBRARY_BOOK_IMAGES_LENGTH)
		return FALSE
	var/new_content = jointext(texts, "\n\n")
	if(length(new_content) > MAX_LIBRARY_ARCHIVE_TEXT_BYTES)
		return FALSE
	// Unpaginated editions retain the exact legacy text when only their cover changes.
	if(!isnull(new_pages))
		content = new_content
	pages = new_pages
	cover_image = new_cover
	binding_color = new_binding
	revision++
	return TRUE

/// Commits text, caption and an optional imported illustration in one revision.
/datum/book_info/proc/set_page_text(index, new_text, caption, new_image)
	if(!istext(new_text) || length_char(new_text) > MAX_LIBRARY_PAGE_LENGTH)
		return FALSE
	if(!isnull(caption) && (!istext(caption) || length_char(caption) > MAX_LIBRARY_CAPTION_LENGTH))
		return FALSE
	if(!valid_page_image(new_image))
		return FALSE
	var/list/new_pages = get_pages(encoded = TRUE)
	if(!valid_page_index(index, new_pages))
		return FALSE
	var/list/page = new_pages[index]
	if(!isnull(new_image))
		page["image"] = new_image
	page["text"] = html_encode(new_text)
	if(!isnull(caption))
		if(length(caption) && !page["image"])
			return FALSE
		page["caption"] = html_encode(caption)
	return commit_pages(new_pages, cover_image, binding_color)

/// Inserts a blank leaf immediately after the selected page.
/datum/book_info/proc/add_page(after_index)
	var/list/new_pages = get_pages(encoded = TRUE)
	if(!valid_page_index(after_index, new_pages) || length(new_pages) >= MAX_LIBRARY_BOOK_PAGES)
		return FALSE
	new_pages.Insert(after_index + 1, list(list("text" = "", "image" = null, "caption" = "")))
	return commit_pages(new_pages, cover_image, binding_color)

/// Removes one page. Every manuscript retains at least one editable page.
/datum/book_info/proc/remove_page(index)
	var/list/new_pages = get_pages(encoded = TRUE)
	if(!valid_page_index(index, new_pages) || length(new_pages) <= 1)
		return FALSE
	new_pages.Cut(index, index + 1)
	return commit_pages(new_pages, cover_image, binding_color)

/// Attaches a PNG from a physical item, or removes the illustration when passed null.
/datum/book_info/proc/set_page_image(index, png)
	if(!valid_page_image(png))
		return FALSE
	var/list/new_pages = get_pages(encoded = TRUE)
	if(!valid_page_index(index, new_pages))
		return FALSE
	var/list/page = new_pages[index]
	page["image"] = png
	if(isnull(png))
		page["caption"] = ""
	return commit_pages(new_pages, cover_image, binding_color)

/// Changes only the binding and shares the edition's existing image budget.
/datum/book_info/proc/set_cover_image(png, new_binding = binding_color)
	if(!valid_page_image(png))
		return FALSE
	return commit_pages(pages, png, new_binding)

/// Only editions with a customized cover need the versioned envelope around the existing pages.
/datum/book_info/proc/serialize_pages()
	if(cover_image || binding_color)
		var/list/edition = list("version" = 1, "cover" = cover_image, "pages" = pages)
		if(binding_color)
			edition["bindingColor"] = binding_color
		return json_encode(edition)
	return pages ? json_encode(pages) : null

/// Loads an edition atomically after set_content() supplied the readable text fallback.
/datum/book_info/proc/load_pages(archived_pages)
	if(isnull(archived_pages))
		if(cover_image || binding_color || !isnull(pages))
			return commit_pages(null, null, null)
		return TRUE
	// JSON escapes can expand the text projection by up to six bytes per character.
	if(!istext(archived_pages) || length(archived_pages) > MAX_LIBRARY_BOOK_IMAGES_LENGTH + 6 * MAX_LIBRARY_ARCHIVE_TEXT_BYTES + 8192)
		return FALSE
	var/list/records = safe_json_decode(archived_pages)
	if(!islist(records))
		return FALSE
	var/new_cover
	var/new_binding
	if("version" in records)
		new_cover = records["cover"]
		new_binding = records["bindingColor"]
		if(records["version"] != 1 || (!new_cover && !new_binding) || !valid_page_image(new_cover) || !("pages" in records))
			return FALSE
		records = records["pages"]
		if(isnull(records))
			return commit_pages(null, new_cover, new_binding)
	// Longer old TEXT editions can have more pages than a new manuscript allows.
	// The splitter cuts in the latter half of its chunk or at the full character limit.
	if(!islist(records) || !length(records) || length(records) > 2 * MAX_LIBRARY_ARCHIVE_TEXT_BYTES / MAX_LIBRARY_PAGE_LENGTH + 2)
		return FALSE
	var/list/new_pages = list()
	for(var/entry in records)
		if(!islist(entry))
			return FALSE
		var/list/page = entry
		if(!istext(page["text"]) || !istext(page["caption"]) || !valid_page_image(page["image"]))
			return FALSE
		var/raw_text = html_decode(page["text"])
		var/raw_caption = html_decode(page["caption"])
		if(length_char(raw_text) > MAX_LIBRARY_PAGE_LENGTH || length_char(raw_caption) > MAX_LIBRARY_CAPTION_LENGTH || (length(raw_caption) && !page["image"]))
			return FALSE
		new_pages += list(list("text" = html_encode(raw_text), "image" = page["image"], "caption" = html_encode(raw_caption)))
	return commit_pages(new_pages, new_cover, new_binding)

///Returns a copy of the book_info datum
/datum/book_info/proc/return_copy()
	var/datum/book_info/copycat = new
	return copy_into(copycat)

///Modify an existing book_info datum to match your data
/datum/book_info/proc/copy_into(datum/book_info/copycat)
	copycat.set_title(title, trusted = TRUE)
	copycat.set_author(author, trusted = TRUE)
	copycat.set_content(content, trusted = TRUE)
	copycat.cover_image = cover_image
	copycat.binding_color = binding_color
	if(pages)
		copycat.pages = get_pages(encoded = TRUE)
	return copycat

/datum/book_info/proc/compare(datum/book_info/cmp_with)
	if(author != cmp_with.author)
		return FALSE
	if(title != cmp_with.title)
		return FALSE
	if(content != cmp_with.content || cover_image != cmp_with.cover_image || binding_color != cmp_with.binding_color)
		return FALSE
	if(length(pages) != length(cmp_with.pages))
		return FALSE
	for(var/index in 1 to length(pages))
		var/list/our_page = pages[index]
		var/list/their_page = cmp_with.pages[index]
		if(our_page["text"] != their_page["text"] || our_page["image"] != their_page["image"] || our_page["caption"] != their_page["caption"])
			return FALSE
	return TRUE
