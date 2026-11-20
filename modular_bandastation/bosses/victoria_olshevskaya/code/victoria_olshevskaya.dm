/// Invulnerable, player-controlled event character with four native 32x64 views.
/mob/living/basic/boss/victoria_olshevskaya
	name = "Виктория Ольшевская"
	// Speaks in the large bold type of a megaphone or a head of staff's loud headset.
	speech_span = SPAN_COMMAND
	desc = "За рваной фатой скрывается жуткое лицо, обрамлённое двумя тугими косами."
	gender = FEMALE
	icon = 'modular_bandastation/bosses/victoria_olshevskaya/icons/victoria_olshevskaya.dmi'
	icon_state = "idle"
	icon_living = "idle"
	icon_dead = "idle"
	maxHealth = 1000
	health = 1000
	ai_controller = null
	faction = list(FACTION_MINING, FACTION_BOSS, FACTION_HELL)

/mob/living/basic/boss/victoria_olshevskaya/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/event_boss, list())
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_step))

/// Footstep element skips flying mobs, and every boss flies; her bare feet must still be heard.
/mob/living/basic/boss/victoria_olshevskaya/proc/on_step(datum/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(forced || throwing || !isturf(loc))
		return
	var/static/list/barefoot = list(
		'sound/effects/footstep/hardbarefoot1.ogg',
		'sound/effects/footstep/hardbarefoot2.ogg',
		'sound/effects/footstep/hardbarefoot3.ogg',
		'sound/effects/footstep/hardbarefoot4.ogg',
		'sound/effects/footstep/hardbarefoot5.ogg',
	)
	playsound(src, pick(barefoot), 50, TRUE)
