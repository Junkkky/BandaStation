/// Chart ownership needs no physical hull or processing loop.
/datum/stationtrauma_overmap/space/chart_test/New()
	return

/datum/unit_test/stationtrauma_sector_charts/Run()
	var/datum/stationtrauma_overmap_sector/space/home = new /datum/stationtrauma_overmap_sector/space/home
	var/datum/stationtrauma_overmap_sector/space/away = new
	var/datum/stationtrauma_overmap/space/first = new /datum/stationtrauma_overmap/space/chart_test
	var/datum/stationtrauma_overmap/space/second = new /datum/stationtrauma_overmap/space/chart_test
	var/datum/stationtrauma_overmap_site/space/home_site = new
	var/datum/stationtrauma_overmap_site/space/away_site = new
	home_site.id = away_site.id = "same_local_id"
	home_site.discovered = away_site.discovered = FALSE
	home.sites[home_site.id] = home_site
	away.sites[away_site.id] = away_site
	var/datum/stationtrauma_overmap_zone/zone = new("Home cloud", "nebula", 0, 0, 10)
	home.zones += zone
	if(!home.register("first", first) || !home.register("second", second))
		Fail("Space hull registration failed", __FILE__, __LINE__)
	first.discover_site(home_site)
	first.visited_sites[home_site.id] = TRUE
	first.charted_zones[zone] = TRUE
	if(away.unregister(first) || first.sector != home)
		Fail("A foreign sector cannot unregister a hull", __FILE__, __LINE__)
	if(!home.unregister(first) || !away.register("first", first))
		Fail("Unregister/register must support a sector transfer", __FILE__, __LINE__)
	if(first.knows_site(away_site) || first.visited_sites[away_site.id] || length(first.charted_zones) || second.knows_site(home_site))
		Fail("Local chart IDs must not leak across sectors or crews", __FILE__, __LINE__)
	first.discover_site(away_site)
	if(first.zones != away.zones || first.sites != away.sites || first.contacts != away.contacts)
		Fail("The destination must supply its own geography", __FILE__, __LINE__)
	away.unregister(first)
	home.register("first", first)
	if(!first.knows_site(home_site) || !first.visited_sites[home_site.id] || !first.charted_zones[zone])
		Fail("Returning must restore discoveries and visits", __FILE__, __LINE__)
	qdel(first)
	if(QDELETED(home_site) || second.sites[home_site.id] != home_site || !away.ship_charts["first"])
		Fail("Deleting a hull must preserve shared sites and round-local charts", __FILE__, __LINE__)
	qdel(home)
	qdel(away)
