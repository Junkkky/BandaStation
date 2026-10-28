ADMIN_VERB(stationtrauma_overmap_jump, R_DEBUG, "Overmap - Переместить корабль к объекту", "Переместить корабль к координатам объекта без стыковки.", ADMIN_CATEGORY_DEBUG)
	var/list/ships = list()
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[id]
			ships["[navigation.vessel.name] ([id], [sector.name])"] = navigation
	var/ship_choice = tgui_input_list(user, "Корабль", "Перемещение на овермапе", ships)
	var/datum/stationtrauma_overmap/space/navigation = ships[ship_choice]
	var/datum/stationtrauma_overmap_sector/space/sector = navigation?.sector
	if(!check_rights_for(user, R_DEBUG) || QDELETED(sector) || QDELETED(navigation) || sector.ships[navigation.vessel.shuttle_id] != navigation)
		return
	var/list/destinations = list()
	for(var/id in navigation.sites)
		var/datum/stationtrauma_overmap_site/space/site = navigation.sites[id]
		if(site.berth && !site.failed)
			destinations["[site.name] ([id])"] = site
	var/choice = tgui_input_list(user, "Объект", "Перемещение на овермапе", destinations)
	var/datum/stationtrauma_overmap_site/space/site = destinations[choice]
	if(!check_rights_for(user, R_DEBUG) || QDELETED(navigation) || QDELETED(sector) || navigation.sector != sector || QDELETED(site) || navigation.sites[site.id] != site)
		return
	if(navigation.preparing || navigation.relocating || navigation.planning || navigation.arrival_pending)
		to_chat(user, span_warning("Дождись завершения текущего манёвра."), confidential = TRUE)
		return
	navigation.stop()
	var/revision = navigation.control_revision
	if((navigation.docked || navigation.ship_docking) && !navigation.sail())
		to_chat(user, span_warning("Не удалось освободить стоянку: [navigation.status]"), confidential = TRUE)
		return
	if(!check_rights_for(user, R_DEBUG) || QDELETED(navigation) || navigation.control_revision != revision || !navigation.debug_reposition(site))
		return
	log_admin("[key_name(user)] moved [navigation.vessel.shuttle_id] to overmap site [site.id] ([site.pos_x], [site.pos_y]) without docking")
	to_chat(user, span_notice("[navigation.vessel.name]: координаты [site.name]. Стыковка не выполнялась."), confidential = TRUE)

/** A non-yielding debug effect; the admin verb revalidates permissions after its dialogs and departure. */
/datum/stationtrauma_overmap/space/proc/debug_reposition(datum/stationtrauma_overmap_site/space/site)
	if(!is_operational() || preparing || relocating || planning || arrival_pending || docked || ship_docking || QDELETED(site) || sites[site.id] != site || !site.berth || site.failed)
		return FALSE
	stop("Движение остановлено")
	clear_encounters()
	pos_x = encounter_x = site.pos_x
	pos_y = encounter_y = site.pos_y
	discover_site(site)
	selected_destination = site.id
	prepared_site = site
	trip_distance = travelled = 0
	update_parallax()
	return TRUE
