/** Finite local inventory; steam is measured as the liquid volume it will condense into. */
/datum/stationtrauma_plant_inventory
	var/water = 0
	var/water_capacity = 1200 * ST_PLANT_CAPACITY_SCALE
	var/steam = 0
	var/steam_capacity = 80 * ST_PLANT_CAPACITY_SCALE
	/// Enthalpy above the reference liquid state, not an environmental temperature.
	var/steam_energy = 0

/** Move liquid without creating water when a destination fills. */
/datum/stationtrauma_plant_inventory/proc/move_water(datum/stationtrauma_plant_inventory/target, amount)
	amount = max(0, min(amount, water, target.water_capacity - target.water))
	water -= amount
	target.water += amount
	return amount

/** Paired mass/energy transfer preserves a partly filled steam reservoir's enthalpy. */
/datum/stationtrauma_plant_inventory/proc/move_steam(datum/stationtrauma_plant_inventory/target, amount, efficiency = 0)
	amount = max(0, min(amount, steam, target.steam_capacity - target.steam))
	if(!amount)
		return 0
	var/transferred_energy = steam_energy * amount / steam
	steam -= amount
	steam_energy = max(0, steam_energy - transferred_energy)
	target.steam += amount
	target.steam_energy += transferred_energy * (1 - efficiency)
	return transferred_energy * efficiency

/** The whole installation has one small physical state, advanced by its reactor only. */
/datum/stationtrauma_plant_state
	var/datum/stationtrauma_plant_inventory/core
	var/datum/stationtrauma_plant_inventory/turbine
	var/datum/stationtrauma_plant_inventory/condenser
	var/datum/stationtrauma_plant_inventory/reserve
	var/core_temperature = ST_PLANT_AMBIENT
	var/core_heat_capacity = 2000000 * ST_PLANT_CAPACITY_SCALE
	/// Thermal rating supplies the turbine nameplate at its conversion efficiency.
	var/rated_heat = ST_PLANT_NOMINAL_POWER / ST_PLANT_TURBINE_EFFICIENCY
	var/decay_heat = 0
	var/running = FALSE
	var/demand = 0
	var/tripped = FALSE
	var/thermal_damage = 0
	var/condenser_heat = 0
	var/cooler_heat = 0
	var/condenser_buffer = 500 * ST_PLANT_WATER_HEAT * ST_PLANT_CAPACITY_SCALE
	var/cooler_buffer = 1000 * ST_PLANT_WATER_HEAT * ST_PLANT_CAPACITY_SCALE
	var/power = 0
	var/steam_flow = 0
	var/condensed_flow = 0
	var/cooler_power = 0
	/// Accounting sinks remain explicit; rejected heat never changes ocean/floodwater.
	var/rejected_heat = 0
	var/electrical_energy = 0
	var/fuel_energy = 0

/datum/stationtrauma_plant_state/New()
	core = new
	core.water = 600 * ST_PLANT_CAPACITY_SCALE
	core.steam_capacity = 40 * ST_PLANT_CAPACITY_SCALE
	turbine = new
	turbine.water_capacity = 0
	condenser = new
	condenser.water = 600 * ST_PLANT_CAPACITY_SCALE
	condenser.steam_capacity = 120 * ST_PLANT_CAPACITY_SCALE
	reserve = new
	reserve.water = 1000 * ST_PLANT_CAPACITY_SCALE
	reserve.water_capacity = 3000 * ST_PLANT_CAPACITY_SCALE
	reserve.steam_capacity = 0

/datum/stationtrauma_plant_state/Destroy()
	QDEL_NULL(core)
	QDEL_NULL(turbine)
	QDEL_NULL(condenser)
	QDEL_NULL(reserve)
	return ..()

/** Only this installation's inventories participate in its mass ledger. */
/datum/stationtrauma_plant_state/proc/total_water()
	return core.water + core.steam + turbine.steam + condenser.water + condenser.steam + reserve.water

/** Stored energy excludes unrealised future decay, which is booked when produced. */
/datum/stationtrauma_plant_state/proc/stored_energy()
	return (core_temperature - ST_PLANT_AMBIENT) * core_heat_capacity + core.steam_energy + turbine.steam_energy + condenser.steam_energy + condenser_heat + cooler_heat

/** A bounded gauge gives backpressure without a second per-pipe gas simulation. */
/datum/stationtrauma_plant_state/proc/pressure(datum/stationtrauma_plant_inventory/inventory)
	return 20 * inventory.steam / inventory.steam_capacity

/** An automatic trip latches until the operator resets a cool, depressurised core. */
/datum/stationtrauma_plant_state/proc/scram(automatic = FALSE)
	running = FALSE
	demand = 0
	tripped = tripped || automatic

/** Advance conserved local flows; rates are already cached from physical pipe connections. */
/datum/stationtrauma_plant_state/proc/advance(seconds, fuel_seconds, steam_rate, exhaust_rate, feed_rate, reserve_rate, condenser_sea_rate, cooler_rate, cooler_sea_rate)
	power = 0
	steam_flow = 0
	condensed_flow = 0
	cooler_power = 0
	thermal_damage = 0
	if(seconds <= 0)
		return 0
	if(running && (core_temperature >= ST_PLANT_SCRAM || pressure(core) >= 16 || core.water < ST_PLANT_CAPACITY_SCALE || fuel_seconds <= 0))
		scram(TRUE)
	var/fuel_used = running ? min(fuel_seconds, demand * seconds) : 0
	var/heat = rated_heat * fuel_used
	decay_heat = max(decay_heat, heat / seconds * 0.08)
	var/residual = decay_heat * (1 - 0.998 ** seconds) / -log(0.998)
	decay_heat *= 0.998 ** seconds
	heat += residual
	fuel_energy += heat
	core_temperature += heat / core_heat_capacity

	// Liquid is reference-temperature condensate; boiling accounts for its heating and vaporisation.
	var/boiling_energy = min(max(0, (core_temperature - ST_PLANT_BOILING) * core_heat_capacity), max(0, core_temperature - ST_PLANT_BOILING) * 80000 * ST_PLANT_CAPACITY_SCALE * seconds)
	var/boiled = max(0, min(core.water, core.steam_capacity - core.steam, boiling_energy / ST_PLANT_VAPOR_ENERGY))
	core.water -= boiled
	core.steam += boiled
	core.steam_energy += boiled * ST_PLANT_VAPOR_ENERGY
	core_temperature -= boiled * ST_PLANT_VAPOR_ENERGY / core_heat_capacity

	var/turbine_flow = min(steam_rate * seconds, max(0, pressure(core) - pressure(turbine)) * seconds * 2 * ST_PLANT_CAPACITY_SCALE)
	var/old_steam = core.steam
	var/generated = core.move_steam(turbine, turbine_flow, ST_PLANT_TURBINE_EFFICIENCY)
	var/exported = min(generated, ST_PLANT_NOMINAL_POWER * seconds)
	// Energy above the generator rating stays in the exhaust for the condenser to reject.
	turbine.steam_energy += generated - exported
	steam_flow = (old_steam - core.steam) / seconds
	power = exported / seconds
	electrical_energy += exported
	turbine.move_steam(condenser, min(exhaust_rate * seconds, max(0, pressure(turbine) - pressure(condenser)) * seconds * 4 * ST_PLANT_CAPACITY_SCALE))

	if(condenser.steam > 0)
		var/per_litre = condenser.steam_energy / condenser.steam
		var/condensed = min(condenser.steam, condenser.water_capacity - condenser.water, max(0, condenser_buffer * 70 - condenser_heat) / max(1, per_litre))
		var/condensation_energy = condensed * per_litre
		condenser.steam -= condensed
		condenser.steam_energy = max(0, condenser.steam_energy - condensation_energy)
		condenser.water += condensed
		condenser_heat += condensation_energy
		condensed_flow = condensed / seconds
	var/condenser_rejection = min(condenser_heat, condenser_sea_rate * ST_PLANT_WATER_HEAT * 20 * seconds)
	condenser_heat -= condenser_rejection
	rejected_heat += condenser_rejection

	var/returned = condenser.move_water(core, feed_rate * seconds)
	reserve.move_water(core, min(reserve_rate * seconds, max(0, 600 * ST_PLANT_CAPACITY_SCALE - core.water), max(0, max(feed_rate, reserve_rate) * seconds - returned)))
	var/coolant_temperature = ST_PLANT_AMBIENT + cooler_heat / cooler_buffer
	var/cooling_energy = min(max(0, (core_temperature - coolant_temperature) / (1 / core_heat_capacity + 1 / cooler_buffer)), max(0, core_temperature - coolant_temperature) * cooler_rate * ST_PLANT_WATER_HEAT * seconds, max(0, cooler_buffer * 120 - cooler_heat))
	core_temperature -= cooling_energy / core_heat_capacity
	cooler_heat += cooling_energy
	cooler_power = cooling_energy / seconds
	var/cooler_rejection = min(cooler_heat, cooler_sea_rate * ST_PLANT_WATER_HEAT * 20 * seconds)
	cooler_heat -= cooler_rejection
	rejected_heat += cooler_rejection
	if(core_temperature >= ST_PLANT_SCRAM || pressure(core) >= 16 || core.water < ST_PLANT_CAPACITY_SCALE)
		scram(TRUE)
	if(core_temperature >= ST_PLANT_DAMAGE)
		thermal_damage = 5 * seconds
	return fuel_used
