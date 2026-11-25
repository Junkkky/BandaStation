/// The dome's floor outline and shell share one sprite centered on the caster's tile.
/obj/effect/sister_dome_visual
	name = "световой купол"
	icon = 'modular_bandastation/weapon/icons/melee/sister_dome.dmi'
	icon_state = "forming"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	layer = ABOVE_MOB_LAYER
	pixel_x = -64
	base_pixel_x = -64
	pixel_y = -64
	base_pixel_y = -64
	light_system = OVERLAY_LIGHT
	light_flags = LIGHT_IGNORE_OFFSET
	light_range = 3
	light_power = 0.65
	light_color = COLOR_WHITE
	/// Wielder whose held overlay carries the opening glint.
	var/mob/living/caster
	/// Only this weapon's held appearance changes during the stance.
	var/obj/item/dualsaber/legendary_saber/saber
	/// Restore the sword's own light, including any prior customization, when the stance ends.
	var/previous_light_color

/obj/effect/sister_dome_visual/Initialize(mapload, mob/living/caster, obj/item/dualsaber/legendary_saber/saber)
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(finish_forming)), 0.4 SECONDS)
	if(!caster || !saber || saber.loc != caster)
		return
	src.caster = caster
	src.saber = saber
	previous_light_color = saber.light_color
	saber.set_light_color(COLOR_WHITE)
	RegisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS, PROC_REF(add_blade_glint))
	caster.update_held_items()

/obj/effect/sister_dome_visual/Destroy()
	if(!QDELETED(saber))
		UnregisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS)
		saber.set_light_color(previous_light_color)
	if(!QDELETED(caster))
		caster.update_held_items()
	caster = null
	saber = null
	return ..()

/// The opening wave settles into the sustained shell after four frames.
/obj/effect/sister_dome_visual/proc/finish_forming()
	icon_state = "dome"
	if(!QDELETED(caster) && saber?.loc == caster)
		UnregisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS)
		caster.update_held_items()

/// Use the glint cut for the same grip as the visible blade.
/obj/effect/sister_dome_visual/proc/add_blade_glint(obj/item/source, list/overlays, mutable_appearance/draw_target, isinhands, icon_file)
	SIGNAL_HANDLER
	if(isinhands && source.loc == caster)
		var/glint_state = icon_file == source.lefthand_file ? "glint_left" : "glint_right"
		var/glint_icon = draw_target.icon == 'modular_bandastation/weapon/icons/melee/sister_gauntlet.dmi' ? draw_target.icon : 'modular_bandastation/weapon/icons/melee/sister_blade_glint.dmi'
		overlays += mutable_appearance(glint_icon, glint_state)

/// Spawns a separate one-shot animation so shattering survives deletion of the shield.
/obj/effect/sister_dome_visual/proc/burst()
	new /obj/effect/temp_visual/sister_dome_burst(get_turf(src))

/obj/effect/temp_visual/sister_dome_burst
	icon = 'modular_bandastation/weapon/icons/melee/sister_dome.dmi'
	icon_state = "shatter"
	randomdir = FALSE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	pixel_x = -64
	base_pixel_x = -64
	pixel_y = -64
	base_pixel_y = -64
	duration = 0.6 SECONDS
