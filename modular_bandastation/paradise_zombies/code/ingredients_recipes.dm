/** Instant donor recipes for the otherwise unavailable research ingredients. */
/datum/chemical_reaction/paradise_ingredient
	abstract_type = /datum/chemical_reaction/paradise_ingredient
	reaction_flags = REACTION_INSTANT|REACTION_IGNORE_PURITY
	required_temp = 0

/** The shared Lazarus recipe keeps its original instant, purity-independent yield. */
/datum/chemical_reaction/medicine/strange_reagent
	reaction_flags = REACTION_INSTANT|REACTION_IGNORE_PURITY
	required_temp = 0

/datum/chemical_reaction/paradise_ingredient/teporone
	results = list(/datum/reagent/medicine/paradise_teporone = 2)
	required_reagents = list(/datum/reagent/acetone = 1, /datum/reagent/silicon = 1, /datum/reagent/toxin/plasma = 1)
	mix_message = "The mixture turns an odd lavender color."

/datum/chemical_reaction/paradise_ingredient/charcoal
	// The shared reactants select Charcoal at 1:5 and native Multiver at lower salt ratios.
	reaction_flags = REACTION_INSTANT|REACTION_IGNORE_PURITY|REACTION_COMPETITIVE
	results = list(/datum/reagent/medicine/paradise_charcoal = 6)
	required_reagents = list(/datum/reagent/ash = 1, /datum/reagent/consumable/salt = 5)
	required_temp = T0C + 100
	mix_message = "The mixture yields a fine black powder."

/datum/chemical_reaction/paradise_ingredient/charcoal/pre_reaction_other_checks(datum/reagents/holder)
	if(!..())
		return FALSE
	for(var/datum/equilibrium/active as anything in holder.reaction_list)
		if(istype(active.reaction, /datum/chemical_reaction/medicine/multiver))
			return FALSE
	var/ash = holder.get_reagent_amount(/datum/reagent/ash)
	return ash > 0 && holder.get_reagent_amount(/datum/reagent/consumable/salt) >= 5 * ash

/datum/chemical_reaction/medicine/multiver/pre_reaction_other_checks(datum/reagents/holder)
	if(!..())
		return FALSE
	var/ash = holder.get_reagent_amount(/datum/reagent/ash)
	return ash <= 0 || holder.get_reagent_amount(/datum/reagent/consumable/salt) < 5 * ash

/datum/chemical_reaction/ammonia/pre_reaction_other_checks(datum/reagents/holder)
	if(!..())
		return FALSE
	return !(holder.has_reagent(/datum/reagent/chlorine, 1) && holder.has_reagent(/datum/reagent/hydrogen, 1) && holder.has_reagent(/datum/reagent/nitrogen, 1))

/datum/chemical_reaction/paradise_ingredient/mitocholide
	results = list(/datum/reagent/medicine/paradise_mitocholide = 3)
	required_reagents = list(/datum/reagent/medicine/c2/synthflesh = 1, /datum/reagent/medicine/cryoxadone = 1, /datum/reagent/toxin/plasma = 1)

/datum/chemical_reaction/paradise_ingredient/jenkem
	results = list(/datum/reagent/drug/paradise_jenkem = 3)
	required_reagents = list(/datum/reagent/water/paradise_toilet = 1, /datum/reagent/ammonia = 1, /datum/reagent/water = 1)
	mix_message = "The mixture ferments into a filthy morass."

/datum/chemical_reaction/paradise_ingredient/jenkem/on_reaction(datum/reagents/holder, datum/equilibrium/reaction, created_volume)
	var/turf/location = get_turf(holder.my_atom)
	if(!location)
		return
	location.visible_message(span_warning("The solution generates a strong vapor!"))
	for(var/mob/living/carbon/carbon in range(1, location))
		if(!carbon.has_smoke_protection() && !carbon.internal && !carbon.external)
			carbon.reagents.add_reagent(/datum/reagent/drug/paradise_jenkem, 25)

/datum/chemical_reaction/paradise_ingredient/surge
	results = list(/datum/reagent/drug/paradise_surge = 6)
	required_reagents = list(/datum/reagent/thermite = 3, /datum/reagent/uranium = 1, /datum/reagent/fluorosurfactant = 1, /datum/reagent/toxin/acid = 1)
	mix_message = "The mixture congeals into a metallic green gel that crackles with electrical activity."

/datum/chemical_reaction/paradise_ingredient/ultralube
	results = list(/datum/reagent/lube/paradise_ultra = 2)
	required_reagents = list(/datum/reagent/lube = 2, /datum/reagent/toxin/formaldehyde = 1, /datum/reagent/cryostylane = 1)
	mix_message = "The mixture darkens and partially vaporizes into a chilling aerosol."

/datum/chemical_reaction/paradise_ingredient/glyphosate
	results = list(/datum/reagent/paradise_glyphosate = 4)
	required_reagents = list(/datum/reagent/chlorine = 1, /datum/reagent/phosphorus = 1, /datum/reagent/toxin/formaldehyde = 1, /datum/reagent/ammonia = 1)

/datum/chemical_reaction/paradise_ingredient/atrazine
	results = list(/datum/reagent/paradise_glyphosate/atrazine = 3)
	required_reagents = list(/datum/reagent/chlorine = 1, /datum/reagent/hydrogen = 1, /datum/reagent/nitrogen = 1)
	mix_message = "The mixture gives off a harsh odor."

/datum/chemical_reaction/paradise_ingredient/sarin
	results = list(/datum/reagent/toxin/paradise_sarin = 3)
	required_reagents = list(/datum/reagent/chlorine = 1, /datum/reagent/fuel = 1, /datum/reagent/oxygen = 1, /datum/reagent/phosphorus = 1, /datum/reagent/fluorine = 1, /datum/reagent/hydrogen = 1, /datum/reagent/acetone = 1, /datum/reagent/paradise_glyphosate/atrazine = 1)
	required_temp = T0C + 100
	mix_message = "The mixture yields a colorless, odorless liquid."

/datum/chemical_reaction/paradise_ingredient/sarin/on_reaction(datum/reagents/holder, datum/equilibrium/reaction, created_volume)
	var/turf/location = get_turf(holder.my_atom)
	if(!location)
		return
	location.visible_message(span_warning("The solution generates a strong vapor!"))
	for(var/mob/living/carbon/carbon in range(2, location))
		if(!carbon.has_smoke_protection() && !carbon.internal && !carbon.external)
			carbon.reagents.add_reagent(/datum/reagent/toxin/paradise_sarin, 4)
