/*
 * Adapted SEV Icarus layout, logs and icons/icarus*.dmi: SierraBay/Baystation contributors,
 * https://github.com/SierraBay/SierraBay12/tree/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/icarus
 * Layout/art: CC BY-SA 3.0; companion code/text: AGPL-3.0. Artwork is unmodified.
 * Adapted Abandoned Mining Operation layout: Voidcrew/Whitesands/TG contributors,
 * https://github.com/Void-Crew/Voidcrew-LRP/blob/66c552922bf2a28963c2a8f5d89993623a141a1f/voidcrew/_maps/RandomRuins/SpaceRuins/scav_mining.dmm
 * CC BY-SA 3.0: https://creativecommons.org/licenses/by-sa/3.0/
 * Both retain their rooms; incompatible machinery/items/inhabitants use local TG types.
 */
/datum/map_template/ruin/space/stationtrauma_icarus
	id = "stationtrauma_icarus"
	prefix = "modular_bandastation/space_overmap/maps/ruins/"
	suffix = "icarus.dmm"
	name = "Expedition-Ruin SEV Icarus"
	description = "An airless expedition wreck with a damaged reactor and an abandoned anomaly laboratory."

/datum/map_template/ruin/space/stationtrauma_scav_mining
	id = "stationtrauma_scav_mining"
	prefix = "modular_bandastation/space_overmap/maps/ruins/"
	suffix = "scav_mining.dmm"
	name = "Expedition-Ruin Abandoned Mining Base"
	description = "A mining asteroid with salvageable equipment, ore deposits and hostile inhabitants."

/area/ruin/space/has_grav/stationtrauma_icarus
	name = "SEV Icarus"

/area/ruin/space/has_grav/stationtrauma_icarus/bridge
	name = "SEV Icarus Bridge"

/area/ruin/space/has_grav/stationtrauma_icarus/eng
	name = "SEV Icarus Engineering"

/area/ruin/space/has_grav/stationtrauma_icarus/sec
	name = "SEV Icarus Brig"

/area/ruin/space/has_grav/stationtrauma_icarus/armory
	name = "SEV Icarus Armory"

/area/ruin/space/has_grav/stationtrauma_icarus/sci
	name = "SEV Icarus Laboratory"

/area/ruin/space/has_grav/stationtrauma_icarus/driver/east
	name = "SEV Icarus Starboard Mass Driver"

/area/ruin/space/has_grav/stationtrauma_icarus/driver/west
	name = "SEV Icarus Port Mass Driver"

/area/ruin/space/has_grav/stationtrauma_scav_mining/core
	name = "Abandoned Mine Operations"

/area/ruin/space/has_grav/stationtrauma_scav_mining/dorm
	name = "Abandoned Mine Dormitory"

/area/ruin/space/has_grav/stationtrauma_scav_mining/entrance
	name = "Abandoned Mine Airlock"

/obj/structure/girder/stationtrauma_icarus_core
	name = "damaged reactor shielding"
	desc = "Cracked reactor shielding. The exposed remnants are radioactive."
	light_range = 6
	light_power = 0.4
	light_color = LIGHT_COLOR_GREEN

/obj/structure/girder/stationtrauma_icarus_core/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/radioactive_emitter, cooldown_time = 10 SECONDS, range = 6, threshold = RAD_MEDIUM_INSULATION)

/obj/effect/anomaly/grav/stationtrauma_icarus
	immortal = TRUE
	move_chance = 0
	object_launch_prob = 0

/obj/item/disk/stationtrauma_icarus
	name = "SEV Icarus research archive"
	desc = "An encrypted archive from the lost expedition. Its label requests delivery to Expeditionary Corps Command."

/obj/structure/closet/crate/stationtrauma_icarus_tools
	name = "anomaly containment equipment"
	desc = "An analyzer and a signaler for identifying and neutralizing an anomaly. Match the signaler frequency and code to the analyzer readings."
	anchored = TRUE

/obj/structure/closet/crate/stationtrauma_icarus_tools/PopulateContents()
	..()
	new /obj/item/analyzer(src)
	new /obj/item/assembly/signaler(src)
	new /obj/item/geiger_counter(src)
	new /obj/item/clothing/suit/utility/radiation(src)
	new /obj/item/clothing/head/utility/radiation(src)

/obj/structure/closet/crate/stationtrauma_icarus_sample
	parent_type = /obj/structure/closet/crate/radiation
	name = "Icarus experimental specimen"
	desc = "A shielded transport crate containing a recovered anomaly core."

/obj/structure/closet/crate/stationtrauma_icarus_sample/PopulateContents()
	..()
	new /obj/item/assembly/signaler/anomaly/pyro(src)
