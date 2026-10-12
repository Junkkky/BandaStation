#include "../_defines.dm"

/area/space/ocean
	name = "Deep ocean"
	static_lighting = TRUE
	base_lighting_alpha = 0
	requires_power = FALSE
	always_unpowered = FALSE

/area/space/ocean/Initialize(mapload)
	. = ..()
	for(var/turf/open/space/tile in src)
		tile.space_lit = FALSE
		tile.update_appearance(UPDATE_OVERLAYS)

/turf/open/space/enable_starlight()
	if(!space_lit)
		return
	if(!light_on)
		set_light(l_on = TRUE, l_range = GLOB.starlight_range, l_power = GLOB.starlight_power, l_color = GLOB.starlight_color)
		GLOB.starlight += src

/// Space-compatible ocean: a native parallax mask below a translucent water overlay.
/turf/open/space/ocean
	name = "ocean"
	desc = "Толща воды. Без источника воздуха здесь не выжить."
	icon = 'modular_bandastation/underwater/icons/water.dmi'
	icon_state = MAP_SWITCH("ocean_mask", "volume")
	baseturfs = /turf/open/space/ocean
	space_lit = FALSE
	light_range = 0
	temperature = FLOOD_WATER_TEMPERATURE
	initial_gas_mix = GAS_O2 + "=22;" + GAS_N2 + "=82;TEMP=277.15"
	/// The reservoir maintains this depth. Shallower subtypes represent a surface shoreline.
	var/water_depth = FLOOD_WATER_MAX_DEPTH
	var/water_pressure = STATIONTRAUMA_WATER_OCEAN_PRESSURE * 100

/turf/open/space/ocean/Initialize(mapload)
	. = ..()
	// PLANE_SPACE needs opaque pixels for the native parallax whitifier, not an empty icon.
	// Also replace the mapper preview when compiling directly without CBT.
	icon_state = "ocean_mask"
	update_appearance(UPDATE_OVERLAYS)
	var/area/ocean_area = loc
	if(SSlighting.initialized && !lighting_object && ocean_area.static_lighting)
		lighting_build_overlay()
	// The ocean gets its own cold environment; never change the shared room-air mixture.
	if(!SSair.planetary[initial_gas_mix])
		var/datum/gas_mixture/immutable/planetary/environment = new
		environment.parse_string_immutable(initial_gas_mix)
		SSair.planetary[initial_gas_mix] = environment
	air = SSair.planetary[initial_gas_mix]
	var/datum/component/floodwater/water = set_water_depth(water_depth, TRUE)
	water.reservoir_pressure = water_pressure

/turf/open/space/ocean/remove_air(amount)
	// Space normally returns no breath at all; surface water must supply its environment.
	return air.remove(amount)

/turf/open/space/ocean/assume_air(datum/gas_mixture/giver)
	return !!giver

/turf/open/space/ocean/enable_starlight()
	return

/// Diagonal corners need the same water column, without space's starlight overlays.
/turf/open/space/ocean/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	underlay_appearance.icon = 'modular_bandastation/underwater/icons/water.dmi'
	underlay_appearance.icon_state = "ocean_mask"
	SET_PLANE(underlay_appearance, PLANE_SPACE, asking_turf)
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	if(water?.water_overlay)
		var/mutable_appearance/volume = new(water.water_overlay)
		SET_PLANE(volume, FLOOR_PLANE, asking_turf)
		underlay_appearance.overlays += volume
	return TRUE

/turf/open/space/ocean/shallow
	desc = "Мелкая вода."
	water_depth = 30
	water_pressure = ONE_ATMOSPHERE + 30 * FLOOD_WATER_KPA_PER_CM

/turf/open/space/ocean/waist
	desc = "Вода по пояс."
	water_depth = 80
	water_pressure = ONE_ATMOSPHERE + 80 * FLOOD_WATER_KPA_PER_CM

/turf/open/space/ocean/deep
	desc = "Глубокая вода. Здесь приходится плыть."
	water_depth = 150
	water_pressure = ONE_ATMOSPHERE + 150 * FLOOD_WATER_KPA_PER_CM

/// Add water without replacing the floor, its contents, area, or atmosphere. Zero drains it.
/turf/open/proc/set_water_depth(new_depth, infinite_source = null, water_temperature = null, notify_neighbors = TRUE)
	if(!isnum(new_depth) || !IS_FINITE(new_depth) || istype(src, /turf/open/water))
		return null
	if(!isnull(water_temperature) && (!isnum(water_temperature) || !IS_FINITE(water_temperature) || water_temperature < 0))
		return null
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	new_depth = clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH)
	if(!new_depth)
		if(water)
			qdel(water)
		return null
	if(!water)
		return AddComponent(/datum/component/floodwater, new_depth, !!infinite_source, isnull(water_temperature) ? FLOOD_WATER_TEMPERATURE : water_temperature)
	if(!isnull(infinite_source) && water.infinite_source != infinite_source)
		water.infinite_source = infinite_source
		SSfloodwater.pressure.cells -= water
		SSfloodwater.pressure.wet_air -= water
		SSfloodwater.pressure.dirty = TRUE
		water.ocean_pressure = 0
		if(!infinite_source)
			SSfloodwater.pressure.wet_air[water] = TRUE
		water.update_pressure_connection()
		SEND_SIGNAL(src, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)
	if(!isnull(water_temperature))
		water.temperature = water_temperature
	water.set_depth(new_depth, notify_neighbors)
	return water

/turf/open/proc/get_water_depth()
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	return water?.depth || 0

/// Returns litres actually accepted; floor water and TG plumbing use the same volume conversion.
/turf/open/proc/add_water(volume, water_temperature)
	if(!isnum(volume) || !IS_FINITE(volume) || volume <= 0 || !isnum(water_temperature) || !IS_FINITE(water_temperature) || water_temperature < 0 || istype(src, /turf/open/water))
		return 0
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	if(water?.infinite_source)
		return 0
	var/old_volume = get_water_depth() * FLOOD_WATER_LITRES_PER_CM
	var/accepted = min(volume, FLOOD_WATER_MAX_DEPTH * FLOOD_WATER_LITRES_PER_CM - old_volume)
	if(accepted <= 0)
		return 0
	var/new_depth = (old_volume + accepted) / FLOOD_WATER_LITRES_PER_CM
	if(new_depth == get_water_depth())
		return 0
	var/mixed_temperature = water ? (old_volume * water.temperature + accepted * water_temperature) / (old_volume + accepted) : water_temperature
	set_water_depth(new_depth, FALSE, mixed_temperature)
	return accepted

/// Only water crosses the floor boundary; other reagents remain in their native holder.
/turf/open/proc/receive_water(datum/reagents/source, volume)
	if(QDELETED(source) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0)
		return 0
	var/free_space = (FLOOD_WATER_MAX_DEPTH - get_water_depth()) * FLOOD_WATER_LITRES_PER_CM
	var/accepted = add_water(stationtrauma_water_transfer_amount(source, volume, free_space), source.chem_temp)
	if(accepted)
		source.remove_reagent(/datum/reagent/water, accepted)
	return accepted

// TG rounds holder totals to centilitres and deletes smaller tails; retain those tails until a complete transfer fits.
/proc/stationtrauma_water_transfer_amount(datum/reagents/source, volume, free_space)
	if(QDELETED(source) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0 || free_space <= 0)
		return 0
	var/available = source.get_reagent_amount(/datum/reagent/water)
	var/amount = min(volume, available, free_space)
	if(amount >= available)
		return available
	amount = FLOOR(amount, CHEMICAL_QUANTISATION_LEVEL)
	if(available - amount < CHEMICAL_VOLUME_ROUNDING)
		amount = max(0, FLOOR(available - CHEMICAL_VOLUME_ROUNDING, CHEMICAL_QUANTISATION_LEVEL))
	return amount

/proc/transfer_stationtrauma_water(datum/reagents/source, datum/reagents/receiver, volume)
	if(QDELETED(receiver) || receiver == source)
		return 0
	var/free_space = receiver.maximum_volume
	for(var/datum/reagent/reagent as anything in receiver.reagent_list)
		free_space -= reagent.volume
	var/amount = stationtrauma_water_transfer_amount(source, volume, free_space)
	if(amount <= 0)
		return 0
	var/accepted = store_stationtrauma_water(receiver, amount, source.chem_temp)
	if(accepted)
		source.remove_reagent(/datum/reagent/water, accepted)
	return accepted

/// Preserve fractional hydraulic volumes that native chemistry would quantise away.
/proc/store_stationtrauma_water(datum/reagents/receiver, amount, water_temperature)
	var/stored_before = receiver.get_reagent_amount(/datum/reagent/water)
	var/heat_before = receiver.heat_capacity()
	var/temperature_before = receiver.chem_temp
	var/accepted = receiver.add_reagent(/datum/reagent/water, max(amount, CHEMICAL_VOLUME_ROUNDING), reagtemp = water_temperature, no_react = TRUE)
	var/datum/reagent/water/collected = receiver.has_reagent(/datum/reagent/water)
	if(!collected || (!accepted && amount >= CHEMICAL_QUANTISATION_LEVEL))
		return 0
	collected.volume = stored_before + amount
	receiver.set_temperature((heat_before * temperature_before + collected.specific_heat * amount * water_temperature) / receiver.heat_capacity())
	receiver.total_volume = 0
	for(var/datum/reagent/reagent as anything in receiver.reagent_list)
		receiver.total_volume += reagent.volume
	return amount

/// One component per wet turf; only unequal, connected neighbours enter SSfloodwater's work queue.
/datum/component/floodwater
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/depth = 0
	var/infinite_source = FALSE
	var/temperature = FLOOD_WATER_TEMPERATURE
	var/stage = -1
	var/mask_state
	var/mutable_appearance/water_overlay
	var/show_puddle
	/// Cardinal direction bits are bounded positional indices (N=1, S=2, E=4, W=8).
	var/list/flow_edge_keys
	/// Cardinal masks; only edges between two live water components can reuse a geometry result.
	var/flow_geometry_known = NONE
	var/flow_geometry_open = NONE

/datum/component/floodwater/Initialize(initial_depth, is_source = FALSE, initial_temperature = FLOOD_WATER_TEMPERATURE)
	// Existing static water already owns immersion/wetness elements.
	if(!isopenturf(parent) || istype(parent, /turf/open/water))
		return COMPONENT_INCOMPATIBLE
	depth = clamp(initial_depth, 0, FLOOD_WATER_MAX_DEPTH)
	infinite_source = is_source
	temperature = initial_temperature
	show_puddle = prob(30)

/datum/component/floodwater/RegisterWithParent()
	flow_edge_keys = new/list(8)
	RegisterSignal(parent, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, PROC_REF(on_atmos_update))
	RegisterSignal(parent, COMSIG_TURF_CHANGE, PROC_REF(on_turf_change))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(add_water_overlay))
	RegisterSignal(parent, COMSIG_TURF_PREPARE_STEP_SOUND, PROC_REF(water_steps))
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(examine_depth))
	RegisterSignals(parent, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(on_entered))
	RegisterSignal(parent, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	var/turf/open/tile = parent
	for(var/obj/obstacle in tile)
		watch_pressure_obstacle(obstacle)
	tile.AddElement(/datum/element/watery_tile)
	if(isspaceturf(tile))
		tile.AddElement(/datum/element/forced_gravity, STANDARD_GRAVITY, TRUE)
	last_air_pressure = tile.air?.return_pressure() || 0
	if(!infinite_source)
		SSfloodwater.pressure.wet_air[src] = TRUE
	on_atmos_update()
	update_depth()
	wake()
	SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED, src, TRUE)
	if(infinite_source || isspaceturf(parent))
		SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)

/datum/component/floodwater/UnregisterFromParent()
	SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED, src, FALSE)
	if(infinite_source || isspaceturf(parent))
		SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)
	SSfloodwater.active -= src
	UnregisterSignal(parent, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_TURF_CHANGE, COMSIG_ATOM_UPDATE_OVERLAYS, COMSIG_TURF_PREPARE_STEP_SOUND, COMSIG_ATOM_EXAMINE, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON))
	var/turf/open/tile = parent
	SSfloodwater.pressure.wet_air -= src
	if((infinite_source && pressure_boundary) || SSfloodwater.pressure.cells[src])
		SSfloodwater.pressure.dirty = TRUE
	SSfloodwater.pressure.cells -= src
	SSfloodwater.pressure.pending -= src
	tile.RemoveElement(/datum/element/immerse/floodwater, mask_state, 140)
	tile.RemoveElement(/datum/element/watery_tile)
	if(isspaceturf(tile))
		tile.RemoveElement(/datum/element/forced_gravity, STANDARD_GRAVITY, TRUE)
	tile.cut_overlay(water_overlay)
	for(var/mob/living/occupant in tile)
		occupant.remove_status_effect(/datum/status_effect/floodwater)
		occupant.refresh_gravity()
	wake_neighbours()

/datum/component/floodwater/proc/set_depth(new_depth, notify_neighbors = TRUE)
	depth = clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH)
	if(!depth)
		qdel(src)
		return
	update_depth()
	wake()
	if(notify_neighbors)
		wake_neighbours()

/// Remove only an accepted transfer; a null receiver is used for floor-to-floor flow. Pumps cannot drain an ocean.
/datum/component/floodwater/proc/remove_water(volume, datum/reagents/receiver = null, allow_ocean = FALSE)
	if(!isnum(volume) || !IS_FINITE(volume) || volume <= 0 || (infinite_source && !allow_ocean))
		return 0
	var/removed = min(volume, depth * FLOOD_WATER_LITRES_PER_CM)
	if(receiver)
		if(QDELETED(receiver))
			return 0
		removed = FLOOR(removed, CHEMICAL_QUANTISATION_LEVEL)
		removed = receiver.add_reagent(/datum/reagent/water, removed, reagtemp = temperature, no_react = TRUE)
	if(removed <= 0)
		return 0
	if(!infinite_source)
		var/remaining_depth = max(0, depth - removed / FLOOD_WATER_LITRES_PER_CM)
		if(!remaining_depth && show_puddle && !isspaceturf(parent))
			var/turf/open/tile = parent
			tile.MakeSlippery(TURF_WET_WATER, 1 MINUTES, 0, 1 MINUTES)
		set_depth(remaining_depth)
	return removed

/// Visual/behaviour changes only happen when crossing a depth threshold.
/datum/component/floodwater/proc/update_depth()
	var/new_stage = depth <= 0.6 && !infinite_source ? 0 : depth >= FLOOD_WATER_SUBMERGED ? 4 : depth >= FLOOD_WATER_DEEP ? 3 : depth >= FLOOD_WATER_WAIST ? 2 : 1
	if(stage == new_stage)
		return
	update_pressure_connection()
	var/turf/open/tile = parent
	if(mask_state)
		tile.RemoveElement(/datum/element/immerse/floodwater, mask_state, 140)
	stage = new_stage
	mask_state = !stage ? null : stage == 4 ? "submerged" : stage >= 2 ? "immerse_deep" : "immerse"
	if(stage)
		tile.AddElement(/datum/element/immerse/floodwater, mask_state, 140)
	tile.cut_overlay(water_overlay)
	water_overlay = null
	if(!stage)
		if(show_puddle)
			water_overlay = mutable_appearance('icons/effects/water.dmi', "wet_floor_static")
			water_overlay.plane = MUTATE_PLANE(FLOOR_PLANE, tile)
			tile.add_overlay(water_overlay)
		return
	// Flooded floors need a stronger water column; the exterior must keep the seabed visible.
	var/water_alpha = isspaceturf(tile) ? 16 + stage * 8 : 32 + stage * 24
	water_overlay = mutable_appearance('modular_bandastation/underwater/icons/water.dmi', "volume", TOPDOWN_WATER_LEVEL_LAYER, alpha = water_alpha)
	water_overlay.plane = MUTATE_PLANE(FLOOR_PLANE, tile)
	tile.add_overlay(water_overlay)
	for(var/mob/living/occupant in tile)
		if(occupant.flags_1 & INITIALIZED_1)
			on_entered(tile, occupant)

/datum/component/floodwater/proc/on_entered(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isobj(arrived) && arrived.can_atmos_pass != ATMOS_PASS_YES)
		watch_pressure_obstacle(arrived)
		on_atmos_update()
	if(!isliving(arrived) || !(arrived.flags_1 & INITIALIZED_1))
		return
	var/mob/living/swimmer = arrived
	swimmer.apply_status_effect(/datum/status_effect/floodwater)
	var/datum/status_effect/floodwater/effect = swimmer.has_status_effect(/datum/status_effect/floodwater)
	effect?.update_water()
	swimmer.refresh_gravity()

/datum/component/floodwater/proc/watch_pressure_obstacle(obj/obstacle)
	if(obstacle.can_atmos_pass == ATMOS_PASS_YES)
		return
	RegisterSignals(obstacle, list(COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING), PROC_REF(on_atmos_update), override = TRUE)
	RegisterSignal(obstacle, COMSIG_ATOM_DENSITY_CHANGED, (istype(obstacle, /obj/machinery/door) || istype(obstacle, /obj/structure/fluff/airlock_filler)) ? PROC_REF(on_door_density) : PROC_REF(on_atmos_update), override = TRUE)

/datum/component/floodwater/proc/on_exited(turf/source, atom/movable/departed)
	SIGNAL_HANDLER
	if(!isobj(departed) || departed.can_atmos_pass == ATMOS_PASS_YES)
		return
	UnregisterSignal(departed, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING))
	on_atmos_update()

/datum/component/floodwater/proc/on_door_density(obj/door)
	SIGNAL_HANDLER
	on_atmos_update()
	if(!door.density || (door.flags_1 & ON_BORDER_1) || infinite_source || door.loc != parent)
		return
	var/turf/open/tile = parent
	var/volume = depth * FLOOD_WATER_LITRES_PER_CM
	var/water_temperature = temperature
	var/obj/machinery/door/filled_door
	if(istype(door, /obj/structure/fluff/airlock_filler))
		var/obj/structure/fluff/airlock_filler/filler = door
		filled_door = filler.filled_airlock
	var/list/destinations = list()
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(tile, direction)
		if(!isopenturf(neighbor) || neighbor.blocks_air || istype(neighbor, /turf/open/water))
			continue
		var/passable = TRUE
		for(var/obj/obstacle in tile.contents + neighbor.contents)
			if(obstacle == door || obstacle == filled_door)
				if(obstacle.loc != neighbor)
					continue
			if(!CANATMOSPASS(obstacle, obstacle.loc == tile ? neighbor : tile, FALSE))
				passable = FALSE
				break
		if(!passable)
			continue
		var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
		if(water?.infinite_source)
			volume = 0
			break
		destinations |= neighbor.stationtrauma_water_room()
	for(var/turf/open/destination as anything in destinations)
		if(volume <= 0)
			break
		volume -= destination.add_water(volume, water_temperature)
	if(volume > 0)
		// A completely full sealed compartment still needs a recoverable displaced volume.
		var/obj/item/stationtrauma_water_canister/remainder = new(tile)
		remainder.create_reagents(volume, NO_REACT)
		remainder.reagents.add_reagent(/datum/reagent/water, volume, reagtemp = water_temperature, no_react = TRUE)
	tile.set_water_depth(0)

/datum/component/floodwater/proc/add_water_overlay(atom/source, list/overlays)
	SIGNAL_HANDLER
	if(water_overlay)
		overlays += water_overlay

/datum/component/floodwater/proc/water_steps(turf/source, list/steps)
	SIGNAL_HANDLER
	steps[FOOTSTEP_MOB_SHOE] = FOOTSTEP_WATER
	steps[FOOTSTEP_MOB_BAREFOOT] = FOOTSTEP_WATER
	steps[FOOTSTEP_MOB_CLAW] = FOOTSTEP_WATER
	steps[FOOTSTEP_MOB_HEAVY] = FOOTSTEP_WATER
	return FOOTSTEP_OVERRIDEN

/datum/component/floodwater/proc/examine_depth(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("Глубина воды: [round(depth, 0.1)] см[ infinite_source ? " (океан)" : ""]. Температура: [round(temperature - T0C, 0.1)] °C.")

/datum/component/floodwater/proc/affects(mob/living/swimmer)
	return depth >= FLOOD_WATER_SUBMERGED || (!(swimmer.movement_type & MOVETYPES_NOT_TOUCHING_GROUND) && !HAS_TRAIT(swimmer, TRAIT_MOB_ELEVATED))

/datum/component/floodwater/proc/head_underwater(mob/living/swimmer)
	return affects(swimmer) && (depth >= FLOOD_WATER_SUBMERGED || (depth >= FLOOD_WATER_WAIST && (swimmer.body_position == LYING_DOWN || swimmer.mob_size < MOB_SIZE_HUMAN)))

/datum/component/floodwater/proc/on_turf_change(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(restore_floodwater), depth, temperature)

/// The old component is deleted with its turf, so the callback must not depend on its fields.
/proc/restore_floodwater(old_depth, old_temperature, turf/new_tile)
	if(isopenturf(new_tile) && !istype(new_tile, /turf/open/water))
		var/turf/open/open_tile = new_tile
		if(!open_tile.GetComponent(/datum/component/floodwater))
			open_tile.set_water_depth(old_depth, FALSE, old_temperature)

/// Extend the native immersion element only for completely submerged sprites.
/datum/element/immerse/floodwater/generate_immerse_mask(width, height, is_below_water)
	if(mask_icon != "submerged")
		return ..()
	var/key = "[width]-[height]"
	if(!immersion_masks[key])
		var/icon/mask = icon('icons/effects/alphacolors.dmi', "white")
		mask.Scale(max(width, ICON_SIZE_X), max(height, ICON_SIZE_Y))
		immersion_masks[key] = mutable_appearance(mask, alpha = alpha)
	return immersion_masks[key]
