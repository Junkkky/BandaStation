// Research nodes of Voidcrew PR #506, in our typepath techweb format.

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
	experiments_to_unlock = list(/datum/experiment/xenoarch_analysis)
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

/// Voidcrew gated this node behind faction standing; here it needs three different dug artifacts analysed.
/datum/techweb_node/xenoarch_exotic_particles
	display_name = "Экзотические частицы"
	description = "Сборщик, вытягивающий пробуждённое излучение крупной находки в батарею, и ручной утилизатор, высвобождающий его снова."
	prerequisite_nodes = list(/datum/techweb_node/xenoarchaeology)
	unlocked_designs = list(
		/datum/design/board/artifact_harvester,
		/datum/design/anomaly_battery,
		/datum/design/anomaly_utilizer,
	)
	required_experiments = list(/datum/experiment/xenoarch_analysis)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/// Three different dug artifacts fully analysed for the station's research network.
/datum/experiment/xenoarch_analysis
	name = "Анализ артефактов"
	description = "Полностью проанализируйте три разных выкопанных артефакта на сканирующей площадке."
	exp_tag = "Ксеноархеология"
	performance_hint = "Первый полный анализ каждой выкопанной находки засчитывается автоматически."
	/// Different finds required
	var/required = 3
	/// Catalogue numbers of the finds analysed so far
	var/list/serials = list()

/datum/experiment/xenoarch_analysis/is_complete()
	return length(serials) >= required

/datum/experiment/xenoarch_analysis/check_progress()
	return list(EXPERIMENT_PROG_INT("Проанализировано выкопанных артефактов", length(serials), required))

/// Counts the first full analysis of a dug find toward the station's open experiment.
/proc/xenoarch_record_analysis(obj/machinery/artifact/find)
	var/datum/techweb/web = locate(/datum/techweb/science) in SSresearch.techwebs
	for(var/datum/experiment/xenoarch_analysis/experiment in web?.available_experiments)
		experiment.serials |= find.serial
		if(experiment.is_complete())
			experiment.finish_experiment(null, web)
		return

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
