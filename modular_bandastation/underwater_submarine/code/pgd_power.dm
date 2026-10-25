/** Local high-voltage SMES converters retain native terminals, charging and excess-power recovery. */
/obj/machinery/power/smes/stationtrauma_pgd
	name = "высоковольтный преобразователь ПГД"
	desc = "Судовой преобразователь с накопителем на 1 ГДж. Красная линия — вход от реактора, жёлтая — судовая сеть и двигатели."
	circuit = /obj/item/circuitboard/machine/smes/stationtrauma_pgd
	charge = 1 GIGA JOULES
	// Six default inputs share the reactor's 200 MW budget evenly.
	input_level = (200 MEGA WATTS) / 6
	input_level_max = 40 MEGA WATTS
	output_level = 60 MEGA WATTS
	output_level_max = 60 MEGA WATTS

/obj/item/circuitboard/machine/smes/stationtrauma_pgd
	name = "высоковольтный преобразователь ПГД"
	build_path = /obj/machinery/power/smes/stationtrauma_pgd
	def_components = list(/obj/item/stock_parts/power_store/battery = /obj/item/stock_parts/power_store/battery/stationtrauma_pgd)

/obj/item/stock_parts/power_store/battery/stationtrauma_pgd
	name = "судовой сверхпроводящий накопитель"
	maxcharge = 200 MEGA JOULES
	empty = TRUE
