/datum/floodwater_debug
	var/list/viewers = list()
	/// Administrators waiting for a single click report; no per-tick processing.
	var/list/click_viewers = list()
	var/next_update = 0
	/// Optional counters; disabled during normal play.
	var/enabled = FALSE
	var/cpu_ms = 0
	var/max_slice_ms = 0
	var/list/phase_ms = list()
	var/phase_name
	var/phase_started = 0
	var/steps = 0
	var/tiles = 0
	var/edges = 0
	var/cell_updates = 0
	var/stage_updates = 0
	var/bfs = 0
	var/bfs_tiles = 0
	var/wakes = 0
	var/wake_requests = 0
	var/area/area
	var/litres = 0

/datum/floodwater_debug/proc/reset()
	cpu_ms = 0
	max_slice_ms = 0
	phase_ms.Cut()
	phase_name = null
	phase_started = 0
	steps = 0
	tiles = 0
	edges = 0
	cell_updates = 0
	stage_updates = 0
	bfs = 0
	bfs_tiles = 0
	wakes = 0
	wake_requests = 0


/// Close each slice before yielding so time spent paused is never charged to a phase.
/datum/floodwater_debug/proc/measure_phase(name)
	var/now = TICK_USAGE_REAL
	if(phase_name)
		phase_ms[phase_name] += TICK_DELTA_TO_MS(now - phase_started)
	phase_name = name
	phase_started = now

/datum/floodwater_debug/proc/statistics()
	var/result = " CPU:[round(cpu_ms, 0.01)]ms MaxSlice:[round(max_slice_ms, 0.01)]ms Microsteps:[steps] Tiles:[tiles] Edges:[edges] Cells:[cell_updates] Stages:[stage_updates] BFS:[bfs]/[bfs_tiles] Wakes:[wakes]/[wake_requests] Volume:[round(litres, 0.01)]L"
	for(var/name as anything in phase_ms)
		result += " [name]:[round(phase_ms[name], 0.01)]ms"
	return result

ADMIN_VERB(stationtrauma_water_debug, R_DEBUG, "Water Depth Debug", "Toggle live water depths in centimetres on nearby turfs.", ADMIN_CATEGORY_DEBUG)
	if(SSfloodwater.debug.viewers[user])
		SSfloodwater.debug.clear_viewer(user)
		SSfloodwater.debug.viewers -= user
		to_chat(user, span_notice("Отображение глубины воды выключено."))
	else
		SSfloodwater.debug.viewers[user] = list()
		SSfloodwater.debug.update_viewers()
		to_chat(user, span_notice("Отображение глубины воды включено: см; ∞ — океан. Обновление дважды в секунду."))
	BLACKBOX_LOG_ADMIN_VERB("Water Depth Debug")

ADMIN_VERB(stationtrauma_water_statistics, R_DEBUG, "Water Performance Debug", "Toggle Floodwater counters and finite volume in your current area.", ADMIN_CATEGORY_DEBUG)
	if(SSfloodwater.debug.enabled)
		to_chat(user, span_notice(SSfloodwater.debug.statistics()))
	SSfloodwater.debug.enabled = !SSfloodwater.debug.enabled
	SSfloodwater.debug.area = SSfloodwater.debug.enabled ? get_area(user.mob) : null
	SSfloodwater.debug.reset()
	to_chat(user, span_notice("Floodwater counters [SSfloodwater.debug.enabled ? "enabled" : "disabled"]. See the MC stat tab; disabling prints the latest snapshot here. Volume excludes ocean reservoirs."))
	BLACKBOX_LOG_ADMIN_VERB("Water Performance Debug")

ADMIN_VERB(stationtrauma_water_click_debug, R_DEBUG, "Water Click Debug", "Report the next map click and nearby physical objects without changing them.", ADMIN_CATEGORY_DEBUG)
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	if(user in debug.click_viewers)
		debug.clear_click_viewer(user)
		to_chat(user, span_notice("Water click diagnostic cancelled."))
		return
	debug.click_viewers += user
	debug.RegisterSignal(user, COMSIG_CLIENT_CLICK, TYPE_PROC_REF(/datum/floodwater_debug, report_click))
	debug.RegisterSignal(user, COMSIG_QDELETING, TYPE_PROC_REF(/datum/floodwater_debug, clear_click_viewer))
	to_chat(user, span_notice("Water click diagnostic armed: click the affected tile once. The report appears here and in the game log."))
	BLACKBOX_LOG_ADMIN_VERB("Water Click Debug")

/// Unsubscribe after one report, cancellation or disconnection.
/datum/floodwater_debug/proc/clear_click_viewer(client/viewer)
	SIGNAL_HANDLER
	UnregisterSignal(viewer, list(COMSIG_CLIENT_CLICK, COMSIG_QDELETING))
	click_viewers -= viewer

/// Observe the client target before normal click handling, without intercepting it.
/datum/floodwater_debug/proc/report_click(client/source, atom/target, atom/location, control, params, mob/user)
	SIGNAL_HANDLER
	if(istype(target, /atom/movable/screen))
		return
	clear_click_viewer(source)
	if(!check_rights_for(source, R_DEBUG))
		return
	var/turf/tile = get_turf(target)
	if(!tile)
		tile = get_turf(location)
	var/list/report = list("WaterClick target=[target?.type] ref=[REF(target)] loc=[target?.loc] tile=[COORD(tile)] control=[control] params=[params]")
	if(tile)
		var/turf/open/open_tile = isopenturf(tile) ? tile : null
		report += "Tile depth=[open_tile?.get_water_depth()] obscured=[tile.IsObscured()] contents=[length(tile.contents)] user=[COORD(user)] see_invisible=[user?.see_invisible]"
		for(var/turf/nearby as anything in RANGE_TURFS(1, tile))
			for(var/atom/movable/thing as anything in nearby)
				if(nearby != tile && !isitem(thing) && !(thing.flags_1 & PREVENT_CLICK_UNDER_1))
					continue
				var/turf/pixel_tile = get_turf_pixel(thing)
				report += "[thing.type] ref=[REF(thing)] loc=[COORD(nearby)] pixel_tile=[COORD(pixel_tile)] mouse=[thing.mouse_opacity] invisible=[thing.invisibility] obscured=[thing.IsObscured()] density=[thing.density] blocks_click=[!!(thing.flags_1 & PREVENT_CLICK_UNDER_1)] layer=[thing.layer] plane=[thing.plane] filters=[length(thing.filters)] vis=[length(thing.vis_contents)]"
				for(var/atom/movable/immerse_mask/mask in thing.vis_contents)
					report += "Immersion relay owner=[REF(thing)] mouse=[mask.mouse_opacity] alpha=[mask.alpha] target=[mask.render_target] vis_flags=[mask.vis_flags] appearance_flags=[mask.appearance_flags]"
	for(var/line in report)
		log_game(line)
		to_chat(source, span_notice(html_encode(line)))

/// Remove private label visuals as well as their images when refreshing or disabling the display.
/datum/floodwater_debug/proc/clear_viewer(client/viewer)
	if(!QDELETED(viewer))
		viewer.images -= viewers[viewer]
	for(var/image/label as anything in viewers[viewer])
		for(var/obj/effect/overlay/vis/text as anything in label.vis_contents)
			qdel(text)
	viewers[viewer] = list()

/datum/floodwater_debug/proc/update_viewers()
	if(enabled && area)
		litres = 0
		for(var/turf/open/tile in area)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			if(water && !water.infinite_source)
				litres += tile.get_water_depth() * FLOOD_WATER_LITRES_PER_CM
	for(var/client/viewer as anything in viewers)
		if(QDELETED(viewer) || !viewer.mob)
			clear_viewer(viewer)
			viewers -= viewer
			continue
		var/list/labels_by_turf = list()
		for(var/image/label as anything in viewers[viewer])
			labels_by_turf[label.loc] = label
		var/list/images = list()
		var/list/added_images = list()
		for(var/turf/open/tile in range(12, viewer.mob))
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			var/image/label = labels_by_turf[tile]
			var/obj/effect/overlay/vis/text
			if(!label)
				label = image(loc = tile)
				text = new
				label.vis_contents += text
				added_images += label
			else
				text = label.vis_contents[1]
			labels_by_turf -= tile
			// Image overlays inherit turf clicks; a separate visual lets clicks pass through the digits.
			SET_PLANE_EXPLICIT(text, BALLOON_CHAT_PLANE, tile)
			text.layer = label.layer
			var/depth = water?.infinite_source ? null : tile.get_water_depth()
			var/maptext = MAPTEXT("<span style='color:[water?.infinite_source ? "#37c7b7" : depth ? "#ffffff" : "#aaaaaa"];text-align:center'>[water?.infinite_source ? "∞" : round(depth, 0.1)]</span>")
			if(text.maptext != maptext)
				text.maptext = maptext
			text.maptext_y = 8
			images += label
		// Only labels that left the visible range are retired; stationary labels reuse their visuals.
		var/list/removed_images = list()
		for(var/turf/tile as anything in labels_by_turf)
			var/image/label = labels_by_turf[tile]
			removed_images += label
			for(var/obj/effect/overlay/vis/text as anything in label.vis_contents)
				qdel(text)
		viewers[viewer] = images
		if(length(removed_images))
			viewer.images -= removed_images
		if(length(added_images))
			viewer.images += added_images
