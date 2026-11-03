/** Renders DS13 flesh mutations over the current anatomy without replacing any biological state. */
/datum/component/paradise_zombie_mutation_body
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Mutation selected by the progression controller.
	var/form_id
	/// Original DS13 bodypart sheet; its complete directional and animation metadata is retained.
	var/body_icon
	/// DS13 state prefix; the bile mutation uses the original Puker artwork.
	var/state_prefix
	/// Complete bodypart appearances currently added to the host.
	var/list/body_appearances = list()
	/// Horizontal anchor of the selected source artwork.
	var/form_pixel_x = -8
	/// The body's pre-mutation anchors, independent of its species and DNA.
	var/old_pixel_x
	/// The body's pre-mutation vertical anchor.
	var/old_pixel_y
	/// The body's pre-mutation resting horizontal anchor.
	var/old_base_pixel_x
	/// The body's pre-mutation resting vertical anchor.
	var/old_base_pixel_y
	/// Appearance flags added by this component, removed without touching pre-existing flags.
	var/added_appearance_flags = NONE
	/// Whether the component has applied its appearance and must restore it during teardown.
	var/appearance_applied = FALSE
	/// These human overlays are retained in the native cache but hidden while flesh has another shape.
	var/static/list/hidden_layers = list(BODYPARTS_LAYER, BODY_LAYER, HAIR_LAYER, EYES_LAYER, DAMAGE_LAYER, WOUND_LAYER, HANDS_LAYER)

/datum/component/paradise_zombie_mutation_body/Initialize(new_form_id)
	if(!ishuman(parent) || !set_form(new_form_id))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/carbon/human/host = parent
	old_pixel_x = host.pixel_x
	old_pixel_y = host.pixel_y
	old_base_pixel_x = host.base_pixel_x
	old_base_pixel_y = host.base_pixel_y

/datum/component/paradise_zombie_mutation_body/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CARBON_APPLY_OVERLAY, PROC_REF(on_overlay_applied))
	RegisterSignals(parent, list(COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB), PROC_REF(on_anatomy_changed))
	appearance_applied = TRUE
	var/mob/living/carbon/human/host = parent
	added_appearance_flags = (KEEP_TOGETHER | TILE_BOUND | PIXEL_SCALE | LONG_GLIDE) & ~host.appearance_flags
	host.appearance_flags |= added_appearance_flags
	apply_anchor()
	for(var/hidden_layer in hidden_layers)
		host.cut_overlay(host.overlays_standing[hidden_layer])
	redraw_body()

/datum/component/paradise_zombie_mutation_body/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB))
	if(!appearance_applied)
		return
	appearance_applied = FALSE
	var/mob/living/carbon/human/host = parent
	host.cut_overlay(body_appearances)
	body_appearances.Cut()
	if(QDELETED(host))
		return
	host.pixel_x = old_pixel_x
	host.pixel_y = old_pixel_y
	host.base_pixel_x = old_base_pixel_x
	host.base_pixel_y = old_base_pixel_y
	host.appearance_flags &= ~added_appearance_flags
	// A creating update would recolor transplanted tissue from the recipient's DNA.
	host.update_body()
	for(var/hidden_layer in hidden_layers)
		host.cut_overlay(host.overlays_standing[hidden_layer])
		host.apply_overlay(hidden_layer)

/** Switches an existing visual mutation while keeping the same real limbs, organs and DNA. */
/datum/component/paradise_zombie_mutation_body/proc/set_form(new_form_id)
	var/datum/paradise_zombie_form/chosen = get_paradise_zombie_form(new_form_id)
	if(!chosen)
		return FALSE
	form_id = chosen.id
	body_icon = chosen.body_icon
	state_prefix = form_id == "spitter" ? "puker" : form_id
	form_pixel_x = form_id == "brute" ? -16 : -8
	if(appearance_applied)
		apply_anchor()
		redraw_body()
	return TRUE

/** Uses the source's resting anchor without changing race, body height, physical size or limb data. */
/datum/component/paradise_zombie_mutation_body/proc/apply_anchor()
	var/mob/living/carbon/human/host = parent
	host.pixel_x = form_pixel_x
	host.base_pixel_x = form_pixel_x
	host.pixel_y = 0
	host.base_pixel_y = 0

/datum/component/paradise_zombie_mutation_body/proc/on_overlay_applied(mob/living/carbon/human/source, cache_index, list/applied_overlays)
	SIGNAL_HANDLER
	if(!(cache_index in hidden_layers))
		return
	source.cut_overlay(applied_overlays)
	if(cache_index == BODYPARTS_LAYER)
		redraw_body()

/datum/component/paradise_zombie_mutation_body/proc/on_anatomy_changed()
	SIGNAL_HANDLER
	redraw_body()

/** Draws actual attached limbs, so removal and transplantation remain native anatomy operations. */
/datum/component/paradise_zombie_mutation_body/proc/redraw_body()
	var/mob/living/carbon/human/host = parent
	host.cut_overlay(body_appearances)
	body_appearances.Cut()
	for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
		if(IS_STUMP(limb) || limb.is_invisible)
			continue
		// The source Exploder's fused legs are painted into its chest, not separate limb states.
		if(form_id == "exploder" && (limb.body_zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
			continue
		var/body_state = "[state_prefix]_[limb.body_zone]"
		if(!icon_exists(body_icon, body_state))
			continue
		body_appearances += mutable_appearance(body_icon, body_state, layer = -BODYPARTS_LAYER)
	host.add_overlay(body_appearances)
