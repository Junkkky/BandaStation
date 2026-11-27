/// Preselects saving when this character reviews a new tattoo.
/datum/preference/toggle/persistent_tattoos
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_key = "persistent_tattoos"
	savefile_identifier = PREFERENCE_CHARACTER
	can_randomize = FALSE
	should_update_preview = FALSE
	default_value = FALSE

/datum/preference/toggle/persistent_tattoos/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return // Read the owner's choice when a design is reviewed.

/// Round-local bindings survive reconnects and are dropped when a slot is deleted or reused.
/datum/preferences/var/list/tattoo_slot_owners

/datum/preferences/proc/get_tattoo_slot(slot)
	if(!load_and_save || !savefile?.path || !parent)
		return null
	if(!isnum(slot) || !ISINTEGER(slot) || !ISINRANGE(slot, 1, max_save_slots))
		return null
	var/list/profile = savefile.get_entry("character[slot]")
	return islist(profile) ? profile : null

/// Only the body spawned from this account and profile may change its collection.
/mob/living/carbon/human/proc/bind_tattoo_character(datum/preferences/preferences, slot)
	if(!preferences?.get_tattoo_slot(slot))
		return
	LAZYSET(preferences.tattoo_slot_owners, "[slot]", WEAKREF(src))
	restore_saved_tattoos(preferences, slot)

/mob/living/carbon/human/proc/get_tattoo_preferences()
	var/client/player = GET_CLIENT(src)
	var/datum/preferences/preferences = player?.prefs
	if(!preferences || player.mob != src || preferences.parent != player || mind?.current != src || mind.original_character?.resolve() != src)
		return null
	var/slot = mind.original_character_slot_index
	var/datum/weakref/owner = preferences.tattoo_slot_owners?["[slot]"]
	if(owner?.resolve() == src && preferences.get_tattoo_slot(slot))
		return preferences

/mob/living/carbon/human/proc/tattoo_save_by_default()
	var/datum/preferences/preferences = get_tattoo_preferences()
	if(!preferences)
		return FALSE
	var/slot = mind.original_character_slot_index
	if(slot == preferences.default_slot)
		return preferences.read_preference(/datum/preference/toggle/persistent_tattoos)
	var/datum/preference/setting = GLOB.preference_entries[/datum/preference/toggle/persistent_tattoos]
	return setting.read(preferences.get_tattoo_slot(slot), preferences) == TRUE

/mob/living/carbon/human/proc/set_tattoo_persistent(obj/item/bodypart/limb, datum/tattoo_design/design, save)
	var/datum/preferences/preferences = get_tattoo_preferences()
	if(!preferences || limb?.owner != src)
		return FALSE
	return preferences.set_saved_tattoo(mind.original_character_slot_index, limb, design, save)

/mob/living/carbon/human/proc/is_tattoo_persistent(obj/item/bodypart/limb, datum/tattoo_design/design)
	var/datum/preferences/preferences = get_tattoo_preferences()
	return preferences && limb?.owner == src && preferences.has_saved_tattoo(mind.original_character_slot_index, limb, design)

/datum/preferences/proc/has_saved_tattoo(slot, obj/item/bodypart/limb, datum/tattoo_design/design)
	if(!istype(limb) || !istype(design))
		return FALSE
	var/list/profile = get_tattoo_slot(slot)
	var/list/records = profile?["drawn_tattoos"]
	if(!islist(records))
		return FALSE
	var/list/record = records["[limb.body_zone]:[design.side]"]
	return islist(record) && record["skin"] == design.skin_key && record["bitmap"] == design.bitmap \
		&& (record["all_views"] == TRUE) == design.all_views && compare_list(record["palette"], design.palette)

/datum/preferences/proc/set_saved_tattoo(slot, obj/item/bodypart/limb, datum/tattoo_design/design, save)
	var/list/profile = get_tattoo_slot(slot)
	if(!profile || !istype(limb) || !istype(design) || !(limb.body_zone in GLOB.all_body_zones) || !(design.side in GLOB.cardinals))
		return FALSE
	// Write only a completed server-side drawing still on the limb it was prepared for.
	if(!design.world_icon || design.target_ref?.resolve() != limb || design.skin_key != limb.tattoo_skin_key() || !limb.has_drawn_tattoo(design.side, design))
		return FALSE
	if(!!save == has_saved_tattoo(slot, limb, design))
		return TRUE
	var/list/records = profile["drawn_tattoos"]
	var/location = "[limb.body_zone]:[design.side]"
	if(save)
		if(!islist(records))
			records = list()
			profile["drawn_tattoos"] = records
		records[location] = list(
			"skin" = design.skin_key,
			"bitmap" = design.bitmap,
			"palette" = design.palette.Copy(),
			"all_views" = design.all_views,
		)
	else
		records -= location
		if(!length(records))
			profile -= "drawn_tattoos"
	savefile.save()
	return TRUE

/// Rebuild healed artwork from bounded data using the new body's actual limb sprites.
/mob/living/carbon/human/proc/restore_saved_tattoos(datum/preferences/preferences, slot)
	var/list/profile = preferences?.get_tattoo_slot(slot)
	var/list/records = profile?["drawn_tattoos"]
	if(!islist(records) || !length(records))
		return 0
	var/restored = 0
	for(var/zone in GLOB.all_body_zones)
		var/obj/item/bodypart/limb = get_bodypart(zone)
		var/skin = limb?.tattoo_skin_key()
		if(!skin)
			continue
		// Whole-limb drawings take precedence if a previous limb replacement left legacy records.
		for(var/all_views in list(TRUE, FALSE))
			for(var/side in GLOB.cardinals)
				var/list/record = records["[zone]:[side]"]
				if(!islist(record) || record["skin"] != skin || (record["all_views"] == TRUE) != all_views || limb.has_drawn_tattoo(side))
					continue
				var/datum/tattoo_design/design = new
				if(design.prepare(limb, side, record["bitmap"], record["palette"], ignore_clothing = TRUE, all_views = all_views) && limb.apply_drawn_tattoo(design, restoring = TRUE))
					restored++
				else
					qdel(design)
	if(restored)
		update_body_parts()
	return restored
