// AI EDIT START - expedition planets module integration
// Sierra's cold, ore-poor snow profile; local TG turfs provide atmosphere, footprints and slippery ice.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/snow.dm
/** Cold oxygen-bearing surface profile with snow, frozen lakes and ice core samples. */
/datum/stationtrauma_overmap_site/space/planet/frozen
	name = "Ледяная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/frozen
	biome = "Снежные равнины и ледяные озёра"
	atmosphere = "Кислород и азот, 62 кПа"
	surface_temperature = 180

/** Seeded snow and ice terrain with reduced ore availability. */
/datum/map_generator/expedition_barren/frozen
	floor_type = /turf/open/misc/asteroid/snow
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_frozen

/datum/map_generator/expedition_barren/frozen/terrain_at(x, y)
	var/terrain = ..()
	if(terrain == floor_type)
		if(!is_reserved(x, y))
			var/height = text2num(rustg_noise_get_at_coordinates("[seed]", "[x / 12]", "[y / 12]"))
			if(height < 0.28)
				return /turf/open/misc/ice/expedition
		return terrain
	if(ispath(terrain, /turf/closed/mineral))
		var/ore = text2num(copytext(md5("[seed]:[x]:[y]"), 1, 5), 16) % 1000
		return ore < 25 ? /turf/closed/mineral/iron/ice : /turf/closed/mineral/snowmountain
	return terrain

/** Single-deck surface ice that cannot open a fishing hole into a nonexistent lower level. */
/turf/open/misc/ice/expedition
	// This single-deck surface has no fishing environment beneath its lakes.
	can_make_hole = FALSE
	baseturfs = /turf/open/misc/ice/expedition

/** Finite research source: слоистое ледяное отложение, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_frozen
	name = "слоистое ледяное отложение"
	desc = "Голубоватый лёд с тёмными прослойками и запечатанными пузырьками газа. Можно обследовать и отобрать керн."
	icon_state = "diamond"
	field_notes = "Чередуются прозрачные и пылевые слои. Мелкие пузырьки газа вытянуты вдоль границ слоёв; поверхность пересечена старыми трещинами."
	laboratory_notes = "Керн содержит несколько поколений льда и минеральную пыль. Состав газа в изолированных пузырьках отличается от современной атмосферы: отложение сохраняет следы прежних климатических условий."
// AI EDIT END
