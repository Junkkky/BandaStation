// Field gear of the corps after the NT explorers of SierraBay: role lockers, anomaly suit,
// leader's machete, animal net launcher and the XP-3 ballistic launcher.

#define CALIBER_EXPEDITION_NET "expedition net"
/// Combined damage of a shell above which the XP-3 may burst: slugs and buckshot do, beanbags and rubbershot do not.
#define XP3_SAFE_DAMAGE 20

// ===== Role lockers =====

/obj/structure/closet/secure_closet/expedition
	name = "шкафчик исследователя"
	icon_state = "mining"
	req_access = list(ACCESS_EXPLORER)

/obj/structure/closet/secure_closet/expedition/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/radio = 1,
		/obj/item/gps/expedition = 1,
		/obj/item/storage/belt/expedition_sheath = 1,
		/obj/item/clothing/accessory/expedition_webbing = 1,
		/obj/item/analyzer = 1,
		/obj/item/binoculars = 1,
		/obj/item/crowbar = 1,
		/obj/item/stack/marker_beacon/ten = 1,
	), src)
	var/light_type = pick(/obj/item/flashlight, /obj/item/flashlight/flare, /obj/item/flashlight/glowstick)
	new light_type(src)

/obj/structure/closet/secure_closet/expedition/leader
	name = "шкафчик главы экспедиционного корпуса"
	icon_state = "qm"
	req_access = list(ACCESS_EXPEDITION_LEADER)

/obj/structure/closet/secure_closet/expedition/leader/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/hatchet/expedition_machete/deluxe = 1,
		/obj/item/taperecorder = 1,
		/obj/item/tape/random = 1,
		/obj/item/assembly/flash/handheld = 1,
		/obj/item/flashlight/seclite = 1,
		/obj/item/encryptionkey/expedition = 2,
		/obj/item/clothing/under/expedition = 1,
		/obj/item/clothing/under/expedition/leader = 1,
		/obj/item/clothing/under/expedition/pilot = 1,
		/obj/item/clothing/under/expedition/engineer = 1,
	), src)

/obj/structure/closet/secure_closet/expedition/pilot
	name = "шкафчик пилота экспедиционного корпуса"

/obj/structure/closet/secure_closet/expedition/pilot/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/storage/belt/utility/full = 1,
		/obj/item/clothing/gloves/color/black/expedition = 1,
		/obj/item/clothing/suit/toggle/expedition = 1,
		/obj/item/clothing/head/helmet/expedition_pilot = 1,
	), src)

/obj/structure/closet/secure_closet/expedition/medic
	name = "шкафчик полевого медика"
	icon_state = "med"

/obj/structure/closet/secure_closet/expedition/medic/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/storage/belt/medical/paramedic = 1,
		/obj/item/healthanalyzer = 1,
		/obj/item/storage/medkit/advanced = 1,
		/obj/item/clothing/gloves/color/black/expedition = 1,
	), src)

/obj/structure/closet/secure_closet/expedition/engineer
	name = "шкафчик полевого инженера"
	icon_state = "eng"

/obj/structure/closet/secure_closet/expedition/engineer/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/storage/belt/utility/full = 1,
		/obj/item/multitool = 1,
		/obj/item/flashlight/seclite = 1,
		/obj/item/clothing/gloves/color/black/expedition = 1,
	), src)

// ===== Anomaly suit =====

/// Bio suit cut for work around anomalies and artifacts; its bio rating is what shields from them.
/obj/item/clothing/suit/bio_suit/expedition_anomaly
	name = "антианомальный костюм"
	desc = "Костюм, защищающий от экзотических инопланетных энергий и биологического заражения."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/gear_worn.dmi'
	lefthand_file = 'modular_bandastation/explorers/icons/gear_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/gear_righthand.dmi'
	icon_state = "bio_anom"
	inhand_icon_state = "bio_anom"
	supports_variations_flags = NONE
	bodyshapes_with_variations = NONE

/obj/item/clothing/head/bio_hood/expedition_anomaly
	name = "антианомальный капюшон"
	desc = "Капюшон, защищающий голову и лицо от экзотических инопланетных энергий и биологического заражения."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/gear_worn.dmi'
	lefthand_file = 'modular_bandastation/explorers/icons/gear_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/gear_righthand.dmi'
	icon_state = "bio_anom_hood"
	inhand_icon_state = "bio_anom_hood"
	dirt_state = null

/obj/structure/closet/l3closet/expedition
	name = "шкаф антианомальной защиты"
	icon_door = "bio_sci"

/obj/structure/closet/l3closet/expedition/PopulateContents()
	new /obj/item/clothing/suit/bio_suit/expedition_anomaly(src)
	new /obj/item/clothing/head/bio_hood/expedition_anomaly(src)
	new /obj/item/clothing/mask/breath(src)
	new /obj/item/tank/internals/oxygen(src)

// ===== Leader's machete =====

/obj/item/hatchet/expedition_machete/deluxe
	name = "парадное мачете главы корпуса"
	desc = "Отменное мачете с полированным клинком, деревянной рукоятью и кожаным темляком."
	icon_state = "machetedx"

// ===== Animal net launcher =====

/// Net shell: fits a bandolier like a shotgun shell, but only the net launcher takes its calibre.
/obj/item/ammo_casing/shotgun/expedition_net
	name = "сетевой заряд"
	desc = "Гильза с самораскрывающейся сетью для сетемёта. Похожа на фонарик."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	icon_state = "netshell"
	caliber = CALIBER_EXPEDITION_NET
	projectile_type = /obj/projectile/expedition_net
	newtonian_force = 0.5

/obj/projectile/expedition_net
	name = "сеть для животных"
	icon = 'icons/obj/clothing/modsuit/mod_modules.dmi'
	icon_state = "net_projectile"
	damage = 0
	range = 7
	hitsound = 'sound/items/fulton/fultext_deploy.ogg'
	hitsound_wall = 'sound/items/fulton/fultext_deploy.ogg'

/obj/projectile/expedition_net/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/mob/living/victim = target
	if(!istype(victim) || (locate(/obj/structure/energy_net) in get_turf(victim)))
		return
	var/obj/structure/energy_net/expedition/net = new(victim.drop_location())
	victim.visible_message(span_danger("[victim] запутывается в сети!"), span_userdanger("Вас опутывает сеть!"))
	victim.buckled?.unbuckle_mob(victim, force = TRUE)
	net.buckle_mob(victim, force = TRUE)

/// A net that holds an animal for transport: it can be dragged, and a person shakes it off quickly.
/obj/structure/energy_net/expedition
	name = "сеть для животных"
	desc = "Энергетическая сеть для поимки животных. Её можно тащить вместе с добычей."
	anchored = FALSE
	buckle_prevents_pull = FALSE
	max_integrity = 25

/obj/structure/energy_net/expedition/user_unbuckle_mob(mob/living/buckled_mob, mob/living/user)
	if(user != buckled_mob)
		return
	user.visible_message(span_warning("[user] пытается выпутаться из сети!"), span_notice("Вы пытаетесь выпутаться из сети..."))
	if(!do_after(user, 1 SECONDS, src) || QDELETED(src) || !(user in buckled_mobs))
		return
	user.visible_message(span_warning("[user] выпутывается из сети!"), span_notice("Вы выпутались из сети."))
	qdel(src)

/obj/item/ammo_box/magazine/internal/expedition_netgun
	name = "внутренний магазин сетемёта"
	ammo_type = /obj/item/ammo_casing/shotgun/expedition_net
	caliber = CALIBER_EXPEDITION_NET
	max_ammo = 1

/obj/item/ammo_box/magazine/internal/expedition_netgun/empty
	start_empty = TRUE

/// XX-1 "Varmint Catcher": one net shell at a time, to bring fauna home alive.
/obj/item/gun/ballistic/expedition_netgun
	name = "сетемёт XX-1 «Ловец вредителей»"
	desc = "Изготовленный на заказ Xenonomix, он ловит даже самых буйных тварей для безопасной перевозки."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	icon_state = "netgun"
	inhand_icon_state = "grenade_launcher"
	worn_icon_state = "dragnet"
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/expedition_netgun/empty
	fire_sound = 'sound/items/weapons/empty.ogg'
	slot_flags = ITEM_SLOT_BACK
	w_class = WEIGHT_CLASS_BULKY
	weapon_weight = WEAPON_MEDIUM
	can_suppress = FALSE
	casing_ejector = FALSE
	bolt_type = BOLT_TYPE_NO_BOLT
	internal_magazine = TRUE
	tac_reloads = FALSE
	can_muzzle_flash = FALSE
	cartridge_wording = "зарядов"

/obj/item/storage/belt/bandolier/expedition_safari
	name = "сафари-бандольер"
	desc = "Бандольер, набитый сетевыми зарядами для сетемёта."

/obj/item/storage/belt/bandolier/expedition_safari/PopulateContents()
	generate_items_inside(list(/obj/item/ammo_casing/shotgun/expedition_net = 10), src)

// ===== XP-3 ballistic launcher =====

/**
 * Xynergy XP-3 "Boomstick": a pump launcher for 12 gauge payloads that is "not a shotgun".
 * Off the station it fires freely; full-power loads may burst it in the hands, less so with
 * the barrel reinforced by a pipe.
 */
/obj/item/gun/ballistic/shotgun/expedition_xp3
	name = "баллистический метатель XP-3"
	desc = "Как напомнит руководство пользователя, Xynergy XP-3 — /не/ дробовик: он просто метает заряды того же калибра. Прозван «Бумстиком» за поведение на полноценных боеприпасах."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	icon_state = "expshotgun0"
	worn_icon_state = "shotgun"
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/expedition_xp3
	pin = /obj/item/firing_pin/explorer
	/// Chance in percent that a full-power shell bursts it.
	var/burst_chance = 50
	/// Pipe reinforcing the barrel, if any.
	var/obj/item/pipe/reinforcement

/obj/item/ammo_box/magazine/internal/shot/expedition_xp3
	start_empty = TRUE

/obj/item/gun/ballistic/shotgun/expedition_xp3/Destroy()
	QDEL_NULL(reinforcement)
	return ..()

/obj/item/gun/ballistic/shotgun/expedition_xp3/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == reinforcement)
		reinforcement = null
		burst_chance = initial(burst_chance)
		update_appearance()

/obj/item/gun/ballistic/shotgun/expedition_xp3/examine(mob/user)
	. = ..()
	. += reinforcement ? span_notice("Ствол укреплён трубой; её можно снять кусачками.") : span_notice("Ствол можно укрепить трубой, чтобы мощные заряды реже разрывали его.")

/obj/item/gun/ballistic/shotgun/expedition_xp3/update_icon_state()
	. = ..()
	icon_state = "[reinforcement ? "ghett" : ""]expshotgun[chambered ? 1 : 0]"

/obj/item/gun/ballistic/shotgun/expedition_xp3/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/pipe))
		return ..()
	if(reinforcement)
		balloon_alert(user, "уже укреплён!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	reinforcement = tool
	burst_chance = 10
	playsound(src, 'sound/items/duct_tape/duct_tape_rip.ogg', 25, TRUE)
	balloon_alert(user, "ствол укреплён")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/ballistic/shotgun/expedition_xp3/wirecutter_act(mob/living/user, obj/item/tool)
	if(!reinforcement)
		return NONE
	tool.play_tool_sound(src)
	user.put_in_hands(reinforcement)
	balloon_alert(user, "труба снята")
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/ballistic/shotgun/expedition_xp3/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	var/obj/projectile/payload = chambered?.loaded_projectile
	if(payload && payload.damage * chambered.pellets > XP3_SAFE_DAMAGE && prob(burst_chance))
		burst(user)
		return FALSE
	return ..()

/// Bursts in the hands of `user`, hurting their hands and face.
/obj/item/gun/ballistic/shotgun/expedition_xp3/proc/burst(mob/living/user)
	if(user)
		user.visible_message(span_danger("[src] разрывается в руках [user]!"), span_userdanger("[src] разрывается прямо у вас в руках!"))
		user.dropItemToGround(src, force = TRUE)
		for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_HEAD))
			user.apply_damage(rand(10, 20), BRUTE, zone)
	else
		visible_message(span_danger("[src] разрывается!"))
	reinforcement?.forceMove(drop_location())
	explosion(src, light_impact_range = 1, explosion_cause = src)
	qdel(src)

#undef XP3_SAFE_DAMAGE
#undef CALIBER_EXPEDITION_NET
