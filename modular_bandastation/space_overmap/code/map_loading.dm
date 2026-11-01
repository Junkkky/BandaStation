/** Ship and destination loader replacing space instead of stacking over it. */
/datum/map_template/stationtrauma_space
	should_place_on_top = FALSE

/** A failed map must release native loading gates before an outer caller handles the failure. */
/datum/parsed_map/load(x_offset = 0, y_offset = 0, z_offset = 0, crop_map = FALSE, no_changeturf = FALSE, x_lower = -INFINITY, x_upper = INFINITY, y_lower = -INFINITY, y_upper = INFINITY, z_lower = -INFINITY, z_upper = INFINITY, place_on_top = FALSE, new_z = FALSE)
	Master.StartLoadingMap()
	try
		. = _load_impl(x_offset, y_offset, z_offset, crop_map, no_changeturf, x_lower, x_upper, y_lower, y_upper, z_lower, z_upper, place_on_top, new_z)
	catch(var/exception/failure)
		SSatoms.map_loader_stop(REF(src))
		loading = FALSE
		bounds = null
		Master.StopLoadingMap()
		log_mapping("Failed to load map [original_path]: [failure] at [failure.file]:[failure.line]")
		return FALSE
	Master.StopLoadingMap()

/// Processing requests for template machines whose pipe networks are not ready yet.
/datum/controller/subsystem/air/var/list/initializing_machines = list()

/** Retain in-flight template requests when SSair is recreated. */
/datum/controller/subsystem/air/Recover()
	initializing_machines = SSair.initializing_machines
	return ..()

/** Keep a new template machine out of the live run until its networks have been built. */
/datum/controller/subsystem/air/start_processing_machine(obj/machinery/machine)
	if(!QDELETED(machine) && !isnull(initializing_machines[machine]))
		initializing_machines[machine] = TRUE
		return
	return ..()

/** Preserve a stop request made during template initialization, including destruction. */
/datum/controller/subsystem/air/stop_processing_machine(obj/machinery/machine)
	if(!isnull(initializing_machines[machine]))
		initializing_machines[machine] = FALSE
	return ..()

/** Native initialization yields before building pipe networks; defer only the newly loaded machines. */
/datum/map_template/initTemplateBounds(list/bounds)
	if(!bounds || !SSatoms.initialized)
		return ..()
	var/list/machines = list()
	for(var/turf/tile as anything in block(bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ], bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]))
		for(var/obj/machinery/machine in tile)
			if(QDELETED(machine) || (machine.flags_1 & INITIALIZED_1) || !isnull(SSair.initializing_machines[machine]))
				continue
			var/was_processing = machine.atmos_processing
			SSair.stop_processing_machine(machine)
			SSair.initializing_machines[machine] = was_processing
			machines += machine
	// An outer catch would bypass SSatoms cleanup when an individual atom fails to initialize.
	. = ..()
	for(var/obj/machinery/machine as anything in machines)
		var/requested = SSair.initializing_machines[machine]
		SSair.initializing_machines -= machine
		if(!QDELETED(src) && requested && !QDELETED(machine))
			SSair.start_processing_machine(machine)

/** Templates initialize their footprint; the traversable vacuum outside it also needs native space gas. */
/datum/map_template/stationtrauma_space/initTemplateBounds(list/bounds)
	if(bounds)
		for(var/z_level in bounds[MAP_MINZ] to bounds[MAP_MAXZ])
			stationtrauma_space_vacuum(z_level)
	return ..()

/** Initialize vacuum outside a loaded template's footprint. */
/proc/stationtrauma_space_vacuum(z_level)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/open/space/tile in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		tile.air ||= tile.space_gas
		budget.yield()
