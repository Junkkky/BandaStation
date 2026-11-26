/** A sealed one-use capsule with ordinary locker loading and manual egress. */
/obj/structure/closet/stationtrauma_drop_pod
	name = "дроп-под"
	desc = "Герметичная десантная капсула на двух человек. Откройте люк, встаньте на клетку капсулы и закройте люк перед пуском. Для выхода после посадки откройте люк или попробуйте шагнуть."
	icon = 'modular_bandastation/space_combat/icons/patrol_pod.dmi'
	icon_state = "pod"
	enable_door_overlay = FALSE
	door_anim_time = 0
	generate_map_preview = FALSE
	anchored = TRUE
	anchorable = FALSE
	opened = TRUE
	sealed = TRUE
	contents_pressure_protection = 1
	contents_thermal_insulation = 1
	can_weld_shut = FALSE
	can_install_electronics = FALSE
	paint_jobs = FALSE
	mob_storage_capacity = 2
	/// A capsule can only be sent from its original launch rack, once.
	var/launched = FALSE
	/// A landed capsule is spent as soon as its hatch has been opened.
	var/spent = FALSE
	/// Holds the hatch and protects the capsule during transit.
	var/datum/stationtrauma_drop_flight/flight

/obj/structure/closet/stationtrauma_drop_pod/closet_update_overlays(list/new_overlays)
	. = ..()
	if(!opened)
		. += mutable_appearance(icon, "pod_door")

/obj/structure/closet/stationtrauma_drop_pod/can_open(mob/living/user, force = FALSE)
	return !flight && ..()

/obj/structure/closet/stationtrauma_drop_pod/after_open(mob/living/user, force = FALSE)
	. = ..()
	if(launched && !flight && !spent)
		spent = TRUE
		QDEL_IN(src, ST_DROP_POD_SPENT_TIME)

/obj/structure/closet/stationtrauma_drop_pod/can_close(mob/living/user)
	return !spent && ..()

/obj/structure/closet/stationtrauma_drop_pod/get_remote_view_fullscreens(mob/user)
	if(flight && user.loc == src && isliving(user) && user.stat != DEAD)
		var/braking = world.time >= flight.arrives_at - ST_DROP_POD_BRAKING_TIME
		return user.overlay_fullscreen("remote_view", /atom/movable/screen/fullscreen/stationtrauma_drop_pod, braking ? 2 : 1)
	if(istype(user.screens["remote_view"], /atom/movable/screen/fullscreen/stationtrauma_drop_pod))
		user.clear_fullscreen("remote_view", FALSE)
	return ..()

/// Refresh occupants already looking through the capsule when its flight phase changes.
/obj/structure/closet/stationtrauma_drop_pod/proc/refresh_passenger_views()
	for(var/mob/living/passenger in src)
		if(passenger.client?.eye == src)
			passenger.update_fullscreen()
		else if(istype(passenger.screens["remote_view"], /atom/movable/screen/fullscreen/stationtrauma_drop_pod))
			passenger.clear_fullscreen("remote_view", FALSE)

/obj/structure/closet/stationtrauma_drop_pod/Exited(atom/movable/gone, direction)
	. = ..()
	var/mob/living/passenger = gone
	if(istype(passenger) && istype(passenger.screens["remote_view"], /atom/movable/screen/fullscreen/stationtrauma_drop_pod))
		passenger.clear_fullscreen("remote_view", FALSE)

/// The 320px cabin is centred on the map. Crop the outer hull to fill widescreen without stretching the glass.
/atom/movable/screen/fullscreen/stationtrauma_drop_pod
	icon = 'modular_bandastation/space_combat/icons/drop_pod_view.dmi'
	icon_state = "flight"
	screen_loc = "CENTER-4:-16,CENTER-4:-16"

/atom/movable/screen/fullscreen/stationtrauma_drop_pod/update_for_view(client_view)
	var/list/tiles = getviewsize(client_view)
	var/scale = max(tiles[1], tiles[2]) * world.icon_size / 320
	transform = matrix().Scale(scale)

/obj/structure/closet/stationtrauma_drop_pod/Destroy()
	if(flight)
		flight.finish("lost")
	return ..()

/obj/structure/closet/stationtrauma_drop_pod/proc/touchdown(turf/tile)
	flight = null
	resistance_flags &= ~INDESTRUCTIBLE
	forceMove(tile)
	refresh_passenger_views()
	pixel_z = 24
	animate(src, pixel_z = 0, time = 4)
	var/obj/effect/supplypod_smoke/dust = new(tile)
	QDEL_IN(dust, 1 SECONDS)
	playsound(tile, 'sound/effects/bang.ogg', 55, TRUE)
	for(var/mob/living/passenger in contents)
		to_chat(passenger, span_notice("Капсула приземлилась. Подготовьтесь к выходу и откройте люк."))

/obj/docking_port/mobile/stationtrauma_space
	var/list/drop_pod_reports

/datum/stationtrauma_overmap_sector/space
	var/list/active_drop_pods
	var/next_drop_pod = 0

/** Tracks the actual capsule independently of the console and ship which launched it. */
/datum/stationtrauma_drop_flight
	var/obj/structure/closet/stationtrauma_drop_pod/pod
	var/datum/weakref/source_ref
	var/datum/weakref/target_ref
	/// Fixed chart destination, which can lose its berth during flight.
	var/datum/weakref/site_ref
	var/datum/stationtrauma_overmap_sector/space/sector
	var/number
	var/capsule_name
	var/contact_name
	var/section
	var/start_x
	var/start_y
	var/end_x
	var/end_y
	var/started_at
	var/arrives_at
	var/result = "flying"

/datum/stationtrauma_drop_flight/New(obj/structure/closet/stationtrauma_drop_pod/capsule, datum/stationtrauma_overmap/space/source, datum/stationtrauma_overmap/space/target, target_label, landing_section, datum/stationtrauma_overmap_site/space/docking_target/site)
	pod = capsule
	source_ref = WEAKREF(source.vessel)
	if(site)
		site_ref = WEAKREF(site)
	else
		target_ref = WEAKREF(target)
	sector = source.sector
	section = landing_section
	capsule_name = capsule.name
	contact_name = target_label
	start_x = source.pos_x
	start_y = source.pos_y
	end_x = site ? site.pos_x : target.pos_x
	end_y = site ? site.pos_y : target.pos_y
	started_at = world.time
	var/distance = sqrt((end_x - start_x) ** 2 + (end_y - start_y) ** 2)
	var/duration = max(ST_DROP_POD_MIN_FLIGHT, ST_DROP_POD_PREPARE + CEILING(distance / ST_DROP_POD_SPEED * (1 SECONDS), 1))
	arrives_at = started_at + duration
	number = ++sector.next_drop_pod
	LAZYADD(sector.active_drop_pods, src)
	LAZYADD(source.vessel.drop_pod_reports, src)
	if(target_ref)
		START_PROCESSING(SSfastprocess, src)
	addtimer(CALLBACK(capsule, TYPE_PROC_REF(/obj/structure/closet/stationtrauma_drop_pod, refresh_passenger_views)), duration - ST_DROP_POD_BRAKING_TIME)
	addtimer(CALLBACK(src, PROC_REF(arrive)), duration)

/datum/stationtrauma_drop_flight/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	var/obj/docking_port/mobile/stationtrauma_space/source = source_ref?.resolve()
	if(source)
		LAZYREMOVE(source.drop_pod_reports, src)
	if(sector)
		LAZYREMOVE(sector.active_drop_pods, src)
	return ..()

/datum/stationtrauma_drop_flight/proc/finish(outcome)
	if(result != "flying")
		return
	result = outcome
	STOP_PROCESSING(SSfastprocess, src)
	LAZYREMOVE(sector.active_drop_pods, src)
	pod = null
	QDEL_IN(src, ST_DROP_POD_REPORT_TIME)

/datum/stationtrauma_drop_flight/proc/arrive()
	if(QDELETED(pod) || result != "flying")
		return
	if(site_ref)
		var/datum/stationtrauma_overmap_site/space/docking_target/site = site_ref.resolve()
		var/datum/stationtrauma_overmap_site/space/berth = site?.combat_berth(sector)
		var/turf/landing = berth?.random_drop_turf()
		// Finding a clear tile may yield on a crowded deck.
		if(QDELETED(pod) || result != "flying")
			return
		if(landing && site?.combat_berth(sector) == berth && relay_drop_turf(landing))
			pod.touchdown(landing)
			finish("landed")
			return
		await_rescue()
		return
	var/datum/stationtrauma_overmap/space/target = guided_target()
	if(target)
		end_x = target.pos_x
		end_y = target.pos_y
		// The field is sampled at touchdown, after the whole sector flight.
		var/shielded = target.vessel.combat_shield_active()
		var/turf/landing = target.drop_pod_landing_turf(section, shielded)
		if(landing)
			pod.touchdown(landing)
			finish(shielded ? "rim" : "inside")
			return
	await_rescue()

/datum/stationtrauma_drop_flight/process(seconds_per_tick)
	var/datum/stationtrauma_overmap/space/target = guided_target()
	if(target)
		end_x = target.pos_x
		end_y = target.pos_y

/** Both the track and touchdown use the same pursuit limit. */
/datum/stationtrauma_drop_flight/proc/guided_target()
	var/datum/stationtrauma_overmap/space/target = target_ref.resolve()
	if(QDELETED(target) || target.sector != sector || !target.kinetic_exposed())
		return null
	var/reach = min(ST_DROP_POD_RANGE, ST_DROP_POD_SPEED * (arrives_at - started_at) / (1 SECONDS)) + target.radius
	if((target.pos_x - start_x) ** 2 + (target.pos_y - start_y) ** 2 <= reach ** 2)
		return target

/datum/stationtrauma_drop_flight/proc/await_rescue()
	var/datum/stationtrauma_lost_space/loss = stationtrauma_open_space(sector, end_x, end_y)
	if(QDELETED(pod))
		return
	var/turf/landing
	if(loss?.level)
		var/center_x = world.maxx >> 1
		var/center_y = world.maxy >> 1
		var/deck = loss.level.z_value
		landing = locate(center_x, center_y, deck)
		if(landing.is_blocked_turf())
			for(var/turf/open/space/candidate in block(center_x - 4, center_y - 4, deck, center_x + 4, center_y + 4, deck))
				if(!candidate.is_blocked_turf())
					landing = candidate
					break
	if(!landing)
		// The normal failure path keeps the crew in a rescue site even after the launcher is gone.
		var/obj/docking_port/mobile/stationtrauma_space/source = source_ref.resolve()
		landing = get_turf(source)
	if(!landing)
		// Keep the sealed capsule recoverable at the native holding location.
		landing = get_turf(pod)
	pod.touchdown(landing)
	if(loss?.level)
		var/obj/item/stationtrauma_distress_beacon/beacon = new(landing)
		beacon.active = TRUE
		beacon.callsign = "Дроп-под [number]"
		beacon.update_appearance(UPDATE_ICON_STATE)
		loss.refresh_signal()
	finish(loss?.level ? "rescue" : "returned")

/** Return a clear floor or an exterior cell touching genuine hull, constrained to the selected third. */
/datum/stationtrauma_overmap/space/proc/drop_pod_landing_turf(section, shielded)
	var/list/bounds = vessel.return_coords()
	var/low_x = min(bounds[1], bounds[3])
	var/high_x = max(bounds[1], bounds[3])
	var/low_y = min(bounds[2], bounds[4])
	var/high_y = max(bounds[2], bounds[4])
	var/fore = vessel.preferred_direction
	var/longitudinal_x = (fore == EAST || fore == WEST)
	var/low = longitudinal_x ? low_x : low_y
	var/high = longitudinal_x ? high_x : high_y
	var/decreasing = (fore == SOUTH || fore == WEST)
	var/third = (high - low + 1) / 3
	var/from_aft = section == "bow" ? 2 : section == "midship" ? 1 : 0
	var/index = decreasing ? 2 - from_aft : from_aft
	var/section_low = low + index * third
	var/section_high = section_low + third
	var/center = (section_low + section_high - 1) / 2
	var/lateral = longitudinal_x ? (low_y + high_y) / 2 : (low_x + high_x) / 2
	var/list/decks = vessel.orbital_only ? vessel.owned_z_levels : list(vessel.z)
	var/turf/best
	var/best_score
	for(var/deck in decks)
		for(var/turf/open/candidate in block(max(2, low_x - 1), max(2, low_y - 1), deck, min(world.maxx - 1, high_x + 1), min(world.maxy - 1, high_y + 1), deck))
			var/along = longitudinal_x ? candidate.x : candidate.y
			// A rim tile beyond either end inherits the ship section it touches.
			along = clamp(along, low, high)
			if(along < section_low || along >= section_high || candidate.is_transition_turf() || candidate.is_blocked_turf())
				continue
			if(shielded)
				if(!isspaceturf(candidate) || get_area(candidate) != exterior)
					continue
				var/touches_hull = FALSE
				for(var/direction in GLOB.cardinals)
					var/turf/neighbor = get_step(candidate, direction)
					if(!isspaceturf(neighbor) && vessel.shuttle_areas[get_area(neighbor)] && vessel.is_in_shuttle_bounds(neighbor))
						touches_hull = TRUE
						break
				if(!touches_hull)
					continue
			else
				var/area/shuttle/stationtrauma_space/compartment = get_area(candidate)
				if(!isfloorturf(candidate) || !istype(compartment) || compartment.vacuum_by_design \
					|| !vessel.shuttle_areas[compartment] || !vessel.is_in_shuttle_bounds(candidate) || (locate(/obj/machinery/door) in candidate))
					continue
			var/across = longitudinal_x ? candidate.y : candidate.x
			var/score = abs(along - center) * 2 + abs(across - lateral)
			if(!best || score < best_score || (score == best_score && candidate.z > best.z))
				best = candidate
				best_score = score
	return best

/** Only detected capsules are shown; the track carries no destination or passenger data. */
/datum/stationtrauma_overmap/space/proc/drop_pod_echo_data()
	. = list()
	var/datum/stationtrauma_overmap_sector/space/here = sector
	for(var/datum/stationtrauma_drop_flight/flight as anything in here?.active_drop_pods)
		var/progress = clamp((world.time - flight.started_at) / (flight.arrives_at - flight.started_at), 0, 1)
		var/x = lerp(flight.start_x, flight.end_x, progress)
		var/y = lerp(flight.start_y, flight.end_y, progress)
		if(flight.source_ref.resolve() != vessel && (!vessel.has_power() || (x - pos_x) ** 2 + (y - pos_y) ** 2 > sensor_range ** 2))
			continue
		. += list(list("id" = flight.number, "x" = x, "y" = y))
