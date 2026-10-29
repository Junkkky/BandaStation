// AI EDIT START - space overmap module integration
/** Persistent obstacle state; only nearby rocks need physical atoms on the flight Z. */
/datum/stationtrauma_overmap_terrain/asteroid
	name = "астероид"
	/// Persistent rock integrity shared by its physical projections.
	var/integrity = 200
	/// Each ship has its own physical projection of the same persistent obstacle.
	var/list/markers = list()

/datum/stationtrauma_overmap_terrain/asteroid/Destroy()
	for(var/datum/stationtrauma_overmap/space/owner as anything in markers.Copy())
		hide(owner)
	return ..()

/** Delete this ship physical rock projection without destroying the persistent obstacle. */
/datum/stationtrauma_overmap_terrain/asteroid/proc/hide(datum/stationtrauma_overmap/space/owner)
	var/obj/structure/stationtrauma_asteroid/marker = markers[owner]
	markers -= owner
	if(marker)
		marker.rock = null
		marker.owner = null
		qdel(marker)

/** Damageable flight-level projection of a persistent sector obstacle. */
/obj/structure/stationtrauma_asteroid
	name = "дрейфующий астероид"
	desc = "Крупный обломок породы. Его можно разбить огнём или добывающим инструментом."
	icon = 'icons/obj/meteor.dmi'
	icon_state = "large"
	anchored = TRUE
	density = TRUE
	max_integrity = 200
	/// Persistent rock represented by this damageable physical projection.
	var/datum/stationtrauma_overmap_terrain/asteroid/rock
	/// Navigation instance whose flight level contains this projection.
	var/datum/stationtrauma_overmap/space/owner

/obj/structure/stationtrauma_asteroid/Destroy()
	if(rock)
		rock.markers -= owner
	rock = null
	owner = null
	return ..()

/obj/structure/stationtrauma_asteroid/on_update_integrity(old_value, new_value)
	. = ..()
	if(!rock || rock.integrity == new_value)
		return
	rock.integrity = new_value
	for(var/datum/stationtrauma_overmap/space/navigation as anything in rock.markers)
		var/obj/structure/stationtrauma_asteroid/marker = rock.markers[navigation]
		if(marker != src)
			marker.update_integrity(new_value)

/obj/structure/stationtrauma_asteroid/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour != TOOL_MINING)
		return ..()
	if(!tool.use_tool(src, user, 2 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	if(!QDELETED(src) && !QDELETED(tool) && user.is_holding(tool) && user.can_perform_action(src, NEED_DEXTERITY))
		take_damage(50, BRUTE, MELEE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/stationtrauma_asteroid/atom_destruction(damage_flag)
	if(rock)
		rock.blocking = FALSE
		for(var/datum/stationtrauma_overmap/space/navigation as anything in rock.markers.Copy())
			if(navigation != owner)
				rock.hide(navigation)
	new /obj/item/stack/ore/iron(drop_location(), 2)
	return ..()

/** Project bounded nearby contacts into the stationary ship's current physical orientation. */
/datum/stationtrauma_overmap/space/proc/update_asteroids()
	var/list/bounds = vessel.return_coords()
	var/cx = round((bounds[1] + bounds[3]) / 2)
	var/cy = round((bounds[2] + bounds[4]) / 2)
	var/rotation = course - dir2angle(vessel.preferred_direction)
	for(var/datum/stationtrauma_overmap_terrain/asteroid/rock in contacts)
		var/dx = (rock.pos_x + rock.end_x) / 2 - pos_x
		var/dy = (rock.pos_y + rock.end_y) / 2 - pos_y
		if(!rock.blocking || dx ** 2 + dy ** 2 > 55 ** 2)
			rock.hide(src)
			continue
		var/turf/tile = locate(cx + round(dx * cos(rotation) - dy * sin(rotation)), cy + round(dx * sin(rotation) + dy * cos(rotation)), vessel.z)
		if(!isspaceturf(tile) || vessel.shuttle_areas[get_area(tile)])
			rock.hide(src)
			continue
		var/obj/structure/stationtrauma_asteroid/marker = rock.markers[src]
		if(!marker)
			marker = new(tile)
			marker.rock = rock
			marker.owner = src
			rock.markers[src] = marker
			marker.update_integrity(rock.integrity)
		else
			marker.forceMove(tile)
// AI EDIT END
