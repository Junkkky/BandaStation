/// Decorative, non-harvestable flowers with the event nebula's faint glow.
/obj/structure/flora/bush/gate_closure_flowers
	name = "цветы редспейса"
	desc = "Невысокий куст с тонкими малиново-пурпурными цветами. Лепестки слабо светятся."
	icon = 'modular_bandastation/gate_closure/icons/event_flowers.dmi'
	icon_state = "event_flower_1"
	base_icon_state = "event_flower"
	harvestable = FALSE
	can_uproot = FALSE
	regrowth_time_high = 0
	light_range = 1.5
	light_power = 0.35
	light_color = "#e52b87"

/obj/structure/flora/bush/gate_closure_flowers/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/flora/bush/gate_closure_flowers/update_overlays()
	. = ..()
	. += emissive_appearance(icon, "[icon_state]_e", src)

/// A spreading cluster of flowers.
/obj/structure/flora/bush/gate_closure_flowers/style_2
	icon_state = "event_flower_2"

/// An uneven cluster with a taller central bloom.
/obj/structure/flora/bush/gate_closure_flowers/style_3
	icon_state = "event_flower_3"

/// Chooses one of the three approved silhouettes when the plant is created.
/obj/structure/flora/bush/gate_closure_flowers/style_random

/obj/structure/flora/bush/gate_closure_flowers/style_random/Initialize(mapload)
	. = ..()
	icon_state = "[base_icon_state]_[rand(1, 3)]"
	update_appearance()

/// Native small flowers in the event palette, without a light source or harvest products.
/obj/structure/flora/bush/gate_closure_small_flowers
	name = "мелкие цветы редспейса"
	desc = "Среди тёмной серо-синей травы рассыпаны небольшие пурпурные цветы."
	icon = 'modular_bandastation/gate_closure/icons/small_flowers.dmi'
	icon_state = "small_flower_1"
	harvestable = FALSE
	can_uproot = FALSE
	regrowth_time_high = 0
	light_range = 0

/obj/structure/flora/bush/gate_closure_small_flowers/style_2
	icon_state = "small_flower_2"

/obj/structure/flora/bush/gate_closure_small_flowers/style_3
	icon_state = "small_flower_3"

/// Two petals remain visible in darkness, without lighting the surrounding tiles.
/obj/structure/flora/bush/gate_closure_small_flowers/emissive
	desc = "Среди тёмной серо-синей травы рассыпаны небольшие пурпурные цветы. Пара лепестков мерцает в темноте."

/obj/structure/flora/bush/gate_closure_small_flowers/emissive/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/flora/bush/gate_closure_small_flowers/emissive/update_overlays()
	. = ..()
	. += emissive_appearance(icon, "[icon_state]_e", src)

/obj/structure/flora/bush/gate_closure_small_flowers/emissive/style_2
	icon_state = "small_flower_2"

/// Chooses equally between the three plain and two emissive variants.
/obj/structure/flora/bush/gate_closure_small_flowers/style_random
	/// Whether the randomly chosen variant has emissive petals.
	var/emissive_petals = FALSE

/obj/structure/flora/bush/gate_closure_small_flowers/style_random/Initialize(mapload)
	. = ..()
	var/style = rand(1, 5)
	emissive_petals = style > 3
	icon_state = "small_flower_[emissive_petals ? style - 3 : style]"
	update_appearance()

/obj/structure/flora/bush/gate_closure_small_flowers/style_random/update_overlays()
	. = ..()
	if(emissive_petals)
		. += emissive_appearance(icon, "[icon_state]_e", src)

#ifdef __DEMIR_BAKE__
// RMD skips gameplay Initialize(), so build the same emissive overlays for the map preview.
/obj/structure/flora/bush/gate_closure_flowers/demir_bake_appearance()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/flora/bush/gate_closure_small_flowers/emissive/demir_bake_appearance()
	update_appearance(UPDATE_OVERLAYS)
#endif
