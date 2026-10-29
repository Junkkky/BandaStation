// AI EDIT START - expedition planets module integration
// Sierra's hot, mineral-rich desert profile; local TG terrain and atmosphere are used.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/desert.dm
/** Hot oxygen-free surface profile with saline mineral research sources. */
/datum/stationtrauma_overmap_site/space/planet/arid
	name = "Пустынная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/arid
	biome = "Песчаные равнины и рудные массивы"
	atmosphere = "Азот и углекислый газ, 114 кПа; кислорода нет"
	surface_temperature = 330

/** Seeded desert terrain using a local oxygen-free planetary atmosphere. */
/datum/map_generator/expedition_barren/arid
	floor_type = /turf/open/misc/asteroid/expedition_arid
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_arid
	rock_color = "#c6aa73"

/** Sand carrying the arid profile atmosphere and preserving it beneath excavation. */
/turf/open/misc/asteroid/expedition_arid
	name = "пустынный песок"
	desc = "Сухой песок с обломками выветренной породы."
	color = "#c6aa73"
	initial_gas_mix = GAS_N2 + "=82;" + GAS_CO2 + "=22;TEMP=330"
	temperature = 330
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/expedition_arid
	turf_type = /turf/open/misc/asteroid/expedition_arid
	worm_chance = 0

/** Finite research source: полосчатое соляное отложение, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_arid
	name = "полосчатое соляное отложение"
	desc = "Светлая корка покрывает слоистую породу. Под ней различимы тёмные минеральные прожилки. Можно отобрать пробу."
	icon_state = "silver"
	field_notes = "Соляные слои пересечены минеральными прожилками. На поверхности видны следы ветровой эрозии; слои залегают почти горизонтально."
	laboratory_notes = "Последовательность солевых фракций указывает на многократное испарение древнего водоёма. Металлоносные прожилки образовались позднее и пересекают уже высохшие отложения."
// AI EDIT END
