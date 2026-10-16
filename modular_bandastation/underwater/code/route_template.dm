/** Keep route editable as one multi-z TGM, allocating its whole stack before any atoms initialize. */
/datum/map_template/stationtrauma_route
	name = "StationTrauma route"
	mappath = 'modular_bandastation/underwater/maps/stationtrauma_route.dmm'
	should_place_on_top = FALSE

/datum/map_template/stationtrauma_route/load_new_z(secret = FALSE)
	var/datum/parsed_map/parsed = new(file(mappath))
	if(!parsed.bounds)
		return FALSE
	var/deck_count = parsed.bounds[MAP_MAXZ]
	if(parsed.bounds[MAP_MINZ] != 1 || deck_count < 2 || width > world.maxx || height > world.maxy)
		stack_trace("StationTrauma route requires at least two decks beginning at z=1 and fitting the world")
		return FALSE
	var/datum/space_level/first_level
	for(var/deck in 1 to deck_count)
		var/list/traits = secret ? ZTRAITS_AWAY_SECRET : ZTRAITS_AWAY
		if(deck > 1)
			traits[ZTRAIT_DOWN] = TRUE
		if(deck < deck_count)
			traits[ZTRAIT_UP] = TRUE
		var/datum/space_level/level = SSmapping.add_new_zlevel("[name]: deck [deck]", traits, contain_turfs = FALSE)
		first_level ||= level
		// LINDA can reach a new placeholder before its ocean marker has initialized.
		for(var/turf/open/space/basic/placeholder in block(locate(1, 1, level.z_value), locate(world.maxx, world.maxy, level.z_value)))
			if(!placeholder.air)
				placeholder.air = placeholder.space_gas
	// The old space area cached its lighting before this stack introduced another plane offset.
	var/area/space/placeholders = GLOB.areas_by_type[/area/space]
	if(placeholders?.lighting_effects)
		for(var/offset in placeholders.lighting_effects.len to SSmapping.max_plane_offset)
			var/mutable_appearance/light = new(placeholders.lighting_effects[1])
			SET_PLANE_W_SCALAR(light, LIGHTING_PLANE, offset)
			placeholders.lighting_effects += light
	var/x_start = round((world.maxx - width) * 0.5) + 1
	var/y_start = round((world.maxy - height) * 0.5) + 1
	// These are fresh placeholders; preserve the TGM's baseturfs instead of stacking a second hull.
	if(!parsed.load(x_start, y_start, first_level.z_value, no_changeturf = TRUE, place_on_top = should_place_on_top, new_z = TRUE))
		return FALSE
	require_area_resort()
	initTemplateBounds(parsed.bounds)
	for(var/deck in first_level.z_value to first_level.z_value + deck_count - 1)
		fill_ocean(deck)
		smooth_zlevel(deck)
	require_area_resort()
	return first_level

/** Finish the exterior before reporting a playable route; no timer keeps changing the ocean during movement. */
/datum/map_template/stationtrauma_route/proc/fill_ocean(level)
	var/turf/origin = locate(1, 1, level)
	var/upper_deck = !!GET_TURF_BELOW(origin)
	var/ocean_path = upper_deck ? /turf/open/space/openspace/ocean : /turf/open/space/ocean
	var/area_path = upper_deck ? /area/space/ocean/openspace : /area/space/ocean
	var/area/space/ocean/ocean_area = GLOB.areas_by_type[area_path] || new area_path
	for(var/turf/open/space/tile in block(locate(1, 1, level), locate(world.maxx, world.maxy, level)))
		CHECK_TICK
		if((tile.type != /turf/open/space/basic && tile.type != /turf/open/space && tile.type != /turf/open/space/openspace) || tile.loc.type != /area/space)
			continue
		// Initialize immediately; fresh space placeholders cannot be left without air between mapload batches.
		tile = tile.ChangeTurf(ocean_path, ocean_path)
		tile.change_area(tile.loc, ocean_area)
	ocean_area.reg_in_areas_in_z()

ADMIN_VERB(stationtrauma_load_route, R_DEBUG, "StationTrauma - Load Route", "Load route as a connected multi-deck ocean map.", ADMIN_CATEGORY_DEBUG)
	var/datum/map_template/stationtrauma_route/template = new
	var/datum/space_level/lower = template.load_new_z()
	if(lower)
		to_chat(user, span_notice("Route loaded on connected z-levels starting at [lower.z_value]."), confidential = TRUE)
		message_admins("[key_name_admin(user)] loaded the StationTrauma route deck stack.")
	else
		to_chat(user, span_warning("Route could not be loaded."), confidential = TRUE)
	qdel(template)
