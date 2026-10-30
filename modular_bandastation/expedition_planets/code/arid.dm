// AI EDIT START - expedition planets module integration
// Sierra's hot, mineral-rich desert profile; local TG terrain and atmosphere are used.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/desert.dm
// Biomes adapted from Celadon's sand planet generator (see barren.dm); donor ice caps, acid and lava pools,
// sulfur pools, ore veins, hermits, burrows and maintenance loot are omitted or replaced with local desert ground.
/** Hot oxygen-free surface profile with saline mineral research sources. */
/datum/stationtrauma_overmap_site/space/planet/arid
	name = "Пустынная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/arid
	biome = "Песчаные равнины, сухие русла и каменистые пустоши"
	atmosphere = "Азот и углекислый газ, 114 кПа; кислорода нет"
	surface_temperature = 330

/** Seeded desert terrain using a local oxygen-free planetary atmosphere. */
/datum/map_generator/expedition_barren/arid
	floor_type = /turf/open/misc/asteroid/expedition_arid
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_arid
	rock_color = "#c6aa73"
	biome_zoom = 70
	mountain_height = 0.8
	biome_table = list(
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand, /datum/biome/expedition/sand/grass/dead, /datum/biome/expedition/sand/flats, /datum/biome/expedition/sand/flats),
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand/riverbed, /datum/biome/expedition/sand/wasteland, /datum/biome/expedition/sand/wasteland, /datum/biome/expedition/sand/flats),
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand, /datum/biome/expedition/sand/riverbed, /datum/biome/expedition/sand, /datum/biome/expedition/sand),
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand/grass/dead, /datum/biome/expedition/sand/grass, /datum/biome/expedition/sand/grass, /datum/biome/expedition/sand/grass),
		list(/datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/riverbed, /datum/biome/expedition/sand/grass, /datum/biome/expedition/sand/grass),
		list(/datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand),
	)
	cave_biome_table = list(
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave, /datum/biome/expedition/sand_cave),
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave),
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave, /datum/biome/expedition/sand_cave),
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave),
	)

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

/** Weathered stony desert ground in the arid profile atmosphere. */
/turf/open/misc/asteroid/basalt/expedition_arid
	name = "каменистая пустошь"
	desc = "Выветренная порода, присыпанная песком."
	color = "#a08a68"
	initial_gas_mix = /turf/open/misc/asteroid/expedition_arid::initial_gas_mix
	temperature = 330
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_arid
	turf_type = /turf/open/misc/asteroid/basalt/expedition_arid
	worm_chance = 0

/** Cracked dry riverbed in the arid profile atmosphere. */
/turf/open/misc/dirt/expedition_arid
	name = "высохшее русло"
	desc = "Растрескавшаяся корка давно высохшего ила."
	color = "#b89b72"
	initial_gas_mix = /turf/open/misc/asteroid/expedition_arid::initial_gas_mix
	temperature = 330
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/dirt/expedition_arid

/** Celadon sand plain with mushroom patches, geysers and desert predators. */
/datum/biome/expedition/sand
	open_turf_type = /turf/open/misc/asteroid/expedition_arid
	flora_density = 3
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 4,
		/obj/structure/flora/ash/cap_shroom = 4,
		/obj/structure/flora/ash/stem_shroom = 4,
	)
	feature_density = 0.1
	feature_types = list(/obj/structure/geyser/random = 1)
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/basilisk = 40,
		/mob/living/basic/mining/legion = 30,
	)

/** Celadon wasteland with mushrooms and old remains. */
/datum/biome/expedition/sand/wasteland
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 4,
		/obj/structure/flora/ash/cap_shroom = 4,
		/obj/structure/flora/ash/stem_shroom = 4,
		/obj/effect/decal/remains/human = 4,
	)

/** Celadon scrubland; dry ground replaces the donor desert grass. */
/datum/biome/expedition/sand/grass
	open_turf_type = /turf/open/misc/dirt/expedition_arid
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/ash/cacti = 2,
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
	)
	fauna_density = 0

/** Celadon dead scrubland with withered trees. */
/datum/biome/expedition/sand/grass/dead
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 2,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/tree/dead/style_random = 4,
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
	)

/** Celadon ice-cap flats; rocky sand stands in for the donor snow. */
/datum/biome/expedition/sand/flats
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
	)
	feature_density = 0
	fauna_density = 1

/** Celadon sulfur plains without their donor pools: bare sand where predators do not roam. */
/datum/biome/expedition/sand/sulfur
	flora_density = 0
	feature_density = 0
	fauna_density = 0

/** Celadon dry riverbed hunted by desert predators. */
/datum/biome/expedition/sand/riverbed
	open_turf_type = /turf/open/misc/dirt/expedition_arid
	flora_density = 0
	fauna_types = list(
		/mob/living/basic/mining/goliath = 40,
		/mob/living/basic/mining/basilisk = 30,
		/mob/living/basic/mining/legion = 20,
	)

/** Celadon sand cave with rocks, geysers and burrowing grubs. */
/datum/biome/expedition/sand_cave
	open_turf_type = /turf/open/misc/asteroid/expedition_arid
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/style_random = 4,
		/obj/structure/flora/rock/pile/style_random = 4,
	)
	feature_density = 0.1
	feature_types = list(/obj/structure/geyser/random = 1)
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/basilisk = 40,
		/mob/living/basic/mining/legion = 30,
		/mob/living/basic/mining/goldgrub = 10,
	)

/** Celadon deep cave on stony ground with more grubs. */
/datum/biome/expedition/sand_cave/deep
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_arid
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/basilisk = 40,
		/mob/living/basic/mining/legion = 30,
		/mob/living/basic/mining/goldgrub = 20,
	)

/** Celadon dry volcanic cave; dry ground replaces the donor acid and lava pools. */
/datum/biome/expedition/sand_cave/dry
	open_turf_type = /turf/open/misc/dirt/expedition_arid
	fauna_density = 2

/** Finite research source: полосчатое соляное отложение, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_arid
	name = "полосчатое соляное отложение"
	desc = "Светлая корка покрывает слоистую породу. Под ней различимы тёмные минеральные прожилки. Можно отобрать пробу."
	icon_state = "silver"
	field_notes = "Соляные слои пересечены минеральными прожилками. На поверхности видны следы ветровой эрозии; слои залегают почти горизонтально."
	laboratory_notes = "Последовательность солевых фракций указывает на многократное испарение древнего водоёма. Металлоносные прожилки образовались позднее и пересекают уже высохшие отложения."
// AI EDIT END
