/** Ocean loader, PGD propulsion and sonar adapter for the reusable overmap model. */
/datum/stationtrauma_overmap/submarine
	/// Permanent physical vessel; navigation never relocates its hull or water.
	var/obj/docking_port/mobile/stationtrauma/vessel

/datum/stationtrauma_overmap/submarine/New(obj/docking_port/mobile/stationtrauma/owner)
	vessel = owner
	radius = max(12, sqrt(owner.width ** 2 + owner.height ** 2) / 2)
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in owner.berths)
		var/datum/stationtrauma_overmap_site/submarine/site = new(berth.type)
		site.berth = berth
		sites[site.id] = site
	for(var/destination in owner.unloaded_destinations)
		var/datum/map_template/stationtrauma_route/template = owner.unloaded_destinations[destination]
		var/datum/stationtrauma_overmap_site/submarine/site = new(initial(template.destination_berth_type))
		sites[site.id] = site
	var/datum/stationtrauma_overmap_site/origin = sites[owner.fixed_location?.shuttle_id]
	if(origin)
		origin.visited = TRUE
	pos_x = origin?.pos_x || 0
	pos_y = origin?.pos_y || 0
	build_contacts()
	return ..()

/** Small destinations are resident before departure; retain their native worlds throughout the round. */
/datum/stationtrauma_overmap/submarine/proc/preload_destinations()
	if(preparing)
		return FALSE
	preparing = TRUE
	var/saved_status = status
	for(var/id in sites)
		if(QDELETED(src) || QDELETED(vessel))
			preparing = FALSE
			return FALSE
		var/datum/stationtrauma_overmap_site/site = sites[id]
		if(site.berth || site.failed)
			continue
		status = "Подготовка локации: [site.name]"
		try
			site.berth = vessel.load_destination(site.name, TRUE)
		catch(var/exception/failure)
			stack_trace("StationTrauma preload of [site.name] failed: [failure]")
		site.failed = !site.berth
	status = saved_status
	preparing = FALSE
	return TRUE

/** Begin or resume manual navigation; location preparation does not own the helm. */
/datum/stationtrauma_overmap/submarine/sail()
	if(!..())
		return FALSE
	var/datum/stationtrauma_overmap_site/site = sites[selected_destination]
	if(!vessel.travelling)
		vessel.travelling = TRUE
		vessel.map_connection.active = FALSE
		INVOKE_ASYNC(src, PROC_REF(prepare_destination))
	else if(site && !preparing && (prepared_site != site || vessel.map_connection.prepared_revision != vessel.map_connection.revision || !length(vessel.map_connection.passages)))
		INVOKE_ASYNC(src, PROC_REF(prepare_destination))
	return TRUE

/** Select only registered IDs; an in-flight native map load cannot be duplicated or retargeted. */
/datum/stationtrauma_overmap/submarine/select_site(id)
	var/datum/stationtrauma_overmap_site/site = sites[id]
	if(site && !vessel.travelling && site.berth == vessel.fixed_location)
		return FALSE
	. = ..()
	if(. && vessel.travelling && prepared_site != site)
		INVOKE_ASYNC(src, PROC_REF(prepare_destination))

/** One worker prepares an inactive ocean corridor while the physical vessel continues to run. */
/datum/stationtrauma_overmap/submarine/proc/prepare_destination()
	if(preparing || QDELETED(vessel))
		return
	preparing = TRUE
	prepared_site = null
	var/datum/stationtrauma_overmap_site/site = sites[selected_destination]
	vessel.loading_fraction = site?.berth ? 0.95 : 0
	var/datum/stationtrauma_work_budget/budget = new
	try
		vessel.disconnect_ocean_cooperatively(budget)
		if(QDELETED(src) || QDELETED(vessel))
			preparing = FALSE
			return
		if(site)
			if(!site.berth)
				site.berth = vessel.load_destination(site.name)
			if(!QDELETED(vessel) && site.berth && vessel.connect_ocean_location(site.berth, budget, FALSE))
				prepared_site = site
				vessel.loading_fraction = 1
			else
				site.failed = !site.berth
				stop("Не удалось подготовить [site.name]. Выберите другую точку или вернитесь к исходной.")
	catch(var/exception/failure)
		if(!QDELETED(vessel))
			stop("Ошибка подготовки локации. Ход остановлен.")
		stack_trace("StationTrauma overmap preparation failed: [failure]")
	preparing = FALSE

/** The marker reaches the point only after its entire physical stack and corridor are ready. */
/datum/stationtrauma_overmap/submarine/arrive(datum/stationtrauma_overmap_site/site)
	var/datum/stationtrauma_work_budget/budget = new
	var/arrived = FALSE
	try
		if(can_arrive(site))
			arrived = vessel.activate_ocean_passages(budget, CALLBACK(src, PROC_REF(can_arrive), site))
	catch(var/exception/failure)
		stack_trace("StationTrauma overmap arrival failed: [failure]")
	if(arrived)
		vessel.fixed_location = site.berth
		vessel.voyage_progress = 1
		vessel.travelling = FALSE
		..()
	else if(helm_engaged)
		stop("Проход перекрыт: остановка перед локацией")
	arrival_pending = FALSE

/** Native client-side ocean loops are restarted only when the compass octant or motion changes. */
/datum/stationtrauma_overmap/submarine/update_parallax()
	if(QDELETED(vessel))
		return
	var/direction = helm_engaged && speed > 0.05 ? angle2dir(delta_to_angle(velocity_x, velocity_y)) : NONE
	if(parallax_direction == direction)
		return
	parallax_direction = direction
	vessel.set_fixed_parallax(direction)

/** Read underwater route metadata without coupling the shared site registry to ocean berths. */
/datum/stationtrauma_overmap_site/submarine/New(obj/docking_port/stationary/stationtrauma/berth_type)
	id = initial(berth_type.shuttle_id)
	name = initial(berth_type.name)
	pos_x = initial(berth_type.route_position)
	pos_y = initial(berth_type.route_y)
	discovered = initial(berth_type.route_known)

/** Author the initial ocean in metres; no corresponding physical levels are allocated for these lines. */
/datum/stationtrauma_overmap/submarine/proc/build_contacts()
	contacts += new /datum/stationtrauma_overmap_terrain(450, -380, 1000, -180)
	contacts += new /datum/stationtrauma_overmap_terrain(1000, -180, 1300, 80)
	contacts += new /datum/stationtrauma_overmap_terrain(1300, 80, 1950, 40)
	contacts += new /datum/stationtrauma_overmap_terrain(650, 850, 1450, 1100)
	contacts += new /datum/stationtrauma_overmap_terrain(2100, 1050, 2750, 450)
	contacts += new /datum/stationtrauma_overmap_terrain(2750, 450, 3150, 500)

/** Only powered submarine consoles can emit an active acoustic pulse. */
/datum/stationtrauma_overmap/submarine/has_sensors()
	for(var/obj/machinery/computer/stationtrauma_navigation/console as anything in vessel.navigation_consoles)
		if(!(console.machine_stat & (NOPOWER|BROKEN)))
			return TRUE
	return FALSE

/datum/stationtrauma_overmap/submarine/ping()
	if(!..())
		return FALSE
	for(var/obj/machinery/computer/stationtrauma_navigation/console as anything in vessel.navigation_consoles)
		if(!(console.machine_stat & (NOPOWER|BROKEN)))
			playsound(console, 'modular_bandastation/underwater_submarine/sounds/sonar.wav', 35, FALSE)
	return TRUE

/** Derive noise from six cached drives, never from machinery or water scans. */
/datum/stationtrauma_overmap/submarine/acoustic_noise()
	var/noise = 0
	for(var/obj/machinery/power/stationtrauma_pgd/engine as anything in vessel.drive_engines)
		noise += engine.acoustic_signature / 6
	return noise

/** Physical ownership, propulsion and hull effects stay outside the shared navigation model. */
/datum/stationtrauma_overmap/submarine/is_operational()
	return !QDELETED(vessel)

/datum/stationtrauma_overmap/submarine/propulsion_available()
	return vessel.engines_running && !(preparing && !vessel.travelling)

/datum/stationtrauma_overmap/submarine/get_target_speed()
	return vessel.available_voyage_speed()

/datum/stationtrauma_overmap/submarine/get_response_time()
	var/drag = 6 * vessel.nominal_drive_thrust / max(1, vessel.cruise_speed)
	return max(1, vessel.navigation_mass) / drag

/datum/stationtrauma_overmap/submarine/stop(reason = "Стоп-машина")
	. = ..()
	if(QDELETED(vessel))
		return
	vessel.engines_running = FALSE
	vessel.stop_drive_output()
	SEND_SIGNAL(vessel, COMSIG_STATIONTRAUMA_NAVIGATION_CHANGED)

/datum/stationtrauma_overmap/submarine/on_collision(datum/stationtrauma_overmap_terrain/obstacle, impact_speed)
	var/list/point = obstacle.nearest(pos_x, pos_y)
	vessel.damage_navigation_hull(point[1] - pos_x, point[2] - pos_y, impact_speed)

/datum/stationtrauma_overmap/submarine/Destroy()
	vessel = null
	return ..()
