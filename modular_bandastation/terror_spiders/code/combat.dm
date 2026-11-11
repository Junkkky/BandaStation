/datum/action/cooldown/mob_cooldown/lay_web/terror_reinforced
	parent_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести усиленную паутину"
	desc = "Сплетите паутину с дополнительными нитями. Её труднее разрушить."
	terror_web_type = /obj/structure/spider/stickyweb/terror/reinforced

/obj/structure/spider/stickyweb/terror/reinforced
	name = "усиленная паутина"
	desc = "Паутина укреплена дополнительными нитями."
	max_integrity = 30

/mob/living/basic/spider/giant/terror/gray/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_cloak_web_changed),
		COMSIG_ATOM_EXITED = PROC_REF(on_cloak_web_changed),
		COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON = PROC_REF(on_cloak_web_changed),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	RegisterSignals(src, list(COMSIG_MOVABLE_MOVED, COMSIG_BASICMOB_LOOK_ALIVE), PROC_REF(refresh_terror_cloak))
	refresh_terror_cloak()

/mob/living/basic/spider/giant/terror/gray/proc/on_cloak_web_changed(datum/source, atom/movable/moved)
	SIGNAL_HANDLER

	if(istype(moved, /obj/structure/spider/stickyweb/terror))
		refresh_terror_cloak()

/mob/living/basic/spider/giant/terror/gray/proc/refresh_terror_cloak()
	SIGNAL_HANDLER

	icon_living = initial(icon_living)
	if(isturf(loc))
		for(var/obj/structure/spider/stickyweb/terror/web in loc)
			if(!QDELETED(web))
				icon_living = "terror_gray_cloaked"
				break
	if(stat != DEAD && icon_state != icon_dead)
		icon_state = icon_living

/mob/living/basic/spider/giant/terror/gray/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(!ishuman(target) || icon_living != "terror_gray_cloaked")
		return ..()
	var/normal_lower = melee_damage_lower
	var/normal_upper = melee_damage_upper
	var/normal_penetration = armour_penetration
	melee_damage_lower *= 3
	melee_damage_upper *= 3
	armour_penetration *= 25
	. = ..()
	melee_damage_lower = normal_lower
	melee_damage_upper = normal_upper
	armour_penetration = normal_penetration
	if(.)
		var/mob/living/carbon/human/prey = target
		prey.apply_damage(45, STAMINA)
		prey.adjust_silence(10 SECONDS)
		visible_message(span_danger("[src] яростно терзает [target] в паутине!"))

/datum/action/cooldown/mob_cooldown/lay_web/terror_transparent
	parent_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести полупрозрачную паутину"
	desc = "Быстро сплетите малозаметную паутину. Ваш окрас сливается с паутиной улья."
	webbing_time = 1 SECONDS
	terror_web_type = /obj/structure/spider/stickyweb/terror/transparent

/obj/structure/spider/stickyweb/terror/transparent
	name = "полупрозрачная паутина"
	desc = "Тонкие нити этой паутины трудно заметить."
	alpha = 150

/obj/structure/spider/stickyweb/terror/transparent/stuck_react(mob/living/victim)
	. = ..()
	if(!iscarbon(victim) || victim.stat == DEAD)
		return
	victim.adjust_silence(14 SECONDS)
	victim.Knockdown(6 SECONDS)

/mob/living/basic/spider/giant/terror/black/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(envenom_terror_bite))

/mob/living/basic/spider/giant/terror/black/proc/envenom_terror_bite(datum/source, mob/living/carbon/human/prey, success)
	SIGNAL_HANDLER

	if(!success || !ishuman(prey) || prey.stat == DEAD || faction_check_atom(prey) || !prey.reagents)
		return
	prey.adjust_silence(10 SECONDS)
	if(prey.reagents.get_reagent_amount(/datum/reagent/toxin/terror_black_venom) >= 100)
		return
	var/injection_zone = pick(BODY_ZONE_CHEST, BODY_ZONE_HEAD)
	if(prey.can_inject(src, injection_zone, NONE))
		prey.reagents.add_reagent(/datum/reagent/toxin/terror_black_venom, prey.incapacitated ? 33 : 20)
		visible_message(span_danger("[src] вонзает клыки в [prey], впрыскивая яд!"))
	else
		visible_message(span_danger("[src] кусает [prey], но клыки не пробивают защиту!"))

/datum/action/cooldown/mob_cooldown/lay_web/terror_venom
	parent_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести ядовитую паутину"
	desc = "Сплетите паутину, нити которой впрыскивают яд в попавшуюся добычу."
	terror_web_type = /obj/structure/spider/stickyweb/terror/venom

/obj/structure/spider/stickyweb/terror/venom
	name = "ядовитая паутина"
	desc = "На нитях блестят капли тёмной жидкости."

/obj/structure/spider/stickyweb/terror/venom/stuck_react(mob/living/victim)
	. = ..()
	if(QDELETED(victim) || !iscarbon(victim) || victim.stat == DEAD || !victim.reagents)
		return
	if(victim.reagents.get_reagent_amount(/datum/reagent/toxin/terror_black_venom) >= 60 || !victim.can_inject(null, pick(BODY_ZONE_CHEST, BODY_ZONE_HEAD), NONE))
		return
	to_chat(victim, span_danger("Нити паутины впиваются в вас!"))
	victim.reagents.add_reagent(/datum/reagent/toxin/terror_black_venom, 45)

/datum/reagent/toxin/terror_black_venom
	name = "Яд Вдовы Ужаса"
	description = "Токсичность этого яда резко возрастает с концентрацией."
	color = "#cc00ff"
	toxpwr = 0
	liver_tolerance_multiplier = 0
	metabolization_rate = 0.25 * REAGENTS_METABOLISM
	chemical_flags = REAGENT_NO_RANDOM_RECIPE
	randomized_spawns = REAGENT_SPAWN_NO_RANDOM

/datum/reagent/toxin/terror_black_venom/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	var/damage_per_second = 0.5
	if(volume >= 90)
		damage_per_second = 4
		affected_mob.set_eye_blur_if_lower(12 SECONDS)
		affected_mob.Paralyze(10 SECONDS)
	else if(volume >= 60)
		damage_per_second = 2
		affected_mob.set_eye_blur_if_lower(12 SECONDS)
		affected_mob.set_confusion_if_lower(12 SECONDS)
	else
		if(volume >= 30)
			damage_per_second = 1
		affected_mob.set_eye_blur_if_lower(6 SECONDS)
	if(affected_mob.adjust_tox_loss(damage_per_second * seconds_per_tick * metabolization_ratio, updating_health = FALSE, required_biotype = affected_biotype))
		return . | UPDATE_MOB_HEALTH

/mob/living/basic/spider/giant/terror/brown/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/wall_smasher, ENVIRONMENT_SMASH_RWALLS)

/mob/living/basic/spider/giant/terror/purple
	/// Time spent away from the royal that laid this spider's egg.
	var/queen_separation = 0 SECONDS

/mob/living/basic/spider/giant/terror/purple/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/wall_smasher, ENVIRONMENT_SMASH_RWALLS)
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(on_guardian_bite))

/mob/living/basic/spider/giant/terror/purple/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(QDELETED(src) || stat == DEAD || terror_degenerating || !terror_queen_ref)
		return
	var/mob/living/basic/spider/giant/terror/queen = terror_queen_ref.resolve()
	if(!queen || queen.stat == DEAD)
		terror_queen_ref = null
		to_chat(src, span_userdanger("Королева погибла! Её сила больше не поддерживает вас!"))
		return
	var/turf/queen_turf = get_turf(queen)
	var/turf/our_turf = get_turf(src)
	if(queen_turf && our_turf && queen_turf.z == our_turf.z && get_dist(our_turf, queen_turf) < 10)
		queen_separation = 0 SECONDS
		return
	var/previous_separation = queen_separation
	queen_separation += seconds_per_tick SECONDS
	if(previous_separation < 3 MINUTES && queen_separation >= 3 MINUTES)
		melee_damage_lower = 5
		melee_damage_upper = 10
		to_chat(src, span_userdanger("Связь с [queen] разорвана! Вы потеряли часть силы!"))
	else if(previous_separation < 2 MINUTES && queen_separation >= 2 MINUTES)
		to_chat(src, span_danger("Разлука с [queen] ослабляет вас. Вернитесь к ней. Местоположение: [get_area(queen)]."))
	else if(previous_separation < 1 MINUTES && queen_separation >= 1 MINUTES)
		to_chat(src, span_danger("Вы отдалились от [queen]. Вернитесь к ней. Местоположение: [get_area(queen)]."))

/mob/living/basic/spider/giant/terror/purple/get_status_tab_items()
	. = ..()
	if(stat != STABLE)
		return
	if(terror_degenerating)
		. += "Связь с королевой разорвана"
		return
	var/mob/living/basic/spider/giant/terror/queen = terror_queen_ref?.resolve()
	if(!queen)
		return
	if(!queen_separation)
		. += "Королева рядом"
	else if(queen_separation >= 3 MINUTES)
		. += "Критическая связь. Вернитесь к королеве: [get_area(queen)]."
	else
		. += "До разрыва связи с королевой [DisplayTimeText(3 MINUTES - queen_separation)]. Местоположение: [get_area(queen)]."

/datum/action/cooldown/mob_cooldown/lay_web/terror_opaque
	parent_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести плотную паутину"
	desc = "Сплетите прочную паутину, которая закрывает обзор."
	webbing_time = 2 SECONDS
	terror_web_type = /obj/structure/spider/stickyweb/terror/opaque

/obj/structure/spider/stickyweb/terror/opaque
	name = "плотная паутина"
	desc = "За плотным переплетением нитей ничего не видно."
	opacity = TRUE
	max_integrity = 40

/mob/living/basic/spider/giant/terror/prince/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/wall_smasher, ENVIRONMENT_SMASH_RWALLS)
