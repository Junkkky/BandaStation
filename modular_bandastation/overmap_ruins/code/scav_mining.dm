/*
 * Adapted Abandoned Mining Operation layout: Voidcrew/Whitesands/TG contributors,
 * https://github.com/Void-Crew/Voidcrew-LRP/blob/66c552922bf2a28963c2a8f5d89993623a141a1f/voidcrew/_maps/RandomRuins/SpaceRuins/scav_mining.dmm
 * CC BY-SA 3.0: https://creativecommons.org/licenses/by-sa/3.0/
 * Retains its rooms; incompatible machinery/items/inhabitants use local TG types.
 */
/** Expedition-only ruin template for Expedition-Ruin Abandoned Mining Base. */
/datum/map_template/ruin/space/stationtrauma_scav_mining
	ruin_type = "expedition_space"
	id = "stationtrauma_scav_mining"
	prefix = "_maps/map_files/overmap_ruins/space/"
	suffix = "scav_mining.dmm"
	name = "Expedition-Ruin Abandoned Mining Base"
	description = "A mining asteroid with salvageable equipment, ore deposits and hostile inhabitants."

/** Mapped expedition area: Abandoned Mine Operations. */
/area/ruin/space/has_grav/stationtrauma_scav_mining/core
	name = "Abandoned Mine Operations"

/** Mapped expedition area: Abandoned Mine Dormitory. */
/area/ruin/space/has_grav/stationtrauma_scav_mining/dorm
	name = "Abandoned Mine Dormitory"

/** Mapped expedition area: Abandoned Mine Airlock. */
/area/ruin/space/has_grav/stationtrauma_scav_mining/entrance
	name = "Abandoned Mine Airlock"
