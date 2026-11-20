/// One held target, its chains, and the exact traits owned by this Pinhead.
/datum/status_effect/pinhead_chains
	id = "pinhead_chains"
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Captor owns the list and cannot operate on another Pinhead's prisoners.
	var/mob/living/basic/boss/gatekeeper/captor
	/// Visual chains owned by this status.
	var/list/datum/beam/chains = list()
	/// Hidden endpoints from the floor and air.
	var/list/obj/effect/chain_anchor/anchors = list()
	/// Original height, restored on release.
	var/old_height
	/// Stamina added by capture, removed without clearing unrelated stamina damage.
	var/stamina_added = 0

/datum/status_effect/pinhead_chains/on_creation(mob/living/new_owner, mob/living/basic/boss/gatekeeper/new_captor)
	captor = new_captor
	old_height = new_owner.pixel_z
	return ..()

/datum/status_effect/pinhead_chains/on_apply()
	if(QDELETED(captor) || owner == captor || owner.stat == DEAD || !isturf(owner.loc))
		return FALSE
	captor.prisoners += src
	old_height = owner.pixel_z
	owner.pixel_z += 18
	owner.pulledby?.stop_pulling()
	// Swapping, pushing or dragging would move the prisoner and drop the chains.
	owner.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_INCAPACITATED, TRAIT_FORCED_STANDING, TRAIT_NOMOBSWAP, TRAIT_PUSHIMMUNE), REF(src))
	stamina_added = max(0, 100 - owner.get_stamina_loss())
	owner.adjust_stamina_loss(stamina_added)
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(owner, COMSIG_LIVING_TRYING_TO_PULL, PROC_REF(block_pull))
	for(var/side in list(-1, 1))
		for(var/is_hand in list(FALSE, TRUE))
			var/obj/effect/chain_anchor/anchor = new(get_turf(owner))
			anchors += anchor
			// Beam adds pixel_z itself; these offsets locate wrists and ankles within the sprite.
			var/datum/beam/chain = new(anchor, owner, icon_state = "zipline_hook", beam_color = COLOR_GRAY, emissive = FALSE, override_origin_pixel_x = side * 64, override_origin_pixel_y = is_hand ? 96 : -32, override_target_pixel_x = owner.pixel_x + side * (is_hand ? 8 : 5), override_target_pixel_y = owner.pixel_y + (is_hand ? -2 : -14))
			chains += chain
			INVOKE_ASYNC(chain, TYPE_PROC_REF(/datum/beam, Start))
	playsound(owner, 'modular_bandastation/bosses/gatekeeper/sounds/pinhead_chains.ogg', 50, FALSE)
	owner.apply_damage(5, BRUTE, wound_bonus = CANT_WOUND)
	owner.create_splatter()
	return TRUE

/datum/status_effect/pinhead_chains/proc/on_moved()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/pinhead_chains/proc/block_pull(datum/source, mob/living/puller, force)
	SIGNAL_HANDLER
	return COMSIG_LIVING_CANCEL_PULL

/datum/status_effect/pinhead_chains/tick(seconds_between_ticks)
	if(QDELETED(captor) || owner.stat == DEAD)
		qdel(src)
	else
		var/added = max(0, 100 - owner.get_stamina_loss())
		owner.adjust_stamina_loss(added)

/datum/status_effect/pinhead_chains/on_remove()
	if(!QDELETED(captor))
		captor.prisoners -= src
	if(owner)
		playsound(owner, 'modular_bandastation/bosses/gatekeeper/sounds/pinhead_chains.ogg', 30, TRUE, frequency = 0.8)
		UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_TRYING_TO_PULL))
		owner.pixel_z = old_height
		owner.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_INCAPACITATED, TRAIT_FORCED_STANDING, TRAIT_NOMOBSWAP, TRAIT_PUSHIMMUNE), REF(src))
		owner.adjust_stamina_loss(-min(stamina_added, owner.get_stamina_loss()))
	QDEL_LIST(chains)
	QDEL_LIST(anchors)
	captor = null

/// Invisible point anchoring a chain in the floor or air.
/obj/effect/chain_anchor
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// Large targeted capture; the single-target subtype shares the exact same status.
/datum/action/cooldown/event_target/chains
	name = "Цепи: область"
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "voidpull"
	/// Radius around the clicked point; walls restrict the native view.
	var/radius = 10

/datum/action/cooldown/event_target/chains/Activate(atom/target)
	var/mob/living/basic/boss/gatekeeper/captor = owner
	for(var/mob/living/carbon/human/victim in view(radius, get_turf(target)))
		if(victim != owner && victim.stat != DEAD && !victim.has_status_effect(/datum/status_effect/pinhead_chains))
			victim.apply_status_effect(/datum/status_effect/pinhead_chains, captor)
	return TRUE

/datum/action/cooldown/event_target/chains/Remove(mob/remove_from)
	var/mob/living/basic/boss/gatekeeper/captor = remove_from
	captor.release_prisoners()
	return ..()

/// Capture one selected person instead of everyone in the area.
/datum/action/cooldown/event_target/chains/single
	name = "Цепи: выбранная цель"
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "cuff"

/datum/action/cooldown/event_target/chains/single/Activate(atom/target)
	if(!ishuman(target) || target == owner)
		return FALSE
	var/mob/living/victim = target
	if(victim.has_status_effect(/datum/status_effect/pinhead_chains))
		return FALSE
	return !!victim.apply_status_effect(/datum/status_effect/pinhead_chains, owner)

/// Targeted operations only accept this caster's chain status unless explicitly unrestricted.
/datum/action/cooldown/event_target/chain_operation
	/// Whether chains are required for this operation.
	var/needs_chains = TRUE

/datum/action/cooldown/event_target/chain_operation/Activate(atom/target)
	if(!ishuman(target) || target == owner)
		return FALSE
	var/mob/living/carbon/human/victim = target
	var/datum/status_effect/pinhead_chains/held = victim.has_status_effect(/datum/status_effect/pinhead_chains)
	if(needs_chains && held?.captor != owner)
		return FALSE
	return operate(victim, held)

/// Applies an operation after validating ownership of the prisoner.
/datum/action/cooldown/event_target/chain_operation/proc/operate(mob/living/carbon/human/victim, datum/status_effect/pinhead_chains/held)
	return FALSE

/// Releases a single prisoner.
/datum/action/cooldown/event_target/chain_operation/release
	name = "Отпустить выбранного"
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "uncuff"

/datum/action/cooldown/event_target/chain_operation/release/operate(mob/living/carbon/human/victim, datum/status_effect/pinhead_chains/held)
	qdel(held)
	return TRUE

/// Tears the selected arm or leg off a held prisoner.
/datum/action/cooldown/event_target/chain_operation/dismember
	name = "Оторвать конечность"
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "cleave"

/datum/action/cooldown/event_target/chain_operation/dismember/operate(mob/living/carbon/human/victim, datum/status_effect/pinhead_chains/held)
	var/zone = check_zone(owner.zone_selected)
	if(!(zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
		to_chat(owner, span_warning("Выберите руку или ногу."))
		return FALSE
	var/obj/item/bodypart/limb = victim.get_bodypart(zone)
	if(!limb)
		return FALSE
	log_combat(owner, victim, "tore off [zone] using [name]")
	if(needs_chains)
		playsound(victim, 'modular_bandastation/bosses/gatekeeper/sounds/chain_gib.ogg', 80, TRUE)
	return limb.dismember()

/// Execution with chains.
/datum/action/cooldown/event_target/chain_operation/gib
	name = "Разорвать цепями"
	button_icon_state = "gib"

/datum/action/cooldown/event_target/chain_operation/gib/operate(mob/living/carbon/human/victim, datum/status_effect/pinhead_chains/held)
	log_combat(owner, victim, "gibbed with event power")
	playsound(get_turf(victim), 'modular_bandastation/bosses/gatekeeper/sounds/chain_gib.ogg', 100, TRUE)
	victim.gib(DROP_ALL_REMAINS)
	return TRUE

/// Direct execution, independent of chain capture.
/datum/action/cooldown/event_target/chain_operation/gib/direct
	name = "Гиб выбранной цели"
	button_icon_state = "exsanguinating_strike"
	needs_chains = FALSE

/// Releases all prisoners owned by this Pinhead.
/datum/action/cooldown/release_chains
	name = "Отпустить всех"
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "repulse"

/datum/action/cooldown/release_chains/Activate(atom/target)
	var/mob/living/basic/boss/gatekeeper/captor = owner
	captor.release_prisoners()
	return TRUE
