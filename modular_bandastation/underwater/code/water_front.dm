/// Conservative aggregate volumes and delayed local fronts; native bindings live in water_hybrid.dm.
#define FLOOD_FRONT_CAPACITY 2200
#define FLOOD_FRONT_SEED 10
#define FLOOD_FRONT_RATE 2000

/// Internal state for conservative fronts and resumable connectivity.
/datum/floodwater_front_cell
	/// Stable cell identity inside the selected test domain.
	var/id
	/// Room interiors share region 1; each door throat has its own region.
	var/region = 1
	/// Current two-sided passable edges, excluding separate portal edges.
	var/list/neighbors = list()
	/// Owner of this reached wet footprint.
	var/datum/floodwater_front_group/group
	/// TRUE while volume and heat are held in a local front packet.
	var/local = FALSE
	/// Finite litres, either local or aggregated over bulk_count cells.
	var/volume = 0
	/// Conserved litre-kelvin paired with volume.
	var/heat = 0
	/// First front clock that reached this cell.
	var/arrival = -1
	/// The live turf cannot hold finite interior water.
	var/blocked = FALSE
	/// Temporary materialized bulk share during a connectivity rebuild.
	var/transient = FALSE
	/// Finite water retained while its floor is replaced or blocked.
	var/displaced_volume = 0
	/// Heat paired with displaced_volume.
	var/displaced_heat = 0

/// Internal state for conservative fronts and resumable connectivity.
/datum/floodwater_front_group
	/// Former owner forwarding, retained for root resolution.
	var/datum/floodwater_front_group/merged_into
	/// Settled cells sharing one aggregate volume.
	var/list/members = list()
	/// Actual currently owned cells; publication uses a separate planned footprint.
	var/list/wet = list()
	/// Remaining aggregate shares, including during partial materialization.
	var/bulk_count = 0
	/// Actual ownership count, independent of planned traversal.
	var/owned_count = 0
	/// Transfers are rejected until current connectivity is published.
	var/dirty = FALSE
	/// Empty owner removed from the solver.
	var/retired = FALSE
	/// Whether this owner is present in the live owner list.
	var/registered = FALSE
	/// Per-cell bulk share fixed during a paused rebuild.
	var/frozen_volume = 0
	/// Per-cell heat share fixed during a paused rebuild.
	var/frozen_heat = 0
	/// Only local fronts and cells bordering unreached floors.
	var/list/boundary = list()
	/// Finite litres, either local or aggregated over bulk_count cells.
	var/volume = 0
	/// Conserved litre-kelvin paired with volume.
	var/heat = 0

/datum/floodwater_front_group/proc/root()
	RETURN_TYPE(/datum/floodwater_front_group)
	if(merged_into)
		merged_into = merged_into.root()
		return merged_into
	return src

/datum/floodwater_front_cell/proc/root()
	RETURN_TYPE(/datum/floodwater_front_group)
	if(group)
		group = group.root()
	return group

/datum/floodwater_front_cell/proc/amount()
	if(blocked)
		return 0
	if(local)
		return volume
	var/datum/floodwater_front_group/owner = root()
	return owner ? (owner.dirty ? owner.frozen_volume : owner.volume / owner.members.len) : 0

/datum/floodwater_front_cell/proc/temperature()
	if(local)
		return volume ? heat / volume : FLOOD_WATER_TEMPERATURE
	var/datum/floodwater_front_group/owner = root()
	return owner?.dirty ? (owner.frozen_volume ? owner.frozen_heat / owner.frozen_volume : FLOOD_WATER_TEMPERATURE) : (owner?.volume ? owner.heat / owner.volume : FLOOD_WATER_TEMPERATURE)

/datum/floodwater_front_cell/proc/level()
	var/litres = amount()
	return litres <= 0 ? 0 : litres < 400 ? 1 : litres < 2000 ? 2 : 3

/datum/floodwater_front_cell/proc/capacity()
	if(blocked)
		return 0
	var/datum/floodwater_front_group/owner = root()
	return !owner || local ? FLOOD_FRONT_CAPACITY - volume : owner.members.len * FLOOD_FRONT_CAPACITY - owner.volume

/datum/floodwater_front_cell/proc/available()
	var/datum/floodwater_front_group/owner = root()
	return local ? volume : owner?.volume || 0

/// Internal state for conservative fronts and resumable connectivity.
/datum/floodwater_front_solver
	/// Deduplicated cells whose native presentation or lifecycle needs refreshing.
	var/list/changed = list()
	/// Finite domain cells, with stable identities across turf replacement.
	var/list/cells = list()
	/// Live finite owners.
	var/list/groups = list()
	/// Deduplicated next-front jobs.
	var/list/pending = list()
	/// Completed front intervals; arrivals cannot cross a dry gap instantly.
	var/clock = 0
	/// Current resumable front snapshot.
	var/list/run = list()
	/// Next front job in run.
	var/cursor = 1
	/// Elapsed physical time used by the current front.
	var/run_dt = 0.1
	/// Processed front jobs, excluding sleeping interiors.
	var/jobs = 0
	/// Front edge visits for profiling.
	var/neighbor_visits = 0
	/// Largest observed pending front queue.
	var/max_queue = 0
	/// Wet-contact merge events.
	var/merges = 0
	/// Revision invalidating paused geometry and transfer plans.
	var/geometry_version = 0
	/// Owners queued for incremental connectivity repair.
	var/list/dirty_groups = list()
	/// Cells awaiting restoration of displaced water.
	var/list/restore = list()
	/// Current resumable connectivity job.
	var/datum/floodwater_front_rebuild/rebuild
	/// Processed connectivity work units.
	var/geometry_jobs = 0
	/// Connectivity restarts caused by newer events.
	var/restarts = 0

/datum/floodwater_front_solver/proc/enqueue(datum/floodwater_front_cell/cell)
	pending[cell] = TRUE
	changed[cell] = TRUE
	max_queue = max(max_queue, pending.len)

/datum/floodwater_front_solver/proc/wake(datum/floodwater_front_group/owner)
	if(owner.dirty)
		return
	for(var/datum/floodwater_front_cell/cell as anything in owner.boundary)
		enqueue(cell)

/datum/floodwater_front_solver/proc/start(datum/floodwater_front_cell/cell)
	var/datum/floodwater_front_group/owner = new
	groups += owner
	owner.registered = TRUE
	owner.members += cell
	owner.bulk_count++
	owner.wet[cell] = TRUE
	owner.boundary[cell] = TRUE
	cell.group = owner
	owner.owned_count = 1
	cell.arrival = clock
	return owner

/datum/floodwater_front_solver/proc/receive(datum/floodwater_front_cell/cell, requested, temperature)
	if(cell.blocked || cell.root()?.dirty)
		return 0
	if(requested <= 0)
		return 0
	var/amount = min(requested, cell.capacity())
	if(amount <= 0)
		return 0
	var/datum/floodwater_front_group/owner = cell.root() || start(cell)
	if(cell.local)
		cell.volume += amount
		cell.heat += amount * temperature
	else
		owner.volume += amount
		owner.heat += amount * temperature
	wake(owner)
	changed[cell] = TRUE
	return amount

/datum/floodwater_front_solver/proc/withdraw(datum/floodwater_front_cell/cell, requested)
	if(cell.blocked || cell.root()?.dirty)
		return 0
	var/amount = min(max(0, requested), cell.available())
	var/temperature = cell.temperature()
	var/datum/floodwater_front_group/owner = cell.root()
	if(cell.local)
		cell.volume -= amount
		cell.heat -= amount * temperature
		if(!cell.volume)
			cell.heat = 0
	else if(owner)
		owner.volume -= amount
		owner.heat -= amount * temperature
		if(!owner.volume)
			owner.heat = 0
	if(amount)
		// Free capacity vents this simplified model; a withdrawal releases full-room head.
		if(owner)
			owner.pressure_head = 0
			owner.pressure_remainder = 0
		cell.pressure_head = 0
		changed[cell] = TRUE
	return amount

/datum/floodwater_front_solver/proc/merge(datum/floodwater_front_group/left, datum/floodwater_front_group/right)
	if(left == right)
		return left
	geometry_version++
	invalidate(left)
	invalidate(right)
	merges++
	return left

// Only reached wet cells are eligible. New jobs wait until the next fire.
/datum/floodwater_front_solver/proc/begin(dt = 0.1)
	if(cursor <= run.len)
		CRASH("Previous water front must finish before starting the next")
	clock++
	run = pending
	pending = list()
	cursor = 1
	run_dt = dt

/datum/floodwater_front_solver/proc/resume(budget = 32)
	while(cursor <= run.len && budget-- > 0)
		process_cell(run[cursor++], run_dt)
	return cursor > run.len

/datum/floodwater_front_solver/proc/process_cell(datum/floodwater_front_cell/cell, dt)
	var/datum/floodwater_front_group/owner = cell.root()
	if(cell.blocked || !owner || owner.dirty)
		return
	jobs++
	if(cell.local)
		var/difference = owner.volume / owner.members.len - cell.volume
		var/amount = min(FLOOD_FRONT_RATE * dt, abs(difference) / (1 + 1 / owner.members.len))
		if(difference > 0)
			var/temperature = owner.volume ? owner.heat / owner.volume : FLOOD_WATER_TEMPERATURE
			amount = withdraw(owner.members[1], amount)
			cell.volume += amount
			cell.heat += amount * temperature
		else if(difference < 0)
			var/temperature = cell.temperature()
			amount = withdraw(cell, amount)
			owner.volume += amount
			owner.heat += amount * temperature
		if(abs(owner.volume / owner.members.len - cell.volume) < 0.01)
			owner.volume += cell.volume
			owner.heat += cell.heat
			owner.members += cell
			owner.bulk_count++
			owner.wet[cell] = TRUE
			cell.volume = 0
			cell.heat = 0
			cell.local = FALSE
	/// Has dry neighbor.
	var/has_dry_neighbor = FALSE
	for(var/datum/floodwater_front_cell/neighbor as anything in cell.neighbors)
		neighbor_visits++
		if(!can_link(cell, neighbor))
			continue
		var/datum/floodwater_front_group/neighbor_owner = neighbor.root()
		if(neighbor_owner)
			if(neighbor_owner != owner)
				owner = merge(owner, neighbor_owner)
				return
			continue
		has_dry_neighbor = TRUE
		if(cell.amount() < 2 * FLOOD_FRONT_SEED)
			continue
		var/temperature = cell.temperature()
		var/seed = withdraw(cell, FLOOD_FRONT_SEED)
		neighbor.group = owner
		owner.wet[neighbor] = TRUE
		owner.owned_count++
		neighbor.local = TRUE
		neighbor.volume = seed
		neighbor.heat = seed * temperature
		neighbor.arrival = clock
		owner.boundary[neighbor] = TRUE
		enqueue(neighbor)
	if(!has_dry_neighbor && !cell.local)
		owner.boundary -= cell
	else if(cell.local || cell.amount() >= 2 * FLOOD_FRONT_SEED)
		enqueue(cell)

// A plan does not reserve water; commit rechecks the door and live endpoints.
/// Internal state for conservative fronts and resumable connectivity.
/datum/floodwater_front_portal
	/// Solver owning this portal or traversal.
	var/datum/floodwater_front_solver/solver
	/// First live portal endpoint.
	var/datum/floodwater_front_cell/left
	/// Second live portal endpoint.
	var/datum/floodwater_front_cell/right
	/// Whether the native boundary currently permits passage.
	var/open = FALSE
	/// Maximum conservative portal transfer in litres per second.
	var/rate = 3000
	/// Door-local revision for cancellation of stale transfer plans.
	var/revision = 0
	/// Effective opening area, independent of the ordinary front transfer rate.
	var/opening = FLOOD_WATER_BREACH_OPENING
	/// Temporary full/full connection held apart until a confirmed head exchange.
	var/pressure_link = FALSE
	/// Each prepared transfer can be committed only once, including after MC resume.
	var/serial = 0
	/// Last consumed plan identity.
	var/committed_serial = 0

/datum/floodwater_front_portal/proc/prepare(dt = 0.1)
	if(!open || left.blocked || right.blocked || left.root()?.dirty || right.root()?.dirty)
		return null
	if(left.root()?.is_full() && right.root()?.is_full())
		return prepare_head(dt)
	var/datum/floodwater_front_cell/source = left.amount() > right.amount() ? left : right
	var/datum/floodwater_front_cell/destination = source == left ? right : left
	return list(source, destination, rate * dt, revision, solver.geometry_version, ++serial)

/datum/floodwater_front_portal/proc/commit(list/plan)
	if(!open || !plan || revision != plan[4] || solver.geometry_version != plan[5] || plan[6] <= committed_serial || left.blocked || right.blocked || left.root()?.dirty || right.root()?.dirty)
		return 0
	if(plan.len > 6)
		return commit_head(plan)
	var/datum/floodwater_front_cell/source = plan[1]
	var/datum/floodwater_front_cell/destination = plan[2]
	var/datum/floodwater_front_group/from_group = source.root()
	var/datum/floodwater_front_group/to_group = destination.root()
	var/source_count = source.local ? 1 : from_group?.members.len || 1
	var/destination_count = destination.local ? 1 : to_group?.members.len || 1
	/// Equalizing.
	var/equalizing = max(0, source.amount() - destination.amount()) / (1 / source_count + 1 / destination_count)
	var/amount = min(plan[3], equalizing, source.available(), destination.capacity())
	if(amount <= 0)
		return 0
	var/temperature = source.temperature()
	var/difference = source.head_pressure() - destination.head_pressure()
	// Paired changes complete before returning or yielding.
	solver.withdraw(source, amount)
	solver.receive(destination, amount, temperature)
	committed_serial = plan[6]
	solver.confirm_flow(source, destination, amount, difference, opening)
	return amount
