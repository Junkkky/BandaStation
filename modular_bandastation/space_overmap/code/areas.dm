/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Корабль"
	requires_power = FALSE
	ambientsounds = list(null)
	ambient_buzz = null

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

/** Powered interiors of the Epsilon Eridani trade outposts. */
/area/stationtrauma_trade_outpost
	name = "Торговый аванпост"
	default_gravity = STANDARD_GRAVITY

/area/stationtrauma_trade_outpost/industrial
	name = "Промышленный торговый узел"

/area/stationtrauma_trade_outpost/medical
	name = "Медицинский торговый узел"

/area/stationtrauma_trade_outpost/agricultural
	name = "Аграрный торговый узел"

/area/stationtrauma_trade_outpost/research
	name = "Научный торговый узел"

/area/stationtrauma_trade_outpost/security
	name = "Охранный торговый узел"

/area/stationtrauma_trade_outpost/service
	name = "Сервисный торговый узел"

/area/stationtrauma_trade_outpost/corporate
	name = "Корпоративный торговый узел"
