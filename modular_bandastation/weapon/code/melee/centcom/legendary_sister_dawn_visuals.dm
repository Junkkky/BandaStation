/// The Dawn status owns this light. Its rays follow the bearer behind their worn equipment.
/obj/effect/dummy/lighting_obj/moblight/sister_dawn
	name = "сияние Рассвета"
	icon = 'modular_bandastation/weapon/icons/melee/sister_dawn.dmi'
	icon_state = "aura"
	layer = BELOW_MOB_LAYER
	vis_flags = VIS_INHERIT_PLANE
	// Keep the rays outside the filter that traces the bearer and their equipment.
	appearance_flags = parent_type::appearance_flags | KEEP_APART
	pixel_x = -16
	pixel_y = -16
	light_flags = LIGHT_IGNORE_OFFSET
	light_range = 4
	light_power = 1
	light_color = COLOR_WHITE
	/// The filter belongs to the original bearer even if the light changes location.
	var/mob/bearer
	/// Each aura removes only its own outline when its status ends.
	var/outline_filter_name

/obj/effect/dummy/lighting_obj/moblight/sister_dawn/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	bearer = loc
	outline_filter_name = "sister_dawn_outline_[REF(src)]"
	bearer.add_filter(outline_filter_name, 2, outline_filter(size = 1, color = "#ffffffad"))
	bearer.vis_contents += src
	flick("opening", src)

/obj/effect/dummy/lighting_obj/moblight/sister_dawn/Destroy()
	if(!QDELETED(bearer))
		bearer.remove_filter(outline_filter_name)
	bearer = null
	return ..()
