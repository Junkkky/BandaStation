/obj/structure/closet/wardrobe/expedition
	name = "гардероб экспедиционного корпуса"
	desc = "Полный комплект полевой одежды экспедиционного корпуса Нанотрейзен."
	icon_door = "green"
	storage_capacity = 80

/obj/structure/closet/wardrobe/expedition/PopulateContents()
	generate_items_inside(list(
		/obj/item/clothing/under/expedition = 7,
		/obj/item/clothing/under/expedition/leader = 7,
		/obj/item/clothing/under/expedition/pilot = 7,
		/obj/item/clothing/under/expedition/engineer = 7,
		/obj/item/clothing/shoes/jackboots/expedition = 7,
		/obj/item/clothing/gloves/color/black/expedition = 7,
		/obj/item/clothing/suit/toggle/expedition = 7,
		/obj/item/clothing/accessory/expedition_webbing = 7,
		/obj/item/clothing/accessory/expedition_sheath = 7,
		/obj/item/storage/belt/expedition_sheath = 7,
		/obj/item/clothing/head/helmet/expedition_pilot = 1,
	), src)
