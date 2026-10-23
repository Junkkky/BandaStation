/// Stock reinforced walls with diagonal corner art; strength and construction remain inherited.
/turf/closed/wall/r_wall/diagonal
	icon = 'modular_bandastation/diagonal_turfs/icons/reinforced_wall_diagonal.dmi'
	icon_state = MAP_SWITCH("reinforced_wall-0", "map-wall-5")
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS

/turf/closed/wall/r_wall/diagonal/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/diagonal_hull)

/** Native reinforced-wall updates reset their flags and sprite while changing deconstruction stages. */
/turf/closed/wall/r_wall/diagonal/update_icon(updates = ALL)
	. = ..()
	if(d_state == INTACT)
		smoothing_flags |= SMOOTH_DIAGONAL_CORNERS|SMOOTH_OBJ
		QUEUE_SMOOTH(src)

/turf/closed/wall/r_wall/diagonal/update_icon_state()
	. = ..()
	if(d_state == INTACT)
		icon = initial(icon)
		set_smoothed_icon_state(smoothing_junction)

/turf/closed/wall/r_wall/diagonal/northeast
	icon_state = MAP_SWITCH("reinforced_wall-0", "map-wall-5")

/turf/closed/wall/r_wall/diagonal/southeast
	icon_state = MAP_SWITCH("reinforced_wall-0", "map-wall-6")

/turf/closed/wall/r_wall/diagonal/southwest
	icon_state = MAP_SWITCH("reinforced_wall-0", "map-wall-10")

/turf/closed/wall/r_wall/diagonal/northwest
	icon_state = MAP_SWITCH("reinforced_wall-0", "map-wall-9")

/// Numeric corner states let native object smoothing select the diagonal without an override.
/obj/structure/window/reinforced/fulltile/diagonal
	icon = 'modular_bandastation/diagonal_turfs/icons/reinforced_window_diagonal.dmi'
	icon_state = MAP_SWITCH("reinforced_window-0", "map-window-5")
	edge_overlay_file = 'modular_bandastation/diagonal_turfs/icons/reinforced_window_edges_diagonal.dmi'
	color = MAP_SWITCH(/obj/structure/window/reinforced/fulltile::color, null)
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS

/obj/structure/window/reinforced/fulltile/diagonal/Initialize(mapload, direct)
	. = ..()
	var/turf/tile = get_turf(src)
	if(tile)
		tile.AddElement(/datum/element/diagonal_hull)

/obj/structure/window/reinforced/fulltile/diagonal/northeast
	icon_state = MAP_SWITCH("reinforced_window-0", "map-window-5")

/obj/structure/window/reinforced/fulltile/diagonal/southeast
	icon_state = MAP_SWITCH("reinforced_window-0", "map-window-6")

/obj/structure/window/reinforced/fulltile/diagonal/southwest
	icon_state = MAP_SWITCH("reinforced_window-0", "map-window-10")

/obj/structure/window/reinforced/fulltile/diagonal/northwest
	icon_state = MAP_SWITCH("reinforced_window-0", "map-window-9")

/// Editor previews include the clipped grille that the spawner creates beneath the window.
/obj/effect/spawner/structure/window/reinforced/diagonal
	icon = 'modular_bandastation/diagonal_turfs/icons/reinforced_window_diagonal.dmi'
	icon_state = "map-5"
	spawn_list = list(/obj/structure/grille, /obj/structure/window/reinforced/fulltile/diagonal)

/obj/effect/spawner/structure/window/reinforced/diagonal/northeast
	icon_state = "map-5"

/obj/effect/spawner/structure/window/reinforced/diagonal/southeast
	icon_state = "map-6"

/obj/effect/spawner/structure/window/reinforced/diagonal/southwest
	icon_state = "map-10"

/obj/effect/spawner/structure/window/reinforced/diagonal/northwest
	icon_state = "map-9"

/// Remember only explicitly mapped diagonal cells, including ordinary RCD window repairs there.
/datum/element/diagonal_hull
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/diagonal_hull/Attach(turf/target)
	. = ..()
	if(!isturf(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(turf_changed), override = TRUE)
	RegisterSignals(target, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(structure_created), override = TRUE)
	RegisterSignal(target, COMSIG_ATOM_EXITED, PROC_REF(structure_left), override = TRUE)
	for(var/obj/structure/window/reinforced/fulltile/window in target)
		apply_window(window)

/datum/element/diagonal_hull/Detach(turf/source)
	var/datum/component/diagonal_window_floor/floor_mask = source.GetComponent(/datum/component/diagonal_window_floor)
	qdel(floor_mask)
	UnregisterSignal(source, list(COMSIG_TURF_CHANGE, COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_ATOM_EXITED))
	for(var/obj/structure/window/window in source)
		UnregisterSignal(window, list(COMSIG_ATOM_SMOOTHED_ICON, COMSIG_QDELETING))
	return ..()

/datum/element/diagonal_hull/proc/turf_changed(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(restore_diagonal_hull))

/datum/element/diagonal_hull/proc/structure_created(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(istype(arrived, /obj/structure/window/reinforced/fulltile))
		apply_window(arrived)
	else if(istype(arrived, /obj/structure/grille))
		for(var/obj/structure/window/reinforced/fulltile/window in source)
			clip_grille(window)

/** Entry and initialization may notify the same window; only our own smoothing subscription is replaced. */
/datum/element/diagonal_hull/proc/apply_window(obj/structure/window/reinforced/fulltile/window)
	if(!(window.flags_1 & INITIALIZED_1) || (window.type != /obj/structure/window/reinforced/fulltile && !istype(window, /obj/structure/window/reinforced/fulltile/diagonal)))
		return
	window.icon = /obj/structure/window/reinforced/fulltile/diagonal::icon
	window.edge_overlay_file = /obj/structure/window/reinforced/fulltile/diagonal::edge_overlay_file
	window.smoothing_flags |= SMOOTH_DIAGONAL_CORNERS
	window.set_can_smooth_with(SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS)
	RegisterSignal(window, COMSIG_ATOM_SMOOTHED_ICON, PROC_REF(clip_grille), override = TRUE)
	RegisterSignal(window, COMSIG_QDELETING, PROC_REF(window_deleted), override = TRUE)
	QUEUE_SMOOTH_NEIGHBORS(window)
	QUEUE_SMOOTH(window)

/datum/element/diagonal_hull/proc/structure_left(turf/source, atom/movable/gone)
	SIGNAL_HANDLER
	if(istype(gone, /obj/structure/grille))
		gone.remove_filter("diagonal_hull")
	if(!istype(gone, /obj/structure/window/reinforced/fulltile))
		return
	UnregisterSignal(gone, list(COMSIG_ATOM_SMOOTHED_ICON, COMSIG_QDELETING))
	for(var/obj/structure/grille/grille in source)
		grille.remove_filter("diagonal_hull")
	if(gone.type == /obj/structure/window/reinforced/fulltile)
		gone.icon = initial(gone.icon)
		var/obj/structure/window/window = gone
		window.edge_overlay_file = initial(window.edge_overlay_file)
		gone.smoothing_flags = initial(gone.smoothing_flags)
		gone.set_can_smooth_with(initial(gone.canSmoothWith))
		QUEUE_SMOOTH(gone)

/datum/element/diagonal_hull/proc/window_deleted(obj/structure/window/source)
	SIGNAL_HANDLER
	for(var/obj/structure/grille/grille in get_turf(source))
		grille.remove_filter("diagonal_hull")

/** The native grille keeps its damage, electrocution and construction behavior; only its visible half is clipped. */
/datum/element/diagonal_hull/proc/clip_grille(obj/structure/window/source)
	SIGNAL_HANDLER
	var/junction = source.smoothing_junction
	var/is_corner = (junction in list(5, 6, 9, 10, 21, 38, 74, 137))
	var/turf/tile = get_turf(source)
	for(var/obj/structure/grille/grille in tile)
		if(is_corner)
			grille.add_filter("diagonal_hull", 1, alpha_mask_filter(icon = icon('modular_bandastation/diagonal_turfs/icons/reinforced_window_diagonal.dmi', "mask-[junction]")))
		else
			grille.remove_filter("diagonal_hull")
	var/datum/component/diagonal_window_floor/floor_mask = tile.GetComponent(/datum/component/diagonal_window_floor)
	if(is_corner && istype(tile, /turf/open/floor/plating))
		if(!floor_mask)
			floor_mask = tile.AddComponent(/datum/component/diagonal_window_floor, source)
		floor_mask.update_corner(junction)
	else
		qdel(floor_mask)

/** Turf replacement keeps the local repair rule without changing global construction designs. */
/proc/restore_diagonal_hull(turf/tile)
	tile.AddElement(/datum/element/diagonal_hull)
