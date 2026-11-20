#define SMOOTH_GROUP_GATE_CLOSURE_FLESH S_TURF(5001)
#define SMOOTH_GROUP_GATE_CLOSURE_ROCK S_TURF(5002)
#define SMOOTH_GROUP_GATE_CLOSURE_BONE S_TURF(5003)

/// Shallow water with native lava artwork for the harmless event river.
/turf/open/water/gate_closure_lava
	parent_type = /turf/open/water/lavaland_atmos/basalt
	name = "лава"
	desc = "Багровый поток выглядит раскалённым, но на ощупь прохладный."
	icon = /turf/open/lava/smooth::icon
	icon_state = /turf/open/lava/smooth::icon_state
	base_icon_state = /turf/open/lava/smooth::base_icon_state
	baseturfs = /turf/open/water/gate_closure_lava
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = FALSE
	smoothing_groups = /turf/open/lava/smooth::smoothing_groups
	canSmoothWith = /turf/open/lava/smooth::canSmoothWith
	immerse_overlay_alpha = 215
	fishing_datum = null

/// The Wedding pond keeps its shallow-water behavior but contains blood.
/turf/open/water/alternative/muddy/gate_closure_blood
	name = "кровь"
	desc = "Тёмная кровь медленно колышется у берега."
	color = "#b52a36"
	baseturfs = /turf/open/water/alternative/muddy/gate_closure_blood
	reagent_to_extract = /datum/reagent/blood
	fishing_datum = null

/// Inert, breathable crust used by the pre-baked Redspace landscape.
/turf/open/misc/gate_closure
	name = "багровая корка"
	desc = "Тёмная поверхность покрыта спёкшимися багровыми наплывами."
	icon = 'modular_bandastation/gate_closure/icons/crust.dmi'
	icon_state = "crust"
	base_icon_state = "crust"
	baseturfs = /turf/open/misc/gate_closure
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	footstep = FOOTSTEP_CONCRETE
	smoothing_flags = NONE
	underfloor_accessibility = UNDERFLOOR_HIDDEN

/// Tissue borders blend into crust without importing the donor antagonist's effects.
/turf/open/misc/gate_closure/flesh
	name = "живая поверхность"
	desc = "Переплетённые волокна туго обтягивают камень."
	icon = 'modular_bandastation/gate_closure/icons/flesh.dmi'
	icon_state = "flesh_tile-0"
	base_icon_state = "flesh_tile"
	footstep = FOOTSTEP_MEAT
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_GATE_CLOSURE_FLESH
	canSmoothWith = SMOOTH_GROUP_GATE_CLOSURE_FLESH

/turf/open/misc/gate_closure/flesh/Initialize(mapload)
	. = ..()
	underlays += mutable_appearance('modular_bandastation/gate_closure/icons/crust.dmi', "crust", layer = LOWER_FLOOR_LAYER, offset_spokesman = src)

/// Sculpted rock masses; their apparent heat does not create hundreds of light sources or fires.
/turf/closed/indestructible/gate_closure_growth
	name = "раскалённая порода"
	desc = "Складчатую породу прорезают багровые прожилки."
	icon = 'modular_bandastation/gate_closure/icons/heated_rock.dmi'
	icon_state = "heated_rock-0"
	base_icon_state = "heated_rock"
	color = "#da563d"
	baseturfs = /turf/open/misc/gate_closure
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_GATE_CLOSURE_ROCK
	canSmoothWith = SMOOTH_GROUP_GATE_CLOSURE_ROCK

/turf/closed/indestructible/gate_closure_growth/Initialize(mapload)
	. = ..()
	underlays += mutable_appearance('modular_bandastation/gate_closure/icons/crust.dmi', "crust", layer = layer - 0.01, offset_spokesman = src, appearance_flags = RESET_COLOR|KEEP_APART)

/// Skeletal ridges join into organic cavities rather than station-style rooms.
/turf/closed/indestructible/gate_closure_growth/bone
	name = "костяной нарост"
	desc = "Изогнутые рёбра срослись в плотную стену."
	icon = 'modular_bandastation/gate_closure/icons/bone.dmi'
	icon_state = "bone-0"
	base_icon_state = "bone"
	color = null
	smoothing_groups = SMOOTH_GROUP_GATE_CLOSURE_BONE
	canSmoothWith = SMOOTH_GROUP_GATE_CLOSURE_BONE

/// A static two-by-two obstruction placed away from the guaranteed walking route.
/obj/structure/gate_closure_boulder
	name = "крупный валун"
	desc = "Тяжёлый обломок растрескавшейся скалы."
	icon = 'modular_bandastation/gate_closure/icons/boulders.dmi'
	icon_state = "boulder_largedark1"
	density = TRUE
	anchored = TRUE
	bound_width = 64
	bound_height = 64
	max_integrity = 300

#undef SMOOTH_GROUP_GATE_CLOSURE_FLESH
#undef SMOOTH_GROUP_GATE_CLOSURE_ROCK
#undef SMOOTH_GROUP_GATE_CLOSURE_BONE
