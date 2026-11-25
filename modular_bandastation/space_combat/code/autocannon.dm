/** A fixed, bridge-operated kinetic autocannon. */
/obj/machinery/stationtrauma_autocannon
	name = "кинетическая автопушка"
	desc = "Носовая установка на три выстрела в очереди. Управляется с оружейной консоли. Внутренний загрузочный лоток подаёт кинетические снаряды между очередями."
	icon = 'modular_bandastation/space_combat/icons/patrol_machines.dmi'
	icon_state = "autocannon"
	anchored = TRUE
	density = FALSE
	use_power = NO_POWER_USE
	interaction_flags_machine = NONE
	/// Stack family accepted by the breech and its matching interior loader.
	var/ammo_type = /obj/item/stack/stationtrauma_autocannon_shell
	/// Shells available for a burst.
	var/shells = 9
	/// Maximum number of shells in the feed.
	var/feed_capacity = 9
	/// Type carried all the way from the muzzle to an incoming hull impact.
	var/projectile_type = /obj/projectile/bullet/stationtrauma_kinetic
	var/burst_size = 3
	var/reload_time = ST_AUTOCANNON_RELOAD
	var/firing_sound = 'sound/items/weapons/gun/l6/shot.ogg'
	/// Charge delivered by an installed combat distributor.
	var/capacitor_charge = 0
	/// Hull registration is updated by the native shuttle loader.
	var/datum/weakref/vessel_ref
	/// A burst owns the feed until its last round or an interruption.
	var/firing_burst = FALSE
	COOLDOWN_DECLARE(burst_cooldown)

/obj/docking_port/mobile/stationtrauma_space
	/// Physical autocannons connected to the hull.
	var/list/ship_autocannons = list()

/obj/machinery/stationtrauma_autocannon/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/stationtrauma_autocannon/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/vessel = vessel_ref?.resolve()
	vessel?.ship_autocannons.Remove(src)
	vessel_ref = null
	if(istype(port, /obj/docking_port/mobile/stationtrauma_space))
		vessel = port
		if(vessel.is_in_shuttle_bounds(src) && vessel.shuttle_areas[get_area(src)])
			vessel_ref = WEAKREF(vessel)
			vessel.ship_autocannons |= src

/obj/machinery/stationtrauma_autocannon/Destroy()
	connect_to_shuttle(FALSE, null)
	return ..()

/** Ammunition for the kinetic autocannon's feed. */
/obj/item/stack/stationtrauma_autocannon_shell
	name = "кинетические снаряды"
	singular_name = "кинетический снаряд"
	desc = "Боеприпасы лёгкой корабельной автопушки. Полная кассета вмещает 30 снарядов."
	merge_type = /obj/item/stack/stationtrauma_autocannon_shell
	icon = 'modular_bandastation/space_combat/icons/patrol_ammunition.dmi'
	icon_state = "shells"
	novariants = FALSE
	inhand_icon_state = "syringe_kit"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	max_amount = 30
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/stack/stationtrauma_autocannon_shell/full
	amount = /obj/item/stack/stationtrauma_autocannon_shell::max_amount

/obj/item/stack/stationtrauma_autocannon_shell/heavy
	name = "тяжёлые кинетические снаряды"
	singular_name = "тяжёлый кинетический снаряд"
	desc = "Боеприпасы тяжёлой корабельной автопушки. В кассете с янтарной полосой помещается восемь снарядов."
	icon = 'modular_bandastation/space_combat/icons/patrol_heavy_ammunition.dmi'
	merge_type = /obj/item/stack/stationtrauma_autocannon_shell/heavy
	max_amount = 8

/obj/item/stack/stationtrauma_autocannon_shell/heavy/full
	amount = /obj/item/stack/stationtrauma_autocannon_shell/heavy::max_amount

/obj/item/stack/stationtrauma_autocannon_shell/update_icon_state()
	. = ..()
	if(amount == 1)
		icon_state = "shell"

/obj/machinery/stationtrauma_autocannon/examine(mob/user)
	. = ..()
	. += span_notice("В подаче [shells]/[feed_capacity] снарядов.")

/obj/machinery/stationtrauma_autocannon/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/stationtrauma_autocannon_shell))
		return ..()
	if(firing_burst)
		balloon_alert(user, "идёт очередь")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/stack/stationtrauma_autocannon_shell/ammo = tool
	if(ammo.merge_type != ammo_type)
		balloon_alert(user, "неподходящие снаряды")
		return ITEM_INTERACT_BLOCKING
	var/count = min(feed_capacity - shells, ammo.get_amount())
	if(!count)
		balloon_alert(user, "подача полна")
		return ITEM_INTERACT_BLOCKING
	if(!ammo.use(count))
		return ITEM_INTERACT_BLOCKING
	shells += count
	balloon_alert(user, "заряжено: [shells]/[feed_capacity]")
	return ITEM_INTERACT_SUCCESS

/** Only mounts still on this hull can be operated from its console. */
/obj/machinery/stationtrauma_autocannon/proc/is_mounted(obj/docking_port/mobile/stationtrauma_space/vessel)
	return !QDELETED(vessel) && anchored && vessel_ref?.resolve() == vessel && vessel.is_in_shuttle_bounds(src) && vessel.shuttle_areas[get_area(src)]

/obj/machinery/stationtrauma_autocannon/proc/hardware_ready(obj/docking_port/mobile/stationtrauma_space/ship)
	return is_mounted(ship) && !panel_open && !(machine_stat & (NOPOWER|BROKEN|MAINT))

/** Match the shuttered feed through the intervening hull tile even if the native shuttle rotates. */
/obj/machinery/stationtrauma_autocannon/proc/interior_loader()
	var/turf/inlet = get_step(get_step(src, REVERSE_DIR(dir)), REVERSE_DIR(dir))
	var/obj/machinery/stationtrauma_autocannon_loader/loader = locate() in inlet
	if(!QDELETED(loader) && loader.mounted_gun() == src)
		return loader

/obj/machinery/stationtrauma_autocannon/proc/firing_muzzle()
	return clear_muzzle_ahead(src)

/obj/machinery/stationtrauma_autocannon/proc/clear_muzzle_ahead(atom/barrel)
	var/turf/muzzle = get_step(barrel, dir)
	return isspaceturf(muzzle) && !muzzle.is_transition_turf() && !muzzle.is_blocked_turf() ? muzzle : null

/obj/machinery/stationtrauma_autocannon/proc/firing_heading(datum/stationtrauma_overmap/space/map)
	return WRAP(map.course + dir2angle(dir) - dir2angle(map.vessel.preferred_direction), 0, 360)

/obj/machinery/stationtrauma_autocannon/proc/charge_demand(obj/docking_port/mobile/stationtrauma_space/ship)
	if(!hardware_ready(ship))
		return 0
	return max(0, ST_AUTOCANNON_CAPACITY - capacitor_charge)

/** Hardware readiness, independent of the selected aim point. */
/obj/machinery/stationtrauma_autocannon/proc/readiness(datum/stationtrauma_overmap/space/map)
	if(!hardware_ready(map.vessel))
		return "fault"
	if(firing_burst)
		return "firing"
	if(!COOLDOWN_FINISHED(src, burst_cooldown))
		return "reload"
	if(!shells)
		return "empty"
	if(map.vessel.combat_power_managed && capacitor_charge < ST_AUTOCANNON_SHOT_ENERGY)
		return "charging"
	if(!map.kinetic_flight_ready())
		return "moored"
	if(!firing_muzzle())
		return "obstructed"
	return "ready"

/** Resolve a sector point to a valid firing angle without tracking a ship. */
/obj/machinery/stationtrauma_autocannon/proc/aim_at(datum/stationtrauma_overmap/space/map, aim_x, aim_y)
	var/dx = aim_x - map.pos_x
	var/dy = aim_y - map.pos_y
	if(abs(dx) > ST_AUTOCANNON_RANGE || abs(dy) > ST_AUTOCANNON_RANGE)
		return null
	var/distance_squared = dx ** 2 + dy ** 2
	if(distance_squared <= map.kinetic_launch_offset() ** 2 || distance_squared > ST_AUTOCANNON_RANGE ** 2)
		return null
	var/angle = delta_to_angle(dx, dy)
	if(abs(closer_angle_difference(firing_heading(map), angle)) > ST_AUTOCANNON_ARC)
		return null
	return angle

/** Claim the feed before yielding to the burst, so two consoles cannot fire the same mount. */
/obj/machinery/stationtrauma_autocannon/proc/start_burst(obj/machinery/computer/stationtrauma_weapon_console/console, mob/user, datum/stationtrauma_overmap/space/map, aim_x, aim_y)
	map.advance()
	if(readiness(map) != "ready" || isnull(aim_at(map, aim_x, aim_y)))
		return FALSE
	firing_burst = TRUE
	INVOKE_ASYNC(src, PROC_REF(fire_burst), console, user, map, map.sector, aim_x, aim_y)
	return TRUE

/obj/machinery/stationtrauma_autocannon/proc/fire_burst(obj/machinery/computer/stationtrauma_weapon_console/console, mob/user, datum/stationtrauma_overmap/space/map, datum/stationtrauma_overmap_sector/space/sector, aim_x, aim_y)
	var/rounds_fired = 0
	for(var/index in 1 to burst_size)
		if(QDELETED(src) || QDELETED(map) || map.sector != sector || !console?.can_control_weapons(user) || console.current_vessel() != map.vessel || !is_mounted(map.vessel))
			break
		if(!fire_round(console, user, map, aim_x, aim_y))
			balloon_alert(user, rounds_fired ? "очередь прервана" : "выстрел недоступен")
			break
		rounds_fired++
		if(index < burst_size && shells)
			sleep(0.3 SECONDS)
		else
			break
	firing_burst = FALSE
	if(rounds_fired)
		COOLDOWN_START(src, burst_cooldown, reload_time)

/** Commit one physical shell and draw its power from the control station's supply. */
/obj/machinery/stationtrauma_autocannon/proc/fire_round(obj/machinery/computer/stationtrauma_weapon_console/console, mob/user, datum/stationtrauma_overmap/space/map, aim_x, aim_y)
	map.advance()
	if(!map.kinetic_flight_ready() || panel_open || (machine_stat & (NOPOWER|BROKEN|MAINT)))
		return FALSE
	var/turf/muzzle = firing_muzzle()
	if(!muzzle || !shells)
		return FALSE
	var/angle = aim_at(map, aim_x, aim_y)
	if(isnull(angle))
		return FALSE
	if(map.vessel.combat_power_managed)
		if(capacitor_charge < ST_AUTOCANNON_SHOT_ENERGY)
			return FALSE
		capacitor_charge -= ST_AUTOCANNON_SHOT_ENERGY
	else if(console.use_energy(ST_AUTOCANNON_SHOT_ENERGY, force = FALSE) < ST_AUTOCANNON_SHOT_ENERGY)
		return FALSE
	shells--
	var/datum/stationtrauma_kinetic_shot/shot = new
	shot.projectile_type = projectile_type
	shot.sector_ref = WEAKREF(map.sector)
	shot.source_ref = WEAKREF(map)
	shot.gunner_ref = WEAKREF(user)
	shot.weapon_ref = WEAKREF(src)
	shot.direction_x = sin(angle)
	shot.direction_y = cos(angle)
	var/offset = map.kinetic_launch_offset()
	shot.pos_x = map.pos_x + shot.direction_x * offset
	shot.pos_y = map.pos_y + shot.direction_y * offset
	shot.remaining = ST_AUTOCANNON_RANGE - offset
	var/obj/projectile/bullet/stationtrauma_kinetic/round = new projectile_type(muzzle)
	round.outgoing_shot = shot
	round.range = round.maximum_range = 2 * (world.maxx + world.maxy)
	round.firer = user
	round.fired_from = src
	log_combat(user, src, "fired", "toward sector coordinates ([round(aim_x, 0.1)], [round(aim_y, 0.1)])")
	// The feed transmits the report into the hull even though the mount itself is in vacuum.
	var/atom/sound_origin = interior_loader() || console
	playsound(sound_origin, firing_sound, 75, TRUE, pressure_affected = FALSE)
	if(get_dist(user, sound_origin) > SOUND_RANGE)
		user.playsound_local(get_turf(console), firing_sound, 60, TRUE, pressure_affected = FALSE)
	round.fire(WRAP(angle - map.course + dir2angle(map.vessel.preferred_direction), 0, 360))
	return TRUE

/** Inside the hull, a one-stack magazine feeds the gun across a sealed panel. */
/obj/machinery/stationtrauma_autocannon_loader
	name = "загрузочный лоток автопушки"
	desc = "Закрытая подача к наружной автопушке. Загрузите пачку кинетических снарядов прямо в лоток."
	icon = 'modular_bandastation/space_combat/icons/patrol_machines.dmi'
	icon_state = "loader"
	dir = NORTH
	anchored = TRUE
	density = FALSE
	interaction_flags_machine = NONE
	/// Rounds still inside the ship, independent of the gun's local feed.
	var/reserve_shells = 0
	var/reserve_capacity = 30
	/// Prevent cross-feeding when a loader or gun has been replaced.
	var/ammo_type = /obj/item/stack/stationtrauma_autocannon_shell

/obj/machinery/stationtrauma_autocannon_loader/update_icon_state()
	icon_state = reserve_shells ? "loader_stocked" : "loader"
	return ..()

/obj/machinery/stationtrauma_autocannon_loader/proc/mounted_gun()
	var/turf/outlet = get_step(get_step(src, dir), dir)
	var/obj/machinery/stationtrauma_autocannon/gun = locate() in outlet
	if(QDELETED(gun) || gun.dir != dir || gun.ammo_type != ammo_type || !anchored)
		return null
	var/obj/docking_port/mobile/stationtrauma_space/ship = gun.vessel_ref?.resolve()
	var/area/shuttle/stationtrauma_space/compartment = get_area(src)
	if(!QDELETED(ship) && gun.is_mounted(ship) && istype(compartment) && !compartment.vacuum_by_design \
		&& ship.shuttle_areas[compartment] && ship.is_in_shuttle_bounds(src))
		return gun

/obj/machinery/stationtrauma_autocannon_loader/proc/operating()
	return anchored && !panel_open && !(machine_stat & (NOPOWER|BROKEN|MAINT))

/obj/machinery/stationtrauma_autocannon_loader/proc/feeder_available(obj/machinery/stationtrauma_autocannon/gun)
	return operating() && gun?.hardware_ready(gun.vessel_ref?.resolve())

/obj/machinery/stationtrauma_autocannon_loader/examine(mob/user)
	. = ..()
	. += span_notice("В лотке [reserve_shells]/[reserve_capacity] снарядов.")
	var/obj/machinery/stationtrauma_autocannon/gun = mounted_gun()
	if(!feeder_available(gun))
		. += span_warning("Подача к орудию недоступна.")

/obj/machinery/stationtrauma_autocannon_loader/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/stationtrauma_autocannon_shell))
		return ..()
	if(!Adjacent(user) || !operating() || !can_interact(user))
		return ITEM_INTERACT_BLOCKING
	var/obj/item/stack/stationtrauma_autocannon_shell/ammo = tool
	if(ammo.merge_type != ammo_type)
		balloon_alert(user, "неподходящие снаряды")
		return ITEM_INTERACT_BLOCKING
	var/count = min(reserve_capacity - reserve_shells, ammo.get_amount())
	if(count <= 0)
		balloon_alert(user, "лоток полон")
		return ITEM_INTERACT_BLOCKING
	if(!ammo.use(count))
		return ITEM_INTERACT_BLOCKING
	reserve_shells += count
	feed_gun()
	update_appearance(UPDATE_ICON_STATE)
	balloon_alert(user, "в лотке [reserve_shells]/[reserve_capacity]")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_autocannon_loader/process(seconds_per_tick)
	if(reserve_shells)
		feed_gun()

/obj/machinery/stationtrauma_autocannon_loader/proc/feed_gun()
	var/obj/machinery/stationtrauma_autocannon/gun = mounted_gun()
	if(!feeder_available(gun) || gun.firing_burst)
		return
	var/count = min(reserve_shells, gun.feed_capacity - gun.shells)
	if(count <= 0)
		return
	reserve_shells -= count
	gun.shells += count
	if(!reserve_shells)
		update_appearance(UPDATE_ICON_STATE)

/** A two-tile naval mount. Its forward assembly travels with the same native shuttle footprint. */
/obj/machinery/stationtrauma_autocannon/heavy
	name = "тяжёлая кинетическая автопушка"
	desc = "Двухсекционная корабельная установка. Даёт очередь из двух усиленных выстрелов и шесть секунд возвращается в готовность."
	icon = 'modular_bandastation/space_combat/icons/patrol_heavy_gun.dmi'
	icon_state = "receiver"
	ammo_type = /obj/item/stack/stationtrauma_autocannon_shell/heavy
	projectile_type = /obj/projectile/bullet/stationtrauma_kinetic/heavy
	firing_sound = 'sound/items/weapons/gun/rifle/shot_heavy.ogg'
	burst_size = 2
	reload_time = 6 SECONDS
	feed_capacity = 4
	shells = 4

/obj/machinery/stationtrauma_autocannon/heavy/firing_muzzle()
	var/obj/structure/stationtrauma_autocannon_barrel/barrel = locate() in get_step(src, dir)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(!QDELETED(barrel) && barrel.anchored && barrel.dir == dir && ship?.shuttle_areas[get_area(barrel)] && ship.is_in_shuttle_bounds(barrel))
		return clear_muzzle_ahead(barrel)
	return null

/obj/structure/stationtrauma_autocannon_barrel
	name = "ствольная секция тяжёлой автопушки"
	desc = "Передняя секция двухтайловой корабельной установки."
	icon = 'modular_bandastation/space_combat/icons/patrol_heavy_gun.dmi'
	icon_state = "barrel"
	anchored = TRUE
	density = TRUE

/obj/machinery/stationtrauma_autocannon_loader/compact
	name = "малый загрузочный лоток автопушки"
	desc = "Компактная подача тяжёлой установки. Вмещает восемь тяжёлых кинетических снарядов."
	icon = 'modular_bandastation/space_combat/icons/patrol_heavy_gun.dmi'
	ammo_type = /obj/item/stack/stationtrauma_autocannon_shell/heavy
	reserve_capacity = 8
