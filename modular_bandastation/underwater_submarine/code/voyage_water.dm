/** A shuttle relocation briefly fences water while native turf callbacks replace its coordinates. */
/datum/controller/subsystem/floodwater
	/// Source and destination turf identities fenced only during the physical relocation.
	var/list/relocating_turfs = list()

/** Keep the existing cell/group identities and stocks; only their native turf bindings travel. */
/datum/floodwater_hybrid/proc/relocate_vessel(list/mapping, finish = FALSE, datum/stationtrauma_work_budget/budget)
	if(!finish)
		for(var/turf/tile as anything in mapping)
			var/datum/floodwater_front_cell/cell = by_turf[tile]
			if(cell)
				cell.unwatch_turf()
				QDEL_NULL(cell.stream_visual)
			if(budget)
				budget.yield()
			else
				CHECK_TICK
		return
	var/list/moved = list()
	for(var/turf/tile as anything in mapping)
		var/datum/floodwater_front_cell/cell = by_turf[tile]
		if(!cell)
			continue
		by_turf -= tile
		cell.tile = mapping[tile]
		moved += cell
	for(var/datum/floodwater_front_cell/cell as anything in moved)
		by_turf[cell.tile] = cell
	for(var/datum/floodwater_front_cell/cell as anything in moved)
		cell.watch_turf()
		geometry_events[cell] = TRUE
		changed[cell] = TRUE
		paint(cell)
		if(budget)
			budget.yield()
		else
			CHECK_TICK
	geometry_version++

/** No aggregate, cached neighbor or pipe network may straddle the moving footprint. */
/obj/docking_port/mobile/stationtrauma/proc/connections_contained(list/tiles)
	var/datum/floodwater_hybrid/solver = SSfloodwater.hybrid
	var/list/owners = list()
	for(var/turf/tile as anything in tiles)
		var/datum/floodwater_front_cell/cell = solver.by_turf[tile]
		if(cell)
			var/datum/floodwater_front_group/owner = cell.root()
			if(owner && !owners[owner])
				owners[owner] = TRUE
				for(var/datum/floodwater_front_cell/member as anything in owner.members)
					if(!(member.tile in tiles))
						return FALSE
			for(var/datum/floodwater_front_cell/neighbor as anything in cell.neighbors)
				if(!(neighbor.tile in tiles))
					return FALSE
		for(var/atom/movable/device as anything in tile)
			if(istype(device, /obj/structure/ladder) && (device.resistance_flags & INDESTRUCTIBLE))
				return FALSE
			if(istype(device, /obj/machinery/button/stationtrauma_water_airlock))
				var/obj/machinery/button/stationtrauma_water_airlock/controller = device
				if(controller.cycling)
					return FALSE
			for(var/datum/component/plumbing/connection as anything in device.GetComponents(/datum/component/plumbing))
				for(var/key in connection.ducts)
					var/datum/ductnet/network = connection.ducts[key]
					for(var/obj/machinery/duct/pipe as anything in network.ducts)
						if(!(get_turf(pipe) in tiles))
							return FALSE
					for(var/datum/component/plumbing/other as anything in network.suppliers + network.demanders)
						if(!(get_turf(other.parent) in tiles))
							return FALSE
	return TRUE
