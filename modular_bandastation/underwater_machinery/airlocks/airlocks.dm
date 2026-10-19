/obj/machinery/door/airlock/highsecurity/underwater
	name = "гермодверь"
	desc = "Тяжёлая круглая створка на боковых направляющих. Вентиль управляет механическими запорами."
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	note_overlay_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	assemblytype = /obj/structure/door_assembly/underwater
	normal_integrity = 400
	security_level = 6
	air_tight = TRUE
	has_open_lights = TRUE
	doorOpen = 'sound/machines/airlock/airlockopen.ogg'
	doorClose = 'sound/machines/airlock/airlockclose.ogg'
	/// Mechanical dogs are independent of the powered airlock bolts.
	var/handwheel_locked = FALSE
	var/handwheel_turning = FALSE
	/// Only a linked water chamber controls these mechanical dogs automatically.
	var/obj/machinery/button/stationtrauma_water_airlock/water_airlock
	/// Adjacent compartments with active flood alarms; manual wheel operation remains available.
	var/list/flood_alarm_areas = list()
	var/list/flood_sources = list()
	var/flood_sealed = FALSE
	var/flood_bypassed = FALSE
	var/flood_revision = 0

/obj/machinery/door/airlock/highsecurity/underwater/Initialize(mapload)
	setDir(dir)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(bind_flood_areas))

/obj/machinery/door/airlock/highsecurity/underwater/post_machine_initialize()
	. = ..()
	bind_flood_areas()

/obj/machinery/door/airlock/highsecurity/underwater/Destroy()
	flood_alarm_areas.Cut()
	flood_sources.Cut()
	return ..()

/obj/machinery/door/airlock/highsecurity/underwater/on_set_is_operational(old_value)
	. = ..()
	if(is_operational && flood_sources.len && !flood_bypassed && !water_airlock)
		INVOKE_ASYNC(src, PROC_REF(seal_for_flood), flood_revision)

/// Only our door subtype listens for flood alerts; chamber controllers retain exclusive ownership.
/obj/machinery/door/airlock/highsecurity/underwater/proc/bind_flood_areas()
	SIGNAL_HANDLER
	for(var/area/zone as anything in flood_alarm_areas)
		UnregisterSignal(zone, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED)
	flood_alarm_areas.Cut()
	var/turf/tile = get_turf(src)
	flood_alarm_areas |= get_area(tile)
	for(var/direction in GLOB.cardinals)
		var/area/neighbor = get_area(get_step(tile, direction))
		if(neighbor)
			flood_alarm_areas |= neighbor
	for(var/area/zone as anything in flood_alarm_areas)
		RegisterSignal(zone, COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED, PROC_REF(flood_alarm_changed))
	flood_alarm_changed()

/// Muting or refreshing an existing alert never recloses a manually released door.
/obj/machinery/door/airlock/highsecurity/underwater/proc/flood_alarm_changed()
	SIGNAL_HANDLER
	if(water_airlock)
		return
	// Mapping alone excludes chamber doors before their controller has linked at late initialization.
	for(var/area/zone as anything in flood_alarm_areas)
		if(zone.stationtrauma_flood_exempt)
			return
	var/list/next_sources = list()
	for(var/area/zone as anything in flood_alarm_areas)
		if(zone.flood_alarm?.active)
			next_sources |= zone
	var/had_alarm = !!flood_sources.len
	flood_sources = next_sources
	if(had_alarm == !!flood_sources.len)
		return
	flood_revision++
	flood_bypassed = FALSE
	if(flood_sources.len)
		INVOKE_ASYNC(src, PROC_REF(seal_for_flood), flood_revision)
	else if(flood_sealed)
		set_handwheel(FALSE)

/// One safe close and wheel turn per alert; no retry loop and no forced crushing on obstruction.
/obj/machinery/door/airlock/highsecurity/underwater/proc/seal_for_flood(revision)
	if(revision != flood_revision || !flood_sources.len || water_airlock || flood_bypassed)
		return
	close()

/// A native safe-close retry also engages the wheel once its obstruction is gone.
/obj/machinery/door/airlock/highsecurity/underwater/close(forced = DEFAULT_DOOR_CHECKS, force_crush = FALSE)
	. = ..()
	if(!. || !is_operational || !flood_sources.len || water_airlock || flood_bypassed || handwheel_locked || handwheel_turning)
		return
	var/revision = flood_revision
	handwheel_turning = TRUE
	update_appearance()
	sleep(1 SECONDS)
	if(QDELETED(src))
		return
	handwheel_turning = FALSE
	if(revision == flood_revision && flood_sources.len && !water_airlock && density && !operating && is_operational)
		set_handwheel(TRUE)
		flood_sealed = TRUE
	else if(revision != flood_revision && flood_sources.len && !water_airlock && !flood_bypassed && is_operational)
		// A reset/retrigger during this turn must not strand the newer seal request.
		INVOKE_ASYNC(src, PROC_REF(seal_for_flood), flood_revision)
	update_appearance()

/obj/machinery/door/airlock/highsecurity/underwater/setDir(newdir)
	return ..(multi_tile ? newdir : SOUTH)

/obj/machinery/door/airlock/highsecurity/underwater/examine(mob/user)
	. = ..()
	. += span_notice("Вентиль [handwheel_locked ? "закручен: механические запоры закрыты" : "откручен: механические запоры открыты"]. Механический запор работает даже без питания.")

/obj/machinery/door/airlock/highsecurity/underwater/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(density && !operating && !handwheel_turning)
		context[SCREENTIP_CONTEXT_ALT_LMB] = handwheel_locked ? "Открутить вентиль" : "Закрутить вентиль"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/door/airlock/highsecurity/underwater/click_alt(mob/user)
	if(!isliving(user) || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return CLICK_ACTION_BLOCKING
	if(!density || operating || handwheel_turning)
		to_chat(user, span_warning("Вентиль можно повернуть только на неподвижной закрытой двери."))
		return CLICK_ACTION_BLOCKING
	if(isElectrified() && shock(user, 100))
		return CLICK_ACTION_BLOCKING
	add_fingerprint(user)
	handwheel_turning = TRUE
	update_appearance()
	user.visible_message(span_notice("[user] поворачивает вентиль [src]."), span_notice("Вы [handwheel_locked ? "откручиваете" : "закручиваете"] вентиль [src]."))
	var/completed = do_after(user, 1 SECONDS, src)
	if(QDELETED(src))
		return CLICK_ACTION_BLOCKING
	handwheel_turning = FALSE
	if(completed && density && !operating)
		water_airlock?.stop_cycle("Ручное управление вентилем")
		set_handwheel(!handwheel_locked)
		if(water_airlock && !handwheel_locked)
			open(BYPASS_DOOR_CHECKS, user)
	update_appearance()
	return CLICK_ACTION_SUCCESS

/** Manual and automatic wheel operations finish with the same mechanical sound and appearance. */
/obj/machinery/door/airlock/highsecurity/underwater/proc/set_handwheel(locked)
	flood_sealed = FALSE
	if(!locked && flood_sources.len)
		flood_bypassed = TRUE
	handwheel_locked = locked
	playsound(src, handwheel_locked ? boltDown : boltUp, 30, FALSE, 3)
	update_appearance()

/** An automatic turn uses the existing wheel animation; cancelled cycles cannot release a door later. */
/obj/machinery/door/airlock/highsecurity/underwater/proc/turn_handwheel(locked, obj/machinery/button/stationtrauma_water_airlock/controller, revision)
	if(QDELETED(controller) || !controller.cycling || revision != controller.cycle_revision || !density || operating || handwheel_turning)
		return FALSE
	if(handwheel_locked == locked)
		return TRUE
	handwheel_turning = TRUE
	update_appearance()
	sleep(1 SECONDS)
	if(QDELETED(src))
		return FALSE
	handwheel_turning = FALSE
	if(QDELETED(controller) || !controller.cycling || revision != controller.cycle_revision || !controller.is_operational || !is_operational || !density || operating)
		update_appearance()
		return FALSE
	set_handwheel(locked)
	return TRUE

/obj/machinery/door/airlock/highsecurity/underwater/open(forced = DEFAULT_DOOR_CHECKS, mob/living/opener)
	if(handwheel_locked || handwheel_turning || water_airlock?.cycling)
		return FALSE
	return ..()

/obj/machinery/door/airlock/highsecurity/underwater/update_overlays()
	. = ..()
	if(density && !operating)
		var/wheel_state = "wheel_[handwheel_locked || locked ? "locked" : "unlocked"]"
		if(handwheel_turning)
			wheel_state = "wheel_[handwheel_locked ? "unlocking" : "locking"]"
		. += get_airlock_overlay(wheel_state, icon, src, em_block = TRUE)
		if(handwheel_locked && feedback && hasPower())
			. += get_airlock_overlay("lights_bolts", overlays_file, src, em_block = FALSE)

/obj/machinery/door/airlock/highsecurity/underwater/multi_tile
	name = "большая гермодверь"
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	note_overlay_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	assemblytype = /obj/structure/door_assembly/multi_tile/underwater
	multi_tile = TRUE

/obj/machinery/door/airlock/highsecurity/underwater/multi_tile/setDir(newdir)
	. = ..()
	set_bounds()
	if(filler)
		set_filler()

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/airlock/highsecurity/underwater/multi_tile, 0)

/obj/structure/door_assembly/underwater
	parent_type = /obj/structure/door_assembly/door_assembly_highsecurity
	base_name = "гермодверь"
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	airlock_type = /obj/machinery/door/airlock/highsecurity/underwater

/obj/structure/door_assembly/multi_tile/underwater
	base_name = "большая гермодверь"
	dir = SOUTH
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	airlock_type = /obj/machinery/door/airlock/highsecurity/underwater/multi_tile
	glass_type = null
	glass = FALSE
	noglass = TRUE
	material_type = /obj/item/stack/sheet/plasteel
	custom_materials = list(/datum/material/alloy/plasteel = SHEET_MATERIAL_AMOUNT * 8)

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/door_assembly/multi_tile/underwater, 0)
