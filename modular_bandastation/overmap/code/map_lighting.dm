/** Replace local ambient light with the remote tile's live native lighting, without recalculating it. */
/atom/movable/stationtrauma_map_lighting
	icon = null
	plane = LIGHTING_PLANE
	appearance_flags = KEEP_TOGETHER
	layer = LIGHTING_ABOVE_ALL
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	/// Own the visual link only; the lighting subsystem still owns the real light.
	var/turf/remote_tile

/atom/movable/stationtrauma_map_lighting/Initialize(mapload, turf/source_tile)
	. = ..()
	remote_tile = source_tile
	var/turf/local_tile = get_turf(src)
	SET_PLANE(src, LIGHTING_PLANE, local_tile)
	underlays += mutable_appearance(LIGHTING_ICON, "lighting_dark", 0, src, LIGHTING_PLANE)
	RegisterSignal(remote_tile, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, PROC_REF(light_created))
	RegisterSignal(remote_tile, COMSIG_ATOM_UPDATED_ICON, PROC_REF(refresh))
	RegisterSignal(SSdcs, COMSIG_STARLIGHT_COLOR_CHANGED, PROC_REF(refresh))
	refresh()

/atom/movable/stationtrauma_map_lighting/Destroy()
	UnregisterSignal(remote_tile, list(COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_ATOM_UPDATED_ICON))
	UnregisterSignal(SSdcs, COMSIG_STARLIGHT_COLOR_CHANGED)
	vis_contents.Cut()
	remote_tile = null
	return ..()

/atom/movable/stationtrauma_map_lighting/proc/light_created(datum/source, atom/movable/actor)
	SIGNAL_HANDLER
	if(istype(actor, /atom/movable/lighting_object))
		refresh()

/** KEEP_TOGETHER draws the live light above the opaque mask, regardless of its original Z-based layer. */
/atom/movable/stationtrauma_map_lighting/proc/refresh()
	SIGNAL_HANDLER
	vis_contents.Cut()
	if(remote_tile.lighting_object)
		vis_contents += remote_tile.lighting_object
	var/area/remote_area = get_area(remote_tile)
	cut_overlays()
	if(remote_area.area_has_base_lighting || remote_tile.space_lit)
		// A direct appearance avoids native render-source relays breaking KEEP_TOGETHER.
		var/mutable_appearance/base_light = mutable_appearance('icons/effects/alphacolors.dmi', "white", LIGHTING_PRIMARY_LAYER, src, LIGHTING_PLANE)
		base_light.alpha = remote_area.area_has_base_lighting ? remote_area.base_lighting_alpha : 255
		base_light.color = remote_area.area_has_base_lighting && remote_area.base_lighting_color != COLOR_STARLIGHT ? remote_area.base_lighting_color : GLOB.starlight_color
		base_light.blend_mode = BLEND_ADD
		add_overlay(base_light)
