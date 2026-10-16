#define FLOOD_NATIVE_GEOMETRY 1
#define FLOOD_NATIVE_FRONT 2
#define FLOOD_NATIVE_PORTALS 3
#define FLOOD_NATIVE_LEVELS 4
#define FLOOD_NATIVE_EFFECTS 5
#define FLOOD_NATIVE_VERTICAL 6
#define FLOOD_NATIVE_HEADS 7

/** C owns finite volume; components publish the existing appearance and gameplay effects. */
/datum/floodwater_hybrid
	parent_type = /datum/floodwater_front_solver
	/// Finite cells keyed by current turf; external ocean is never included.
	var/list/by_turf = list()
	/// Door throats exchange water without merging the rooms on either side.
	var/list/portals = list()
	/// Only observed holes between connected decks; their finite owners always remain separate.
	var/list/vertical_portals = list()
	/// Awake open edges; geometry and stock events restore parked registry entries.
	var/list/open_portals = list()
	/// Vertical edges retain their separate processing order and elevation.
	var/list/open_vertical_portals = list()
	/// Unique full endpoints whose native air can change without a water event.
	var/list/pressure_watch = list()
	/// A phase snapshot of head endpoints or portals survives removals during an MC pause.
	var/list/portal_run
	/// Deduplicated native geometry events, including changes on dry floors.
	var/list/geometry_events = list()
	/// Only finite floor contacts with the external ocean, independent of the size of the wet interior.
	var/list/ocean_contacts = list()
	/// Owners whose native stage has crossed a rendering threshold.
	var/list/paint_groups = list()
	/// Sealed door/window floors with displaced litres; retries follow capacity/geometry events, not a timer.
	var/list/closed_packets = list()
	/// Elapsed front time; the A microsteps do not scan C interiors.
	var/elapsed = 0
	/// Current resumable front phase, or zero between front intervals.
	var/native_phase = 0
	/// Front, head and geometry work wake ocean contacts once at the next completed geometry boundary.
	var/ocean_wakeup = FALSE
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
				changed[cell] = TRUE
			else
				receive(cell, water.depth * FLOOD_WATER_LITRES_PER_CM)
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
			portal.set_open(FALSE)
			portal.solver = null
			portal.left = null
			portal.right = null
			qdel(portal)
	for(var/datum/floodwater_front_cell/cell as anything in vertical_portals)
		var/datum/floodwater_front_portal/portal = vertical_portals[cell]
		portal.set_open(FALSE)
		portal.solver = null
		portal.left = null
		portal.right = null
		qdel(portal)
	vertical_portals.Cut()
	open_portals.Cut()
	open_vertical_portals.Cut()
	pressure_watch.Cut()
	portal_run = null
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
	closed_packets.Cut()
	return ..()

/// Native queries use live ownership even while connectivity is materialized in packets.
/datum/floodwater_hybrid/proc/depth_at(turf/tile)
	var/datum/floodwater_front_cell/cell = by_turf[tile]
	return cell ? cell.amount() / FLOOD_WATER_LITRES_PER_CM : 0

/// Component callers may change one cell's share, never multiply a room-wide volume by its footprint.
/datum/floodwater_hybrid/proc/set_depth_at(turf/tile, new_depth)
	var/datum/floodwater_front_cell/cell = by_turf[tile]
	if(!cell || cell.blocked || cell.root()?.dirty)
		return tile.GetComponent(/datum/component/floodwater)
	var/old_volume = cell.amount()
	var/new_volume = new_depth * FLOOD_WATER_LITRES_PER_CM
	if(new_volume > old_volume)
		receive(cell, new_volume - old_volume)
	else if(new_volume < old_volume)
		withdraw(cell, old_volume - new_volume)
	changed[cell] = TRUE
	return tile.GetComponent(/datum/component/floodwater)

/datum/floodwater_hybrid/receive(datum/floodwater_front_cell/cell, requested)
	var/datum/floodwater_front_group/owner = cell.root()
	if(owner && !owner.is_full() && !owner.dirty)
		owner.pressure_head = 0
		owner.pressure_remainder = 0
		cell.pressure_head = 0
	. = ..()
	if(.)
		cell.wake_portals()

/datum/floodwater_hybrid/withdraw(datum/floodwater_front_cell/cell, requested)
	. = ..()
	if(.)
		cell.wake_portals()
		cell.root()?.wake_portals()
		wake_ocean_contacts(cell.root(), cell)
		for(var/datum/floodwater_front_cell/door_cell as anything in closed_packets)
			for(var/direction in GLOB.cardinals)
				var/datum/floodwater_front_cell/neighbor = by_turf[get_step(door_cell.tile, direction)]
				if(neighbor && neighbor.root() == cell.root())
					restore[door_cell] = TRUE
					break

/** Sealed floor obstacles push their packet to adjacent finite capacity, respecting every other barrier. */
/datum/floodwater_hybrid/restore_displaced(datum/floodwater_front_cell/cell)
	var/turf/open/tile = cell.tile
	if(!cell.blocked && !cell.displaced_volume && !cell.available())
		fill_equalized_ocean_opening(cell)
	var/obj/barrier = isopenturf(tile) ? (tile.closed_stationtrauma_water_door() || tile.sealed_stationtrauma_water_window()) : null
	if(!cell.blocked || !barrier || !cell.displaced_volume)
		closed_packets -= cell
		return ..()
	closed_packets[cell] = TRUE
	for(var/direction in GLOB.cardinals)
		var/datum/floodwater_front_cell/neighbor = by_turf[get_step(tile, direction)]
		if(!neighbor || neighbor.blocked || neighbor.root()?.is_full() || !tile.can_pass_stationtrauma_water(neighbor.tile, barrier))
			continue
		var/accepted = receive(neighbor, cell.displaced_volume)
		cell.displaced_volume -= accepted
		if(!cell.displaced_volume)
			closed_packets -= cell
			break

/** A new opening between equalized full stocks fills from the ocean without venting the whole room. */
/datum/floodwater_hybrid/proc/fill_equalized_ocean_opening(datum/floodwater_front_cell/cell)
	var/turf/open/tile = cell.tile
	var/datum/component/floodwater/ocean
	var/full_room = FALSE
	var/min_head = INFINITY
	var/max_head = 0
	for(var/direction in GLOB.cardinals)
		var/turf/open/adjacent = get_step(tile, direction)
		if(!tile.can_pass_stationtrauma_water(adjacent))
			continue
		var/datum/component/floodwater/water = adjacent.GetComponent(/datum/component/floodwater)
		var/head
		if(water?.infinite_source)
			ocean = water
			head = water.reservoir_pressure
		else
			var/datum/floodwater_front_cell/neighbor = by_turf[adjacent]
			if(!neighbor?.root()?.is_full())
				return
			full_room = TRUE
			head = neighbor.head_pressure()
		min_head = min(min_head, head)
		max_head = max(max_head, head)
	if(!ocean || !full_room || max_head - min_head > FLOOD_WATER_HEAD_EPSILON)
		return
	if(receive(cell, FLOOD_FRONT_CAPACITY))
		cell.root().pressure_head = ocean.reservoir_pressure

/// Aggregate withdrawal frees every member's capacity, including a source far from the active front.
/datum/floodwater_hybrid/proc/wake_ocean_contacts(datum/floodwater_front_group/owner = null, datum/floodwater_front_cell/withdrawn_cell = null)
	for(var/datum/component/floodwater_leak/leak as anything in SSfloodwater.leaks)
		leak.wake(owner, withdrawn_cell)
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
	cell.wake_portals()
	var/turf/open/tile = cell.tile
	set_blocked(cell, !isopenturf(tile) || isspaceturf(tile) || istype(tile, /turf/open/water) || tile.blocks_air || tile.closed_stationtrauma_water_door() || tile.sealed_stationtrauma_water_window())
	if(cell.blocked && isopenturf(tile) && tile.GetComponent(/datum/component/floodwater))
		paint(cell)
	if(cell.displaced_volume)
		restore[cell] = TRUE
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
		var/pressure_link = set_link(cell, neighbor, opened && cell.region == neighbor.region)
		if((cell.region != neighbor.region || pressure_link) && cell.id < neighbor.id)
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
				portal.open_index = open_portals
				portal.open_order = (portals.Find(cell) - 1) * GLOB.cardinals.len + edges.len
				edges[neighbor] = portal
			portal.pressure_link = pressure_link
			portal.set_open(opened)
	refresh_vertical_links(cell)
	cell.watch_obstacles()
	if(cell.root() && !cell.root().dirty)
		wake(cell.root())

/// One original mask/overlay update; the aggregate remains the authoritative physical state.
/datum/floodwater_hybrid/proc/paint(datum/floodwater_front_cell/cell)
	if(!isopenturf(cell.tile) || (!cell.blocked && cell.root()?.dirty))
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
			water.update_depth()
		else
			tile.set_water_depth(depth, FALSE, FALSE)
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
				if(geometry_events.len || rebuild || dirty_groups.len || restore.len)
					ocean_wakeup = TRUE
				if(geometry_events.len)
					var/datum/floodwater_front_cell/cell = geometry_events[geometry_events.len]
					geometry_events -= cell
					refresh_cell(cell)
				else if(resume_geometry(1))
					if(ocean_wakeup)
						wake_ocean_contacts()
						ocean_wakeup = FALSE
					begin(elapsed)
					elapsed = 0
					native_phase = FLOOD_NATIVE_HEADS
					native_cursor = 1
					portal_run = pressure_watch.Copy()
			if(FLOOD_NATIVE_HEADS)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("HeadsC")
				if(native_cursor > portal_run.len)
					native_phase = FLOOD_NATIVE_FRONT
					portal_run = null
				else
					var/datum/floodwater_front_cell/cell = portal_run[native_cursor++]
					if((cell in pressure_watch) && cell.head_pressure() != pressure_watch[cell])
						cell.wake_portals()
			if(FLOOD_NATIVE_FRONT)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("FrontC")
				var/old_jobs = jobs
				var/old_edges = neighbor_visits
				if(resume(1))
					native_phase = FLOOD_NATIVE_PORTALS
					native_cursor = 1
					portal_run = open_portals.Copy()
				if(jobs != old_jobs)
					ocean_wakeup = TRUE
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.tiles += jobs - old_jobs
					SSfloodwater.debug.edges += neighbor_visits - old_edges
			if(FLOOD_NATIVE_PORTALS)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("PortalsC")
				if(native_cursor > portal_run.len)
					native_phase = FLOOD_NATIVE_VERTICAL
					native_cursor = 1
					portal_run = open_vertical_portals.Copy()
				else
					var/datum/floodwater_front_portal/portal = portal_run[native_cursor++]
					var/turf/open/left_tile = portal.left.tile
					portal.set_open(!portal.left.blocked && !portal.right.blocked && (portal.left.region != portal.right.region || portal.pressure_link) && left_tile.can_pass_stationtrauma_water(portal.right.tile))
					if(!portal.commit(portal.prepare(run_dt)))
						portal.sleep_until_changed()
					if(portal.pressure_link && portal.open && !portal.left.root()?.dirty && !portal.right.root()?.dirty && abs(portal.left.head_pressure() - portal.right.head_pressure()) <= FLOOD_WATER_HEAD_EPSILON)
						portal.pressure_link = FALSE
						portal.set_open(FALSE)
						set_link(portal.left, portal.right, TRUE)
			if(FLOOD_NATIVE_VERTICAL)
				if(SSfloodwater.debug.enabled)
					SSfloodwater.debug.measure_phase("VerticalC")
				if(native_cursor > portal_run.len)
					native_phase = FLOOD_NATIVE_LEVELS
					native_cursor = 1
					portal_run = null
				else
					var/datum/floodwater_front_portal/portal = portal_run[native_cursor++]
					var/turf/open/upper = portal.left.tile
					portal.set_open(!portal.left.blocked && !portal.right.blocked && upper.can_pass_stationtrauma_water_down(portal.right.tile))
					if(!portal.commit(portal.prepare(run_dt)))
						portal.sleep_until_changed()
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
	restore_stationtrauma_hull(tile)
	RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(turf_changed))
	RegisterSignals(tile, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(native_changed))
	watch_obstacles()

/datum/floodwater_front_cell/proc/unwatch_turf()
	UnregisterSignal(tile, list(COMSIG_TURF_CHANGE, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON))
	for(var/obj/obstacle as anything in obstacles)
		UnregisterSignal(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING))
	obstacles.Cut()

/datum/floodwater_front_cell/proc/watch_obstacles()
	for(var/obj/obstacle as anything in obstacles.Copy())
		if(QDELETED(obstacle) || obstacle.loc != tile)
			UnregisterSignal(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING))
			obstacles -= obstacle
	for(var/obj/obstacle in tile)
		if(obstacle.can_atmos_pass == ATMOS_PASS_YES || (obstacle in obstacles))
			continue
		obstacles |= obstacle
		RegisterSignals(obstacle, list(COMSIG_ATOM_DENSITY_CHANGED, COMSIG_ATOM_DIR_CHANGE, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING), PROC_REF(native_changed))

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
	if(!ispath(path, /turf/open/floor))
		impulse_floor_repair = FALSE
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
