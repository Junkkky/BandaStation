// AI EDIT START - overmap module integration
/** Persistent virtual destination and its physical berth. */
/datum/stationtrauma_overmap_site
	/// Stable mapped docking ID, independent of display name and storage z.
	var/id
	/// Crew-facing name of the destination or sensed source.
	var/name
	/// Virtual easting; physical turf coordinates are independent.
	var/pos_x
	/// Virtual northing; physical turf coordinates are independent.
	var/pos_y
	/// Unknown sites cannot be selected or disclosed by a navigation display until detected.
	var/discovered = TRUE
	/// Set only after the physical arrival guard succeeds, retained for subsequent visits.
	var/visited = FALSE
	/// Radius at which a fully prepared location may be entered.
	var/radius = 80
	/// Physical arrival point; null until the environment adapter finishes loading.
	var/obj/docking_port/stationary/berth
	/// Failed partial native loads must not allocate another copy on a repeated click.
	var/failed = FALSE

/** Ship-local shared snapshots follow Voidcrew's ship_sensors.dm without scanning physical maps. */
/datum/stationtrauma_overmap_contact
	/// Crew-facing name of the destination or sensed source.
	var/name = "контакт"
	/// Virtual easting; physical turf coordinates are independent.
	var/pos_x = 0
	/// Virtual northing; physical turf coordinates are independent.
	var/pos_y = 0
	/// Acoustic source strength; zero is invisible to passive sonar.
	var/noise = 0

/** Terrain is a line segment; collision and sonar share exactly these coordinates. */
/datum/stationtrauma_overmap_terrain
	parent_type = /datum/stationtrauma_overmap_contact
	name = "скальный массив"
	/// Easting of the blocking line segment endpoint.
	var/end_x
	/// Northing of the blocking line segment endpoint.
	var/end_y
	/// Destroyed physical obstacles remain chart records, but no longer block movement or planning.
	var/blocking = TRUE

/datum/stationtrauma_overmap_terrain/New(ax, ay, bx, by)
	pos_x = ax
	pos_y = ay
	end_x = bx
	end_y = by

/** Nearest point gives both sonar range and the actual side of a hull impact. */
/datum/stationtrauma_overmap_terrain/proc/nearest(px, py)
	var/length_squared = (end_x - pos_x) ** 2 + (end_y - pos_y) ** 2
	var/fraction = length_squared ? clamp(((px - pos_x) * (end_x - pos_x) + (py - pos_y) * (end_y - pos_y)) / length_squared, 0, 1) : 0
	return list(pos_x + fraction * (end_x - pos_x), pos_y + fraction * (end_y - pos_y))

/** Passive detection reports sound sources; own machinery masks weak or distant contacts. */
/datum/stationtrauma_overmap/proc/listen()
	next_listen = world.time + 1 SECONDS
	echoes = list()
	var/masking = 1 + acoustic_noise() / 100
	for(var/datum/stationtrauma_overmap_contact/contact as anything in contacts)
		if(contact.noise <= 0)
			continue
		var/distance = sqrt((contact.pos_x - pos_x) ** 2 + (contact.pos_y - pos_y) ** 2)
		if(distance <= ST_NAV_PASSIVE_RANGE * min(1, contact.noise / 50) / masking)
			echoes += list(list("kind" = "noise", "x" = contact.pos_x, "y" = contact.pos_y))

/** Detect terrain and destinations within active sensor range. */
/datum/stationtrauma_overmap/proc/ping()
	if(!active_sonar || world.time < next_ping)
		return FALSE
	last_ping = world.time
	next_ping = world.time + ST_NAV_PING_INTERVAL
	echoes = list()
	for(var/datum/stationtrauma_overmap_contact/contact as anything in contacts)
		var/cx = contact.pos_x
		var/cy = contact.pos_y
		if(istype(contact, /datum/stationtrauma_overmap_terrain))
			var/datum/stationtrauma_overmap_terrain/terrain = contact
			var/list/point = terrain.nearest(pos_x, pos_y)
			cx = point[1]
			cy = point[2]
		if((cx - pos_x) ** 2 + (cy - pos_y) ** 2 > ST_NAV_ACTIVE_RANGE ** 2)
			continue
		if(istype(contact, /datum/stationtrauma_overmap_terrain))
			var/datum/stationtrauma_overmap_terrain/terrain = contact
			var/list/echo = list("kind" = "terrain", "x" = terrain.pos_x, "y" = terrain.pos_y, "end_x" = terrain.end_x, "end_y" = terrain.end_y)
			echoes += list(echo)
			charted_terrain[terrain] = echo
		else
			echoes += list(list("kind" = "echo", "x" = cx, "y" = cy))
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/site = sites[id]
		if((site.pos_x - pos_x) ** 2 + (site.pos_y - pos_y) ** 2 > ST_NAV_ACTIVE_RANGE ** 2)
			continue
		discover_site(site)
		echoes += list(list("kind" = "site", "x" = site.pos_x, "y" = site.pos_y))
	return TRUE

/** Serialize only discovered destinations; hidden names, IDs and coordinates stay server-side. */
/datum/stationtrauma_overmap/proc/known_sites()
	var/list/known = list()
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/site = sites[id]
		if(!knows_site(site))
			continue
		known += list(list("id" = id, "name" = site.name, "x" = site.pos_x, "y" = site.pos_y, "distance" = round(distance_to(site)), "failed" = site.failed, "visited" = (site.visited || visited_sites[site.id])))
	return known

/** Own-vessel noise masking passive sensors. */
/datum/stationtrauma_overmap/proc/acoustic_noise()
	return 0

/** Emissions remain noticeable briefly after a pulse, including one at world time zero. */
/datum/stationtrauma_overmap/proc/detection_signature()
	return !isnull(last_ping) && world.time < last_ping + 5 SECONDS ? 2 : 0

/** Return this vessel identification reply; environment adapters supply the transmitter. */
/datum/stationtrauma_overmap/proc/transponder_identity()
	return null

/** Measurements retain sampled motion and copied registration, never live target references. */
/datum/stationtrauma_overmap/proc/observe_ships(reach, passive = FALSE)
	if(!sector)
		return 0
	var/found = 0
	for(var/id in sector.ships)
		var/datum/stationtrauma_overmap/other = sector.ships[id]
		if(other == src || !other.is_operational() || other.preparing)
			continue
		var/detection_range = passive ? reach * other.detection_signature() : reach
		if(detection_range <= 0 || (other.pos_x - pos_x) ** 2 + (other.pos_y - pos_y) ** 2 > detection_range ** 2)
			continue
		found += record_ship_observation(id, other, passive ? "passive" : "active")
	return found

/** Record a sensor or radio observation under its crew-local contact number. */
/datum/stationtrauma_overmap/proc/record_ship_observation(id, datum/stationtrauma_overmap/other, mode)
	if(QDELETED(other) || !sector || other == src || sector.ships[id] != other)
		return 0
	var/list/previous = ship_observations[id]
	if(previous && world.time - previous["seen"] >= ST_NAV_SHIP_MEMORY)
		previous = null
	var/number = previous ? previous["id"] : ++next_contact_number
	var/list/observation = list("id" = number, "x" = other.pos_x, "y" = other.pos_y, "seen" = world.time, "mode" = mode)
	if(previous)
		var/seconds = (world.time - previous["seen"]) / (1 SECONDS)
		if(seconds > 0)
			observation["vx"] = (other.pos_x - previous["x"]) / seconds
			observation["vy"] = (other.pos_y - previous["y"]) / seconds
		else if(!isnull(previous["vx"]))
			// Active, passive and radio samples may arrive in the same tick.
			observation["vx"] = previous["vx"]
			observation["vy"] = previous["vy"]
	var/list/identity = other.transponder_identity()
	if(identity)
		observation["identity"] = identity.Copy()
	ship_observations[id] = observation
	return !previous

/** Expired measurements disappear without consulting a target's current position or existence. */
/datum/stationtrauma_overmap/proc/ship_echo_data()
	var/list/observations = list()
	for(var/index = length(ship_observations), index >= 1, index--)
		var/id = ship_observations[index]
		var/list/record = ship_observations[id]
		var/age = world.time - record["seen"]
		if(age >= ST_NAV_SHIP_MEMORY)
			ship_observations -= id
			continue
		var/list/echo = list("id" = record["id"], "x" = record["x"], "y" = record["y"], "age" = age / (1 SECONDS), "mode" = record["mode"])
		if(!isnull(record["vx"]))
			echo["vx"] = record["vx"]
			echo["vy"] = record["vy"]
		var/list/identity = record["identity"]
		if(identity)
			echo["identity"] = identity.Copy()
		observations += list(echo)
	return observations
// AI EDIT END
