/** A reusable floor rack that fabricates and holds one capsule. */
/obj/machinery/stationtrauma_drop_launcher
	name = "пусковая установка дроп-подов"
	desc = "Станина со сборочным механизмом. Загрузите листы железа прямо в установку. Команда сборки подаётся с консоли запуска."
	icon = 'modular_bandastation/space_combat/icons/patrol_machines.dmi'
	icon_state = "pod_rack"
	layer = ABOVE_NORMAL_TURF_LAYER
	anchored = TRUE
	density = FALSE
	interaction_flags_machine = NONE
	/// Designation on the console, independent of the capsule currently fitted.
	var/launcher_number = 1
	/// Sheets in the feed, capped at one capsule.
	var/iron = 0
	/// The hull that owns this physical station.
	var/datum/weakref/vessel_ref
	/// The capsule assembled at this station, which becomes independent on launch.
	var/datum/weakref/pod_ref

/obj/docking_port/mobile/stationtrauma_space
	/// Reusable drop-pod launchers connected to the hull.
	var/list/drop_launchers

/obj/machinery/stationtrauma_drop_launcher/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/stationtrauma_drop_launcher/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/vessel = vessel_ref?.resolve()
	if(vessel)
		LAZYREMOVE(vessel.drop_launchers, src)
	vessel_ref = null
	if(istype(port, /obj/docking_port/mobile/stationtrauma_space) && port.shuttle_areas[get_area(src)] && port.is_in_shuttle_bounds(src))
		vessel = port
		vessel_ref = WEAKREF(vessel)
		LAZYADD(vessel.drop_launchers, src)

/obj/machinery/stationtrauma_drop_launcher/Destroy()
	connect_to_shuttle(FALSE, null)
	pod_ref = null
	return ..()

/obj/machinery/stationtrauma_drop_launcher/examine(mob/user)
	. = ..()
	. += span_notice("Установка №[launcher_number]. Листы железа: [iron]/[ST_DROP_POD_IRON_COST].")

/obj/machinery/stationtrauma_drop_launcher/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/sheet/iron))
		return ..()
	if(!can_operate() || !Adjacent(user) || !can_interact(user))
		return ITEM_INTERACT_BLOCKING
	if(mounted_pod())
		balloon_alert(user, "на установке уже есть капсула")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/stack/sheet/iron/sheets = tool
	var/count = min(ST_DROP_POD_IRON_COST - iron, sheets.get_amount())
	if(count <= 0)
		balloon_alert(user, "достаточно железа для сборки")
		return ITEM_INTERACT_BLOCKING
	if(!sheets.use(count))
		return ITEM_INTERACT_BLOCKING
	iron += count
	balloon_alert(user, "железо: [iron]/[ST_DROP_POD_IRON_COST]")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_drop_launcher/proc/is_mounted(obj/docking_port/mobile/stationtrauma_space/vessel)
	return anchored && vessel_ref?.resolve() == vessel && vessel.shuttle_areas[get_area(src)] && vessel.is_in_shuttle_bounds(src)

/obj/machinery/stationtrauma_drop_launcher/proc/can_operate()
	return anchored && is_operational && !panel_open

/obj/machinery/stationtrauma_drop_launcher/proc/mounted_pod()
	var/obj/structure/closet/stationtrauma_drop_pod/pod = pod_ref?.resolve()
	if(!QDELETED(pod) && !pod.launched && pod.anchored && pod.loc == loc)
		return pod

/obj/machinery/stationtrauma_drop_launcher/proc/can_assemble()
	var/turf/pad = get_turf(src)
	return can_operate() && iron >= ST_DROP_POD_IRON_COST && !mounted_pod() && isfloorturf(pad) && !pad.is_blocked_turf() \
		&& !(locate(/obj/structure/closet) in pad)

/obj/machinery/stationtrauma_drop_launcher/proc/assemble_pod()
	if(!can_assemble())
		return FALSE
	iron -= ST_DROP_POD_IRON_COST
	var/obj/structure/closet/stationtrauma_drop_pod/pod = new(get_turf(src))
	pod.name = "дроп-под №[launcher_number]"
	pod_ref = WEAKREF(pod)
	// The compact cabin fills from the bay without taking half a tile of air.
	pod.internal_air.volume = ST_DROP_POD_CABIN_VOLUME
	pod.process_internal_air(0)
	playsound(src, 'sound/machines/closet/closet_close.ogg', 45, TRUE)
	return TRUE
