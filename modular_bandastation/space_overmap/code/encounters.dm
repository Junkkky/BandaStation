/** Space effects stay local to the owner; no global round event or station-Z selection. */
/datum/stationtrauma_overmap/space
	var/list/zones = list()
	var/list/zone_timers = list()
	var/list/charted_zones = list()
	var/list/live_meteors = list()
	var/encounter_x = 0
	var/encounter_y = 0
	var/next_detection = 0
	var/next_scan = 0
	var/sensor_range = 600
	var/encounter_status = "Маршрут свободен"

/** Fixed regions with round-local variation; small location maps are still preloaded once. */
/datum/stationtrauma_overmap_sector/space/proc/build_encounters()
	zones += new /datum/stationtrauma_overmap_zone("Астероидный пояс / обломки", "asteroids", 1250, -450, 360)
	// A central full-speed crossing must outlast the warning instead of making every storm harmless.
	var/datum/stationtrauma_overmap_zone/stream = new("Метеорный поток", "meteors", -450 + rand(-60, 60), 260 + rand(-60, 60), 320)
	stream.direction = pick(45, 90, 135, 225, 270, 315)
	zones += stream
	zones += new /datum/stationtrauma_overmap_zone("Плотная туманность", "nebula", 260, 640, 230)
	for(var/list/offset as anything in list(list(0, 200), list(-180, 60), list(-170, -130), list(50, -190), list(210, -50), list(150, 150)))
		var/cx = 1250 + offset[1] + rand(-15, 15)
		var/cy = -450 + offset[2] + rand(-15, 15)
		contacts += new /datum/stationtrauma_overmap_terrain/asteroid(cx - 4, cy, cx + 4, cy)

/** Leaving the region cancels future emissions; already launched objects retain their bounded flight. */
/datum/stationtrauma_overmap/space/proc/process_encounters()
	if(docked || ship_docking || relocating || preparing)
		clear_encounters()
		return
	sensor_range = 600
	encounter_status = "Маршрут свободен"
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		var/inside = zone.crosses(encounter_x, encounter_y, pos_x, pos_y)
		if(!inside)
			zone_timers -= zone
			continue
		encounter_status = zone.name
		if(zone.kind == "nebula")
			sensor_range = 180
			continue
		if(isnull(zone_timers[zone]))
			zone_timers[zone] = world.time + 8 SECONDS
			navigation_notice("[zone.name]. Ожидаются обломки через восемь секунд.")
			for(var/mob/crew as anything in GLOB.player_list)
				if(vessel.is_in_shuttle_bounds(crew))
					SEND_SOUND(crew, sound('sound/machines/warning-buzzer.ogg'))
		if(world.time >= zone_timers[zone])
			var/is_stream = zone.kind == "meteors"
			launch_debris(is_stream, is_stream ? zone.direction : course)
			// Multi-minute journeys need occasional repairable impacts, not a sustained bombardment.
			var/interval = is_stream ? rand(90, 150) : rand(90, 150) / clamp(1 + speed / 5, 1, 3)
			zone_timers[zone] = world.time + interval SECONDS
		encounter_status = "[zone.name]: опасность столкновения с обломками"
	encounter_x = pos_x
	encounter_y = pos_y
	update_asteroids()
	if(world.time < next_detection)
		return
	next_detection = world.time + 1 SECONDS
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/space/site = sites[id]
		if(!site.needs_scan && !knows_site(site) && distance_to(site) <= sensor_range)
			discover_site(site)
			navigation_notice("Обнаружен контакт — [site.name].")

/** Rare entry/discovery notifications reach crew throughout the hull, not only near its port marker. */
/datum/stationtrauma_overmap/space/proc/navigation_notice(message)
	for(var/mob/crew as anything in GLOB.player_list)
		if(vessel.is_in_shuttle_bounds(crew))
			to_chat(crew, span_warning("Навигация: [message]"))

/** Both regions and close terrain are charted, without exposing undiscovered salvage. */
/datum/stationtrauma_overmap/space/proc/encounter_data()
	var/list/chart = list()
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		if(!charted_zones[zone])
			continue
		chart += list(list("name" = zone.name, "kind" = zone.kind, "x" = zone.pos_x, "y" = zone.pos_y, "radius" = zone.radius, "direction" = zone.direction))
	return chart

/datum/stationtrauma_overmap/space/proc/terrain_data()
	var/list/chart = list()
	for(var/datum/stationtrauma_overmap_terrain/terrain in contacts)
		var/list/point = terrain.nearest(pos_x, pos_y)
		if(terrain.blocking && (point[1] - pos_x) ** 2 + (point[2] - pos_y) ** 2 <= sensor_range ** 2)
			chart += list(list("x" = terrain.pos_x, "y" = terrain.pos_y, "end_x" = terrain.end_x, "end_y" = terrain.end_y))
	return chart

/** Cancel objects before a native relocation or safe docking, retaining chart and salvage state. */
/datum/stationtrauma_overmap/space/proc/clear_encounters()
	for(var/obj/effect/meteor/meteor as anything in live_meteors)
		UnregisterSignal(meteor, COMSIG_QDELETING)
	QDEL_LIST(live_meteors)
	for(var/datum/stationtrauma_overmap_terrain/asteroid/rock in contacts)
		rock.hide(src)
	zone_timers.Cut()
	encounter_x = pos_x
	encounter_y = pos_y
	sensor_range = 600
	encounter_status = "Маршрут свободен"

/datum/stationtrauma_overmap/space/proc/forget_meteor(datum/source)
	SIGNAL_HANDLER
	live_meteors -= source

/** Native movement, projectile interception and turf damage; six objects maximum per ship. */
/datum/stationtrauma_overmap/space/proc/launch_debris(dangerous, bearing)
	if(docked || relocating || preparing || length(live_meteors) >= 6)
		return null
	var/list/bounds = vessel.return_coords()
	var/cx = round((bounds[1] + bounds[3]) / 2)
	var/cy = round((bounds[2] + bounds[4]) / 2)
	var/rotation = bearing - course + dir2angle(vessel.preferred_direction)
	var/dx = sin(rotation)
	var/dy = cos(rotation)
	var/reach = max(vessel.width, vessel.height) / 2 + 10
	var/offset = rand(-8, 8)
	var/turf/start = locate(cx + round(dx * reach - dy * offset), cy + round(dy * reach + dx * offset), vessel.z)
	var/turf/goal = locate(cx - round(dx * reach + dy * offset), cy - round(dy * reach - dx * offset), vessel.z)
	if(!isspaceturf(start) || !goal)
		return null
	var/meteor_type = dangerous ? /obj/effect/meteor/stationtrauma : /obj/effect/meteor/sand/stationtrauma
	var/obj/effect/meteor/meteor = new meteor_type(start, goal)
	if(QDELETED(meteor))
		return null
	live_meteors += meteor
	RegisterSignal(meteor, COMSIG_QDELETING, PROC_REF(forget_meteor))
	return meteor

/obj/effect/meteor/stationtrauma
	name = "обломок астероида"
	hits = 1
	hitpwr = EXPLODE_HEAVY
	lifetime = 12
	dropamt = 1

/obj/effect/meteor/sand/stationtrauma
	name = "мелкий космический обломок"
	hits = 1
	lifetime = 12
