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
/// The launcher sits almost on the viewer's line of sight, so a probe goes near where it is aimed and only bends with gravity
#define SURVEY_LAUNCH_Y -0.3
#define SURVEY_LAUNCH_Z 8
#define SURVEY_GRAVITY 1
#define SURVEY_STEP 0.02
#define SURVEY_STEPS 900
/// A probe this far from the planet's centre is lost in space
#define SURVEY_ESCAPE 12
#define SURVEY_SPEED_MIN 0.8
#define SURVEY_SPEED_MAX 2
/// The furthest from the planet's centre a probe may be aimed, in planet radii
#define SURVEY_AIM_LIMIT 1.6
/// Every this many steps a point of a flight is kept for the screen
#define SURVEY_PATH_STRIDE 10
/// Real time per unit of simulated flight: flights take three to nine seconds
#define SURVEY_TIME_SCALE (1 SECONDS)
#define SURVEY_RELOAD (1.5 SECONDS)
/// Most probes in flight at once
#define SURVEY_MAX_FLIGHTS 6
/// Angular radius of the ground a probe reads, in degrees: an ideal survey of the whole planet takes about six probes
#define SURVEY_FOOTPRINT 50
/// Share of the planet that has to be covered
#define SURVEY_GOAL 0.9
/// Points the coverage is measured on, spread evenly over the sphere
#define SURVEY_SAMPLES 600
/// A survey done in this many probes also finds structures and life on the schematic
#define SURVEY_EFFICIENT_PROBES 10
#define SURVEY_MAPPING_TIME (2 MINUTES)

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
 * Flies one probe aimed at [aim_x], [aim_y] on the planet's face with [power] (0-1), as seen from the front.
 * Returns list(path, steps, impact): the kept points of the flight, each list(x, y, z), how many steps it took, and the
 * point on the sphere it struck, or null if it missed.
 */
/proc/stationtrauma_survey_flight(aim_x, aim_y, power)
	var/x = 0
	var/y = SURVEY_LAUNCH_Y
	var/z = SURVEY_LAUNCH_Z
	// aimed at the point of the face under the cursor, or at the planet's plane past its rim
	var/aim_z = sqrt(max(0, 1 - aim_x * aim_x - aim_y * aim_y))
	var/dx = aim_x - x
	var/dy = aim_y - y
	var/dz = aim_z - z
	var/speed = (SURVEY_SPEED_MIN + power * (SURVEY_SPEED_MAX - SURVEY_SPEED_MIN)) / sqrt(dx * dx + dy * dy + dz * dz)
	var/vx = dx * speed
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
	/// world.time both faces were covered and mapping began; zero before
	var/covered_at = 0
	/// Covered within SURVEY_EFFICIENT_PROBES
	var/efficient = FALSE

/datum/stationtrauma_planet_survey/New(datum/stationtrauma_overmap/space/navigation, datum/stationtrauma_overmap_site/space/planet/planet)
	src.navigation = navigation
	src.planet = planet
	covered = new /list(SURVEY_SAMPLES)
	return ..()

/datum/stationtrauma_planet_survey/Destroy(force)
	navigation = null
	planet = null
	flights = null
	return ..()

/**
 * Launches a probe aimed at [aim_x], [aim_y] with [power], at the back face if [back_side]. The first probe sets the
 * planet's generation going. Returns FALSE if the launcher is not ready.
 */
/datum/stationtrauma_planet_survey/proc/launch(aim_x, aim_y, power, back_side)
	if(covered_at || world.time < next_launch || length(flights) >= SURVEY_MAX_FLIGHTS)
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
	if(!impact || covered_at || QDELETED(navigation) || navigation.survey_target() != planet)
		return
	hits += list(impact)
	var/reach = cos(SURVEY_FOOTPRINT)
	var/list/samples = GLOB.stationtrauma_survey_samples
	var/read = 0
	for(var/index in 1 to length(samples))
		var/list/sample = samples[index]
		if(!covered[index] && sample[1] * impact[1] + sample[2] * impact[2] + sample[3] * impact[3] >= reach)
			covered[index] = TRUE
		read += !!covered[index]
	coverage = read / length(samples)
	if(coverage >= SURVEY_GOAL)
		covered_at = world.time
		efficient = probes <= SURVEY_EFFICIENT_PROBES
		flights.Cut()

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

ADMIN_VERB(stationtrauma_survey_timer, R_ADMIN, "Overmap - Таймер картографирования", "Включить или выключить двухминутное картографирование планет после сканирования.", ADMIN_CATEGORY_EVENTS)
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
		"launch_y" = SURVEY_LAUNCH_Y, "launch_z" = SURVEY_LAUNCH_Z, "gravity" = SURVEY_GRAVITY,
		"step" = SURVEY_STEP, "steps" = SURVEY_STEPS, "escape" = SURVEY_ESCAPE,
		"speed_min" = SURVEY_SPEED_MIN, "speed_max" = SURVEY_SPEED_MAX, "aim_limit" = SURVEY_AIM_LIMIT,
		"footprint" = SURVEY_FOOTPRINT, "goal" = SURVEY_GOAL, "efficient" = SURVEY_EFFICIENT_PROBES,
	))

/obj/machinery/computer/stationtrauma_planet_survey/ui_data(mob/user)
	var/datum/stationtrauma_overmap/space/map = navigation()
	var/list/data = list("vessel_name" = map?.vessel.name, "planet" = null)
	var/datum/stationtrauma_overmap_site/space/planet/planet = map?.survey_target()
	if(!planet)
		data["reason"] = !map ? "Нет связи с кораблём" : (map.docked ? "Корабль на стоянке" : "Нет планеты в зоне захода или корабль в движении")
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
		"efficient" = !!survey?.efficient,
		"mapping" = survey ? survey.mapping_progress() : 0,
		"mapped" = !!survey?.mapped(),
		"generating" = !!(survey && planet.loading_map),
		"failed" = !!planet.failed,
	)
	if(survey?.covered_at)
		data["planet"]["facts"] = planet.survey_data()
	if(survey?.mapped() && planet.survey_map)
		var/list/schematic = planet.survey_map.Copy()
		var/list/pads = list()
		for(var/list/pad as anything in schematic["pads"])
			pads += list(list("rect" = pad.Copy(1, 5), "label" = survey_pad_label(pad, survey.efficient)))
		schematic["pads"] = pads
		if(!survey.efficient)
			schematic -= "structures"
			schematic -= "organic"
		data["planet"]["schematic"] = schematic
	return data

/obj/machinery/computer/stationtrauma_planet_survey/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || action != "launch" || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return
	var/datum/stationtrauma_overmap/space/map = navigation()
	var/datum/stationtrauma_overmap_site/space/planet/planet = map?.survey_target()
	var/aim_x = params["x"]
	var/aim_y = params["y"]
	var/power = params["power"]
	if(!planet || !isnum(aim_x) || !isnum(aim_y) || !isnum(power))
		return
	var/datum/stationtrauma_planet_survey/survey = map.planet_survey(planet)
	if(!survey)
		survey = new(map, planet)
		LAZYSET(map.planet_surveys, planet.id, survey)
	if(survey.launch(clamp(aim_x, -SURVEY_AIM_LIMIT, SURVEY_AIM_LIMIT), clamp(aim_y, -SURVEY_AIM_LIMIT, SURVEY_AIM_LIMIT), clamp(power, 0, 1), !!params["back"]))
		playsound(src, 'sound/items/weapons/gun/general/grenade_launch.ogg', 35, TRUE, -3)
		return TRUE

#undef SURVEY_LAUNCH_Y
#undef SURVEY_LAUNCH_Z
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
#undef SURVEY_EFFICIENT_PROBES
#undef SURVEY_MAPPING_TIME
