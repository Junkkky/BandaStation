/// Bright, wide mapping light matching the event nebula and portals.
/obj/effect/light_emitter/gate_closure
	name = "ивент: свет параллакса, большой"
	light_color = "#e52b87"
	set_luminosity = 12
	set_cap = 1.5

/// A small pool of nebula-colored light.
/obj/effect/light_emitter/gate_closure/small
	name = "ивент: свет параллакса, малый"
	set_luminosity = 3
	set_cap = 1

/// Red counterpart of the wide event light.
/obj/effect/light_emitter/gate_closure/red
	name = "ивент: красный свет, большой"
	light_color = "#ff3030"

/// A small pool of red light.
/obj/effect/light_emitter/gate_closure/red/small
	name = "ивент: красный свет, малый"
	set_luminosity = 3
	set_cap = 1

/// Persistent, click-through haze; its footprint follows the mapper's cardinal direction.
/obj/effect/abstract/mist/gate_closure
	name = "ивент: лёгкая дымка"
	desc = "Тонкая пелена тумана."
	icon = 'modular_bandastation/gate_closure/icons/ambient_haze.dmi'
	icon_state = "haze"
	pixel_x = -32
	pixel_y = -32
	alpha = 55
	dir = EAST
	anchored = TRUE
	opacity = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	/// Width of the horizontal haze footprint, in tiles.
	var/mist_width = 15
	/// Height of the horizontal haze footprint, in tiles.
	var/mist_height = 7

/// A smaller patch for corridors and compact spaces.
/obj/effect/abstract/mist/gate_closure/small
	name = "ивент: лёгкая дымка, малая"
	mist_width = 7
	mist_height = 3

/// A broad cloud bank for large open scenes.
/obj/effect/abstract/mist/gate_closure/huge
	name = "ивент: лёгкая дымка, огромная"
	mist_width = 31
	mist_height = 15

/obj/effect/abstract/mist/gate_closure/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_direction_changed))
	update_appearance(UPDATE_ICON_STATE)

/// Rebuild the matrix instead of accumulating transforms when the haze is rotated repeatedly.
/obj/effect/abstract/mist/gate_closure/update_icon_state()
	. = ..()
	var/matrix/orientation = matrix()
	orientation.Scale(mist_width / 3, mist_height / 3)
	switch(dir)
		if(NORTH)
			orientation.Turn(90)
		if(WEST)
			orientation.Turn(180)
		if(SOUTH)
			orientation.Turn(270)
	transform = orientation

/// Keep live admin rotations consistent with map-loaded directions.
/obj/effect/abstract/mist/gate_closure/proc/on_direction_changed()
	SIGNAL_HANDLER
	update_appearance(UPDATE_ICON_STATE)

/// Persistent airborne dust; its DMI provides slow drifting without server-side processing.
/obj/effect/abstract/gate_closure_dust
	name = "ивент: пыль в воздухе"
	desc = "Мелкие пылинки медленно дрейфуют в воздухе."
	icon = 'modular_bandastation/gate_closure/icons/ambient_dust.dmi'
	icon_state = "dust"
	pixel_x = -96
	pixel_y = -96
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	anchored = TRUE
	opacity = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE

/// A 21-by-21-tile field that reuses the small grains without enlarging them.
/obj/effect/abstract/gate_closure_dust/huge
	name = "ивент: пыль в воздухе, огромная"

/obj/effect/abstract/gate_closure_dust/huge/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/effect/abstract/gate_closure_dust/huge/update_overlays()
	. = ..()
	for(var/column in -1 to 1)
		for(var/row in -1 to 1)
			if(!column && !row)
				continue
			var/mutable_appearance/patch = mutable_appearance(icon, icon_state)
			patch.pixel_x = column * 224
			patch.pixel_y = row * 224
			var/matrix/orientation = matrix()
			orientation.Turn((column - row) * 90)
			patch.transform = orientation
			. += patch

#ifdef __DEMIR_BAKE__
/// RMD skips gameplay Initialize(), so bake the same footprint after a mapper rotates the object.
/obj/effect/abstract/mist/gate_closure/demir_bake_appearance()
	update_appearance(UPDATE_ICON_STATE)

/obj/effect/abstract/gate_closure_dust/huge/demir_bake_appearance()
	update_appearance(UPDATE_OVERLAYS)
#endif

/// Event broken-machine marker: breaks every terminal and machine on its tile, unlike the native helper
/// that breaks only the first machinery found, which is often a pipe under the console.
/// Infrastructure and mapper-driven controls keep working.
/obj/effect/mapping_helpers/broken_machine/gate_closure
	name = "ивент: нерабочие машины"

/obj/effect/mapping_helpers/broken_machine/gate_closure/payload(obj/machinery/target)
	for(var/obj/machinery/machine in loc)
		if(is_gate_closure_broken_machine(machine) && !(machine.machine_stat & BROKEN))
			machine.set_machine_stat(machine.machine_stat | BROKEN)

/obj/effect/mapping_helpers/broken_machine/gate_closure/LateInitialize()
	for(var/obj/machinery/machine in loc)
		if(is_gate_closure_broken_machine(machine))
			machine.update_appearance()
	qdel(src)

/// Terminals and machines a ruined scene shows as dead; doors, pipes, canisters, power, lights, gateways and buttons stay intact.
/proc/is_gate_closure_broken_machine(obj/machinery/machine)
	var/static/list/kept = typecacheof(list(
		/obj/machinery/door,
		/obj/machinery/atmospherics,
		/obj/machinery/power,
		/obj/machinery/light,
		/obj/machinery/gateway,
		/obj/machinery/camera,
		/obj/machinery/button,
		/obj/machinery/door_buttons,
		/obj/machinery/portable_atmospherics,
	))
	return !is_type_in_typecache(machine, kept)
