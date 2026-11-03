ADMIN_VERB(paradise_zombie_control, R_ADMIN, "Zombie Control", "Infect, zombify, cure or clear a character using Paradise's necrotizing plague.", ADMIN_CATEGORY_FUN)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_WORLD, /mob/living/carbon/human)
	var/operation = tgui_input_list(user, "Choose an operation for [target].", "Zombie Control", list("Infect", "Zombify", "Cure", "Clear"))
	if(!operation || QDELETED(target) || !check_rights_for(user, R_ADMIN))
		return
	var/datum/disease/paradise_zombie/infection = locate() in target.diseases
	switch(operation)
		if("Infect", "Zombify")
			if(!infection)
				infection = new
				infection.infect(target, FALSE)
			if(operation == "Zombify")
				infection.stage = 8
				infection.process_infection_cycle()
		if("Cure")
			if(infection)
				infection.cure()
		if("Clear")
			qdel(infection)
	message_admins("[key_name_admin(user)] used [operation] on [key_name_admin(target)] in Zombie Control.")
	log_admin("[key_name(user)] used [operation] on [key_name(target)] in Zombie Control.")
	BLACKBOX_LOG_ADMIN_VERB("Zombie Control")
