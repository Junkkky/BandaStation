/// Deep demonic double without the former distortion, bit crushing or raspy modulation.
/datum/singleton/sound_effect/event_growl
	suffix = "_event_growl_v3"
	ffmpeg_arguments = "aresample=48000,asetrate=24960,aresample=48000,atempo=1.92307692,highpass=f=45,equalizer=f=110:t=q:w=1:g=4,lowpass=f=2600,alimiter=limit=0.85:level=0"

/// Keep intelligible lowered speech above a separate, quieter demonic voice.
/datum/singleton/sound_effect/event_dual_voice
	suffix = "_event_dual_voice_v1"

/datum/singleton/sound_effect/event_dual_voice/Initialize()
	. = ..()
	var/datum/singleton/sound_effect/growl = GLOB.Singletons.GetInstance(/datum/singleton/sound_effect/event_growl)
	suffix += growl.suffix
	ffmpeg_arguments = "asplit=2\[low_voice\]\[low_demon\];\[low_voice\]aresample=48000,asetrate=39360,aresample=48000,atempo=1.21951220,highpass=f=65,lowpass=f=6500\[low_main\];\[low_demon\][growl.ffmpeg_arguments],adelay=25:all=1\[low_double\];\[low_main\]\[low_double\]amix=inputs=2:duration=longest:weights='1 0.6':normalize=0,alimiter=limit=0.85:level=0"

/// The clown adds a quieter, lowered creaking voice with uneven pitch modulation.
/datum/singleton/sound_effect/event_clown_voice
	suffix = "_event_clown_voice_v1"

/datum/singleton/sound_effect/event_clown_voice/Initialize()
	. = ..()
	var/datum/singleton/sound_effect/dual = GLOB.Singletons.GetInstance(/datum/singleton/sound_effect/event_dual_voice)
	suffix += dual.suffix
	ffmpeg_arguments = "asplit=2\[clown_low\]\[clown_creak\];\[clown_low\][dual.ffmpeg_arguments]\[clown_body\];\[clown_creak\]aresample=48000,asetrate=33600,aresample=48000,atempo=1.42857143,vibrato=f=4.7:d=0.8,vibrato=f=1.3:d=0.5,highpass=f=220,acrusher=bits=10:mix=0.12:mode=log:aa=1,lowpass=f=2400,adelay=40:all=1\[clown_scratch\];\[clown_body\]\[clown_scratch\]amix=inputs=2:duration=longest:weights='1 0.3':normalize=0,alimiter=limit=0.85:level=0"

/// Three modulated voice doubles with a fading reverberant tail.
/datum/singleton/sound_effect/event_choir
	suffix = "_event_choir_v1"
	ffmpeg_arguments = "highpass=f=80,chorus=0.6:0.75:22|37|53:0.45|0.35|0.3:0.31|0.43|0.37:1.7|2.3|3.1,aecho=0.8:0.5:90|170|310|530|830:0.3|0.25|0.2|0.13|0.08,volume=1.5,alimiter=limit=0.85:level=0"

/// Pinhead's reverberant voice stays clear above a quieter, delayed demonic double.
/datum/singleton/sound_effect/event_pinhead
	suffix = "_event_pinhead_dual_v1"

/datum/singleton/sound_effect/event_pinhead/Initialize()
	. = ..()
	var/datum/singleton/sound_effect/choir = GLOB.Singletons.GetInstance(/datum/singleton/sound_effect/event_choir)
	var/datum/singleton/sound_effect/growl = GLOB.Singletons.GetInstance(/datum/singleton/sound_effect/event_growl)
	suffix += "[choir.suffix][growl.suffix]"
	ffmpeg_arguments = "asplit=2\[pinhead_voice\]\[pinhead_demon\];\[pinhead_voice\][choir.ffmpeg_arguments]\[pinhead_main\];\[pinhead_demon\][growl.ffmpeg_arguments],volume=2,adelay=65:all=1,aecho=0.8:0.5:110|230|390:0.3|0.2|0.1\[pinhead_echo\];\[pinhead_main\]\[pinhead_echo\]amix=inputs=2:duration=longest:weights='1 0.35':normalize=0,alimiter=limit=0.85:level=0"

/mob/living/basic/boss/heinrich_traizen/add_tts_component()
	AddComponent(/datum/component/tts_component, null, list(/datum/singleton/sound_effect/event_dual_voice))

/mob/living/basic/boss/crooked_man/add_tts_component()
	AddComponent(/datum/component/tts_component, null, list(/datum/singleton/sound_effect/event_dual_voice))

/mob/living/basic/boss/gatekeeper/add_tts_component()
	AddComponent(/datum/component/tts_component, null, list(/datum/singleton/sound_effect/event_pinhead))

/mob/living/basic/boss/victoria_olshevskaya/add_tts_component()
	AddComponent(/datum/component/tts_component, null, list(/datum/singleton/sound_effect/event_choir))

/// Add the spider's optional filter at cast time so copied voices keep the same toggle.
/mob/living/basic/boss/spider_clown/proc/filter_tts(datum/source, list/tts_args)
	SIGNAL_HANDLER
	if(growl_enabled)
		tts_args[TTS_CAST_EFFECTS] |= /datum/singleton/sound_effect/event_clown_voice

/// The same switch is granted to the spider and to its replaceable human body.
/datum/action/cooldown/spider_voice_filter
	name = "Голос: гроул"
	desc = "Включить или выключить многослойный демонический голос со скрипучим призвуком. Настройка сохраняется при смене формы и голоса."
	button_icon = 'icons/mob/actions/actions_ai.dmi'
	button_icon_state = "voice_changer"
	cooldown_time = 0

/datum/action/cooldown/spider_voice_filter/Activate(atom/target)
	var/mob/living/basic/boss/spider_clown/spider = get_spider_clown(owner)
	if(!spider)
		return FALSE
	spider.growl_enabled = !spider.growl_enabled
	to_chat(owner, span_notice("Фильтр гроула [spider.growl_enabled ? "включён" : "выключен"]."))
	return TRUE
