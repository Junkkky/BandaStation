/** The editor shows the assembled console; three sections provide collision and reach. */
/obj/machinery/computer/stationtrauma_navigation
	var/list/obj/machinery/stationtrauma_navigation_section/sections = list()

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/computer/stationtrauma_navigation, 0)

/obj/machinery/computer/stationtrauma_navigation/Initialize(mapload)
	. = ..()
	sonar_loop = new(src)
	for(var/index in 1 to 3)
		var/obj/machinery/stationtrauma_navigation_section/section = new(loc)
		section.console = src
		section.name = name
		section.desc = desc
		section.number = index
		sections += section
	position_sections()
	update_appearance()

/obj/machinery/computer/stationtrauma_navigation/proc/link_vessel(obj/docking_port/mobile/stationtrauma/boat)
	if(vessel)
		UnregisterSignal(vessel, list(COMSIG_STATIONTRAUMA_NAVIGATION_CHANGED, COMSIG_QDELETING))
	vessel = boat
	if(vessel)
		RegisterSignal(vessel, COMSIG_STATIONTRAUMA_NAVIGATION_CHANGED, PROC_REF(refresh_hardware))
		RegisterSignal(vessel, COMSIG_QDELETING, PROC_REF(vessel_deleted))
	refresh_hardware()

/obj/machinery/computer/stationtrauma_navigation/proc/vessel_deleted()
	SIGNAL_HANDLER
	link_vessel(null)
	active_sonar = FALSE
	sonar_loop?.stop()
	refresh_hardware()

/obj/machinery/computer/stationtrauma_navigation/proc/refresh_hardware()
	SIGNAL_HANDLER
	if(machine_stat & (NOPOWER|BROKEN))
		active_sonar = FALSE
		sonar_loop?.stop()
		set_light(0)
	for(var/obj/machinery/stationtrauma_navigation_section/section as anything in sections)
		section.update_appearance()

/obj/machinery/computer/stationtrauma_navigation/update_icon_state()
	// The full-bank state is only for mapping; clickable sections draw the same pixels in game.
	icon_state = ""
	return ..()

/obj/machinery/computer/stationtrauma_navigation/update_overlays()
	. = ..()
	refresh_hardware()

/obj/machinery/computer/stationtrauma_navigation/can_interact(mob/user)
	if(QDELETED(user) || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	if((SEND_SIGNAL(user, COMSIG_TRY_USE_MACHINE, src) | SEND_SIGNAL(src, COMSIG_TRY_USE_MACHINE, user)) & COMPONENT_CANT_USE_MACHINE_INTERACT)
		return FALSE
	// Each section applies the native mob, reach and literacy checks at its own occupied tile.
	for(var/obj/machinery/stationtrauma_navigation_section/section as anything in sections)
		if(section.can_interact(user))
			return TRUE
	return FALSE

/obj/machinery/computer/stationtrauma_navigation/CheckReachableAdjacency(atom/movable/reacher, reacher_range)
	if(..())
		return TRUE
	for(var/obj/machinery/stationtrauma_navigation_section/section as anything in sections)
		if(section.CheckReachableAdjacency(reacher, reacher_range))
			return TRUE
	return FALSE

/obj/machinery/computer/stationtrauma_navigation/power_change()
	. = ..()
	if(machine_stat & (NOPOWER|BROKEN))
		active_sonar = FALSE
		sonar_loop?.stop()
		set_light(0)
	else
		set_light(brightness_on, 0.45, light_color)
	refresh_hardware()

/obj/machinery/computer/stationtrauma_navigation/get_light_offset()
	return (dir in list(NORTH, SOUTH)) ? list(1, 0) : list(0, 1)

/obj/machinery/computer/stationtrauma_navigation/setDir(newdir)
	. = ..()
	position_sections()

/obj/machinery/computer/stationtrauma_navigation/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	position_sections()

/obj/machinery/computer/stationtrauma_navigation/proc/position_sections()
	if(!isturf(loc))
		return
	var/horizontal = (dir in list(NORTH, SOUTH))
	for(var/obj/machinery/stationtrauma_navigation_section/section as anything in sections)
		var/offset = section.number - 1
		section.forceMove(locate(x + (horizontal ? offset : 0), y + (horizontal ? 0 : offset), z))
		section.setDir(dir)
		section.update_appearance()
	update_light()

/obj/machinery/computer/stationtrauma_navigation/Destroy()
	for(var/mob/viewer as anything in navigation_windows.Copy())
		close_navigation(viewer)
	link_vessel(null)
	QDEL_NULL(sonar_loop)
	QDEL_LIST(sections)
	return ..()

/** Sections retain native adjacency, dexterity and literacy checks; they never process or scan the map. */
/obj/machinery/stationtrauma_navigation_section
	name = "навигация «Нырка»"
	icon = 'modular_bandastation/underwater_submarine/icons/navigation_sections.dmi'
	icon_state = "passive-1"
	density = TRUE
	use_power = NO_POWER_USE
	processing_flags = NONE
	interaction_flags_machine = INTERACT_MACHINE_ALLOW_SILICON|INTERACT_MACHINE_REQUIRES_LITERACY
	var/obj/machinery/computer/stationtrauma_navigation/console
	var/number = 1

/obj/machinery/stationtrauma_navigation_section/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!QDELETED(console) && can_interact(user))
		console.ui_interact(user)

/obj/machinery/stationtrauma_navigation_section/update_icon_state()
	var/state = "off"
	if(console && !(console.machine_stat & (NOPOWER|BROKEN)))
		state = console.active_sonar ? "active" : "passive"
	icon_state = "[state]-[number]"
	return ..()

/obj/machinery/stationtrauma_navigation_section/update_overlays()
	. = ..()
	if(console && !(console.machine_stat & (NOPOWER|BROKEN)))
		. += emissive_appearance(icon, "mask-[number]", src)
		var/engine_section = (dir in list(NORTH, WEST)) ? 3 : 1
		if(number == engine_section && console.vessel?.engines_running)
			. += "engine"
			. += emissive_appearance(icon, "engine-mask", src)

/obj/machinery/stationtrauma_navigation_section/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = TRUE, attack_dir, armour_penetration = 0)
	if(!QDELETED(console))
		return console.take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	return ..()

/obj/machinery/stationtrauma_navigation_section/Destroy()
	if(console && !QDELETED(console))
		console.sections -= src
		qdel(console)
	console = null
	return ..()
