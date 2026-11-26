/// Exercise native collision on the live map without damaging the station or another test's fixture.
/obj/projectile/bullet/stationtrauma_kinetic/site_test
	damage = 0

/obj/projectile/bullet/stationtrauma_kinetic/site_test/on_hit(atom/target, blocked = 0, pierce_hit)
	return ..(target, 100, pierce_hit)

/datum/unit_test/stationtrauma_fixed_site_combat/Run()
	if(SSmapping.current_map.space_overmap?["station_id"] != "cyberiad")
		return
	var/datum/stationtrauma_overmap_sector/space/home/home = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	var/datum/stationtrauma_overmap/space/source = home.ships["overmap_cargo_s"]
	var/datum/stationtrauma_overmap_site/space/docking_target/station = home.sites["traffic:station"]
	TEST_ASSERT_NOTNULL(source, "The mapped cargo shuttle must have a chart.")
	TEST_ASSERT_NOTNULL(station, "The main station must be present.")
	var/list/targets = list(station)
	for(var/level in home.trade_outpost_names)
		var/datum/stationtrauma_overmap_site/space/docking_target/outpost = home.sites["traffic:outpost:[level]"]
		TEST_ASSERT_NOTNULL(outpost, "[home.trade_outpost_names[level]] must have a public chart contact.")
		targets += outpost
	TEST_ASSERT(length(targets) > 1, "At least one trade outpost must be present.")
	var/obj/machinery/computer/stationtrauma_drop_pod_console/console = allocate(/obj/machinery/computer/stationtrauma_drop_pod_console)
	var/mob/living/carbon/human/consistent/operator = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/passenger = allocate(/mob/living/carbon/human/consistent)
	for(var/datum/stationtrauma_overmap_site/space/docking_target/site as anything in targets)
		TEST_ASSERT(site in home.fixed_combat_sites, "[site.name] must appear as a sector target.")
		var/datum/stationtrauma_overmap_site/space/berth = site.combat_berth(home)
		TEST_ASSERT_NOTNULL(berth, "[site.name] must resolve a physical berth.")
		var/datum/stationtrauma_kinetic_shot/shot = allocate(/datum/stationtrauma_kinetic_shot)
		shot.sector_ref = WEAKREF(home)
		shot.projectile_type = /obj/projectile/bullet/stationtrauma_kinetic/site_test
		var/heading = 90 + (targets.Find(site) - 1) * 45
		shot.direction_x = sin(heading)
		shot.direction_y = cos(heading)
		shot.pos_x = site.pos_x - (site.radius + 2) * shot.direction_x
		shot.pos_y = site.pos_y - (site.radius + 2) * shot.direction_y
		shot.remaining = site.radius + 4
		shot.last_update = world.time - 1 SECONDS
		var/previous_impact = home.next_kinetic_impact
		shot.process(1)
		TEST_ASSERT_NOTNULL(shot.finished_at, "The sector path must intersect [site.name].")
		var/timeout = world.time + 12 SECONDS
		UNTIL(home.next_kinetic_impact > previous_impact || world.time >= timeout)
		TEST_ASSERT(home.next_kinetic_impact > previous_impact, "The incoming round must collide on [site.name]'s physical map.")
		var/list/impact = home.kinetic_impacts[length(home.kinetic_impacts)]
		TEST_ASSERT_EQUAL(impact["x"], site.pos_x, "The native collision must identify the targeted installation.")
		TEST_ASSERT_EQUAL(impact["y"], site.pos_y, "The native collision must identify the targeted installation.")

		var/obj/structure/closet/stationtrauma_drop_pod/pod = allocate(/obj/structure/closet/stationtrauma_drop_pod)
		var/obj/item/cargo = allocate(/obj/item, pod)
		if(site == station)
			passenger.forceMove(pod)
		pod.opened = FALSE
		var/original_x = source.pos_x
		var/original_y = source.pos_y
		source.pos_x = site.pos_x - 5
		source.pos_y = site.pos_y
		var/launched = console.launch_pod(source, pod, site.id, "site", operator)
		source.pos_x = original_x
		source.pos_y = original_y
		TEST_ASSERT(launched, "The console must launch a loaded capsule at [site.name].")
		var/datum/stationtrauma_drop_flight/flight = pod.flight
		allocated += flight
		if(site == station)
			pod.get_remote_view_fullscreens(passenger)
			var/atom/movable/screen/fullscreen/cabin = passenger.screens["remote_view"]
			TEST_ASSERT_EQUAL(cabin?.icon_state, "flight1", "Entering the in-flight pod perspective must show the cruise loop.")
			passenger.forceMove(get_turf(operator))
			TEST_ASSERT_NULL(passenger.screens["remote_view"], "Forced egress must remove the flight view immediately.")
			passenger.forceMove(pod)
			flight.arrives_at = world.time + 1 SECONDS
			pod.get_remote_view_fullscreens(passenger)
			cabin = passenger.screens["remote_view"]
			TEST_ASSERT_EQUAL(cabin?.icon_state, "flight2", "Reacquiring the capsule view on final approach must show braking.")
		flight.arrive()
		TEST_ASSERT_EQUAL(flight.result, "landed", "The capsule must land on [site.name].")
		TEST_ASSERT_NULL(pod.flight, "Touchdown must unlock the hatch.")
		TEST_ASSERT_EQUAL(cargo.loc, pod, "The payload must arrive inside the capsule.")
		if(site == station)
			TEST_ASSERT(!istype(passenger.screens["remote_view"], /atom/movable/screen/fullscreen/stationtrauma_drop_pod), "Landing must clear the flight view even if the passenger disconnected.")
			TEST_ASSERT(is_station_level(pod.z) && istype(get_area(pod), /area/station), "The capsule must land on a station deck.")
		else
			TEST_ASSERT_EQUAL(get_area(pod), relay_mapped_area(berth), "The capsule must land inside the selected outpost.")
