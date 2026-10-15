#define FLOOD_FRONT_REBUILD_COLLECT 1
#define FLOOD_FRONT_REBUILD_DISCOVER 2
#define FLOOD_FRONT_REBUILD_ASSIGN 3
#define FLOOD_FRONT_REBUILD_COARSEN 4
#define FLOOD_FRONT_REBUILD_RETIRE 5
#define FLOOD_FRONT_REBUILD_WAKE 6

/** Freeze just the affected reservoirs; finite sources keep unaccepted water. */
/datum/floodwater_front_solver/proc/invalidate(datum/floodwater_front_group/owner)
	if(!owner || owner.retired)
		return
	owner.dirty = TRUE
	owner.frozen_volume = owner.bulk_count ? owner.volume / owner.bulk_count : 0
	owner.frozen_heat = owner.bulk_count ? owner.heat / owner.bulk_count : 0
	dirty_groups[owner] = TRUE

/** The live graph is authoritative even when a queued traversal describes an old wall. */
/datum/floodwater_front_solver/proc/can_link(datum/floodwater_front_cell/left, datum/floodwater_front_cell/right)
	return !left.blocked && !right.blocked && left.region == right.region && (right in left.neighbors) && (left in right.neighbors)

/datum/floodwater_front_solver/proc/set_link(datum/floodwater_front_cell/left, datum/floodwater_front_cell/right, opened)
	if((right in left.neighbors) == opened)
		return
	if(opened)
		left.neighbors |= right
		right.neighbors |= left
	else
		left.neighbors -= right
		right.neighbors -= left
	geometry_version++
	invalidate(left.root())
	invalidate(right.root())

/** Wall replacement keeps displaced finite water in a packet, never in the external ocean. */
/datum/floodwater_front_solver/proc/set_blocked(datum/floodwater_front_cell/cell, blocked)
	if(cell.blocked == blocked)
		return
	cell.blocked = blocked
	geometry_version++
	invalidate(cell.root())
	for(var/datum/floodwater_front_cell/neighbor as anything in cell.neighbors)
		invalidate(neighbor.root())
	if(!blocked && cell.displaced_volume)
		restore[cell] = TRUE

/datum/floodwater_front_portal/proc/set_open(opened)
	if(open == opened)
		return
	open = opened
	revision++

/datum/floodwater_front_solver/proc/retire_empty(datum/floodwater_front_group/owner)
	if(owner.owned_count)
		return
	if(owner.volume || owner.heat || owner.bulk_count)
		CRASH("Retired water owner still contains finite water")
	owner.retired = TRUE
	groups -= owner
	dirty_groups -= owner
	owner.members.Cut()
	owner.wet.Cut()
	owner.boundary.Cut()

/** One budget covers discovery, attachment, volume moves and wakeup. */
/datum/floodwater_front_solver/proc/resume_geometry(budget = 32)
	while(budget-- > 0)
		if(!rebuild && dirty_groups.len)
			rebuild = new(src)
		if(rebuild)
			if(rebuild.version != geometry_version)
				rebuild.restart()
				restarts++
			geometry_jobs++
			if(rebuild.advance_unit())
				rebuild = null
			continue
		if(restore.len)
			var/datum/floodwater_front_cell/cell = restore[restore.len]
			restore -= cell
			restore_displaced(cell)
			continue
		return TRUE
	return !rebuild && !dirty_groups.len && !restore.len

/** Restore displaced finite stocks once capacity is available; blocked walls keep their packet. */
/datum/floodwater_front_solver/proc/restore_displaced(datum/floodwater_front_cell/cell)
	if(cell.blocked || !cell.displaced_volume)
		return
	var/restored_head = cell.pressure_head
	var/temperature = cell.displaced_heat / cell.displaced_volume
	var/accepted = receive(cell, cell.displaced_volume, temperature)
	var/datum/floodwater_front_group/owner = cell.root()
	if(accepted && owner?.is_full())
		// Reopening a full packet must retain its head, rather than invent another decompression.
		owner.pressure_head = max(owner.pressure_head, restored_head)
	cell.displaced_volume -= accepted
	cell.displaced_heat -= accepted * temperature
	if(!cell.displaced_volume)
		cell.displaced_heat = 0
	// shortcut: wall overflow still needs a later geometry event; closed-door overflow observes withdrawals.

/** Temporary per-cell packets exist only during geometry changes, not normal simulation. */
/datum/floodwater_front_rebuild
	/// Solver owning this portal or traversal.
	var/datum/floodwater_front_solver/solver
	/// Old owners whose live packets are being repartitioned.
	var/list/sources = list()
	/// New owners under construction.
	var/list/candidates = list()
	/// Planned footprints, separate from actual published ownership.
	var/list/footprints = list()
	/// Wet cells awaiting connected-component discovery.
	var/list/unvisited = list()
	/// Blocked or empty cells awaiting ownership removal.
	var/list/removed = list()
	/// Resumable connectivity phase.
	var/phase = FLOOD_FRONT_REBUILD_COLLECT
	/// Geometry revision used by this traversal.
	var/version
	/// Next old owner to materialize or retire.
	var/source_cursor = 1
	/// Next ownership or materialization unit.
	var/cell_cursor = 1
	/// Next new owner to publish.
	var/candidate_cursor = 1
	/// Connected component currently being discovered.
	var/datum/floodwater_front_group/current
	/// Next BFS cell in the current planned footprint.
	var/discover_cursor = 1
	/// Bulk shares found in the current planned component.
	var/planned_bulk = 0
	/// Next unvisited discovery seed.
	var/seed_cursor = 1

/datum/floodwater_front_rebuild/New(datum/floodwater_front_solver/owner)
	solver = owner
	restart()

/** Restart uses live ownership and remaining bulk counts, including half-published results. */
/datum/floodwater_front_rebuild/proc/restart()
	for(var/datum/floodwater_front_group/owner as anything in candidates)
		if(owner.registered && !owner.retired)
			sources |= owner
	sources |= solver.dirty_groups
	solver.dirty_groups = list()
	/// Live sources.
	var/list/live_sources = list()
	for(var/datum/floodwater_front_group/owner as anything in sources)
		if(owner.retired)
			continue
		live_sources |= owner
		owner.dirty = TRUE
		owner.frozen_volume = owner.bulk_count ? owner.volume / owner.bulk_count : 0
		owner.frozen_heat = owner.bulk_count ? owner.heat / owner.bulk_count : 0
	sources = live_sources
	candidates = list()
	footprints = list()
	unvisited = list()
	removed = list()
	phase = FLOOD_FRONT_REBUILD_COLLECT
	version = solver.geometry_version
	source_cursor = 1
	cell_cursor = 1
	candidate_cursor = 1
	current = null
	seed_cursor = 1

/datum/floodwater_front_rebuild/proc/advance_unit()
	switch(phase)
		if(FLOOD_FRONT_REBUILD_COLLECT)
			if(source_cursor > sources.len)
				phase = FLOOD_FRONT_REBUILD_DISCOVER
				return FALSE
			var/datum/floodwater_front_group/owner = sources[source_cursor]
			if(owner.retired || cell_cursor > owner.wet.len)
				source_cursor++
				cell_cursor = 1
				return FALSE
			var/datum/floodwater_front_cell/cell = owner.wet[cell_cursor++]
			if(cell.root() != owner)
				return FALSE
			if(!cell.local)
				cell.pressure_head = owner.pressure_head
				cell.volume = owner.bulk_count == 1 ? owner.volume : min(owner.volume, owner.frozen_volume)
				cell.heat = owner.bulk_count == 1 ? owner.heat : min(owner.heat, owner.frozen_heat)
				owner.volume -= cell.volume
				owner.heat -= cell.heat
				owner.bulk_count--
				cell.local = TRUE
				cell.transient = TRUE
			if(cell.blocked || !cell.volume)
				removed[cell] = TRUE
			else
				unvisited[cell] = TRUE
			return FALSE

		if(FLOOD_FRONT_REBUILD_DISCOVER)
			if(!current)
				if(seed_cursor > unvisited.len)
					phase = FLOOD_FRONT_REBUILD_ASSIGN
					cell_cursor = 1
					return FALSE
				var/datum/floodwater_front_cell/seed = unvisited[seed_cursor++]
				if(!unvisited[seed])
					return FALSE
				current = new
				current.dirty = TRUE
				candidates += current
				current.wet[seed] = TRUE
				unvisited[seed] = FALSE
				discover_cursor = 1
				planned_bulk = 0
			if(discover_cursor > current.wet.len)
				if(!planned_bulk)
					var/datum/floodwater_front_cell/promoted = current.wet[1]
					promoted.transient = TRUE
				footprints[current] = current.wet
				current.wet = list()
				current = null
				return FALSE
			var/datum/floodwater_front_cell/cell = current.wet[discover_cursor++]
			if(cell.transient)
				planned_bulk++
			else
				current.boundary[cell] = TRUE
			for(var/datum/floodwater_front_cell/neighbor as anything in cell.neighbors)
				if(!solver.can_link(cell, neighbor))
					continue
				if(unvisited[neighbor])
					current.wet[neighbor] = TRUE
					unvisited[neighbor] = FALSE
				else if(!neighbor.group)
					current.boundary[cell] = TRUE
			return FALSE

		if(FLOOD_FRONT_REBUILD_ASSIGN)
			if(candidate_cursor > candidates.len)
				if(removed.len)
					var/datum/floodwater_front_cell/cell = removed[removed.len]
					removed -= cell
					cell.displaced_volume += cell.volume
					cell.displaced_heat += cell.heat
					solver.restore[cell] = TRUE
					cell.volume = 0
					cell.heat = 0
					cell.local = FALSE
					cell.transient = FALSE
					var/datum/floodwater_front_group/old_owner = cell.root()
					old_owner.wet[cell] = FALSE
					old_owner.owned_count--
					cell.group = null
					solver.changed[cell] = TRUE
					solver.pending -= cell
					solver.retire_empty(old_owner)
					return FALSE
				phase = FLOOD_FRONT_REBUILD_COARSEN
				candidate_cursor = 1
				cell_cursor = 1
				return FALSE
			var/datum/floodwater_front_group/owner = candidates[candidate_cursor]
			var/list/footprint = footprints[owner]
			if(!owner.registered)
				owner.registered = TRUE
				solver.groups += owner
			if(cell_cursor > footprint.len)
				candidate_cursor++
				cell_cursor = 1
				return FALSE
			var/datum/floodwater_front_cell/cell = footprint[cell_cursor++]
			var/datum/floodwater_front_group/old_owner = cell.root()
			old_owner.wet[cell] = FALSE
			old_owner.owned_count--
			owner.wet[cell] = TRUE
			owner.owned_count++
			cell.group = owner
			solver.retire_empty(old_owner)
			return FALSE

		if(FLOOD_FRONT_REBUILD_COARSEN)
			if(candidate_cursor > candidates.len)
				phase = FLOOD_FRONT_REBUILD_RETIRE
				source_cursor = 1
				return FALSE
			var/datum/floodwater_front_group/owner = candidates[candidate_cursor]
			var/list/footprint = footprints[owner]
			if(cell_cursor > footprint.len)
				candidate_cursor++
				cell_cursor = 1
				return FALSE
			var/datum/floodwater_front_cell/cell = footprint[cell_cursor++]
			if(cell.transient)
				owner.members += cell
				owner.bulk_count++
				owner.pressure_head = (owner.pressure_head * owner.volume + cell.pressure_head * cell.volume) / (owner.volume + cell.volume)
				owner.volume += cell.volume
				owner.heat += cell.heat
				cell.volume = 0
				cell.heat = 0
				cell.local = FALSE
				cell.transient = FALSE
				owner.frozen_volume = owner.volume / owner.bulk_count
				owner.frozen_heat = owner.heat / owner.bulk_count
			return FALSE

		if(FLOOD_FRONT_REBUILD_RETIRE)
			if(source_cursor > sources.len)
				phase = FLOOD_FRONT_REBUILD_WAKE
				candidate_cursor = 1
				cell_cursor = 1
				return FALSE
			var/datum/floodwater_front_group/owner = sources[source_cursor++]
			solver.retire_empty(owner)
			return FALSE

		if(FLOOD_FRONT_REBUILD_WAKE)
			if(candidate_cursor > candidates.len)
				return TRUE
			var/datum/floodwater_front_group/owner = candidates[candidate_cursor]
			if(cell_cursor > owner.wet.len)
				owner.dirty = FALSE
				candidate_cursor++
				cell_cursor = 1
				return FALSE
			var/datum/floodwater_front_cell/cell = owner.wet[cell_cursor++]
			if(owner.boundary[cell])
				solver.enqueue(cell)
			return FALSE
	return FALSE
