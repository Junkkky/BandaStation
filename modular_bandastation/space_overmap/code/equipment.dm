/** Finite emergency construction materials placed on the cargo platform. */
/obj/structure/closet/crate/stationtrauma_salvage
	name = "аварийный запас материалов"

/obj/structure/closet/crate/stationtrauma_salvage/PopulateContents()
	new /obj/item/stack/sheet/iron(src, 15)
	new /obj/item/stack/sheet/glass(src, 5)
	new /obj/item/stack/cable_coil(src, 20)

/** Starting EVA and mining equipment. */
/obj/structure/closet/crate/stationtrauma_space_eva
	name = "экспедиционное снаряжение"

/obj/structure/closet/crate/stationtrauma_space_eva/PopulateContents()
	for(var/index in 1 to 2)
		new /obj/item/clothing/suit/space(src)
		new /obj/item/clothing/head/helmet/space(src)
		new /obj/item/tank/jetpack/void(src)
		new /obj/item/clothing/mask/breath(src)
		new /obj/item/pickaxe(src)
		new /obj/item/storage/bag/ore(src)
	new /obj/item/pinpointer/stationtrauma_docking(src)

/**
 * Handheld guide to the airlock of the destination a vessel holds through a remote seam.
 *
 * Aboard, it points at the seam exit level with the berth, since the seam keeps the crossing row; beyond the seam it points
 * at the entrance airlock itself, or at the berth when the destination has none.
 */
/obj/item/pinpointer/stationtrauma_docking
	name = "стыковочный пеленгатор"
	desc = "Указывает путь к входному шлюзу объекта, у которого стоит корабль. На борту ведёт к точке выхода напротив шлюза."
	/// Turf to head for on the holder's level; null without a seam-docked destination there.
	var/turf/beacon

/obj/item/pinpointer/stationtrauma_docking/Destroy()
	beacon = null
	return ..()

/obj/item/pinpointer/stationtrauma_docking/scan_for_target()
	beacon = null
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			var/datum/stationtrauma_overmap_site/space/site = navigation?.docked
			if(!istype(navigation) || !istype(site) || site.landing || site.physical_docking || QDELETED(site.berth) || !navigation.connection.active)
				continue
			if(here.z == site.berth.z)
				beacon = site.entrance || get_turf(site.berth)
				return
			if(here.z != navigation.vessel.z)
				continue
			var/datum/stationtrauma_map_connection/connection = navigation.connection
			var/edge = connection.get_ship_edge(navigation.vessel.return_coords(), 1, connection.direction)
			if(isnull(edge))
				continue
			beacon = connection.direction & (EAST|WEST) ? locate(edge, site.berth.y, here.z) : locate(site.berth.x, edge, here.z)
			return

/obj/item/pinpointer/stationtrauma_docking/update_overlays()
	. = ..()
	var/turf/here = get_turf(src)
	if(!active || !beacon || here?.z != beacon.z)
		return
	// The base pinpointer tracks movables only; a turf beacon replaces its idle overlay.
	. -= "pinonnull"
	. += get_direction_icon(here, beacon)
