/// Geometry changes update their own cell without deleting unrelated live preview objects.
/datum/unit_test/overmap_preview_geometry
	/// Original turf definitions restored after preview teardown.
	var/list/original_turfs = list()
	/// Limit a wait for an actual queued preview update.
	var/timed_out = FALSE

/datum/unit_test/overmap_preview_geometry/Destroy()
	QDEL_LIST(allocated)
	for(var/turf/tile as anything in original_turfs)
		var/list/original = original_turfs[tile]
		tile.ChangeTurf(original[1], original[2])
	return ..()

/datum/unit_test/overmap_preview_geometry/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/destination = locate(origin.x + 30, origin.y, origin.z)
	var/turf/changed_local = get_step(origin, EAST)
	var/turf/changed_remote = get_step(destination, EAST)
	var/turf/unchanged_remote = locate(destination.x + 1, destination.y + 1, destination.z)
	var/turf/reverse_gate = get_step(destination, WEST)
	var/turf/reverse_landing = get_step(origin, WEST)
	for(var/turf/tile as anything in list(origin, destination, reverse_gate, reverse_landing, changed_local, changed_remote, get_step(changed_local, NORTH)))
		original_turfs[tile] = list(tile.type, tile.baseturfs)
		tile.ChangeTurf(/turf/open/space)
	var/datum/component/stationtrauma_map_passage/passage = origin.AddComponent(/datum/component/stationtrauma_map_passage, destination, EAST)
	allocated += passage
	allocated += reverse_gate.AddComponent(/datum/component/stationtrauma_map_passage, reverse_landing, WEST)
	var/obj/item/coin/actor = allocate(/obj/item/coin, unchanged_remote)
	var/datum/stationtrauma_map_preview/preview = allocate(/datum/stationtrauma_map_preview, passage, 2)
	var/timeout = addtimer(VARSET_CALLBACK(src, timed_out, TRUE), 5 SECONDS, TIMER_STOPPABLE)
	UNTIL(preview.projections[actor] || timed_out)
	deltimer(timeout)
	TEST_ASSERT(!timed_out, "Initial preview never published its remote actor.")
	var/obj/effect/abstract/stationtrauma_map_projection/carrier = preview.projections[actor]
	var/atom/movable/stationtrauma_map_lighting/unchanged_light
	for(var/atom/movable/stationtrauma_map_lighting/light as anything in preview.lighting)
		if(light.remote_tile == unchanged_remote)
			unchanged_light = light
	TEST_ASSERT_NOTNULL(unchanged_light, "The unchanged remote cell was not lit initially.")
	changed_local.ChangeTurf(/turf/closed/wall)
	timeout = addtimer(VARSET_CALLBACK(src, timed_out, TRUE), 5 SECONDS, TIMER_STOPPABLE)
	UNTIL(!preview.tiles[changed_remote] || timed_out)
	deltimer(timeout)
	TEST_ASSERT(!timed_out, "A replaced local wall never withdrew its remote preview cell.")
	TEST_ASSERT(!QDELETED(carrier) && preview.projections[actor] == carrier, "An unrelated actor's carrier was torn down for a single geometry change.")
	TEST_ASSERT(!QDELETED(unchanged_light) && unchanged_light in preview.lighting, "An unrelated cell's lighting was torn down for a single geometry change.")
	changed_local.ChangeTurf(/turf/open/space)
	timeout = addtimer(VARSET_CALLBACK(src, timed_out, TRUE), 5 SECONDS, TIMER_STOPPABLE)
	UNTIL(preview.tiles[changed_remote] || timed_out)
	deltimer(timeout)
	TEST_ASSERT(!timed_out, "Restoring local space did not restore the cell's preview subscriptions.")
	changed_remote.ChangeTurf(/turf/closed/wall)
	timeout = addtimer(VARSET_CALLBACK(src, timed_out, TRUE), 5 SECONDS, TIMER_STOPPABLE)
	UNTIL(preview.projections[changed_remote] || timed_out)
	deltimer(timeout)
	TEST_ASSERT(!timed_out, "Replacing remote terrain never published the new wall.")
	var/obj/effect/abstract/stationtrauma_map_projection/wall_carrier = preview.projections[changed_remote]
	TEST_ASSERT_EQUAL(wall_carrier.visual_source, changed_remote, "The wall carrier did not retain the replacement turf.")
	changed_remote.ChangeTurf(/turf/open/space)
	var/obj/item/coin/new_actor = allocate(/obj/item/coin, changed_remote)
	timeout = addtimer(VARSET_CALLBACK(src, timed_out, TRUE), 5 SECONDS, TIMER_STOPPABLE)
	UNTIL(preview.projections[new_actor] || timed_out)
	deltimer(timeout)
	TEST_ASSERT(!timed_out, "The replacement remote turf lost actor subscriptions.")
