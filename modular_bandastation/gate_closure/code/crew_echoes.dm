/// Mapper-selected corpse positions, consumed after the starting crew has spawned.
/obj/effect/landmark/gate_closure_corpse
	name = "crew echo"
	icon_state = "x"

/// Equipment and appearances are ready by this signal; creation may yield outside the handler.
/datum/controller/subsystem/gate_closure/proc/on_crew_ready(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING)
	INVOKE_ASYNC(src, PROC_REF(spawn_crew_echoes))

/// Copies starting humanoid players once, without keeping references to their living bodies.
/datum/controller/subsystem/gate_closure/proc/spawn_crew_echoes()
	var/list/turf/positions = list()
	for(var/obj/effect/landmark/gate_closure_corpse/marker in GLOB.landmarks_list.Copy())
		var/turf/position = get_turf(marker)
		if(isopenturf(position) && !position.density)
			positions |= position
		qdel(marker)
	if(!length(positions))
		return

	for(var/mob/living/carbon/human/crew in GLOB.player_list.Copy())
		if(QDELETED(crew) || !crew.client || !is_station_level(crew.z))
			continue
		var/turf/position = pick_n_take(positions)
		if(!position)
			stack_trace("Gate closure ran out of corpse markers.")
			break
		create_echo(crew, position)
		CHECK_TICK

/// Copies appearance and visible clothing only; never transfers minds, access, pockets or implants.
/datum/controller/subsystem/gate_closure/proc/create_echo(mob/living/carbon/human/crew, turf/position)
	var/mob/living/carbon/human/echo = new(position)
	crew.dna.copy_dna(echo.dna, COPY_DNA_SPECIES)
	crew.copy_clothing_prefs(echo)
	echo.fully_replace_character_name(null, crew.real_name)
	echo.age = crew.age
	echo.updateappearance(mutcolor_update = TRUE)
	ADD_TRAIT(echo, TRAIT_NO_SOUL, INNATE_TRAIT)

	for(var/slot in list(ITEM_SLOT_ICLOTHING, ITEM_SLOT_OCLOTHING, ITEM_SLOT_HEAD, ITEM_SLOT_FEET, ITEM_SLOT_GLOVES, ITEM_SLOT_EYES, ITEM_SLOT_MASK, ITEM_SLOT_NECK))
		var/obj/item/clothing/original = crew.get_item_by_slot(slot)
		if(!istype(original))
			continue
		var/obj/item/clothing/garment = new original.type(echo)
		garment.color = original.color
		garment.worn_icon = original.worn_icon
		garment.worn_icon_state = original.worn_icon_state
		for(var/atom/movable/content as anything in garment.contents.Copy())
			qdel(content)
		echo.equip_to_slot_or_del(garment, slot)

	echo.death()
	if(prob(30))
		echo.adjust_fire_loss(100, forced = TRUE)
	else
		echo.adjust_brute_loss(100, forced = TRUE)
		if(prob(60))
			var/obj/item/bodypart/limb = echo.get_bodypart(pick(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG, BODY_ZONE_HEAD))
			limb?.dismember()
	echo.add_splatter_floor(position)
	return echo
