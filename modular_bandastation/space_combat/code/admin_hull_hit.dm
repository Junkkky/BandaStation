ADMIN_VERB(stationtrauma_hull_hit, R_FUN, "Overmap - Удар по кораблю", "Нанести внешний удар по корпусу корабля овермапы.", ADMIN_CATEGORY_FUN)
	// Dialogs sleep, so only IDs survive them; the hull is looked up again afterwards.
	var/list/ships = list()
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/id in sector.ships)
			var/datum/stationtrauma_overmap/space/listed = sector.ships[id]
			ships["[listed.vessel.name] ([id], [sector.name])"] = list(sector_id, id)
	var/ship_choice = tgui_input_list(user, "Корабль", "Удар по кораблю", ships)
	if(!ship_choice)
		return
	var/list/kinds = list("Кинетический снаряд" = SHIP_HIT_KINETIC, "ЭМИ" = SHIP_HIT_EMP)
	var/kind_choice = tgui_input_list(user, "Вид удара", "Удар по кораблю", kinds)
	if(!kind_choice)
		return
	// Bearing of the hit source relative to the bow, clockwise.
	var/list/sides = list("Нос" = 0, "Правый борт" = 90, "Корма" = 180, "Левый борт" = 270)
	var/side_choice = tgui_input_list(user, "Откуда", "Удар по кораблю", sides)
	if(!side_choice)
		return
	var/power = tgui_input_number(user, "Радиус сильного поражения, клеток", "Удар по кораблю", 1, 3, 1)
	if(!power)
		return
	if(!check_rights_for(user, R_FUN))
		return
	var/list/ship_ids = ships[ship_choice]
	var/datum/stationtrauma_overmap_sector/space/target_sector = SSstationtrauma_space_voyage.sectors[ship_ids[1]]
	var/datum/stationtrauma_overmap/space/navigation = target_sector ? target_sector.ships[ship_ids[2]] : null
	if(QDELETED(navigation) || QDELETED(navigation.vessel))
		to_chat(user, span_warning("Корабль больше не на овермапе."), confidential = TRUE)
		return
	var/bearing = navigation.course + sides[side_choice]
	var/atom/target = stationtrauma_hull_hit(navigation.vessel, navigation.course, sin(bearing), cos(bearing), kinds[kind_choice], power)
	if(!target)
		to_chat(user, span_warning("[navigation.vessel.name]: с этой стороны луч не нашёл обшивку."), confidential = TRUE)
		return
	log_admin("[key_name(user)] hit [navigation.vessel.shuttle_id] with [kinds[kind_choice]] power [power] from [side_choice] at [AREACOORD(target)]")
	message_admins("[key_name_admin(user)] нанёс удар ([kind_choice], [power]) по [navigation.vessel.name]: [ADMIN_VERBOSEJMP(target)]")
