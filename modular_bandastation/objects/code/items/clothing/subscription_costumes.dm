/obj/item/clothing/under/costume/subscription
	abstract_type = /obj/item/clothing/under/costume/subscription
	icon = 'modular_bandastation/objects/icons/obj/clothing/subscription_costumes.dmi'
	worn_icon = 'modular_bandastation/objects/icons/mob/clothing/subscription_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/subscription_costumes_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/subscription_costumes_right.dmi'
	armor_type = /datum/armor/clothing_under/primera
	can_adjust = FALSE
	female_sprite_flags = NO_FEMALE_UNIFORM
	supports_variations_flags = CLOTHING_DIGITIGRADE_MASK|CLOTHING_CERULEAN_MASK_LEGS
	bodyshapes_with_variations = BODYSHAPE_DIGITIGRADE|BODYSHAPE_CERULEAN
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/subscription/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/subscription/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/subscription/drask.dmi',
	)

/obj/item/clothing/under/costume/subscription/generate_digitigrade_icons(icon/base_icon, greyscale_colors)
	// Preserve the original fabric patterns and use the shared silhouette for dresses.
	if(icon_exists('modular_bandastation/objects/icons/mob/clothing/subscription/digitigrade.dmi', icon_state))
		return icon('modular_bandastation/objects/icons/mob/clothing/subscription/digitigrade.dmi', icon_state)
	return base_icon

/obj/item/clothing/under/costume/subscription/generate_cerulean_icons(icon/base_icon, key, greyscale_colors, bodyshape)
	if(icon_exists('modular_bandastation/objects/icons/mob/clothing/subscription/cerulean.dmi', icon_state))
		return icon('modular_bandastation/objects/icons/mob/clothing/subscription/cerulean.dmi', icon_state)
	return ..()

/obj/item/clothing/under/costume/subscription/black_scarlet_dress
	name = "black-and-scarlet dress"
	desc = "Длинное чёрное платье с бордовыми рукавами, белым воротником и нагрудником."
	icon_state = "black_scarlet_dress"

/obj/item/clothing/under/costume/subscription/black_strap_dress
	name = "black strappy dress"
	desc = "Приталенное чёрное платье на тонких бретелях с асимметричным подолом."
	icon_state = "black_strap_dress"
	body_parts_covered = CHEST|GROIN

/obj/item/clothing/under/costume/subscription/anime_dress
	name = "anime dress"
	desc = "Розовое платье с пышными белыми рукавами, оборками и бантом на талии."
	icon_state = "anime_dress"
	body_parts_covered = CHEST|GROIN|ARMS

/obj/item/clothing/under/costume/subscription/gothic_dress
	name = "gothic dress"
	desc = "Длинное чёрное платье с приталенным лифом и сетчатыми вставками по бокам."
	icon_state = "gothic_dress"
	body_parts_covered = CHEST|GROIN|LEGS

/obj/item/clothing/under/costume/subscription/spongebob_uniform
	name = "spongebob uniform"
	desc = "Белая рубашка с красным галстуком и коричневые шорты."
	icon_state = "spongebob_uniform"
	body_parts_covered = CHEST|GROIN

/obj/item/clothing/under/costume/subscription/patrick_shorts
	name = "patrick shorts"
	desc = "Зелёные шорты с фиолетовым узором."
	icon_state = "patrick_shorts"
	body_parts_covered = GROIN

/obj/item/clothing/under/costume/subscription/woodcutter_uniform
	name = "woodcutter outfit"
	desc = "Тёмная футболка и коричневые рабочие штаны."
	icon_state = "woodcutter_uniform"
	body_parts_covered = CHEST|GROIN|LEGS

/obj/item/clothing/under/costume/subscription/black_tracksuit
	name = "black tracksuit"
	desc = "Чёрная олимпийка и спортивные штаны с белыми полосами."
	icon_state = "black_tracksuit"

/obj/item/clothing/suit/costume/subscription
	abstract_type = /obj/item/clothing/suit/costume/subscription
	icon = 'modular_bandastation/objects/icons/obj/clothing/subscription_costumes.dmi'
	worn_icon = 'modular_bandastation/objects/icons/mob/clothing/subscription_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/subscription_costumes_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/subscription_costumes_right.dmi'
	allowed = list()
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON|CLOTHING_CERULEAN_MASK_INBETWEEN
	bodyshapes_with_variations = BODYSHAPE_CERULEAN
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/subscription/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/subscription/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/subscription/drask.dmi',
		SPECIES_VULPKANIN = 'modular_bandastation/objects/icons/mob/clothing/subscription/vulpkanin.dmi',
		SPECIES_TAJARAN = 'modular_bandastation/objects/icons/mob/clothing/subscription/tajaran.dmi',
	)

/obj/item/clothing/suit/costume/subscription/woodcutter_shirt
	name = "woodcutter plaid shirt"
	desc = "Красная клетчатая рубашка, которую можно носить нараспашку поверх футболки."
	icon_state = "woodcutter_shirt"
	body_parts_covered = CHEST|ARMS

/obj/item/clothing/suit/costume/subscription/mascot
	abstract_type = /obj/item/clothing/suit/costume/subscription/mascot
	body_parts_covered = HEAD|CHEST|GROIN|ARMS|LEGS|HANDS|FEET
	// Cover the underlying outfit while keeping headgear visible on examine.
	flags_inv = HIDEJUMPSUIT|HIDESHOES|HIDEGLOVES|HIDEHAIR|HIDEFACIALHAIR|HIDESNOUT
	alternate_worn_layer = UNDER_HEAD_LAYER
	supports_variations_flags = CLOTHING_DIGITIGRADE_MASK|CLOTHING_CERULEAN_MASK_LEGS
	bodyshapes_with_variations = BODYSHAPE_DIGITIGRADE|BODYSHAPE_CERULEAN

/obj/item/clothing/suit/costume/subscription/mascot/generate_digitigrade_icons(icon/base_icon, greyscale_colors)
	// Fitted species overlays already include their own leg shape.
	var/mob/living/carbon/human/wearer = loc
	if(ishuman(wearer) && get_species_worn_icon(wearer.get_bodypart(BODY_ZONE_CHEST)?.limb_id, slot_id = ITEM_SLOT_OCLOTHING))
		return base_icon
	return icon('modular_bandastation/objects/icons/mob/clothing/subscription/digitigrade.dmi', icon_state)

/obj/item/clothing/suit/costume/subscription/mascot/generate_cerulean_icons(icon/base_icon, key, greyscale_colors, bodyshape)
	return icon('modular_bandastation/objects/icons/mob/clothing/subscription/cerulean.dmi', icon_state)

/obj/item/clothing/suit/costume/subscription/mascot/spongebob
	name = "spongebob mascot costume"
	desc = "Ростовой костюм Губки Боба с большой квадратной головой и чёрными ботинками."
	icon_state = "spongebob_mascot"

/obj/item/clothing/suit/costume/subscription/mascot/patrick
	name = "patrick mascot costume"
	desc = "Ростовой костюм Патрика, розовой морской звезды в зелёных шортах."
	icon_state = "patrick_mascot"

/obj/item/clothing/head/costume/subscription_black_cap
	name = "black cap"
	desc = "Низкая чёрная кепка с коротким козырьком."
	icon = 'modular_bandastation/objects/icons/obj/clothing/subscription_costumes.dmi'
	worn_icon = 'modular_bandastation/objects/icons/mob/clothing/subscription_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/subscription_costumes_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/subscription_costumes_right.dmi'
	icon_state = "black_cap"
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/subscription/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/subscription/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/subscription/drask.dmi',
		SPECIES_VULPKANIN = 'modular_bandastation/objects/icons/mob/clothing/subscription/vulpkanin.dmi',
		SPECIES_TAJARAN = 'modular_bandastation/objects/icons/mob/clothing/subscription/tajaran.dmi',
	)
