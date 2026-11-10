/obj/item/excavation/depth_scanner
	/// One survey of a specimen source at a time.
	var/surveying = FALSE

/// The field kit carries one scanner: the depth scanner also surveys expedition specimen sources.
/obj/item/excavation/depth_scanner/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/structure/stationtrauma_research_source))
		return ..()
	if(!surveying && user.is_holding(src))
		INVOKE_ASYNC(src, PROC_REF(survey), interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/** Survey a source while the operator holds the scanner. */
/obj/item/excavation/depth_scanner/proc/survey(obj/structure/stationtrauma_research_source/source, mob/living/user)
	if(surveying || QDELETED(source) || !user?.is_holding(src) || !user.can_perform_action(source, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	surveying = TRUE
	var/datum/mind/operator = user.mind
	to_chat(user, span_notice("Вы начинаете полевое обследование [source]."))
	var/completed = do_after(user, 6 SECONDS, source)
	if(QDELETED(src))
		return
	surveying = FALSE
	if(!completed || QDELETED(source) || QDELETED(user) || user.mind != operator || !user.is_holding(src) || !user.can_perform_action(source, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	var/datum/stationtrauma_research_record/record = source.research_record()
	record.log_observation(user, source, record.surveyed ? "Повторное полевое обследование." : "Полевое обследование: [record.field_notes]")
	record.surveyed = TRUE
	to_chat(user, span_notice(record.specimen_text()))
	playsound(src, 'sound/machines/ping.ogg', 30, TRUE)
