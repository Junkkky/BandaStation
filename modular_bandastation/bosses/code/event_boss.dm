/// Owns a director monster's actions and removes them safely before its body disappears.
/datum/component/event_boss
	/// Actions created by this component, including actions removed by administrators.
	var/list/datum/action/abilities = list()

/datum/component/event_boss/Initialize(list/action_types)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/body = parent
	body.add_traits(list(TRAIT_GODMODE, TRAIT_NODEATH, TRAIT_NOBREATH, TRAIT_STUNIMMUNE, TRAIT_SLEEPIMMUNE, TRAIT_NODISMEMBER, TRAIT_NEVER_WOUNDED), REF(src))
	for(var/action_type in action_types)
		var/datum/action/action = new action_type(body)
		// The director paces these monsters by hand; shared ability types keep their cooldowns elsewhere.
		if(istype(action, /datum/action/cooldown))
			var/datum/action/cooldown/cooldown_action = action
			cooldown_action.cooldown_time = 0
		abilities += action
		action.Grant(body)

/datum/component/event_boss/Destroy()
	QDEL_LIST(abilities)
	var/mob/living/body = parent
	body.remove_traits(list(TRAIT_GODMODE, TRAIT_NODEATH, TRAIT_NOBREATH, TRAIT_STUNIMMUNE, TRAIT_SLEEPIMMUNE, TRAIT_NODISMEMBER, TRAIT_NEVER_WOUNDED), REF(src))
	return ..()

/// Click-targeted director actions share native targeting and enforce a visible same-level target.
/datum/action/cooldown/event_target
	click_to_activate = TRUE
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "repulse"

/datum/action/cooldown/event_target/PreActivate(atom/target)
	if(!owner || QDELETED(target) || !get_turf(target) || target.z != owner.z || !(target in view(owner)))
		return FALSE
	return ..()
