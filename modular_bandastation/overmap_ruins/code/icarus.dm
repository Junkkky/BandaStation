/*
 * Adapted SEV Icarus layout, logs and icons/icarus*.dmi: SierraBay/Baystation contributors,
 * https://github.com/SierraBay/SierraBay12/tree/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/icarus
 * Layout/art: CC BY-SA 3.0; companion code/text: AGPL-3.0. Artwork is unmodified.
 */
/** Expedition-only ruin template for Expedition-Ruin SEV Icarus. */
/datum/map_template/ruin/space/stationtrauma_icarus
	ruin_type = "expedition_space"
	id = "stationtrauma_icarus"
	prefix = "_maps/map_files/overmap_ruins/space/"
	suffix = "icarus.dmm"
	name = "Expedition-Ruin SEV Icarus"
	description = "An airless expedition wreck with a damaged reactor and an abandoned anomaly laboratory."

/** Mapped expedition area: SEV Icarus. */
/area/ruin/space/has_grav/stationtrauma_icarus
	name = "SEV Icarus"

/** Mapped expedition area: SEV Icarus Bridge. */
/area/ruin/space/has_grav/stationtrauma_icarus/bridge
	name = "SEV Icarus Bridge"

/** Mapped expedition area: SEV Icarus Engineering. */
/area/ruin/space/has_grav/stationtrauma_icarus/eng
	name = "SEV Icarus Engineering"

/** Mapped expedition area: SEV Icarus Brig. */
/area/ruin/space/has_grav/stationtrauma_icarus/sec
	name = "SEV Icarus Brig"

/** Mapped expedition area: SEV Icarus Armory. */
/area/ruin/space/has_grav/stationtrauma_icarus/armory
	name = "SEV Icarus Armory"

/** Mapped expedition area: SEV Icarus Laboratory. */
/area/ruin/space/has_grav/stationtrauma_icarus/sci
	name = "SEV Icarus Laboratory"

/** Mapped expedition area: SEV Icarus Starboard Mass Driver. */
/area/ruin/space/has_grav/stationtrauma_icarus/driver/east
	name = "SEV Icarus Starboard Mass Driver"

/** Mapped expedition area: SEV Icarus Port Mass Driver. */
/area/ruin/space/has_grav/stationtrauma_icarus/driver/west
	name = "SEV Icarus Port Mass Driver"

/** Damaged Icarus shielding with a native radioactive emitter. */
/obj/structure/girder/stationtrauma_icarus_core
	name = "damaged reactor shielding"
	desc = "Cracked reactor shielding. The exposed remnants are radioactive."
	light_range = 6
	light_power = 0.4
	light_color = LIGHT_COLOR_GREEN

/obj/structure/girder/stationtrauma_icarus_core/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/radioactive_emitter, cooldown_time = 10 SECONDS, range = 6, threshold = RAD_MEDIUM_INSULATION)

/** Stationary native gravitational anomaly retained in the Icarus laboratory. */
/obj/effect/anomaly/grav/stationtrauma_icarus
	immortal = TRUE
	move_chance = 0
	object_launch_prob = 0

/** Recoverable authored Icarus expedition archive. */
/obj/item/disk/stationtrauma_icarus
	name = "SEV Icarus research archive"
	desc = "An encrypted archive from the lost expedition. Its label requests delivery to Expeditionary Corps Command."

/** Bridge scale model of the lost expedition ship. */
/obj/item/toy/stationtrauma_icarus_model
	name = "SEV Icarus model"
	desc = "A 1:278 scale model of the lost expedition ship."
	icon = 'modular_bandastation/overmap_ruins/icons/icarus.dmi'
	icon_state = "model"

/** Mapped radiation protection and native anomaly containment tools. */
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

/** Shielded Icarus specimen crate containing a native anomaly core. */
/obj/structure/closet/crate/stationtrauma_icarus_sample
	parent_type = /obj/structure/closet/crate/radiation
	name = "Icarus experimental specimen"
	desc = "A shielded transport crate containing a recovered anomaly core."

/obj/structure/closet/crate/stationtrauma_icarus_sample/PopulateContents()
	..()
	new /obj/item/assembly/signaler/anomaly/pyro(src)
