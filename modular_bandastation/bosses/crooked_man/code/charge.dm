/// Bubblegum's charge: his landing shadow marks where the Crooked Man will rush, and the first one in the way
/// takes the hit, so whoever holds him can step in front of the others.
/datum/action/cooldown/mob_cooldown/charge/crooked
	name = "Рывок"
	desc = "Короткая пауза — и стремительный рывок к выбранному месту. Сбивает первого, кто окажется на пути."
	cooldown_time = 15 SECONDS
	charge_delay = 0.8 SECONDS
	charge_past = 1
	charge_distance = 7
	charge_damage = 20
	// Bumping walls would blow them up on the event map; he tears walls on his own anyway.
	destroy_objects = FALSE
