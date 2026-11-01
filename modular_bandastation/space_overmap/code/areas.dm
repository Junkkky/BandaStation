/*
 * raven.dmm: adapted from local _maps/shuttles/emergency/emergency_raven.dmm, /tg/ contributors, CC BY-SA 3.0.
 */
/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Корабль"
	requires_power = FALSE
	ambientsounds = list(null)
	ambient_buzz = null

/** Mapped expedition area: Raven: изолятор. */
/area/shuttle/stationtrauma_space/brig
	name = "Raven: изолятор"

/** Mapped expedition area: Открытый космос. */
/area/space/stationtrauma_space_home
	name = "Открытый космос"

/** Mapped expedition area: stationtrauma space site. */
/area/stationtrauma_space_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/** Mapped expedition area: Астероидное поле. */
/area/stationtrauma_space_site/asteroid
	name = "Астероидное поле"
	default_gravity = ZERO_GRAVITY
/** Mapped expedition area: Экспедиционная база. */
/area/stationtrauma_space_site/planet
	name = "Экспедиционная база"

/** Mapped expedition area: Дрейфующая грузовая платформа. */
/area/stationtrauma_space_site/cargo
	name = "Дрейфующая грузовая платформа"
	default_gravity = ZERO_GRAVITY

/** Mapped expedition area: Pocket Rocket. */
/area/shuttle/stationtrauma_space/pocketrocket
	name = "Pocket Rocket"

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
