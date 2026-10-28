/datum/stationtrauma_overmap/space
	var/jump_timer
	var/jump_target
	var/jump_phase = NONE
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
		&& !QDELETED(flight_berth) && vessel.z == flight_berth.z

/datum/stationtrauma_overmap/space/proc/jump_data()
	var/list/routes = list()
	var/datum/stationtrauma_overmap_sector/space/current = sector
	for(var/id in current?.jump_routes)
		var/datum/stationtrauma_overmap_sector/space/target = SSstationtrauma_space_voyage.sectors[id]
		if(!QDELETED(target) && target.ready)
			routes += list(list("id" = id, "name" = target.name, "available" = can_jump(id)))
	return routes

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
	selected_destination = null
	prepared_site = null
	ship_observations.Cut()
	charted_terrain.Cut()
	echoes.Cut()
	last_ping = null
	pos_x = encounter_x = target.entry_x
	pos_y = encounter_y = target.entry_y
	trip_distance = travelled = 0
	stop("Блюспейс-переход завершён: [target.name]")
	navigation_notice("Прибытие в систему: [target.name].")
	return TRUE
