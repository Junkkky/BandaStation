/// Resolves the spider clown behind either of its bodies.
/proc/get_spider_clown(mob/living/body)
	if(istype(body, /mob/living/basic/boss/spider_clown))
		return body
	var/mob/living/carbon/human/spider_clown_body/human = body
	if(istype(human))
		return human.spider

/// Gore and a spider's shriek accompany every change of the spider clown's form.
/proc/spider_clown_transform_effects(turf/where, gibs = TRUE)
	if(gibs)
		new /obj/effect/gibspawner/generic(where)
	playsound(where, 'sound/effects/splat.ogg', 100, TRUE)
	playsound(where, 'sound/effects/screech.ogg', 70, TRUE, 4, frequency = 1.3)
	playsound(where, 'sound/mobs/non-humanoids/insect/chitter.ogg', 80, TRUE, 4)

/// Mortal human body of the spider clown's clown and mimic forms; the spider waits inside it.
/mob/living/carbon/human/spider_clown_body
	// The spider's red night vision; mob-level, so it is blended with whatever eyes a changeling copy brings.
	lighting_cutoff_red = 25
	lighting_cutoff_green = 10
	lighting_cutoff_blue = 10
	/// Spider owning this body; cleared when either side is deleted.
	var/mob/living/basic/boss/spider_clown/spider
	/// Actions granted to this body, deleted with it.
	var/list/datum/action/abilities = list()
	/// Body, name and voice restored by the clown choice; its clothing slots are left to the real clothes.
	var/datum/changeling_profile/clown_profile
	/// Whether the body shows a copied crew member.
	var/mimicking = FALSE
	/// Real clothes taken off while mimicking, keyed by slot flag as text.
	var/list/obj/item/stashed_clothes = list()

/mob/living/carbon/human/spider_clown_body/Initialize(mapload)
	. = ..()
	randomize_human(src)
	// randomize_human replaces the voice component; DNA must carry the same voice into profiles.
	dna.tts_seed_dna = get_tts_seed()
	equipOutfit(/datum/outfit/job/clown)
	// The clown outfit picks a random clown name; renaming afterwards also rewrites the ID and PDA.
	fully_replace_character_name(real_name, "Скрамерс")
	ADD_TRAIT(src, TRAIT_NOHUNGER, INNATE_TRAIT)
	// The spider's thermal sight belongs to the mob, so it survives changeling copies of other species.
	ADD_TRAIT(src, TRAIT_THERMAL_VISION, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_WEB_SURFER, INNATE_TRAIT)
	// No event_boss component: this body must stay killable. The form buttons also work from its corpse.
	for(var/action_type in list(
		/datum/action/cooldown/spell/spatial_phase,
		/datum/action/cooldown/spider_invisibility,
		/datum/action/cooldown/spider_disguise,
		/datum/action/cooldown/spider_tiny,
		/datum/action/cooldown/spider_mimic,
		/datum/action/cooldown/spider_voice,
		/datum/action/cooldown/spider_voice_filter,
		/datum/action/cooldown/event_target/chain_operation/dismember/event_spider/clown,
	))
		var/datum/action/cooldown/action = new action_type(src)
		action.cooldown_time = 0
		abilities += action
		action.Grant(src)
	RegisterSignal(src, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_item_attack))
	clown_profile = make_profile(src)
	// The clown's real clothes stay real; restoring the clown must never create flesh copies of them.
	clown_profile.exists_list = list()

/mob/living/carbon/human/spider_clown_body/Destroy()
	if(spider)
		var/mob/living/basic/boss/spider_clown/owner_spider = spider
		spider = null
		owner_spider.reclaim_from_human()
	QDEL_LIST(abilities)
	QDEL_NULL(clown_profile)
	QDEL_LIST_ASSOC_VAL(stashed_clothes)
	return ..()

/// Clicking oneself with a severed arm or leg eats it, the way food is eaten.
/mob/living/carbon/human/spider_clown_body/proc/on_item_attack(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(target != src)
		return
	var/obj/item/bodypart/limb = get_active_held_item()
	if(!(istype(limb, /obj/item/bodypart/arm) || istype(limb, /obj/item/bodypart/leg)) || limb.owner)
		return
	INVOKE_ASYNC(src, PROC_REF(eat_limb), limb)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Eats a held severed limb, taking as long as eating food oneself.
/mob/living/carbon/human/spider_clown_body/proc/eat_limb(obj/item/bodypart/limb)
	if(DOING_INTERACTION(src, limb))
		return
	if(!do_after(src, 1 SECONDS, limb, interaction_key = limb) || QDELETED(limb) || limb.owner || !is_holding(limb))
		return
	visible_message(span_danger("[src] с хрустом пожирает [limb]!"), span_notice("Вы пожираете [limb]."))
	playsound(src, 'sound/effects/wounds/crackandbleed.ogg', 80, TRUE)
	new /obj/effect/decal/cleanable/blood/splatter(get_turf(src))
	qdel(limb)

/// The clown seizes people aggressively from the first touch and can tighten the grip as usual.
/mob/living/carbon/human/spider_clown_body/start_pulling(atom/movable/AM, state, force = pull_force, supress_message = FALSE)
	. = ..()
	if(pulling == AM && isliving(AM) && !grab_state)
		var/mob/living/victim = AM
		victim.grippedby(src, instant = TRUE)

/mob/living/carbon/human/spider_clown_body/get_mob_emote_panel_entries()
	return spider?.get_mob_emote_panel_entries()

/// Worn slots in the order they can be removed without dropping items that depend on them.
/mob/living/carbon/human/spider_clown_body/proc/clothing_slots()
	var/static/list/slots = list(
		ITEM_SLOT_SUITSTORE,
		ITEM_SLOT_BELT,
		ITEM_SLOT_ID,
		ITEM_SLOT_LPOCKET,
		ITEM_SLOT_RPOCKET,
		ITEM_SLOT_HEAD,
		ITEM_SLOT_MASK,
		ITEM_SLOT_NECK,
		ITEM_SLOT_BACK,
		ITEM_SLOT_EYES,
		ITEM_SLOT_EAR_LEFT,
		ITEM_SLOT_EAR_RIGHT,
		ITEM_SLOT_GLOVES,
		ITEM_SLOT_FEET,
		ITEM_SLOT_OCLOTHING,
		ITEM_SLOT_ICLOTHING,
	)
	return slots

// shortcut: native changeling procs need a changeling datum; it lives only inside these synchronous calls,
// so it never stays in GLOB.antagonists. Upgrade to standalone helpers if upstream extracts them.
/// Native changeling profile of a human, as a changeling would absorb it.
/mob/living/carbon/human/spider_clown_body/proc/make_profile(mob/living/carbon/human/target)
	var/datum/antagonist/changeling/mimicry = new
	. = mimicry.create_profile(target)
	qdel(mimicry)

/// Native changeling transformation into a profile, including flesh copies of its clothing.
/mob/living/carbon/human/spider_clown_body/proc/apply_profile(datum/changeling_profile/profile)
	var/datum/antagonist/changeling/mimicry = new
	mimicry.transform(src, profile)
	qdel(mimicry)

/// Copies a crew member like a changeling; the first copy puts the real clown clothes aside.
/mob/living/carbon/human/spider_clown_body/proc/mimic(mob/living/carbon/human/target)
	if(!mimicking)
		stash_clothes()
	var/datum/changeling_profile/profile = make_profile(target)
	apply_profile(profile)
	qdel(profile)
	mimicking = TRUE

/// Returns to the clown: flesh copies vanish and the stashed real clothes are worn again.
/mob/living/carbon/human/spider_clown_body/proc/restore_clown()
	if(mimicking)
		for(var/slot in clothing_slots())
			var/obj/item/worn = get_item_by_slot(slot)
			if(worn && HAS_TRAIT_FROM(worn, TRAIT_NODROP, CHANGELING_TRAIT))
				qdel(worn)
		unstash_clothes()
	apply_profile(clown_profile)
	mimicking = FALSE

/// Takes off the real clothes so the changeling transformation can dress the copy.
/mob/living/carbon/human/spider_clown_body/proc/stash_clothes()
	for(var/slot in clothing_slots())
		var/obj/item/worn = get_item_by_slot(slot)
		if(!worn || !temporarilyRemoveItemFromInventory(worn, force = TRUE))
			continue
		worn.moveToNullspace()
		stashed_clothes["[slot]"] = worn

/// Puts the real clothes back on, outer layers first; anything that no longer fits drops.
/mob/living/carbon/human/spider_clown_body/proc/unstash_clothes()
	var/list/slots = clothing_slots()
	for(var/index in length(slots) to 1 step -1)
		var/slot = slots[index]
		var/obj/item/worn = stashed_clothes["[slot]"]
		stashed_clothes -= "[slot]"
		if(QDELETED(worn))
			continue
		if(!equip_to_slot_if_possible(worn, slot, disable_warning = TRUE, bypass_equip_delay_self = TRUE))
			worn.forceMove(drop_location())
