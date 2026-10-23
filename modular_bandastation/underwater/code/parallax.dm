/// Map configuration set by a landmark, independent of the level's current turfs.
GLOBAL_LIST_EMPTY(ocean_parallax_levels)

/// Ocean backgrounds need the space geometry, but not its screen relay that bypasses lighting.
/atom/movable/screen/plane_master/parallax_white/Initialize(mapload, datum/hud/hud_owner, datum/plane_master_group/home, offset)
	. = ..()
	add_relay_to(GET_NEW_PLANE(RENDER_PLANE_EMISSIVE, offset), relay_layer = EMISSIVE_SPACE_LAYER)
	AddComponent(/datum/component/connect_perspective, home, list(COMSIG_MOVABLE_Z_CHANGED = PROC_REF(update_ocean_fullbright)))
	RegisterSignal(home, COMSIG_PLANE_GROUP_PERSPECTIVE_CHANGED, PROC_REF(update_ocean_fullbright))
	update_ocean_fullbright()

/atom/movable/screen/plane_master/parallax_white/proc/update_ocean_fullbright(datum/source)
	SIGNAL_HANDLER
	var/turf/viewing_from = get_turf(home.get_perspective())
	var/ocean_level = FALSE
	if(viewing_from)
		for(var/level in SSmapping.get_connected_levels(viewing_from))
			if(GET_Z_PLANE_OFFSET(level) == offset)
				ocean_level = !!GLOB.ocean_parallax_levels["[level]"]
				break
	var/atom/movable/render_plane_relay/emissive_relay = get_relay_to(GET_NEW_PLANE(RENDER_PLANE_EMISSIVE, offset))
	emissive_relay.color = ocean_level ? GLOB.em_block_color : null
	// Blur only the native copy of the deck below, preserving actors and HUD on the current deck.
	var/atom/movable/screen/plane_master/rendering_plate/transparent/below = home.get_plane(GET_NEW_PLANE(RENDER_PLANE_TRANSPARENT, offset))
	if(below)
		// Observers expose both decks at once; keep native depth shading without an extra full-screen blur pass.
		if(ocean_level && !isobserver(home.get_perspective()))
			below.add_filter("ocean_depth_haze", 1, gauss_blur_filter(size = 0.7))
		else
			below.remove_filter("ocean_depth_haze")

/obj/effect/landmark/ocean_parallax
	name = "ocean parallax (entire z-level)"
	desc = "Назначает океанский параллакс уровню карты при загрузке."

/obj/effect/landmark/ocean_parallax/Initialize(mapload)
	. = ..()
	GLOB.ocean_parallax_levels["[z]"] = TRUE
	// The marker is only map configuration; the theme remains for the round after it disappears.
	return INITIALIZE_HINT_QDEL

/atom/movable/screen/parallax_home
	var/ocean_parallax = FALSE

/// Preserve the native area listener, selecting the environment from the actual perspective z.
/atom/movable/screen/parallax_home/set_perspective_area(area/new_area)
	var/turf/viewing_from = get_turf(perspective)
	var/is_ocean = !!GLOB.ocean_parallax_levels["[viewing_from?.z]"]
	var/theme_changed = ocean_parallax != is_ocean
	if(theme_changed)
		ocean_parallax = is_ocean
		blend_mode = is_ocean ? BLEND_OVERLAY : initial(blend_mode)
		// Large screen backgrounds must not create HUD borders and rescale the viewport.
		appearance_flags = is_ocean ? (initial(appearance_flags) | TILE_BOUND) : initial(appearance_flags)
		regenerate_layers()
	if(perspective_area == new_area && !theme_changed)
		return
	if(perspective_area)
		UnregisterSignal(perspective_area, COMSIG_AREA_PARALLAX_DIR_CHANGED)
	perspective_area = new_area
	RegisterSignal(perspective_area, COMSIG_AREA_PARALLAX_DIR_CHANGED, is_ocean ? PROC_REF(ocean_area_motion_changed) : PROC_REF(area_parallax_dir_changed))
	if(is_ocean)
		addtimer(CALLBACK(src, PROC_REF(refresh_ocean_motion)), 0, TIMER_UNIQUE)

/** Let native perspective updates finish, then use each ocean texture's actual repeat distance. */
/atom/movable/screen/parallax_home/proc/ocean_area_motion_changed()
	SIGNAL_HANDLER
	update_parallax()
	refresh_ocean_motion()

/atom/movable/screen/parallax_home/proc/refresh_ocean_motion()
	if(!ocean_parallax || !perspective_area)
		return
	for(var/key in parallax_animate_timers)
		deltimer(parallax_animate_timers[key])
	parallax_animate_timers?.Cut()
	for(var/atom/movable/screen/parallax_layer/ocean/layer in parallax_layers)
		layer.set_ocean_motion(perspective_area.parallax_movedir)

/// Keep native preference/layer lifetime handling, replacing only the underwater layer palette.
/atom/movable/screen/parallax_home/regenerate_layers()
	clear_layers()
	if(layers_to_draw == 0 && !draw_old_space)
		return
	parallax_layers_cached = list()
	if(ocean_parallax)
		var/static/list/ocean_layers = list(
			/atom/movable/screen/parallax_layer/ocean/seafloor,
			/atom/movable/screen/parallax_layer/ocean/seafloor/crests,
			/atom/movable/screen/parallax_layer/ocean/haze,
			/atom/movable/screen/parallax_layer/ocean/fine_silt,
			/atom/movable/screen/parallax_layer/ocean/silt,
		)
		// Both terrain layers form one backdrop; preferences still control the atmosphere layers.
		for(var/index in 1 to min(max(1, layers_to_draw) + 1, length(ocean_layers)))
			var/layer_type = ocean_layers[index]
			parallax_layers_cached += new layer_type(null, null, src)
	else
		for(var/space_layer in 1 to layers_to_draw)
			var/atom/movable/screen/parallax_layer/parallax = generate_space_layer(space_layer)
			if(parallax)
				parallax_layers_cached += parallax
		if(draw_old_space)
			parallax_layers_cached += new /atom/movable/screen/parallax_layer/old(null, null, src)
	display_layers()
	if(ocean_parallax)
		addtimer(CALLBACK(src, PROC_REF(refresh_ocean_motion)), 0, TIMER_UNIQUE)

/atom/movable/screen/parallax_layer/ocean
	blend_mode = BLEND_OVERLAY
	icon_state = ""
	appearance_flags = APPEARANCE_UI | KEEP_TOGETHER | TILE_BOUND
	/// Native sediment tiles repeat at 480 pixels; mirrored terrain repeats every two tiles.
	var/draw_period = 480
	/// Last animation's repeat distance, direction, origin and server start time.
	var/motion_period = 480
	var/motion_direction = NONE
	var/motion_x = 0
	var/motion_y = 0
	var/motion_started = 0

/** Sample our linear loop before stopping or changing direction, without snapping back to its origin. */
/atom/movable/screen/parallax_layer/ocean/proc/motion_position()
	var/distance = (world.time - motion_started) * 480 * speed * 2 / PARALLAX_LOOP_TIME
	var/dx = motion_direction & EAST ? -1 : motion_direction & WEST ? 1 : 0
	var/dy = motion_direction & NORTH ? -1 : motion_direction & SOUTH ? 1 : 0
	return list(
		WRAP(motion_x + dx * distance, 0, draw_period),
		WRAP(motion_y + dy * distance, 0, draw_period),
	)

/** Client-side looping only; no recurring server processing or image regeneration during a voyage. */
/atom/movable/screen/parallax_layer/ocean/proc/set_ocean_motion(direction)
	if(motion_direction == direction && motion_period == draw_period)
		return
	var/list/position = motion_position()
	motion_x = position[1]
	motion_y = position[2]
	// Equivalent periodic positions keep the whole loop inside the repeated texture's margins.
	if(direction & WEST)
		motion_x -= draw_period
	if(direction & SOUTH)
		motion_y -= draw_period
	motion_direction = direction
	motion_period = draw_period
	motion_started = world.time
	var/matrix/start = matrix(1, 0, motion_x, 0, 1, motion_y)
	if(direction == NONE)
		animate(src, transform = start, time = 0, flags = ANIMATION_END_NOW)
		return
	var/dx = direction & EAST ? -draw_period : direction & WEST ? draw_period : 0
	var/dy = direction & NORTH ? -draw_period : direction & SOUTH ? draw_period : 0
	animate(src, transform = start, time = 0, loop = -1, flags = ANIMATION_END_NOW)
	animate(transform = matrix(1, 0, motion_x + dx, 0, 1, motion_y + dy), time = draw_period * PARALLAX_LOOP_TIME / (480 * speed * 2))

/// Mirrored copies share their edge pixels, so long voyages never expose an image border.
/atom/movable/screen/parallax_layer/ocean/seafloor
	icon = 'modular_bandastation/underwater/icons/seafloor.png'
	layer = 1
	speed = 0.25
	absolute = TRUE
	// Distant terrain receives much less light than the nearby water and suspended sediment.
	color = "#35444C"
	/// Keep this client's seabed aligned across distant ocean passages, including view changes.
	var/passage_offset_x = 0
	var/passage_offset_y = 0

/atom/movable/screen/parallax_layer/ocean/seafloor/update_overlays()
	SHOULD_CALL_PARENT(FALSE)
	var/list/copies = list()
	var/icon/background = icon(icon)
	var/size = background.Width()
	for(var/column in -2 to 2)
		for(var/row in -2 to 2)
			if(!column && !row)
				continue
			var/mutable_appearance/copy = mutable_appearance(icon, icon_state)
			copy.pixel_w = column * size
			copy.pixel_z = row * size
			copy.transform = matrix(column % 2 ? -1 : 1, 0, 0, 0, row % 2 ? -1 : 1, 0)
			copies += copy
	return copies

/atom/movable/screen/parallax_layer/ocean/seafloor/update_o(new_view)
	if(working_view == new_view)
		return
	working_view = new_view
	var/list/view_size = getviewsize(new_view)
	var/icon/background = icon(initial(icon))
	var/size = CEILING(max(background.Width(), max(view_size[1], view_size[2]) * ICON_SIZE_ALL + max(world.maxx, world.maxy) * speed * 2 + ICON_SIZE_ALL * 2), 1)
	if(size != background.Width())
		background.Scale(size, size)
	icon = background
	draw_period = size * 2
	update_appearance(UPDATE_OVERLAYS)
	// The native home is centred around a 480px cell; centre our larger image on that cell.
	var/centre = round((480 - size) / 2)
	pixel_x = centre + round(passage_offset_x, 1)
	pixel_y = centre + round(passage_offset_y, 1)
	if(home)
		addtimer(CALLBACK(home, TYPE_PROC_REF(/atom/movable/screen/parallax_home, refresh_ocean_motion)), 0, TIMER_UNIQUE)

/** Native absolute layers follow map coordinates; a distant ocean passage must preserve their screen position. */
/atom/movable/screen/parallax_layer/ocean/seafloor/proc/preserve_ocean_position(position_x, position_y)
	var/new_offset_x = position_x - offset_x
	var/new_offset_y = position_y - offset_y
	// Keep the unrounded origin so repeated crossings cannot accumulate pixel rounding errors.
	pixel_x += round(new_offset_x, 1) - round(passage_offset_x, 1)
	pixel_y += round(new_offset_y, 1) - round(passage_offset_y, 1)
	passage_offset_x = new_offset_x
	passage_offset_y = new_offset_y

/// Raised stone shares the seabed's registration, but receives more of the available light.
/atom/movable/screen/parallax_layer/ocean/seafloor/crests
	icon = 'modular_bandastation/underwater/icons/seafloor_crests.png'
	layer = 2
	color = "#A8CDD6"

/atom/movable/screen/parallax_layer/ocean/haze
	icon = 'modular_bandastation/underwater/icons/haze.png'
	layer = 3
	speed = 0.55
	alpha = 45

/atom/movable/screen/parallax_layer/ocean/haze/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/home, template = FALSE)
	. = ..()
	if(template)
		return
	animate(src, pixel_x = 12, pixel_y = 6, time = 30 SECONDS, loop = -1, easing = SINE_EASING)
	animate(pixel_x = 0, pixel_y = 0, time = 30 SECONDS, easing = SINE_EASING)

/atom/movable/screen/parallax_layer/ocean/fine_silt
	icon = 'modular_bandastation/underwater/icons/fine_silt.png'
	layer = 4
	speed = 0.9
	alpha = 55

/atom/movable/screen/parallax_layer/ocean/silt
	icon = 'modular_bandastation/underwater/icons/silt.png'
	layer = 5
	speed = 1.35
	alpha = 95

/atom/movable/screen/parallax_layer/ocean/silt/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/home, template = FALSE)
	. = ..()
	if(template)
		return
	animate(src, pixel_x = 5, pixel_y = -10, time = 18 SECONDS, loop = -1, easing = SINE_EASING)
	animate(pixel_x = 0, pixel_y = 0, time = 18 SECONDS, easing = SINE_EASING)
