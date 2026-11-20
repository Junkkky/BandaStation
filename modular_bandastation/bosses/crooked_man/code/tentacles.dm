/// Goliath tentacles for the Crooked Man: they rise with the same visible delay but hold only three seconds.
/obj/effect/goliath_tentacle/crooked
	grapple_time = 3 SECONDS

/obj/effect/goliath_tentacle/drag/crooked
	grapple_time = 3 SECONDS

/// Spikes under a chosen spot and around it.
/datum/action/cooldown/mob_cooldown/goliath_tentacles/crooked
	name = "Шипы"
	desc = "Из пола под выбранным местом и вокруг него вырываются шипы, хватающие и ранящие."
	cooldown_time = 10 SECONDS

/datum/action/cooldown/mob_cooldown/goliath_tentacles/crooked/Activate(atom/target)
	new /obj/effect/goliath_tentacle/crooked(target, owner)
	for(var/spawndir in GLOB.cardinals)
		var/turf/adjacent_target = get_step(target, spawndir)
		if(isopenturf(adjacent_target) && !isgroundlessturf(adjacent_target))
			new /obj/effect/goliath_tentacle/crooked(adjacent_target, owner)
	StartCooldown()
	return TRUE

/// A ring of spikes around him; whoever holds him has to step back.
/datum/action/cooldown/mob_cooldown/tentacle_burst/crooked
	name = "Кольцо шипов"
	desc = "Шипы вырываются из пола кольцом вокруг вас."
	cooldown_time = 15 SECONDS

/datum/action/cooldown/mob_cooldown/tentacle_burst/crooked/Activate(atom/target)
	for(var/dir in GLOB.alldirs)
		var/turf/adjacent_target = get_step(owner, dir)
		if(adjacent_target)
			new /obj/effect/goliath_tentacle/drag/crooked(adjacent_target, owner)
	owner.visible_message(span_warning("Вокруг [owner] из пола вырываются шипы!"))
	StartCooldown()
	return TRUE

/// A line of spikes running out to the chosen spot.
/datum/action/cooldown/mob_cooldown/tentacle_grasp/crooked
	name = "Дорожка шипов"
	desc = "Шипы бегут по полу от вас к выбранному месту."
	cooldown_time = 15 SECONDS

/datum/action/cooldown/mob_cooldown/tentacle_grasp/crooked/Activate(atom/target)
	new /obj/effect/temp_visual/effect_trail/burrowed_tentacle/crooked(owner.loc, target, owner)
	StartCooldown()
	return TRUE

/obj/effect/temp_visual/effect_trail/burrowed_tentacle/crooked
	spawned_effect = /obj/effect/goliath_tentacle/drag/crooked
