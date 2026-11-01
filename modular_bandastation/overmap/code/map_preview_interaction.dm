/** Keep native weapon checks; a nearby image still represents a remote ranged target. */
/obj/item/gun/fire_gun(atom/target, mob/living/user, flag, params)
	if(istype(target, /obj/effect/abstract/stationtrauma_map_projection))
		flag = FALSE
	return ..()

/** Shared click ownership preserves a live actor's visuals while aiming at the image's local coordinates. */
/datum/component/stationtrauma_map_click
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Every live image retaining this actor's click identity.
	var/list/projections = list()
	/// Leave an inherited flag that already belonged to another system intact.
	var/added_flag = FALSE

/datum/component/stationtrauma_map_click/Initialize()
	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE
	return ..()

/datum/component/stationtrauma_map_click/RegisterWithParent()
	var/atom/movable/actor = parent
	added_flag = !(actor.vis_flags & VIS_INHERIT_ID)
	actor.vis_flags |= VIS_INHERIT_ID

/datum/component/stationtrauma_map_click/UnregisterFromParent()
	var/atom/movable/actor = parent
	if(added_flag)
		actor.vis_flags &= ~VIS_INHERIT_ID
	for(var/datum/projection as anything in projections)
		UnregisterSignal(projection, COMSIG_QDELETING)
	projections.Cut()

/** Retain click forwarding until the last image is destroyed. */
/datum/component/stationtrauma_map_click/proc/add_projection(obj/effect/abstract/stationtrauma_map_projection/projection)
	if(projection in projections)
		return
	projections += projection
	RegisterSignal(projection, COMSIG_QDELETING, PROC_REF(remove_projection))

/** Release a deleted click projection from the real actor component. */
/datum/component/stationtrauma_map_click/proc/remove_projection(datum/projection)
	SIGNAL_HANDLER
	UnregisterSignal(projection, COMSIG_QDELETING)
	projections -= projection
	if(!projections.len)
		qdel(src)
