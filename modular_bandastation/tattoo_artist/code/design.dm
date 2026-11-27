/// The same source state as get_limb_icon(), before clothing, hair and body markings.
/obj/item/bodypart/proc/tattoo_skin_state()
	return "[limb_id]_[body_zone][is_dimorphic ? "_[limb_gender]" : ""]"

/obj/item/bodypart/proc/tattoo_skin_key()
	if(!IS_ORGANIC_LIMB(src) || IS_STUMP(src) || is_husked || is_invisible || held_index >= 3)
		return null
	return "[(should_draw_greyscale && icon_greyscale) || icon_static]|[tattoo_skin_state()]|[aux_zone]"

/obj/item/bodypart/proc/tattoo_hand_icon(side)
	if(!aux_zone)
		return null
	var/source_icon = (should_draw_greyscale && icon_greyscale) || icon_static
	var/state = "[limb_id]_[aux_zone]"
	if(icon_exists(source_icon, state))
		if(side)
			return icon(source_icon, state, side, 1)
		return icon(source_icon, state)

/// Gloves and shoes cover only part of the selected limb. Use the owner's actual worn sprite.
/obj/item/bodypart/proc/tattoo_extremity_cover(side)
	var/mob/living/carbon/human/human = owner
	if(!istype(human))
		return null
	var/worn_layer
	if((body_part & ARMS) && human.gloves)
		worn_layer = GLOVES_LAYER
	else if((body_part & LEGS) && human.shoes)
		worn_layer = SHOES_LAYER
	if(!worn_layer || !human.overlays_standing[worn_layer])
		return null
	var/image/equipment = image('icons/blanks/32x32.dmi', icon_state = "nothing")
	equipment.overlays += human.overlays_standing[worn_layer]
	return getFlatIcon(equipment, defdir = side, no_anim = TRUE)

/// A single natural-size frame. GetPixel() is null outside the actual outline.
/obj/item/bodypart/proc/tattoo_skin_icon(side = SOUTH, ignore_clothing = FALSE)
	RETURN_TYPE(/icon)
	if(!(side in GLOB.cardinals) || !tattoo_skin_key() || (!ignore_clothing && !tattoo_is_exposed()))
		return null
	var/source_icon = (should_draw_greyscale && icon_greyscale) || icon_static
	var/state = tattoo_skin_state()
	if(!icon_exists(source_icon, state))
		return null
	var/icon/skin = icon(source_icon, state, side, 1)
	if(skin.Width() != 32 || skin.Height() != 32)
		return null
	var/icon/hand = tattoo_hand_icon(side)
	if(hand)
		skin.Blend(hand, ICON_OVERLAY)
	var/icon/cover = ignore_clothing ? null : tattoo_extremity_cover(side)
	var/has_skin = FALSE
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			if(!skin.GetPixel(x, y))
				continue
			if(!cover)
				return skin
			if(cover.GetPixel(x, y))
				skin.DrawBox(null, x, y)
			else
				has_skin = TRUE
	return has_skin ? skin : null

/// Fast check for the main body zone. Partial footwear and gloves use the per-view mask.
/obj/item/bodypart/proc/tattoo_is_exposed()
	if(!owner)
		return TRUE
	for(var/obj/item/clothing/garment in owner.get_equipped_items(INCLUDE_ABSTRACT))
		if(garment.body_parts_covered & body_part)
			return FALSE
	return TRUE

/obj/item/bodypart/proc/has_drawn_tattoo(side, datum/tattoo_design/exact_design)
	for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in bodypart_overlays)
		if(exact_design && tattoo.design != exact_design)
			continue
		if(isnull(side) || tattoo.design.side == side || (tattoo.design.all_views && (side in GLOB.cardinals)))
			return TRUE
	return FALSE

/// The examine panel may stay open after the viewer moves or the wearer changes clothing.
/mob/living/carbon/human/proc/get_visible_drawn_tattoos(mob/viewer)
	var/list/tattoos = list()
	if(!viewer || viewer.is_blind() || (viewer != src && !(src in view(1, viewer))))
		return tattoos
	var/datum/preferences/prefs = viewer == src ? get_tattoo_preferences() : null
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in limb.bodypart_overlays)
			if(!tattoo.can_examine(src, viewer))
				continue
			var/list/entry = list(
				"id" = REF(tattoo),
				"zone" = ru_parse_zone(limb.body_zone, declent = NOMINATIVE),
				"side" = tattoo.design.side_label(),
				"image" = tattoo.design.examine_image_url,
			)
			if(prefs)
				entry["saved"] = prefs.has_saved_tattoo(mind.original_character_slot_index, limb, tattoo.design)
			tattoos += list(entry)
	return tattoos

/// Resolve the selected row against the wearer's currently visible drawings.
/mob/living/carbon/human/proc/set_visible_tattoo_saved(mob/viewer, overlay_id, save)
	if(viewer != src || viewer.is_blind() || !istext(overlay_id) || !isnum(save) || (save != TRUE && save != FALSE))
		return FALSE
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		for(var/datum/bodypart_overlay/drawn_tattoo/tattoo in limb.bodypart_overlays)
			if(REF(tattoo) == overlay_id && tattoo.can_examine(src, viewer))
				return set_tattoo_persistent(limb, tattoo.design, save)
	return FALSE

/// A prepared design belongs to its exact limb. The overlay owns the design after success.
/obj/item/bodypart/proc/apply_drawn_tattoo(datum/tattoo_design/design, restoring = FALSE)
	if(!istype(design) || !design.world_icon || design.target_ref?.resolve() != src || design.skin_key != tattoo_skin_key())
		return FALSE
	if(has_drawn_tattoo(design.all_views ? null : design.side) || (!restoring && !design.ink_is_exposed(src)))
		return FALSE
	var/datum/bodypart_overlay/drawn_tattoo/overlay = new
	overlay.design = design
	add_bodypart_overlay(overlay, update = !restoring)
	design.view_previews = null
	return TRUE

/// Editor input is indexed ink on a 64x64 canvas, in row-major order from the top left.
/// Zero is transparent. Each group of four detail samples represents one world pixel.
/datum/tattoo_design
	var/side
	var/all_views = FALSE
	var/bitmap
	var/list/palette
	var/icon/detail_icon
	var/icon/world_icon
	var/skin_key
	var/datum/weakref/target_ref
	var/render_key
	/// Enlarged, cropped artwork on skin, shared by the examine tab and detailed chat output.
	var/examine_image_url
	/// 1-based linear world pixel positions occupied by ink.
	var/list/ink_locations
	/// Projected world pixel positions keyed by direction, for partial gloves and shoes.
	var/list/ink_by_direction
	/// Cropped views sent to the artist and client while they review this design.
	var/list/view_previews

/datum/tattoo_design/proc/ink_is_exposed(obj/item/bodypart/limb)
	if(!limb.tattoo_is_exposed())
		return FALSE
	for(var/direction in (all_views ? GLOB.cardinals : list(side)))
		var/icon/cover = limb.tattoo_extremity_cover(direction)
		if(!cover)
			continue
		var/list/locations = all_views ? ink_by_direction["[direction]"] : ink_locations
		for(var/location in locations)
			var/x = (location - 1) % 32 + 1
			var/y = FLOOR((location - 1) / 32, 1) + 1
			if(cover.GetPixel(x, y))
				return FALSE
	return TRUE

/datum/tattoo_design/proc/prepare(obj/item/bodypart/limb, new_side, new_bitmap, list/new_palette, ignore_clothing = FALSE, all_views = FALSE)
	if(world_icon || !istype(limb) || !(new_side in GLOB.cardinals))
		return FALSE
	if(!istext(new_bitmap) || length(new_bitmap) != 4096 || !islist(new_palette) || !ISINRANGE(length(new_palette), 1, 15))
		return FALSE
	for(var/color in new_palette)
		if(!istext(color) || length(color) != 7 || !findtext(color, GLOB.is_color) || !isnull(new_palette[color]))
			return FALSE
	var/icon/skin = limb.tattoo_skin_icon(new_side, ignore_clothing)
	if(!skin)
		return FALSE
	var/list/projection_skins
	if(all_views)
		projection_skins = list()
		for(var/direction in GLOB.cardinals)
			var/icon/projection_skin = limb.tattoo_skin_icon(direction, ignore_clothing = TRUE)
			if(!projection_skin)
				return FALSE
			projection_skins["[direction]"] = projection_skin
	var/icon/blank = icon('icons/blanks/32x32.dmi', "nothing", SOUTH)
	var/icon/world_frame = icon(blank)
	var/icon/detail = icon(blank)
	detail.Scale(64, 64)
	var/left = 65
	var/right = 0
	var/bottom = 65
	var/top = 0
	var/digits = "0123456789ABCDEF"
	var/list/painted_pixels = list()
	// Work by world pixel so a fine line that touches only one subpixel still shows on the mob.
	for(var/world_y in 1 to 32)
		for(var/world_x in 1 to 32)
			var/list/samples
			for(var/row_offset in 0 to 1)
				var/detail_y = world_y * 2 - row_offset
				for(var/col_offset in 0 to 1)
					var/detail_x = world_x * 2 - 1 + col_offset
					var/index = (64 - detail_y) * 64 + detail_x
					var/digit = copytext(new_bitmap, index, index + 1)
					if(digit == "0")
						continue
					var/color_index = findtext(digits, digit) - 1
					if(!ISINRANGE(color_index, 1, length(new_palette)) || !skin.GetPixel(world_x, world_y))
						return FALSE
					LAZYADD(samples, color_index)
					detail.DrawBox(new_palette[color_index], detail_x, detail_y)
					left = min(left, detail_x)
					right = max(right, detail_x)
					bottom = min(bottom, detail_y)
					top = max(top, detail_y)
			if(!length(samples))
				continue
			// Pick the most frequent ink, with the top-left sample winning tied counts.
			var/winner
			var/highest_count = 0
			for(var/candidate in samples)
				var/matches = 0
				for(var/sample in samples)
					if(sample == candidate)
						matches++
				if(matches > highest_count)
					winner = candidate
					highest_count = matches
			world_frame.DrawBox(new_palette[winner], world_x, world_y)
			painted_pixels += (world_y - 1) * 32 + world_x
	if(!right)
		return FALSE

	world_icon = icon(blank)
	src.all_views = all_views
	detail_icon = detail
	side = new_side
	bitmap = new_bitmap
	palette = new_palette.Copy()
	ink_locations = painted_pixels
	target_ref = WEAKREF(limb)
	skin_key = limb.tattoo_skin_key()
	render_key = md5("[skin_key]:[side]:[all_views]:[bitmap]:[jointext(palette, ",")]")
	examine_image_url = tattoo_view_image(skin, detail, limb.draw_color, left, bottom, right, top)
	if(all_views)
		build_tattoo_views(projection_skins, limb.draw_color, world_frame, blank, make_previews = !ignore_clothing)
	else
		for(var/direction in GLOB.cardinals)
			world_icon.Insert(direction == new_side ? world_frame : blank, icon_state = "", dir = direction)
	return TRUE

/datum/tattoo_design/proc/side_label()
	if(all_views)
		return "все ракурсы"
	switch(side)
		if(SOUTH)
			return "вид спереди"
		if(NORTH)
			return "вид сзади"
		if(EAST)
			return "лицом вправо"
		if(WEST)
			return "лицом влево"

/datum/bodypart_overlay/drawn_tattoo
	layers = list("" = BODY_ADJ_LAYER)
	offset_location = ENTIRE_BODY
	blocks_emissive = EMISSIVE_BLOCK_NONE
	overlay_flags = NONE
	var/datum/tattoo_design/design
	var/obj/item/bodypart/marked_limb
	var/mob/living/carbon/observed_owner
	var/icon/hand_art
	var/icon/leg_art
	var/icon/lower_leg_art

/datum/bodypart_overlay/drawn_tattoo/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	var/icon/art = leg_art || design.world_icon
	switch(layer_index)
		if("hand")
			art = hand_art
		if("lower_leg")
			art = lower_leg_art
	return mutable_appearance(art, "", layer = layer_real)

/datum/bodypart_overlay/drawn_tattoo/icon_render_key(obj/item/bodypart/limb)
	return list("tattoo_[design.render_key]")

/datum/bodypart_overlay/drawn_tattoo/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	return ..() && design && design.skin_key == bodypart_owner.tattoo_skin_key()

/datum/bodypart_overlay/drawn_tattoo/added_to_limb(obj/item/bodypart/limb)
	marked_limb = limb
	var/icon/hand_mask = limb.tattoo_hand_icon()
	if(hand_mask)
		// The auxiliary hand is above the uniform. Its ink goes between hand and glove.
		hand_mask.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1, 1,1,1,0)
		hand_art = icon(design.world_icon)
		hand_art.Blend(hand_mask, ICON_MULTIPLY)
		set_layer("hand", limb.aux_layer - 0.01)
	if(limb.body_part & LEGS)
		// In profile one entire leg is behind the body, as in the native leg renderer.
		var/state = limb.body_zone == BODY_ZONE_R_LEG ? "right_leg" : "left_leg"
		leg_art = icon(design.world_icon)
		leg_art.Blend(icon('icons/mob/leg_masks.dmi', state), ICON_MULTIPLY)
		lower_leg_art = icon(design.world_icon)
		lower_leg_art.Blend(icon('icons/mob/leg_masks.dmi', "[state]_lower"), ICON_MULTIPLY)
		set_layer("lower_leg", (BODYPARTS_LAYER + BODYPARTS_LOW_LAYER) / 2)
	RegisterSignal(limb, COMSIG_BODYPART_ATTACHED, PROC_REF(on_attached))
	RegisterSignal(limb, COMSIG_BODYPART_REMOVED, PROC_REF(on_removed))
	RegisterSignal(limb, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(limb, COMSIG_ATOM_EXAMINE_MORE, PROC_REF(on_examine_more))
	set_observed_owner(limb.owner)

/datum/bodypart_overlay/drawn_tattoo/removed_from_limb(obj/item/bodypart/limb)
	qdel(src)

/datum/bodypart_overlay/drawn_tattoo/Destroy()
	if(marked_limb)
		UnregisterSignal(marked_limb, list(COMSIG_BODYPART_ATTACHED, COMSIG_BODYPART_REMOVED, COMSIG_ATOM_EXAMINE, COMSIG_ATOM_EXAMINE_MORE))
	marked_limb = null
	set_observed_owner(null)
	QDEL_NULL(design)
	return ..()

/datum/bodypart_overlay/drawn_tattoo/proc/set_observed_owner(mob/living/carbon/new_owner)
	if(observed_owner)
		UnregisterSignal(observed_owner, list(COMSIG_ATOM_EXAMINE, COMSIG_ATOM_EXAMINE_MORE))
	observed_owner = new_owner
	if(observed_owner)
		if(ishuman(observed_owner))
			observed_owner.LoadComponent(/datum/component/examine_panel)
		RegisterSignal(observed_owner, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
		RegisterSignal(observed_owner, COMSIG_ATOM_EXAMINE_MORE, PROC_REF(on_examine_more))

/datum/bodypart_overlay/drawn_tattoo/proc/on_attached(obj/item/bodypart/source, mob/living/carbon/new_owner)
	SIGNAL_HANDLER
	set_observed_owner(new_owner)

/datum/bodypart_overlay/drawn_tattoo/proc/on_removed(obj/item/bodypart/source)
	SIGNAL_HANDLER
	set_observed_owner(null)

/datum/bodypart_overlay/drawn_tattoo/proc/can_examine(atom/source, mob/viewer)
	return viewer && (viewer == source || viewer.Adjacent(source)) && marked_limb && can_draw_on_bodypart(marked_limb, marked_limb.owner) && design.ink_is_exposed(marked_limb)

/datum/bodypart_overlay/drawn_tattoo/proc/on_examine(atom/source, mob/viewer, list/lines)
	SIGNAL_HANDLER
	if(can_examine(source, viewer))
		if(ishuman(source))
			lines |= span_notice("На коже видна татуировка. Нажмите «Раскрыть описание» и выберите вкладку «Татуировки».")
		else
			lines |= span_notice("На коже видна татуировка. Осмотрите ещё раз, чтобы рассмотреть рисунок.")
		var/datum/component/tattoo_care/care = marked_limb.GetComponent(/datum/component/tattoo_care)
		if(care?.covered_with_film)
			lines |= span_notice("Свежая татуировка ([marked_limb.plaintext_zone]) закрыта прозрачной защитной плёнкой.")

/datum/bodypart_overlay/drawn_tattoo/proc/on_examine_more(atom/source, mob/viewer, list/lines)
	SIGNAL_HANDLER
	if(!can_examine(source, viewer))
		return
	lines += span_notice("Татуировка ([marked_limb.plaintext_zone], [design.side_label()])") + "<br><img src='[design.examine_image_url]' alt='Татуировка крупным планом'>"
