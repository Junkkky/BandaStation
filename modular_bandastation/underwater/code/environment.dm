/// A solid black service recess, without opening the hull to space or another deck.
/turf/open/floor/catwalk_floor/iron_dark/stationtrauma
	floor_tile = /obj/item/stack/tile/catwalk_tile/iron_dark/stationtrauma

/turf/open/floor/catwalk_floor/iron_dark/stationtrauma/Initialize(mapload)
	. = ..()
	blacken_recess()

/turf/open/floor/catwalk_floor/iron_dark/stationtrauma/proc/blacken_recess()
	var/mutable_appearance/recess = mutable_appearance(icon, "[catwalk_type]_below", LOW_FLOOR_LAYER, src, FLOOR_PLANE)
	underlays -= recess
	recess.color = COLOR_BLACK
	underlays -= recess
	underlays += recess

/obj/item/stack/tile/catwalk_tile/iron_dark/stationtrauma
	turf_type = /turf/open/floor/catwalk_floor/iron_dark/stationtrauma
	merge_type = /obj/item/stack/tile/catwalk_tile/iron_dark/stationtrauma

// Flora artwork and salvage concept: CeladonSS13/Nodalec; see ATTRIBUTION.md.
/area/stationtrauma_test
	name = "StationTrauma: испытательный полигон"
	requires_power = TRUE
	static_lighting = TRUE
	default_gravity = STANDARD_GRAVITY

/// Powered test fixtures without a separate electrical setup for the flow corridor.
/area/stationtrauma_test/flow
	name = "StationTrauma: испытательный коридор"
	requires_power = FALSE

/// Only the route template requests an ocean beyond its mapped rectangle.
/obj/effect/landmark/ocean_parallax/route
	name = "route ocean (entire z-level)"

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
