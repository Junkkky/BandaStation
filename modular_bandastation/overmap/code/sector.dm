// AI EDIT START - overmap module integration
/** A sector owns its persistent geography; registered vessels own their navigation and observations. */
/datum/stationtrauma_overmap_sector
	/// Owned stable destination ID to physical destination mapping.
	var/list/sites = list()
	/// Sector-owned persistent terrain and sensor sources.
	var/list/contacts = list()
	/// Native, unique shuttle IDs are independent of crew type and display names.
	var/list/ships = list()

/datum/stationtrauma_overmap_sector/Destroy()
	for(var/id in ships.Copy())
		qdel(ships[id])
	QDEL_LIST_ASSOC_VAL(sites)
	QDEL_LIST(contacts)
	return ..()

/** Register a unique hull ID and lend this sector geography to its navigation instance. */
/datum/stationtrauma_overmap_sector/proc/register(id, datum/stationtrauma_overmap/navigation)
	if(!istext(id) || !length(id) || QDELETED(navigation) || navigation.sector || length(navigation.sites) || length(navigation.contacts) || ships[id])
		return FALSE
	ships[id] = navigation
	navigation.sector = src
	navigation.sites = sites
	navigation.contacts = contacts
	return TRUE

/** Release a registered hull and detach its borrowed sector geography. */
/datum/stationtrauma_overmap_sector/proc/unregister(datum/stationtrauma_overmap/navigation)
	if(navigation.sector != src)
		return FALSE
	for(var/id in ships)
		if(ships[id] == navigation)
			ships -= id
			break
	navigation.sector = null
	navigation.sites = list()
	navigation.contacts = list()
	return TRUE
// AI EDIT END
