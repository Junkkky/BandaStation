/mob/living/basic/spider/growing/spiderling/terror
	name = "детёныш паука террора"
	desc = "Крохотный, шустрый паук. Хочется верить, что он не вырастет."
	speed = -1
	melee_damage_upper = 1
	unsuitable_heat_damage = 0
	faction = list(FACTION_TERROR_SPIDER)
	directive = TERROR_SPIDER_DEFAULT_DIRECTIVE
	web_type = null
	spider_growth_time = 2 SECONDS
	/// The queen whose brood this spiderling belongs to.
	var/datum/weakref/terror_queen_ref
	/// Decoy spiderlings disappear instead of becoming adults.
	var/stillborn = FALSE
	/// A ghost who accepted an invitation when the parasite hatched.
	var/datum/weakref/reserved_ghost

/mob/living/basic/spider/growing/spiderling/terror/Initialize(mapload, caste, brood_directive, datum/weakref/brood_queen, stillborn = FALSE)
	grow_as = caste || pick(\
		/mob/living/basic/spider/giant/terror/red,\
		/mob/living/basic/spider/giant/terror/gray,\
		/mob/living/basic/spider/giant/terror/green,\
		/mob/living/basic/spider/giant/terror/reaper,\
		/mob/living/basic/spider/giant/terror/builder,\
	)
	if(!isnull(brood_directive))
		directive = brood_directive
	terror_queen_ref = brood_queen
	src.stillborn = stillborn
	. = ..()
	qdel(GetComponent(/datum/component/tameable))
	RegisterSignal(src, COMSIG_MOB_CHANGED_TYPE, PROC_REF(on_grown))

/mob/living/basic/spider/growing/spiderling/terror/on_fire_stack(seconds_per_tick, datum/status_effect/fire_handler/fire_stacks/fire_handler)
	. = ..()
	adjust_fire_loss(TERROR_SPIDER_FIRE_DAMAGE_PER_SECOND * seconds_per_tick, forced = TRUE)

/mob/living/basic/spider/growing/spiderling/terror/grow_up()
	if(stillborn)
		qdel(src)
		return
	return ..()

/mob/living/basic/spider/growing/spiderling/terror/proc/on_grown(datum/source, mob/living/basic/spider/giant/terror/adult)
	SIGNAL_HANDLER
	if(!istype(adult))
		return
	adult.terror_queen_ref = terror_queen_ref
	adult.directive = directive
	if(is_away_level(adult.z) || istype(adult, /mob/living/basic/spider/giant/terror/queen/empress))
		return
	var/datum/component/ghost_direct_control/direct_control = adult.AddComponent(\
		/datum/component/ghost_direct_control,\
		ban_type = ROLE_ALIEN,\
		poll_candidates = FALSE,\
		assumed_control_message = "Вы паук Ужаса. Следуйте директиве выводка.",\
		extra_control_checks = CALLBACK(adult, TYPE_PROC_REF(/mob/living/basic/spider/giant/terror, can_claim_brood_role)),\
		after_assumed_control = CALLBACK(adult, TYPE_PROC_REF(/mob/living/basic/spider/giant/terror, grant_brood_role)),\
	)
	var/mob/dead/observer/chosen = reserved_ghost?.resolve()
	if(chosen?.client && !adult.key)
		INVOKE_ASYNC(direct_control, TYPE_PROC_REF(/datum/component/ghost_direct_control, assume_direct_control), chosen)

/mob/living/basic/spider/giant/terror/proc/can_claim_brood_role(mob/dead/observer/ghost)
	if(!isobserver(ghost) || !ghost.client)
		return FALSE
	if(terror_degenerating)
		to_chat(ghost, span_warning("Паук угасает. Его уже нельзя занять."))
		return FALSE
	if(is_banned_from(ghost.ckey, list(ROLE_SYNDICATE)))
		to_chat(ghost, span_warning("Вам недоступна эта роль."))
		return FALSE
	return TRUE

/mob/living/basic/spider/giant/terror/proc/grant_brood_role()
	mind.set_assigned_role(SSjob.get_job_type(/datum/job/spider))
	mind.add_antag_datum(new /datum/antagonist/spider/terror(directive))

/datum/action/cooldown/mob_cooldown/terror_royal_jelly
	name = "Секреция королевского желе"
	desc = "Произведите желе, которое ускоряет регенерацию раненых пауков."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "spiderjelly"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 30 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_royal_jelly/Activate(atom/target)
	var/mob/living/basic/spider/giant/terror/mother/mother = owner
	var/turf/jelly_turf = mother.loc
	if(!isturf(jelly_turf))
		mother.balloon_alert(mother, "нужно встать на пол!")
		return FALSE
	playsound(mother, 'modular_bandastation/terror_spiders/sound/jelly.ogg', 50, TRUE)
	mother.visible_message(span_notice("[mother] начинает выделять королевское желе."))
	if(!do_after(mother, 3.3 SECONDS, target = jelly_turf, interaction_key = DOAFTER_SOURCE_SPIDER) || QDELETED(src) || QDELETED(mother) || owner != mother || mother.loc != jelly_turf || !IsAvailable())
		return FALSE
	new /obj/structure/spider/royal_jelly(jelly_turf)
	StartCooldown()
	return TRUE

/obj/structure/spider/royal_jelly
	name = "королевское желе"
	desc = "Капля питательного секрета, которой могут подкрепиться раненые пауки Ужаса."
	icon = 'modular_bandastation/terror_spiders/icons/terrorspider.dmi'
	icon_state = "spiderjelly"

/obj/structure/spider/royal_jelly/attack_hand(mob/user, list/modifiers)
	var/mob/living/basic/spider/giant/terror/spider = user
	if(!istype(spider))
		return ..()
	if(QDELETED(src) || spider.stat != STABLE || spider.incapacitated || !isturf(spider.loc) || !spider.Adjacent(src))
		return TRUE
	if(istype(spider, /mob/living/basic/spider/giant/terror/mother))
		spider.balloon_alert(spider, "мать не ест желе!")
		return TRUE
	if(spider.health >= spider.maxHealth)
		spider.balloon_alert(spider, "вам не нужно лечиться!")
		return TRUE
	playsound(spider.loc, 'modular_bandastation/terror_spiders/sound/jelly.ogg', 100, TRUE)
	spider.apply_status_effect(/datum/status_effect/terror_recovery)
	to_chat(spider, span_notice("Вы съедаете королевское желе. Регенерация ускоряется!"))
	qdel(src)
	return TRUE
