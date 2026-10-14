// Flora artwork and salvage concept: CeladonSS13/Nodalec; see ATTRIBUTION.md.
/area/stationtrauma_test
	name = "StationTrauma: испытательный полигон"
	requires_power = TRUE
	static_lighting = TRUE

/// Powered test fixtures without a separate electrical setup for the flow corridor.
/area/stationtrauma_test/flow
	name = "StationTrauma: испытательный коридор"
	requires_power = FALSE

/// Only the route template requests an ocean beyond its mapped rectangle.
/obj/effect/landmark/ocean_parallax/route
	name = "route ocean (entire z-level)"

/obj/effect/landmark/ocean_parallax/route/Initialize(mapload)
	. = ..()
	// New levels use uninitialized space placeholders; LINDA can reach them before the background loads.
	for(var/turf/open/space/basic/placeholder in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if(!placeholder.air)
			placeholder.air = placeholder.space_gas
	return INITIALIZE_HINT_LATELOAD

/obj/effect/landmark/ocean_parallax/route/LateInitialize()
	// Template initialization shares the late-loader queue; replace turfs after it returns.
	addtimer(CALLBACK(src, PROC_REF(fill_ocean)), 0)

/** Fill unused space on this test level once, preserving every mapped room and special turf. */
/obj/effect/landmark/ocean_parallax/route/proc/fill_ocean()
	var/area/space/ocean/ocean_area = GLOB.areas_by_type[/area/space/ocean] || new /area/space/ocean
	for(var/turf/open/space/tile in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		CHECK_TICK
		if((tile.type != /turf/open/space/basic && tile.type != /turf/open/space) || tile.loc.type != /area/space)
			continue
		// Initialize immediately; deferred ocean turfs have no air until their mapload batch runs.
		tile = tile.ChangeTurf(/turf/open/space/ocean, /turf/open/space/ocean)
		// ChangeTurf owns replacement lighting; change the area only after it has finished.
		tile.change_area(tile.loc, ocean_area)
	ocean_area.reg_in_areas_in_z()
	require_area_resort()
	qdel(src)

/obj/structure/flora/underwater
	name = "водоросли"
	desc = "Морская растительность, колышущаяся в темноте."
	icon = 'modular_bandastation/underwater/icons/ocean_flora.dmi'
	icon_state = "seaweed1"
	harvestable = FALSE

/obj/structure/flora/underwater/long
	icon_state = "longseaweed1"

/obj/structure/flora/underwater/glowing
	name = "светящиеся водоросли"
	icon_state = "glowweed1"
	light_color = LIGHT_COLOR_CYAN
	light_range = 1.5

/obj/structure/flora/underwater/coral
	name = "коралл"
	icon_state = "coral1"
	density = TRUE

/obj/structure/underwater_scrap
	name = "ржавый металлолом"
	desc = "Обломок затонувшей конструкции. Его можно разобрать сваркой."
	icon = 'modular_bandastation/underwater/icons/scrap.dmi'
	icon_state = "scrap1"
	anchored = TRUE
	density = TRUE

/obj/structure/underwater_scrap/welder_act(mob/living/user, obj/item/tool)
	if(!tool.tool_start_check(user, amount = 0))
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 5 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	new /obj/item/stack/sheet/iron(drop_location(), 5)
	qdel(src)
	return ITEM_INTERACT_SUCCESS
