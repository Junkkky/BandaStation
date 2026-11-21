#define TTS_VOICE_FILTER_MAX_LENGTH 256
#define TTS_VOICE_FILTER_MAX_STAGES 6

/// Applies a configurable audio filter to the owner's TTS speech.
/datum/action/cooldown/mob_cooldown/voice_filter
	name = "Фильтр голоса"
	desc = "ЛКМ включает или выключает фильтр TTS.<br>ПКМ открывает настройки FFmpeg."
	button_icon = 'modular_bandastation/tts/icons/voice_filter.dmi'
	button_icon_state = "voice_filter_off"
	check_flags = NONE
	cooldown_time = 0
	text_cooldown = FALSE
	click_to_activate = FALSE
	shared_cooldown = NONE

	/// Validated graph to apply before the standard TTS effects.
	VAR_PRIVATE/filter_arguments = "highpass=f=500,lowpass=f=3500"
	/// Whether this action currently adds its filter to outgoing speech.
	VAR_PRIVATE/filter_enabled = FALSE
	/// Identifies the open input and invalidates it if the action is removed.
	VAR_PRIVATE/list/configuration_prompt
	/// Routes a secondary click through the cooldown action's activation checks.
	VAR_PRIVATE/configure_on_activate = FALSE

/datum/action/cooldown/mob_cooldown/voice_filter/Trigger(mob/clicker, trigger_flags, atom/target)
	if(clicker && clicker != owner)
		return FALSE

	var/previous_configure_on_activate = configure_on_activate
	configure_on_activate = !!(trigger_flags & TRIGGER_SECONDARY_ACTION)
	. = ..()
	configure_on_activate = previous_configure_on_activate

/datum/action/cooldown/mob_cooldown/voice_filter/Activate(atom/target)
	if(QDELETED(owner) || target != owner)
		return FALSE

	if(configure_on_activate)
		INVOKE_ASYNC(src, PROC_REF(configure_filter), owner)
		return TRUE

	filter_enabled = !filter_enabled
	if(filter_enabled)
		RegisterSignal(owner, COMSIG_TTS_COMPONENT_PRE_CAST_TTS, PROC_REF(add_voice_filter))
	else
		UnregisterSignal(owner, COMSIG_TTS_COMPONENT_PRE_CAST_TTS)

	button_icon_state = filter_enabled ? "voice_filter_on" : "voice_filter_off"
	build_all_button_icons(UPDATE_BUTTON_ICON)
	return TRUE

/datum/action/cooldown/mob_cooldown/voice_filter/Remove(mob/removed_from)
	UnregisterSignal(removed_from, COMSIG_TTS_COMPONENT_PRE_CAST_TTS)
	filter_enabled = FALSE
	button_icon_state = initial(button_icon_state)
	configuration_prompt = null
	return ..()

/datum/action/cooldown/mob_cooldown/voice_filter/proc/add_voice_filter(datum/source, list/tts_args)
	SIGNAL_HANDLER

	tts_args[TTS_CAST_VOICE_FILTER] = filter_arguments

/datum/action/cooldown/mob_cooldown/voice_filter/proc/configure_filter(mob/user)
	var/client/editor = user.client
	if(configuration_prompt || !editor)
		return FALSE

	var/list/prompt = list()
	configuration_prompt = prompt
	var/input = tgui_input_text(
		user,
		"Введите цепочку фильтров через запятую, например highpass=f=500, lowpass=f=3500, acrusher=bits=8:mix=0.7. Доступны highpass, lowpass, equalizer, volume, atempo, acrusher, tremolo и vibrato.",
		name,
		default = filter_arguments,
		max_length = TTS_VOICE_FILTER_MAX_LENGTH,
		encode = FALSE,
		timeout = 1 MINUTES,
	)
	if(QDELETED(src) || configuration_prompt != prompt)
		return FALSE

	configuration_prompt = null
	if(isnull(input) || QDELETED(user) || user != owner || user.client != editor || !IsAvailable())
		return FALSE

	var/normalized_filter = normalize_tts_voice_filter(input)
	if(!normalized_filter)
		to_chat(user, span_warning("Не удалось сохранить фильтр. Проверьте названия фильтров и числовые параметры."))
		return FALSE

	filter_arguments = normalized_filter
	to_chat(user, span_notice("Настройки фильтра голоса сохранены."))
	return TRUE

/// Builds an audio-only FFmpeg graph using supported filters and bounded numeric options.
/proc/normalize_tts_voice_filter(input)
	if(!istext(input) || !length(input) || length(input) > TTS_VOICE_FILTER_MAX_LENGTH)
		return null

	// The first option in each list is the positional shorthand for this action.
	var/static/list/supported_filters = list(
		"highpass" = list("f" = list(20, 10000)),
		"lowpass" = list("f" = list(20, 10000)),
		"equalizer" = list("f" = list(20, 10000), "g" = list(-20, 10), "w" = list(0.1, 10)),
		"volume" = list("volume" = list(0, 2)),
		"atempo" = list("tempo" = list(0.5, 2)),
		"acrusher" = list("bits" = list(2, 16), "mix" = list(0, 1)),
		"tremolo" = list("f" = list(0.1, 20), "d" = list(0, 1)),
		"vibrato" = list("f" = list(0.1, 10), "d" = list(0, 1)),
	)
	var/static/regex/number_option = new(@"-?[0-9]{1,5}(?:\.[0-9]{1,3})?")
	var/list/stages = splittext(LOWER_TEXT(input), ",")
	if(length(stages) > TTS_VOICE_FILTER_MAX_STAGES)
		return null

	var/list/normalized_stages = list()
	var/has_tempo = FALSE
	for(var/stage as anything in stages)
		var/assignment = findtext(stage, "=")
		if(!assignment)
			return null
		var/filter_name = trim(copytext(stage, 1, assignment))
		var/list/allowed_options = supported_filters[filter_name]
		if(!allowed_options || (filter_name == "atempo" && has_tempo))
			return null
		if(filter_name == "atempo")
			has_tempo = TRUE

		var/list/seen_options = list()
		var/list/normalized_options = list()
		for(var/option as anything in splittext(copytext(stage, assignment + 1), ":"))
			var/option_assignment = findtext(option, "=")
			var/option_name = option_assignment ? trim(copytext(option, 1, option_assignment)) : allowed_options[1]
			var/list/bounds = allowed_options[option_name]
			var/value = trim(copytext(option, option_assignment + 1))
			if(!number_option.Find(value) || number_option.match != value)
				return null

			var/numeric_value = text2num(value)
			if(!bounds || (option_name in seen_options) || numeric_value < bounds[1] || numeric_value > bounds[2])
				return null

			seen_options += option_name
			normalized_options += "[option_name]=[value]"

		normalized_stages += "[filter_name]=[normalized_options.Join(":")]"

	return normalized_stages.Join(",")

#undef TTS_VOICE_FILTER_MAX_LENGTH
#undef TTS_VOICE_FILTER_MAX_STAGES
