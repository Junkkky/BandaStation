#define BOOK_PHRASE_LENGTH 120
#define COOLDOWN_BOOK_READING "book_reading"

/obj/item/book/Destroy()
	stop_reading_aloud()
	return ..()

/obj/item/book/dropped(mob/user, silent)
	if(user == aloud_reader)
		stop_reading_aloud()
	return ..()

/// The actor must be able to read and speak in person. Speech itself performs the normal IC checks.
/obj/item/book/proc/can_read_aloud(mob/living/user)
	return !QDELETED(user) && !unique && !carved && user.is_holding(src) && !user.incapacitated \
		&& !IS_UNCONSCIOUS_OR_CRIT(user) && !user.is_blind() && user.can_read(src, silent = TRUE) \
		&& user.can_speak() && !HAS_TRAIT(user, TRAIT_SIGN_LANG) && !(user.client?.prefs.muted & MUTE_IC)

/// Split the server's plain page text into short utterances, preferably at a sentence or word boundary.
/obj/item/book/proc/page_reading_phrases(list/page)
	var/static/regex/block_markup = regex(@"^[ \t]*(?:#{1,6}|[-*+]|\d+[.)])[ \t]+", "gm")
	var/static/regex/emphasis = regex(@"(\*{1,3}|_{1,3})(\S(?:[^\n]*?\S)?)\1", "g")
	var/body = block_markup.Replace(page["text"], "")
	body = emphasis.Replace(body, "$2")
	var/text = htmlrendertext("[body] [page["caption"]]")
	var/list/phrases = list()
	while(length(text))
		var/phrase = copytext_char(text, 1, BOOK_PHRASE_LENGTH + 1)
		if(length(phrase) < length(text))
			var/boundary = max(findlasttext(phrase, ". "), findlasttext(phrase, "? "), findlasttext(phrase, "! "))
			if(!boundary)
				boundary = findlasttext(phrase, " ")
			if(boundary)
				phrase = copytext(phrase, 1, boundary + 1)
		text = trim_left(copytext(text, length(phrase) + 1))
		phrases += trim(phrase)
	return phrases

/obj/item/book/proc/start_reading_aloud(mob/living/user, page_number, revision)
	if(aloud_reader || !can_read_aloud(user) || !isnum(revision) || revision != book_data.revision || !isnum(page_number) || !ISINTEGER(page_number))
		return FALSE
	if(!TIMER_COOLDOWN_FINISHED(user, COOLDOWN_BOOK_READING))
		balloon_alert(user, "подождите немного!")
		return FALSE
	for(var/obj/item/book/held in user.get_held_items())
		if(held.aloud_reader == user)
			balloon_alert(user, "вы уже читаете вслух!")
			return FALSE
	var/list/pages = book_data.get_pages()
	if(page_number < 1 || page_number > length(pages))
		return FALSE
	var/list/phrases = page_reading_phrases(pages[page_number])
	if(!length(phrases))
		return FALSE
	aloud_reader = user
	aloud_page = page_number
	aloud_revision = revision
	aloud_phrases = phrases
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING), PROC_REF(stop_reading_aloud))
	TIMER_COOLDOWN_START(user, COOLDOWN_BOOK_READING, 1 SECONDS)
	// Timers created by this callback retain the speaker as usr for IC slow mode and filters.
	world.push_usr(user, CALLBACK(src, PROC_REF(read_next_phrase)))
	return TRUE

/// A speech filter may open a confirmation dialog. The book must still be held when it returns.
/obj/item/book/proc/reading_is_current(list/session)
	return session == aloud_phrases && aloud_revision == book_data.revision && can_read_aloud(aloud_reader)

/obj/item/book/proc/read_next_phrase()
	aloud_timer = null
	var/list/session = aloud_phrases
	if(!length(session) || !reading_is_current(session))
		stop_reading_aloud()
		return
	var/phrase = session[1]
	session.Cut(1, 2)
	var/spoken = aloud_reader.say(phrase, message_mods = list(LITERAL_SPEECH_CHECK = CALLBACK(src, PROC_REF(reading_is_current), session)))
	if(aloud_phrases != session)
		return
	if(!spoken)
		stop_reading_aloud()
		return
	var/delay = max(2 SECONDS, round(length_char(phrase) * (1 SECONDS) / 14))
	aloud_timer = addtimer(CALLBACK(src, PROC_REF(read_next_phrase)), delay, TIMER_STOPPABLE | TIMER_DELETE_ME)

/obj/item/book/proc/stop_reading_aloud()
	SIGNAL_HANDLER
	if(aloud_timer)
		deltimer(aloud_timer)
		aloud_timer = null
	if(aloud_reader)
		UnregisterSignal(aloud_reader, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING))
	aloud_reader = null
	aloud_page = null
	aloud_revision = null
	aloud_phrases = null

#undef COOLDOWN_BOOK_READING
#undef BOOK_PHRASE_LENGTH
