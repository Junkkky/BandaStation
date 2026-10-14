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
	water.set_reservoir_pressure(water_pressure)

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
/turf/open/proc/set_water_depth(new_depth, infinite_source = null, water_temperature = null, notify_neighbors = TRUE)
	if(!isnum(new_depth) || !IS_FINITE(new_depth) || istype(src, /turf/open/water))
		return null
	if(!isnull(water_temperature) && (!isnum(water_temperature) || !IS_FINITE(water_temperature) || water_temperature < 0))
		return null
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	new_depth = clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH)
	var/is_finite_water = isnull(infinite_source) ? !water?.infinite_source : !infinite_source
	if(is_finite_water && !isspaceturf(src) && !SSfloodwater.hybrid.publishing)
		if(water?.infinite_source)
			qdel(water)
		SSfloodwater.ensure_water_domain(src)
		return SSfloodwater.hybrid.set_depth_at(src, new_depth, water_temperature)
	if(!new_depth)
		if(water)
			qdel(water)
		return null
	if(!water)
		return AddComponent(/datum/component/floodwater, new_depth, !!infinite_source, isnull(water_temperature) ? FLOOD_WATER_TEMPERATURE : water_temperature)
	if(!isnull(infinite_source) && water.infinite_source != infinite_source)
		water.infinite_source = infinite_source
		SEND_SIGNAL(src, COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED)
	if(!isnull(water_temperature))
		water.temperature = water_temperature
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

/datum/component/floodwater/proc/get_temperature()
	var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid?.by_turf[parent]
	return cell && !infinite_source ? cell.temperature() : temperature

/// Preserve the original source and puddle rendering thresholds.
/datum/component/floodwater/proc/get_stage()
	return !infinite_source && SSfloodwater.hybrid?.by_turf[parent] ? stationtrauma_water_stage(get_depth()) : stage

/// Returns litres actually accepted; floor water and TG plumbing use the same volume conversion.
/turf/open/proc/add_water(volume, water_temperature)
	if(!isnum(volume) || !IS_FINITE(volume) || volume <= 0 || !isnum(water_temperature) || !IS_FINITE(water_temperature) || water_temperature < 0 || istype(src, /turf/open/water))
		return 0
	var/datum/component/floodwater/water = GetComponent(/datum/component/floodwater)
	if(water?.infinite_source)
		return 0
	var/datum/floodwater_front_cell/cell = !isspaceturf(src) ? SSfloodwater.ensure_water_domain(src) : null
	if(cell && !SSfloodwater.hybrid.publishing)
		return SSfloodwater.hybrid.receive(cell, volume, water_temperature)
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

/** One component per wet turf, publishing the native appearance while C owns finite water. */
/datum/component/floodwater
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/depth = 0
	var/infinite_source = FALSE
	var/temperature = FLOOD_WATER_TEMPERATURE
	var/stage = -1
	/// Last rendered stage; flow batches may change the physical stage before effects are flushed.
	var/visual_stage = -1
	var/mask_state
	/// Cached mouse-transparent visual; ordinary turf overlays intercept clicks on submerged contents.
	var/obj/effect/overlay/vis/water_overlay
	var/show_puddle

/datum/component/floodwater/Initialize(initial_depth, is_source = FALSE, initial_temperature = FLOOD_WATER_TEMPERATURE)
	// Existing static water already owns immersion/wetness elements.
	if(!isopenturf(parent) || istype(parent, /turf/open/water))
		return COMPONENT_INCOMPATIBLE
	depth = clamp(initial_depth, 0, FLOOD_WATER_MAX_DEPTH)
	infinite_source = is_source
	temperature = initial_temperature
	show_puddle = prob(30)

/datum/component/floodwater/RegisterWithParent()
	RegisterSignal(parent, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, PROC_REF(on_atmos_update))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(add_water_overlay))
	RegisterSignal(parent, COMSIG_TURF_PREPARE_STEP_SOUND, PROC_REF(water_steps))
	RegisterSignals(parent, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(on_entered))
	RegisterSignal(parent, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	var/turf/open/tile = parent
	if(infinite_source)
		for(var/obj/obstacle in tile)
			watch_pressure_obstacle(obstacle)
	else
		SSfloodwater.ensure_water_domain(tile)
	tile.AddElement(/datum/element/watery_tile)
	if(isspaceturf(tile))
		tile.AddElement(/datum/element/forced_gravity, STANDARD_GRAVITY, TRUE)
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
	UnregisterSignal(parent, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_TURF_CHANGE, COMSIG_ATOM_UPDATE_OVERLAYS, COMSIG_TURF_PREPARE_STEP_SOUND, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON))
	var/turf/open/tile = parent
	if(mask_state)
		tile.RemoveElement(/datum/element/immerse/floodwater, "immerse", 140)
	tile.RemoveElement(/datum/element/watery_tile)
	if(isspaceturf(tile))
		tile.RemoveElement(/datum/element/forced_gravity, STANDARD_GRAVITY, TRUE)
	if(water_overlay)
		SSvis_overlays.remove_vis_overlay(tile, list(water_overlay))
	for(var/mob/living/occupant in tile)
		occupant.remove_status_effect(/datum/status_effect/floodwater)
		occupant.refresh_gravity()
	wake_neighbours()

/// Set bounded depth and refresh depth-dependent behavior; reservoirs must still recheck their boundary.
/datum/component/floodwater/proc/set_depth(new_depth, notify_neighbors = TRUE, defer_effects = FALSE)
	if(!infinite_source && SSfloodwater.hybrid?.by_turf[parent] && !SSfloodwater.hybrid.publishing)
		return SSfloodwater.hybrid.set_depth_at(parent, clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH))
	depth = clamp(new_depth, 0, FLOOD_WATER_MAX_DEPTH)
	if(!depth)
		qdel(src)
		return
	update_depth(defer_effects)
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
			amount = store_stationtrauma_water(receiver, amount, cell.temperature())
		return SSfloodwater.hybrid.withdraw(cell, amount)
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

/// Physics and occupant state stay immediate; repeated wet-stage visual changes can be coalesced.
/datum/component/floodwater/proc/update_depth(defer_effects = FALSE)
	var/new_stage = depth <= 0.6 && !infinite_source ? 0 : depth >= FLOOD_WATER_SUBMERGED ? 4 : depth >= FLOOD_WATER_DEEP ? 3 : depth >= FLOOD_WATER_WAIST ? 2 : 1
	if(stage == new_stage)
		if(!defer_effects && visual_stage != stage)
			update_depth_effects()
		return
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	var/previous_phase
	if(debug.enabled)
		debug.stage_updates++
		previous_phase = debug.phase_name
		debug.measure_phase("DepthPressure")
	// Puddle transitions attach/remove immersion traits and wetness, so keep them immediate.
	defer_effects = defer_effects && stage > 0 && new_stage > 0
	stage = new_stage
	if(!defer_effects)
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

/// Apply only the final wet-stage appearance after conservative transfers have finished.
/datum/component/floodwater/proc/update_depth_effects()
	if(visual_stage == stage)
		return
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	var/previous_phase
	if(debug.enabled)
		previous_phase = debug.phase_name
	var/turf/open/tile = parent
	if(debug.enabled)
		debug.measure_phase("Immersion")
	var/new_mask_state = !stage ? null : stage == 4 ? "submerged" : stage >= 2 ? "immerse_deep" : "immerse"
	if(mask_state && !new_mask_state)
		tile.RemoveElement(/datum/element/immerse/floodwater, "immerse", 140)
	if(mask_state != new_mask_state)
		var/was_immersed = !!mask_state
		mask_state = new_mask_state
		if(mask_state)
			if(was_immersed)
				SEND_SIGNAL(tile, COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED, mask_state)
			else
				tile.AddElement(/datum/element/immerse/floodwater, "immerse", 140)
	if(debug.enabled)
		debug.measure_phase("WaterOverlay")
	if(water_overlay)
		SSvis_overlays.remove_vis_overlay(tile, list(water_overlay))
	water_overlay = null
	visual_stage = stage
	if(!stage)
		if(show_puddle)
			water_overlay = SSvis_overlays.add_vis_overlay(tile, 'icons/effects/water.dmi', "wet_floor_static", FLOAT_LAYER, MUTATE_PLANE(FLOOR_PLANE, tile), tile.dir)
		if(debug.enabled)
			debug.measure_phase(previous_phase)
		return
	// Flooded floors need a stronger water column; the exterior must keep the seabed visible.
	var/water_alpha = isspaceturf(tile) ? 16 + stage * 8 : 32 + stage * 24
	water_overlay = SSvis_overlays.add_vis_overlay(tile, 'modular_bandastation/underwater/icons/water.dmi', "volume", TOPDOWN_WATER_LEVEL_LAYER, MUTATE_PLANE(FLOOR_PLANE, tile), tile.dir, water_alpha)
	if(debug.enabled)
		debug.measure_phase(previous_phase)

/datum/component/floodwater/proc/on_entered(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
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
		water_overlay = SSvis_overlays.add_vis_overlay(tile, water_overlay.icon, water_overlay.icon_state, water_overlay.layer, water_overlay.plane, tile.dir, water_overlay.alpha)

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
	var/turf/open/destination = exited.loc
	// An attached empty tile has a null contents list; membership still keeps immersion active.
	if(!(destination in attached_turf_contents))
		return ..()
	LAZYREMOVE(attached_turf_contents[source], exited)
	LAZYADD(attached_turf_contents[destination], exited)
	if(!generated_visual_overlays[exited])
		return
	var/datum/component/floodwater/old_water = source.GetComponent(/datum/component/floodwater)
	var/datum/component/floodwater/new_water = destination.GetComponent(/datum/component/floodwater)
	// Native movement keeps an element shared by both tiles; refresh only when their masks differ.
	if(old_water?.mask_state != new_water?.mask_state)
		add_immerse_overlay(exited)

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
