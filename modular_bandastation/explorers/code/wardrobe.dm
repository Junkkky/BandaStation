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

/// The corps wardrobe as a vending machine: free spare clothes and carrying gear for the corps.
/obj/machinery/vending/wardrobe/expedition_wardrobe
	name = "ExpeDrobe"
	desc = "Автомат с полевой одеждой и снаряжением экспедиционного корпуса Нанотрейзен."
	icon_state = "scidrobe"
	product_ads = "Полевая форма для любой планеты!;Ножны и разгрузка — не забудьте перед вылазкой!"
	vend_reply = "Удачной экспедиции!"
	all_products_free = TRUE
	products = list(
		/obj/item/clothing/under/expedition = 3,
		/obj/item/clothing/under/expedition/leader = 3,
		/obj/item/clothing/under/expedition/pilot = 3,
		/obj/item/clothing/under/expedition/engineer = 3,
		/obj/item/clothing/shoes/jackboots/expedition = 4,
		/obj/item/clothing/gloves/color/black/expedition = 4,
		/obj/item/clothing/suit/toggle/expedition = 4,
		/obj/item/clothing/accessory/expedition_webbing = 7,
		/obj/item/clothing/accessory/expedition_sheath = 7,
		/obj/item/storage/belt/expedition_sheath = 7,
		/obj/item/clothing/head/helmet/expedition_pilot = 2,
	)
	refill_canister = /obj/item/vending_refill/wardrobe/expedition_wardrobe

/obj/item/vending_refill/wardrobe/expedition_wardrobe
	machine_name = "ExpeDrobe"
