/// Opt-in state only; ordinary areas do not acquire flood detection or processing.
/area
	var/datum/component/stationtrauma_flood_alarm/flood_alarm
	/// Deliberate filling of a water-lock chamber is not an emergency.
	var/stationtrauma_flood_exempt = FALSE

/area/shuttle/stationtrauma/water_airlock
	stationtrauma_flood_exempt = TRUE

/** One event-driven sensor per mapped compartment, shared by its panels and pump displays. */
/datum/component/stationtrauma_flood_alarm
	/// Finite water still above the safe threshold, and water deep enough to trigger.
	var/list/wet = list()
	var/list/deep = list()
	var/active = FALSE
	var/muted = FALSE
	/// A single cancellable rearm, never an idle polling timer.
	var/reset_timer
	/// Separate ownership prevents a flood reset from clearing a real fire report.
	var/datum/alarm_handler/reporter
	var/inherited_fire = FALSE

/datum/component/stationtrauma_flood_alarm/Initialize()
	if(!isarea(parent))
		return COMPONENT_INCOMPATIBLE
	var/area/zone = parent
	if(zone.stationtrauma_flood_exempt || istype(zone, /area/space))
		return COMPONENT_INCOMPATIBLE
	zone.flood_alarm = src
	reporter = new(zone)

/datum/component/stationtrauma_flood_alarm/RegisterWithParent()
	RegisterSignal(parent, COMSIG_STATIONTRAUMA_WATER_STAGE_CHANGED, PROC_REF(water_changed))
	RegisterSignal(parent, COMSIG_AREA_FIRE_CHANGED, PROC_REF(fire_changed))
	// One initial snapshot also supports a panel built in an already flooded room.
	for(var/turf/tile as anything in parent)
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		if(water && !water.infinite_source)
			water_changed(parent, water, stationtrauma_water_stage(water.get_depth()))

/datum/component/stationtrauma_flood_alarm/UnregisterFromParent()
	if(reset_timer)
		deltimer(reset_timer)
		reset_timer = null
	set_active(FALSE)
	UnregisterSignal(parent, list(COMSIG_STATIONTRAUMA_WATER_STAGE_CHANGED, COMSIG_AREA_FIRE_CHANGED))
	var/area/zone = parent
	zone.flood_alarm = null
	wet.Cut()
	deep.Cut()
	QDEL_NULL(reporter)

/// Native visual-stage crossings already cover both hysteresis thresholds; no extra water scan.
/datum/component/stationtrauma_flood_alarm/proc/water_changed(area/source, datum/component/floodwater/water, stage)
	SIGNAL_HANDLER
	if(stage >= 2)
		wet[water] = TRUE
	else
		wet -= water
	if(stage >= 3)
		deep[water] = TRUE
	else
		deep -= water
	if(!wet.len)
		if(reset_timer)
			deltimer(reset_timer)
			reset_timer = null
			SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED)
		set_active(FALSE)
	else if(deep.len && !reset_timer)
		set_active(TRUE)

/// Native firelock resets may clear lighting while flooding is still a separate active cause.
/datum/component/stationtrauma_flood_alarm/proc/fire_changed(area/source, burning)
	SIGNAL_HANDLER
	if(!burning)
		inherited_fire = FALSE
		if(active)
			source.set_fire_effect(TRUE, AREA_FAULT_AUTOMATIC, "Затопление")

/// Reuse native red emergency lighting, but release only this alarm's report and door claims.
/datum/component/stationtrauma_flood_alarm/proc/set_active(enabled)
	if(active == enabled)
		return
	var/area/zone = parent
	active = enabled
	muted = FALSE
	if(active)
		inherited_fire = zone.fire
		reporter.send_alarm(ALARM_FIRE, zone)
		zone.set_fire_effect(TRUE, AREA_FAULT_AUTOMATIC, "Затопление")
	else
		reporter.clear_alarm(ALARM_FIRE, zone)
		if(!inherited_fire && !zone.active_alarms[ALARM_FIRE] && !LAZYLEN(zone.active_firelocks))
			zone.set_fire_effect(FALSE, AREA_FAULT_NONE)
	SEND_SIGNAL(zone, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED)

/// Sound acknowledgement does not unlock doors or disable emergency lighting.
/datum/component/stationtrauma_flood_alarm/proc/toggle_mute()
	if(!active)
		return
	muted = !muted
	SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED)

/// Manual reset gives ten seconds to intervene, then uses cached sensor state to rearm once.
/datum/component/stationtrauma_flood_alarm/proc/reset_alarm()
	if(reset_timer || !active)
		return
	if(wet.len)
		reset_timer = addtimer(CALLBACK(src, PROC_REF(rearm)), 10 SECONDS, TIMER_STOPPABLE)
	set_active(FALSE)

/datum/component/stationtrauma_flood_alarm/proc/rearm()
	reset_timer = null
	set_active(!!wet.len)

/// A source-local native loop stops immediately on mute, reset, power loss or deletion.
/datum/looping_sound/stationtrauma_flood_alarm
	mid_sounds = 'modular_bandastation/underwater_machinery/alarms/sounds/198107__julius_galla__sirene-alarm-loop.wav'
	mid_length = 20.026 SECONDS
	volume = 40
	use_sound_tokens = TRUE

/** A dedicated water alarm button; intentionally has no thermal sensor or processing loop. */
/obj/machinery/stationtrauma_flood_alarm
	name = "тревога затопления"
	desc = "Панель сигнализации затопления. Автоматика срабатывает от 100 см воды; ниже 40 см тревога снимается."
	icon = 'modular_bandastation/underwater_machinery/icons/wall_controls.dmi'
	icon_state = "alarm"
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.05
	power_channel = AREA_USAGE_ENVIRON
	processing_flags = NONE
	light_color = LIGHT_COLOR_VIVID_GREEN
	light_power = 0.5
	light_range = 1.5
	var/area/alarm_area
	var/datum/looping_sound/stationtrauma_flood_alarm/soundloop

/obj/machinery/stationtrauma_flood_alarm/Initialize(mapload)
	. = ..()
	soundloop = new(src)
	register_context()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(bind_area))
	bind_area()
	if(mapload)
		find_and_mount_on_atom()

/obj/machinery/stationtrauma_flood_alarm/proc/bind_area()
	SIGNAL_HANDLER
	var/area/zone = get_area(src)
	if(alarm_area == zone)
		return
	if(alarm_area)
		UnregisterSignal(alarm_area, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED)
	alarm_area = zone
	if(!zone.stationtrauma_flood_exempt && !istype(zone, /area/space))
		zone.LoadComponent(/datum/component/stationtrauma_flood_alarm)
		RegisterSignal(zone, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED, PROC_REF(alarm_changed))
	alarm_changed()

/obj/machinery/stationtrauma_flood_alarm/Destroy()
	QDEL_NULL(soundloop)
	alarm_area = null
	return ..()

/obj/machinery/stationtrauma_flood_alarm/on_set_is_operational(old_value)
	. = ..()
	if(soundloop)
		alarm_changed()

/obj/machinery/stationtrauma_flood_alarm/proc/alarm_changed()
	SIGNAL_HANDLER
	if(is_operational && alarm_area?.flood_alarm?.active && !alarm_area.flood_alarm.muted)
		soundloop.start()
	else
		soundloop.stop()
	update_appearance()

/obj/machinery/stationtrauma_flood_alarm/update_icon_state()
	icon_state = !is_operational ? "alarm-nopower" : alarm_area?.flood_alarm?.active ? "alarm_alert" : "alarm"
	return ..()

/obj/machinery/stationtrauma_flood_alarm/update_overlays()
	. = ..()
	if(!is_operational)
		set_light(l_on = FALSE)
		return
	var/alert = alarm_area?.flood_alarm?.active
	. += emissive_appearance(icon, "[icon_state]-light-mask", src, alpha = src.alpha)
	set_light(l_on = TRUE, l_color = alert ? LIGHT_COLOR_INTENSE_RED : LIGHT_COLOR_VIVID_GREEN)

/obj/machinery/stationtrauma_flood_alarm/attack_hand(mob/living/user, list/modifiers)
	if(..() || !is_operational)
		return
	var/datum/component/stationtrauma_flood_alarm/alarm = alarm_area?.flood_alarm
	if(alarm && !alarm.reset_timer)
		alarm.set_active(TRUE)

/obj/machinery/stationtrauma_flood_alarm/attack_hand_secondary(mob/living/user, list/modifiers)
	if(is_operational && user.can_perform_action(src, NEED_DEXTERITY))
		alarm_area?.flood_alarm?.reset_alarm()
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/machinery/stationtrauma_flood_alarm/click_alt(mob/user)
	if(is_operational && user.can_perform_action(src, NEED_DEXTERITY | FORBID_TELEKINESIS_REACH))
		alarm_area?.flood_alarm?.toggle_mute()
	return CLICK_ACTION_SUCCESS

/// Display controls in the native hover HUD instead of the examination text.
/obj/machinery/stationtrauma_flood_alarm/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!is_operational || !alarm_area?.flood_alarm)
		return .
	if(!held_item)
		context[SCREENTIP_CONTEXT_LMB] = "Включить тревогу"
		context[SCREENTIP_CONTEXT_RMB] = "Временно сбросить тревогу"
	context[SCREENTIP_CONTEXT_ALT_LMB] = alarm_area.flood_alarm.muted ? "Включить сирену" : "Отключить сирену"
	return CONTEXTUAL_SCREENTIP_SET

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/stationtrauma_flood_alarm, 24)
