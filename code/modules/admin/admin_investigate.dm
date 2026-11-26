/atom/proc/investigate_log(message, subject)
	if(!message)
		return
	if(!subject)
		CRASH("No subject provided for investigate_log")
	var/F = file("[GLOB.log_directory]/[subject].html")
	var/source = "[src]"

	if(isliving(src))
		var/mob/living/source_mob = src
		source += " ([source_mob.ckey ? source_mob.ckey : "*no key*"])"

	WRITE_FILE(F, "[server_timestamp(format = "YYYY-MM-DD hh:mm:ss")] [REF(src)] ([x],[y],[z]) || [source] [message]<br>")

ADMIN_VERB(investigate_show, R_ADMIN|R_DEBUG, "Investigate", "Browse various detailed logs.", ADMIN_CATEGORY_GAME)
	var/static/list/investigates = list(
		INVESTIGATE_ACCESSCHANGES,
		INVESTIGATE_ATMOS,
		INVESTIGATE_BOTANY,
		INVESTIGATE_CARGO,
		INVESTIGATE_CRAFTING,
		INVESTIGATE_DEATHS,
		INVESTIGATE_ENGINE,
		INVESTIGATE_EXPERIMENTOR,
		INVESTIGATE_GRAVITY,
		INVESTIGATE_HALLUCINATIONS,
		INVESTIGATE_HYPERTORUS,
		INVESTIGATE_PORTAL,
		INVESTIGATE_PRESENTS,
		INVESTIGATE_RADIATION,
		INVESTIGATE_RECORDS,
		INVESTIGATE_RESEARCH,
		INVESTIGATE_WIRES,
	)

	var/list/logs_present = list("notes, memos, watchlist")
	var/list/logs_missing = list("---")

	for(var/subject in investigates)
		var/temp_file = file("[GLOB.log_directory]/[subject].html")
		if(fexists(temp_file))
			logs_present += subject
		else
			logs_missing += "[subject] (empty)"

	var/list/combined = sort_list(logs_present) + sort_list(logs_missing)

	var/selected = tgui_input_list(user, "Investigate what?", "Investigation", combined)
	if(isnull(selected))
		return
	if(!(selected in combined) || selected == "---")
		return

	selected = replacetext(selected, " (empty)", "")

	if(selected == "notes, memos, watchlist" && check_rights(R_ADMIN))
		browse_messages()
		return

	var/F = file("[GLOB.log_directory]/[selected].html")
	if(!fexists(F))
		to_chat(user, span_danger("No [selected] logfile was found."), confidential = TRUE)
		return

	var/datum/browser/browser = new(user, "investigate[selected]", "Investigation of [selected]", 800, 300)
	browser.set_content(sanitize_investigation_log(file2text(F)))
	browser.open()

/// Investigation files mix game formatting with player text, including records written before this round's code.
/proc/sanitize_investigation_log(contents)
	var/static/allowed_tags = json_encode(list("br", "b", "strong", "i", "em", "u", "span", "font"))
	var/static/allowed_attributes = json_encode(list("class", "color"))
	return rustg_sanitize_html(contents, allowed_attributes, allowed_tags)
