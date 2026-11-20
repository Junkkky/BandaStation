/// Mortal, player-controlled event character using the approved four-view design; as frail as a person.
/mob/living/basic/boss/heinrich_traizen
	name = "Генрих Трейзен III"
	// Speaks in the large bold type of a megaphone or a head of staff's loud headset.
	speech_span = SPAN_COMMAND
	desc = "Грузная фигура в изодранной парадной мантии с золотыми эполетами. Лицо скрыто промышленным противогазом."
	gender = MALE
	icon = 'modular_bandastation/bosses/heinrich_traizen/icons/heinrich_traizen.dmi'
	icon_state = "idle"
	icon_living = "idle"
	icon_dead = "dead"
	pixel_x = -32
	base_pixel_x = -32
	// Three tiles wide like the sprite; he never moves, so the wide body only has to block and be hit.
	bound_width = 96
	bound_x = -32
	maxHealth = 100
	health = 100
	ai_controller = null
	faction = list(FACTION_MINING, FACTION_BOSS, FACTION_HELL)
	/// Growl he makes for as long as he lives.
	var/datum/looping_sound/heinrich_growl/growl

/mob/living/basic/boss/heinrich_traizen/Initialize(mapload)
	. = ..()
	// Unlike the other directed monsters he can die; only stuns and sleep keep missing him.
	add_traits(list(TRAIT_STUNIMMUNE, TRAIT_SLEEPIMMUNE), INNATE_TRAIT)
	growl = new(src, TRUE)

/mob/living/basic/boss/heinrich_traizen/Destroy()
	QDEL_NULL(growl)
	return ..()

/// Anyone next to any of his three tiles can reach him, not only next to the centre one.
/mob/living/basic/boss/heinrich_traizen/CheckReachableAdjacency(atom/movable/reacher, reacher_range)
	if(..())
		return TRUE
	for(var/turf/part as anything in locs)
		if(reacher.Adjacent(part))
			return TRUE
	return FALSE

/mob/living/basic/boss/heinrich_traizen/death(gibbed)
	. = ..()
	growl.stop()
	if(gibbed)
		return
	// The corpse state is already set; the flick plays the cut, the spilling guts and the slump before it.
	flick("death", src)
	playsound(src, 'sound/effects/wounds/crackandbleed.ogg', 100, TRUE)
	playsound(src, 'sound/effects/splat.ogg', 100, TRUE)
	playsound(src, 'sound/mobs/humanoids/human/gag_vomit/crack_vomit.ogg', 100, TRUE)
	playsound(src, 'modular_bandastation/bosses/heinrich_traizen/sounds/death_growl.ogg', 100, FALSE, 6)
	burst()

/// The opened body sprays blood over the room and everyone near, and spills guts and vomit around him.
/mob/living/basic/boss/heinrich_traizen/proc/burst()
	var/turf/center = get_turf(src)
	if(!center)
		return
	var/list/blood_dna = list("Heinrich DNA" = random_human_blood_type())
	for(var/turf/part as anything in locs)
		new /obj/effect/gibspawner/human/bodypartless(part, null, null, blood_dna)
	for(var/turf/open/floor in range(2, center))
		if(prob(70))
			new /obj/effect/decal/cleanable/blood(floor, null, blood_dna)
		else if(prob(50))
			new /obj/effect/decal/cleanable/vomit(floor)
	for(var/turf/open/floor in range(4, center))
		if(get_dist(center, floor) > 2 && prob(30))
			new /obj/effect/decal/cleanable/blood/splatter(floor, null, blood_dna)
	// Sprays fly out in every direction; one more goes straight at each person nearby, so nobody stays clean.
	var/list/targets = list()
	for(var/i in 1 to 16)
		targets += locate(clamp(center.x + rand(-6, 6), 1, world.maxx), clamp(center.y + rand(-6, 6), 1, world.maxy), center.z)
	for(var/mob/living/carbon/human/witness in view(5, center))
		targets += get_turf(witness)
	for(var/turf/target as anything in targets)
		if(target == center)
			continue
		var/obj/effect/decal/cleanable/blood/hitsplatter/spray = new(center, null, blood_dna, 6)
		spray.fly_towards(target, get_dist(center, target) + 2)

/mob/living/basic/boss/heinrich_traizen/look_alive()
	. = ..()
	growl.start()

/datum/looping_sound/heinrich_growl
	mid_sounds = 'modular_bandastation/bosses/heinrich_traizen/sounds/growl_loop.ogg'
	mid_length = 77.1 SECONDS
	volume = 60
	// Follows him as he moves and repeats the long track without gaps.
	use_sound_tokens = TRUE
