/** Native space openspace supplies lower-deck rendering; the reservoir supplies swimming and gravity. */
/turf/open/space/openspace/ocean
	name = "ocean"
	desc = "Толща воды. Внизу смутно виден нижний уровень."
	baseturfs = /turf/open/space/openspace/ocean
	space_lit = FALSE
	light_range = 0
	temperature = T20C
	initial_gas_mix = GAS_O2 + "=22;" + GAS_N2 + "=82;TEMP=293.15"

/turf/open/space/openspace/ocean/Initialize(mapload)
	. = ..()
	initialize_stationtrauma_ocean(FLOOD_WATER_MAX_DEPTH, STATIONTRAUMA_WATER_OCEAN_PRESSURE * 100)

/turf/open/space/openspace/ocean/ChangeTurf(path, list/new_baseturfs, flags)
	return ..(path, new_baseturfs, flags | CHANGETURF_NO_AREA_CHANGE)

/turf/open/space/openspace/ocean/remove_air(amount)
	return air.remove(amount)

/turf/open/space/openspace/ocean/assume_air(datum/gas_mixture/giver)
	return !!giver

/turf/open/space/openspace/ocean/enable_starlight()
	return

/** Match the lower ocean: only finite neighboring air needs simulation. */
/turf/open/space/openspace/ocean/process_cell(fire_count)
	SSair.sleep_active_turf(src)

/turf/open/space/openspace/ocean/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	return get_stationtrauma_ocean_underlay(underlay_appearance, asking_turf)
