/**
 * # Terrain survey
 *
 * A ship lands on a planet only after its crew has surveyed it from orbit: probes launched from the survey console
 * cover both faces of the planet, then the data is mapped into a schematic of the surface with its landing pads.
 * The first probe starts generating the planet, so the generation is hidden inside the survey and the landing
 * itself is short.
 *
 * Probes fly a real ballistic path, worked out here; the console only draws it. The planet is a unit sphere at the
 * origin, its front face towards the viewer (+z). Seen from the back the same picture is turned half round the
 * vertical axis.
 */

/// Probe ballistics, also sent to the console's aim preview (see ui_static_data()).
/**
 * The ship's orbit is tilted towards the viewer, passing in front of the planet below it and behind it above; the
 * launcher hangs at the orbit's lowest point, but a probe leaves it moving along the orbit with the ship: the throw at
 * the cursor adds to that, and gravity bends the sum round the planet. A probe thrown straight at the middle drifts
 * along the orbit before it strikes; one thrown weak swings far round, over the top of the planet; one thrown hard and
 * forward flies past.
 */
#define SURVEY_ORBIT_RADIUS 2
/// How far the orbit is tilted towards the viewer, in degrees
#define SURVEY_ORBIT_TILT 30
#define SURVEY_GRAVITY 1.2
/// Share of the ship's orbital speed a probe keeps as it leaves the launcher
#define SURVEY_DRIFT 0.75
#define SURVEY_STEP 0.02
#define SURVEY_STEPS 900
/// A probe this far from the planet's centre is lost in space
#define SURVEY_ESCAPE 8
#define SURVEY_SPEED_MIN 0.2
#define SURVEY_SPEED_MAX 1.6
/// The furthest from the planet's centre a probe may be aimed, in planet radii
#define SURVEY_AIM_LIMIT 2.4
/// Every this many steps a point of a flight is kept for the screen
#define SURVEY_PATH_STRIDE 10
/// Real time per unit of simulated flight: flights take three to nine seconds
#define SURVEY_TIME_SCALE (2.5 SECONDS)
#define SURVEY_RELOAD (3 SECONDS)
/// Most probes in flight at once
#define SURVEY_MAX_FLIGHTS 6
/// Angular radius of the ground a probe reads, in degrees: an ideal survey of the whole planet takes about eleven probes
#define SURVEY_FOOTPRINT 35
/// Shares of the planet read at which the survey tells more: the biome and air; then the climate and caves, and enough
/// to map and land; then the ore and the planet's peculiarities; then everything, structures and life included
#define SURVEY_TIER_BASIC 0.3
#define SURVEY_TIER_LAND 0.5
#define SURVEY_TIER_DEEP 0.7
#define SURVEY_GOAL 0.9
/// Probes a ship has for one planet
#define SURVEY_PROBE_LIMIT 14
/// Time between two data disks written by one console
#define SURVEY_DISK_COOLDOWN (20 SECONDS)
/// Points the coverage is measured on, spread evenly over the sphere
#define SURVEY_SAMPLES 600
#define SURVEY_MAPPING_TIME (1 MINUTES)

/// Whether mapping takes its full time; an admin can switch it off for the round
GLOBAL_VAR_INIT(stationtrauma_survey_mapping_timer, TRUE)

/// Evenly spread points on the unit sphere, each list(x, y, z)
GLOBAL_LIST_INIT(stationtrauma_survey_samples, stationtrauma_survey_samples())

/proc/stationtrauma_survey_samples()
	. = list()
	var/turn = 180 * (3 - sqrt(5))
	for(var/index in 0 to SURVEY_SAMPLES - 1)
		var/y = 1 - 2 * (index + 0.5) / SURVEY_SAMPLES
		var/ring = sqrt(1 - y * y)
		. += list(list(ring * cos(turn * index), y, ring * sin(turn * index)))

/**
 * Flies one probe thrown from the launcher at [aim_x], [aim_y] on the planet's face with [power] (0-1), as seen from the
 * front. Returns list(path, steps, impact): the kept points of the flight, each list(x, y, z), how many steps it took, and
 * the point on the sphere it struck, or null if it missed.
 */
/proc/stationtrauma_survey_flight(aim_x, aim_y, power)
	var/x = 0
	var/y = -SURVEY_ORBIT_RADIUS * cos(SURVEY_ORBIT_TILT)
	var/z = SURVEY_ORBIT_RADIUS * sin(SURVEY_ORBIT_TILT)
	// aimed at the point of the face under the cursor, or at the planet's plane past its rim
	var/aim_z = sqrt(max(0, 1 - aim_x * aim_x - aim_y * aim_y))
	var/dx = aim_x - x
	var/dy = aim_y - y
	var/dz = aim_z - z
	var/speed = (SURVEY_SPEED_MIN + power * (SURVEY_SPEED_MAX - SURVEY_SPEED_MIN)) / sqrt(dx * dx + dy * dy + dz * dz)
	// the probe keeps part of the ship's motion along its orbit, which at the bottom runs to the right
	var/vx = dx * speed + SURVEY_DRIFT * sqrt(SURVEY_GRAVITY / SURVEY_ORBIT_RADIUS)
	var/vy = dy * speed
	var/vz = dz * speed
	var/list/path = list(list(x, y, z))
	for(var/step in 1 to SURVEY_STEPS)
		var/reach = sqrt(x * x + y * y + z * z)
		var/pull = SURVEY_GRAVITY / (reach * reach * reach)
		vx -= x * pull * SURVEY_STEP
		vy -= y * pull * SURVEY_STEP
		vz -= z * pull * SURVEY_STEP
		x += vx * SURVEY_STEP
		y += vy * SURVEY_STEP
		z += vz * SURVEY_STEP
		reach = sqrt(x * x + y * y + z * z)
		if(reach <= 1)
			var/list/impact = list(x / reach, y / reach, z / reach)
			path += list(impact)
			return list(path, step, impact)
		if(!(step % SURVEY_PATH_STRIDE))
			path += list(list(x, y, z))
		if(reach > SURVEY_ESCAPE)
			return list(path, step, null)
	return list(path, SURVEY_STEPS, null)

/// One ship's survey of one planet
/datum/stationtrauma_planet_survey
	var/datum/stationtrauma_overmap/space/navigation
	var/datum/stationtrauma_overmap_site/space/planet/planet
	/// Where probes struck, each list(x, y, z) on the sphere
	var/list/hits = list()
	/// Sample index -> TRUE once a probe has read it
	var/list/covered
	/// Share of the planet read
	var/coverage = 0
	/// Probes launched, misses included
	var/probes = 0
	/// Flight number as text -> list("path", "launched", "duration")
	var/list/flights = list()
	var/flight_count = 0
	var/next_launch = 0
	/// world.time mapping began, the probing over; zero before
	var/covered_at = 0
	/// Mapped from a full survey: the schematic shows structures and life
	var/efficient = FALSE
	/// The schematic as this survey saw it, cut to the ground its probes read; made once mapping is done
	var/list/schematic
	/// The console that launched the last probe, which pings when a probe reads the ground
	var/datum/weakref/console_ref

/datum/stationtrauma_planet_survey/New(datum/stationtrauma_overmap/space/navigation, datum/stationtrauma_overmap_site/space/planet/planet)
	src.navigation = navigation
	src.planet = planet
	covered = new /list(SURVEY_SAMPLES)
	return ..()

/datum/stationtrauma_planet_survey/Destroy(force)
	navigation = null
	planet = null
	flights = null
	schematic = null
	return ..()

/**
 * Launches a probe aimed at [aim_x], [aim_y] with [power], at the back face if [back_side]. The first probe sets the
 * planet's generation going. Returns FALSE if the launcher is not ready.
 */
/datum/stationtrauma_planet_survey/proc/launch(aim_x, aim_y, power, back_side)
	if(covered_at || probes >= SURVEY_PROBE_LIMIT || world.time < next_launch || length(flights) >= SURVEY_MAX_FLIGHTS)
		return FALSE
	next_launch = world.time + SURVEY_RELOAD
	probes++
	if(planet.awaits_map() && !planet.loading_map)
		INVOKE_ASYNC(planet, TYPE_PROC_REF(/datum/stationtrauma_overmap_site/space, load_map))
	var/list/flight = stationtrauma_survey_flight(aim_x, aim_y, power)
	var/list/path = flight[1]
	var/list/impact = flight[3]
	if(back_side)
		for(var/list/point as anything in path)
			point[1] = -point[1]
			point[3] = -point[3]
		// the impact is the last point of the path, already turned
	var/duration = max(1, round(flight[2] * SURVEY_STEP * SURVEY_TIME_SCALE))
	var/id = "[++flight_count]"
	flights[id] = list("path" = path, "launched" = world.time, "duration" = duration)
	addtimer(CALLBACK(src, PROC_REF(land), id, impact), duration, TIMER_DELETE_ME)
	return TRUE

/// A probe reaches the end of its flight: it reads the ground if it struck it and the ship is still on station
/datum/stationtrauma_planet_survey/proc/land(id, list/impact)
	flights -= id
	if(covered_at)
		return
	if(impact && !QDELETED(navigation) && navigation.survey_target() == planet)
		read_ground(impact)
	// mapping starts by itself on a full survey, or once the last probe is down with enough of the planet read
	if(coverage >= SURVEY_GOAL || (probes >= SURVEY_PROBE_LIMIT && !length(flights) && coverage >= SURVEY_TIER_LAND))
		begin_mapping()

/// A probe struck [impact]: the ground around it is read
/datum/stationtrauma_planet_survey/proc/read_ground(list/impact)
	hits += list(impact)
	var/obj/machinery/computer/stationtrauma_planet_survey/console = console_ref?.resolve()
	if(console)
		playsound(console, 'sound/machines/sonar-ping.ogg', 30, FALSE, -3)
	var/reach = cos(SURVEY_FOOTPRINT)
	var/list/samples = GLOB.stationtrauma_survey_samples
	var/read = 0
	for(var/index in 1 to length(samples))
		var/list/sample = samples[index]
		if(!covered[index] && sample[1] * impact[1] + sample[2] * impact[2] + sample[3] * impact[3] >= reach)
			covered[index] = TRUE
		read += !!covered[index]
	coverage = read / length(samples)

/// End the probing and map what was read. FALSE if too little of the planet is read to map it.
/datum/stationtrauma_planet_survey/proc/begin_mapping()
	if(covered_at || coverage < SURVEY_TIER_LAND)
		return FALSE
	covered_at = world.time
	efficient = coverage >= SURVEY_GOAL
	flights.Cut()
	return TRUE

/// What the survey tells of the planet, as far as the ground read goes
/datum/stationtrauma_planet_survey/proc/facts()
	var/list/all = planet.survey_data()
	. = list()
	if(coverage >= SURVEY_TIER_BASIC)
		.["biome"] = all["biome"]
		.["atmosphere"] = all["atmosphere"]
	if(coverage >= SURVEY_TIER_LAND)
		.["temperature"] = all["temperature"]
		.["breathable"] = all["breathable"]
		.["caves"] = all["caves"]
	if(coverage >= SURVEY_TIER_DEEP)
		.["ore"] = all["ore"]
		.["modifiers"] = all["modifiers"]

/**
 * The planet's schematic as this survey saw it: the surface square lies inscribed in the front face, so a cell shows
 * only where the probes read the ground over it ("?" elsewhere). Cave entrances in the dark are left out, structures
 * and life are shown only for a full survey; the landing pads are always shown. Made once, when mapping is done.
 */
/datum/stationtrauma_planet_survey/proc/survey_schematic()
	if(schematic || !mapped() || !planet.survey_map)
		return schematic
	var/list/full = planet.survey_map
	var/list/rows = full["rows"]
	var/cells = length(rows)
	var/reach = cos(SURVEY_FOOTPRINT)
	var/list/seen_rows = list()
	for(var/row_index in 1 to cells)
		var/row = rows[row_index]
		var/list/seen = list()
		for(var/cell in 1 to length(row))
			seen += survey_reads(cell / cells - 0.5 / cells, 1 - (row_index - 0.5) / cells, reach) ? copytext(row, cell, cell + 1) : "?"
		seen_rows += seen.Join("")
	var/list/caves = list()
	for(var/list/cave as anything in full["caves"])
		if(survey_reads(cave[1], cave[2], reach))
			caves += list(cave)
	var/list/pads = list()
	for(var/list/pad as anything in full["pads"])
		pads += list(list("rect" = pad.Copy(1, 5), "label" = survey_pad_label(pad, efficient)))
	schematic = list("rows" = seen_rows, "pads" = pads, "caves" = caves)
	if(efficient)
		schematic["structures"] = full["structures"]
		schematic["organic"] = full["organic"]
	return schematic

/// Whether the probes read the ground at [x], [y] of the surface square (shares from its south-west corner)
/datum/stationtrauma_planet_survey/proc/survey_reads(x, y, reach)
	var/u = (x - 0.5) * sqrt(2)
	var/v = (y - 0.5) * sqrt(2)
	var/w = sqrt(max(0, 1 - u * u - v * v))
	for(var/list/hit as anything in hits)
		if(u * hit[1] + v * hit[2] + w * hit[3] >= reach)
			return TRUE
	return FALSE

/// A saved map for the archive and the data disks: what this survey learned of its planet
/datum/stationtrauma_planet_survey/proc/record()
	return list(
		"name" = navigation?.site_label(planet) || planet.name,
		"coverage" = coverage,
		"facts" = facts(),
		"schematic" = survey_schematic(),
	)

/// How far mapping has got, 0-1
/datum/stationtrauma_planet_survey/proc/mapping_progress()
	if(!covered_at)
		return 0
	if(!GLOB.stationtrauma_survey_mapping_timer)
		return 1
	return clamp((world.time - covered_at) / SURVEY_MAPPING_TIME, 0, 1)

/// The planet has been generated and is fit to land on
/datum/stationtrauma_planet_survey/proc/planet_ready()
	return !QDELETED(planet) && !planet.failed && !planet.awaits_map() && !planet.loading_map

/// Mapping is done: the crew has the schematic and the landing pads
/datum/stationtrauma_planet_survey/proc/mapped()
	return covered_at && mapping_progress() >= 1 && planet_ready()

/datum/stationtrauma_overmap/space
	/// Planet id -> /datum/stationtrauma_planet_survey made by this ship
	var/list/planet_surveys
	/// Planet id -> number of the landing pad the pilot chose: 1 is the planet's own berth, the rest its pads
	var/list/chosen_pads

/// This ship's survey of [planet], if it has begun one
/datum/stationtrauma_overmap/space/proc/planet_survey(datum/stationtrauma_overmap_site/space/planet/planet)
	return planet ? LAZYACCESS(planet_surveys, planet.id) : null

/**
 * The planet this ship can survey now: the nearest charted one within landing range, with the ship stopped and not busy.
 */
/datum/stationtrauma_overmap/space/proc/survey_target()
	if(docked || approach_started || relocating || preparing || jump_target || speed > ST_NAV_STOPPED_SPEED || !is_operational())
		return null
	var/datum/stationtrauma_overmap_site/space/planet/nearest
	var/nearest_distance = ST_SPACE_DOCK_RANGE
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/space/planet/planet = sites[id]
		if(!istype(planet) || planet.failed || !knows_site(planet))
			continue
		var/distance = distance_to(planet)
		if(distance <= nearest_distance)
			nearest = planet
			nearest_distance = distance
	return nearest

/// Whether this ship's survey of [planet] lets it land there
/datum/stationtrauma_overmap/space/proc/surveyed(datum/stationtrauma_overmap_site/space/planet/planet)
	var/datum/stationtrauma_planet_survey/survey = planet_survey(planet)
	return survey?.mapped()

/// The site behind landing pad [number] of [planet]: 1 is the planet's own berth, the rest its pads
/datum/stationtrauma_overmap/space/proc/planet_pad_site(datum/stationtrauma_overmap_site/space/planet/planet, number)
	if(!isnum(number) || number < 1)
		return null
	return number == 1 ? planet : LAZYACCESS(planet.pads, number - 1)

/// Whether a hull may claim [site]'s berth now
/datum/stationtrauma_overmap/space/proc/pad_available(datum/stationtrauma_overmap_site/space/site)
	if(site.docking_owner || site.failed)
		return FALSE
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
	return istype(slot) ? (!slot.active_berth && slot.accepts(vessel)) : (site.berth && !site.berth.get_docked())

/// The landing pads of a surveyed [planet] for the helm chart, each with its place on the schematic
/datum/stationtrauma_overmap/space/proc/landing_pad_data(datum/stationtrauma_overmap_site/space/planet/planet)
	var/datum/stationtrauma_planet_survey/survey = planet_survey(planet)
	if(!survey?.mapped() || !planet.survey_map)
		return null
	. = list()
	var/list/pads = planet.survey_map["pads"]
	for(var/number in 1 to length(pads))
		var/list/pad = pads[number]
		var/datum/stationtrauma_overmap_site/space/site = planet_pad_site(planet, number)
		if(!site)
			continue
		. += list(list(
			"number" = number,
			"x" = (pad[1] + pad[3]) / 2,
			"y" = (pad[2] + pad[4]) / 2,
			"label" = survey_pad_label(pad, survey.efficient),
			"free" = site.docking_owner == src || pad_available(site),
			"chosen" = LAZYACCESS(chosen_pads, planet.id) == number,
		))

/// Where a pad lies, as the survey can tell
/proc/survey_pad_label(list/pad, efficient)
	if(efficient && pad[5])
		return "у искусственной структуры"
	if(pad[6])
		return "у входа в пещеры"
	return "открытая местность"

/** Choose the landing pad [number] of the planet selected on the helm chart. */
/datum/stationtrauma_overmap/space/proc/choose_landing_pad(number)
	var/datum/stationtrauma_overmap_site/space/planet/planet = sites[selected_destination]
	if(!istype(planet) || !surveyed(planet) || docked || approach_started || preparing)
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = planet_pad_site(planet, number)
	if(!site || !pad_available(site))
		return FALSE
	LAZYSET(chosen_pads, planet.id, number)
	return TRUE

ADMIN_VERB(stationtrauma_survey_timer, R_ADMIN, "Overmap - Таймер картографирования", "Включить или выключить минутное картографирование планет после сканирования.", ADMIN_CATEGORY_EVENTS)
	GLOB.stationtrauma_survey_mapping_timer = !GLOB.stationtrauma_survey_mapping_timer
	var/state = GLOB.stationtrauma_survey_mapping_timer ? "включил" : "выключил"
	message_admins("[key_name_admin(user)] [state] таймер картографирования планет.")
	log_admin("[key_name(user)] [state] таймер картографирования планет.")

/** Terrain survey console: launches probes at the planet below and maps its surface. */
/obj/machinery/computer/stationtrauma_planet_survey
	name = "консоль сканирования местности"
	desc = "Пусковая зондов и картограф: перед посадкой на планету её нужно покрыть зондами и нанести на карту."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/shuttle")
	icon_screen = "mining"
	icon_keyboard = "tech_key"
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/computer/stationtrauma_planet_survey
	/// The saved map shown, by its place in the archive
	var/archive_index = 1
	/// When the console may write another data disk
	var/next_disk = 0

/obj/item/circuitboard/computer/stationtrauma_planet_survey
	name = "консоль сканирования местности"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/computer/stationtrauma_planet_survey

/datum/design/board/shuttle/stationtrauma_planet_survey
	name = "Плата консоли сканирования местности"
	desc = "Плата консоли, которая запускает зонды и картографирует планету перед посадкой корабля."
	build_path = /obj/item/circuitboard/computer/stationtrauma_planet_survey

/datum/techweb_node/shuttle_engineering/New()
	. = ..()
	unlocked_designs += /datum/design/board/shuttle/stationtrauma_planet_survey

/// The navigation of the hull this console stands in
/obj/machinery/computer/stationtrauma_planet_survey/proc/navigation()
	RETURN_TYPE(/datum/stationtrauma_overmap/space)
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	return istype(ship) && ship.is_in_shuttle_bounds(src) ? ship.overmap : null

/obj/machinery/computer/stationtrauma_planet_survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "PlanetSurvey")

/obj/machinery/computer/stationtrauma_planet_survey/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(navigation()) || (!isobserver(user) && !can_interact(user)))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_planet_survey/ui_static_data(mob/user)
	return list("physics" = list(
		"orbit_radius" = SURVEY_ORBIT_RADIUS, "orbit_tilt" = SURVEY_ORBIT_TILT, "drift" = SURVEY_DRIFT, "gravity" = SURVEY_GRAVITY,
		"step" = SURVEY_STEP, "steps" = SURVEY_STEPS, "escape" = SURVEY_ESCAPE,
		"speed_min" = SURVEY_SPEED_MIN, "speed_max" = SURVEY_SPEED_MAX, "aim_limit" = SURVEY_AIM_LIMIT,
		"footprint" = SURVEY_FOOTPRINT, "goal" = SURVEY_GOAL, "land" = SURVEY_TIER_LAND, "probe_limit" = SURVEY_PROBE_LIMIT,
		"tiers" = list(SURVEY_TIER_BASIC, SURVEY_TIER_LAND, SURVEY_TIER_DEEP, SURVEY_GOAL),
	))

/// This ship's mapped surveys, as the console's archive lists them
/obj/machinery/computer/stationtrauma_planet_survey/proc/archive(datum/stationtrauma_overmap/space/map)
	. = list()
	for(var/id in map?.planet_surveys)
		var/datum/stationtrauma_planet_survey/survey = map.planet_surveys[id]
		if(survey.mapped())
			. += survey

/obj/machinery/computer/stationtrauma_planet_survey/ui_data(mob/user)
	var/datum/stationtrauma_overmap/space/map = navigation()
	var/list/data = list("vessel_name" = map?.vessel.name, "planet" = null)
	// the saved maps, one shown at a time
	var/list/saved = archive(map)
	archive_index = length(saved) ? clamp(archive_index, 1, length(saved)) : 0
	data["archive_count"] = length(saved)
	data["archive_index"] = archive_index
	if(archive_index)
		var/datum/stationtrauma_planet_survey/shown = saved[archive_index]
		data["archive"] = shown.record()
	data["disk_ready"] = world.time >= next_disk && length(saved) > 0
	var/datum/stationtrauma_overmap_site/space/planet/planet = map?.survey_target()
	if(!planet)
		// why nothing is held, as an instrument would put it
		if(!map)
			data["standby"] = "offline"
		else if(map.docked)
			data["standby"] = "landed"
		else if(map.approach_started || map.relocating || map.preparing || map.jump_target || map.speed > ST_NAV_STOPPED_SPEED)
			data["standby"] = "unstable"
		else
			data["standby"] = "range"
		return data
	var/datum/stationtrauma_planet_survey/survey = map.planet_survey(planet)
	var/list/flights = list()
	for(var/id in survey?.flights)
		var/list/flight = survey.flights[id]
		flights += list(list("id" = id, "path" = flight["path"], "elapsed" = (world.time - flight["launched"]) / (1 SECONDS), "duration" = flight["duration"] / (1 SECONDS)))
	data["planet"] = list(
		"name" = map.site_label(planet),
		"kind" = planet.glyph_kind(),
		"probes" = survey?.probes || 0,
		"coverage" = survey?.coverage || 0,
		"hits" = survey?.hits || list(),
		"flights" = flights,
		"reload" = survey ? max(0, survey.next_launch - world.time) / (1 SECONDS) : 0,
		"covered" = !!survey?.covered_at,
		"mapping" = survey ? survey.mapping_progress() : 0,
		"mapped" = !!survey?.mapped(),
		"generating" = !!(survey && planet.loading_map),
		"failed" = !!planet.failed,
		"facts" = survey ? survey.facts() : list(),
	)
	return data

/** The console's keys press as the navigation console's do; a launch is heard as the probe leaving, not as a key. */
/obj/machinery/computer/stationtrauma_planet_survey/play_ui_sound(action, list/params)
	if(action == "launch")
		return
	playsound(src, 'modular_bandastation/space_overmap/sound/navigation_button.wav', ST_CONSOLE_BUTTON_VOLUME, FALSE, FALSE)

/obj/machinery/computer/stationtrauma_planet_survey/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return
	var/datum/stationtrauma_overmap/space/map = navigation()
	if(!map)
		return
	switch(action)
		if("archive_previous", "archive_next")
			var/count = length(archive(map))
			if(!count)
				return
			archive_index = (archive_index - 1 + (action == "archive_next" ? 1 : -1) + count) % count + 1
			return TRUE
		if("extract")
			var/list/saved = archive(map)
			if(!length(saved) || world.time < next_disk)
				return
			next_disk = world.time + SURVEY_DISK_COOLDOWN
			var/obj/item/stationtrauma_survey_disk/disk = new(drop_location())
			for(var/datum/stationtrauma_planet_survey/survey as anything in saved)
				disk.records += list(survey.record())
			ui.user.put_in_hands(disk)
			playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 40, TRUE)
			return TRUE
	var/datum/stationtrauma_overmap_site/space/planet/planet = map.survey_target()
	if(!planet)
		return
	var/datum/stationtrauma_planet_survey/survey = map.planet_survey(planet)
	switch(action)
		if("map")
			if(survey?.begin_mapping())
				playsound(src, 'sound/machines/terminal/terminal_prompt_confirm.ogg', 30, FALSE)
				return TRUE
		if("launch")
			var/aim_x = params["x"]
			var/aim_y = params["y"]
			var/power = params["power"]
			if(!isnum(aim_x) || !isnum(aim_y) || !isnum(power))
				return
			if(!survey)
				survey = new(map, planet)
				LAZYSET(map.planet_surveys, planet.id, survey)
			survey.console_ref = WEAKREF(src)
			if(survey.launch(clamp(aim_x, -SURVEY_AIM_LIMIT, SURVEY_AIM_LIMIT), clamp(aim_y, -SURVEY_AIM_LIMIT, SURVEY_AIM_LIMIT), clamp(power, 0, 1), !!params["back"]))
				playsound(src, 'sound/effects/gravhit.ogg', 35, TRUE, -3)
				return TRUE

/// A data disk: copies of the survey maps of a ship, carried off its console
/obj/item/stationtrauma_survey_disk
	name = "диск картографических данных"
	desc = "Диск с копиями карт местности, снятых консолью сканирования."
	icon = 'icons/obj/devices/floppy_disks.dmi'
	icon_state = "datadisk4"
	inhand_icon_state = "card-id"
	lefthand_file = 'icons/mob/inhands/equipment/idcards_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/idcards_righthand.dmi'
	drop_sound = 'sound/items/handling/disk_drop.ogg'
	pickup_sound = 'sound/items/handling/disk_pickup.ogg'
	w_class = WEIGHT_CLASS_TINY
	/// Saved maps, each as /datum/stationtrauma_planet_survey/proc/record() makes them
	var/list/records = list()

/obj/item/stationtrauma_survey_disk/examine(mob/user)
	. = ..()
	if(!length(records))
		. += span_notice("Диск пуст.")
		return
	for(var/list/record as anything in records)
		. += span_notice("[record["name"]]: покрытие [round(record["coverage"] * 100)]%.")

#undef SURVEY_ORBIT_RADIUS
#undef SURVEY_DRIFT
#undef SURVEY_ORBIT_TILT
#undef SURVEY_GRAVITY
#undef SURVEY_STEP
#undef SURVEY_STEPS
#undef SURVEY_ESCAPE
#undef SURVEY_SPEED_MIN
#undef SURVEY_SPEED_MAX
#undef SURVEY_AIM_LIMIT
#undef SURVEY_PATH_STRIDE
#undef SURVEY_TIME_SCALE
#undef SURVEY_RELOAD
#undef SURVEY_MAX_FLIGHTS
#undef SURVEY_FOOTPRINT
#undef SURVEY_GOAL
#undef SURVEY_SAMPLES
#undef SURVEY_TIER_BASIC
#undef SURVEY_TIER_LAND
#undef SURVEY_TIER_DEEP
#undef SURVEY_PROBE_LIMIT
#undef SURVEY_DISK_COOLDOWN
#undef SURVEY_MAPPING_TIME
