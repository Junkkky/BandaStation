GLOBAL_LIST_EMPTY(gate_closure_island_landings)

/// Walkable redspace abyss: whoever steps off the edge falls onto one of the separate islands.
/turf/open/chasm/gate_closure
	name = "бездна"
	desc = "За краем камня клубится бесконечная багровая пустота."
	icon = 'icons/turf/space.dmi'
	icon_state = MAP_SWITCH("space", "space_map")
	plane = PLANE_SPACE
	smoothing_flags = NONE
	smoothing_groups = null
	canSmoothWith = null
	baseturfs = /turf/open/chasm/gate_closure
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	// Drawn by the redspace parallax: no lighting objects for tens of thousands of tiles.
	space_lit = TRUE

/// Tens of thousands of abyss tiles are never touched; the chasm logic is only attached where something arrives.
/turf/open/chasm/gate_closure/apply_components(mapload)
	return

/turf/open/chasm/gate_closure/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	// Entered runs before the move's abstract-entered signal, so the fresh component still sees this arrival.
	if(!GetComponent(/datum/component/chasm))
		AddComponent(/datum/component/chasm/gate_closure, null, TRUE)
	return ..()

/// Native chasm detection and timing, but the fall ends on a redspace island instead of oblivion.
/datum/component/chasm/gate_closure
	fall_message = "Вы срываетесь в багровую бездну!"

/datum/component/chasm/gate_closure/Initialize(turf/target, mapload)
	. = ..()
	if(. == COMPONENT_INCOMPATIBLE)
		return
	// The abyss is not a fishing spot.
	var/turf/abyss = parent
	qdel(abyss.GetComponent(/datum/component/fishing_spot))

/datum/component/chasm/gate_closure/drop(atom/movable/dropped_thing)
	// Drops run asynchronously; a second one for the same fall finds the thing already gone from the edge.
	if(QDELETED(dropped_thing) || dropped_thing.loc != parent)
		return
	var/turf/landing = gate_closure_island_landing(get_turf(parent))
	// Without the island level nothing should vanish; the thing simply stays at the edge.
	if(!landing)
		return
	if(SEND_SIGNAL(dropped_thing, COMSIG_MOVABLE_CHASM_DROPPED, parent) & COMPONENT_NO_CHASM_DROP)
		return
	for(var/mob/living/buckled as anything in dropped_thing.buckled_mobs)
		dropped_thing.unbuckle_mob(buckled)
		drop_stuff(buckled)
	dropped_thing.visible_message(span_boldwarning("[dropped_thing] срывается в бездну!"), span_userdanger(fall_message))
	dropped_thing.forceMove(landing)
	landing.visible_message(span_boldwarning("[dropped_thing] падает откуда-то сверху!"))
	playsound(landing, 'sound/effects/meteorimpact.ogg', 50, TRUE)
	if(isliving(dropped_thing))
		var/mob/living/fallen = dropped_thing
		fallen.Unconscious(10 SECONDS)

/// Island landing marker; each island of the fall level carries one.
/obj/effect/landmark/gate_closure_island
	name = "ивент: приземление на остров"

/obj/effect/landmark/gate_closure_island/Initialize(mapload)
	. = ..()
	GLOB.gate_closure_island_landings += get_turf(src)
	return INITIALIZE_HINT_QDEL

/// A free tile on a random island; when falling from the island level itself, never the island just left.
/proc/gate_closure_island_landing(turf/fall_from)
	var/list/turf/islands = list()
	for(var/turf/marker as anything in GLOB.gate_closure_island_landings)
		if(fall_from && marker.z == fall_from.z && get_dist(marker, fall_from) < 25)
			continue
		islands += marker
	if(!length(islands))
		return null
	var/turf/marker = pick(islands)
	var/list/turf/free = list()
	for(var/turf/open/candidate in range(2, marker))
		if(!istype(candidate, /turf/open/chasm) && !candidate.is_blocked_turf(exclude_mobs = TRUE))
			free += candidate
	return length(free) ? pick(free) : marker
