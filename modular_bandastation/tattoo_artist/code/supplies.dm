/obj/item/tattoo_machine
	name = "rotary tattoo machine"
	desc = "Машинка для нанесения и сведения татуировок. Активируйте её в руке, чтобы переключить режим."
	icon = 'modular_bandastation/tattoo_artist/icons/studio.dmi'
	icon_state = "machine"
	lefthand_file = 'modular_bandastation/tattoo_artist/icons/studio_l.dmi'
	righthand_file = 'modular_bandastation/tattoo_artist/icons/studio_r.dmi'
	w_class = WEIGHT_CLASS_SMALL

/obj/item/tattoo_needle
	name = "sterile tattoo cartridge"
	desc = "Одноразовый игольный картридж в запечатанном блистере. Вставьте его в тату-машинку перед сеансом. Одного картриджа хватает на весь сеанс с одним клиентом. Смените картридж перед следующим сеансом."
	icon = 'modular_bandastation/tattoo_artist/icons/studio.dmi'
	icon_state = "needle"
	lefthand_file = 'modular_bandastation/tattoo_artist/icons/studio_l.dmi'
	righthand_file = 'modular_bandastation/tattoo_artist/icons/studio_r.dmi'
	w_class = WEIGHT_CLASS_TINY

/obj/item/tattoo_wipe
	name = "tattoo prep swab"
	desc = "Стерильная салфетка в бирюзовом пакетике. Используйте её на клиенте перед первым нанесением. Одной салфетки хватает для подготовки всего тела."
	icon = 'modular_bandastation/tattoo_artist/icons/studio.dmi'
	icon_state = "wipe"
	lefthand_file = 'modular_bandastation/tattoo_artist/icons/studio_l.dmi'
	righthand_file = 'modular_bandastation/tattoo_artist/icons/studio_r.dmi'
	w_class = WEIGHT_CLASS_TINY

/obj/item/tattoo_dressing
	name = "tattoo aftercare film"
	desc = "Прозрачная защитная плёнка на бумажной подложке. После сеанса приложите её к открытой свежей татуировке клиента. Одной упаковки хватит, чтобы закрыть все такие татуировки."
	icon = 'modular_bandastation/tattoo_artist/icons/studio.dmi'
	icon_state = "dressing"
	lefthand_file = 'modular_bandastation/tattoo_artist/icons/studio_l.dmi'
	righthand_file = 'modular_bandastation/tattoo_artist/icons/studio_r.dmi'
	w_class = WEIGHT_CLASS_TINY

/obj/item/tattoo_ink
	name = "graphite tattoo ink"
	desc = "Герметичный флакон на четыре порции. Одной порции пигмента хватает на полный сеанс с одним клиентом. Поднесите флакон к машинке, чтобы заправить её."
	icon = 'modular_bandastation/tattoo_artist/icons/studio.dmi'
	icon_state = "ink_graphite"
	lefthand_file = 'modular_bandastation/tattoo_artist/icons/studio_l.dmi'
	righthand_file = 'modular_bandastation/tattoo_artist/icons/studio_r.dmi'
	w_class = WEIGHT_CLASS_TINY
	/// The ink color loaded into the machine; the same pigment is shown through the vial.
	var/pigment_color = "#262638"

/obj/item/tattoo_ink/carmine
	name = "carmine tattoo ink"
	icon_state = "ink_carmine"
	pigment_color = "#aa264b"

/obj/item/tattoo_ink/turquoise
	name = "turquoise tattoo ink"
	icon_state = "ink_turquoise"
	pigment_color = "#176b78"

/obj/item/tattoo_ink/ochre
	name = "ochre tattoo ink"
	icon_state = "ink_ochre"
	pigment_color = "#dc962d"

/obj/item/tattoo_ink/violet
	name = "violet tattoo ink"
	icon_state = "ink_violet"
	pigment_color = "#8253b2"

/obj/item/tattoo_ink/white
	name = "white tattoo ink"
	icon_state = "ink_white"
	pigment_color = "#f3f2ed"

/obj/item/tattoo_ink/silver
	name = "silver tattoo ink"
	icon_state = "ink_silver"
	pigment_color = "#9ca5ae"

/obj/item/tattoo_ink/yellow
	name = "yellow tattoo ink"
	icon_state = "ink_yellow"
	pigment_color = "#f1d344"

/obj/item/tattoo_ink/orange
	name = "orange tattoo ink"
	icon_state = "ink_orange"
	pigment_color = "#ee7634"

/obj/item/tattoo_ink/scarlet
	name = "scarlet tattoo ink"
	icon_state = "ink_scarlet"
	pigment_color = "#dc3540"

/obj/item/tattoo_ink/rose
	name = "rose tattoo ink"
	icon_state = "ink_rose"
	pigment_color = "#e98aad"

/obj/item/tattoo_ink/green
	name = "green tattoo ink"
	icon_state = "ink_green"
	pigment_color = "#398c54"

/obj/item/tattoo_ink/navy
	name = "navy tattoo ink"
	icon_state = "ink_navy"
	pigment_color = "#304d8c"

/obj/item/tattoo_ink/sky_blue
	name = "sky blue tattoo ink"
	icon_state = "ink_sky_blue"
	pigment_color = "#63b5da"

/obj/item/tattoo_ink/brown
	name = "brown tattoo ink"
	icon_state = "ink_brown"
	pigment_color = "#835638"

/obj/item/tattoo_mannequin
	name = "packed tattoo training mannequin"
	desc = "Складной манекен с учебной кожей. Встаньте лицом к свободной клетке и активируйте упаковку в руке. На манекене можно отработать полный сеанс в одиночку."
	icon = 'icons/obj/medical/bodybag.dmi'
	icon_state = "bodybag_folded"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/tattoo_mannequin/attack_self(mob/user)
	if(!user.is_holding(src) || !isopenturf(user.loc))
		return
	var/turf/spot = get_step(user, user.dir)
	if(!isopenturf(spot) || spot.is_blocked_turf() || !user.Adjacent(spot) || locate(/mob/living/carbon/human/tattoo_mannequin) in spot)
		balloon_alert(user, "нужна свободная клетка впереди")
		return
	new /mob/living/carbon/human/tattoo_mannequin(spot)
	balloon_alert(user, "манекен установлен")
	qdel(src)

/// A stationary training surface with ordinary organic limbs and a liquid reservoir.
/mob/living/carbon/human/tattoo_mannequin
	name = "учебный тату-манекен"
	real_name = "учебный тату-манекен"
	desc = "Шарнирная модель с учебной кожей и резервуаром красной жидкости. Выберите участок, протрите салфеткой и примените тату-машинку."
	move_resist = INFINITY
	visual_only_organs = TRUE

/mob/living/carbon/human/tattoo_mannequin/Initialize(mapload, datum/species/species)
	. = ..()
	AddComponent(/datum/component/examine_panel)
	add_traits(list(TRAIT_IMMOBILIZED, TRAIT_UNDENSE, TRAIT_NODISMEMBER, TRAIT_NO_SOUL, TRAIT_NO_MINDSWAP), INNATE_TRAIT)

/mob/living/carbon/human/tattoo_mannequin/setup_human_dna()
	dna.initialize_dna(create_mutation_blocks = FALSE)

/mob/living/carbon/human/tattoo_mannequin/Life(seconds_per_tick = SSMOBS_DT)
	// Only the liquid reservoir responds to punctures. The model has no metabolism.
	if(stat != DEAD && get_bleed_rate())
		handle_blood(seconds_per_tick)

/obj/item/storage/box/tattoo_studio
	name = "tattoo studio supply case"
	desc = "Органайзер с пятнадцатью флаконами пигмента. В нём по двенадцать картриджей, салфеток и защитных плёнок, а также гнездо для тату-машинки."
	icon = 'modular_bandastation/tattoo_artist/icons/studio.dmi'
	icon_state = "case"
	inhand_icon_state = "case"
	lefthand_file = 'modular_bandastation/tattoo_artist/icons/studio_l.dmi'
	righthand_file = 'modular_bandastation/tattoo_artist/icons/studio_r.dmi'
	storage_type = /datum/storage/box/tattoo_studio
	illustration = null
	foldable_result = null

/obj/item/storage/box/tattoo_studio/PopulateContents()
	for(var/i in 1 to 12)
		new /obj/item/tattoo_needle(src)
		new /obj/item/tattoo_wipe(src)
		new /obj/item/tattoo_dressing(src)
	for(var/vial_type in typesof(/obj/item/tattoo_ink))
		new vial_type(src)

/datum/storage/box/tattoo_studio
	// Twelve sets of three disposables, fifteen inks, and a slot for the machine.
	max_slots = 52
	max_total_storage = 51 * WEIGHT_CLASS_TINY + WEIGHT_CLASS_SMALL
	numerical_stacking = TRUE

/datum/storage/box/tattoo_studio/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(list(/obj/item/tattoo_machine, /obj/item/tattoo_needle, /obj/item/tattoo_wipe, /obj/item/tattoo_dressing, /obj/item/tattoo_ink))

/datum/supply_pack/misc/tattoo_studio
	name = "Расходники тату-мастера"
	desc = "Двенадцать стерильных картриджей, столько же салфеток и защитных плёнок, пятнадцать флаконов пигмента разных цветов и запасные нитриловые перчатки."
	cost = CARGO_CRATE_VALUE * 1.8
	contains = list(/obj/item/storage/box/tattoo_studio, /obj/item/clothing/gloves/latex/nitrile)
	crate_name = "ящик расходников тату-мастера"
	crate_type = /obj/structure/closet/crate/wooden
