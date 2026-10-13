#define FLOOD_NATIVE_GEOMETRY 1
#define FLOOD_NATIVE_FRONT 2
#define FLOOD_NATIVE_PORTALS 3
#define FLOOD_NATIVE_LEVELS 4
#define FLOOD_NATIVE_EFFECTS 5

/** C owns finite volume and heat; components publish the existing appearance and gameplay effects. */
/datum/floodwater_hybrid
	parent_type = /datum/floodwater_front_solver
	/// Finite cells keyed by current turf; external ocean is never included.
	var/list/by_turf = list()
	/// Door throats exchange water without merging the rooms on either side.
	var/list/portals = list()
	/// Deduplicated native geometry events, including changes on dry floors.
	var/list/geometry_events = list()
	/// Only finite floor contacts with the external ocean, independent of the size of the wet interior.
	var/list/ocean_contacts = list()
	/// Owners whose native stage has crossed a rendering threshold.
	var/list/paint_groups = list()
	/// Elapsed front time; the A microsteps do not scan C interiors.
	var/elapsed = 0
	/// Current resumable front phase, or zero between front intervals.
	var/native_phase = 0
	/// Cursor shared by portal and owner-stage scans.
	var/native_cursor = 1
	/// Native setters publish appearances without feeding the same litres back into the solver.
	var/publishing = FALSE

/** Register every finite turf before linking it, so dry walls and doors are observed too. */
/datum/floodwater_hybrid/proc/add_domain(list/tiles)
	var/list/added = list()
	for(var/turf/tile as anything in tiles)
		if(by_turf[tile] || isspaceturf(tile) || istype(tile, /turf/open/water))
			continue
		var/datum/floodwater_front_cell/cell = new
		cell.id = cells.len + 1
		cell.native = src
		cell.tile = tile
		cell.blocked = !isopenturf(tile) || tile.blocks_air
		cells += cell
		added += cell
		by_turf[tile] = cell
		cell.watch_turf()
	for(var/datum/floodwater_front_cell/cell as anything in added)
		var/datum/component/floodwater/water = cell.tile.GetComponent(/datum/component/floodwater)
		if(water && !water.infinite_source)
			if(cell.blocked)
				cell.displaced_volume = water.depth * FLOOD_WATER_LITRES_PER_CM
				cell.displaced_heat = cell.displaced_volume * water.temperature
				changed[cell] = TRUE
			else
				receive(cell, water.depth * FLOOD_WATER_LITRES_PER_CM, water.temperature)
	// Both endpoints need their door region before links are finalized.
	for(var/datum/floodwater_front_cell/cell as anything in added)
		refresh_cell(cell)
	for(var/datum/floodwater_front_cell/cell as anything in added)
		refresh_cell(cell)
		invalidate(cell.root())

/datum/floodwater_hybrid/Destroy()
	for(var/datum/floodwater_front_cell/cell as anything in cells)
		cell.unwatch_turf()
		cell.native = null
		cell.tile = null
		cell.group = null
		cell.neighbors.Cut()
		qdel(cell)
	for(var/datum/floodwater_front_group/owner as anything in groups)
		owner.members.Cut()
		owner.wet.Cut()
		owner.boundary.Cut()
		qdel(owner)
	for(var/datum/floodwater_front_cell/cell as anything in portals)
		var/list/edges = portals[cell]
		for(var/datum/floodwater_front_cell/neighbor as anything in edges)
			var/datum/floodwater_front_portal/portal = edges[neighbor]
			portal.solver = null
			portal.left = null
			portal.right = null
			qdel(portal)
	cells.Cut()
	groups.Cut()
	run.Cut()
	pending.Cut()
	restore.Cut()
	dirty_groups.Cut()
	by_turf.Cut()
	portals.Cut()
	geometry_events.Cut()
	ocean_contacts.Cut()
	changed.Cut()
	paint_groups.Cut()
	return ..()

/// Native queries use live ownership even while connectivity is materialized in packets.
/datum/floodwater_hybrid/proc/depth_at(turf/tile)
	var/datum/floodwater_front_cell/cell = by_turf[tile]
	return cell ? cell.amount() / FLOOD_WATER_LITRES_PER_CM : 0

/// Component callers may change one cell's share, never multiply a room-wide volume by its footprint.
/datum/floodwater_hybrid/proc/set_depth_at(turf/tile, new_depth, water_temperature = null)
	var/datum/floodwater_front_cell/cell = by_turf[tile]
	if(!cell || cell.blocked || cell.root()?.dirty)
		return tile.GetComponent(/datum/component/floodwater)
	var/old_volume = cell.amount()
	var/old_temperature = cell.temperature()
	var/new_volume = new_depth * FLOOD_WATER_LITRES_PER_CM
	if(new_volume > old_volume)
		receive(cell, new_volume - old_volume, isnull(water_temperature) ? cell.temperature() : water_temperature)
	else if(new_volume < old_volume)
		withdraw(cell, old_volume - new_volume)
	if(!isnull(water_temperature) && cell.root())
		if(cell.local)
			cell.heat = cell.volume * water_temperature
		else
			var/datum/floodwater_front_group/owner = cell.root()
			owner.heat += min(old_volume, new_volume) * (water_temperature - old_temperature)
	changed[cell] = TRUE
	return tile.GetComponent(/datum/component/floodwater)

/datum/floodwater_hybrid/receive(datum/floodwater_front_cell/cell, requested, temperature)
	. = ..()

/datum/floodwater_hybrid/withdraw(datum/floodwater_front_cell/cell, requested)
	. = ..()
	if(.)
		wake_ocean_contacts(cell.root())

/// Aggregate withdrawal frees every member's capacity, including a source far from the active front.
/datum/floodwater_hybrid/proc/wake_ocean_contacts(datum/floodwater_front_group/owner = null)
	for(var/datum/floodwater_front_cell/contact as anything in ocean_contacts)
		if(owner && contact.root() != owner)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(contact.tile, direction)
			var/datum/component/floodwater/source = neighbor?.GetComponent(/datum/component/floodwater)
			if(source?.infinite_source)
				source.wake()

/// Cache passable edges only on geometry events; live door checks also precede paired portal commits.
/datum/floodwater_hybrid/proc/refresh_cell(datum/floodwater_front_cell/cell)
	var/turf/open/tile = cell.tile
	set_blocked(cell, !isopenturf(tile) || isspaceturf(tile) || istype(tile, /turf/open/water) || tile.blocks_air)
	var/new_region = locate(/obj/machinery/door) in tile
	new_region = new_region ? cell.id + 1 : 1
	if(cell.region != new_region)
		cell.region = new_region
		geometry_version++
		invalidate(cell.root())
	ocean_contacts -= cell
	for(var/direction in GLOB.cardinals)
		var/turf/adjacent = get_step(tile, direction)
		var/datum/component/floodwater/source = adjacent?.GetComponent(/datum/component/floodwater)
		if(!cell.blocked && source?.infinite_source)
			ocean_contacts[cell] = TRUE
		var/datum/floodwater_front_cell/neighbor = by_turf[adjacent]
		if(!neighbor)
			// Observe the adjoining area even while its door is closed; links still enforce the barrier.
			if(!cell.blocked && isopenturf(adjacent) && !isspaceturf(adjacent) && !istype(adjacent, /turf/open/water))
				SSfloodwater.ensure_water_domain(adjacent)
				geometry_events[cell] = TRUE
			continue
		var/opened = !cell.blocked && !neighbor.blocked && tile.can_pass_stationtrauma_water(neighbor.tile)
		set_link(cell, neighbor, opened && cell.region == neighbor.region)
		if(cell.region != neighbor.region && cell.id < neighbor.id)
			var/list/edges = portals[cell]
			if(!edges)
				edges = list()
				portals[cell] = edges
			var/datum/floodwater_front_portal/portal = edges[neighbor]
			if(!portal)
				portal = new
				portal.solver = src
				portal.left = cell
				portal.right = neighbor
				edges[neighbor] = portal
			portal.set_open(opened)
	cell.watch_obstacles()
	if(cell.root() && !cell.root().dirty)
		wake(cell.root())

/// One original mask/overlay update; the aggregate remains the authoritative physical state.
/datum/floodwater_hybrid/proc/paint(datum/floodwater_front_cell/cell)
	if(!isopenturf(cell.tile) || cell.root()?.dirty)
		return
	var/turf/open/tile = cell.tile
	var/depth = cell.blocked ? 0 : cell.amount() / FLOOD_WATER_LITRES_PER_CM
	var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
	if(water?.infinite_source)
		return
	publishing = TRUE
	if(depth > 0)
		if(water)
			water.depth = depth
			water.temperature = cell.temperature()
			water.update_depth()
		else
			tile.set_water_depth(depth, FALSE, cell.temperature(), FALSE)
	else if(water && !water.infinite_source)
		qdel(water)
	publishing = FALSE
	if(SSfloodwater.debug.enabled)
		SSfloodwater.debug.cell_updates++

/// Run small native work units in the same resumed MC fire, not one chunk per simulated interval.
/datum/floodwater_hybrid/proc/advance_native(seconds)
	if(!native_phase)
		elapsed += seconds
		if(elapsed + FLOOD_WATER_FLOW_EPSILON < 0.1)
			return TRUE
		native_phase = FLOOD_NATIVE_GEOMETRY
		native_cursor = 1
	while(native_phase)
		switch(native_phase)
			if(FLOOD_NATIVE_GEOMETRY)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("GeometryC")
				if(geometry_events.len)
					var/datum/floodwater_front_cell/cell = geometry_events[geometry_events.len]
					geometry_events -= cell
					refresh_cell(cell)
				else if(resume_geometry(1))
					wake_ocean_contacts()
					begin(elapsed)
					elapsed = 0
					native_phase = FLOOD_NATIVE_FRONT
			if(FLOOD_NATIVE_FRONT)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("FrontC")
				var/old_jobs = jobs
				var/old_edges = neighbor_visits
				if(resume(1))
					native_phase = FLOOD_NATIVE_PORTALS
					native_cursor = 1
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.tiles += jobs - old_jobs
					SSfloodwater.debug.edges += neighbor_visits - old_edges
			if(FLOOD_NATIVE_PORTALS)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("PortalsC")
				if(native_cursor > portals.len)
					native_phase = FLOOD_NATIVE_LEVELS
					native_cursor = 1
				else
					var/list/edges = portals[portals[native_cursor++]]
					for(var/datum/floodwater_front_cell/neighbor as anything in edges)
						var/datum/floodwater_front_portal/portal = edges[neighbor]
						var/turf/open/left_tile = portal.left.tile
						portal.set_open(!portal.left.blocked && !portal.right.blocked && portal.left.region != portal.right.region && left_tile.can_pass_stationtrauma_water(portal.right.tile))
						portal.commit(portal.prepare(run_dt))
			if(FLOOD_NATIVE_LEVELS)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("LevelsC")
				if(native_cursor > groups.len)
					native_phase = FLOOD_NATIVE_EFFECTS
				else
					var/datum/floodwater_front_group/owner = groups[native_cursor++]
					if(!owner.dirty)
						var/stage = stationtrauma_water_stage(owner.volume / owner.members.len / FLOOD_WATER_LITRES_PER_CM)
						if(stage != owner.render_stage)
							owner.render_stage = stage
							paint_groups[owner] = 1
						if(!owner.volume)
							invalidate(owner)
			if(FLOOD_NATIVE_EFFECTS)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("EffectsC")
				if(changed.len)
					var/datum/floodwater_front_cell/cell = changed[changed.len]
					changed -= cell
					paint(cell)
				else if(paint_groups.len)
					var/datum/floodwater_front_group/owner = paint_groups[paint_groups.len]
					var/index = paint_groups[owner]
					if(owner.retired || owner.dirty || index > owner.wet.len)
						paint_groups -= owner
					else
						paint_groups[owner] = index + 1
						var/datum/floodwater_front_cell/cell = owner.wet[index]
						if(cell.root() == owner)
							paint(cell)
				else
					native_phase = 0
		if(TICK_USAGE > Master.current_ticklimit || SSfloodwater.state != SS_RUNNING)
			SSfloodwater.pause()
			return FALSE
	return TRUE

/// Native appearance thresholds are retained, including the two alpha variants sharing a waist mask.
/proc/stationtrauma_water_stage(depth)
	return depth <= 0.6 ? 0 : depth >= FLOOD_WATER_SUBMERGED ? 4 : depth >= FLOOD_WATER_DEEP ? 3 : depth >= FLOOD_WATER_WAIST ? 2 : 1

/** Native observers are separate from the conservative core so fixtures can exercise the same algorithm. */
/datum/floodwater_front_cell
	/// Native controller, or null in an isolated core fixture.
	var/datum/floodwater_hybrid/native
	/// Current turf identity, updated by the turf-change callback.
	var/turf/tile
	/// Objects whose directional or density changes invalidate this cell.
	var/list/obstacles = list()

/datum/floodwater_front_group
	/// Last queued original native rendering stage; no interior updates until it changes.
	var/render_stage = -1

/// Dry cells must observe doors and walls before water reaches them.
/datum/floodwater_front_cell/proc/watch_turf()
	RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(turf_changed))
	RegisterSignals(tile, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED), PROC_REF(native_changed))
	watch_obstacles()

/datum/floodwater_front_cell/proc/unwatch_turf()
	UnregisterSignal(tile, list(COMSIG_TURF_CHANGE, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED))
	for(var/obj/obstacle as anything in obstacles)
		UnregisterSignal(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING))
	obstacles.Cut()

/datum/floodwater_front_cell/proc/watch_obstacles()
	for(var/obj/obstacle as anything in obstacles.Copy())
		if(QDELETED(obstacle) || obstacle.loc != tile)
			UnregisterSignal(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING))
			obstacles -= obstacle
	for(var/obj/obstacle in tile)
		if(obstacle.can_atmos_pass == ATMOS_PASS_YES || (obstacle in obstacles))
			continue
		obstacles |= obstacle
		RegisterSignals(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_QDELETING), PROC_REF(native_changed))

/datum/floodwater_front_cell/proc/native_changed(datum/source, atom/movable/moved)
	SIGNAL_HANDLER
	if(!native || native.publishing)
		return
	if(source == tile && moved && (!isobj(moved) || moved.can_atmos_pass == ATMOS_PASS_YES))
		return
	// Compare live edges now; deletion also gets a second check after the object leaves.
	native.refresh_cell(src)
	native.geometry_events[src] = TRUE
	for(var/direction in GLOB.cardinals)
		var/datum/floodwater_front_cell/neighbor = native.by_turf[get_step(tile, direction)]
		if(neighbor)
			native.refresh_cell(neighbor)
			native.geometry_events[neighbor] = TRUE

/datum/floodwater_front_cell/proc/turf_changed(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	if(!native)
		return
	native.geometry_version++
	native.invalidate(root())
	for(var/datum/floodwater_front_cell/neighbor as anything in neighbors)
		native.invalidate(neighbor.root())
	native.geometry_events[src] = TRUE
	post_change_callbacks += CALLBACK(src, PROC_REF(turf_restored))

/datum/floodwater_front_cell/proc/turf_restored(turf/new_tile)
	if(!native)
		return
	native.by_turf -= tile
	unwatch_turf()
	tile = new_tile
	native.by_turf[tile] = src
	watch_turf()
	native.geometry_events[src] = TRUE

/** Admit the requested finite floor and its area once; ordinary maps without floodwater remain untouched. */
/datum/controller/subsystem/floodwater/proc/ensure_water_domain(turf/tile)
	RETURN_TYPE(/datum/floodwater_front_cell)
	if(!isturf(tile) || isspaceturf(tile) || istype(tile, /turf/open/water))
		return null
	if(!hybrid.by_turf[tile])
		var/area/domain = get_area(tile)
		var/list/tiles = list()
		for(var/turf/member in domain)
			if(!isspaceturf(member) && !istype(member, /turf/open/water))
				tiles += member
		hybrid.add_domain(tiles)
	return hybrid.by_turf[tile]
