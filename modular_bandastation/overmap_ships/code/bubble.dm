/*
 * Bubble: adapted from the CeladonSS13/Shiptest ship map, Celadon, Shiptest, Whitesands and TG contributors,
 * https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/independent/independent_bubble.dmm
 * Layout: CC BY-SA 3.0. Rooms are kept; Shiptest machinery, items and inhabitants use local TG types.
 */
/** Mapped ship area: Bubble. */
/area/shuttle/stationtrauma_space/bubble
	name = "Bubble"

/** Mapped ship area: Bubble: рубка. */
/area/shuttle/stationtrauma_space/bubble/bridge
	name = "Bubble: рубка"

/** Mapped ship area: Bubble: грузовой отсек. */
/area/shuttle/stationtrauma_space/bubble/cargo
	name = "Bubble: грузовой отсек"

/** Mapped ship area: Bubble: каюты. */
/area/shuttle/stationtrauma_space/bubble/crew/dorm
	name = "Bubble: каюты"

/** Mapped ship area: Bubble: инженерный отсек. */
/area/shuttle/stationtrauma_space/bubble/engineering
	name = "Bubble: инженерный отсек"

/** Mapped ship area: Bubble: наружный шлюз. */
/area/shuttle/stationtrauma_space/bubble/external
	name = "Bubble: наружный шлюз"

/** Mapped ship area: Bubble: коридор. */
/area/shuttle/stationtrauma_space/bubble/hallway/central
	name = "Bubble: коридор"

/** Mapped ship area: Bubble: кормовой техотсек. */
/area/shuttle/stationtrauma_space/bubble/maintenance/aft
	name = "Bubble: кормовой техотсек"

/** Mapped ship area: Bubble: левый техотсек. */
/area/shuttle/stationtrauma_space/bubble/maintenance/port
	name = "Bubble: левый техотсек"

/** Mapped ship area: Bubble: правый техотсек. */
/area/shuttle/stationtrauma_space/bubble/maintenance/starboard
	name = "Bubble: правый техотсек"

/** Mapped ship area: Bubble: лаборатория. */
/area/shuttle/stationtrauma_space/bubble/science
	name = "Bubble: лаборатория"

/** Transponder preset bubble; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/bubble
	registration_faction = "Независимые"
	callsign = "Bubble"

/** Transponder preset bubble; identity remains on the removable board. */
/obj/machinery/computer/stationtrauma_transponder/bubble
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/bubble
