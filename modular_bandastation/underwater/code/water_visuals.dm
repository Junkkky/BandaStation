/datum/controller/subsystem/floodwater
	/// A hard cap on short-lived water effects, independent of room size or hydraulic microsteps.
	var/water_visual_count = 0

/datum/floodwater_front_cell
	/// Separate from physical impulses; missing a cosmetic slot never suppresses a transfer or push.
	COOLDOWN_DECLARE(water_visual_cooldown)
	/// Confirmed strong transfers renew one looping visual instead of restarting its animation.
	var/obj/effect/temp_visual/stationtrauma_water/stream/stream_visual

/datum/floodwater_front_cell/Destroy()
	QDEL_NULL(stream_visual)
	return ..()

/datum/component/floodwater_leak
	/// At most one current marker per damaged barrier; repair/rebuild removes it immediately.
	var/obj/effect/temp_visual/stationtrauma_water/leak/leak_visual
	/// Accepted inlet events are frequent; animated frames themselves run on the client.
	COOLDOWN_DECLARE(leak_visual_cooldown)

/** Mild flow remains a brief cue; confirmed strong flow retains one native looping animation. */
/datum/controller/subsystem/floodwater/proc/show_flow_visual(datum/floodwater_front_cell/contact, turf/open/from_tile, turf/open/tile, direction, burst, continuous = FALSE)
	if(!continuous)
		QDEL_NULL(contact.stream_visual)
	if(!burst && !contact.stream_visual && !COOLDOWN_FINISHED(contact, water_visual_cooldown))
		return
	if(!from_tile.can_pass_stationtrauma_water(tile))
		QDEL_NULL(contact.stream_visual)
		return
	if(!contact.stream_visual && water_visual_count >= FLOOD_WATER_VISUAL_LIMIT)
		return
	var/previous_phase = debug.phase_name
	if(debug.enabled)
		debug.measure_phase("Visuals")
	if(burst && water_visual_count < FLOOD_WATER_VISUAL_LIMIT)
		new /obj/effect/temp_visual/stationtrauma_water/burst(tile, direction)
	if(contact.stream_visual && (contact.stream_visual.loc != tile || contact.stream_visual.dir != direction))
		QDEL_NULL(contact.stream_visual)
	if(contact.stream_visual)
		contact.stream_visual.renew()
	else if(water_visual_count < FLOOD_WATER_VISUAL_LIMIT)
		COOLDOWN_START(contact, water_visual_cooldown, FLOOD_WATER_VISUAL_INTERVAL)
		if(continuous)
			contact.stream_visual = new(tile, direction, contact)
		else
			new /obj/effect/temp_visual/stationtrauma_water/stream(tile, direction)
	if(debug.enabled)
		debug.measure_phase(previous_phase)

/** Mark the leaking face, not the whole room; a parked inlet produces no new visuals. */
/datum/component/floodwater_leak/proc/show_leak_visual(turf/open/outside, turf/open/intake)
	if(!COOLDOWN_FINISHED(src, leak_visual_cooldown))
		return
	COOLDOWN_START(src, leak_visual_cooldown, FLOOD_WATER_VISUAL_INTERVAL)
	if(SSfloodwater.water_visual_count >= FLOOD_WATER_VISUAL_LIMIT)
		return
	var/previous_phase = SSfloodwater.debug.phase_name
	if(SSfloodwater.debug.enabled)
		SSfloodwater.debug.measure_phase("Visuals")
	QDEL_NULL(leak_visual)
	var/turf/location = get_turf(parent)
	leak_visual = new(location, get_dir(outside, intake), src, intake == location, leak_severity())
	if(SSfloodwater.debug.enabled)
		SSfloodwater.debug.measure_phase(previous_phase)

/** Native temporary visuals stay click-through, ignore immersion, and use existing sprite animations. */
/obj/effect/temp_visual/stationtrauma_water
	randomdir = FALSE
	duration = FLOOD_WATER_VISUAL_DURATION
	layer = BELOW_MOB_LAYER
	color = "#b8d6df"
	/// Count against the creating controller, even if the global subsystem is later recovered.
	var/datum/controller/subsystem/floodwater/visual_controller

/obj/effect/temp_visual/stationtrauma_water/Initialize(mapload, direction)
	. = ..()
	if(!isturf(loc) || !(direction in GLOB.cardinals) || SSfloodwater.water_visual_count >= FLOOD_WATER_VISUAL_LIMIT)
		return INITIALIZE_HINT_QDEL
	visual_controller = SSfloodwater
	visual_controller.water_visual_count++
	setDir(direction)
	plane = MUTATE_PLANE(GAME_PLANE, loc)

/obj/effect/temp_visual/stationtrauma_water/Destroy()
	if(!QDELETED(visual_controller))
		visual_controller.water_visual_count--
	visual_controller = null
	return ..()

/** A short ring marks the start of the breach; it is not a water-depth overlay. */
/obj/effect/temp_visual/stationtrauma_water/burst
	icon_state = "splash_floor"
	alpha = 160

/obj/effect/temp_visual/stationtrauma_water/burst/Initialize(mapload, direction)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	flick(icon_state, src)
	transform = matrix().Scale(0.8)
	animate(src, time = duration / 2)
	animate(alpha = 0, time = duration / 2)

/** A two-tile animated jet starts at the inlet; a closed next tile clips it to one tile. */
/obj/effect/temp_visual/stationtrauma_water/stream
	icon = 'modular_bandastation/underwater/icons/water_jet.dmi'
	icon_state = "jet"
	color = null
	alpha = 180
	/// Only strong-flow visuals belong to a contact; mild pulses still use the native expiry/fade.
	var/datum/floodwater_front_cell/flow_contact
	/// One native repeating sound shares the strong jet's lifetime and cosmetic cap.
	var/datum/sound_token/flow_sound

/obj/effect/temp_visual/stationtrauma_water/stream/Initialize(mapload, direction, datum/floodwater_front_cell/flow_contact)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	src.flow_contact = flow_contact
	if(flow_contact)
		flow_sound = new(src, 'modular_bandastation/underwater/sound/breach_flow.ogg', 7, 65, _repeating = TRUE)
	var/turf/open/tile = loc
	if(!tile.can_pass_stationtrauma_water(get_step(tile, direction)))
		icon_state = "jet_short"
	pixel_x = (direction & EAST) ? 0 : ((direction & WEST) ? -32 : -16)
	pixel_y = (direction & NORTH) ? 0 : ((direction & SOUTH) ? -32 : -16)
	if(!flow_contact)
		animate(src, time = duration * 0.75)
		animate(alpha = 0, time = duration * 0.25)

/** Refresh the timeout, not the icon clock; one stoppable timer bounds cleanup after the last event. */
/obj/effect/temp_visual/stationtrauma_water/stream/proc/renew()
	deltimer(timerid)
	timerid = QDEL_IN_STOPPABLE(src, duration)
	var/turf/open/tile = loc
	var/state = tile.can_pass_stationtrauma_water(get_step(tile, dir)) ? "jet" : "jet_short"
	if(icon_state != state)
		icon_state = state

/obj/effect/temp_visual/stationtrauma_water/stream/Destroy()
	QDEL_NULL(flow_sound)
	if(!QDELETED(flow_contact) && flow_contact.stream_visual == src)
		flow_contact.stream_visual = null
	flow_contact = null
	return ..()

/** Damage widens the same drip on the interior wall face or ocean-facing edge of a border window. */
/obj/effect/temp_visual/stationtrauma_water/leak
	icon_state = "splash_hydroponics"
	alpha = 220
	/// Release the owner's marker reference when the native deletion timer expires.
	var/datum/component/floodwater_leak/leak_owner

/obj/effect/temp_visual/stationtrauma_water/leak/Initialize(mapload, direction, datum/component/floodwater_leak/leak_owner, border_intake, severity = 1)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	flick(icon_state, src)
	src.leak_owner = leak_owner
	var/dx = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/dy = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	var/offset = border_intake ? -12 : 12
	pixel_x = offset * dx
	pixel_y = offset * dy
	var/matrix/leak_transform = matrix()
	leak_transform.Scale(0.3 + 0.2 * severity, 0.55 + 0.15 * severity)
	leak_transform.Turn(dir2angle(direction) - dir2angle(SOUTH))
	transform = leak_transform
	alpha = 205 + 15 * severity
	animate(src, time = duration / 2)
	animate(alpha = 0, time = duration / 2)

/obj/effect/temp_visual/stationtrauma_water/leak/Destroy()
	if(!QDELETED(leak_owner) && leak_owner.leak_visual == src)
		leak_owner.leak_visual = null
	leak_owner = null
	return ..()
