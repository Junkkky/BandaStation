// Budgeted planet modifiers follow CrystallEdge's demiplane modifier selection; no donor code is copied.
// https://github.com/crystallpunk-14/crystall-punk-14/blob/5b6108377e40235c768be3ac6ffadb37a085f441/Content.Server/_CP14/Demiplane/CP14DemiplaneSystem.cs

/// Budget category of modifiers that make a planet harder.
#define PLANET_MODIFIER_DANGER "danger"
/// Budget category of modifiers that make a planet richer.
#define PLANET_MODIFIER_REWARD "reward"

/**
 * Random planetary trait rolled before terrain generation and reported by the environmental survey.
 *
 * Each modifier is offered with its own probability, costs points from its category budget and excludes
 * other modifiers of the same group.
 */
/datum/expedition_planet_modifier
	/// Crew-facing survey line.
	var/name
	/// Only one modifier of a group applies to a planet.
	var/group
	/// Budget category paying [/datum/expedition_planet_modifier/var/cost].
	var/category = PLANET_MODIFIER_DANGER
	/// Budget points spent; zero-cost modifiers fit any planet.
	var/cost = 0
	/// Percent chance that this modifier is offered to a planet at all.
	var/probability = 50
	/// Multiplier for the profile's ore vein seed chance.
	var/ore_multiplier = 1
	/// Multiplier for every biome's fauna density on this planet.
	var/fauna_multiplier = 1
	/// Whether the profile's periodic storm weather is enabled on this planet.
	var/storms = FALSE
	/// Whether this planet gains a richer cave level beneath its surface.
	var/underground = FALSE
	/// Whether the profile's storm rages without pause instead of alternating with calm periods.
	var/endless_storm = FALSE
	/// Base light alpha of the open surface in the profile's sky colour; zero keeps the surface dark.
	var/light_alpha = 0
	/// Object placed on the open surface away from the camp, or a list to pick each one from.
	var/nest_type
	/// Lowest and highest number of [/datum/expedition_planet_modifier/var/nest_type] placed.
	var/list/nest_count = list(1, 2)
	/// Radius of the patch every placed object shares around the first one; zero scatters them over the whole surface.
	var/nest_cluster = 0

/** Whether this modifier means anything for the generator's environment profile. */
/datum/expedition_planet_modifier/proc/can_apply(datum/map_generator/expedition_barren/generator)
	return TRUE

/// Reward: ore veins seed half as often again.
/datum/expedition_planet_modifier/rich_ore
	name = "Богатые рудные жилы"
	group = "ore"
	category = PLANET_MODIFIER_REWARD
	cost = 1
	ore_multiplier = 1.5

/// Reward: ore veins seed twice as often.
/datum/expedition_planet_modifier/very_rich_ore
	name = "Исключительно богатые рудные жилы"
	group = "ore"
	category = PLANET_MODIFIER_REWARD
	cost = 2
	probability = 25
	ore_multiplier = 2

/// Free: ore veins seed half as often.
/datum/expedition_planet_modifier/poor_ore
	name = "Истощённые рудные жилы"
	group = "ore"
	category = PLANET_MODIFIER_REWARD
	probability = 25
	ore_multiplier = 0.5

/// Danger: twice the profile fauna; only on profiles with wildlife.
/datum/expedition_planet_modifier/predators
	name = "Многочисленная фауна"
	group = "fauna"
	cost = 1
	fauna_multiplier = 2

/datum/expedition_planet_modifier/predators/can_apply(datum/map_generator/expedition_barren/generator)
	return generator.wildlife

/// Free: a third of the profile fauna; only on profiles with wildlife.
/datum/expedition_planet_modifier/calm
	name = "Редкая фауна"
	group = "fauna"
	probability = 25
	fauna_multiplier = 0.3

/datum/expedition_planet_modifier/calm/can_apply(datum/map_generator/expedition_barren/generator)
	return generator.wildlife

/// Danger: the profile storm weather comes and goes; only on profiles with a storm.
/datum/expedition_planet_modifier/storms
	name = "Периодические штормы"
	group = "weather"
	cost = 0.5
	probability = 60
	storms = TRUE

/datum/expedition_planet_modifier/storms/can_apply(datum/map_generator/expedition_barren/generator)
	return !!generator.storm_trait

/// Danger: the profile storm never stops; only on profiles with an endless storm variant.
/datum/expedition_planet_modifier/endless_storm
	name = "Непрекращающийся шторм"
	group = "weather"
	cost = 1
	probability = 20
	endless_storm = TRUE

/datum/expedition_planet_modifier/endless_storm/can_apply(datum/map_generator/expedition_barren/generator)
	return !!generator.endless_storm_type

/// Reward: a cave level with extra features beneath the surface.
/datum/expedition_planet_modifier/caves
	name = "Пещерная система"
	group = "underground"
	category = PLANET_MODIFIER_REWARD
	cost = 0.5
	probability = 40
	underground = TRUE

/// Danger: one or two spawners on the open surface; biome nests belong to their own profiles.
/datum/expedition_planet_modifier/nest
	group = "nest"
	cost = 1
	probability = 0
	/// Generator profile types this nest fits; empty fits every profile.
	var/list/profiles
	/// Whether only the bare barren profile fits, not the profiles derived from it.
	var/barren_only = FALSE

/datum/expedition_planet_modifier/nest/can_apply(datum/map_generator/expedition_barren/generator)
	if(barren_only)
		return generator.type == /datum/map_generator/expedition_barren
	if(!length(profiles))
		return TRUE
	for(var/profile in profiles)
		if(istype(generator, profile))
			return TRUE
	return FALSE

/// A xenomorph egg cluster hatches hunters until it is torn down.
/datum/expedition_planet_modifier/nest/xeno_hive
	name = "Улей ксеноморфов"
	probability = 15
	nest_type = /obj/structure/spawner/stationtrauma_xeno_hive

/// A plague pit raises the dead until it is filled in.
/datum/expedition_planet_modifier/nest/zombie_pit
	name = "Очаг заражения"
	probability = 15
	nest_type = /obj/structure/spawner/stationtrauma_zombie_pit

/// Wolf packs den in cave mouths that hold a little ore.
/datum/expedition_planet_modifier/nest/wolf_dens
	name = "Волчьи логова"
	probability = 30
	profiles = list(/datum/map_generator/expedition_barren/frozen)
	nest_type = /obj/structure/spawner/ice_moon

/// A polar bear guards each den.
/datum/expedition_planet_modifier/nest/bear_dens
	name = "Берлоги полярных медведей"
	probability = 25
	profiles = list(/datum/map_generator/expedition_barren/frozen)
	nest_type = /obj/structure/spawner/ice_moon/polarbear

/// A netheric rift spits ice demons until it collapses.
/datum/expedition_planet_modifier/nest/demonic_rift
	name = "Демонический разлом"
	cost = 2
	probability = 15
	profiles = list(/datum/map_generator/expedition_barren/frozen)
	nest_type = /obj/structure/spawner/ice_moon/demonic_portal

/// Ancient goliaths burrow in the ash.
/datum/expedition_planet_modifier/nest/goliath_dens
	name = "Гнёзда голиафов"
	probability = 30
	profiles = list(/datum/map_generator/expedition_barren/lava)
	nest_type = /obj/structure/spawner/mining/goliath

/// Hivelords bud from their colonies.
/datum/expedition_planet_modifier/nest/hivelord_colony
	name = "Колонии роевиков"
	probability = 25
	profiles = list(/datum/map_generator/expedition_barren/lava)
	nest_type = /obj/structure/spawner/mining/hivelord

/// Basilisks lair in the sun-baked rock.
/datum/expedition_planet_modifier/nest/basilisk_lairs
	name = "Логова василисков"
	probability = 30
	profiles = list(/datum/map_generator/expedition_barren/arid)
	nest_type = /obj/structure/spawner/mining/basilisk

/// Reward: a stable bluespace anomaly whose core a signaller tuned to it frees for the bluespace drive.
/datum/expedition_planet_modifier/bluespace_anomaly
	name = "Блюспейс-аномалия"
	group = "anomaly"
	category = PLANET_MODIFIER_REWARD
	cost = 1
	probability = 20
	nest_type = /obj/effect/anomaly/bluespace/stationtrauma
	nest_count = list(1, 1)

/// Danger: a patch of light explosive mines left by an old war.
/datum/expedition_planet_modifier/minefield
	name = "Брошенное минное поле"
	group = "hazard"
	cost = 1
	probability = 20
	nest_type = /obj/effect/mine/explosive/light
	nest_count = list(10, 16)
	nest_cluster = 8

/// Reward: chemical geysers for plumbing.
/datum/expedition_planet_modifier/geysers
	name = "Химические гейзеры"
	group = "geysers"
	category = PLANET_MODIFIER_REWARD
	cost = 0.5
	probability = 30
	nest_type = list(/obj/structure/geyser/wittel, /obj/structure/geyser/plasma_oxide, /obj/structure/geyser/protozine, /obj/structure/geyser/hollowwater)
	nest_count = list(2, 3)

/// The dead of a forgotten expedition climb out of their pit.
/datum/expedition_planet_modifier/nest/bone_pit
	name = "Костяная яма"
	probability = 30
	barren_only = TRUE
	nest_type = /obj/structure/spawner/skeleton/stationtrauma

/// Free: the open surface is lit strongly in the profile sky colour.
/datum/expedition_planet_modifier/bright_day
	name = "Яркое светило"
	group = "light"
	probability = 30
	// TG's bright day station trait lights the icemoon wastes this strongly.
	light_alpha = 145

/// Free: the open surface is lit dimly in the profile sky colour.
/datum/expedition_planet_modifier/twilight
	name = "Тусклое светило"
	group = "light"
	probability = 40
	light_alpha = 60

/**
 * Roll offered modifiers in random order and apply those that fit the remaining budgets.
 *
 * Both budgets are half of `level`, so distant planets afford stronger rewards and dangers.
 * Returns the survey names of the applied modifiers.
 */
/datum/map_generator/expedition_barren/proc/apply_modifiers(level)
	var/static/list/datum/expedition_planet_modifier/modifiers
	if(!modifiers)
		modifiers = list()
		for(var/modifier_type in subtypesof(/datum/expedition_planet_modifier))
			modifiers += new modifier_type
	var/list/budget = list(PLANET_MODIFIER_DANGER = level / 2, PLANET_MODIFIER_REWARD = level / 2)
	var/list/offered = list()
	for(var/datum/expedition_planet_modifier/modifier as anything in modifiers)
		if(prob(modifier.probability) && modifier.can_apply(src))
			offered += modifier
	var/list/used_groups = list()
	var/list/names = list()
	while(length(offered))
		var/datum/expedition_planet_modifier/modifier = pick_n_take(offered)
		if((modifier.group in used_groups) || modifier.cost > budget[modifier.category])
			continue
		budget[modifier.category] -= modifier.cost
		used_groups += modifier.group
		mineral_chance *= modifier.ore_multiplier
		fauna_multiplier *= modifier.fauna_multiplier
		storms ||= modifier.storms
		endless_storm ||= modifier.endless_storm
		underground ||= modifier.underground
		light_alpha = max(light_alpha, modifier.light_alpha)
		if(modifier.nest_type)
			nests += modifier
		names += modifier.name
	return names

#undef PLANET_MODIFIER_DANGER
#undef PLANET_MODIFIER_REWARD
