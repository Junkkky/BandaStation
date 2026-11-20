/// Invulnerable, player-controlled event character using the approved four-view design.
/mob/living/basic/boss/heinrich_traizen
	name = "Генрих Трейзен III"
	// Speaks in the large bold type of a megaphone or a head of staff's loud headset.
	speech_span = SPAN_COMMAND
	desc = "Грузная фигура в изодранной парадной мантии с золотыми эполетами. Лицо скрыто промышленным противогазом."
	gender = MALE
	icon = 'modular_bandastation/bosses/heinrich_traizen/icons/heinrich_traizen.dmi'
	icon_state = "idle"
	icon_living = "idle"
	icon_dead = "idle"
	pixel_x = -32
	base_pixel_x = -32
	maxHealth = 1000
	health = 1000
	ai_controller = null
	faction = list(FACTION_MINING, FACTION_BOSS, FACTION_HELL)

/mob/living/basic/boss/heinrich_traizen/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/event_boss, list())
