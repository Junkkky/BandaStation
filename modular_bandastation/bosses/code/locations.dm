GLOBAL_LIST_EMPTY(event_boss_arrivals)
GLOBAL_LIST_EMPTY(event_boss_loading)
/// Point name -> turf for the gatekeeper's portals.
GLOBAL_LIST_EMPTY(event_portal_points)

/// Independently loaded hidden rooms; they remain alive when portals close.
/area/event_boss_room
	name = "GC: Логово боссов"
	area_flags = HIDDEN_AREA | NOTELEPORT
	default_gravity = STANDARD_GRAVITY
	// Same random background as the Gate Closure locations instead of the generic station ambience.
	ambientsounds = list(
		'modular_bandastation/gate_closure/sound/ambience/ominous_background.ogg',
		'modular_bandastation/gate_closure/sound/ambience/spacecraft_hum.ogg',
		'modular_bandastation/gate_closure/sound/ambience/space_atmosphere.ogg',
		'modular_bandastation/gate_closure/sound/ambience/spaceship_ambience.ogg',
	)

/// Private arrivals never enter the global heretic sacrifice landmark registry.
/obj/effect/landmark/event_boss_room
	/// Persistent room identifier.
	var/room_id = "lair"

/obj/effect/landmark/event_boss_room/Initialize(mapload)
	. = ..()
	GLOB.event_boss_arrivals[room_id] = get_turf(src)
	return INITIALIZE_HINT_QDEL

/// A hidden mapped point the gatekeeper's portal can lead to; the mapper names it.
/obj/effect/landmark/event_portal_point
	name = "Точка портала"
	icon_state = "x"

/obj/effect/landmark/event_portal_point/Initialize(mapload)
	. = ..()
	var/point_name = name
	for(var/copy = 2; GLOB.event_portal_points[point_name]; copy++)
		point_name = "[name] ([copy])"
	GLOB.event_portal_points[point_name] = get_turf(src)
	return INITIALIZE_HINT_QDEL

/// Loads the requested persistent room only when first needed.
/proc/event_boss_room(room_id)
	if(GLOB.event_boss_arrivals[room_id])
		return GLOB.event_boss_arrivals[room_id]
	if(room_id != "lair")
		return null
	if(room_id in GLOB.event_boss_loading)
		return null
	GLOB.event_boss_loading += room_id
	var/loaded = load_new_z_level("_maps/map_files/gate_closure/boss_[room_id].dmm", "Неизвестное место", TRUE)
	GLOB.event_boss_loading -= room_id
	if(!loaded)
		return null
	return GLOB.event_boss_arrivals[room_id]

/// Native hardlinked portal pair; closing either removes its partner.
/// Pressing the button asks where the portal leads, then the click picks where it opens.
/datum/action/cooldown/event_target/pinhead_portal
	button_icon = 'modular_bandastation/bosses/icons/action_buttons.dmi'
	button_icon_state = "common_portal"
	name = "Открыть / закрыть портал"
	/// Owned entrance; the native portal owns its linked return entrance.
	var/obj/effect/portal/entrance
	/// Point picked from the list, used by the next click; automatic use without a pick still leads to the lair.
	var/destination_name = "Логово боссов"

/datum/action/cooldown/event_target/pinhead_portal/proc/destination_names()
	return list("Логово боссов") + sort_list(assoc_to_keys(GLOB.event_portal_points))

/datum/action/cooldown/event_target/pinhead_portal/proc/choose_destination(mob/user)
	var/choice = tgui_input_list(user, "Куда ведёт портал?", name, destination_names())
	if(!choice || QDELETED(src) || QDELETED(owner) || user != owner || !QDELETED(entrance) || !IsAvailable())
		return
	destination_name = choice
	var/datum/action/cooldown/already_set = user.click_intercept
	if(istype(already_set) && already_set != src)
		already_set.unset_click_ability(user, refund_cooldown = TRUE)
	set_click_ability(user)
	to_chat(user, span_notice("Кликните, где откроется портал в «[choice]»."))

/datum/action/cooldown/event_target/pinhead_portal/Activate(atom/target)
	if(!QDELETED(entrance))
		QDEL_NULL(entrance)
		return TRUE
	var/turf/destination = destination_name == "Логово боссов" ? event_boss_room("lair") : GLOB.event_portal_points[destination_name]
	if(QDELETED(src) || QDELETED(owner) || QDELETED(target) || target.z != owner.z || !(target in view(owner)))
		return FALSE
	var/turf/start = get_turf(target)
	if(!destination || !isopenturf(start) || start.is_blocked_turf())
		return FALSE
	var/list/pair = create_portal_pair(start, destination, 0, newtype = /obj/effect/portal/event_boss)
	if(!length(pair))
		return FALSE
	entrance = pair[1]
	return TRUE

/datum/action/cooldown/event_target/pinhead_portal/Remove(mob/remove_from)
	QDEL_NULL(entrance)
	return ..()

/datum/action/cooldown/event_target/pinhead_portal/Trigger(mob/clicker, trigger_flags, atom/target)
	if(!QDELETED(entrance))
		if(!IsAvailable())
			return FALSE
		QDEL_NULL(entrance)
		return TRUE
	var/mob/user = clicker || owner
	// A second press while aiming cancels; automatic use with a target keeps the last picked point.
	if(target || user?.click_intercept == src)
		return ..()
	if(!IsAvailable(feedback = TRUE))
		return FALSE
	INVOKE_ASYNC(src, PROC_REF(choose_destination), user)
	return TRUE

/// Director portals can enter the explicitly hidden, teleport-restricted scene.
/obj/effect/portal/event_boss
	force_teleport = TRUE
	light_color = "#e52b87"
	light_range = 5
	light_power = 3

/obj/effect/portal/event_boss/Initialize(mapload, _lifespan = 0, obj/effect/portal/_linked, automatic_link = FALSE, turf/hard_target_override)
	. = ..()
	transform = matrix() * 2
	add_filter("event_portal_color", 1, color_transition_filter(light_color, SATURATION_OVERRIDE))
	portal_lightning(5)
	playsound(src, 'sound/effects/magic/lightningbolt.ogg', 50, FALSE)
	playsound(src, 'modular_bandastation/bosses/gatekeeper/sounds/portal_open.ogg', 70, FALSE)
	addtimer(CALLBACK(src, PROC_REF(idle_lightning)), 2 SECONDS, TIMER_DELETE_ME)

/// Short-lived turf-to-turf beams survive the closing portal without shocking anyone.
/obj/effect/portal/event_boss/proc/portal_lightning(count)
	var/turf/origin = get_turf(src)
	if(!origin)
		return
	var/list/targets = list()
	for(var/turf/open/target in view(2, origin))
		if(target != origin)
			targets += target
	for(var/index in 1 to min(count, length(targets)))
		var/turf/target = pick_n_take(targets)
		origin.Beam(target, icon_state = "purple_lightning", time = 0.4 SECONDS)

/// The timer belongs to this portal and is cancelled when it closes.
/obj/effect/portal/event_boss/proc/idle_lightning()
	if(QDELETED(src))
		return
	portal_lightning(2)
	addtimer(CALLBACK(src, PROC_REF(idle_lightning)), 2 SECONDS, TIMER_DELETE_ME)

/obj/effect/portal/event_boss/Destroy()
	portal_lightning(5)
	playsound(get_turf(src), 'sound/effects/magic/lightningbolt.ogg', 50, FALSE)
	return ..()
