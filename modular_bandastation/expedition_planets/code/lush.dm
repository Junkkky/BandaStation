// AI EDIT START - expedition planets module integration
// Sierra's lush surface profile; flora comes from the existing TG plains biome.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/grass.dm
/** Temperate breathable surface profile populated with native TG plains flora. */
/datum/stationtrauma_overmap_site/space/planet/lush
	name = "Зелёная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/lush
	biome = "Травянистые равнины, заросли и влажные низины"
	atmosphere = "Кислород и азот, 101 кПа"
	surface_temperature = T20C
	breathable = TRUE

/** Seeded grass and dirt terrain with flora excluded from reserved paths and ruins. */
/datum/map_generator/expedition_barren/lush
	floor_type = /turf/open/misc/grass/jungle
	source_type = /obj/structure/stationtrauma_research_source/expedition_lush

/datum/map_generator/expedition_barren/lush/terrain_at(x, y)
	var/terrain = ..()
	if(terrain == floor_type && !is_reserved(x, y))
		var/height = text2num(rustg_noise_get_at_coordinates("[seed]", "[x / 12]", "[y / 12]"))
		if(height < 0.32)
			return /turf/open/misc/dirt/jungle/dark
	return terrain

/datum/map_generator/expedition_barren/lush/populate_terrain(list/turfs, area/generate_in)
	. = ..()
	var/datum/biome/plains/biome = new
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/tile as anything in turfs)
		budget.yield()
		if(!istype(tile, floor_type) || get_area(tile) != generate_in || is_reserved(tile.x - origin_x + 1, tile.y - origin_y + 1))
			continue
		var/placement = text2num(copytext(md5("flora:[seed]:[tile.x - origin_x]:[tile.y - origin_y]"), 1, 7), 16)
		if(placement % 1000 >= biome.flora_density * 10)
			continue
		var/flora_type = biome.flora_types[1 + round(placement / 1000) % length(biome.flora_types)]
		new flora_type(tile)
	qdel(biome)

/** Finite research source: пластинчатая растительная колония, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/expedition_lush
	name = "пластинчатая растительная колония"
	desc = "Плотные листовые пластины соединены влажными волокнами. Можно обследовать колонию и отобрать образец."
	icon = 'icons/obj/fluff/flora/jungleflora.dmi'
	icon_state = "bushb1"
	field_notes = "На освещённых пластинах заметен тёмный пигмент. Волокна уходят в почву и связывают несколько соседних побегов."
	laboratory_notes = "В образце обнаружены растительные клетки и симбиотические микроорганизмы. Пористые волокна удерживают влагу; чередование плотных и рыхлых слоёв отражает периоды пересыхания почвы."
// AI EDIT END
