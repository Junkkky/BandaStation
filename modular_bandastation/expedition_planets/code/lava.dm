// AI EDIT START - expedition planets module integration
// Volcanic profile with biomes adapted from Celadon's lava planet generator (see barren.dm); local TG turfs, flora and fauna.
// Donor purple rock, moss, hell bushes, landmines, elite tumors, anomalies, ore veins, burrows and crystal fauna are omitted or replaced.
/// Fixed volcanic atmosphere; TG lavaland air is randomized per round and would contradict the survey.
#define EXPEDITION_VOLCANIC_ATMOS (GAS_CO2 + "=60;" + GAS_N2 + "=30;TEMP=380")

/** Hot oxygen-free volcanic surface profile with basalt plains, ash scrub and lava lakes. */
/datum/stationtrauma_overmap_site/space/planet/lava
	name = "Вулканическая экзопланета"
	generator_type = /datum/map_generator/expedition_barren/lava
	biome = "Базальтовые равнины, пепельные заросли и лавовые озёра"
	atmosphere = "Углекислый газ и азот, 114 кПа; кислорода нет"
	surface_temperature = 380
	ruin_biome = "lava"

/** Seeded volcanic terrain with volcanic ore walls. */
/datum/map_generator/expedition_barren/lava
	floor_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_volcanic
	mountain_height = 0.45
	biome_table = list(
		list(/datum/biome/expedition/volcanic/forest, /datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic/forest/rocky, /datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic/plains/dense),
		list(/datum/biome/expedition/volcanic/plains, /datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic/plains/dense, /datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic),
		list(/datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic/lush, /datum/biome/expedition/volcanic/forest, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic/forest, /datum/biome/expedition/volcanic/plains/dense, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic/forest/rocky, /datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic/nearlava, /datum/biome/expedition/volcanic_lava),
	)
	cave_biome_table = list(
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_cave/mossy),
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_lava, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_cave/mossy, /datum/biome/expedition/volcanic_cave/obsidian, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave/mossy, /datum/biome/expedition/volcanic_cave/obsidian, /datum/biome/expedition/volcanic_lava, /datum/biome/expedition/volcanic_lava),
	)
	rock_type = /turf/closed/mineral/volcanic
	ore_types = list(
		/turf/closed/mineral/diamond/volcanic = 5,
		/turf/closed/mineral/gold/volcanic = 20,
		/turf/closed/mineral/silver/volcanic = 40,
		/turf/closed/mineral/uranium/volcanic = 60,
		/turf/closed/mineral/titanium/volcanic = 90,
		/turf/closed/mineral/plasma/volcanic = 140,
		/turf/closed/mineral/iron/volcanic = 240,
	)

/** Basalt ground carrying the volcanic profile atmosphere. */
/turf/open/misc/asteroid/basalt/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_volcanic
	turf_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	worm_chance = 0

/** Smooth glassy basalt near lava, in the volcanic profile atmosphere. */
/turf/open/misc/asteroid/basalt/smooth/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/smooth/expedition_volcanic
	turf_type = /turf/open/misc/asteroid/basalt/smooth/expedition_volcanic
	worm_chance = 0

/** Iron-red volcanic rock in the volcanic profile atmosphere. */
/turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	turf_type = /turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	worm_chance = 0

/** Ash grass in the volcanic profile atmosphere. */
/turf/open/misc/grass/lavaland/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_volcanic

/** Lava lakes in the volcanic profile atmosphere. */
/turf/open/lava/smooth/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/lava/smooth/expedition_volcanic

#undef EXPEDITION_VOLCANIC_ATMOS

/** Celadon basalt plain hunted by volcanic predators. */
/datum/biome/expedition/volcanic
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/ash/fireblossom = 1,
		/obj/structure/flora/bush/sparsegrass/style_random = 4,
		/obj/structure/flora/bush/flowers_yw/style_random = 1,
	)
	feature_density = 0.3
	feature_types = list(
		/obj/structure/flora/rock/volcano = 34,
		/obj/structure/geyser/random = 6,
	)
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/watcher = 40,
		/mob/living/basic/mining/legion = 30,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/brimdemon = 20,
	)

/** Celadon dead forest on ash grass. */
/datum/biome/expedition/volcanic/forest
	open_turf_type = /turf/open/misc/grass/lavaland/expedition_volcanic
	flora_density = 80
	flora_types = list(
		/obj/structure/flora/tree/dead/style_random = 2,
		/obj/structure/flora/bush/fullgrass/style_random = 10,
		/obj/structure/flora/bush/sparsegrass/style_random = 5,
	)

/** Celadon rocky dead forest. */
/datum/biome/expedition/volcanic/forest/rocky
	flora_density = 75
	flora_types = list(
		/obj/structure/flora/rock/pile/style_random = 5,
		/obj/structure/flora/rock/volcano = 4,
		/obj/structure/flora/tree/dead/style_random = 10,
		/obj/structure/flora/bush/fullgrass/style_random = 40,
		/obj/structure/flora/bush/sparsegrass/style_random = 20,
		/obj/structure/flora/bush/generic/style_random = 4,
	)

/** Celadon ash grass plains. */
/datum/biome/expedition/volcanic/plains
	open_turf_type = /turf/open/misc/grass/lavaland/expedition_volcanic
	flora_density = 15
	flora_types = list(
		/obj/structure/flora/bush/fullgrass/style_random = 50,
		/obj/structure/flora/bush/sparsegrass/style_random = 35,
		/obj/structure/flora/bush/flowers_yw/style_random = 1,
		/obj/structure/flora/bush/grassy/style_random = 4,
		/obj/structure/flora/ash/fireblossom = 1,
	)

/** Celadon dense ash plains with scattered dead trees. */
/datum/biome/expedition/volcanic/plains/dense
	flora_density = 85
	feature_density = 5
	feature_types = list(/obj/structure/flora/tree/dead/style_random = 1)

/** Celadon mixed ash plains. */
/datum/biome/expedition/volcanic/plains/dense/mixed
	flora_density = 50

/** Celadon ash outback scrub. */
/datum/biome/expedition/volcanic/outback
	open_turf_type = /turf/open/misc/grass/lavaland/expedition_volcanic
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/bush/grassy/style_random = 10,
		/obj/structure/flora/bush/generic/style_random = 10,
		/obj/structure/flora/bush/sparsegrass/style_random = 3,
		/obj/structure/flora/tree/dead/style_random = 3,
		/obj/structure/flora/rock/volcano = 2,
	)

/** Celadon flowering ash meadow. */
/datum/biome/expedition/volcanic/lush
	open_turf_type = /turf/open/misc/grass/lavaland/expedition_volcanic
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/ash/fireblossom = 3,
		/obj/structure/flora/tree/dead/style_random = 1,
		/obj/structure/flora/bush/grassy/style_random = 5,
		/obj/structure/flora/bush/fullgrass/style_random = 10,
		/obj/structure/flora/bush/sparsegrass/style_random = 8,
		/obj/structure/flora/bush/ferny/style_random = 5,
		/obj/structure/flora/bush/generic/style_random = 5,
		/obj/structure/flora/bush/flowers_yw/style_random = 7,
	)

/** Celadon glassy shore of a lava lake. */
/datum/biome/expedition/volcanic/nearlava
	open_turf_type = /turf/open/misc/asteroid/basalt/smooth/expedition_volcanic
	flora_density = 2
	flora_types = list(
		/obj/structure/flora/rock/volcano = 1,
		/obj/structure/flora/rock/pile/style_random = 1,
	)

/** Celadon lava lake; like the donor, nothing grows or spawns on lava. */
/datum/biome/expedition/volcanic_lava
	open_turf_type = /turf/open/lava/smooth/expedition_volcanic

/** Celadon basalt cave with mushrooms and cave predators. */
/datum/biome/expedition/volcanic_cave
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/ash/cacti = 1,
		/obj/structure/flora/ash/tall_shroom = 2,
	)
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/watcher = 40,
		/mob/living/basic/mining/legion = 30,
		/mob/living/basic/mining/goldgrub = 10,
	)

/** Celadon obsidian cave floor. */
/datum/biome/expedition/volcanic_cave/obsidian
	open_turf_type = /turf/open/misc/asteroid/basalt/smooth/expedition_volcanic

/** Celadon rocky cave of iron-red stone. */
/datum/biome/expedition/volcanic_cave/rocky
	open_turf_type = /turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/pile/style_random = 6,
		/obj/structure/flora/rock/volcano = 6,
	)

/** Celadon overgrown cave; ash grass replaces the donor moss. */
/datum/biome/expedition/volcanic_cave/mossy
	open_turf_type = /turf/open/misc/grass/lavaland/expedition_volcanic
	flora_density = 80
	flora_types = list(
		/obj/structure/flora/bush/fullgrass/style_random = 10,
		/obj/structure/flora/bush/sparsegrass/style_random = 5,
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/ash/cacti = 1,
		/obj/structure/flora/ash/tall_shroom = 2,
	)

/** Finite research source: застывший лавовый натёк, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_volcanic
	name = "застывший лавовый натёк"
	desc = "Волнистая корка остывшей лавы с газовыми пузырями и стекловатыми прожилками. Можно обследовать и отобрать пробу."
	icon_state = "plasma"
	field_notes = "Поверхность натёка покрыта застывшими волнами. Пузыри газа вытянуты по направлению течения; в трещинах заметен тонкий налёт серы."
	laboratory_notes = "Порода быстро остыла: в ней много вулканического стекла и мелких кристаллов. Газовые включения и сернистый налёт указывают на недавнюю вулканическую активность под поверхностью."
// AI EDIT END
