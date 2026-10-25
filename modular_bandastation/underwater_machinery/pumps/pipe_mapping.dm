// Mapper hierarchy and map sprites follow atmos mapping.dm; gameplay networks stay separate.
#define ST_PIPE_MAP_LEVELS(Path, LevelVar, State) \
	##Path/layer1 { LevelVar = 1; icon_state = State + "-1"; } \
	##Path/layer2 { LevelVar = 2; icon_state = State + "-2"; } \
	##Path/layer4 { LevelVar = 4; icon_state = State + "-4"; } \
	##Path/layer5 { LevelVar = 5; icon_state = State + "-5"; }

#define ST_PIPE_MAP_VISIBILITY(Path, LevelVar, State) \
	##Path/visible { hide = FALSE; layer = GAS_PIPE_VISIBLE_LAYER; } \
	##Path/hidden { hide = TRUE; layer = GAS_PIPE_HIDDEN_LAYER; } \
	ST_PIPE_MAP_LEVELS(Path/visible, LevelVar, State) \
	ST_PIPE_MAP_LEVELS(Path/hidden, LevelVar, State)

ST_PIPE_MAP_VISIBILITY(/obj/machinery/duct/stationtrauma, water_level, "manifold4w")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/duct/stationtrauma/simple, water_level, "pipe11")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/duct/stationtrauma/straight, water_level, "pipe11")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/duct/stationtrauma/tee, water_level, "manifold")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/duct/stationtrauma/cross, water_level, "manifold4w")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/stationtrauma_reactor_pipe, piping_layer, "manifold4w")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/stationtrauma_reactor_pipe/valve, piping_layer, "mvalve_map")
ST_PIPE_MAP_VISIBILITY(/obj/machinery/stationtrauma_reactor_pipe/pump, piping_layer, "pump_map")

ST_PIPE_MAP_LEVELS(/obj/machinery/stationtrauma_water_device/valve/manual, water_level, "mvalve_map")
ST_PIPE_MAP_LEVELS(/obj/machinery/stationtrauma_water_device/inline_pump/pressure, water_level, "pump_map")
ST_PIPE_MAP_LEVELS(/obj/machinery/stationtrauma_water_device/valve/passive_gate, water_level, "passgate_map")
ST_PIPE_MAP_LEVELS(/obj/machinery/stationtrauma_water_device/valve/pressure_gate, water_level, "pvalve_map")

#undef ST_PIPE_MAP_VISIBILITY
#undef ST_PIPE_MAP_LEVELS
