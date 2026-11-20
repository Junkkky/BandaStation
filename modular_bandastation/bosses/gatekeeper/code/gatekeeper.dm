/// Player-controlled Pinhead event character using the approved gatekeeper sprite.
/mob/living/basic/boss/gatekeeper
	name = "Пинхед"
	// Loud bold speech, a step smaller than the other bosses.
	speech_span = SPAN_SOAPBOX
	desc = "Высокая фигура в бледном церемониальном облачении."
	icon = 'modular_bandastation/bosses/gatekeeper/icons/gatekeeper.dmi'
	icon_state = "idle"
	icon_living = "idle"
	icon_dead = "dead"
	maxHealth = 1000
	health = 1000
	melee_damage_lower = 20
	melee_damage_upper = 20
	ai_controller = null
	faction = list(FACTION_MINING, FACTION_BOSS, FACTION_HELL)
	hud_type = /datum/hud/living/pinhead
	/// Chain statuses owned by this particular director.
	var/list/datum/status_effect/pinhead_chains/prisoners = list()

/mob/living/basic/boss/gatekeeper/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/event_boss, list(
		/datum/action/cooldown/spell/spatial_phase/pinhead,
		/datum/action/cooldown/event_target/chains,
		/datum/action/cooldown/event_target/chains/single,
		/datum/action/cooldown/event_target/chain_operation/release,
		/datum/action/cooldown/release_chains,
		/datum/action/cooldown/event_target/chain_operation/dismember,
		/datum/action/cooldown/event_target/chain_operation/gib,
		/datum/action/cooldown/event_target/chain_operation/gib/direct,
		/datum/action/cooldown/event_target/pinhead_portal,
	))
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_step))

/// Basic mobs without attack_sound hit silently; the native one would also be fixed at half volume.
/mob/living/basic/boss/gatekeeper/melee_attack(atom/target, list/modifiers, ignore_cooldown)
	. = ..()
	if(!. || !isliving(target))
		return
	var/static/list/impacts = list(
		'modular_bandastation/bosses/crooked_man/sounds/impact_1.ogg',
		'modular_bandastation/bosses/crooked_man/sounds/impact_2.ogg',
		'modular_bandastation/bosses/crooked_man/sounds/impact_3.ogg',
	)
	playsound(src, pick(impacts), 100, TRUE, 4)

/mob/living/basic/boss/gatekeeper/Destroy()
	release_prisoners()
	return ..()

/// Status removal edits prisoners, so iterate a snapshot when releasing a group.
/mob/living/basic/boss/gatekeeper/proc/release_prisoners()
	for(var/datum/status_effect/pinhead_chains/held as anything in prisoners.Copy())
		qdel(held)

/// Expose the normal body-zone selector for the director's limb-tearing action.
/datum/hud/living/pinhead/initialize_screen_objects()
	. = ..()
	// The basic-mob combat toggle otherwise covers the body-zone selector.
	var/atom/movable/screen/combattoggle/combat = screen_objects[HUD_MOB_INTENTS]
	combat.screen_loc = ui_acti
	combat.default_screen_location = ui_acti
	add_screen_object(/atom/movable/screen/zone_sel, HUD_MOB_ZONE_SELECTOR, HUD_GROUP_STATIC, ui_style)

/// Footstep element skips flying mobs, and every boss flies; Pinhead's steps must still be heard.
/mob/living/basic/boss/gatekeeper/proc/on_step(datum/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(forced || throwing || !isturf(loc))
		return
	playsound(src, pick('sound/effects/footstep/heavy1.ogg', 'sound/effects/footstep/heavy2.ogg'), 70, TRUE, 2)

/// Pinhead returns from the phase through a rift that hangs open for a few seconds.
/datum/action/cooldown/spell/spatial_phase/pinhead

/datum/action/cooldown/spell/spatial_phase/pinhead/play_phase_exit(mob/living/unjaunter)
	new /obj/effect/portal/event_boss/opening(get_turf(unjaunter), 4 SECONDS)
