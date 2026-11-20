/// Large pines from the Prime event asset pack, retaining the house map's typepaths.
/obj/structure/flora/tree/large_pine
	name = "large pine tree"
	desc = "A coniferous large pine tree."
	icon = 'modular_bandastation/gate_closure/icons/limneya/tall_trees.dmi'
	icon_state = "large_pine_1"

/obj/structure/flora/tree/large_pine/get_seethrough_map()
	return SEE_THROUGH_MAP_DEFAULT_TWO_TALL

/obj/structure/flora/tree/large_pine/style_2
	icon_state = "large_pine_2"

/obj/structure/flora/tree/large_pine/style_3
	icon_state = "large_pine_3"

/// Broad dead trees used around the Limneya house.
/obj/structure/flora/tree/large_tree
	name = "large dead tree"
	desc = "A large dead tree."
	icon = 'modular_bandastation/gate_closure/icons/limneya/tall_trees.dmi'
	icon_state = "large_tree_1"

/obj/structure/flora/tree/large_tree/get_seethrough_map()
	return SEE_THROUGH_MAP_DEFAULT_TWO_TALL

/obj/structure/flora/tree/large_tree/style_random/Initialize(mapload)
	. = ..()
	icon_state = "large_tree_[rand(1, 3)]"
	update_appearance()

/obj/structure/flora/tree/large_tree/snow
	icon_state = "snow_large_tree_1"

/obj/structure/flora/tree/large_tree/snow/style_random/Initialize(mapload)
	. = ..()
	icon_state = "snow_large_tree_[rand(1, 3)]"
	update_appearance()

/obj/structure/flora/tree/stump/large_tree
	icon = 'modular_bandastation/gate_closure/icons/limneya/tall_trees.dmi'
	icon_state = "large_tree_stump"

/obj/structure/flora/tree/stump/large_tree/snow
	icon_state = "snow_large_tree_stump"

/// Scattered sticks, grass and logs from the original map's event pack.
/obj/structure/flora/grass_sticks
	name = "stick"
	desc = "Watch your step."
	icon = 'modular_bandastation/gate_closure/icons/limneya/grass-sticks.dmi'
	icon_state = "stick_1"
	flora_flags = FLORA_HERBAL

/obj/structure/flora/grass_sticks/style_2
	icon_state = "stick_2"

/obj/structure/flora/grass_sticks/style_3
	icon_state = "stick_3"

/obj/structure/flora/grass_sticks/style_4
	icon_state = "stick_4"

/obj/structure/flora/grass_sticks/style_random/Initialize(mapload)
	. = ..()
	icon_state = "stick_[rand(1, 4)]"
	update_appearance()

/obj/structure/flora/dry_grass
	name = "dry grass"
	desc = "Dead, dry grass."
	icon = 'modular_bandastation/gate_closure/icons/limneya/grass-sticks.dmi'
	icon_state = "dry_grass_1"
	flora_flags = FLORA_HERBAL

/obj/structure/flora/dry_grass/style_random/Initialize(mapload)
	. = ..()
	icon_state = "dry_grass_[rand(1, 2)]"
	update_appearance()

/obj/structure/flora/tall_grass
	name = "tall grass"
	desc = "Thick clumps of grass."
	icon = 'modular_bandastation/gate_closure/icons/limneya/grass-sticks.dmi'
	icon_state = "tall_grass_1"
	flora_flags = FLORA_HERBAL

/obj/structure/flora/tall_grass/style_random/Initialize(mapload)
	. = ..()
	icon_state = "tall_grass_[rand(1, 2)]"
	update_appearance()

/obj/structure/flora/dry_log
	name = "dry log"
	desc = "A dry log. It's almost rotten."
	icon = 'modular_bandastation/gate_closure/icons/limneya/grass-sticks.dmi'
	icon_state = "dry_log"
	density = TRUE
	harvest_amount_low = 2
	harvest_amount_high = 4
	harvest_message_med = "You finish chopping the log."
	harvest_verb = "chop"
	flora_flags = FLORA_WOODEN
	can_uproot = FALSE
	delete_on_harvest = TRUE

/obj/structure/flora/dry_log/get_potential_products()
	return list(/obj/item/grown/log/tree = 1)

/// Old pipes retain the original two-tile collision footprint.
/obj/structure/old_tube
	name = "tube"
	desc = "Bunch of tubes."
	icon = 'modular_bandastation/gate_closure/icons/limneya/misc32x64.dmi'
	icon_state = "old_tube"
	anchored = TRUE
	density = TRUE
	bound_width = 64

/// Shelves are decorative structures, as in the original Prime map.
/obj/structure/shelf
	name = "shelf"
	desc = "A sturdy wooden shelf to store a variety of items on."
	icon = 'modular_bandastation/gate_closure/icons/limneya/furniture.dmi'
	icon_state = "empty_shelf_1"
	density = TRUE
	anchored = TRUE
	max_integrity = 50

/obj/structure/shelf/crates
	desc = "A sturdy wooden shelf with a bunch of crates on it."
	icon_state = "shelf_1"

/// Wooden border fencing uses the native directional railing collision.
/obj/structure/railing/wooden_fencing
	name = "wooden fence"
	desc = "A basic wooden fence meant to prevent people like you either in or out of somewhere."
	icon = 'modular_bandastation/gate_closure/icons/limneya/wooden_fence.dmi'
	icon_state = "fence"
	resistance_flags = FLAMMABLE
	/// Allows a mapper to hold a chosen style instead of randomizing it.
	var/random_icons = TRUE

/obj/structure/railing/wooden_fencing/Initialize(mapload)
	. = ..()
	if(random_icons)
		icon_state = pick("fence", "fence_2", "fence_3")
		update_appearance()

/obj/structure/railing/wooden_fencing/atom_deconstruct(disassembled)
	var/obj/plank = new /obj/item/stack/sheet/mineral/wood(drop_location(), 5)
	transfer_fingerprints_to(plank)

/obj/structure/railing/wooden_fencing/wirecutter_act(mob/living/user, obj/item/tool)
	return NONE

/obj/structure/railing/wooden_fencing/crowbar_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return
	to_chat(user, span_warning("You pry apart the railing."))
	tool.play_tool_sound(src, 100)
	deconstruct()
	return ITEM_INTERACT_SUCCESS

/// The portraits named in the house map's original object entries.
/obj/structure/sharlotta
	name = "портрет девушки"
	desc = "Молодая светловолосая девушка в белом халате. Смотрит так, как будто сейчас расплачется. Подпись снизу - Шарлотта П-Б."
	icon = 'modular_bandastation/gate_closure/icons/limneya/photo.dmi'
	icon_state = "sharlotta"
	density = FALSE
	anchored = TRUE
	max_integrity = 30

/obj/structure/sharlotta/victor
	name = "портрет мужчины"
	desc = "Молодой светловолосый мужчина в жилетке и галстуке. Смотрит так, как будто сейчас расхохочется. Подпись снизу - Виктор П-Б."
	icon_state = "victor"

/// Map-specific ground tint from the original Limneya event module.
/turf/open/indestructible/rockyground/limneya
	color = COLOR_GRAY
