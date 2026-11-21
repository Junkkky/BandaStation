#define GATE_MUSIC_FOLDER "modular_bandastation/gate_closure/sound/music/"
#define GATE_MUSIC_AMBIENT "ambient"
#define GATE_MUSIC_COMBAT "combat"
#define GATE_MUSIC_SITUATIONS "situations"
/// Crossfade between tracks of a playlist and between playlists.
#define GATE_MUSIC_CROSSFADE (3 SECONDS)
/// A situation track first slowly silences whatever played before it.
#define GATE_MUSIC_SITUATION_FADE (5 SECONDS)
/// How often listeners entering or leaving the event locations are picked up.
#define GATE_MUSIC_SYNC_INTERVAL (1 SECONDS)

GLOBAL_DATUM_INIT(gate_closure_music, /datum/gate_closure_music, new)

/// One file from the event music folders.
/datum/gate_closure_track
	var/name
	var/file
	/// Deciseconds.
	var/length

/**
 * The event music player: plays only to clients on the event locations, with endless shuffled
 * ambient and combat playlists, one-off situation tracks and smooth fades between everything.
 */
/datum/gate_closure_music
	/// Category -> list of tracks, read from [GATE_MUSIC_FOLDER].
	var/list/tracks
	/// Files whose length could not be read; they cannot be scheduled, so they are left out.
	var/list/unreadable = list()
	/// GATE_MUSIC_AMBIENT, GATE_MUSIC_COMBAT, GATE_MUSIC_SITUATIONS or null when stopped.
	var/mode
	/// Remaining shuffled tracks of the current playlist.
	var/list/queue = list()
	var/datum/gate_closure_track/current
	var/current_channel
	/// 0..1, rises after a track starts.
	var/current_level = 0
	var/started_at = 0
	/// The previous track, still fading out on its own channel.
	var/fading_channel
	var/fading_level = 0
	var/fading_time = GATE_MUSIC_CROSSFADE
	/// Track waiting for the previous one to finish fading out.
	var/datum/gate_closure_track/pending
	var/pending_at = 0
	/// Master volume, 0..100, scaled by each player's admin music volume.
	var/volume = 60
	/// ckey -> TRUE for every client currently hearing the player.
	var/list/listeners = list()
	var/next_sync = 0
	var/channel_a
	var/channel_b

/// One track from a file in a folder on the server, or null if it is not a sound or its length cannot be read.
/proc/gate_closure_make_track(folder, file_name, list/unreadable)
	var/sound_file = file("[folder][file_name]")
	if(!IS_SOUND_FILE_SAFE(sound_file))
		return null
	var/datum/gate_closure_track/track = new
	track.file = sound_file
	track.name = replacetext(strip_filepath_extension(file_name, SSsounds.safe_formats), "_", " ")
	track.length = SSsounds.get_sound_length(sound_file)
	if(!(track.length > 0))
		unreadable += "[folder][file_name]"
		return null
	return track

/// Tracks of one folder in name order. Files whose length cannot be read cannot be scheduled; their names go to `unreadable`.
/proc/gate_closure_read_tracks(folder, list/unreadable)
	. = list()
	for(var/file_name in sort_list(flist(folder)))
		var/datum/gate_closure_track/track = gate_closure_make_track(folder, file_name, unreadable)
		if(track)
			. += track

/**
 * Asks an admin for an .ogg on their own computer and saves it into a player's folder on the server,
 * the way the jukebox upload does. Returns the new track, or null if nothing usable arrived.
 */
/proc/gate_closure_upload_track(mob/user, folder, list/unreadable)
	var/upload = input(user, "Выберите .ogg на своём компьютере.", "Загрузка звука") as sound|null
	// The file dialog waits for the admin; their rights are checked again once it closes.
	if(!upload || !check_rights_for(user?.client, R_SOUND))
		return null
	if(!IS_OGG_FILE(upload))
		to_chat(user, span_warning("Нужен файл .ogg."), confidential = TRUE)
		return null
	var/file_name = SANITIZE_FILENAME("[upload]")
	if(fexists("[folder][file_name]"))
		to_chat(user, span_warning("[file_name] уже есть в папке."), confidential = TRUE)
		return null
	fcopy(upload, "[folder][file_name]")
	log_admin("[key_name(user)] uploaded [folder][file_name] for the Gate Closure players.")
	message_admins("[key_name_admin(user)] загрузил звук [file_name] в [folder].")
	var/datum/gate_closure_track/track = gate_closure_make_track(folder, file_name, unreadable)
	if(!track)
		to_chat(user, span_warning("Не удалось прочитать длину [file_name]; перепакуйте его: ffmpeg -i in.ogg -c:a copy out.ogg."), confidential = TRUE)
	return track

/// Reads the three folders; files dropped in during the round appear after a rescan.
/datum/gate_closure_music/proc/load_tracks()
	tracks = list()
	unreadable.Cut()
	for(var/category in list(GATE_MUSIC_AMBIENT, GATE_MUSIC_COMBAT, GATE_MUSIC_SITUATIONS))
		tracks[category] = gate_closure_read_tracks("[GATE_MUSIC_FOLDER][category]/", unreadable)
	queue.Cut()

/datum/gate_closure_music/proc/play_playlist(category)
	if(!length(tracks[category]))
		return FALSE
	mode = category
	queue.Cut()
	switch_to(next_track(), GATE_MUSIC_CROSSFADE, crossfade = TRUE)
	return TRUE

/datum/gate_closure_music/proc/play_track(category, datum/gate_closure_track/track)
	mode = category
	if(category == GATE_MUSIC_SITUATIONS)
		switch_to(track, GATE_MUSIC_SITUATION_FADE, crossfade = FALSE)
		return
	queue -= track
	switch_to(track, GATE_MUSIC_CROSSFADE, crossfade = TRUE)

/datum/gate_closure_music/proc/stop()
	mode = null
	queue.Cut()
	switch_to(null, GATE_MUSIC_CROSSFADE, crossfade = TRUE)

/// Reshuffles what is left of the current playlist.
/datum/gate_closure_music/proc/reshuffle()
	if(mode != GATE_MUSIC_AMBIENT && mode != GATE_MUSIC_COMBAT)
		return
	queue = shuffle(tracks[mode] - current)

/// The next track of the playlist; a fresh shuffle never starts with the track that just played.
/datum/gate_closure_music/proc/next_track()
	if(!length(queue))
		queue = shuffle(tracks[mode])
		if(length(queue) > 1 && queue[1] == current)
			queue.Swap(1, length(queue))
	if(!length(queue))
		return null
	var/datum/gate_closure_track/track = queue[1]
	queue.Cut(1, 2)
	return track

/**
 * Fades the current track out and brings the new one in.
 * A crossfade starts the new track at once; otherwise it waits until the old one is silent.
 */
/datum/gate_closure_music/proc/switch_to(datum/gate_closure_track/track, fade_time, crossfade)
	if(!channel_a)
		channel_a = SSsounds.reserve_sound_channel_for_datum(src)
		channel_b = SSsounds.reserve_sound_channel_for_datum(src)
	if(fading_channel)
		silence(fading_channel)
	fading_channel = null
	if(current)
		fading_channel = current_channel
		fading_level = current_level
		fading_time = fade_time
	current = null
	pending = track
	pending_at = world.time + (crossfade || !fading_channel ? 0 : fade_time)
	START_PROCESSING(SSfastprocess, src)

/datum/gate_closure_music/proc/start_pending()
	current = pending
	pending = null
	current_channel = (current_channel == channel_a) ? channel_b : channel_a
	current_level = 0
	started_at = world.time
	log_admin("Gate closure music: [mode] - [current.name].")
	for(var/ckey in listeners)
		var/client/listener = GLOB.directory[ckey]
		if(listener)
			send_current(listener)

/// Starts the current track for one client from where it is now.
/datum/gate_closure_music/proc/send_current(client/listener)
	var/sound/music = sound(current.file, repeat = FALSE, wait = FALSE, channel = current_channel)
	music.volume = listener_volume(listener, current_level)
	music.offset = (world.time - started_at) / 10
	SEND_SOUND(listener, music)

/datum/gate_closure_music/proc/listener_volume(client/listener, level)
	return volume * level * listener.prefs.read_preference(/datum/preference/numeric/volume/sound_midi) / 100

/datum/gate_closure_music/proc/set_level(channel, level)
	for(var/ckey in listeners)
		var/client/listener = GLOB.directory[ckey]
		if(!listener)
			continue
		var/sound/update = sound(null, repeat = FALSE, wait = FALSE, channel = channel, volume = listener_volume(listener, level))
		update.status = SOUND_UPDATE
		SEND_SOUND(listener, update)

/datum/gate_closure_music/proc/silence(channel)
	for(var/ckey in listeners)
		var/client/listener = GLOB.directory[ckey]
		if(listener)
			SEND_SOUND(listener, sound(null, repeat = FALSE, wait = FALSE, channel = channel))

/datum/gate_closure_music/process(seconds_per_tick)
	if(fading_channel)
		fading_level -= seconds_per_tick SECONDS / fading_time
		if(fading_level <= 0)
			silence(fading_channel)
			fading_channel = null
		else
			set_level(fading_channel, fading_level)
	if(pending && world.time >= pending_at)
		start_pending()
	if(current)
		if(current_level < 1)
			current_level = min(1, current_level + seconds_per_tick SECONDS / GATE_MUSIC_CROSSFADE)
			set_level(current_channel, current_level)
		if(mode == GATE_MUSIC_SITUATIONS)
			// The situation is over: the ambient comes back in once the track has played out.
			if(world.time >= started_at + current.length)
				fading_channel = null
				current = null
				if(!play_playlist(GATE_MUSIC_AMBIENT))
					mode = null
		// Short stingers play at least half through before the crossfade, or a playlist of them would skip every tick.
		else if(world.time >= started_at + max(current.length - GATE_MUSIC_CROSSFADE, current.length / 2))
			switch_to(next_track(), GATE_MUSIC_CROSSFADE, crossfade = TRUE)
	if(world.time >= next_sync)
		next_sync = world.time + GATE_MUSIC_SYNC_INTERVAL
		sync_listeners()
	if(!current && !pending && !fading_channel)
		sync_listeners()
		return PROCESS_KILL

/// Picks up clients who walked into the event locations and silences those who left them.
/datum/gate_closure_music/proc/sync_listeners()
	var/list/event_levels = SSgate_closure.event_levels
	for(var/client/player as anything in GLOB.clients)
		var/turf/location = get_turf(player.mob)
		var/should_hear = (current || fading_channel) && location && (location.z in event_levels) && player.prefs.read_preference(/datum/preference/numeric/volume/sound_midi)
		if(should_hear && !listeners[player.ckey])
			listeners[player.ckey] = TRUE
			if(current)
				send_current(player)
		else if(!should_hear && listeners[player.ckey])
			listeners -= player.ckey
			SEND_SOUND(player, sound(null, repeat = FALSE, wait = FALSE, channel = channel_a))
			SEND_SOUND(player, sound(null, repeat = FALSE, wait = FALSE, channel = channel_b))
	for(var/ckey in listeners)
		if(!GLOB.directory[ckey])
			listeners -= ckey

/datum/gate_closure_music/ui_state(mob/user)
	return ADMIN_STATE(R_SOUND)

/datum/gate_closure_music/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "GateClosureMusic")
		ui.open()

/datum/gate_closure_music/ui_static_data(mob/user)
	var/list/data = list()
	for(var/category in tracks)
		var/list/category_tracks = list()
		for(var/datum/gate_closure_track/track as anything in tracks[category])
			category_tracks += list(list("name" = track.name, "length" = round(track.length / 10)))
		data[category] = category_tracks
	data["folder"] = GATE_MUSIC_FOLDER
	data["unreadable"] = unreadable
	return data

/datum/gate_closure_music/ui_data(mob/user)
	var/datum/gate_closure_track/next = length(queue) ? queue[1] : null
	return list(
		"mode" = mode,
		"current" = current?.name,
		"elapsed" = current ? round((world.time - started_at) / 10) : 0,
		"length" = current ? round(current.length / 10) : 0,
		"switching" = !!(pending || fading_channel),
		"next" = (mode == GATE_MUSIC_AMBIENT || mode == GATE_MUSIC_COMBAT) ? next?.name : null,
		"volume" = volume,
		"listeners" = length(listeners),
	)

/datum/gate_closure_music/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("playlist")
			var/category = params["category"]
			if(category != GATE_MUSIC_AMBIENT && category != GATE_MUSIC_COMBAT)
				return
			return play_playlist(category)
		if("track")
			var/category = params["category"]
			var/index = params["index"]
			if(!(category in tracks) || !isnum(index) || index != round(index) || index < 1 || index > length(tracks[category]))
				return
			play_track(category, tracks[category][index])
			return TRUE
		if("stop")
			stop()
			return TRUE
		if("next")
			if(mode != GATE_MUSIC_AMBIENT && mode != GATE_MUSIC_COMBAT)
				return
			switch_to(next_track(), GATE_MUSIC_CROSSFADE, crossfade = TRUE)
			return TRUE
		if("shuffle")
			reshuffle()
			return TRUE
		if("volume")
			var/new_volume = params["volume"]
			if(!isnum(new_volume))
				return
			volume = clamp(round(new_volume), 0, 100)
			if(current)
				set_level(current_channel, current_level)
			return TRUE
		if("upload")
			var/category = params["category"]
			if(!(category in tracks))
				return
			var/datum/gate_closure_track/track = gate_closure_upload_track(usr, "[GATE_MUSIC_FOLDER][category]/", unreadable)
			if(track)
				tracks[category] += track
			update_static_data_for_all_viewers()
			return TRUE
		if("rescan")
			if(mode)
				to_chat(usr, span_warning("Сначала остановите музыку."), confidential = TRUE)
				return
			load_tracks()
			update_static_data_for_all_viewers()
			return TRUE

ADMIN_VERB(gate_closure_music, R_SOUND, "Gate Closure - Проигрыватель", "Музыка только для игроков на ивентовых локациях.", ADMIN_CATEGORY_EVENTS)
	var/datum/gate_closure_music/player = GLOB.gate_closure_music
	if(isnull(player.tracks))
		player.load_tracks()
	player.ui_interact(user.mob)

#undef GATE_MUSIC_FOLDER
#undef GATE_MUSIC_AMBIENT
#undef GATE_MUSIC_COMBAT
#undef GATE_MUSIC_SITUATIONS
#undef GATE_MUSIC_CROSSFADE
#undef GATE_MUSIC_SITUATION_FADE
#undef GATE_MUSIC_SYNC_INTERVAL
