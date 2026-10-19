/** A shortened ship ladder with a manual watertight hatch over its downward opening. */
/obj/structure/ladder/stationtrauma
	name = "лестница с гермолюком"
	desc = "Укороченная стальная лестница и откидной напольный люк с механическим штурвалом."
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/ladder_hatch.dmi'
	icon_state = "ladder11_closed"
	can_atmos_pass = ATMOS_PASS_PROC
	/// The hatch belongs to the floor of this ladder, not the deck above it.
	var/hatch_open = FALSE
	/// One wheel turn at a time, including commands from the lower deck.
	var/hatch_operating = FALSE

/obj/structure/ladder/stationtrauma/update_icon_state()
	// Native ladder travel bypasses turf zPass checks, so a mixed pair could bypass the hatch.
	if(down && !istype(down, /obj/structure/ladder/stationtrauma))
		unlink_down()
	if(up && !istype(up, /obj/structure/ladder/stationtrauma))
		unlink_up()
	. = ..()
	icon_state = "ladder[!!up][!!down]_[down && !hatch_open ? "closed" : "open"]"
	obj_flags &= ~BLOCK_Z_IN_UP
	if(down && !hatch_open)
		obj_flags |= BLOCK_Z_IN_UP

/** Keep the native masked floor opening, with our sprite already aligned to the floor. */
/obj/structure/ladder/stationtrauma/make_base_transparent()
	if(down && hatch_open && SSmapping.level_trait(z, ZTRAIT_DOWN))
		new /obj/effect/abstract/ladder_hole(loc, src)

/** A closed hatch seals its vertical opening without obstructing horizontal room flow. */
/obj/structure/ladder/stationtrauma/can_atmos_pass(turf/other, vertical)
	return !down || hatch_open || !isturf(other) || other.z >= z

/** Recheck at the end of the native climb, so a wheel turn can cancel a pending crossing. */
/obj/structure/ladder/stationtrauma/travel(mob/user, going_up = TRUE, is_ghost = FALSE, grant_exp = FALSE)
	var/obj/structure/ladder/stationtrauma/hatch = going_up ? up : src
	if(!is_ghost && istype(hatch) && hatch.down && !hatch.hatch_open)
		balloon_alert(user, "гермолюк закрыт")
		return
	return ..()

/obj/structure/ladder/stationtrauma/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!held_item)
		if(down || istype(up, /obj/structure/ladder/stationtrauma))
			context[SCREENTIP_CONTEXT_ALT_LMB] = down ? "Повернуть штурвал люка в полу" : "Повернуть штурвал верхнего люка"
		if(down && istype(up, /obj/structure/ladder/stationtrauma))
			context[SCREENTIP_CONTEXT_ALT_RMB] = "Повернуть штурвал верхнего люка"
	return CONTEXTUAL_SCREENTIP_SET

/obj/structure/ladder/stationtrauma/click_alt(mob/user)
	return operate_hatch(user, !down)

/obj/structure/ladder/stationtrauma/click_alt_secondary(mob/user)
	return operate_hatch(user, TRUE)

/** Operate either side of the same hatch without reaching through to a remote deck. */
/obj/structure/ladder/stationtrauma/proc/operate_hatch(mob/user, overhead)
	var/obj/structure/ladder/stationtrauma/hatch = overhead ? up : src
	if(!istype(hatch) || !hatch.down || hatch.hatch_operating || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return CLICK_ACTION_BLOCKING
	hatch.hatch_operating = TRUE
	if(do_after(user, 1 SECONDS, target = src) && !QDELETED(hatch) && (overhead ? up == hatch && hatch.down == src : down))
		hatch.set_hatch(!hatch.hatch_open)
	if(!QDELETED(hatch))
		hatch.hatch_operating = FALSE
	return CLICK_ACTION_SUCCESS

/** Existing ladder icon signals wake the local water portal; no hatch processing loop is needed. */
/obj/structure/ladder/stationtrauma/proc/set_hatch(open)
	if(hatch_open == open)
		return
	hatch_open = open
	if(open)
		make_base_transparent()
	else
		clear_base_transparency()
	update_appearance(UPDATE_ICON_STATE)
	air_update_turf(TRUE, TRUE)
	playsound(src, open ? 'sound/machines/airlock/boltsup.ogg' : 'sound/machines/airlock/boltsdown.ogg', 30, TRUE)
