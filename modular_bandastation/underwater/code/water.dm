#include "../_defines.dm"

/area/space/ocean
	name = "Deep ocean"
	static_lighting = TRUE
	base_lighting_alpha = 0
	requires_power = FALSE
	always_unpowered = FALSE
	area_flags = NONE
	default_gravity = STANDARD_GRAVITY
	// A null choice suppresses inherited space tracks; the occupant owns the underwater loop.
	ambientsounds = list(null)

/** Ocean column above another deck, retaining the native view through its floor. */
/area/space/ocean/openspace
	name = "Deep ocean (open below)"

/area/space/ocean/Initialize(mapload)
	. = ..()
	for(var/turf/open/space/tile in src)
		if(!tile.space_lit)
			continue
		tile.space_lit = FALSE
		tile.update_appearance(UPDATE_OVERLAYS)

/** Stop an old area's ambient track as well as preventing new space tracks in the ocean. */
/area/space/ocean/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(ismob(arrived))
		var/mob/listener = arrived
		listener.stop_sound_channel(CHANNEL_AMBIENCE)

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
	temperature = T20C
	initial_gas_mix = GAS_O2 + "=22;" + GAS_N2 + "=82;TEMP=293.15"
	/// The reservoir maintains this depth. Shallower subtypes represent a surface shoreline.
	var/water_depth = FLOOD_WATER_MAX_DEPTH
	var/water_pressure = STATIONTRAUMA_WATER_OCEAN_PRESSURE * 100

/turf/open/space/ocean/Initialize(mapload)
	. = ..()
	// PLANE_SPACE needs opaque pixels for the native parallax whitifier, not an empty icon.
	// Also replace the mapper preview when compiling directly without CBT.
	icon_state = "ocean_mask"
	update_appearance(UPDATE_OVERLAYS)
	initialize_stationtrauma_ocean(water_depth, water_pressure)

/** Both ocean turfs use one immutable atmosphere without modifying a room's shared air. */
/turf/open/proc/initialize_stationtrauma_ocean(depth, pressure)
	GLOB.ocean_parallax_levels["[z]"] = TRUE
	if(!SSair.planetary[initial_gas_mix])
		var/datum/gas_mixture/immutable/planetary/environment = new
		environment.parse_string_immutable(initial_gas_mix)
		SSair.planetary[initial_gas_mix] = environment
	air = SSair.planetary[initial_gas_mix]
	var/datum/component/floodwater/water = set_water_depth(depth, TRUE)
	// Vertical portals include deck height; the connected ocean column must have the same hydrostatic gradient.
	water.set_reservoir_pressure(pressure + GET_TURF_PLANE_OFFSET(src) * FLOOD_WATER_MAX_DEPTH * FLOOD_WATER_KPA_PER_CM)

/** Building in the ocean preserves its area instead of inheriting near-station space ambience and gravity. */
/turf/open/space/ocean/ChangeTurf(path, list/new_baseturfs, flags)
	return ..(path, new_baseturfs, flags | CHANGETURF_NO_AREA_CHANGE)

/turf/open/space/ocean/remove_air(amount)
	// Space normally returns no breath at all; surface water must supply its environment.
	return air.remove(amount)

/turf/open/space/ocean/assume_air(datum/gas_mixture/giver)
	return !!giver

/turf/open/space/ocean/enable_starlight()
	return

/** The immutable reservoir has no air state to advance; adjacent finite floors perform their own exchange. */
/turf/open/space/ocean/process_cell(fire_count)
	SSair.sleep_active_turf(src)

/// Diagonal corners need the same water column, without space's starlight overlays.
/turf/open/space/ocean/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	underlay_appearance.icon = 'modular_bandastation/underwater/icons/water.dmi'
	underlay_appearance.icon_state = "ocean_mask"
	SET_PLANE(underlay_appearance, PLANE_SPACE, asking_turf)
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	if(water?.water_overlay)
		var/mutable_appearance/volume = new(water.water_overlay.appearance)
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
/turf/open/proc/set_water_depth(new_depth, infinite_source = null, notify_neighbors = TRUE)
	if(!isnum(new_depth) || !IS_FINITE(new_depth) || istype(src, /turf/open/water))
		return null
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	new_depth = clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH)
	var/is_finite_water = isnull(infinite_source) ? !water?.infinite_source : !infinite_source
	if(is_finite_water && !isspaceturf(src) && !SSfloodwater.hybrid.publishing && !SSfloodwater.loading_ocean_levels["[z]"])
		if(water?.infinite_source)
			qdel(water)
		SSfloodwater.ensure_water_domain(src)
		return SSfloodwater.hybrid.set_depth_at(src, new_depth)
	if(!new_depth)
		if(water)
			qdel(water)
		return null
	if(!water)
		return AddComponent(/datum/component/floodwater, new_depth, !!infinite_source)
	if(!isnull(infinite_source) && water.infinite_source != infinite_source)
		water.infinite_source = infinite_source
		SEND_SIGNAL(src, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)
	water.set_depth(new_depth, notify_neighbors)
	return water

/turf/open/proc/get_water_depth()
	if(SSfloodwater.hybrid?.by_turf[src] && !isspaceturf(src))
		return SSfloodwater.hybrid.depth_at(src)
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	return water?.depth || 0

/// Gameplay callers read live aggregate values; native component fields cache the last rendered state.
/datum/component/floodwater/proc/get_depth()
	return !infinite_source && SSfloodwater.hybrid?.by_turf[parent] ? SSfloodwater.hybrid.depth_at(parent) : depth

/// Preserve the original source and puddle rendering thresholds.
/datum/component/floodwater/proc/get_stage()
	return !infinite_source && SSfloodwater.hybrid?.by_turf[parent] ? stationtrauma_water_stage(get_depth()) : stage

/// Returns litres actually accepted; floor water and TG plumbing use the same volume conversion.
/turf/open/proc/add_water(volume)
	if(!isnum(volume) || !IS_FINITE(volume) || volume <= 0 || istype(src, /turf/open/water))
		return 0
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	if(water?.infinite_source)
		return 0
	var/datum/floodwater_front_cell/cell = !isspaceturf(src) ? SSfloodwater.ensure_water_domain(src) : null
	if(cell && !SSfloodwater.hybrid.publishing)
		return SSfloodwater.hybrid.receive(cell, volume)
	var/old_volume = get_water_depth() * FLOOD_WATER_LITRES_PER_CM
	var/accepted = min(volume, FLOOD_WATER_MAX_DEPTH * FLOOD_WATER_LITRES_PER_CM - old_volume)
	if(accepted <= 0)
		return 0
	var/new_depth = (old_volume + accepted) / FLOOD_WATER_LITRES_PER_CM
	if(new_depth == get_water_depth())
		return 0
	set_water_depth(new_depth, FALSE)
	return accepted

/// Only water crosses the floor boundary; other reagents remain in their native holder.
/turf/open/proc/receive_water(datum/reagents/source, volume)
	if(QDELETED(source) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0)
		return 0
	var/free_space = (FLOOD_WATER_MAX_DEPTH - get_water_depth()) * FLOOD_WATER_LITRES_PER_CM
	var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid.by_turf[src]
	if(cell)
		free_space = cell.capacity()
	var/accepted = add_water(stationtrauma_water_transfer_amount(source, volume, free_space))
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
	var/accepted = store_stationtrauma_water(receiver, amount)
	if(accepted)
		source.remove_reagent(/datum/reagent/water, accepted)
	return accepted

/// Preserve fractional hydraulic volumes that native chemistry would quantise away.
/proc/store_stationtrauma_water(datum/reagents/receiver, amount)
	var/stored_before = receiver.get_reagent_amount(/datum/reagent/water)
	var/accepted = receiver.add_reagent(/datum/reagent/water, max(amount, CHEMICAL_VOLUME_ROUNDING), no_react = TRUE)
	var/datum/reagent/water/collected = receiver.has_reagent(/datum/reagent/water)
	if(!collected || (!accepted && amount >= CHEMICAL_QUANTISATION_LEVEL))
		return 0
	collected.volume = stored_before + amount
	receiver.total_volume = 0
	for(var/datum/reagent/reagent as anything in receiver.reagent_list)
		receiver.total_volume += reagent.volume
	return amount

/** One component per wet turf, publishing the native appearance while C owns finite water. */
/datum/component/floodwater
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/depth = 0
	var/infinite_source = FALSE
	var/stage = -1
	var/mask_state
	/// Cached mouse-transparent visual; ordinary turf overlays intercept clicks on submerged contents.
	var/obj/effect/overlay/vis/water_overlay
	var/show_puddle
	/// Empty ocean does not need per-occupant signal subscriptions until something enters it.
	var/occupant_effects = FALSE

/datum/component/floodwater/Initialize(initial_depth, is_source = FALSE)
	// Existing static water already owns immersion/wetness elements.
	if(!isopenturf(parent) || istype(parent, /turf/open/water))
		return COMPONENT_INCOMPATIBLE
	depth = clamp(initial_depth, 0, FLOOD_WATER_MAX_DEPTH)
	infinite_source = is_source
	show_puddle = prob(30)

/datum/component/floodwater/RegisterWithParent()
	RegisterSignal(parent, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, PROC_REF(on_atmos_update))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(add_water_overlay))
	var/turf/open/tile = parent
	if(infinite_source)
		RegisterSignal(parent, COMSIG_TURF_CHANGE, PROC_REF(ocean_replaced))
		if(!SSfloodwater.loading_ocean_levels["[tile.z]"])
			for(var/direction in GLOB.cardinals)
				restore_stationtrauma_hull(get_step(tile, direction))
	else
		SSfloodwater.ensure_water_domain(tile)
	if(isspaceturf(tile))
		RegisterSignals(tile, list(COMSIG_ATOM_HAS_GRAVITY, COMSIG_TURF_HAS_GRAVITY), PROC_REF(water_gravity))
		ADD_TRAIT(tile, TRAIT_FORCED_GRAVITY, "floodwater")
	if(!istype(tile, /turf/open/space/ocean) && !istype(tile, /turf/open/space/openspace/ocean))
		enable_occupant_effects()
	else
		RegisterSignals(tile, list(COMSIG_ATOM_ABSTRACT_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(activate_occupant_effects))
		for(var/atom/movable/occupant as anything in tile)
			activate_occupant_effects(tile, occupant)
	on_atmos_update()
	update_depth()
	wake()
	SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED, src, TRUE)
	if(infinite_source || isspaceturf(parent))
		SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)

/** Keep the native forced-gravity signal/trait contract without a second element on every ocean tile. */
/datum/component/floodwater/proc/water_gravity(datum/source, atom/other, list/gravities)
	SIGNAL_HANDLER
	gravities += STANDARD_GRAVITY
	return TRUE

/** Lighting, relays and observers never need immersion or wetness subscriptions. */
/datum/component/floodwater/proc/activate_occupant_effects(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(occupant_effects || istype(arrived, /atom/movable/lighting_object) || is_type_in_typecache(arrived, GLOB.immerse_ignored_movable))
		return
	enable_occupant_effects()
	// A replacement subscriber does not receive the initialization signal already being dispatched.
	on_entered(source, arrived)

/** Activate once, including objects already present when a template or a shuttle places this turf. */
/datum/component/floodwater/proc/enable_occupant_effects()
	if(occupant_effects)
		return
	occupant_effects = TRUE
	var/turf/open/tile = parent
	UnregisterSignal(tile, list(COMSIG_ATOM_ABSTRACT_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON))
	RegisterSignal(tile, COMSIG_TURF_PREPARE_STEP_SOUND, PROC_REF(water_steps))
	RegisterSignals(tile, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(on_entered))
	RegisterSignal(tile, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	if(infinite_source)
		for(var/obj/obstacle in tile)
			watch_pressure_obstacle(obstacle)
	tile.AddElement(/datum/element/watery_tile/floodwater)
	if(mask_state)
		tile.AddElement(/datum/element/immerse/floodwater, "immerse", 140)

/** Construction in the ocean keeps local barrier hooks, independently of area names. */
/datum/component/floodwater/proc/ocean_replaced(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(restore_stationtrauma_hull))
	if(ispath(path, /turf/open/floor))
		post_change_callbacks += CALLBACK(SSfloodwater, TYPE_PROC_REF(/datum/controller/subsystem/floodwater, mark_repaired_inlet))

/datum/component/floodwater/UnregisterFromParent()
	if(!infinite_source)
		var/area/alarm_area = get_area(parent)
		SEND_SIGNAL(alarm_area, COMSIG_STATIONTRAUMA_WATER_STAGE_CHANGED, src, 0)
	SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED, src, FALSE)
	if(infinite_source || isspaceturf(parent))
		SEND_SIGNAL(parent, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)
	SSfloodwater.active -= src
	UnregisterSignal(parent, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_TURF_CHANGE, COMSIG_ATOM_UPDATE_OVERLAYS, COMSIG_TURF_PREPARE_STEP_SOUND, COMSIG_ATOM_ENTERED, COMSIG_ATOM_ABSTRACT_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, COMSIG_ATOM_HAS_GRAVITY, COMSIG_TURF_HAS_GRAVITY))
	var/turf/open/tile = parent
	if(mask_state)
		tile.RemoveElement(/datum/element/immerse/floodwater, "immerse", 140)
	tile.RemoveElement(/datum/element/watery_tile/floodwater)
	if(isspaceturf(tile))
		REMOVE_TRAIT(tile, TRAIT_FORCED_GRAVITY, "floodwater")
	if(water_overlay)
		SSvis_overlays.remove_vis_overlay(tile, list(water_overlay))
	for(var/mob/living/occupant in tile)
		occupant.remove_status_effect(/datum/status_effect/floodwater)
		occupant.refresh_gravity()
	wake_neighbours()

/// Set bounded depth and refresh depth-dependent behavior; reservoirs must still recheck their boundary.
/datum/component/floodwater/proc/set_depth(new_depth, notify_neighbors = TRUE)
	if(!infinite_source && SSfloodwater.hybrid?.by_turf[parent] && !SSfloodwater.hybrid.publishing)
		return SSfloodwater.hybrid.set_depth_at(parent, clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH))
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
	var/datum/floodwater_front_cell/cell = !infinite_source ? SSfloodwater.hybrid?.by_turf[parent] : null
	if(cell)
		if(cell.root()?.dirty)
			return 0
		var/amount = min(volume, cell.amount())
		if(receiver)
			if(QDELETED(receiver))
				return 0
			amount = min(amount, max(0, receiver.maximum_volume - receiver.total_volume))
			if(amount <= 0)
				return 0
			amount = store_stationtrauma_water(receiver, amount)
		return SSfloodwater.hybrid.withdraw(cell, amount)
	var/removed = min(volume, depth * FLOOD_WATER_LITRES_PER_CM)
	if(receiver)
		if(QDELETED(receiver))
			return 0
		removed = FLOOR(removed, CHEMICAL_QUANTISATION_LEVEL)
		removed = receiver.add_reagent(/datum/reagent/water, removed, no_react = TRUE)
	if(removed <= 0)
		return 0
	if(!infinite_source)
		var/remaining_depth = max(0, depth - removed / FLOOD_WATER_LITRES_PER_CM)
		if(!remaining_depth && show_puddle && !isspaceturf(parent))
			var/turf/open/tile = parent
			tile.MakeSlippery(TURF_WET_WATER, 1 MINUTES, 0, 1 MINUTES)
		set_depth(remaining_depth)
	return removed

/// Publish a new depth stage immediately; C already queues the final cell presentation.
/datum/component/floodwater/proc/update_depth()
	var/new_stage = depth <= 0.6 && !infinite_source ? 0 : depth >= FLOOD_WATER_SUBMERGED ? 4 : depth >= FLOOD_WATER_DEEP ? 3 : depth >= FLOOD_WATER_WAIST ? 2 : 1
	if(stage == new_stage)
		return
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	var/previous_phase
	if(debug.enabled)
		debug.stage_updates++
		previous_phase = debug.phase_name
		debug.measure_phase("DepthPressure")
	stage = new_stage
	if(!infinite_source)
		var/area/alarm_area = get_area(parent)
		SEND_SIGNAL(alarm_area, COMSIG_STATIONTRAUMA_WATER_STAGE_CHANGED, src, stage)
	update_depth_effects()
	var/turf/open/tile = parent
	if(stage)
		if(debug.enabled)
			debug.measure_phase("Occupants")
		for(var/mob/living/occupant in tile)
			if(occupant.flags_1 & INITIALIZED_1)
				on_entered(tile, occupant)
	if(debug.enabled)
		debug.measure_phase(previous_phase)

/// Refresh the existing immersion mask and water overlay for a changed stage.
/datum/component/floodwater/proc/update_depth_effects()
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	var/previous_phase
	if(debug.enabled)
		previous_phase = debug.phase_name
	var/turf/open/tile = parent
	if(debug.enabled)
		debug.measure_phase("Immersion")
	var/new_mask_state = !stage ? null : stage == 4 ? "submerged" : stage >= 2 ? "immerse_deep" : "immerse"
	if(occupant_effects && mask_state && !new_mask_state)
		tile.RemoveElement(/datum/element/immerse/floodwater, "immerse", 140)
	if(mask_state != new_mask_state)
		var/was_immersed = !!mask_state
		mask_state = new_mask_state
		if(occupant_effects && mask_state)
			if(was_immersed)
				SEND_SIGNAL(tile, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED, mask_state)
			else
				tile.AddElement(/datum/element/immerse/floodwater, "immerse", 140)
	if(debug.enabled)
		debug.measure_phase("WaterOverlay")
	if(water_overlay)
		SSvis_overlays.remove_vis_overlay(tile, list(water_overlay))
	water_overlay = null
	if(!stage)
		if(show_puddle)
			water_overlay = SSvis_overlays.add_vis_overlay(tile, 'icons/effects/water.dmi', "wet_floor_static", FLOAT_LAYER, MUTATE_PLANE(FLOOR_PLANE, tile), tile.dir, add_appearance_flags = TILE_BOUND)
		if(debug.enabled)
			debug.measure_phase(previous_phase)
		return
	// Flooded floors need a stronger water column; the exterior must keep the seabed visible.
	var/water_alpha = isspaceturf(tile) ? 16 + stage * 8 : 32 + stage * 24
	water_overlay = SSvis_overlays.add_vis_overlay(tile, 'modular_bandastation/underwater/icons/water.dmi', "volume", TOPDOWN_WATER_LEVEL_LAYER, MUTATE_PLANE(FLOOR_PLANE, tile), tile.dir, water_alpha, add_appearance_flags = TILE_BOUND)
	if(debug.enabled)
		debug.measure_phase(previous_phase)

/datum/component/floodwater/proc/on_entered(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
	arrived.start_stationtrauma_ocean_drift()
	if(infinite_source && isobj(arrived) && arrived.can_atmos_pass != ATMOS_PASS_YES)
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
	RegisterSignal(obstacle, COMSIG_ATOM_DENSITY_CHANGED, PROC_REF(on_atmos_update), override = TRUE)

/datum/component/floodwater/proc/on_exited(turf/source, atom/movable/departed)
	SIGNAL_HANDLER
	if(!infinite_source || !isobj(departed) || departed.can_atmos_pass == ATMOS_PASS_YES)
		return
	UnregisterSignal(departed, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING))
	on_atmos_update()

/datum/component/floodwater/proc/add_water_overlay(atom/source, list/overlays)
	SIGNAL_HANDLER
	if(water_overlay)
		// update_overlays() removes managed visuals before this signal.
		var/turf/open/tile = source
		water_overlay = SSvis_overlays.add_vis_overlay(tile, water_overlay.icon, water_overlay.icon_state, water_overlay.layer, water_overlay.plane, tile.dir, water_overlay.alpha, add_appearance_flags = TILE_BOUND)

/datum/component/floodwater/proc/water_steps(turf/source, list/steps)
	SIGNAL_HANDLER
	steps[FOOTSTEP_MOB_SHOE] = FOOTSTEP_WATER
	steps[FOOTSTEP_MOB_BAREFOOT] = FOOTSTEP_WATER
	steps[FOOTSTEP_MOB_CLAW] = FOOTSTEP_WATER
	steps[FOOTSTEP_MOB_HEAVY] = FOOTSTEP_WATER
	return FOOTSTEP_OVERRIDEN

/datum/component/floodwater/proc/affects(mob/living/swimmer)
	return get_depth() >= FLOOD_WATER_SUBMERGED || (!(swimmer.movement_type & MOVETYPES_NOT_TOUCHING_GROUND) && !HAS_TRAIT(swimmer, TRAIT_MOB_ELEVATED))

/datum/component/floodwater/proc/head_underwater(mob/living/swimmer)
	return affects(swimmer) && (get_depth() >= FLOOD_WATER_SUBMERGED || (get_depth() >= FLOOD_WATER_WAIST && (swimmer.body_position == LYING_DOWN || swimmer.mob_size < MOB_SIZE_HUMAN)))

/// One attached element watches all positive water stages; only its rendered masks change.
/datum/element/immerse/floodwater
	var/list/masks_by_state = list()
	/// Pixel hit testing cannot select sprites cut out by the full immersion alpha mask.
	var/list/submerged_mouse_overrides = list()
	/// Unfiltered mouse surfaces, retained while an object remains fully submerged.
	var/list/submerged_click_surfaces = list()

/datum/element/immerse/floodwater/Attach(turf/target, mask_icon = "immerse", alpha = 140)
	. = ..()
	if(. == ELEMENT_INCOMPATIBLE)
		return
	RegisterSignal(target, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED, PROC_REF(refresh_water_mask))

/datum/element/immerse/floodwater/Detach(turf/source)
	UnregisterSignal(source, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED)
	return ..()

/datum/element/immerse/floodwater/on_atom_exited(turf/source, atom/movable/exited, direction)
	if(!HAS_TRAIT_FROM(exited, TRAIT_IMMERSED, ELEMENT_TRAIT(src)))
		return
	var/turf/open/destination = exited.loc
	var/datum/component/floodwater/new_water = isopenturf(destination) ? destination.GetComponent(/datum/component/floodwater) : null
	// Empty wet tiles have null contents; inspect their local component instead of scanning every ocean turf.
	if(!new_water?.mask_state || HAS_TRAIT(destination, TRAIT_IMMERSE_STOPPED))
		return ..()
	new_water.enable_occupant_effects()
	LAZYREMOVE(attached_turf_contents[source], exited)
	LAZYADD(attached_turf_contents[destination], exited)
	if(!generated_visual_overlays[exited])
		return
	var/datum/component/floodwater/old_water = source.GetComponent(/datum/component/floodwater)
	// Native movement keeps an element shared by both tiles; refresh only when their masks differ.
	if(old_water?.mask_state != new_water?.mask_state)
		add_immerse_overlay(exited)

/** Only potentially immersed objects need wetness signals; ocean lighting and observers never become wet. */
/datum/element/watery_tile/floodwater/enter_water(atom/source, atom/movable/entered)
	if(istype(entered, /atom/movable/lighting_object) || is_type_in_typecache(entered, GLOB.immerse_ignored_movable))
		return
	return ..()

/datum/element/watery_tile/floodwater/out_of_water(atom/source, atom/movable/gone)
	if(istype(gone, /atom/movable/lighting_object) || is_type_in_typecache(gone, GLOB.immerse_ignored_movable))
		return
	return ..()

/datum/element/immerse/floodwater/proc/refresh_water_mask(turf/source, new_mask_state)
	SIGNAL_HANDLER
	for(var/atom/movable/movable as anything in attached_turf_contents[source])
		if(generated_visual_overlays[movable])
			add_immerse_overlay(movable, new_mask_state)

/datum/element/immerse/floodwater/add_immerse_overlay(atom/movable/movable, new_mask_state)
	if(!new_mask_state)
		var/turf/open/tile = get_turf(movable)
		var/datum/component/floodwater/water = isopenturf(tile) ? tile.GetComponent(/datum/component/floodwater) : null
		new_mask_state = water?.mask_state || "immerse"
	var/list/masks = masks_by_state[new_mask_state]
	if(!masks)
		masks = list()
		masks_by_state[new_mask_state] = masks
	// Native generation keys only by dimensions; keep separate caches for each mask style.
	var/previous_mask = mask_icon
	var/list/previous_masks = immersion_masks
	mask_icon = new_mask_state
	immersion_masks = masks
	. = ..(movable)
	mask_icon = previous_mask
	immersion_masks = previous_masks
	var/atom/movable/immerse_mask/relay = generated_visual_overlays[movable]
	if(relay)
		// Native appearance assignment resets mouse opacity; the mask is only a render source.
		relay.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		// Blend towards the flooded floor colour without exposing objects behind the sprite.
		movable.add_filter("immerse_mask", INFINITY, layering_filter(
			render_source = relay.render_target,
			y = -floor((movable.get_cached_height() - ICON_SIZE_Y) / 2) - movable.pixel_z,
			color = FLOOD_WATER_IMMERSION_COLOR,
			blend_mode = BLEND_INSET_OVERLAY,
		))
	if(new_mask_state != "submerged")
		restore_mouse_opacity(movable)
	else if(isobj(movable) && generated_visual_overlays[movable] && movable.mouse_opacity == MOUSE_OPACITY_ICON)
		submerged_mouse_overrides[movable] = movable.mouse_opacity
		movable.mouse_opacity = MOUSE_OPACITY_OPAQUE
	if(new_mask_state == "submerged" && isobj(movable) && relay && movable.mouse_opacity != MOUSE_OPACITY_TRANSPARENT && !submerged_click_surfaces[movable])
		var/obj/effect/floodwater_click_surface/surface = new(movable)
		submerged_click_surfaces[movable] = surface
		movable.vis_contents += surface

/datum/element/immerse/floodwater/remove_immerse_overlay(atom/movable/movable, deleting = TRUE)
	restore_mouse_opacity(movable)
	return ..()

/// Restore only our own override; intentionally mouse-transparent objects stay transparent.
/datum/element/immerse/floodwater/proc/restore_mouse_opacity(atom/movable/movable)
	var/obj/effect/floodwater_click_surface/surface = submerged_click_surfaces[movable]
	if(surface)
		movable.vis_contents -= surface
		submerged_click_surfaces -= movable
		qdel(surface)
	if(!submerged_mouse_overrides[movable])
		return
	if(movable.mouse_opacity == MOUSE_OPACITY_OPAQUE)
		movable.mouse_opacity = submerged_mouse_overrides[movable]
	submerged_mouse_overrides -= movable

/// Invisible unfiltered appearance; BYOND sends every mouse operation to the owning object.
/obj/effect/floodwater_click_surface
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	appearance_flags = KEEP_APART|RESET_ALPHA|RESET_COLOR
	vis_flags = VIS_INHERIT_ID|VIS_INHERIT_ICON|VIS_INHERIT_ICON_STATE|VIS_INHERIT_DIR|VIS_INHERIT_LAYER|VIS_INHERIT_PLANE

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
