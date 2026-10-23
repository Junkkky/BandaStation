/** Removable fuel retains its remaining full-power seconds between installations. */
/obj/item/stationtrauma_fuel_rod
	name = "топливная кассета реактора"
	desc = "Сменная кассета судовой реакторной установки."
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/control_rod.dmi'
	icon_state = "irradiated"
	w_class = WEIGHT_CLASS_NORMAL
	/// Full-power operating seconds remaining.
	var/fuel_remaining = 1800

/obj/item/stationtrauma_fuel_rod/examine(mob/user)
	. = ..()
	. += span_notice("Остаток топлива: [round(100 * fuel_remaining / initial(fuel_remaining))]%.")

/** A serviceable absorber is required before the reactor can be started. */
/obj/item/stationtrauma_control_rod
	name = "управляющий стержень реактора"
	desc = "Поглотитель для управления реакцией и аварийной остановки."
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/control_rod.dmi'
	icon_state = "normal"
	w_class = WEIGHT_CLASS_NORMAL

/** One processor owns the isolated installation; only its turbine exports electricity. */
/obj/machinery/power/stationtrauma_reactor
	parent_type = /obj/machinery/power/stationtrauma_plant_machine
	name = "судовой реактор"
	desc = "ЛКМ — управление. Лом — извлечь кассету и стержень после остановки и охлаждения. Слева — питательная вода, справа — пар, сверху — горячий контур охладителя, снизу — его возврат."
	icon = 'modular_bandastation/underwater_machinery/reactor/icons/plant_reactor.dmi'
	plant_role = "reactor"
	pixel_y = -32
	footprint_height = 3
	processing_flags = START_PROCESSING_ON_INIT
	plant_ports = list("вода слева" = list(-1, 0, WEST, ST_PLANT_WATER), "пар справа" = list(1, 0, EAST, ST_PLANT_STEAM), "горячий сверху" = list(0, 1, NORTH, ST_PLANT_COOLANT), "возврат снизу" = list(0, -1, SOUTH, ST_PLANT_COOLANT))
	/// The complete finite liquid, steam and heat inventory.
	var/datum/stationtrauma_plant_state/plant
	/// Removable service parts.
	var/obj/item/stationtrauma_fuel_rod/fuel_rod
	var/obj/item/stationtrauma_control_rod/control_rod
	/// Mapper convenience: a stopped installation with a loaded fuel cartridge.
	var/start_with_fuel = FALSE
	/// Cached parts and scalar route capacities, rebuilt only after network changes.
	var/list/parts = list()
	var/list/rates = list()
	var/cached_revision = -1
	var/topology_error
	var/obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet/sea_inlet
	var/obj/machinery/stationtrauma_reactor_pipe/sea_outlet/sea_outlet
	var/warning = FALSE

/obj/machinery/power/stationtrauma_reactor/Initialize(mapload)
	plant = new
	. = ..()
	control_rod = new(src)
	if(start_with_fuel)
		fuel_rod = new(src)

/obj/machinery/power/stationtrauma_reactor/Destroy()
	fuel_rod?.forceMove(drop_location())
	control_rod?.forceMove(drop_location())
	fuel_rod = null
	control_rod = null
	for(var/role in parts)
		var/obj/machinery/power/stationtrauma_plant_machine/part = parts[role]
		if(!QDELETED(part))
			part.set_plant_mode("off")
	if(plant && isturf(loc))
		plant.scram()
		var/obj/structure/stationtrauma_plant_wreck/wreck = new(loc)
		wreck.contents_state = plant
		plant = null
	QDEL_NULL(plant)
	parts.Cut()
	sea_inlet = null
	sea_outlet = null
	return ..()

/** Join two named flush ports through matching, directed isolated pipework. */
/obj/machinery/power/stationtrauma_reactor/proc/route(obj/machinery/power/stationtrauma_plant_machine/origin, from_port, obj/machinery/power/stationtrauma_plant_machine/destination, to_port, line, pump = FALSE)
	if(QDELETED(origin) || QDELETED(destination))
		return 0
	return stationtrauma_plant_path(origin.port_turf(from_port), origin.port_facing(from_port), destination.port_turf(to_port), destination.port_facing(to_port), plant_id, line, pump, origin.piping_layer, destination.piping_layer)

/** Cache the ocean route's capacity; ocean adjacency itself is checked live. */
/obj/machinery/power/stationtrauma_reactor/proc/sea_route(obj/machinery/power/stationtrauma_plant_machine/part)
	if(QDELETED(part) || QDELETED(sea_inlet) || QDELETED(sea_outlet))
		return 0
	return min(sea_inlet.flow_rate, stationtrauma_plant_path(get_turf(sea_inlet), NONE, part.port_turf("охлаждение справа сверху"), part.port_facing("охлаждение справа сверху"), plant_id, ST_PLANT_SEA, FALSE, sea_inlet.piping_layer, part.piping_layer), stationtrauma_plant_path(part.port_turf("выпуск справа снизу"), part.port_facing("выпуск справа снизу"), get_turf(sea_outlet), NONE, plant_id, ST_PLANT_SEA, FALSE, part.piping_layer, sea_outlet.piping_layer))

/** Missing or ambiguous equipment never creates a fallback supply or free generation. */
/obj/machinery/power/stationtrauma_reactor/proc/rebuild_plant()
	cached_revision = GLOB.stationtrauma_plant_revision
	parts = list()
	rates = list()
	topology_error = null
	sea_inlet = null
	sea_outlet = null
	for(var/obj/machinery/power/stationtrauma_plant_machine/part as anything in GLOB.stationtrauma_plant_parts)
		if(QDELETED(part) || part.plant_id != plant_id)
			continue
		if(parts[part.plant_role])
			topology_error = "Повторяется агрегат: [part.plant_role]. Задайте разным установкам разные plant_id."
		parts[part.plant_role] = part
	for(var/obj/machinery/stationtrauma_reactor_pipe/pipe as anything in GLOB.stationtrauma_plant_pipes)
		if(QDELETED(pipe) || pipe.plant_id != plant_id)
			continue
		if(istype(pipe, /obj/machinery/stationtrauma_reactor_pipe/pump/sea_inlet))
			if(sea_inlet)
				topology_error = "Для одной установки нужен один забортный насос."
			sea_inlet = pipe
		else if(istype(pipe, /obj/machinery/stationtrauma_reactor_pipe/sea_outlet))
			if(sea_outlet)
				topology_error = "Для одной установки нужен один общий забортный выпуск."
			sea_outlet = pipe
	if(topology_error)
		plant.scram(TRUE)
		return
	var/obj/machinery/power/stationtrauma_plant_machine/turbine = parts["turbine"]
	var/obj/machinery/power/stationtrauma_plant_machine/condenser = parts["condenser"]
	var/obj/machinery/power/stationtrauma_plant_machine/cooler = parts["cooler"]
	rates["steam"] = route(src, "пар справа", turbine, "пар слева", ST_PLANT_STEAM)
	rates["exhaust"] = route(turbine, "выхлоп справа", condenser, "пар слева сверху", ST_PLANT_EXHAUST)
	rates["feed"] = route(condenser, "вода слева снизу", src, "вода слева", ST_PLANT_WATER, TRUE)
	rates["reserve"] = route(parts["reservoir"], "вода справа", src, "вода слева", ST_PLANT_WATER, TRUE)
	rates["cooler"] = min(route(src, "горячий сверху", cooler, "горячий слева сверху", ST_PLANT_COOLANT, TRUE), route(cooler, "возврат слева снизу", src, "возврат снизу", ST_PLANT_COOLANT))
	rates["condenser_sea"] = sea_route(condenser)
	rates["cooler_sea"] = sea_route(cooler)

/** Live switches and damage gate cached routes without a per-tick network traversal. */
/obj/machinery/power/stationtrauma_reactor/proc/part_ready(role)
	var/obj/machinery/power/stationtrauma_plant_machine/part = parts[role]
	return !QDELETED(part) && part.enabled && part.is_operational

/obj/machinery/power/stationtrauma_reactor/process(seconds_per_tick)
	if(cached_revision != GLOB.stationtrauma_plant_revision)
		rebuild_plant()
	if(!is_operational || QDELETED(control_rod) || QDELETED(fuel_rod) || fuel_rod.fuel_remaining <= 0)
		plant.scram(plant.running)
	var/condenser_on = part_ready("condenser")
	var/turbine_on = part_ready("turbine")
	var/cooler_on = part_ready("cooler")
	var/sea_available = !QDELETED(sea_inlet) && !QDELETED(sea_outlet) && sea_inlet.available() && sea_outlet.available() && sea_inlet.at_ocean() && sea_outlet.at_ocean()
	var/condenser_sea = sea_available && condenser_on ? rates["condenser_sea"] : 0
	var/cooler_sea = sea_available && cooler_on ? rates["cooler_sea"] : 0
	// The two heat sinks share the same intake; do not count its capacity twice.
	if(condenser_sea && cooler_sea)
		condenser_sea = min(condenser_sea, sea_inlet.flow_rate / 2)
		cooler_sea = min(cooler_sea, sea_inlet.flow_rate / 2)
	var/used = plant.advance(seconds_per_tick, fuel_rod ? fuel_rod.fuel_remaining : 0, turbine_on ? rates["steam"] : 0, turbine_on && condenser_on ? rates["exhaust"] : 0, condenser_on ? rates["feed"] : 0, part_ready("reservoir") ? rates["reserve"] : 0, condenser_sea, cooler_on ? rates["cooler"] : 0, cooler_sea)
	if(fuel_rod)
		fuel_rod.fuel_remaining = max(0, fuel_rod.fuel_remaining - used)
	var/obj/machinery/power/stationtrauma_plant_machine/turbine = parts["turbine"]
	if(!QDELETED(turbine))
		turbine.add_avail(plant.power * seconds_per_tick)
	var/new_warning = plant.tripped || plant.core_temperature >= ST_PLANT_WARNING
	if(new_warning && !warning)
		visible_message(span_danger("[src]: сработала защита или предупреждение о перегреве! Сохраняйте охлаждение."))
		playsound(src, 'sound/machines/warning-buzzer.ogg', 40, FALSE)
	warning = new_warning
	if(plant.thermal_damage)
		take_damage(plant.thermal_damage, BURN, FIRE)
		if(QDELETED(src))
			return
	var/emergency = plant.tripped || !is_operational
	var/overload = plant.core_temperature >= ST_PLANT_WARNING || plant.pressure(plant.core) >= 12
	set_plant_mode(emergency ? "emergency" : overload ? "overload" : plant.running || plant.core_temperature > ST_PLANT_SERVICE ? "working" : "off")
	for(var/role in parts)
		if(role == "reactor")
			continue
		var/obj/machinery/power/stationtrauma_plant_machine/part = parts[role]
		if(QDELETED(part))
			continue
		var/active = role == "turbine" ? plant.power > 0 : role == "cooler" ? plant.cooler_power > 0 : plant.condensed_flow > 0
		part.set_plant_mode(!part.enabled || !part.is_operational ? "off" : emergency ? "emergency" : overload ? "overload" : active ? "working" : "off")

/** All service operations require a stopped, cool and depressurised installation. */
/obj/machinery/power/stationtrauma_reactor/proc/can_service()
	return !plant.running && plant.core_temperature <= ST_PLANT_SERVICE && plant.pressure(plant.core) < 1

/obj/machinery/power/stationtrauma_reactor/examine(mob/user)
	. = ..()
	. += span_notice("Зона: [round(plant.core_temperature - T0C)] °C. Вода: [round(plant.core.water, 0.1)] л. Давление пара: [round(plant.pressure(plant.core), 0.1)] бар. Турбина: [round(plant.power / 1000)] кВт.")
	. += span_notice("Топливо: [fuel_rod ? "[round(fuel_rod.fuel_remaining)] с полной мощности" : "нет"]. Стержень: [control_rod ? "есть" : "нет"]. Остаточное тепло: [round(plant.decay_heat / 1000)] кВт.")
	if(topology_error)
		. += span_warning(topology_error)

/obj/machinery/power/stationtrauma_reactor/attack_hand(mob/living/user, list/modifiers)
	show_controls(user, src)

/** The same guarded control menu is available at the housing and its matched console. */
/obj/machinery/power/stationtrauma_reactor/proc/show_controls(mob/living/user, atom/source)
	if(!controls_available(user, source))
		return
	if(cached_revision != GLOB.stationtrauma_plant_revision)
		rebuild_plant()
	var/list/choices = list("SCRAM", "Мощность 25%", "Мощность 50%", "Мощность 75%", "Мощность 100%", "Сброс защиты", "Насосы: включить", "Насосы: выключить", "Аварийное охлаждение", "Турбина: включить/выключить", "Холодный дренаж в бак")
	var/list/missing = list()
	var/list/route_names = list("steam" = "пар к турбине", "exhaust" = "выхлоп к конденсатору", "feed" = "питательная вода", "condenser_sea" = "забортное охлаждение")
	for(var/line in route_names)
		if(!rates[line])
			missing += route_names[line]
	var/connections_status = topology_error ? topology_error : length(missing) ? "Нет подачи: [jointext(missing, ", ")]. Проверьте насосы и вентили." : "Основные линии соединены."
	var/choice = tgui_input_list(user, "Зона [round(plant.core_temperature - T0C)] °C; вода [round(plant.core.water)] л; пар [round(plant.pressure(plant.core), 0.1)] бар; турбина [round(plant.power / 1000)] кВт. Защита: [plant.tripped ? "СРАБОТАЛА" : "готова"]. [connections_status]", name, choices)
	if(!choice || QDELETED(src) || !controls_available(user, source))
		return
	if(cached_revision != GLOB.stationtrauma_plant_revision)
		rebuild_plant()
	if(choice == "SCRAM")
		plant.scram()
		return
	if(choice == "Сброс защиты")
		if(can_service() && is_operational && !topology_error)
			plant.tripped = FALSE
		return
	if(choice == "Насосы: включить" || choice == "Насосы: выключить")
		for(var/obj/machinery/stationtrauma_reactor_pipe/pump as anything in GLOB.stationtrauma_plant_pipes)
			if(pump.plant_id == plant_id && pump.pumping)
				pump.on = choice == "Насосы: включить"
				pump.update_use_power(pump.on ? ACTIVE_POWER_USE : IDLE_POWER_USE)
				pump.update_appearance()
		stationtrauma_plant_changed()
		return
	if(choice == "Холодный дренаж в бак")
		if(can_service() && part_ready("reservoir") && route(src, "вода слева", parts["reservoir"], "вода справа", ST_PLANT_WATER, TRUE))
			plant.core.move_water(plant.reserve, plant.core.water)
		return
	if(choice == "Аварийное охлаждение" || choice == "Турбина: включить/выключить")
		var/obj/machinery/power/stationtrauma_plant_machine/part = parts[choice == "Аварийное охлаждение" ? "cooler" : "turbine"]
		if(!QDELETED(part))
			part.enabled = !part.enabled
			balloon_alert(user, part.enabled ? "включено" : "выключено")
		return
	var/list/outputs = list("Мощность 25%" = 0.25, "Мощность 50%" = 0.5, "Мощность 75%" = 0.75, "Мощность 100%" = 1)
	if(!outputs[choice] || !is_operational || plant.tripped || QDELETED(fuel_rod) || fuel_rod.fuel_remaining <= 0 || QDELETED(control_rod) || plant.core.water < 10 || plant.core_temperature >= ST_PLANT_SCRAM || topology_error)
		balloon_alert(user, "запуск запрещён")
		return
	plant.demand = outputs[choice]
	plant.running = TRUE

/** Validate location again after a modal prompt, including the console's power and pairing. */
/obj/machinery/power/stationtrauma_reactor/proc/controls_available(mob/living/user, atom/source)
	if(QDELETED(user) || QDELETED(source) || !user.Adjacent(source) || !user.can_perform_action(source, NEED_DEXTERITY | NEED_HANDS))
		return FALSE
	if(source == src)
		return TRUE
	var/obj/machinery/computer/stationtrauma_reactor/console = source
	return istype(console) && console.is_operational && console.plant_id == plant_id

/obj/machinery/power/stationtrauma_reactor/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stationtrauma_fuel_rod) && !istype(tool, /obj/item/stationtrauma_control_rod))
		return ..()
	if(!can_service())
		balloon_alert(user, "сначала остановите и охладите")
		return ITEM_INTERACT_BLOCKING
	if((istype(tool, /obj/item/stationtrauma_fuel_rod) && fuel_rod) || (istype(tool, /obj/item/stationtrauma_control_rod) && control_rod))
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/stationtrauma_fuel_rod))
		fuel_rod = tool
	else
		control_rod = tool
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/stationtrauma_reactor/crowbar_act(mob/living/user, obj/item/tool)
	if(!can_service())
		balloon_alert(user, "сначала остановите и охладите")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/removed = fuel_rod ? fuel_rod : control_rod
	if(!removed || !tool.use_tool(src, user, 1 SECONDS, volume = 30))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || !can_service() || QDELETED(removed) || removed.loc != src)
		return ITEM_INTERACT_BLOCKING
	if(removed == fuel_rod)
		fuel_rod = null
	else
		control_rod = null
	removed.forceMove(drop_location())
	return ITEM_INTERACT_SUCCESS

/** Native powered console paired with a single plant_id. */
/obj/machinery/computer/stationtrauma_reactor
	name = "управление реакторной установкой"
	icon = 'icons/obj/machines/computer.dmi'
	generate_map_preview = FALSE
	icon_screen = "power"
	icon_keyboard = "power_key"
	/// Matches every machine and pipe belonging to the installation.
	var/plant_id = "main"

/obj/machinery/computer/stationtrauma_reactor/attack_hand(mob/living/user, list/modifiers)
	if(..() || !is_operational)
		return
	var/obj/machinery/power/stationtrauma_reactor/found
	for(var/obj/machinery/power/stationtrauma_reactor/reactor as anything in GLOB.stationtrauma_plant_parts)
		if(!istype(reactor) || reactor.plant_id != plant_id)
			continue
		if(found)
			balloon_alert(user, "одинаковые ID реакторов")
			return
		found = reactor
	if(found)
		found.show_controls(user, src)
	else
		balloon_alert(user, "реактор не найден")
