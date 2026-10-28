/** Map seam using native zMove for occupants and pulled objects. */
/datum/component/stationtrauma_map_passage
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// A real exterior tile just beyond the reverse seam, preventing immediate bounce-back.
	var/turf/open/landing
	/// Cardinal direction towards the destination.
	var/direction
	/// Null for standalone seams; a travelling vessel opens all its prepared links together.
	var/datum/stationtrauma_map_connection/connection

/datum/component/stationtrauma_map_passage/Initialize(turf/open/destination, facing, datum/stationtrauma_map_connection/owner)
	if(!isspaceturf(parent) || !isspaceturf(destination) || !(facing in GLOB.cardinals))
		return COMPONENT_INCOMPATIBLE
	landing = destination
	direction = facing
	connection = owner

/datum/component/stationtrauma_map_passage/RegisterWithParent()
	RegisterSignals(parent, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(on_entered))
	RegisterSignal(parent, COMSIG_TURF_CHANGE, PROC_REF(remove_passage))

/datum/component/stationtrauma_map_passage/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_TURF_CHANGE))

/datum/component/stationtrauma_map_passage/proc/remove_passage()
	SIGNAL_HANDLER
	if(connection)
		connection.revision++
	qdel(src)

/datum/component/stationtrauma_map_passage/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isprojectile(arrived))
		var/obj/projectile/shot = arrived
		// Initialization and entry can notify the same passage before the next projectile step.
		RegisterSignal(shot, shot.fired ? COMSIG_PROJECTILE_MOVE_PROCESS_STEP : COMSIG_PROJECTILE_FIRE, PROC_REF(cross_projectile), override = TRUE)
		return
	if(istype(arrived, /obj/effect/abstract/stationtrauma_map_projection))
		return
	// Finish the original area's Entered/Moved signals before entering another area.
	addtimer(CALLBACK(src, PROC_REF(cross), arrived, REF(arrived)), 0, TIMER_UNIQUE)

/** Recheck the live exit instead of using space transit's search for another landing inside the map. */
/datum/component/stationtrauma_map_passage/proc/cross(atom/movable/arrived)
	if((connection && (QDELETED(connection) || !connection.active)) || QDELETED(src) || QDELETED(arrived) || arrived.loc != parent || arrived.anchored || arrived.currently_z_moving || arrived.pulledby)
		return FALSE
	if(istype(arrived, /atom/movable/mirage_holder) || istype(arrived, /obj/effect/overlay) || istype(arrived, /atom/movable/lighting_object) || istype(arrived, /obj/effect/abstract/z_holder))
		return FALSE
	if(SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD || !landing_available() || landing.density)
		return FALSE
	for(var/atom/movable/obstacle as anything in landing)
		if(obstacle.density)
			return FALSE
	return move_actor(arrived)

/** Transfer inside the projectile's native movement step, including instantaneous hitscan loops. */
/datum/component/stationtrauma_map_passage/proc/cross_projectile(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, list(COMSIG_PROJECTILE_MOVE_PROCESS_STEP, COMSIG_PROJECTILE_FIRE))
	if(QDELETED(src) || QDELETED(shot) || shot.loc != parent || !shot.fired || shot.deletion_queued || !shot.movement_vector)
		return FALSE
	if(connection && (QDELETED(connection) || !connection.active))
		return FALSE
	if(SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD || !landing_available())
		return FALSE
	var/forward = direction == NORTH ? shot.movement_vector.pixel_y : direction == SOUTH ? -shot.movement_vector.pixel_y : direction == EAST ? shot.movement_vector.pixel_x : -shot.movement_vector.pixel_x
	if(forward <= 0)
		return FALSE
	var/turf/origin = parent
	var/delta_x = landing.x - origin.x
	var/delta_y = landing.y - origin.y
	// Accuracy origins must stay inside the world after the coordinate shift.
	if(shot.starting)
		shot.starting = locate(clamp(shot.starting.x + delta_x, 1, world.maxx), clamp(shot.starting.y + delta_y, 1, world.maxy), landing.z)
	if(istype(shot.original, /obj/effect/abstract/stationtrauma_map_projection))
		var/obj/effect/abstract/stationtrauma_map_projection/projection = shot.original
		shot.UnregisterSignal(projection, COMSIG_QDELETING)
		shot.original = projection.visual_source
		if(shot.original && shot.original != shot.firer)
			shot.RegisterSignal(shot.original, COMSIG_QDELETING, TYPE_PROC_REF(/obj/projectile, original_deleted))
	if(shot.hitscan)
		shot.create_hitscan_point()
		shot.generate_hitscan_tracers(impact_point = FALSE, impact_visual = FALSE)
	// Finish the relocation before native hit scanning can delete a hitscan or split its beam across Z.
	shot.fired = FALSE
	var/free_move = shot.free_hitscan_forceMove
	shot.free_hitscan_forceMove = TRUE
	shot.forceMove(landing)
	if(QDELETED(shot))
		return FALSE
	shot.free_hitscan_forceMove = free_move
	shot.fired = TRUE
	if(shot.hitscan)
		shot.record_hitscan_start(offset = FALSE)
	shot.scan_moved_turf()
	// forceMove scans living targets, but dense cover on the landing also needs ordinary projectile impact.
	for(var/obj/obstacle in landing)
		if(QDELETED(shot) || shot.deletion_queued)
			break
		if(shot.can_hit_target(obstacle, obstacle == shot.original))
			shot.Bump(obstacle)
	return TRUE
/** Environment adapters may require an initialized exterior medium on the landing. */
/datum/component/stationtrauma_map_passage/proc/landing_available()
	return !QDELETED(landing) && isspaceturf(landing)

/** Transfer an actor and its buckled or pulled occupants. */
/datum/component/stationtrauma_map_passage/proc/move_actor(atom/movable/arrived)
	return arrived.zMove(null, landing, ZMOVE_ALLOW_BUCKLED|ZMOVE_INCLUDE_PULLED)
