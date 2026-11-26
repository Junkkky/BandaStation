/obj/item/encryptionkey/expedition
	name = "ключ шифрования экспедиционного корпуса"
	channels = list(RADIO_CHANNEL_EXPEDITION = 1)

/obj/item/encryptionkey/expedition/leader
	name = "ключ шифрования главы экспедиционного корпуса"
	channels = list(RADIO_CHANNEL_EXPEDITION = 1, RADIO_CHANNEL_COMMAND = 1)

// Keep the mapped headset path; its key now belongs to the independent corps.
/obj/item/radio/headset/headset_cargo/explorer
	name = "гарнитура экспедиционного корпуса"
	desc = "Гарнитура корпуса с коротковолновым режимом для связи на одном уровне без станционной сети."
	keyslot = /obj/item/encryptionkey/expedition
	subspace_switchable = TRUE

/obj/item/radio/headset/headset_cargo/explorer/leader
	name = "гарнитура главы экспедиционного корпуса"
	keyslot = /obj/item/encryptionkey/expedition/leader
	command = TRUE

/// The pilot's full-size headphones: they cover both ears and keep out the roar of the engines and the flashbangs alike
/obj/item/radio/headset/headset_cargo/explorer/pilot
	name = "лётные наушники пилота экспедиционного корпуса"
	desc = "Большие закрытые наушники пилота корпуса с коротковолновым режимом. Защищают слух от вспышек и рёва двигателей."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/gear_worn.dmi'
	icon_state = "pilot_headphones"
	worn_icon_state = "pilot_headphones"

/obj/item/radio/headset/headset_cargo/explorer/pilot/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection)
	AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
