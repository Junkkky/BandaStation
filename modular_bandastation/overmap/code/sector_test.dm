/// Three registrations guard against coupling the model to the two-hull demonstration map.
/datum/unit_test/stationtrauma_overmap_sector/Run()
	var/datum/stationtrauma_overmap_sector/sector = new
	var/datum/stationtrauma_overmap_site/site = new
	site.id = "hidden"
	site.discovered = FALSE
	sector.sites[site.id] = site
	var/list/ships = list()
	for(var/index in 1 to 3)
		var/datum/stationtrauma_overmap/ship = new
		ships += ship
		if(!sector.register("ship_[index]", ship) || ship.sites != sector.sites || ship.contacts != sector.contacts)
			Fail("Each registered ship must share sector geography", __FILE__, __LINE__)
	var/datum/stationtrauma_overmap/first = ships[1]
	var/datum/stationtrauma_overmap/second = ships[2]
	first.discover_site(site)
	first.visited_sites[site.id] = TRUE
	first.velocity_x = 3
	if(!first.knows_site(site) || second.knows_site(site) || second.visited_sites[site.id] || second.velocity_x)
		Fail("Observations and movement must remain ship-local", __FILE__, __LINE__)
	if(sector.register("ship_1", second) || length(sector.ships) != 3)
		Fail("Duplicate registrations must preserve the registry", __FILE__, __LINE__)
	qdel(first)
	if(length(sector.ships) != 2 || QDELETED(site) || second.sites[site.id] != site)
		Fail("Deleting one ship must preserve the sector and its peers", __FILE__, __LINE__)
	qdel(sector)
	if(!QDELETED(second) || !QDELETED(site))
		Fail("Deleting the sector must release its ships and geography", __FILE__, __LINE__)

/// Passive reception follows emissions, and losing the source must stop position updates.
/datum/unit_test/stationtrauma_passive_scan/Run()
	var/datum/stationtrauma_overmap_sector/sector = new
	var/datum/stationtrauma_overmap/observer = new
	var/datum/stationtrauma_overmap/emitter = new
	var/datum/stationtrauma_overmap/distant = new
	sector.register("observer", observer)
	sector.register("emitter", emitter)
	sector.register("distant", distant)
	emitter.pos_x = 1200
	distant.pos_x = 1201
	observer.observe_ships(600, passive = TRUE)
	if(length(observer.ship_echo_data()))
		Fail("Non-emitting sources must not appear on passive sensors", __FILE__, __LINE__)
	emitter.last_ping = world.time
	distant.last_ping = world.time
	observer.observe_ships(600, passive = TRUE)
	var/list/echoes = observer.ship_echo_data()
	if(length(echoes) != 1)
		Fail("A pulse must be detectable exactly up to twice the sensor range", __FILE__, __LINE__)
	else
		var/list/echo = echoes[1]
		var/number = echo["id"]
		if(echo["x"] != 1200 || echo["mode"] != "passive")
			Fail("Passive measurements must retain their channel and measured position", __FILE__, __LINE__)
		emitter.last_ping = world.time - 5 SECONDS
		distant.last_ping = emitter.last_ping
		emitter.pos_x = 400
		observer.observe_ships(600, passive = TRUE)
		echoes = observer.ship_echo_data()
		echo = echoes[1]
		if(echo["x"] != 1200)
			Fail("An expired pulse must not keep tracking its source", __FILE__, __LINE__)
		observer.observe_ships(600)
		echoes = observer.ship_echo_data()
		echo = echoes[1]
		if(echo["x"] != 400 || echo["id"] != number || echo["mode"] != "active")
			Fail("Active and passive measurements must refer to the same local contact", __FILE__, __LINE__)
	qdel(sector)

/// A directed radio request must not become a free sensor sweep or leak native vessel IDs.
/datum/unit_test/stationtrauma_radio_contact/Run()
	var/datum/stationtrauma_overmap_sector/sector = new
	var/datum/stationtrauma_overmap/observer = new
	var/datum/stationtrauma_overmap/sender = new
	var/datum/stationtrauma_overmap/hidden = new
	sector.register("observer", observer)
	sector.register("secret_sender", sender)
	sector.register("hidden", hidden)
	sender.pos_x = 20
	if(observer.record_ship_observation("secret_sender", sender, "signal") != 1 || length(observer.ship_observations) != 1 || length(sender.ship_observations) || length(hidden.ship_observations))
		Fail("Radio contact performed a sweep or changed another crew's observations", __FILE__, __LINE__)
	var/list/echoes = observer.ship_echo_data()
	var/list/echo = echoes[1]
	if(echo["mode"] != "signal" || echo["x"] != 20 || !isnum(echo["id"]) || findtext(json_encode(echo), "secret_sender"))
		Fail("Radio contact lost its sampled mode/position or exposed a native ID", __FILE__, __LINE__)
	if(observer.record_ship_observation("hidden", sender, "signal") || observer.record_ship_observation("absent", sender, "signal") || length(observer.ship_observations) != 1)
		Fail("Radio contact accepted a mismatched sector registration", __FILE__, __LINE__)
	qdel(sector)

/// Motion comes from separated observations; reacquisition must not depend on an open UI.
/datum/unit_test/stationtrauma_contact_motion/Run()
	var/datum/stationtrauma_overmap_sector/sector = new
	var/datum/stationtrauma_overmap/observer = new
	var/datum/stationtrauma_overmap/target = new
	sector.register("observer", observer)
	sector.register("target", target)
	target.pos_x = 100
	target.pos_y = 20
	target.velocity_x = 999
	target.velocity_y = -999
	observer.observe_ships(600)
	var/list/echoes = observer.ship_echo_data()
	var/list/echo = echoes[1]
	var/number = echo["id"]
	if(!isnull(echo["vx"]) || !isnull(echo["vy"]))
		Fail("A single measurement cannot reveal the target's real velocity", __FILE__, __LINE__)
	var/list/record = observer.ship_observations["target"]
	record["seen"] = world.time - 2 SECONDS
	target.pos_x = 106
	target.pos_y = 28
	target.last_ping = world.time
	observer.observe_ships(600, passive = TRUE)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["vx"] != 3 || echo["vy"] != 4 || echo["id"] != number || echo["mode"] != "passive")
		Fail("Active and passive samples must measure motion from positions and elapsed time", __FILE__, __LINE__)
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["vx"] != 3 || echo["vy"] != 4)
		Fail("Same-tick observations must preserve the last motion estimate", __FILE__, __LINE__)
	record = observer.ship_observations["target"]
	record["seen"] = world.time - 2 SECONDS
	observer.pos_x = 100
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(isnull(echo["vx"]) || isnull(echo["vy"]) || echo["vx"] || echo["vy"])
		Fail("Observer movement must not turn a stationary contact into a moving target", __FILE__, __LINE__)
	target.pos_x = 10000
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["x"] != 106 || echo["y"] != 28 || echo["vx"] || echo["vy"])
		Fail("An unseen target must not update its measured position or motion", __FILE__, __LINE__)
	echo["vx"] = 123
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["vx"] != 0)
		Fail("UI data must not expose mutable motion records", __FILE__, __LINE__)
	target.pos_x = 106
	record = observer.ship_observations["target"]
	record["seen"] = world.time - ST_NAV_SHIP_MEMORY + 1
	if(observer.observe_ships(600))
		Fail("A measurement inside the memory lifetime must preserve its contact number", __FILE__, __LINE__)
	record = observer.ship_observations["target"]
	record["seen"] = world.time - ST_NAV_SHIP_MEMORY
	var/found = observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(found != 1 || echo["id"] == number || !isnull(echo["vx"]) || !isnull(echo["vy"]))
		Fail("Reacquiring an expired contact must create a fresh measurement even without a UI refresh", __FILE__, __LINE__)
	qdel(sector)

/// Measurements must not turn into remote tracking, identity disclosure or shared crew knowledge.
/datum/unit_test/stationtrauma_ship_scan/Run()
	var/datum/stationtrauma_overmap_sector/sector = new
	var/datum/stationtrauma_overmap/observer = new
	var/datum/stationtrauma_overmap/nearby = new
	var/datum/stationtrauma_overmap/distant = new
	sector.register("observer", observer)
	sector.register("secret_identity", nearby)
	sector.register("distant", distant)
	nearby.pos_x = 600
	distant.pos_x = 601
	if(observer.observe_ships(600) != 1 || length(observer.ship_observations) != 1 || length(nearby.ship_observations))
		Fail("A scan must include the exact range boundary, exclude self and retain private observations", __FILE__, __LINE__)
	var/list/echoes = observer.ship_echo_data()
	var/list/echo = echoes[1]
	if(!isnum(echo["id"]) || length(echo) != 5 || echo["x"] != 600 || echo["age"] != 0 || echo["mode"] != "active")
		Fail("UI data must contain only a local number, measured coordinates, age and sensor channel", __FILE__, __LINE__)
	var/contact_number = echo["id"]
	nearby.pos_x = 800
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["x"] != 600)
		Fail("An undetected moving ship must not update its last measured position", __FILE__, __LINE__)
	nearby.pos_x = 400
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["x"] != 400 || echo["id"] != contact_number)
		Fail("A repeated detection must refresh the existing measurement", __FILE__, __LINE__)
	qdel(nearby)
	if(length(observer.ship_echo_data()) != 1)
		Fail("A target disappearing must not remotely erase its last measured position", __FILE__, __LINE__)
	var/list/record = observer.ship_observations["secret_identity"]
	record["seen"] = world.time - ST_NAV_SHIP_MEMORY
	if(length(observer.ship_echo_data()) || length(observer.ship_observations))
		Fail("Stale measurements must expire at their lifetime boundary", __FILE__, __LINE__)
	qdel(sector)
