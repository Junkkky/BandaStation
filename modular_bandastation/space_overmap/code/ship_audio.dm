// AI EDIT START - space overmap module integration
/** Native engine sound loop with launch, running and shutdown clips. */
/datum/looping_sound/stationtrauma_ship_engine
	start_sound = 'modular_bandastation/space_overmap/sound/ship_engine_starts.ogg'
	mid_sounds = 'modular_bandastation/space_overmap/sound/ship_engine_processing.ogg'
	end_sound = 'modular_bandastation/space_overmap/sound/ship_engine_stops.ogg'
	start_volume = 35
	end_volume = 30
	volume = 10
	use_sound_tokens = TRUE
	falloff_exponent = SOUND_FALLOFF_EXPONENT
	falloff_distance = 5

/datum/looping_sound/stationtrauma_ship_engine/New(obj/docking_port/mobile/stationtrauma_space/ship)
	start_length = SSsounds.get_sound_length(start_sound)
	extra_range = max(ship.width, ship.height)
	return ..(ship)

/datum/looping_sound/stationtrauma_ship_engine/on_stop()
	// Stopping during the startup clip must also play the shutdown sound.
	if(!loop_started && end_sound)
		play(end_sound, end_volume, delete_when_finished = TRUE)
	return ..()

/** The native token tracks movement/login/logout; interior ambience is non-positional and hull-only. */
/datum/sound_token/stationtrauma_ship_interior/update_listener(mob/listener_mob, update_sound = TRUE)
	if(QDELETED(src) || isnull(listeners[listener_mob]))
		return
	var/obj/docking_port/mobile/stationtrauma_space/ship = source
	var/was_muted = listeners[listener_mob] & SOUND_MUTE
	if(!listener_mob.client || isobserver(listener_mob) || HAS_TRAIT(listener_mob, TRAIT_DEAF) || !ship.shuttle_areas[get_area(listener_mob)] || !ship.is_in_shuttle_bounds(listener_mob) || !listener_mob.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume))
		set_listener_status(listener_mob, SOUND_MUTE)
		if(!was_muted)
			SEND_SOUND(listener_mob, null_sound)
		return
	set_listener_status(listener_mob, NONE)
	sound.status = sound_status | (update_sound && !was_muted ? SOUND_UPDATE : NONE)
	if(!(sound.status & SOUND_UPDATE))
		sound.offset = calculate_offset()
	listener_mob.playsound_local(get_turf(listener_mob), vol = volume, channel = sound_channel, sound_to_use = sound, pressure_affected = FALSE, use_reverb = FALSE, volume_preference = /datum/preference/numeric/volume/sound_ship_ambience_volume)
	sound.offset = null

/area/shuttle/stationtrauma_space/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(ismob(arrived))
		var/mob/crew = arrived
		crew.stop_sound_channel(CHANNEL_AMBIENCE)

/datum/stationtrauma_overmap/space
	/// Owned engine loop updated from engine state and docking status.
	var/datum/looping_sound/stationtrauma_ship_engine/engine_audio
	/// Owned ambience token restricted to listeners inside the physical hull.
	var/datum/sound_token/stationtrauma_ship_interior/interior_audio

/** Create the hull-owned ambience and engine audio resources. */
/datum/stationtrauma_overmap/space/proc/initialize_ship_audio()
	engine_audio = new(vessel)
	interior_audio = new(vessel, 'modular_bandastation/space_overmap/sound/ship_interior_ambience.ogg', radius * 2 + 2, 22, _repeating = TRUE)
	refresh_engine_audio()

/** Switch main propulsion without erasing drift. */
/datum/stationtrauma_overmap/space/proc/set_engines_running(enabled)
	if(!(enabled in list(FALSE, TRUE)) || !is_operational() || preparing || relocating || (enabled && engine_fraction() <= 0))
		return FALSE
	if(vessel.engines_running == enabled)
		return TRUE
	vessel.engines_running = enabled
	if(!enabled)
		command_course(ordered_course)
		throttle = 0
		braking = FALSE
		maneuver_direction = NONE
		helm_engaged = speed > 0.05
	refresh_engine_audio()
	return TRUE

/** Start or stop propulsion audio and select its docked or cruising volume. */
/datum/stationtrauma_overmap/space/proc/refresh_engine_audio()
	if(!engine_audio)
		return
	if(!vessel.engines_running || engine_fraction() <= 0)
		engine_audio.stop()
		return
	var/new_volume = docked || speed <= 0.05 ? 10 : 25
	if(engine_audio.volume != new_volume)
		engine_audio.volume = new_volume
		if(engine_audio.native_repeat_active)
			engine_audio.sound_token_instance?.set_volume(new_volume)
	engine_audio.start()

/** A remote seam also has listeners on the destination level; physical docking needs only one emission. */
/datum/stationtrauma_overmap/space/proc/play_maneuver_audio(atom/remote, departing = FALSE)
	var/clip = departing ? 'modular_bandastation/space_overmap/sound/ship_engine_starts.ogg' : 'modular_bandastation/space_overmap/sound/ship_landing.ogg'
	if(departing && engine_audio)
		// Restart the launch sequence without emitting a shutdown clip or cutting propulsion.
		var/end_clip = engine_audio.end_sound
		engine_audio.end_sound = null
		engine_audio.stop()
		engine_audio.end_sound = end_clip
		engine_audio.start()
	else
		playsound(vessel, clip, 25, FALSE, extrarange = radius, pressure_affected = FALSE)
	if(!QDELETED(remote) && remote.z != vessel.z)
		playsound(remote, clip, 12, FALSE, extrarange = radius, pressure_affected = FALSE)
// AI EDIT END
