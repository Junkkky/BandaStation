// AI EDIT START - expedition planets module integration
// Bay crossings require their authored ports; native smart pipes otherwise reopen all four on mapload.
#define EXPEDITION_PIPE(Type) \
Type/expedition/Initialize(mapload, process, setdir, init_dir = initialize_directions) { \
	return ..(mapload, process, setdir, init_dir); \
}

EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold/general/hidden)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold/general/visible)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold/scrubbers/hidden/layer4)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold/scrubbers/visible/layer4)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold/supply/hidden/layer2)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold/supply/visible/layer2)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold4w/general/hidden)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold4w/general/visible)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold4w/scrubbers/hidden/layer4)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/manifold4w/supply/hidden/layer2)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/simple/general/hidden)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/simple/general/visible)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/simple/scrubbers/hidden/layer4)
EXPEDITION_PIPE(/obj/machinery/atmospherics/pipe/smart/simple/supply/hidden/layer2)

#undef EXPEDITION_PIPE
// AI EDIT END
