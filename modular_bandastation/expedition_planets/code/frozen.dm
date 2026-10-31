// AI EDIT START - expedition planets module integration
// Sierra's cold, ore-poor snow profile; local TG turfs provide atmosphere, footprints and slippery ice.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/snow.dm
// Biomes adapted from Celadon's snow planet generator (see barren.dm); donor ice rock, plasma lakes, ore veins, burrows and mines are omitted.
/** Cold oxygen-bearing surface profile with snow, frozen lakes and ice core samples. */
/datum/stationtrauma_overmap_site/space/planet/frozen
	name = "Ледяная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/frozen
	biome = "Снежные равнины, хвойные леса, ледяные озёра и пещеры"
	atmosphere = "Кислород и азот, 62 кПа"
	surface_temperature = 180

/** Seeded snow and ice terrain with reduced ore availability. */
/datum/map_generator/expedition_barren/frozen
	wildlife = TRUE
	storm_trait = ZTRAIT_SNOWSTORM
	floor_type = /turf/open/misc/asteroid/snow
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_frozen
	biome_zoom = 55
	mountain_height = 0.45
	biome_table = list(
		list(/datum/biome/expedition/arctic/rocky, /datum/biome/expedition/snow, /datum/biome/expedition/iceberg/lake, /datum/biome/expedition/iceberg, /datum/biome/expedition/iceberg),
		list(/datum/biome/expedition/arctic, /datum/biome/expedition/arctic/rocky, /datum/biome/expedition/snow/lush, /datum/biome/expedition/snow, /datum/biome/expedition/iceberg),
		list(/datum/biome/expedition/snow/thawed, /datum/biome/expedition/snow/forest, /datum/biome/expedition/snow, /datum/biome/expedition/snow/lush, /datum/biome/expedition/iceberg),
		list(/datum/biome/expedition/snow/lush, /datum/biome/expedition/snow/forest/dense, /datum/biome/expedition/snow/forest/dense, /datum/biome/expedition/snow/forest, /datum/biome/expedition/snow/lush),
		list(/datum/biome/expedition/snow, /datum/biome/expedition/snow/forest, /datum/biome/expedition/snow/thawed, /datum/biome/expedition/snow/lush, /datum/biome/expedition/snow),
		list(/datum/biome/expedition/snow/forest/dense, /datum/biome/expedition/snow/forest, /datum/biome/expedition/snow/thawed, /datum/biome/expedition/snow/forest/dense, /datum/biome/expedition/snow/thawed),
	)
	cave_biome_table = /datum/biome/expedition/snow_cave
	rock_type = /turf/closed/mineral/snowmountain
	mineral_chance = 0.8
	ore_types = list(/obj/item/stack/ore/iron = 1)

/** Single-deck surface ice that cannot open a fishing hole into a nonexistent lower level. */
/turf/open/misc/ice/expedition
	// This single-deck surface has no fishing environment beneath its lakes.
	can_make_hole = FALSE
	baseturfs = /turf/open/misc/ice/expedition

/** Celadon snowfield with scattered pines, icy rocks and native cold fauna. */
/datum/biome/expedition/snow
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_density = 10
	flora_types = list(
		/obj/structure/flora/tree/pine/style_random = 4,
		/obj/structure/flora/rock/icy/style_random = 4,
		/obj/structure/flora/rock/pile/icy/style_random = 4,
		/obj/structure/flora/grass/both/style_random = 12,
		/obj/structure/flora/ash/chilly = 4,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 30,
		/mob/living/basic/mining/legion/snow = 25,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_demon = 5,
		/mob/living/basic/mining/ice_whelp = 5,
		/mob/living/basic/mining/lobstrosity = 10,
	)

/** Celadon snow meadow overgrown with frozen grass. */
/datum/biome/expedition/snow/lush
	flora_density = 30
	flora_types = list(/obj/structure/flora/grass/both/style_random = 1)

/** Celadon thawed ground where hardy bushes break through the snow. */
/datum/biome/expedition/snow/thawed
	flora_density = 40
	flora_types = list(
		/obj/structure/flora/bush/fullgrass/style_random = 2,
		/obj/structure/flora/bush/sparsegrass/style_random = 2,
		/obj/structure/flora/bush/generic/style_random = 2,
		/obj/structure/flora/bush/flowers_pp/style_random = 2,
		/obj/structure/flora/bush/lavendergrass/style_random = 2,
	)

/** Celadon pine forest. */
/datum/biome/expedition/snow/forest
	flora_density = 15
	flora_types = list(
		/obj/structure/flora/tree/pine/style_random = 20,
		/obj/structure/flora/tree/dead/style_random = 6,
		/obj/structure/flora/grass/both/style_random = 8,
	)

/** Celadon dense pine forest. */
/datum/biome/expedition/snow/forest/dense
	flora_density = 25
	flora_types = list(
		/obj/structure/flora/tree/pine/style_random = 20,
		/obj/structure/flora/grass/both/style_random = 6,
		/obj/structure/flora/tree/dead/style_random = 3,
	)

/** Celadon open arctic plain with sparse fauna and rare snow figures. */
/datum/biome/expedition/arctic
	open_turf_type = /turf/open/misc/asteroid/snow
	feature_density = 0.1
	feature_types = list(
		/obj/structure/statue/snow/snowman = 3,
		/obj/structure/statue/snow/snowlegion = 1,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 30,
		/mob/living/basic/mining/legion/snow = 25,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_demon = 1,
		/mob/living/basic/mining/ice_whelp = 1,
		/mob/living/basic/mining/lobstrosity = 5,
	)

/** Celadon arctic plain strewn with icy rocks. */
/datum/biome/expedition/arctic/rocky
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/icy/style_random = 2,
		/obj/structure/flora/rock/pile/icy/style_random = 2,
	)

/** Celadon iceberg field; snow replaces the donor ice rock, which lacks a local equivalent. */
/datum/biome/expedition/iceberg
	open_turf_type = /turf/open/misc/asteroid/snow
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 30,
		/mob/living/basic/mining/legion/snow = 25,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_demon = 1,
		/mob/living/basic/mining/ice_whelp = 1,
		/mob/living/basic/mining/lobstrosity = 5,
	)

/** Celadon frozen lake of slippery surface ice. */
/datum/biome/expedition/iceberg/lake
	open_turf_type = /turf/open/misc/ice/expedition

/** Celadon snow cave; donor ice, thawed and volcanic caves share this local floor. */
/datum/biome/expedition/snow_cave
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_density = 6
	flora_types = list(
		/obj/structure/flora/grass/both/style_random = 10,
		/obj/structure/flora/rock/pile/icy/style_random = 2,
		/obj/structure/flora/rock/icy/style_random = 2,
		/obj/structure/flora/ash/leaf_shroom = 2,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
	)
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 30,
		/mob/living/basic/mining/legion/snow = 25,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_demon = 1,
		/mob/living/basic/mining/ice_whelp = 1,
		/mob/living/basic/mining/lobstrosity = 10,
	)

/** Finite research source: слоистое ледяное отложение, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_frozen
	name = "слоистое ледяное отложение"
	desc = "Голубоватый лёд с тёмными прослойками и запечатанными пузырьками газа. Можно обследовать и отобрать керн."
	icon_state = "diamond"
	field_notes = "Чередуются прозрачные и пылевые слои. Мелкие пузырьки газа вытянуты вдоль границ слоёв; поверхность пересечена старыми трещинами."
	laboratory_notes = "Керн содержит несколько поколений льда и минеральную пыль. Состав газа в изолированных пузырьках отличается от современной атмосферы: отложение сохраняет следы прежних климатических условий."
// AI EDIT END
