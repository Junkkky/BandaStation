/*
 * Kilo: adapted from the CeladonSS13/Shiptest ship map, Celadon, Shiptest, Whitesands and TG contributors,
 * https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/independent/independent_kilo.dmm
 * Layout: CC BY-SA 3.0. Rooms are kept; Shiptest machinery, items and inhabitants use local TG types.
 */
/** Mapped ship area: Kilo. */
/area/shuttle/stationtrauma_space/kilo
	name = "Kilo"

/** Mapped ship area: Kilo: рубка. */
/area/shuttle/stationtrauma_space/kilo/bridge
	name = "Kilo: рубка"

/** Mapped ship area: Kilo: грузовой отсек. */
/area/shuttle/stationtrauma_space/kilo/cargo
	name = "Kilo: грузовой отсек"

/** Mapped ship area: Kilo: жилой отсек. */
/area/shuttle/stationtrauma_space/kilo/crew
	name = "Kilo: жилой отсек"

/** Mapped ship area: Kilo: камбуз. */
/area/shuttle/stationtrauma_space/kilo/crew/canteen/kitchen
	name = "Kilo: камбуз"

/** Mapped ship area: Kilo: машинное отделение. */
/area/shuttle/stationtrauma_space/kilo/engineering/engine
	name = "Kilo: машинное отделение"

/** Mapped ship area: Kilo: наружный шлюз. */
/area/shuttle/stationtrauma_space/kilo/external
	name = "Kilo: наружный шлюз"
	vacuum_by_design = TRUE

/** Transponder preset kilo; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/kilo
	registration_faction = "Независимые"
	callsign = "Kilo"

/** Transponder preset kilo; identity remains on the removable board. */
/obj/machinery/computer/stationtrauma_transponder/kilo
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/kilo
