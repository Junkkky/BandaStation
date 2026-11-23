
/mob/living/carbon/human/Stun(amount, ignore_canstun = FALSE)
	amount = spec_stun(amount)
	return ..()

/mob/living/carbon/human/Knockdown(amount, daze_amount = 0, ignore_canstun = FALSE)
	amount = spec_stun(amount)
	return ..()

/mob/living/carbon/human/Paralyze(amount, ignore_canstun = FALSE)
	amount = spec_stun(amount)
	return ..()

/mob/living/carbon/human/Immobilize(amount, ignore_canstun = FALSE)
	amount = spec_stun(amount)
	return ..()

/mob/living/carbon/human/Unconscious(amount, ignore_canstun = FALSE)
	amount = spec_stun(amount)
	if(HAS_TRAIT(src, TRAIT_HEAVY_SLEEPER))
		amount *= (rand(125, 130) * 0.01)
	return ..()

/mob/living/carbon/human/Sleeping(amount)
	if(HAS_TRAIT(src, TRAIT_HEAVY_SLEEPER))
		amount *= (rand(125, 130) * 0.01)
	return ..()

/mob/living/carbon/human/become_husk(source)
	. = ..()
	if(. && source == BURN && cremation_stage == NONE)
		cremation_stage = CREMATION_HUSK
		cremation_exposure = max(cremation_exposure, CREMATION_HUSK_TIME)
		// Adding a second husk source does not fire the trait signal that redraws a zombie.
		if(HAS_TRAIT_FROM(src, TRAIT_HUSK, /datum/status_effect/zombie::id))
			update_body_parts()

/mob/living/carbon/human/cure_husk(list/sources)
	. = ..()
	// Another husk source (e.g. a changeling) can survive treatment of the burns.
	var/cured_cremation = (cremation_exposure || deferred_husk_damage) && cremation_stage != CREMATION_ASH && !HAS_TRAIT_FROM(src, TRAIT_HUSK, BURN)
	if(cured_cremation)
		cremation_stage = NONE
		cremation_exposure = 0
		deferred_husk_damage = 0
	if(. || cured_cremation)
		update_body_parts()

/mob/living/carbon/human/proc/spec_stun(amount)
	var/list/stun_amount = list(dna.species.stunmod * amount)
	SEND_SIGNAL(src, COMSIG_HUMAN_SPEC_STUN, stun_amount)
	return stun_amount[1]
