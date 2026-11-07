/** Appearance and real atmosphere hidden beneath one docked hull layer. */
/datum/stationtrauma_dock_surface
	/// Native layering owns these geometry records and may rebase the saved stack.
	var/surface_type
	var/baseturfs
	var/area/surface_area
	/// Gas is removed from the original cell at concealment and returned exactly once.
	var/datum/gas_mixture/air
	/// Original decal elements associated with their saved attachment parameters.
	var/list/decals = list()
	/// Source direction used by the native decal rotation parameter helper.
	var/original_direction
	/// Current direction of this underlay inside a carried assembly.
	var/surface_direction
	/// Mapped floor appearance, without copying the visible hull's overlays.
	var/surface_icon
	var/surface_icon_state
	var/surface_base_icon_state
	var/surface_color
	var/list/surface_atom_colours
	var/surface_alpha
	var/surface_broken
	var/surface_burnt
	/// Concealment and restoration are single-use operations.
	var/concealed = FALSE
	var/restored = FALSE

/datum/stationtrauma_dock_surface/New(turf/open/floor/floor)
	if(!istype(floor))
		CRASH("A dock surface snapshot requires a real floor")
	surface_type = floor.type
	baseturfs = islist(floor.baseturfs) ? floor.baseturfs.Copy() : floor.baseturfs
	surface_area = get_area(floor)
	original_direction = surface_direction = floor.dir
	surface_icon = floor.icon
	surface_icon_state = floor.icon_state
	surface_base_icon_state = floor.base_icon_state
	var/list/floor_colors = floor.color
	surface_color = islist(floor_colors) ? floor_colors.Copy() : floor.color
	surface_atom_colours = floor.atom_colours?.Copy()
	surface_alpha = floor.alpha
	surface_broken = floor.broken
	surface_burnt = floor.burnt
	var/list/datum/element/decal/attached = list()
	SEND_SIGNAL(floor, COMSIG_ATOM_GET_DECALS, attached)
	for(var/datum/element/decal/decal as anything in attached)
		var/list/parameters = decal.get_rotated_parameters(original_direction, surface_direction)
		if(!decal.directional)
			parameters["dir"] = NONE
		decals[decal] = parameters
	return ..()

/** Called directly before native copying so the underlay's gas and decals cannot board the guest. */
/datum/stationtrauma_dock_surface/proc/conceal(turf/open/floor/floor)
	if(restored || !istype(floor) || floor.type != surface_type)
		return FALSE
	if(concealed)
		return TRUE
	air = floor.air ? floor.air.remove_ratio(1) : new /datum/gas_mixture
	for(var/datum/element/decal/decal as anything in decals)
		decal.Detach(floor)
	concealed = TRUE
	return TRUE

/** Native movement must first restore the original floor type, baseturf boundary and source area. */
/datum/stationtrauma_dock_surface/proc/restore(turf/open/floor/floor)
	if(restored)
		return TRUE
	if(!concealed || !istype(floor) || floor.type != surface_type || !floor.air)
		return FALSE
	floor.air.volume = air.volume
	floor.air.copy_from(air)
	QDEL_NULL(air)
	var/list/datum/element/decal/current_decals = list()
	SEND_SIGNAL(floor, COMSIG_ATOM_GET_DECALS, current_decals)
	for(var/datum/element/decal/decal as anything in current_decals)
		decal.Detach(floor)
	floor.icon = surface_icon
	floor.icon_state = surface_icon_state
	floor.base_icon_state = surface_base_icon_state
	floor.setDir(surface_direction)
	var/list/saved_colors = surface_color
	floor.color = islist(saved_colors) ? saved_colors.Copy() : surface_color
	floor.atom_colours = surface_atom_colours?.Copy()
	floor.alpha = surface_alpha
	floor.broken = surface_broken
	floor.burnt = surface_burnt
	for(var/datum/element/decal/decal as anything in decals)
		var/list/parameters = decals[decal]
		floor.AddElement(decal.type, parameters["icon"], parameters["icon_state"], parameters["dir"], PLANE_TO_TRUE(parameters["plane"]), parameters["layer"], parameters["alpha"], parameters["color"], parameters["smoothing"], parameters["cleanable"], parameters["desc"])
	floor.update_appearance(UPDATE_OVERLAYS)
	floor.air_update_turf(FALSE, FALSE)
	restored = TRUE
	return TRUE

/** Recompute decal directions from the original attachment so repeated carrying never compounds rounding. */
/datum/stationtrauma_dock_surface/proc/rotate(rotation)
	if(restored)
		return FALSE
	if(!rotation)
		return TRUE
	surface_direction = angle2dir(dir2angle(surface_direction) + rotation)
	for(var/datum/element/decal/decal as anything in decals)
		var/list/parameters = decal.get_rotated_parameters(original_direction, surface_direction)
		if(!decal.directional)
			parameters["dir"] = NONE
		decals[decal] = parameters
	return TRUE

/datum/stationtrauma_dock_surface/Destroy()
	QDEL_NULL(air)
	surface_area = null
	baseturfs = null
	decals = null
	surface_atom_colours = null
	surface_color = null
	surface_icon = null
	return ..()
