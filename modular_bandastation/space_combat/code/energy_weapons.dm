/** A single-tile laser emitter fed exclusively by ship power. */
/obj/machinery/stationtrauma_autocannon/laser
	name = "корабельная лазерная пушка"
	desc = "Импульсный излучатель с красной линзой. Бортовая сеть заряжает накопитель на два одиночных выстрела."
	icon = 'modular_bandastation/space_combat/icons/ship_energy_weapons.dmi'
	icon_state = "laser"
	ammo_type = null
	shells = 0
	feed_capacity = 0
	burst_size = 1
	reload_time = 2 SECONDS
	requires_powered_grid = TRUE
	energy_per_shot = 12 KILO JOULES
	capacitor_capacity = 24 KILO JOULES
	projectile_type = /obj/projectile/bullet/stationtrauma_kinetic/energy/laser
	firing_sound = 'sound/items/weapons/lasercannonfire.ogg'
	muzzle_flash_type = /obj/effect/projectile/muzzle/laser
	muzzle_flash_color = COLOR_SOFT_RED

/** The plasma breech drives a separate, matched focusing section. */
/obj/machinery/stationtrauma_autocannon/heavy/plasma
	name = "тяжёлая плазменная пушка"
	desc = "Двухсекционная корабельная пушка. Каждый выстрел расходует заряд бортового накопителя и один плазменный картридж. Прямое попадание может прожечь обшивку насквозь. Плазменная волна обжигает всё в радиусе одного тайла."
	icon = 'modular_bandastation/space_combat/icons/ship_energy_weapons.dmi'
	ammo_type = /obj/item/stack/stationtrauma_autocannon_shell/plasma
	barrel_type = /obj/structure/stationtrauma_autocannon_barrel/plasma
	shells = 2
	feed_capacity = 2
	burst_size = 1
	reload_time = 8 SECONDS
	requires_powered_grid = TRUE
	energy_per_shot = 30 KILO JOULES
	capacitor_capacity = 60 KILO JOULES
	projectile_type = /obj/projectile/bullet/stationtrauma_kinetic/energy/plasma
	firing_sound = 'sound/items/weapons/pulse3.ogg'
	muzzle_flash_type = /obj/effect/projectile/muzzle/plasma_cutter/ship
	muzzle_flash_color = LIGHT_COLOR_PURPLE

/obj/effect/projectile/muzzle/plasma_cutter/ship
	// Shift the cyan fringe into violet while preserving the bright core and transparency.
	color = list(0.2,0.8,0,0, 0.8,0.2,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0)

/obj/structure/stationtrauma_autocannon_barrel/plasma
	name = "фокусирующая секция плазменной пушки"
	desc = "Блок магнитных колец, направляющий плазменный сгусток за пределы корпуса."
	icon = 'modular_bandastation/space_combat/icons/ship_energy_weapons.dmi'

/obj/machinery/stationtrauma_autocannon_loader/plasma
	name = "лоток плазменных картриджей"
	desc = "Изолированный лоток тяжёлой плазменной пушки. Принимает до четырёх картриджей по одному."
	icon = 'modular_bandastation/space_combat/icons/ship_energy_weapons.dmi'
	ammo_type = /obj/item/stack/stationtrauma_autocannon_shell/plasma
	reserve_capacity = 4
	shell_load_time = 2.5 SECONDS

/obj/item/stack/stationtrauma_autocannon_shell/plasma
	name = "плазменные картриджи"
	singular_name = "плазменный картридж"
	desc = "Герметичные картриджи с рабочей плазмой для тяжёлой корабельной пушки. В полной кассете четыре картриджа."
	icon = 'modular_bandastation/space_combat/icons/ship_energy_weapons.dmi'
	merge_type = /obj/item/stack/stationtrauma_autocannon_shell/plasma
	max_amount = 4

/obj/item/stack/stationtrauma_autocannon_shell/plasma/full
	amount = /obj/item/stack/stationtrauma_autocannon_shell/plasma::max_amount

/** Thermal projectiles share sector travel and shield interception with kinetic shells. */
/obj/projectile/bullet/stationtrauma_kinetic/energy
	icon = 'modular_bandastation/space_combat/icons/ship_energy_weapons.dmi'
	damage_type = BURN
	shrapnel_type = null
	embed_type = null
	wound_falloff_tile = 0
	embed_falloff_tile = 0
	hitsound = 'sound/items/weapons/sear.ogg'
	hitsound_wall = 'sound/items/weapons/effects/searwall.ogg'

/obj/projectile/bullet/stationtrauma_kinetic/energy/laser
	name = "корабельный лазерный импульс"
	icon_state = "laser_bolt"
	damage = 65
	armor_flag = LASER
	pass_flags = PASSTABLE | PASSGLASS | PASSGRILLE
	speed = 2 * ST_AUTOCANNON_LOCAL_SPEED
	sector_speed = 4 * ST_AUTOCANNON_SPEED
	impact_strength = 0.5
	impact_effect_type = /obj/effect/temp_visual/impact_effect/red_laser
	plot_color = COLOR_SOFT_RED

/obj/projectile/bullet/stationtrauma_kinetic/energy/plasma
	name = "тяжёлый плазменный сгусток"
	icon_state = "plasma_bolt"
	damage = 240
	armor_flag = ENERGY
	sector_speed = 0.75 * ST_AUTOCANNON_SPEED
	shield_impact = 4 * ST_SHIP_SHIELD_KINETIC_IMPACT
	impact_strength = 5
	impact_effect_type = /obj/effect/temp_visual/impact_effect/purple_laser
	plot_color = LIGHT_COLOR_PURPLE
	/// A projectile forced to pierce by its target can still discharge only once.
	var/discharged = FALSE

/obj/projectile/bullet/stationtrauma_kinetic/energy/plasma/on_hit(atom/target, blocked = 0, pierce_hit)
	var/turf/center = get_turf(target)
	. = ..()
	if(. != BULLET_ACT_HIT || blocked >= 100 || discharged || !center || damage <= 0)
		return
	discharged = TRUE
	new /obj/effect/temp_visual/circle_wave/ship_plasma(center)
	playsound(center, 'sound/items/weapons/resonator_blast.ogg', 75, TRUE, pressure_affected = FALSE)

	var/obj/docking_port/mobile/stationtrauma_space/hull = target_hull_ref?.resolve()
	var/splash_damage = damage * 0.25
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(target_hull_ref && (!hull || !hull.shuttle_areas[get_area(tile)] || !hull.is_in_shuttle_bounds(tile)))
			continue
		if(iswallturf(tile) && tile != target)
			tile.AddComponent(/datum/component/torn_wall, null, impact_strength * 0.25)
		else if(isfloorturf(tile))
			tile.burn_tile()
		for(var/mob/living/bystander in tile)
			if(bystander == target)
				continue
			var/armor = bystander.run_armor_check(attack_flag = ENERGY, silent = TRUE)
			if(bystander.apply_damage(splash_damage, BURN, blocked = armor, spread_damage = TRUE) && firer)
				log_combat(firer, bystander, "burned with the splash from", src)
		for(var/obj/fixture in tile)
			if(fixture == target || !(isstructure(fixture) || ismachinery(fixture)) || !fixture.uses_integrity || QDELETED(fixture) || fixture.get_integrity() <= 0)
				continue
			fixture.take_damage(splash_damage, BURN, ENERGY, sound_effect = FALSE)

/// The 64-pixel ring expands to the three-tile diameter of the plasma burst.
/obj/effect/temp_visual/circle_wave/ship_plasma
	name = "плазменная волна"
	color = COLOR_BIOLUMINESCENCE_PURPLE
	duration = 0.7 SECONDS
	amount_to_scale = 1.5
	light_system = OVERLAY_LIGHT
	light_range = 2
	light_color = LIGHT_COLOR_PURPLE

/obj/projectile/bullet/stationtrauma_kinetic/energy/plasma/damage_wall(turf/closed/wall/wall)
	// Shield absorption can turn a penetrating hit into repairable hull damage.
	if(impact_strength < 4)
		return ..()
	wall.dismantle_wall(devastated = TRUE)
