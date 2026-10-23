/// Clip plating beneath an opt-in diagonal window, using native floor/space underlays on its open side.
/datum/component/diagonal_window_floor
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// The window whose smoothing controls this local mask.
	var/obj/structure/window/window
	/// Current native corner junction.
	var/junction
	/// The neighbouring surface copied into the corner's open half.
	var/turf/neighbor
	/// Our own underlay, kept separate from water, decals and other turf visuals.
	var/mutable_appearance/floor_underlay

/datum/component/diagonal_window_floor/Initialize(obj/structure/window/window)
	if(!istype(parent, /turf/open/floor/plating))
		return COMPONENT_INCOMPATIBLE
	src.window = window

/datum/component/diagonal_window_floor/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	RegisterSignal(window, COMSIG_QDELETING, PROC_REF(on_window_deleted))

/datum/component/diagonal_window_floor/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_EXITED)
	UnregisterSignal(window, COMSIG_QDELETING)
	if(neighbor)
		UnregisterSignal(neighbor, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_TURF_CHANGE))
	var/turf/tile = parent
	tile.remove_filter("diagonal_window_floor")
	tile.underlays -= floor_underlay

/datum/component/diagonal_window_floor/Destroy(force)
	. = ..()
	window = null
	neighbor = null
	floor_underlay = null

/** Native object smoothing selects both the grille mask and the complementary floor underlay. */
/datum/component/diagonal_window_floor/proc/update_corner(new_junction)
	var/turf/tile = parent
	junction = new_junction
	tile.add_filter("diagonal_window_floor", 1, alpha_mask_filter(icon = icon('modular_bandastation/diagonal_turfs/icons/reinforced_window_diagonal.dmi', "mask-[junction]")))
	refresh_floor()

/** Reuse native diagonal-wall sampling, including ocean parallax through the space plane. */
/datum/component/diagonal_window_floor/proc/refresh_floor(datum/source)
	SIGNAL_HANDLER
	var/turf/tile = parent
	if(QDELETED(window) || tile.changing_turf)
		return
	if(neighbor)
		UnregisterSignal(neighbor, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_TURF_CHANGE))
	tile.underlays -= floor_underlay
	var/open_direction = REVERSE_DIR(reverse_ndir(junction))
	floor_underlay = mutable_appearance(layer = LOW_FLOOR_LAYER, offset_spokesman = tile, plane = FLOOR_PLANE)
	neighbor = null
	for(var/direction in list(open_direction & (NORTH|SOUTH), open_direction & (EAST|WEST), open_direction))
		var/turf/candidate = get_step(tile, direction)
		if(candidate?.get_smooth_underlay_icon(floor_underlay, tile, open_direction))
			neighbor = candidate
			break
	if(!neighbor)
		floor_underlay.icon = tile.icon
		floor_underlay.icon_state = tile.icon_state
		floor_underlay.color = tile.color
		floor_underlay.dir = tile.dir
	else
		RegisterSignal(neighbor, COMSIG_ATOM_UPDATED_ICON, PROC_REF(refresh_floor))
		RegisterSignal(neighbor, COMSIG_TURF_CHANGE, PROC_REF(on_neighbor_changed))
	// Keep the copied surface outside the plating's filter; its own mask covers the opposite half.
	floor_underlay.appearance_flags |= KEEP_APART|RESET_COLOR|RESET_ALPHA
	floor_underlay.filters += filter(type = "alpha", icon = icon('modular_bandastation/diagonal_turfs/icons/reinforced_window_diagonal.dmi', "mask-[junction]"), flags = MASK_INVERSE)
	tile.underlays += floor_underlay

/datum/component/diagonal_window_floor/proc/on_neighbor_changed(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(src, PROC_REF(refresh_floor))

/datum/component/diagonal_window_floor/proc/on_exited(turf/source, atom/movable/gone)
	SIGNAL_HANDLER
	if(gone == window)
		qdel(src)

/datum/component/diagonal_window_floor/proc/on_window_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)
