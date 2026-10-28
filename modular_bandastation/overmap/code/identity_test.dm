/datum/stationtrauma_overmap/identity_probe
	var/list/identity = list("callsign" = "Raven", "faction" = "NT")

/datum/stationtrauma_overmap/identity_probe/transponder_identity()
	return identity

/// Radio identity may change or disappear, but a continuously observed hull keeps its contact number.
/datum/unit_test/stationtrauma_transponder_tracking/Run()
	var/datum/stationtrauma_overmap_sector/sector = new
	var/datum/stationtrauma_overmap/observer = new
	var/datum/stationtrauma_overmap/identity_probe/target = new
	sector.register("observer", observer)
	sector.register("hidden_hull_id", target)
	target.pos_x = 100
	observer.observe_ships(600)
	var/list/echoes = observer.ship_echo_data()
	var/list/echo = echoes[1]
	var/contact_number = echo["id"]
	var/list/identity = echo["identity"]
	if(identity?["callsign"] != "Raven" || identity?["faction"] != "NT")
		Fail("Detected ships must expose their transmitted identity", __FILE__, __LINE__)
	target.identity["callsign"] = "Another ship"
	target.pos_x = 700
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	identity = echo["identity"]
	if(identity?["callsign"] != "Raven" || echo["x"] != 100)
		Fail("An unseen board change must not alter an existing measurement", __FILE__, __LINE__)
	target.pos_x = 400
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	identity = echo["identity"]
	if(identity?["callsign"] != "Another ship" || echo["id"] != contact_number)
		Fail("Changing a transponder must not create a new hull contact", __FILE__, __LINE__)
	identity["callsign"] = "Modified UI data"
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	identity = echo["identity"]
	if(identity?["callsign"] != "Another ship")
		Fail("UI serialization must not expose a mutable identity alias", __FILE__, __LINE__)
	target.identity = null
	observer.observe_ships(600)
	echoes = observer.ship_echo_data()
	echo = echoes[1]
	if(echo["identity"] || echo["id"] != contact_number || echo["x"] != 400)
		Fail("Disabling identification must retain the observed hull as an anonymous contact", __FILE__, __LINE__)
	qdel(sector)
