// AI EDIT START - expedition planets module integration
// Sierra's lush surface profile; flora and fauna come from Celadon's jungle planet biomes (see barren.dm).
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/grass.dm
// Donor kudzu, gardens, capybaras, chicken flocks, ore veins, burrows, anomalies and terrain patches are omitted.
/** Temperate breathable surface profile populated with jungle flora and wildlife. */
/datum/stationtrauma_overmap_site/space/planet/lush
	name = "Зелёная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/lush
	biome = "Джунгли, травянистые равнины, топкие низины и озёра"
	atmosphere = "Кислород и азот, 101 кПа"
	surface_temperature = T20C
	breathable = TRUE

/** Seeded jungle terrain with flora and wildlife excluded from reserved paths and ruins. */
/datum/map_generator/expedition_barren/lush
	floor_type = /turf/open/misc/grass/jungle
	source_type = /obj/structure/stationtrauma_research_source/expedition_lush
	mountain_height = 0.85
	biome_table = list(
		list(/datum/biome/expedition/jungle_wasteland, /datum/biome/expedition/jungle_wasteland, /datum/biome/expedition/jungle/plains, /datum/biome/expedition/jungle/plains, /datum/biome/expedition/mudlands),
		list(/datum/biome/expedition/jungle_wasteland, /datum/biome/expedition/jungle/plains, /datum/biome/expedition/jungle, /datum/biome/expedition/mudlands, /datum/biome/expedition/mudlands),
		list(/datum/biome/expedition/jungle, /datum/biome/expedition/jungle, /datum/biome/expedition/mudlands, /datum/biome/expedition/mudlands, /datum/biome/expedition/jungle),
		list(/datum/biome/expedition/jungle/dense, /datum/biome/expedition/mudlands, /datum/biome/expedition/jungle_water, /datum/biome/expedition/jungle_water, /datum/biome/expedition/mudlands),
		list(/datum/biome/expedition/jungle, /datum/biome/expedition/jungle, /datum/biome/expedition/jungle/dense, /datum/biome/expedition/jungle/dense, /datum/biome/expedition/jungle/dense),
		list(/datum/biome/expedition/jungle/dense, /datum/biome/expedition/jungle/dense, /datum/biome/expedition/mudlands, /datum/biome/expedition/jungle_water, /datum/biome/expedition/jungle_water),
	)
	cave_biome_table = list(
		list(/datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave),
		list(/datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt),
		list(/datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave),
		list(/datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/lush_cave, /datum/biome/expedition/lush_cave/bright, /datum/biome/expedition/lush_cave/bright),
	)

/** Celadon jungle: thick undergrowth with monkeys and fowl. */
/datum/biome/expedition/jungle
	open_turf_type = /turf/open/misc/grass/jungle
	flora_density = 75
	flora_types = list(
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
		/obj/structure/flora/tree/jungle/style_random = 3,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
		/obj/structure/flora/bush/jungle/a/style_random = 1,
		/obj/structure/flora/bush/jungle/b/style_random = 1,
		/obj/structure/flora/bush/jungle/c/style_random = 1,
		/obj/structure/flora/bush/large/style_random = 1,
	)
	fauna_density = 0.3
	fauna_types = list(
		/mob/living/carbon/human/species/monkey = 10,
		/mob/living/basic/chicken = 10,
	)

/** Celadon dense jungle on dark soil, home to gorillas. */
/datum/biome/expedition/jungle/dense
	open_turf_type = /turf/open/misc/dirt/jungle/dark
	flora_density = 85
	flora_types = list(
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
		/obj/structure/flora/tree/jungle/style_random = 5,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
		/obj/structure/flora/bush/jungle/a/style_random = 1,
		/obj/structure/flora/bush/jungle/b/style_random = 1,
		/obj/structure/flora/bush/jungle/c/style_random = 1,
		/obj/structure/flora/bush/large/style_random = 1,
	)
	fauna_density = 0.6
	fauna_types = list(
		/mob/living/basic/gorilla = 1,
		/mob/living/carbon/human/species/monkey = 6,
		/mob/living/basic/chicken = 4,
	)

/** Celadon jungle plains. */
/datum/biome/expedition/jungle/plains
	flora_density = 50
	fauna_density = 1
	fauna_types = list(
		/mob/living/carbon/human/species/monkey = 1,
		/mob/living/basic/chicken = 1,
	)

/** Celadon mudlands with rare tarantulas. */
/datum/biome/expedition/mudlands
	open_turf_type = /turf/open/misc/dirt/jungle/dark
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
	)
	fauna_density = 0.05
	fauna_types = list(/mob/living/basic/spider/giant/tarantula = 1)

/** Celadon barren jungle wasteland. */
/datum/biome/expedition/jungle_wasteland
	open_turf_type = /turf/open/misc/dirt/jungle/wasteland

/** Celadon jungle lake with carp. */
/datum/biome/expedition/jungle_water
	open_turf_type = /turf/open/water/jungle
	flora_density = 1
	flora_types = list(/obj/structure/flora/rock/style_random = 1)
	fauna_density = 1
	fauna_types = list(/mob/living/basic/carp = 1)

/** Celadon jungle cave with rocks, mushrooms and cave predators. */
/datum/biome/expedition/jungle_cave
	open_turf_type = /turf/open/misc/dirt/jungle
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
		/obj/structure/flora/rock/pile/style_random = 1,
		/obj/structure/flora/rock/style_random = 1,
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 1,
		/obj/structure/flora/ash/stem_shroom = 1,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/mining/wolf = 1,
		/mob/living/basic/bear = 1,
		/mob/living/basic/bat = 1,
		/mob/living/basic/snake = 1,
	)

/** Celadon overgrown cave on bare dirt. */
/datum/biome/expedition/jungle_cave/dirt
	open_turf_type = /turf/open/misc/dirt/jungle/wasteland
	flora_types = list(
		/obj/structure/flora/bush/jungle/a/style_random = 1,
		/obj/structure/flora/bush/jungle/b/style_random = 1,
		/obj/structure/flora/bush/jungle/c/style_random = 1,
		/obj/structure/flora/bush/large/style_random = 1,
		/obj/structure/flora/rock/pile/jungle/large/style_random = 1,
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
	)

/** Celadon lush cavern with flowers, bees and walking mushrooms. */
/datum/biome/expedition/lush_cave
	open_turf_type = /turf/open/misc/grass/jungle
	flora_density = 50
	flora_types = list(
		/obj/structure/flora/tree/jungle/small/style_random = 1,
		/obj/structure/flora/bush/flowers_br/style_random = 1,
		/obj/structure/flora/bush/ferny/style_random = 1,
		/obj/structure/flora/bush/fullgrass/style_random = 1,
		/obj/structure/flora/bush/generic/style_random = 1,
		/obj/structure/flora/bush/grassy/style_random = 1,
		/obj/structure/flora/bush/lavendergrass/style_random = 2,
		/obj/structure/flora/bush/pale/style_random = 1,
		/obj/structure/flora/bush/pointy/style_random = 1,
		/obj/structure/flora/bush/flowers_pp/style_random = 1,
		/obj/structure/flora/bush/reed/style_random = 1,
		/obj/structure/flora/bush/sparsegrass/style_random = 1,
		/obj/structure/flora/bush/stalky/style_random = 2,
		/obj/structure/flora/bush/sunny/style_random = 1,
		/obj/structure/flora/bush/flowers_yw/style_random = 1,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/bee = 1,
		/mob/living/basic/mushroom = 1,
	)

/** Celadon bright cavern lit by wandering lightgeists. */
/datum/biome/expedition/lush_cave/bright
	flora_density = 40
	fauna_types = list(/mob/living/basic/lightgeist = 1)

/** Finite research source: пластинчатая растительная колония, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/expedition_lush
	name = "пластинчатая растительная колония"
	desc = "Плотные листовые пластины соединены влажными волокнами. Можно обследовать колонию и отобрать образец."
	icon = 'icons/obj/fluff/flora/jungleflora.dmi'
	icon_state = "bushb1"
	field_notes = "На освещённых пластинах заметен тёмный пигмент. Волокна уходят в почву и связывают несколько соседних побегов."
	laboratory_notes = "В образце обнаружены растительные клетки и симбиотические микроорганизмы. Пористые волокна удерживают влагу; чередование плотных и рыхлых слоёв отражает периоды пересыхания почвы."
// AI EDIT END
