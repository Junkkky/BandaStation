/** Powered prototype decks; power generation is outside this navigation prototype. */
/area/shuttle/stationtrauma/prototype
	name = "Нырок: нижняя палуба"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/area/shuttle/stationtrauma/prototype/middle
	name = "Нырок: шлюзовая палуба"

/area/shuttle/stationtrauma/prototype/upper
	name = "Нырок: мостик"

/area/shuttle/stationtrauma/prototype/chamber
	name = "Нырок: шлюзовая камера"
	stationtrauma_flood_exempt = TRUE

/** Small fixtures outside the berth remain at their own destination. */
/area/stationtrauma_voyage_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/area/stationtrauma_voyage_site/harbor
	name = "Гавань: причальная станция"

/area/stationtrauma_voyage_site/outpost
	name = "Исследовательский пост"

/area/stationtrauma_voyage_site/ruins
	name = "Затопленные руины"

/** Mapped reservation, including water cells around exterior hull-mounted machinery. */
/area/space/ocean/stationtrauma_berth
	name = "Стоянка подлодки"

/** Permanent three-deck ocean surrounding the stationary submarine. */
/area/space/ocean/stationtrauma_berth/home
	name = "Океан подлодки"

/** Three connected levels at each destination share the same clearance envelope. */
/obj/docking_port/stationary/stationtrauma
	name = "Гавань"
	shuttle_id = "stationtrauma_harbor"
	area_type = /area/space/ocean/stationtrauma_berth
	width = 17
	height = 11
	/// Position along the prototype route, in metres; unrelated to its storage z-level.
	var/route_position = 0
	/// Northing on the virtual ocean chart; physical Z is not a world coordinate.
	var/route_y = 0
	/// Known charted destinations are listed immediately; other sites require an active sensor return.
	var/route_known = TRUE
	/// Zero keeps the distant ocean corridor; positive tile counts allow a near-hull seam on this map.
	var/ship_ocean_clearance = 0
	/// Distance from this site's berth to its own seam; independent of the vessel-side distance.
	var/site_ocean_clearance = 0

/obj/docking_port/stationary/stationtrauma/outpost
	name = "Исследовательский пост"
	shuttle_id = "stationtrauma_outpost"
	route_position = 1500
	route_y = 600

/obj/docking_port/stationary/stationtrauma/ruins
	name = "Затопленные руины"
	shuttle_id = "stationtrauma_ruins"
	route_position = 3500
	route_y = -450

/** Small close-range exploration site, using the same persistent loader as charted destinations. */
/obj/docking_port/stationary/stationtrauma/rock
	name = "Скальный выход"
	shuttle_id = "stationtrauma_rock"
	route_position = -650
	route_y = 120
	route_known = FALSE
	ship_ocean_clearance = 1
	site_ocean_clearance = 1

/** Permanent placement anchor; it is never offered as a navigation destination. */
/obj/docking_port/stationary/stationtrauma/home
	name = "Океан подлодки"
	shuttle_id = "stationtrauma_home"
	area_type = /area/space/ocean/stationtrauma_berth/home

/** A module-owned navigation console with a live route display. */
/obj/machinery/computer/stationtrauma_navigation
	name = "навигация «Нырка»"
	desc = "Выбор размеченной стоянки для трёхпалубной подлодки."
	icon = 'modular_bandastation/underwater_submarine/icons/navigation.dmi'
	icon_state = "navigation"
	icon_screen = null
	icon_keyboard = null
	generate_map_preview = FALSE
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	processing_flags = NONE
	light_color = "#79c96b"
	brightness_on = 2
	use_power = NO_POWER_USE
	/// The loader links the console to this particular vessel, never a global shuttle ID lookup.
	var/obj/docking_port/mobile/stationtrauma/vessel

/** Load each location once; the same command lock covers its preparation and prevents duplicate levels. */
/obj/docking_port/mobile/stationtrauma/proc/load_destination(destination, preload = FALSE)
	if((!travelling && !preload) || SSfloodwater.loading_ocean_levels.len || SSfloodwater.loading_structure_turfs.len)
		return null
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in berths)
		if(berth.name == destination)
			return berth
	var/template_path = unloaded_destinations[destination]
	if(!template_path)
		return null
	// A failed native load can leave allocated levels; do not duplicate them on another click.
	unloaded_destinations -= destination
	overmap.status = "В пути: [destination]"
	var/datum/map_template/stationtrauma_route/template
	var/obj/docking_port/stationary/stationtrauma/loaded_berth
	var/exception/load_error
	try
		template = new template_path
		template.loading_progress = CALLBACK(src, PROC_REF(update_loading_progress))
		var/datum/space_level/bottom = template.load_new_z()
		if(bottom)
			for(var/obj/docking_port/stationary/stationtrauma/berth as anything in SSshuttle.stationary_docking_ports)
				if(berth.z == bottom.z_value && istype(berth, template.destination_berth_type))
					loaded_berth = berth
					break
	catch(var/exception/failure)
		load_error = failure
	qdel(template)
	if(load_error)
		stack_trace("StationTrauma destination failed: [load_error]")
	if(!loaded_berth)
		overmap.status = "Ошибка загрузки: [destination]. Требуется перезапуск прототипа."
		return null
	berths += loaded_berth
	overmap.status = "В пути: [destination]"
	return loaded_berth

/** Reuse the connected-stack ocean loader; each TGM remains an ordinary editable three-deck map. */
/datum/map_template/stationtrauma_route
	/// The mapped berth subtype owns route metadata for destinations that have not loaded yet.
	var/destination_berth_type = /obj/docking_port/stationary/stationtrauma

/datum/map_template/stationtrauma_route/voyage_harbor
	name = "StationTrauma harbor"
	mappath = 'modular_bandastation/underwater_submarine/maps/voyage_harbor.dmm'
	compact_ocean = TRUE

/datum/map_template/stationtrauma_route/voyage_home
	name = "StationTrauma permanent ocean"
	mappath = 'modular_bandastation/underwater_submarine/maps/voyage_home.dmm'
	destination_berth_type = /obj/docking_port/stationary/stationtrauma/home
	exterior_ocean_area = /area/space/ocean/stationtrauma_berth/home

/datum/map_template/stationtrauma_route/voyage_outpost
	name = "StationTrauma research outpost"
	mappath = 'modular_bandastation/underwater_submarine/maps/voyage_outpost.dmm'
	compact_ocean = TRUE
	destination_berth_type = /obj/docking_port/stationary/stationtrauma/outpost

/datum/map_template/stationtrauma_route/voyage_ruins
	name = "StationTrauma flooded ruins"
	mappath = 'modular_bandastation/underwater_submarine/maps/voyage_ruins.dmm'
	compact_ocean = TRUE
	destination_berth_type = /obj/docking_port/stationary/stationtrauma/ruins

/** A small persistent resource scene with close transitions and only the necessary ocean view margin. */
/datum/map_template/stationtrauma_route/voyage_rock
	name = "StationTrauma rock outcrop"
	mappath = 'modular_bandastation/underwater_submarine/maps/voyage_rock.dmm'
	compact_ocean = TRUE
	ocean_margin = 1
	destination_berth_type = /obj/docking_port/stationary/stationtrauma/rock

/datum/map_template/stationtrauma_vessel
	name = "StationTrauma three-deck submarine"
	mappath = 'modular_bandastation/underwater_submarine/maps/voyage_submarine.dmm'
	should_place_on_top = FALSE

/** Generic templates deliberately skip mobile ports; initialize ours after all three decks exist. */
/datum/map_template/stationtrauma_vessel/load(turf/origin, centered = FALSE)
	if(!origin || SSfloodwater.loading_structure_turfs.len || SSfloodwater.loading_ocean_levels.len)
		return FALSE
	var/deadline = world.time + 10 SECONDS
	while(SSfloodwater.step_running && world.time < deadline)
		sleep(world.tick_lag)
	if(SSfloodwater.step_running || SSfloodwater.loading_structure_turfs.len || SSfloodwater.loading_ocean_levels.len)
		return FALSE
	var/turf/anchor = centered ? locate(origin.x - round(width / 2), origin.y - round(height / 2), origin.z) : origin
	if(!anchor || anchor.x + width - 1 > world.maxx || anchor.y + height - 1 > world.maxy || anchor.z + 2 > world.maxz)
		return FALSE
	for(var/turf/tile as anything in block(anchor, locate(anchor.x + width - 1, anchor.y + height - 1, anchor.z + 2)))
		SSfloodwater.loading_structure_turfs[tile] = TRUE
	var/exception/load_error
	try
		. = ..()
		var/obj/docking_port/mobile/stationtrauma/port = locate() in anchor
		if(. && port)
			SSatoms.InitializeAtoms(list(port))
	catch(var/exception/failure)
		load_error = failure
		. = FALSE
	SSfloodwater.loading_structure_turfs.Cut()
	if(load_error)
		stack_trace("StationTrauma vessel template failed: [load_error]")

GLOBAL_VAR_INIT(stationtrauma_voyage_loaded, FALSE)

/** Load the permanent vessel and every small destination before admitting departures. */
ADMIN_VERB(stationtrauma_load_fixed_voyage, R_DEBUG, "StationTrauma - Load Fixed Voyage Prototype", "Load a permanent submarine with distant ocean passages; no vessel transfers during travel.", ADMIN_CATEGORY_DEBUG)
	load_stationtrauma_voyage(user)

/** One permanent submarine is admitted per round. */
/proc/load_stationtrauma_voyage(user)
	if(GLOB.stationtrauma_voyage_loaded)
		to_chat(user, span_warning("Прототип уже загружается или загружен."), confidential = TRUE)
		return
	GLOB.stationtrauma_voyage_loaded = TRUE
	to_chat(user, span_notice("Загружаются гавань и подлодка. Дождись сообщения о готовности."), confidential = TRUE)
	var/list/berths = list()
	var/datum/map_template/stationtrauma_route/voyage_harbor/template = new
	var/datum/space_level/bottom = template.load_new_z()
	qdel(template)
	if(!bottom)
		to_chat(user, span_warning("Не удалось загрузить гавань. Повторная загрузка отключена до перезапуска."), confidential = TRUE)
		return
	for(var/obj/docking_port/stationary/stationtrauma/berth as anything in SSshuttle.stationary_docking_ports)
		if(berth.z == bottom.z_value)
			berths += berth
	if(berths.len != 1)
		to_chat(user, span_warning("На карте гавани не найдена единственная стоянка."), confidential = TRUE)
		return
	var/datum/map_template/stationtrauma_route/voyage_home/ocean = new
	var/datum/space_level/home_stack = ocean.load_new_z()
	qdel(ocean)
	if(!home_stack)
		to_chat(user, span_warning("Не удалось подготовить постоянный океан лодки."), confidential = TRUE)
		return
	var/obj/docking_port/stationary/stationtrauma/home/start
	for(var/obj/docking_port/stationary/stationtrauma/home/anchor as anything in SSshuttle.stationary_docking_ports)
		if(anchor.z == home_stack.z_value)
			start = anchor
			break
	if(!start)
		to_chat(user, span_warning("В постоянном океане не найдена разметка лодки."), confidential = TRUE)
		return
	var/datum/map_template/stationtrauma_vessel/boat = new
	var/loaded = boat.load(get_turf(start), centered = FALSE)
	qdel(boat)
	var/obj/docking_port/mobile/stationtrauma/vessel = locate() in get_turf(start)
	if(!loaded || !vessel)
		to_chat(user, span_warning("Не удалось загрузить подлодку."), confidential = TRUE)
		return
	if(!vessel.configure_berths(berths))
		to_chat(user, span_warning("Разметка подлодки не соответствует её габаритам."), confidential = TRUE)
		return
	vessel.fixed_location = berths[1]
	vessel.overmap = new(vessel)
	vessel.overmap.preload_destinations()
	vessel.set_fixed_parallax(NONE)
	if(!vessel.connect_ocean_location(vessel.fixed_location))
		to_chat(user, span_warning("Не удалось открыть проход к гавани: проверьте свободный океанский коридор."), confidential = TRUE)
		return
	to_chat(user, span_notice("Прототип готов. Подлодка «Нырок»: ([vessel.x], [vessel.y], [vessel.z]); мостик на z=[vessel.z + 2]."), confidential = TRUE)
