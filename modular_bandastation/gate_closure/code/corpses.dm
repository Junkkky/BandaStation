/// Mapper corpse of a specific player doll: «Бродяга».
/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant
	name = "ивент: труп Бродяги"
	mob_name = "Бродяга"
	outfit = /datum/outfit/gate_closure_vagrant
	hairstyle = "Jensen Hair"
	haircolor = "#3D1E00"
	skin_tone = "caucasian1"
	/// Wounds forced onto the body: body zone -> wound type.
	var/list/corpse_wounds
	/// Body zones torn off; the limbs are left lying next to the body.
	var/list/lost_limbs

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/special(mob/living/carbon/human/spawned_human, mob/mob_possessor, apply_prefs)
	. = ..()
	for(var/zone in corpse_wounds)
		var/obj/item/bodypart/limb = spawned_human.get_bodypart(zone)
		limb?.force_wound_upwards(corpse_wounds[zone], wound_source = "event corpse")
	for(var/zone in lost_limbs)
		var/obj/item/bodypart/limb = spawned_human.get_bodypart(zone)
		limb?.dismember(silent = TRUE)
	spawned_human.gender = MALE
	spawned_human.physique = MALE
	spawned_human.set_mob_height(HUMAN_HEIGHT_TALL)
	var/obj/item/organ/eyes/robotic/eyes = new
	eyes.Insert(spawned_human, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	spawned_human.set_eye_color("#990099", "#990099")
	spawned_human.AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/olgierd)
	spawned_human.update_body(is_creating = TRUE)

/obj/effect/mob_spawn/corpse/human/gate_closure_vagrant/equip(mob/living/carbon/human/spawned_human)
	. = ..()
	// Loadout colours: the outfit only knows types, so the greyscale garments are recoloured here.
	spawned_human.wear_suit?.set_greyscale(list("#1C1D1D"))
	spawned_human.wear_neck?.set_greyscale(list("#121314"))
	spawned_human.update_worn_oversuit()
	spawned_human.update_worn_neck()

/datum/outfit/gate_closure_vagrant
	name = "Gate Closure: Бродяга"
	uniform = /obj/item/clothing/under/rank/etamin_ind/formal
	suit = /obj/item/clothing/suit/toggle/jacket/trenchcoat
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
