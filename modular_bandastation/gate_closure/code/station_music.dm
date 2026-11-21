#define STATION_MUSIC_FOLDER "modular_bandastation/gate_closure/sound/station/"

GLOBAL_DATUM_INIT(gate_closure_station_music, /datum/gate_closure_station_music, new)

/**
 * A plain player for the station part of the event: one list of tracks, heard only by clients on station levels.
 * Without autoplay a finished track is followed by silence.
 */
/datum/gate_closure_station_music
	/// Tracks read from [STATION_MUSIC_FOLDER], in name order.
	var/list/datum/gate_closure_track/tracks
	/// Files whose length could not be read; they are left out.
	var/list/unreadable = list()
	var/datum/gate_closure_track/current
	/// Position of the current track in `tracks`.
	var/current_index = 0
	/// When the current track would have started had it never been paused.
	var/started_at = 0
	/// When it was paused; 0 while it plays.
	var/paused_at = 0
	/// Whether a finished track is followed by the next one in the list.
	var/autoplay = FALSE
	/// Master volume, 0..100, scaled by each player's admin music volume.
	var/volume = 60
	/// ckey -> TRUE for every client currently hearing the player.
	var/list/listeners = list()
	var/channel

/datum/gate_closure_station_music/proc/load_tracks()
	unreadable.Cut()
	tracks = gate_closure_read_tracks(STATION_MUSIC_FOLDER, unreadable)

/datum/gate_closure_station_music/proc/play(index)
	if(!channel)
		channel = SSsounds.reserve_sound_channel_for_datum(src)
	current = tracks[index]
	current_index = index
	started_at = world.time
	paused_at = 0
	log_admin("Gate closure station music: [current.name].")
	for(var/ckey in listeners)
		var/client/listener = GLOB.directory[ckey]
		if(listener)
			send_current(listener)
	sync_listeners()
	START_PROCESSING(SSprocessing, src)

/datum/gate_closure_station_music/proc/toggle_pause()
	if(!current)
		return
	if(paused_at)
		started_at += world.time - paused_at
		paused_at = 0
	else
		paused_at = world.time
	for(var/ckey in listeners)
		var/client/listener = GLOB.directory[ckey]
		if(listener)
			update_listener(listener)

/datum/gate_closure_station_music/proc/stop()
	current = null
	current_index = 0
	paused_at = 0
	sync_listeners()

/datum/gate_closure_station_music/proc/elapsed()
	return (paused_at || world.time) - started_at

/// Starts the current track for one client from where it is now, paused if the player is paused.
/datum/gate_closure_station_music/proc/send_current(client/listener)
	var/sound/music = sound(current.file, repeat = FALSE, wait = FALSE, channel = channel)
	music.volume = listener_volume(listener)
	music.offset = elapsed() / 10
	if(paused_at)
		music.status = SOUND_PAUSED
	SEND_SOUND(listener, music)

/// Applies the volume and the pause state to a client already hearing the track.
/datum/gate_closure_station_music/proc/update_listener(client/listener)
	var/sound/update = sound(null, repeat = FALSE, wait = FALSE, channel = channel, volume = listener_volume(listener))
	update.status = SOUND_UPDATE | (paused_at ? SOUND_PAUSED : NONE)
	SEND_SOUND(listener, update)

/datum/gate_closure_station_music/proc/listener_volume(client/listener)
	return volume * listener.prefs.read_preference(/datum/preference/numeric/volume/sound_midi) / 100

/datum/gate_closure_station_music/process(seconds_per_tick)
	if(current && !paused_at && elapsed() >= current.length)
		if(autoplay && length(tracks))
			play(current_index % length(tracks) + 1)
		else
			stop()
	sync_listeners()
	if(!current)
		return PROCESS_KILL

/// Picks up clients who came onto the station and silences those who left it.
/datum/gate_closure_station_music/proc/sync_listeners()
	for(var/client/player as anything in GLOB.clients)
		var/turf/location = get_turf(player.mob)
		var/should_hear = current && location && is_station_level(location.z) && player.prefs.read_preference(/datum/preference/numeric/volume/sound_midi)
		if(should_hear && !listeners[player.ckey])
			listeners[player.ckey] = TRUE
			send_current(player)
		else if(!should_hear && listeners[player.ckey])
			listeners -= player.ckey
			SEND_SOUND(player, sound(null, repeat = FALSE, wait = FALSE, channel = channel))
	for(var/ckey in listeners)
		if(!GLOB.directory[ckey])
			listeners -= ckey

/datum/gate_closure_station_music/ui_state(mob/user)
	return ADMIN_STATE(R_SOUND)

/datum/gate_closure_station_music/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "GateClosureStationMusic")
		ui.open()

/datum/gate_closure_station_music/ui_static_data(mob/user)
	var/list/track_data = list()
	for(var/datum/gate_closure_track/track as anything in tracks)
		track_data += list(list("name" = track.name, "length" = round(track.length / 10)))
	return list(
		"tracks" = track_data,
		"folder" = STATION_MUSIC_FOLDER,
		"unreadable" = unreadable,
	)

/datum/gate_closure_station_music/ui_data(mob/user)
	return list(
		"current" = current?.name,
		"index" = current_index,
		"elapsed" = current ? round(elapsed() / 10) : 0,
		"length" = current ? round(current.length / 10) : 0,
		"paused" = !!paused_at,
		"autoplay" = autoplay,
		"volume" = volume,
		"listeners" = length(listeners),
	)

/datum/gate_closure_station_music/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("play")
			var/index = params["index"]
			if(!isnum(index) || index != round(index) || index < 1 || index > length(tracks))
				return
			play(index)
			return TRUE
		if("step")
			var/direction = params["direction"]
			if((direction != 1 && direction != -1) || !length(tracks))
				return
			if(!current_index)
				play(direction > 0 ? 1 : length(tracks))
			else
				play((current_index - 1 + direction + length(tracks)) % length(tracks) + 1)
			return TRUE
		if("pause")
			toggle_pause()
			return TRUE
		if("stop")
			stop()
			return TRUE
		if("autoplay")
			autoplay = !autoplay
			return TRUE
		if("volume")
			var/new_volume = params["volume"]
			if(!isnum(new_volume))
				return
			volume = clamp(round(new_volume), 0, 100)
			for(var/ckey in listeners)
				var/client/listener = GLOB.directory[ckey]
				if(listener)
					update_listener(listener)
			return TRUE
		if("upload")
			var/datum/gate_closure_track/track = gate_closure_upload_track(usr, STATION_MUSIC_FOLDER, unreadable)
			if(track)
				tracks += track
			update_static_data_for_all_viewers()
			return TRUE
		if("rescan")
			if(current)
				to_chat(usr, span_warning("Сначала остановите звук."), confidential = TRUE)
				return
			load_tracks()
			update_static_data_for_all_viewers()
			return TRUE

ADMIN_VERB(gate_closure_station_music, R_SOUND, "Gate Closure - Звуки станции", "Проигрыватель только для игроков на станции.", ADMIN_CATEGORY_EVENTS)
	var/datum/gate_closure_station_music/player = GLOB.gate_closure_station_music
	if(isnull(player.tracks))
		player.load_tracks()
	player.ui_interact(user.mob)

#undef STATION_MUSIC_FOLDER
