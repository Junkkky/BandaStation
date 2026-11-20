/// Native wrapping interaction, with living containment instead of the spider's lethal feeding.
/datum/action/cooldown/mob_cooldown/wrap/event_spider
	name = "Оплести в кокон"
	desc = "Оплетает выбранного человека рядом живым коконом. Кокон можно разорвать."
	/// Owned containers release their occupants when the action or boss is removed.
	var/list/obj/structure/spider/cocoon/cocoons = list()

/datum/action/cooldown/mob_cooldown/wrap/event_spider/Remove(mob/remove_from)
	QDEL_LIST(cocoons)
	return ..()

/datum/action/cooldown/mob_cooldown/wrap/event_spider/cocoon(atom/movable/to_wrap)
	playsound(owner, 'sound/mobs/non-humanoids/insect/chitter.ogg', 60, TRUE)
	playsound(to_wrap, 'sound/items/handling/cloth/cloth_pickup1.ogg', 60, TRUE)
	return ..()

/datum/action/cooldown/mob_cooldown/wrap/event_spider/Activate(atom/to_wrap)
	if(!ishuman(to_wrap))
		return FALSE
	return ..()

/datum/action/cooldown/mob_cooldown/wrap/event_spider/wrap_target(mob/living/to_wrap)
	if(QDELETED(owner) || QDELETED(to_wrap) || !owner.Adjacent(to_wrap) || !isturf(to_wrap.loc))
		return
	var/obj/structure/spider/cocoon/event_spider/casing = new(get_turf(to_wrap))
	cocoons += casing
	casing.icon_state = "cocoon_large1"
	log_combat(owner, to_wrap, "wrapped alive in an event cocoon")
	playsound(casing, 'sound/effects/splat.ogg', 70, TRUE)
	to_wrap.forceMove(casing)

/// Native web spinning with an audible chitter when it starts.
/datum/action/cooldown/mob_cooldown/lay_web/event_spider
	webbing_time = 1 SECONDS

/datum/action/cooldown/mob_cooldown/lay_web/event_spider/Activate(atom/target)
	playsound(owner, 'sound/mobs/non-humanoids/insect/chitter.ogg', 60, TRUE)
	return ..()

/// Gentle digestion reuses the original owned stomach and safe ejection.
/datum/action/cooldown/spell/crooked_devour/event_spider
	name = "Проглотить / выплюнуть"
	digestion_rate = 0.25

/// Area EMP using the native pulse implementation.
/datum/action/cooldown/spell/emp/event_spider
	name = "Электромагнитный импульс"
	spell_requirements = NONE
	emp_heavy = 3
	emp_light = 7
	cooldown_time = 5 SECONDS

/// A living cocoon that tears audibly whether the victim breaks out or someone cuts it open.
/// Unlike native cocoons it is not fixed to the floor, so the clown can drag it away with the victim inside.
/obj/structure/spider/cocoon/event_spider
	anchored = FALSE

/obj/structure/spider/cocoon/event_spider/Destroy()
	playsound(get_turf(src), 'sound/effects/cloth_rip.ogg', 70, TRUE)
	return ..()

/// Knocks people back across the room and smashes furniture and machines next to the spider; walls and floors hold.
/datum/action/cooldown/spell/aoe/ability_stomp/event_spider
	name = "Топот паука"
	desc = "Бьёт и отбрасывает стоящих рядом и ломает предметы обстановки вокруг."
	stomp_visual = /obj/effect/temp_visual/spider_stomp_dust
	/// Objects are broken only this close; people are still thrown across the whole area.
	var/break_radius = 2

/datum/action/cooldown/spell/aoe/ability_stomp/event_spider/cast(atom/cast_on)
	. = ..()
	new /obj/effect/temp_visual/circle_wave/spider_stomp(get_turf(cast_on))
	var/mob/living/basic/boss/spider_clown/spider = owner
	if(istype(spider))
		spider.play_animation("stomp", 0.7 SECONDS)

/datum/action/cooldown/spell/aoe/ability_stomp/event_spider/cast_on_thing_in_aoe(atom/victim, atom/caster)
	if(isliving(victim))
		return ..()
	if(!(isstructure(victim) || ismachinery(victim)) || get_dist(caster, victim) > break_radius)
		return
	var/turf/victim_turf = get_turf(victim)
	if(isspaceturf(victim_turf))
		return
	var/obj/broken = victim
	broken.take_damage(60, BRUTE, BOMB, 0)

/// Dust thrown up by the spider's stomp, fading over half a second.
/obj/effect/temp_visual/spider_stomp_dust
	icon = 'icons/effects/96x96.dmi'
	icon_state = "smoke2"
	pixel_x = -32
	pixel_y = -32
	color = "#8c8478"
	duration = 0.6 SECONDS

/obj/effect/temp_visual/spider_stomp_dust/Initialize(mapload)
	. = ..()
	animate(src, alpha = 0, time = duration, easing = EASE_IN)

/// Grey shockwave rolling out over the stomp's knockback area.
/obj/effect/temp_visual/circle_wave/spider_stomp
	color = "#9a948a"
	amount_to_scale = 7

/// The Crooked Man's vomit cone, leaving persistent blood pools usable for blood crawling.
/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/event_spider
	name = "Плевок токсичной кровью"
	desc = "Изрыгает конус токсичной крови, заливающий всё впереди."
	button_icon = 'icons/mob/actions/actions_blood_worm.dmi'
	button_icon_state = "spit_blood"
	plume_color = BLOOD_COLOR_RED
	cast_sound = 'sound/effects/wounds/splatter.ogg'

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/event_spider/do_turf_cone_effect(turf/target_turf, atom/caster, level)
	if(!isopenturf(target_turf) || locate(/obj/effect/decal/cleanable/blood) in target_turf)
		return
	if(prob(100 - level * 15))
		new /obj/effect/decal/cleanable/blood/splatter(target_turf)

/datum/action/cooldown/spell/cone/staggered/crooked_vomit_cone/event_spider/do_mob_cone_effect(mob/living/victim, atom/caster, level)
	if(victim == caster || QDELETED(caster))
		return
	victim.apply_damage(max(7.5, 17.5 - level * 2.5), TOX)
	new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(victim), turn(caster.dir, 180))
	to_chat(victim, span_danger("Вас окатило токсичной кровью!"))

/// Clown body and back; both directions leave gibs through the shared form change.
/datum/action/cooldown/spider_disguise
	name = "Облик клоуна / паука"
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "shapeshift"

/datum/action/cooldown/spider_disguise/Activate(atom/target)
	var/mob/living/basic/boss/spider_clown/spider = get_spider_clown(owner)
	if(!spider)
		return FALSE
	return spider.set_form(spider.form == "clown" ? "spider" : "clown")

/// Small ventcrawling spider form; vent exits leave gibs through the spider's own trait signal.
/datum/action/cooldown/spider_tiny
	name = "Облик паучка / паука"
	desc = "Превращает в маленького паучка, который может лазить по вентиляции (Alt-клик по вентиляции)."
	button_icon = 'modular_bandastation/bosses/spider_clown/icons/spider_clown_tiny.dmi'
	button_icon_state = "tiny"

/datum/action/cooldown/spider_tiny/Activate(atom/target)
	var/mob/living/basic/boss/spider_clown/spider = get_spider_clown(owner)
	if(!spider)
		return FALSE
	return spider.set_form(spider.form == "tiny" ? "spider" : "tiny")

/// The clown's true form: a tall tentacled figure in this same body; both directions leave gibs through the shared form change.
/datum/action/cooldown/spider_true_form
	name = "Истинная форма"
	desc = "Принять истинный облик или вернуться в облик паука."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "horror"

/datum/action/cooldown/spider_true_form/Activate(atom/target)
	var/mob/living/basic/boss/spider_clown/spider = get_spider_clown(owner)
	if(!spider)
		return FALSE
	return spider.set_form(spider.form == "true" ? "spider" : "true")

/// Changeling-style copy of a crew member; the clown is always offered first.
/datum/action/cooldown/spider_mimic
	name = "Перевоплощение"
	desc = "Принять облик члена экипажа или вернуть облик клоуна."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "transform"

/datum/action/cooldown/spider_mimic/Activate(atom/target)
	INVOKE_ASYNC(src, PROC_REF(choose_shape), owner)
	return TRUE

/// Shows the crew list; the chosen body and target are checked again after the menu closes.
/datum/action/cooldown/spider_mimic/proc/choose_shape(mob/living/carbon/human/spider_clown_body/body)
	if(!istype(body))
		return
	var/list/choices = list("Клоун" = null)
	for(var/mob/living/carbon/human/crew in GLOB.player_list)
		if(crew == body || istype(crew, /mob/living/carbon/human/spider_clown_body))
			continue
		var/label = "[crew.real_name] ([crew.mind?.assigned_role?.title || "без должности"])"
		if(label in choices)
			label = "[label] [REF(crew)]"
		choices[label] = WEAKREF(crew)
	var/choice = tgui_input_list(body, "В кого перевоплотиться?", "Перевоплощение", choices)
	if(isnull(choice) || !(choice in choices) || QDELETED(body) || owner != body || body.stat == DEAD || !isturf(body.loc))
		return
	var/datum/weakref/crew_ref = choices[choice]
	var/mob/living/carbon/human/crew = crew_ref?.resolve()
	if(crew_ref && (!istype(crew) || QDELETED(crew)))
		to_chat(body, span_warning("Этот человек больше недоступен."))
		return
	spider_clown_transform_effects(body.loc)
	if(crew)
		body.mimic(crew)
		log_admin("[key_name(body)] mimicked [key_name(crew)] as the spider clown.")
	else
		body.restore_clown()

/// Picks the TTS voice for whichever form this body currently shows.
/datum/action/cooldown/spider_voice
	name = "Голос этой формы"
	desc = "Выбрать голос TTS для текущей формы. Копия члена экипажа говорит его голосом, пока не выбран другой."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "mimic_voice"

/datum/action/cooldown/spider_voice/Activate(atom/target)
	INVOKE_ASYNC(src, PROC_REF(choose_voice), owner)
	return TRUE

/// The voice menu waits for input, so the body is checked again before the voice is stored.
/datum/action/cooldown/spider_voice/proc/choose_voice(mob/living/body)
	var/datum/component/tts_component/tts = body?.GetComponent(/datum/component/tts_component)
	if(!tts)
		return
	var/datum/tts_seed/seed = tts.select_tts_seed(chooser = body, overrides = TTS_OVERRIDE_GENDER | TTS_OVERRIDE_TIER)
	if(!seed || QDELETED(body) || owner != body)
		return
	var/mob/living/basic/boss/spider_clown/spider = get_spider_clown(body)
	spider?.remember_voice(body, seed)

/// Native demon blood crawl, ignoring only the boss's own teleport immunity.
/datum/action/cooldown/spell/jaunt/bloodcrawl/event_spider
	name = "Раствориться в крови"
	desc = "Погружается в лужу крови рядом и выходит из другой."

/datum/action/cooldown/spell/jaunt/bloodcrawl/event_spider/can_cast_spell(feedback = TRUE)
	var/turf/owner_turf = get_turf(owner)
	var/area/owner_area = get_area(owner)
	if(!isliving(owner) || !owner_turf || !owner_area || (owner_area.area_flags & NOTELEPORT) || (SEND_SIGNAL(src, COMSIG_SPELL_CAN_CAST_CHECK, feedback) & SPELL_CANCEL_CAST))
		return FALSE
	if(find_nearby_blood(owner_turf))
		return TRUE
	if(feedback)
		to_chat(owner, span_warning("Рядом нет крови!"))
	return FALSE

/// Melee limb tearing with the body-zone doll, independent of Pinhead's chains.
/datum/action/cooldown/event_target/chain_operation/dismember/event_spider
	name = "Оторвать конечность"
	desc = "Отрывает выбранную на кукле руку или ногу у стоящего рядом."
	needs_chains = FALSE

/datum/action/cooldown/event_target/chain_operation/dismember/event_spider/operate(mob/living/carbon/human/victim, datum/status_effect/pinhead_chains/held)
	if(!owner.Adjacent(victim))
		to_chat(owner, span_warning("Цель слишком далеко."))
		return FALSE
	return ..()

/// The clown's hands keep what they tear off; clicking oneself with it eats it.
/datum/action/cooldown/event_target/chain_operation/dismember/event_spider/clown
	desc = "Отрывает выбранную на кукле руку или ногу у стоящего рядом. Конечность остаётся в руке; кликните ею по себе, чтобы сожрать."

/datum/action/cooldown/event_target/chain_operation/dismember/event_spider/clown/operate(mob/living/carbon/human/victim, datum/status_effect/pinhead_chains/held)
	var/obj/item/bodypart/limb = victim.get_bodypart(check_zone(owner.zone_selected))
	. = ..()
	if(. && !QDELETED(limb) && !limb.owner)
		owner.put_in_hands(limb)

/// Invisibility has its own source so removing it never removes another effect.
/datum/action/cooldown/spider_invisibility
	name = "Невидимость"
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "ninja_cloak"
	/// This action's toggle, independent of external invisibility sources.
	var/hidden = FALSE

/datum/action/cooldown/spider_invisibility/Activate(atom/target)
	hidden = !hidden
	playsound(owner, 'sound/effects/magic/cosmic_energy.ogg', 50, TRUE)
	if(hidden)
		owner.SetInvisibility(INVISIBILITY_OBSERVER, REF(src))
	else
		owner.RemoveInvisibility(REF(src))
	to_chat(owner, span_notice((hidden ? "Вы исчезаете из виду." : "Вы снова видимы.")))
	return TRUE

/datum/action/cooldown/spider_invisibility/Remove(mob/remove_from)
	remove_from.RemoveInvisibility(REF(src))
	hidden = FALSE
	return ..()

/// Physical jump based on the zombie hunter's scoped throw, adapted to a basic mob.
/datum/action/cooldown/event_target/spider_jump
	name = "Прыжок"
	button_icon = 'icons/mob/actions/actions_elites.dmi'
	button_icon_state = "legionnaire_charge"
	cooldown_time = 2 SECONDS

/datum/action/cooldown/event_target/spider_jump/Activate(atom/target)
	var/turf/destination = get_turf(target)
	var/mob/living/jumper = owner
	if(!isturf(jumper.loc) || jumper.throwing || jumper.buckled || destination == jumper.loc)
		return FALSE
	if(!jumper.throw_at(destination, 10, 2, spin = FALSE, gentle = TRUE, callback = CALLBACK(src, PROC_REF(land), target), quickstart = FALSE, throw_type_path = /datum/thrownthing/event_spider_jump))
		return FALSE
	playsound(owner, 'sound/items/weapons/thudswoosh.ogg', 40, TRUE)
	StartCooldown()
	return TRUE

/// The clicked victim is pinned like a hunter's pounce; everyone else nearby is knocked away.
/datum/action/cooldown/event_target/spider_jump/proc/land(atom/target)
	if(QDELETED(owner) || !isturf(owner.loc))
		return
	playsound(owner, 'sound/effects/meteorimpact.ogg', 60, TRUE)
	// The landing reuses the stomp's rear-and-slam animation.
	var/mob/living/basic/boss/spider_clown/spider = owner
	if(istype(spider))
		spider.play_animation("stomp", 0.7 SECONDS)
	var/mob/living/pinned
	if(isliving(target) && target != owner && !QDELETED(target) && get_dist(owner, target) <= 1)
		pinned = target
	for(var/mob/living/victim in range(1, owner))
		if(victim == owner || victim == pinned || victim.stat == DEAD)
			continue
		victim.Knockdown(2 SECONDS)
		victim.throw_at(get_edge_target_turf(victim, get_dir(owner, victim) || pick(GLOB.alldirs)), 2, 2, owner)
		log_combat(owner, victim, "knocked away by landing", src)
	if(!pinned || pinned.stat == DEAD)
		return
	pinned.apply_damage(10, BRUTE)
	pinned.Paralyze(4 SECONDS)
	pinned.visible_message(span_danger("[owner] придавливает [pinned] к земле!"), span_userdanger("[owner] придавливает вас к земле!"))
	log_combat(owner, pinned, "pinned by jump", src)

/// The zombie hunter's endpoint guard adapted to arbitrary movable director bodies.
/datum/thrownthing/event_spider_jump
	/// Restore height even when the throw is cancelled or the body is deleted.
	var/original_height
	/// Suppress only this jump's landing impulse, not unrelated movement.
	var/finishing = FALSE

/datum/thrownthing/event_spider_jump/New(thrownthing, target, init_dir, maxrange, speed, thrower, diagonals_first, force, gentle, callback, target_zone)
	. = ..()
	original_height = src.thrownthing.pixel_z
	animate(src.thrownthing, pixel_z = original_height + 16, time = 0.2 SECONDS)
	RegisterSignal(src.thrownthing, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_endpoint))
	RegisterSignal(src.thrownthing, COMSIG_MOVABLE_PRE_THROW, PROC_REF(on_rethrow))
	RegisterSignal(src.thrownthing, COMSIG_MOVABLE_SPACEMOVE, PROC_REF(stop_landing_impulse))

/datum/thrownthing/event_spider_jump/proc/check_endpoint(atom/movable/source)
	SIGNAL_HANDLER
	if(source.throwing == src && (source.loc == target_turf || dist_travelled >= maxrange))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/thrownthing/event_spider_jump/Destroy()
	if(thrownthing)
		UnregisterSignal(thrownthing, list(COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_PRE_THROW, COMSIG_MOVABLE_SPACEMOVE))
		animate(thrownthing, pixel_z = original_height, time = 0.2 SECONDS)
	return ..()

/datum/thrownthing/event_spider_jump/proc/on_rethrow(atom/movable/source)
	SIGNAL_HANDLER
	if(source.throwing == src)
		qdel(src)

/datum/thrownthing/event_spider_jump/proc/stop_landing_impulse(atom/movable/source, movement_dir, continuous_move)
	SIGNAL_HANDLER
	if(finishing && continuous_move)
		return COMSIG_MOVABLE_STOP_SPACEMOVE

/datum/thrownthing/event_spider_jump/finalize(hit = FALSE, atom/target = null)
	finishing = TRUE
	return ..()

/// Raises blood spiders from a clicked pool of blood; they serve every body of their master.
/datum/action/cooldown/event_target/spider_blood_brood
	name = "Кровавый выводок"
	desc = "Поднимает кровавого паука из лужи крови. Одновременно живут не больше шести."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "lay_enriched_eggs"
	/// Living spawned spiders, so repeated clicks cannot raise an army.
	var/list/datum/weakref/brood = list()
	/// Most spiders alive at once.
	var/max_brood = 6

/datum/action/cooldown/event_target/spider_blood_brood/Activate(atom/target)
	var/turf/pool_turf = get_turf(target)
	var/obj/effect/decal/cleanable/pool
	for(var/obj/effect/decal/cleanable/candidate in pool_turf)
		if(candidate.can_bloodcrawl_in())
			pool = candidate
			break
	if(!pool)
		owner.balloon_alert(owner, "нужна лужа крови")
		return FALSE
	for(var/datum/weakref/spawned_ref as anything in brood.Copy())
		var/mob/living/spawned = spawned_ref.resolve()
		if(QDELETED(spawned) || spawned.stat == DEAD)
			brood -= spawned_ref
	if(length(brood) >= max_brood)
		owner.balloon_alert(owner, "выводок уже полон")
		return FALSE
	playsound(pool_turf, 'sound/effects/magic/exit_blood.ogg', 70, TRUE)
	playsound(pool_turf, 'sound/mobs/non-humanoids/insect/chitter.ogg', 70, TRUE)
	pool_turf.visible_message(span_danger("Из [pool.declent_ru(GENITIVE)] выбирается кровавый паук!"))
	var/mob/living/basic/flesh_spider/blood_brood/spawned = new(pool_turf)
	spawned.set_faction(list(REF(owner_spider())))
	brood += WEAKREF(spawned)
	spawned.rise_from_blood()
	StartCooldown()
	return TRUE

/// The brood answers to the spider itself, whichever body currently carries the action.
/datum/action/cooldown/event_target/spider_blood_brood/proc/owner_spider()
	return get_spider_clown(owner) || owner

/// Changeling flesh spider raised from blood by the spider clown.
/mob/living/basic/flesh_spider/blood_brood
	name = "кровавый паук"
	desc = "Мокрый от крови паук. Он только что выбрался из лужи."
	unique_name = FALSE

/// Climbs out of the pool: rises from below the floor while gaining its size and colour.
/mob/living/basic/flesh_spider/blood_brood/proc/rise_from_blood()
	alpha = 0
	pixel_z = -12
	transform = matrix().Scale(0.4)
	animate(src, alpha = 255, pixel_z = 0, transform = matrix(), time = 0.8 SECONDS, easing = BACK_EASING | EASE_OUT)
	new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(src), pick(GLOB.cardinals))
