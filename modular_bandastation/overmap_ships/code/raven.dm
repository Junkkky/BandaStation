/*
 * raven.dmm: adapted from local _maps/shuttles/emergency/emergency_raven.dmm, /tg/ contributors, CC BY-SA 3.0.
 */
/** Mapped ship area: Raven; each compartment has its own labelled mapper icon and runs on the ship's own grid. */
/area/shuttle/stationtrauma_space/raven
	name = "Raven"
	icon = 'modular_bandastation/overmap_ships/icons/raven_areas.dmi'
	icon_state = "hallway"
	requires_power = TRUE

/area/shuttle/stationtrauma_space/raven/bridge
	name = "Raven: мостик"
	icon_state = "bridge"

/area/shuttle/stationtrauma_space/raven/brig
	name = "Raven: изолятор"
	icon_state = "brig"

/area/shuttle/stationtrauma_space/raven/medbay
	name = "Raven: медотсек"
	icon_state = "medbay"

/area/shuttle/stationtrauma_space/raven/hallway
	name = "Raven: центральный коридор"
	icon_state = "hallway"

/area/shuttle/stationtrauma_space/raven/airlock_port_fore
	name = "Raven: левый носовой шлюз"
	icon_state = "airlock_port_fore"

/area/shuttle/stationtrauma_space/raven/airlock_starboard_fore
	name = "Raven: правый носовой шлюз"
	icon_state = "airlock_starboard_fore"

/area/shuttle/stationtrauma_space/raven/airlock_port_aft
	name = "Raven: левый кормовой шлюз"
	icon_state = "airlock_port_aft"

/area/shuttle/stationtrauma_space/raven/airlock_starboard_aft
	name = "Raven: правый кормовой шлюз"
	icon_state = "airlock_starboard_aft"

/area/shuttle/stationtrauma_space/raven/power
	name = "Raven: энергоузел"
	icon_state = "power"

/area/shuttle/stationtrauma_space/raven/storage
	name = "Raven: кладовая"
	icon_state = "storage"

/area/shuttle/stationtrauma_space/raven/fuel
	name = "Raven: топливный отсек"
	icon_state = "fuel"

/area/shuttle/stationtrauma_space/raven/engine_control
	name = "Raven: пост двигателя"
	icon_state = "engine_control"

/// Sealed like a supermatter chamber: purged to vacuum between burns, with no APC; its injector and siphon run unmetered.
/area/shuttle/stationtrauma_space/raven/combustion
	name = "Raven: камера сгорания"
	icon_state = "combustion"
	sound_environment = SOUND_AREA_SMALL_ENCLOSED
	vacuum_by_design = TRUE
	requires_power = FALSE

/area/shuttle/stationtrauma_space/raven/life_support
	name = "Raven: жизнеобеспечение"
	icon_state = "life_support"

/area/shuttle/stationtrauma_space/raven/engineering
	name = "Raven: машинный отсек"
	icon_state = "engineering"

/// Open engine bay behind the heaters; it holds no APC and nothing that needs one.
/area/shuttle/stationtrauma_space/raven/engines
	name = "Raven: двигатели"
	icon_state = "engines"
	vacuum_by_design = TRUE
	requires_power = FALSE

/** Transponder preset raven; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/raven
	callsign = "Raven"

/** Transponder preset raven; identity remains on the removable board. */
/obj/machinery/computer/stationtrauma_transponder/raven
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/nt/raven
