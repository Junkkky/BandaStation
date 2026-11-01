/*
 * Glimpse: adapted from the CeladonSS13/Shiptest ship map, Celadon, Shiptest, Whitesands and TG contributors,
 * https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/solfed/solfed_glimpse.dmm
 * Layout: CC BY-SA 3.0. Rooms are kept; Shiptest machinery, items and inhabitants use local TG types.
 */
/** Mapped ship area: Glimpse. */
/area/shuttle/stationtrauma_space/glimpse
	name = "Glimpse"

/** Mapped ship area: Glimpse: рубка. */
/area/shuttle/stationtrauma_space/glimpse/bridge
	name = "Glimpse: рубка"

/** Mapped ship area: Glimpse: грузовой отсек. */
/area/shuttle/stationtrauma_space/glimpse/cargo
	name = "Glimpse: грузовой отсек"

/** Mapped ship area: Glimpse: камбуз. */
/area/shuttle/stationtrauma_space/glimpse/crew/canteen/kitchen
	name = "Glimpse: камбуз"

/** Mapped ship area: Glimpse: криокамеры. */
/area/shuttle/stationtrauma_space/glimpse/crew/cryo
	name = "Glimpse: криокамеры"

/** Mapped ship area: Glimpse: каюта капитана. */
/area/shuttle/stationtrauma_space/glimpse/crew/dorm/captain
	name = "Glimpse: каюта капитана"

/** Mapped ship area: Glimpse: инженерный отсек. */
/area/shuttle/stationtrauma_space/glimpse/engineering
	name = "Glimpse: инженерный отсек"

/** Mapped ship area: Glimpse: лаборатория. */
/area/shuttle/stationtrauma_space/glimpse/general/science
	name = "Glimpse: лаборатория"

/** Mapped ship area: Glimpse: коридор. */
/area/shuttle/stationtrauma_space/glimpse/hallway/central
	name = "Glimpse: коридор"

/** Mapped ship area: Glimpse: оружейная. */
/area/shuttle/stationtrauma_space/glimpse/security/armory
	name = "Glimpse: оружейная"

/** Transponder preset glimpse; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/scg/glimpse
	callsign = "Glimpse"

/** Transponder preset glimpse; identity remains on the removable board. */
/obj/machinery/computer/stationtrauma_transponder/glimpse
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/scg/glimpse
