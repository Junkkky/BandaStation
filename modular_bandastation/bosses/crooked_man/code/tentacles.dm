#define CROOKED_SPIKE_SCALE 1.6
// The spike's base sits 12.5 px below the icon centre; lift it back so it still grows out of its own tile.
#define CROOKED_SPIKE_MATRIX matrix(CROOKED_SPIKE_SCALE, 0, 0, 0, CROOKED_SPIKE_SCALE, 12.5 * (CROOKED_SPIKE_SCALE - 1))

/// Goliath tentacle logic drawn as a big lavaland bone spike: they rise with the same visible delay but hold only three seconds.
/obj/effect/goliath_tentacle/crooked
	name = "костяной шип"
	icon = 'modular_bandastation/bosses/crooked_man/icons/spikes.dmi'
	grapple_time = 3 SECONDS

/obj/effect/goliath_tentacle/crooked/Initialize(mapload, mob/living/goliath)
	. = ..()
	transform = CROOKED_SPIKE_MATRIX

/// Spikes under a chosen spot and around it.
/datum/action/cooldown/mob_cooldown/goliath_tentacles/crooked
	button_icon = 'modular_bandastation/bosses/icons/action_buttons.dmi'
	button_icon_state = "crooked_spikes"
	name = "Шипы"
	desc = "Из пола под выбранным местом и вокруг него вырываются шипы, хватающие и ранящие."
	cooldown_time = 10 SECONDS

/// Spikes only rise where he can see: a wall between him and the spot keeps it safe.
/datum/action/cooldown/mob_cooldown/goliath_tentacles/crooked/PreActivate(atom/target)
	if(!(get_turf(target) in view(max_range, owner)))
		owner.balloon_alert(owner, "не видно")
		return FALSE
	return ..()

/datum/action/cooldown/mob_cooldown/goliath_tentacles/crooked/Activate(atom/target)
	var/list/seen = view(max_range, owner)
	new /obj/effect/goliath_tentacle/crooked(target, owner)
	for(var/spawndir in GLOB.cardinals)
		var/turf/adjacent_target = get_step(target, spawndir)
		if(isopenturf(adjacent_target) && !isgroundlessturf(adjacent_target) && (adjacent_target in seen))
			new /obj/effect/goliath_tentacle/crooked(adjacent_target, owner)
	StartCooldown()
	return TRUE

/// A wave of spikes rolling out across the whole arena; only a wall between him and a tile keeps it safe.
/datum/action/cooldown/mob_cooldown/tentacle_burst/crooked
	button_icon = 'modular_bandastation/bosses/icons/action_buttons.dmi'
	button_icon_state = "crooked_wave"
	name = "Волна шипов"
	desc = "Шипы вырываются из пола кольцами, расходящимися от вас почти по всей арене. Укрыться можно только за стеной."
	cooldown_time = 25 SECONDS
	/// Outermost ring.
	var/radius = 7
	/// Delay between one ring and the next.
	var/ring_delay = 0.3 SECONDS

/datum/action/cooldown/mob_cooldown/tentacle_burst/crooked/Activate(atom/target)
	owner.visible_message(span_userdanger("Пол вокруг [owner] вздымается шипами — прячьтесь за стены!"))
	for(var/ring in 1 to radius)
		addtimer(CALLBACK(src, PROC_REF(spawn_ring), ring), (ring - 1) * ring_delay)
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/tentacle_burst/crooked/proc/spawn_ring(ring)
	if(QDELETED(owner) || owner.stat == DEAD || !isturf(owner.loc))
		return
	for(var/turf/open/spot in view(ring, owner))
		if(get_dist(owner, spot) == ring && !isgroundlessturf(spot))
			new /obj/effect/goliath_tentacle/crooked(spot, owner)

/// A line of spikes running out to the chosen spot; they hold in place like the other spikes instead of dragging to him.
/datum/action/cooldown/mob_cooldown/tentacle_grasp/crooked
	button_icon = 'modular_bandastation/bosses/icons/action_buttons.dmi'
	button_icon_state = "crooked_trail"
	name = "Дорожка шипов"
	desc = "Шипы бегут по полу от вас к выбранному месту."
	cooldown_time = 15 SECONDS

/datum/action/cooldown/mob_cooldown/tentacle_grasp/crooked/Activate(atom/target)
	new /obj/effect/temp_visual/effect_trail/burrowed_tentacle/crooked(owner.loc, target, owner)
	StartCooldown()
	return TRUE

/obj/effect/temp_visual/effect_trail/burrowed_tentacle/crooked
	spawned_effect = /obj/effect/goliath_tentacle/crooked

#undef CROOKED_SPIKE_SCALE
#undef CROOKED_SPIKE_MATRIX
