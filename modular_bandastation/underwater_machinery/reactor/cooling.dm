// Legacy mapper paths now place isolated devices; the old gas test loop is retired.
/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump
	parent_type = /obj/machinery/stationtrauma_reactor_pipe/pump
	line = ST_PLANT_COOLANT

/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/precharged
	on = TRUE

/obj/machinery/atmospherics/components/unary/stationtrauma_ocean_exchanger
	parent_type = /obj/machinery/stationtrauma_reactor_pipe/sea_outlet
