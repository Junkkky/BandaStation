/// The event's mapper corpses: forced wounds, torn-off limbs, and a body freshly killed - clothes soaked in its
/// blood and a pool under it.
/obj/effect/mob_spawn/corpse/human/gate_closure
	/// Wounds forced onto the body: body zone -> wound type.
	var/list/corpse_wounds
	/// Body zones torn off; the limbs are left lying next to the body.
	var/list/lost_limbs
	/// MALE or FEMALE: the body's gender and physique.
	var/corpse_gender = MALE

/obj/effect/mob_spawn/corpse/human/gate_closure/special(mob/living/carbon/human/spawned_human, mob/mob_possessor, apply_prefs)
	. = ..()
	for(var/zone in corpse_wounds)
		var/obj/item/bodypart/limb = spawned_human.get_bodypart(zone)
		limb?.force_wound_upwards(corpse_wounds[zone], wound_source = "event corpse")
	for(var/zone in lost_limbs)
		var/obj/item/bodypart/limb = spawned_human.get_bodypart(zone)
		limb?.dismember(silent = TRUE)
	spawned_human.gender = corpse_gender
	spawned_human.physique = corpse_gender
	spawned_human.update_body(is_creating = TRUE)

/// Clothes go on after special(), so the blood comes here.
/obj/effect/mob_spawn/corpse/human/gate_closure/equip(mob/living/carbon/human/spawned_human)
	. = ..()
	var/list/blood_dna = spawned_human.get_blood_dna_list()
	spawned_human.add_blood_DNA_to_items(blood_dna, ITEM_SLOT_ICLOTHING|ITEM_SLOT_OCLOTHING|ITEM_SLOT_GLOVES|ITEM_SLOT_HEAD|ITEM_SLOT_MASK|ITEM_SLOT_FEET)
	new /obj/effect/decal/cleanable/blood(get_turf(spawned_human), null, blood_dna)

/// Mapper corpse of a specific player doll: «Бродяга».
/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant
	parent_type = /obj/effect/mob_spawn/corpse/human/gate_closure
	name = "ивент: труп Бродяги"
	mob_name = "Бродяга"
	outfit = /datum/outfit/gate_closure_vagrant
	hairstyle = "Jensen Hair"
	haircolor = "#3D1E00"
	skin_tone = "caucasian1"

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/special(mob/living/carbon/human/spawned_human, mob/mob_possessor, apply_prefs)
	. = ..()
	spawned_human.set_mob_height(HUMAN_HEIGHT_TALL)
	var/obj/item/organ/eyes/robotic/eyes = new
	eyes.Insert(spawned_human, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	spawned_human.set_eye_color("#990099", "#990099")
	spawned_human.AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/olgierd)
	spawned_human.update_body(is_creating = TRUE)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/equip(mob/living/carbon/human/spawned_human)
	. = ..()
	// Loadout colour: the outfit only knows types, so the greyscale cape is recoloured here.
	spawned_human.wear_neck?.set_greyscale(list("#121314"))
	spawned_human.update_worn_neck()

/datum/outfit/gate_closure_vagrant
	name = "Gate Closure: Бродяга"
	uniform = /obj/item/clothing/under/rank/etamin_ind/formal
	suit = /obj/item/clothing/suit/mod
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/color/black
	neck = /obj/item/clothing/neck/robe_cape

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/bruised
	name = "ивент: труп Бродяги (лёгкие повреждения)"
	brute_damage = 30

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/battered
	name = "ивент: труп Бродяги (тяжёлые повреждения)"
	brute_damage = 90
	burn_damage = 15

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/mangled
	name = "ивент: труп Бродяги (изуродован)"
	brute_damage = 160
	burn_damage = 40
	corpse_wounds = list(
		BODY_ZONE_HEAD = /datum/wound/blunt/bone/critical,
		BODY_ZONE_CHEST = /datum/wound/slash/flesh/critical,
		BODY_ZONE_R_LEG = /datum/wound/blunt/bone/severe,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/fractures
	name = "ивент: труп Бродяги (переломы)"
	brute_damage = 70
	corpse_wounds = list(
		BODY_ZONE_CHEST = /datum/wound/blunt/bone/severe,
		BODY_ZONE_L_ARM = /datum/wound/blunt/bone/critical,
		BODY_ZONE_R_LEG = /datum/wound/blunt/bone/critical,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/lacerated
	name = "ивент: труп Бродяги (рваные раны)"
	brute_damage = 80
	corpse_wounds = list(
		BODY_ZONE_CHEST = /datum/wound/slash/flesh/critical,
		BODY_ZONE_L_ARM = /datum/wound/slash/flesh/severe,
		BODY_ZONE_R_LEG = /datum/wound/slash/flesh/moderate,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/stabbed
	name = "ивент: труп Бродяги (колотые раны)"
	brute_damage = 70
	corpse_wounds = list(
		BODY_ZONE_CHEST = /datum/wound/pierce/bleed/critical,
		BODY_ZONE_L_LEG = /datum/wound/pierce/bleed/severe,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/burned
	name = "ивент: труп Бродяги (ожоги)"
	burn_damage = 150
	corpse_wounds = list(
		BODY_ZONE_CHEST = /datum/wound/burn/flesh/critical,
		BODY_ZONE_R_ARM = /datum/wound/burn/flesh/severe,
		BODY_ZONE_HEAD = /datum/wound/burn/flesh/moderate,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/dismembered
	name = "ивент: труп Бродяги (оторваны рука и нога)"
	brute_damage = 120
	corpse_wounds = list(BODY_ZONE_CHEST = /datum/wound/slash/flesh/critical)
	lost_limbs = list(BODY_ZONE_L_ARM, BODY_ZONE_R_LEG)

/// CentCom fleet officers killed on the event: the men in the formal suit, badged berets, wounds and blood.
/datum/outfit/gate_closure_centcom
	name = "Gate Closure: офицер флота ЦК"
	uniform = /obj/item/clothing/under/rank/centcom/official
	shoes = /obj/item/clothing/shoes/jackboots/centcom
	head = /obj/item/clothing/head/beret/centcom

/datum/outfit/gate_closure_centcom/hel
	name = "Gate Closure: Хель Кириэн"
	uniform = /obj/item/clothing/under/rank/centcom/dress

/datum/outfit/gate_closure_centcom/maria
	name = "Gate Closure: Мария Карлайл"
	uniform = /obj/item/clothing/under/rank/centcom/centcom_skirt

/obj/effect/mob_spawn/corpse/human/gate_closure/centcom
	outfit = /datum/outfit/gate_closure_centcom
	skin_tone = "caucasian1"
	brute_damage = 100

/obj/effect/mob_spawn/corpse/human/gate_closure/centcom/hel
	name = "ивент: труп Хель Кириэн"
	mob_name = "Хель Кириэн"
	outfit = /datum/outfit/gate_closure_centcom/hel
	corpse_gender = FEMALE
	facial_hairstyle = "Shaved"
	hairstyle = "Ponytail (Spiky)"
	haircolor = "#C8501E"
	corpse_wounds = list(BODY_ZONE_CHEST = /datum/wound/pierce/bleed/critical)

/// Red hair fading to yellow at the tips; mob_spawn only knows plain hair colours.
/obj/effect/mob_spawn/corpse/human/gate_closure/centcom/hel/special(mob/living/carbon/human/spawned_human, mob/mob_possessor, apply_prefs)
	. = ..()
	spawned_human.set_hair_gradient_style("Fade Up", update = FALSE)
	spawned_human.set_hair_gradient_color("#F0C83C")

/obj/effect/mob_spawn/corpse/human/gate_closure/centcom/maria
	name = "ивент: труп Марии Карлайл"
	mob_name = "Мария Карлайл"
	outfit = /datum/outfit/gate_closure_centcom/maria
	corpse_gender = FEMALE
	facial_hairstyle = "Shaved"
	hairstyle = "Beehive"
	haircolor = "#C8C8C8"
	corpse_wounds = list(
		BODY_ZONE_CHEST = /datum/wound/slash/flesh/critical,
		BODY_ZONE_L_ARM = /datum/wound/slash/flesh/severe,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure/centcom/edward
	name = "ивент: труп Эдварда Клейма"
	mob_name = "Эдвард Клейм"
	hairstyle = "Business Hair"
	haircolor = "#4A2A12"
	facial_hairstyle = "Beard (Volaju)"
	facial_haircolor = "#4A2A12"
	corpse_wounds = list(
		BODY_ZONE_HEAD = /datum/wound/blunt/bone/critical,
		BODY_ZONE_CHEST = /datum/wound/slash/flesh/severe,
	)

/obj/effect/mob_spawn/corpse/human/gate_closure/centcom/austin
	name = "ивент: труп Остина Миллера"
	mob_name = "Остин Миллер"
	hairstyle = "Gelled Back"
	haircolor = "#4A2A12"
	facial_hairstyle = "Beard (Volaju)"
	facial_haircolor = "#4A2A12"
	corpse_wounds = list(
		BODY_ZONE_CHEST = /datum/wound/slash/flesh/critical,
		BODY_ZONE_R_LEG = /datum/wound/pierce/bleed/severe,
	)
