// AI EDIT START - expedition planets module integration
/** Authored surface sites use the native ruin loader; the generator reserves their footprints first. */
/datum/map_template/ruin/expedition
	prefix = "modular_bandastation/expedition_planets/maps/ruins/"
	ruin_type = "expedition_surface"
	allow_duplicates = FALSE
	/// Surface biome keys compatible with this ruin template.
	var/list/planet_biomes = list("barren", "frozen", "arid", "lush", "lava")

/datum/stationtrauma_overmap_site/space/planet
	/// Surface biome key used to select compatible ruin templates.
	var/ruin_biome = "barren"
	/// Loaded ruin IDs retained for this physical surface.
	var/list/ruin_ids = list()

/datum/stationtrauma_overmap_site/space/planet/frozen
	ruin_biome = "frozen"

/datum/stationtrauma_overmap_site/space/planet/arid
	ruin_biome = "arid"

/datum/stationtrauma_overmap_site/space/planet/lush
	ruin_biome = "lush"

/** One large complex and two smaller finds, all retained on the planet's existing level. */
/datum/stationtrauma_overmap_site/space/planet/proc/prepare_ruins(datum/map_generator/expedition_barren/generator)
	var/list/large = list()
	var/list/small = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/expedition/template = SSmapping.ruins_templates[key]
		if(!istype(template) || template.unpickable || (template.loaded && !template.allow_duplicates) || !(ruin_biome in template.planet_biomes))
			continue
		if(template.width > 54 || template.height > 54)
			continue
		if(max(template.width, template.height) >= 25)
			large += template
		else
			small += template
	var/list/placements = list()
	var/list/slots = list(list(70, 5), list(5, 70), list(70, 70))
	for(var/index in 1 to length(slots))
		var/list/pool = index == 1 ? large : small
		if(!length(pool))
			stack_trace("Planet [id] lacks an eligible [index == 1 ? "large" : "small"] ruin")
			return null
		var/choice = 1 + text2num(copytext(md5("ruin:[generator.seed]:[index]"), 1, 7), 16) % length(pool)
		var/datum/map_template/ruin/expedition/template = pool[choice]
		pool -= template
		var/x = slots[index][1]
		var/y = slots[index][2]
		generator.ruin_bounds += list(list(x, y, x + template.width - 1, y + template.height - 1))
		placements += list(list(template, x, y))
	return placements

/** Load reserved ruins and retain their IDs, yielding to `budget` between templates. */
/datum/stationtrauma_overmap_site/space/planet/proc/load_ruins(list/placements, turf/origin, datum/stationtrauma_work_budget/budget)
	for(var/list/placement as anything in placements)
		var/datum/map_template/ruin/expedition/template = placement[1]
		var/turf/bottom = locate(origin.x + placement[2] - 1, origin.y + placement[3] - 1, origin.z)
		var/turf/center = locate(bottom.x + round(template.width / 2), bottom.y + round(template.height / 2), origin.z)
		if(!template.load(bottom))
			return FALSE
		template.loaded++
		new /obj/effect/landmark/ruin(center, template)
		ruin_ids += template.id
		budget?.yield()
	return TRUE

/** Finite research source: испещрённый бороздами монолит, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/expedition_monolith
	name = "испещрённый бороздами монолит"
	desc = "Каменный блок с повторяющимися бороздами. Можно обследовать поверхность и отобрать пробу отслоившегося материала."
	icon = 'icons/obj/fluff/flora/rocks.dmi'
	icon_state = "basalt1"
	field_notes = "Борозды образуют повторяющиеся группы. Выветривание внутри углублений слабее, чем на открытой поверхности камня."
	laboratory_notes = "Минеральный налёт на стенках борозд моложе самого блока. Следы обработки появились после образования породы; назначение последовательностей пока неизвестно."

/** Finite research source: окаменелый фрагмент скелета, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_fossil
	name = "окаменелый фрагмент скелета"
	desc = "В слоистой породе сохранились повторяющиеся костные дуги. Можно обследовать находку и отобрать образец матрицы."
	field_notes = "Дуги окружены тонкими слоями осадка. Трещина пересекает и окаменелость, и вмещающую породу."
	laboratory_notes = "Минералы заместили исходные ткани, сохранив их внутреннюю структуру. Осадок формировался в воде; находка предшествует высыханию этого участка поверхности."

/** Finite research source: отпечаток древней раковины, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_shell
	name = "отпечаток древней раковины"
	desc = "Ребристый отпечаток в камне. После обследования можно отобрать образец."
	field_notes = "На отпечатке различимы концентрические линии роста. Рядом лежат более мелкие фрагменты той же формы."
	laboratory_notes = "Сходные оболочки принадлежали организмам разных возрастов. Сохранность нескольких поколений указывает на устойчивую экосистему древнего водоёма."
// AI EDIT END
