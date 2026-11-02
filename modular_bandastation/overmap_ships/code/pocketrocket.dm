/** Mapped expedition area: Pocket Rocket. */
/area/shuttle/stationtrauma_space/pocketrocket
	name = "Pocket Rocket"
	// Every compartment has an APC; the plasma heaters draw real ship power.
	requires_power = TRUE

/** Mapped expedition area: Pocket Rocket: рубка. */
/area/shuttle/stationtrauma_space/pocketrocket/bridge
	name = "Pocket Rocket: рубка"

/** Mapped expedition area: Pocket Rocket: грузовой отсек. */
/area/shuttle/stationtrauma_space/pocketrocket/cargo
	name = "Pocket Rocket: грузовой отсек"

/** Mapped expedition area: Pocket Rocket: жилой отсек. */
/area/shuttle/stationtrauma_space/pocketrocket/crew
	name = "Pocket Rocket: жилой отсек"

/** Mapped expedition area: Pocket Rocket: камбуз. */
/area/shuttle/stationtrauma_space/pocketrocket/crew/canteen
	name = "Pocket Rocket: камбуз"

/** Mapped expedition area: Pocket Rocket: технический отсек. */
/area/shuttle/stationtrauma_space/pocketrocket/maintenance/central
	name = "Pocket Rocket: технический отсек"

/** Transponder preset pocketrocket; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/pocketrocket
	registration_faction = "Независимые"
	callsign = "Pocket Rocket"

/** Transponder preset pocketrocket; identity remains on the removable board. */
/obj/machinery/computer/stationtrauma_transponder/pocketrocket
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/pocketrocket
