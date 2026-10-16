/** Snapshot local packets and selected bulk shares; withdraw once per aggregate to preserve full drainage. */
/proc/drain_stationtrauma_water_room(turf/open/intake, volume, datum/reagents/receiver, residual_depth = 0, list/room)
	if(!isopenturf(intake) || QDELETED(receiver) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0)
		return 0
	var/datum/component/floodwater/source_water = intake.GetComponent(/datum/component/floodwater)
	if(source_water?.infinite_source)
		return 0
	room ||= intake.stationtrauma_water_intake()
	var/list/contributions = list()
	var/list/bulk_cells = list()
	var/list/bulk_counts = list()
	for(var/turf/open/tile as anything in room)
		var/datum/floodwater_front_cell/cell = SSfloodwater.hybrid.by_turf[tile]
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		if(!cell || cell.blocked || cell.root()?.dirty || water?.infinite_source)
			continue
		var/amount = max(0, cell.amount() - residual_depth * FLOOD_WATER_LITRES_PER_CM)
		if(amount <= 0)
			continue
		if(cell.local)
			contributions[cell] = amount
		else
			var/datum/floodwater_front_group/owner = cell.root()
			var/datum/floodwater_front_cell/representative = bulk_cells[owner]
			if(!representative)
				representative = cell
				bulk_cells[owner] = representative
			bulk_counts[owner]++
			contributions[representative] += amount
	for(var/datum/floodwater_front_group/owner as anything in bulk_cells)
		if(!residual_depth && bulk_counts[owner] == owner.members.len)
			// The saved total is authoritative; adding rounded per-cell means can leave a permanent tail.
			contributions[bulk_cells[owner]] = owner.volume
	var/available = 0
	for(var/datum/floodwater_front_cell/cell as anything in contributions)
		var/amount = contributions[cell]
		available += amount
	if(available <= 0)
		return 0
	var/free_space = receiver.maximum_volume - receiver.total_volume
	var/amount = min(available, volume, max(0, free_space))
	if(amount <= 0)
		return 0
	var/datum/floodwater_debug/debug = SSfloodwater.debug
	var/previous_phase = debug.phase_name
	if(debug.enabled)
		debug.measure_phase("PumpDeposit")
	var/accepted = store_stationtrauma_water(receiver, amount)
	if(debug.enabled)
		debug.measure_phase(previous_phase)
	if(accepted <= 0)
		return 0
	var/fraction = accepted / available
	if(debug.enabled)
		debug.measure_phase("PumpWithdraw")
	// No yield or callback may separate the holder deposit from its paired finite withdrawals.
	for(var/datum/floodwater_front_cell/cell as anything in contributions)
		var/removed = contributions[cell] * fraction
		SSfloodwater.hybrid.withdraw(cell, removed)
	if(debug.enabled)
		debug.measure_phase(previous_phase)
	return accepted
