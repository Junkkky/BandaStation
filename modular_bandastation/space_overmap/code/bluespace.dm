/datum/stationtrauma_overmap/space
	/// Stoppable completion timer for the current bluespace jump.
	var/jump_timer
	/// Destination sector ID while a bluespace jump is pending.
	var/jump_target
	/// Native hyperspace effect phase, or NONE outside a jump.
	var/jump_phase = NONE
	/// Owned stoppable timers for intermediate hyperspace effects.
	var/list/jump_effect_timers = list()

/** Only charted links between resident sectors can be used; a physical dock must first be released. */
/datum/stationtrauma_overmap/space/proc/can_jump(id)
	if(!istext(id))
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/origin = sector
	var/datum/stationtrauma_overmap_sector/space/target = SSstationtrauma_space_voyage.sectors[id]
	return istype(origin) && !QDELETED(target) && target != origin && origin.ready && target.ready \
		&& SSstationtrauma_space_voyage.sectors[origin.id] == origin && (id in origin.jump_routes) \
		&& is_operational() && origin.ships[vessel.shuttle_id] == src && !target.ships[vessel.shuttle_id] \
		&& !preparing && !relocating && !docked && !ship_docking && !connection.active \
		&& !QDELETED(flight_berth) && vessel.z == flight_berth.z && jump_drive()

/** Serialize charted resident sectors available from the current jump network node. */
/datum/stationtrauma_overmap/space/proc/jump_data()
	var/list/routes = list()
	var/datum/stationtrauma_overmap_sector/space/current = sector
	for(var/id in current?.jump_routes)
		var/datum/stationtrauma_overmap_sector/space/target = SSstationtrauma_space_voyage.sectors[id]
		if(!QDELETED(target) && target.ready)
			routes += list(list("id" = id, "name" = target.name, "available" = can_jump(id)))
	return routes

/** Reserve a valid inter-sector jump and start its stoppable hyperspace effect sequence. */
/datum/stationtrauma_overmap/space/proc/request_jump(id)
	if(!can_jump(id))
		return FALSE
	command_course(ordered_course)
	braking = FALSE
	arrival_pending = FALSE
	status = "Зарядка блюспейс-привода"
	preparing = TRUE
	jump_target = id
	set_jump_phase(HYPERSPACE_WARMUP, id, control_revision)
	jump_effect_timers += addtimer(CALLBACK(src, PROC_REF(set_jump_phase), HYPERSPACE_LAUNCH, id, control_revision), 4 SECONDS, TIMER_STOPPABLE)
	jump_effect_timers += addtimer(CALLBACK(src, PROC_REF(set_jump_phase), HYPERSPACE_END, id, control_revision), ST_SPACE_JUMP_TIME - HYPERSPACE_END_TIME, TIMER_STOPPABLE)
	jump_timer = addtimer(CALLBACK(src, PROC_REF(finish_jump), id, control_revision), ST_SPACE_JUMP_TIME, TIMER_STOPPABLE)
	return TRUE

/** Reuse native shuttle audio, ripples and acceleration feedback on the current hull only. */
/datum/stationtrauma_overmap/space/proc/set_jump_phase(phase, id, revision)
	if(jump_target != id || revision != control_revision || !is_operational())
		return FALSE
	jump_phase = phase
	vessel.remove_ripples()
	if(phase != HYPERSPACE_LAUNCH)
		vessel.create_ripples(flight_berth, phase == HYPERSPACE_WARMUP ? 4 SECONDS : HYPERSPACE_END_TIME)
	vessel.hyperspace_sound(phase, vessel.shuttle_areas)
	if(phase != HYPERSPACE_WARMUP)
		for(var/mob/crew as anything in SSmobs.clients_by_zlevel[vessel.z])
			if(vessel.is_in_shuttle_bounds(crew))
				shake_camera(crew, 1 SECONDS, 1)
	update_parallax()
	return TRUE

/** Cancel owned jump timers and restore the current hull visual state. */
/datum/stationtrauma_overmap/space/proc/cancel_jump()
	if(jump_timer)
		deltimer(jump_timer)
		jump_timer = null
	for(var/timer in jump_effect_timers)
		deltimer(timer)
	jump_effect_timers.Cut()
	if(jump_phase)
		if(jump_phase == HYPERSPACE_LAUNCH && is_operational())
			vessel.hyperspace_sound(HYPERSPACE_END, vessel.shuttle_areas)
		vessel?.remove_ripples()
		jump_phase = NONE
	if(jump_target)
		jump_target = null
		preparing = FALSE
	if(is_operational())
		update_parallax()

/** No yield between registry removal and arrival: peers can never see the hull in both sectors. */
/datum/stationtrauma_overmap/space/proc/finish_jump(id, revision)
	if(jump_target != id)
		return FALSE
	jump_timer = null
	preparing = FALSE
	if(control_revision != revision || !can_jump(id))
		stop("Блюспейс-прыжок отменён")
		return FALSE
	cancel_jump()
	var/datum/stationtrauma_overmap_sector/space/origin = sector
	var/datum/stationtrauma_overmap_sector/space/target = SSstationtrauma_space_voyage.sectors[id]
	clear_encounters()
	origin.unregister(src)
	if(!target.register(vessel.shuttle_id, src))
		origin.register(vessel.shuttle_id, src)
		stop("Блюспейс-прыжок не выполнен")
		return FALSE
	var/obj/machinery/stationtrauma_bluespace_drive/drive = jump_drive()
	drive?.spend_charge()
	selected_destination = null
	prepared_site = null
	ship_observations.Cut()
	last_ping = null
	pos_x = encounter_x = target.entry_x
	pos_y = encounter_y = target.entry_y
	trip_distance = travelled = 0
	stop("Блюспейс-переход завершён: [target.name]")
	navigation_notice("Прибытие в систему: [target.name].")
	return TRUE

/** Powered, charged bluespace drive aboard the hull, or null. */
/datum/stationtrauma_overmap/space/proc/jump_drive()
	var/obj/machinery/stationtrauma_bluespace_drive/drive = vessel.bluespace_drive?.resolve()
	if(QDELETED(drive) || !drive.charges || (drive.machine_stat & (NOPOWER|BROKEN)) || !vessel.is_in_shuttle_bounds(drive))
		return null
	return drive

/**
 * Folds space around the hull for inter-system jumps; each bluespace anomaly core fed into it charges a fixed number of jumps.
 * The jump itself is ordered from the bluespace terminal and spends a charge only on arrival.
 */
/obj/machinery/stationtrauma_bluespace_drive
	name = "блюспейс-привод"
	desc = "Складывает пространство вокруг корпуса для межсистемного перехода. Заряжается ядром блюспейс-аномалии."
	icon = 'icons/obj/machines/teleporter.dmi'
	icon_state = "controller"
	density = TRUE
	anchored = TRUE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 5
	/// Jumps left before the drive needs another core.
	var/charges = 0

/obj/machinery/stationtrauma_bluespace_drive/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/stationtrauma_bluespace_drive/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/ship = port
	if(istype(ship) && ship.is_in_shuttle_bounds(src))
		ship.bluespace_drive = WEAKREF(src)

/obj/machinery/stationtrauma_bluespace_drive/update_icon_state()
	icon_state = charges && !(machine_stat & (NOPOWER|BROKEN)) ? "controller-p" : "controller"
	return ..()

/obj/machinery/stationtrauma_bluespace_drive/examine(mob/user)
	. = ..()
	. += span_notice("Запас переходов: [charges] из [ST_BLUESPACE_DRIVE_CAPACITY]. Одно ядро блюспейс-аномалии даёт [ST_BLUESPACE_CORE_JUMPS].")

/obj/machinery/stationtrauma_bluespace_drive/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/assembly/signaler/anomaly/bluespace))
		return NONE
	if(charges + ST_BLUESPACE_CORE_JUMPS > ST_BLUESPACE_DRIVE_CAPACITY)
		balloon_alert(user, "привод заряжен")
		return ITEM_INTERACT_BLOCKING
	if(!user.temporarilyRemoveItemFromInventory(tool))
		return ITEM_INTERACT_BLOCKING
	qdel(tool)
	charges += ST_BLUESPACE_CORE_JUMPS
	update_appearance(UPDATE_ICON_STATE)
	playsound(src, 'sound/effects/phasein.ogg', 50, TRUE)
	balloon_alert(user, "ядро загружено")
	return ITEM_INTERACT_SUCCESS

/** Spend one jump of charge after a completed jump. */
/obj/machinery/stationtrauma_bluespace_drive/proc/spend_charge()
	charges = max(0, charges - 1)
	update_appearance(UPDATE_ICON_STATE)
