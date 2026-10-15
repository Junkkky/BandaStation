/// Presentation belongs to the occupant; resting water never processes screen effects or sound loops.
/datum/status_effect/floodwater
	/// Only our named filters are removed from the last HUD controller we touched.
	var/atom/movable/plane_master_controller/water_planes
	/// Zero is dry/hidden, one is sealed equipment, two is unprotected vision.
	var/presentation_mode = 0
	/// Native repeating audio has one reserved channel and no server loop timer.
	var/ambience_channel
	var/client/ambience_client
	var/ambience_volume = 0
	/// Visor and MOD sealing events need no per-frame equipment checks.
	var/list/presentation_gear = list()
	COOLDOWN_DECLARE(swim_bubbles_cooldown)

/** Pressure flags reflect the actual EVA visor or MOD seal, not just the item's name. */
/mob/living/proc/has_stationtrauma_water_visor()
	if(!ishuman(src))
		return FALSE
	var/mob/living/carbon/human/swimmer = src
	var/obj/item/clothing/helmet = swimmer.head
	var/obj/item/clothing/suit = swimmer.wear_suit
	return istype(helmet) && istype(suit) && (helmet.body_parts_covered & HEAD) && (suit.body_parts_covered & CHEST) && (helmet.clothing_flags & STOPSPRESSUREDAMAGE) && (suit.clothing_flags & STOPSPRESSUREDAMAGE)

/** Equipment and HUD signals can arrive before the new slot/perspective has finished changing. */
/datum/status_effect/floodwater/proc/queue_presentation_refresh()
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(update_water)), 0, TIMER_UNIQUE|TIMER_OVERRIDE)

/** Watch only equipped pieces while the player is submerged; native MODs signal on the controller. */
/datum/status_effect/floodwater/proc/watch_presentation_gear()
	var/list/equipment = list()
	if(ishuman(owner))
		var/mob/living/carbon/human/swimmer = owner
		for(var/obj/item/item in list(swimmer.head, swimmer.wear_suit, swimmer.back))
			equipment += item
	for(var/obj/item/item in presentation_gear)
		if(!(item in equipment))
			UnregisterSignal(item, list(COMSIG_CLOTHING_VISOR_TOGGLE, COMSIG_MOD_PART_SEALED, COMSIG_QDELETING))
	for(var/obj/item/item as anything in equipment)
		if(!(item in presentation_gear))
			RegisterSignals(item, list(COMSIG_CLOTHING_VISOR_TOGGLE, COMSIG_MOD_PART_SEALED, COMSIG_QDELETING), PROC_REF(queue_presentation_refresh))
	presentation_gear = equipment

/** Preserve blindness, FOV and HUD readability by filtering only the native game render plates. */
/datum/status_effect/floodwater/proc/update_presentation(datum/component/floodwater/water)
	if(!owner.client || owner.stat == DEAD || !water?.head_underwater(owner))
		clear_presentation()
		return
	watch_presentation_gear()
	var/atom/movable/plane_master_controller/controller
	if(owner.client.eye == owner && !HAS_TRAIT(owner, TRAIT_SIGHT_BYPASS))
		controller = owner.hud_used?.plane_master_controllers[PLANE_MASTERS_GAME]
	set_water_filters(controller, owner.has_stationtrauma_water_visor() ? 1 : 2)
	update_water_ambience()

/** Reuse unchanged filters; their refraction animation runs entirely on the client. */
/datum/status_effect/floodwater/proc/set_water_filters(atom/movable/plane_master_controller/controller, mode)
	if(controller != water_planes)
		clear_water_filters()
		water_planes = controller
	if(water_planes && presentation_mode != mode)
		presentation_mode = mode
		var/red = mode == 1 ? 0.91 : 0.84
		water_planes.add_filter("floodwater_tint", 20, color_matrix_filter(list(red,0,0,0, 0,0.99,0,0, 0,0,1.03,0, 0,0,0,1, 0,0,0,0)))
		// Radial blur grows with distance from the view centre; the character and nearby tools stay readable.
		water_planes.add_filter("floodwater_blur", 21, radial_blur_filter(mode == 1 ? 0.008 : 0.028))
		water_planes.add_filter("floodwater_refraction", 22, wave_filter(x = 96, y = 64, size = mode == 1 ? 0.35 : 1.5, offset = 0))
		for(var/refraction as anything in water_planes.get_filters("floodwater_refraction"))
			animate(refraction, offset = 1, time = 10 SECONDS, loop = -1, flags = ANIMATION_PARALLEL)

/** Preferences and deafness are rechecked by the existing two-second occupant tick. */
/datum/status_effect/floodwater/proc/update_water_ambience()
	var/volume = HAS_TRAIT(owner, TRAIT_DEAF) ? 0 : 30 * owner.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ambience_volume) / 100
	if(volume <= 0 || ambience_client != owner.client)
		stop_water_ambience()
	if(volume <= 0)
		return
	if(!ambience_channel)
		ambience_channel = SSsounds.reserve_sound_channel()
		if(!ambience_channel)
			return
		ambience_client = owner.client
		ambience_volume = volume
		SEND_SOUND(ambience_client, sound('modular_bandastation/underwater/sound/underwater_ambience.ogg', repeat = TRUE, wait = FALSE, channel = ambience_channel, volume = volume))
	else if(ambience_volume != volume)
		ambience_volume = volume
		var/sound/update = sound(channel = ambience_channel, volume = volume)
		update.status = SOUND_UPDATE
		SEND_SOUND(ambience_client, update)

/** A private channel never replaces area ambience, music or another actor's sound. */
/datum/status_effect/floodwater/proc/stop_water_ambience()
	if(ambience_channel)
		if(ambience_client)
			SEND_SOUND(ambience_client, sound(channel = ambience_channel))
		SSsounds.free_sound_channel(ambience_channel)
	ambience_channel = null
	ambience_client = null
	ambience_volume = 0

/datum/status_effect/floodwater/proc/clear_water_filters()
	if(!QDELETED(water_planes))
		water_planes.remove_filter(list("floodwater_tint", "floodwater_blur", "floodwater_refraction"))
	water_planes = null
	presentation_mode = 0

/** Leaving water, logout, death and status removal share idempotent cleanup. */
/datum/status_effect/floodwater/proc/clear_presentation()
	SIGNAL_HANDLER
	clear_water_filters()
	stop_water_ambience()
	for(var/obj/item/item in presentation_gear)
		UnregisterSignal(item, list(COMSIG_CLOTHING_VISOR_TOGGLE, COMSIG_MOD_PART_SEALED, COMSIG_QDELETING))
	presentation_gear.Cut()

/** A small native animation stays behind a successful stroke or coast, never a stationary swimmer. */
/datum/status_effect/floodwater/proc/show_swim_bubbles(turf/open/old_tile, direction)
	if(!isopenturf(old_tile) || old_tile.get_water_depth() < FLOOD_WATER_DEEP || !COOLDOWN_FINISHED(src, swim_bubbles_cooldown) || SSfloodwater.water_visual_count >= FLOOD_WATER_VISUAL_LIMIT / 2)
		return
	COOLDOWN_START(src, swim_bubbles_cooldown, 0.3 SECONDS)
	new /obj/effect/temp_visual/stationtrauma_water/swim_bubbles(old_tile, (direction & NORTH) ? NORTH : (direction & SOUTH) ? SOUTH : direction)

/// Reuse the existing bubble sprite; finite lifetime and the shared cap bound cosmetic work.
/obj/effect/temp_visual/stationtrauma_water/swim_bubbles
	icon_state = "bubbles"
	duration = 0.65 SECONDS
	alpha = 160

/obj/effect/temp_visual/stationtrauma_water/swim_bubbles/Initialize(mapload, direction)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	pixel_x = rand(-4, 4)
	pixel_y = rand(-3, 3)
	transform = matrix().Scale(0.65)
	flick(icon_state, src)
	animate(src, pixel_y = pixel_y + 8, pixel_x = pixel_x + rand(-3, 3), alpha = 0, time = duration)
