// Corps firearms against hostile fauna, with the look and sound of CM-SS13 rifles from BandaMarines
// and the handling and damage of existing station guns. The outback pin keeps them silent on the station.

/datum/sound_effect/expedition_pulse_rifle
	key = "expedition_pulse_rifle"
	file_paths = list(
		'modular_bandastation/explorers/sound/m20a_fire_1.ogg',
		'modular_bandastation/explorers/sound/m20a_fire_2.ogg',
		'modular_bandastation/explorers/sound/m20a_fire_3.ogg',
		'modular_bandastation/explorers/sound/m20a_fire_4.ogg',
		'modular_bandastation/explorers/sound/m20a_fire_5.ogg',
		'modular_bandastation/explorers/sound/m20a_fire_6.ogg',
	)

/// M20A "Harrington": light pulse rifle firing like the WT-550 and taking its magazines.
/obj/item/gun/ballistic/automatic/wt550/expedition_m20a
	name = "импульсная винтовка M20A «Харрингтон»"
	desc = "Предшественница M41A, которой до сих пор пользуются колониальная гвардия и гражданские организации. Лёгкая, автоматическая, принимает магазины 4,6×30 мм."
	icon = 'modular_bandastation/explorers/icons/firearms.dmi'
	icon_state = "m20a"
	worn_icon = 'modular_bandastation/explorers/icons/firearms_worn.dmi'
	worn_icon_state = "m20a"
	lefthand_file = 'modular_bandastation/explorers/icons/firearms_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/firearms_righthand.dmi'
	inhand_icon_state = "m20a"
	slot_flags = ITEM_SLOT_BACK
	fire_sound = "expedition_pulse_rifle"
	// A quarter weaker than the station WT-550: two of these come with the corps.
	projectile_damage_multiplier = 0.75
	load_sound = 'modular_bandastation/explorers/sound/l42_reload.ogg'
	load_empty_sound = 'modular_bandastation/explorers/sound/l42_reload.ogg'
	eject_sound = 'modular_bandastation/explorers/sound/l42_unload.ogg'
	eject_empty_sound = 'modular_bandastation/explorers/sound/l42_unload.ogg'
	pin = /obj/item/firing_pin/explorer
	mag_display = FALSE
	mag_display_ammo = FALSE
	empty_indicator = FALSE
	show_bolt_icon = FALSE

/obj/item/gun/ballistic/automatic/wt550/expedition_m20a/update_icon_state()
	. = ..()
	icon_state = "[initial(icon_state)][magazine ? "" : "_e"]"

/// M4RA: bullpup marksman rifle firing like the Cawil marksman rifle and taking .40 Sol rifle magazines.
/obj/item/gun/ballistic/automatic/carwo/marksman/expedition_m4ra
	name = "боевая винтовка M4RA"
	desc = "Марксманская винтовка-буллпап Armat для разведки и огневой поддержки. Стреляет одиночными, принимает винтовочные магазины .40 Sol."
	icon = 'modular_bandastation/explorers/icons/firearms.dmi'
	icon_state = "m4ra"
	worn_icon = 'modular_bandastation/explorers/icons/firearms_worn.dmi'
	worn_icon_state = "m4ra"
	lefthand_file = 'modular_bandastation/explorers/icons/firearms_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/firearms_righthand.dmi'
	inhand_icon_state = "m4ra"
	SET_BASE_PIXEL(-6, 0)
	fire_sound = 'modular_bandastation/explorers/sound/m4ra_fire.ogg'
	load_sound = 'modular_bandastation/explorers/sound/l42_reload.ogg'
	load_empty_sound = 'modular_bandastation/explorers/sound/l42_reload.ogg'
	eject_sound = 'modular_bandastation/explorers/sound/l42_unload.ogg'
	eject_empty_sound = 'modular_bandastation/explorers/sound/l42_unload.ogg'
	pin = /obj/item/firing_pin/explorer
	can_suppress = FALSE
	mag_display = FALSE
	show_bolt_icon = FALSE

/obj/item/gun/ballistic/automatic/carwo/marksman/expedition_m4ra/update_icon_state()
	. = ..()
	icon_state = "[initial(icon_state)][magazine ? "" : "_e"]"
	inhand_icon_state = initial(inhand_icon_state)
	worn_icon_state = initial(worn_icon_state)

/// The ship's weapon safe: rifles, the XP-3 and net launchers for the whole corps.
/obj/structure/closet/secure_closet/expedition_ship_armory
	name = "оружейный сейф экспедиционного корабля"
	desc = "Оружие на случай столкновения с агрессивной фауной. На станции из него не выстрелить."
	icon_state = "tac"
	req_access = list(ACCESS_EXPLORER)

/obj/structure/closet/secure_closet/expedition_ship_armory/PopulateContents()
	generate_items_inside(list(
		/obj/item/gun/ballistic/automatic/wt550/expedition_m20a = 2,
		/obj/item/ammo_box/magazine/wt550m9 = 4,
		/obj/item/gun/ballistic/automatic/carwo/marksman/expedition_m4ra = 1,
		/obj/item/ammo_box/magazine/c40sol_rifle = 3,
		/obj/item/gun/ballistic/shotgun/expedition_xp3 = 1,
		/obj/item/storage/box/beanbag = 1,
		/obj/item/storage/box/rubbershot = 1,
		/obj/item/gun/ballistic/expedition_netgun = 2,
		/obj/item/storage/belt/bandolier/expedition_safari = 1,
	), src)
