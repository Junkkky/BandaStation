/datum/floodwater_debug
	var/list/viewers = list()
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
		user.images -= SSfloodwater.debug.viewers[user]
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

/datum/floodwater_debug/proc/update_viewers()
	if(enabled && area)
		litres = 0
		for(var/turf/open/tile in area)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			if(water && !water.infinite_source)
				litres += tile.get_water_depth() * FLOOD_WATER_LITRES_PER_CM
	for(var/client/viewer as anything in viewers)
		if(QDELETED(viewer) || !viewer.mob)
			viewers -= viewer
			continue
		viewer.images -= viewers[viewer]
		var/list/images = list()
		for(var/turf/open/tile in range(12, viewer.mob))
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			var/image/label = image(loc = tile)
			SET_PLANE_EXPLICIT(label, BALLOON_CHAT_PLANE, tile)
			label.maptext = MAPTEXT("<span style='color:[water?.infinite_source ? "#37c7b7" : tile.get_water_depth() ? "#ffffff" : "#aaaaaa"];text-align:center'>[water?.infinite_source ? "∞" : round(tile.get_water_depth(), 0.1)]</span>")
			label.maptext_y = 8
			images += label
		viewers[viewer] = images
		viewer.images += images
