/datum/uplink_item/device_tools/holster_tacticool
	name = "Tacticool Holster"
	desc = "Специальная тактическая кобура на два кармана под разного рода вооружение и прочую экипировку. То, что нужно, чтобы явиться на горячую вечеринку."
	item = /obj/item/clothing/accessory/holster/tacticool
	cost = 2
	purchasable_from = UPLINK_SERIOUS_OPS | UPLINK_SPY

/datum/uplink_item/weapon_kits/medium_cost/syndiesledge
	name = "Syndicate Breaching Sledgehammer (Hard)"
	desc = "Contains a plastitanium sledgehammer made for destruction and chaos. Great for tearing down unnecessary walls or bystanders. Comes with a welding helmet for your safety on the workplace!"
	item = /obj/item/storage/toolbox/guncase/syndiesledge
	purchasable_from = UPLINK_ALL_SYNDIE_OPS
	surplus = 0

/datum/uplink_item/dangerous/syndicate_chainsaw
	name = "Syndicate Chainsaw"
	desc = "Двуручная боевая бензопила. Заведённая пила сбивает жертву с ног, а её владелец на пять секунд получает эффект «Резня», \
		который защищает от оглушения, снижает входящий урон и помогает блокировать удары в ближнем бою. Заглушите двигатель, чтобы выпустить пилу из рук."
	item = /obj/item/chainsaw/syndie
	cost = 18
	purchasable_from = UPLINK_NUKE_OPS
	cant_discount = TRUE
	surplus = 0
