#define DIPLOMATIC_CLOTHING_ICON 'modular_bandastation/objects/icons/obj/clothing/representative_clothing.dmi'

/obj/item/clothing/under/diplomatic
	abstract_type = /obj/item/clothing/under/diplomatic
	icon = DIPLOMATIC_CLOTHING_ICON
	worn_icon = DIPLOMATIC_CLOTHING_ICON
	can_adjust = FALSE
	female_sprite_flags = NO_FEMALE_UNIFORM

/obj/item/clothing/under/diplomatic/skrell
	name = "Skrell imperial diplomatic uniform"
	desc = "Серебристый парадный костюм с золотыми обшлагами и перевязью через плечо."
	icon_state = "SkrellMale_Suit_Icon"
	worn_icon_state = "SkrellMale_Suit"
	inhand_icon_state = "gy_suit"

/obj/item/clothing/under/diplomatic/skrell/skirt
	name = "Skrell imperial diplomatic dress"
	desc = "Серебристое платье с золотым узором по подолу и имперской перевязью через плечо."
	icon_state = "SkrellFemale_Suit_Icon"
	worn_icon_state = "SkrellFemale_Suit"
	dying_key = DYE_REGISTRY_JUMPSKIRT
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON
	bodyshapes_with_variations = NONE

/obj/item/clothing/under/diplomatic/elysium
	name = "Elysium diplomatic uniform"
	desc = "Белая рубашка, тёмно-зелёный жилет и чёрные брюки. Золотая застёжка скрепляет полы жилета."
	icon_state = "Elysium_Costume_Icon"
	worn_icon_state = "Elysium_Costume"
	inhand_icon_state = "dg_suit"

/obj/item/clothing/under/diplomatic/free_sectors
	name = "Free Sectors diplomatic uniform"
	desc = "Песочного цвета костюм с тёмным кожаным поясом."
	icon_state = "FreeSec_Costume_Icon"
	worn_icon_state = "FreeSec_Costume"
	inhand_icon_state = "tan_suit"

/obj/item/clothing/suit/diplomatic
	abstract_type = /obj/item/clothing/suit/diplomatic
	icon = DIPLOMATIC_CLOTHING_ICON
	worn_icon = DIPLOMATIC_CLOTHING_ICON
	body_parts_covered = CHEST|GROIN|LEGS|ARMS

/obj/item/clothing/suit/diplomatic/skrell
	name = "Skrell imperial diplomatic mantle"
	desc = "Длинная имперская мантия с синими наплечниками и золотой отделкой."
	icon_state = "Skrell_Coat_Icon"
	worn_icon_state = "Skrell_Coat"
	inhand_icon_state = "b_suit"

/obj/item/clothing/suit/diplomatic/elysium
	name = "Elysium diplomatic coat"
	desc = "Длинное зелёное пальто представителя Элизиума с белым меховым воротником."
	icon_state = "Elysium_Coat_Icon"
	worn_icon_state = "Elysium_Coat"
	inhand_icon_state = "dg_suit"

/obj/item/clothing/suit/diplomatic/elysium/ceremonial
	name = "Elysium ceremonial armor coat"
	desc = "На плечи и грудь парадного пальто нашиты тёмные декоративные пластины."
	icon_state = "Elysium_ArmorCoat_Icon"
	worn_icon_state = "Elysium_ArmorCoat"

/obj/item/clothing/suit/diplomatic/free_sectors
	name = "Free Sectors diplomatic shawl"
	desc = "Плотная коричневая накидка с капюшоном. Один край перекинут через плечо."
	icon_state = "FreeSec_Coat_Icon"
	worn_icon_state = "FreeSec_Coat"
	inhand_icon_state = "det_suit"
	body_parts_covered = HEAD|CHEST|ARMS
	flags_inv = HIDEHAIR|HIDEEARS

/obj/item/clothing/head/elysium_diplomatic_cap
	name = "Elysium diplomatic cap"
	desc = "Тёмно-зелёная форменная шапочка с золотистой кокардой Доминиона."
	icon = DIPLOMATIC_CLOTHING_ICON
	worn_icon = DIPLOMATIC_CLOTHING_ICON
	icon_state = "Elysium_Head_Icon"
	worn_icon_state = "Elysium_Head"
	inhand_icon_state = "greyscale_softcap"

#undef DIPLOMATIC_CLOTHING_ICON
