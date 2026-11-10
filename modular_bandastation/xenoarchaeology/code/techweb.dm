// Research nodes of Voidcrew PR #506, in our typepath techweb format. The study machines and the
// exotic particles node join in later stages.

/// The hand kit prints on an autolathe from round start.
/datum/techweb_node/fundamental_sci/New()
	. = ..()
	unlocked_designs += list(
		/datum/design/xenoarch_kit,
		/datum/design/xenoarch_hammer,
		/datum/design/xenoarch_brush,
		/datum/design/xenoarch_depth_scanner,
		/datum/design/xenoarch_core_sampler,
		/datum/design/xenoarch_find_bag,
	)

/datum/techweb_node/xenoarchaeology
	display_name = "Ксеноархеология"
	description = "Полевые стабилизаторы и спектрометр проб, чтобы извлекать крупные находки целыми, ящик для их перевозки и лабораторный анализатор с площадкой и маркировщиком."
	prerequisite_nodes = list(/datum/techweb_node/fundamental_sci)
	unlocked_designs = list(
		/datum/design/xenoarch_stabiliser,
		/datum/design/board/xenoarch_spectrometer,
		/datum/design/specimen_crate,
		/datum/design/board/artifact_analyser,
		/datum/design/board/artifact_scanpad,
		/datum/design/artifact_labeler,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/datum/techweb_node/xenoarch_excavation
	display_name = "Продвинутые раскопки"
	description = "Глубинный сканер, сразу определяющий нужное стабилизирующее поле, и быстрая кисть."
	prerequisite_nodes = list(/datum/techweb_node/xenoarchaeology)
	unlocked_designs = list(
		/datum/design/xenoarch_scanner_advanced,
		/datum/design/xenoarch_brush_quick,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/datum/design/specimen_crate
	name = "Ящик для образцов"
	desc = "Мягкий, обшитый свинцом ящик для одной крупной находки."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/structure/closet/crate/specimen
	category = list(RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/board/artifact_analyser
	name = "Плата анализатора артефактов"
	desc = "Печатная плата настольного анализатора артефактов."
	build_path = /obj/item/circuitboard/machine/artifact_analyser
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/artifact_scanpad
	name = "Плата сканирующей площадки"
	desc = "Печатная плата площадки, через которую анализатор считывает находку."
	build_path = /obj/item/circuitboard/machine/artifact_scanpad
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/design/artifact_labeler
	name = "Маркировщик образцов"
	desc = "Ручной принтер этикеток для крупных находок."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT * 1.5,
	)
	build_path = /obj/item/artifact_labeler
	category = list(RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE
