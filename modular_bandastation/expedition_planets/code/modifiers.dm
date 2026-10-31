// Budgeted planet modifiers follow CrystallEdge's demiplane modifier selection; no donor code is copied.
// https://github.com/crystallpunk-14/crystall-punk-14/blob/5b6108377e40235c768be3ac6ffadb37a085f441/Content.Server/_CP14/Demiplane/CP14DemiplaneSystem.cs

#define PLANET_MODIFIER_DANGER "danger"
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

/** Whether this modifier means anything for the generator's environment profile. */
/datum/expedition_planet_modifier/proc/can_apply(datum/map_generator/expedition_barren/generator)
	return TRUE

/datum/expedition_planet_modifier/rich_ore
	name = "Богатые рудные жилы"
	group = "ore"
	category = PLANET_MODIFIER_REWARD
	cost = 1
	ore_multiplier = 1.5

/datum/expedition_planet_modifier/very_rich_ore
	name = "Исключительно богатые рудные жилы"
	group = "ore"
	category = PLANET_MODIFIER_REWARD
	cost = 2
	probability = 25
	ore_multiplier = 2

/datum/expedition_planet_modifier/poor_ore
	name = "Истощённые рудные жилы"
	group = "ore"
	category = PLANET_MODIFIER_REWARD
	probability = 25
	ore_multiplier = 0.5

/datum/expedition_planet_modifier/predators
	name = "Многочисленная фауна"
	group = "fauna"
	cost = 1
	fauna_multiplier = 2

/datum/expedition_planet_modifier/predators/can_apply(datum/map_generator/expedition_barren/generator)
	return generator.wildlife

/datum/expedition_planet_modifier/calm
	name = "Редкая фауна"
	group = "fauna"
	probability = 25
	fauna_multiplier = 0.3

/datum/expedition_planet_modifier/calm/can_apply(datum/map_generator/expedition_barren/generator)
	return generator.wildlife

/datum/expedition_planet_modifier/storms
	name = "Периодические штормы"
	group = "weather"
	cost = 0.5
	probability = 60
	storms = TRUE

/datum/expedition_planet_modifier/storms/can_apply(datum/map_generator/expedition_barren/generator)
	return !!generator.storm_trait

/datum/expedition_planet_modifier/caves
	name = "Пещерная система"
	group = "underground"
	category = PLANET_MODIFIER_REWARD
	cost = 0.5
	probability = 40
	underground = TRUE

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
		underground ||= modifier.underground
		names += modifier.name
	return names

#undef PLANET_MODIFIER_DANGER
#undef PLANET_MODIFIER_REWARD
