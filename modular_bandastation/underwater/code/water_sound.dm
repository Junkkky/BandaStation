/// Attenuate water separately from air pressure; flooded rooms still retain their native atmosphere.
#define FLOOD_WATER_SOUND_GAIN 0.25

/** A living source can submerge its head while prone; other sources use the standing immersion level. */
/atom/proc/stationtrauma_sound_submerged()
	var/turf/open/tile = get_turf(src)
	if(!istype(tile))
		return FALSE
	var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
	return water && (isliving(src) ? water.head_underwater(src) : water.get_depth() >= FLOOD_WATER_SUBMERGED)

/** Native distance, pressure, preferences and channel handling remain in the parent player. */
/mob/living/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff_exponent = SOUND_FALLOFF_EXPONENT, channel = 0, pressure_affected = TRUE, sound/sound_to_use, max_distance, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, distance_multiplier = 1, use_reverb = TRUE, wait = FALSE, datum/preference/numeric/volume/volume_preference = null, min_volume = 5)
	if(!stationtrauma_sound_submerged() && !(pressure_affected && turf_source?.stationtrauma_sound_submerged()))
		return ..()
	sound_to_use ||= sound(get_sfx(soundin))
	// The native player sends synchronously; restore shared state without losing stream/loop/update fields.
	var/list/previous_echo = sound_to_use.echo
	var/previous_sound_environment = sound_to_use.environment
	var/previous_volume = sound_to_use.volume
	sound_to_use.echo = previous_echo ? previous_echo.Copy() : new /list(18)
	sound_to_use.echo[2] = min(sound_to_use.echo[2] || 0, -4000)
	vol *= FLOOD_WATER_SOUND_GAIN
	min_volume *= FLOOD_WATER_SOUND_GAIN
	var/previous_environment = sound_environment_override
	sound_environment_override = SOUND_ENVIRONMENT_UNDERWATER
	. = ..()
	sound_environment_override = previous_environment
	sound_to_use.echo = previous_echo
	sound_to_use.environment = previous_sound_environment
	sound_to_use.volume = previous_volume

/** Hear passes its live arguments; copy shared message modifiers before adding a listener-only effect. */
/datum/status_effect/floodwater/proc/muffle_water_speech(mob/living/source, list/hearing_args)
	SIGNAL_HANDLER
	var/datum/component/floodwater/water = current_water()
	// Self speech already uses playsound_local; radio follows its normal space-compatible path.
	if(hearing_args[HEARING_RADIO_FREQ] || hearing_args[HEARING_SPEAKER] == owner || !water?.head_underwater(owner))
		return
	var/list/message_mods = hearing_args[HEARING_MESSAGE_MODE]
	message_mods = message_mods ? message_mods.Copy() : list()
	var/list/effects = message_mods[MODE_TTS_FILTERS]
	effects = effects ? effects.Copy() : list()
	effects |= /datum/singleton/sound_effect/stationtrauma_underwater
	message_mods[MODE_TTS_FILTERS] = effects
	hearing_args[HEARING_MESSAGE_MODE] = message_mods

/// The existing cached sound-effect pipeline applies this only to a submerged listener's local speech.
/datum/singleton/sound_effect/stationtrauma_underwater
	suffix = "_stationtrauma_underwater"
	ffmpeg_arguments = "lowpass=f=700, volume=0.25"

#undef FLOOD_WATER_SOUND_GAIN
