/*
 * Venture: adapted from the CeladonSS13/Shiptest ship map, Celadon, Shiptest, Whitesands and TG contributors,
 * https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/nanotrasen/nanotrasen_venture.dmm
 * Layout: CC BY-SA 3.0. Rooms are kept; Shiptest machinery, items and inhabitants use local TG types.
 */
/** Mapped ship area: Venture. */
/area/shuttle/stationtrauma_space/venture
	name = "Venture"

/** Mapped ship area: Venture: рубка. */
/area/shuttle/stationtrauma_space/venture/bridge
	name = "Venture: рубка"

/** Mapped ship area: Venture: левый грузовой отсек. */
/area/shuttle/stationtrauma_space/venture/cargo/port
	name = "Venture: левый грузовой отсек"

/** Mapped ship area: Venture: правый грузовой отсек. */
/area/shuttle/stationtrauma_space/venture/cargo/starboard
	name = "Venture: правый грузовой отсек"

/** Mapped ship area: Venture: каюты. */
/area/shuttle/stationtrauma_space/venture/crew/dorm
	name = "Venture: каюты"

/** Mapped ship area: Venture: инженерный отсек. */
/area/shuttle/stationtrauma_space/venture/engineering
	name = "Venture: инженерный отсек"

/** Transponder preset venture; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/venture
	callsign = "Venture"

/** Transponder preset venture; identity remains on the removable board. */
/obj/machinery/computer/stationtrauma_transponder/venture
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/nt/venture
