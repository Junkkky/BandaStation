/// Breathable, walkable islands above a visibly deep, impassable void.
/area/awaymission/gate_closure
	name = "GC: Редспейс"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	base_lighting_alpha = 100
	base_lighting_color = "#b76c86"
	parallax_movedir = EAST
	parallax_layer_types = list(
		/atom/movable/screen/parallax_layer/redspace,
		/atom/movable/screen/parallax_layer/redspace/mist,
		/atom/movable/screen/parallax_layer/redspace/near,
	)
	// The event's own random background instead of the away-mission and ruin music; the ship hum stays.
	ambientsounds = list(
		'modular_bandastation/gate_closure/sound/ambience/ominous_background.ogg',
		'modular_bandastation/gate_closure/sound/ambience/spacecraft_hum.ogg',
		'modular_bandastation/gate_closure/sound/ambience/space_atmosphere.ogg',
		'modular_bandastation/gate_closure/sound/ambience/spaceship_ambience.ogg',
	)

/// Ruined department fragments use the same background as the islands.
/area/awaymission/gate_closure/wreck
	name = "GC: Обломки Кибериады"
	base_lighting_alpha = 60

/// Snowbound Avangarde settlement, adrift in the same void.
/area/awaymission/gate_closure/avangarde
	name = "GC: Авангард"

/// The torn-off command block of Central Command, adrift in the same void.
/area/awaymission/gate_closure/centcom
	name = "GC: Центральное командование"
	base_lighting_alpha = 60

/// Imported scenes share the event's nebula and drifting mist.
/area/awaymission/gate_closure/limnea
	name = "GC: Лимнея"

/area/awaymission/gate_closure/wedding
	name = "GC: Свадьба"

/// The Avangarde bar on its own rock, the first stop after the wreck.
/area/awaymission/gate_closure/avangarde_bar
	name = "GC: Авангард - бар"

/// The Limnea suburb around the Petit-Blanchir house; the rooms keep their own names.
/area/awaymission/gate_closure/peti_house
	name = "GC: Лимнея - Пригород"

/area/awaymission/gate_closure/peti_house/hall
	name = "GC: Дом Пети-Бланшир - Прихожая"

/area/awaymission/gate_closure/peti_house/guest_room_1
	name = "GC: Дом Пети-Бланшир - Гостевая 1"

/area/awaymission/gate_closure/peti_house/guest_room_2
	name = "GC: Дом Пети-Бланшир - Гостевая 2"

/area/awaymission/gate_closure/peti_house/bathroom_1
	name = "GC: Дом Пети-Бланшир - Ванная 1"

/area/awaymission/gate_closure/peti_house/bathroom_2
	name = "GC: Дом Пети-Бланшир - Ванная 2"

/area/awaymission/gate_closure/peti_house/pantry
	name = "GC: Дом Пети-Бланшир - Кладовая"

/area/awaymission/gate_closure/peti_house/storage
	name = "GC: Дом Пети-Бланшир - Склад"

/area/awaymission/gate_closure/peti_house/garage
	name = "GC: Дом Пети-Бланшир - Гараж"

/area/awaymission/gate_closure/peti_house/upstairs
	name = "GC: Дом Пети-Бланшир - Второй Этаж"

/area/awaymission/gate_closure/peti_house/victor_room
	name = "GC: Дом Пети-Бланшир - Комната Виктора"

/area/awaymission/gate_closure/peti_house/charlotte_room
	name = "GC: Дом Пети-Бланшир - Комната Шарлотты"

/area/awaymission/gate_closure/peti_house/august_room
	name = "GC: Дом Пети-Бланшир - Комната Августа"

/// The islands every abyss drops onto.
/area/awaymission/gate_closure/islands
	name = "GC: Острова редспейса"

/// The small stone rooms in a corner of each location where admins keep mobs until they are needed.
/area/awaymission/gate_closure/mob_room
	name = "GC: Комната мобов - Редспейс"

/area/awaymission/gate_closure/wreck/mob_room
	name = "GC: Комната мобов - Обломки Кибериады"

/area/awaymission/gate_closure/avangarde/mob_room
	name = "GC: Комната мобов - Авангард"

/area/awaymission/gate_closure/centcom/mob_room
	name = "GC: Комната мобов - Центральное командование"

/area/awaymission/gate_closure/limnea/mob_room
	name = "GC: Комната мобов - Лимнея"

/area/awaymission/gate_closure/wedding/mob_room
	name = "GC: Комната мобов - Свадьба"

/area/awaymission/gate_closure/katorga/mob_room
	name = "GC: Комната мобов - Каторга"

/area/awaymission/gate_closure/peti_house/mob_room
	name = "GC: Комната мобов - Лимнея - Пригород"

/area/awaymission/gate_closure/avangarde_bar/mob_room
	name = "GC: Комната мобов - Авангард - бар"

/area/awaymission/gate_closure/islands/mob_room
	name = "GC: Комната мобов - Острова редспейса"

/// The neighbouring houses of the suburb.
/area/awaymission/gate_closure/peti_house/neighbours
	name = "GC: Лимнея - Соседний дом"

/// Endless quiet rain over the suburb streets: no thunder, no warnings, wet neither floors nor people.
/datum/weather/particle/rain_storm/gate_closure
	telegraph_duration = 0
	telegraph_message = null
	weather_message = null
	end_message = null
	probability = 0
	// Indoors only so the forced street area passes the outdoors check; the rooms are never in the forced list.
	weather_flags = WEATHER_ENDLESS | WEATHER_INDOORS

/// A void boundary rather than a lethal chasm on the expedition's walking route.
/turf/closed/indestructible/redspace_void
	name = "бездна"
	desc = "За краем камня клубится бесконечная багровая пустота."
	icon = 'icons/turf/space.dmi'
	icon_state = MAP_SWITCH("space", "space_map")
	opacity = FALSE
	plane = PLANE_SPACE
	smoothing_flags = NONE
	baseturfs = /turf/closed/indestructible/redspace_void

/// Ordinary atmospheric basalt, with no random fauna or lava beneath it.
/turf/open/misc/asteroid/basalt/redspace
	name = "тёмный камень"
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	baseturfs = /turf/open/misc/asteroid/basalt/redspace
	worm_chance = 0

/// Mineable outcrops on the static island map.
/turf/closed/mineral/redspace
	name = "тёмная скала"
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	baseturfs = /turf/open/misc/asteroid/basalt/redspace
	turf_type = /turf/open/misc/asteroid/basalt/redspace

/// Distant nebulae tile using the standard 480-pixel parallax grid.
/atom/movable/screen/parallax_layer/redspace
	icon = 'modular_bandastation/gate_closure/icons/redspace.dmi'
	icon_state = "nebula"
	layer = 1
	speed = 0.06

/// Transparent filaments move independently of the distant clouds.
/atom/movable/screen/parallax_layer/redspace/mist
	icon_state = "mist"
	layer = 2
	speed = 0.14
	alpha = 150

/// A second, faint foreground mist gives movement depth without per-turf effects.
/atom/movable/screen/parallax_layer/redspace/near
	icon_state = "mist"
	layer = 3
	speed = 0.25
	alpha = 70
