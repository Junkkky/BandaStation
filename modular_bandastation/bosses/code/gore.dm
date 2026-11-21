/**
 * A body bursting: blood pools within `radius`, splatters out to twice that, and sprays flying across the room.
 * With `at_witnesses` one more spray goes straight at each person nearby, so nobody stays clean.
 */
/proc/event_gore_burst(turf/center, list/blood_dna, sprays = 16, vomit = FALSE, radius = 2, at_witnesses = TRUE)
	if(!center)
		return
	for(var/turf/open/floor in range(radius, center))
		if(prob(70))
			new /obj/effect/decal/cleanable/blood(floor, null, blood_dna)
		else if(vomit && prob(50))
			new /obj/effect/decal/cleanable/vomit(floor)
	for(var/turf/open/floor in range(radius * 2, center))
		if(get_dist(center, floor) > radius && prob(30))
			new /obj/effect/decal/cleanable/blood/splatter(floor, null, blood_dna)
	var/list/targets = list()
	for(var/i in 1 to sprays)
		targets += locate(clamp(center.x + rand(-6, 6), 1, world.maxx), clamp(center.y + rand(-6, 6), 1, world.maxy), center.z)
	if(at_witnesses)
		for(var/mob/living/carbon/human/witness in view(5, center))
			targets += get_turf(witness)
	for(var/turf/target as anything in targets)
		if(target == center)
			continue
		var/obj/effect/decal/cleanable/blood/hitsplatter/spray = new(center, null, blood_dna, 6)
		spray.fly_towards(target, get_dist(center, target) + 2)
