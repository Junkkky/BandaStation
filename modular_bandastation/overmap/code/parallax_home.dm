/area
	/// Divides the steady parallax loop time while the area moves; one keeps the native speed.
	var/parallax_rush = 1

/// A Z change uses the immediate path even when entering stationary space; a rushing area loops faster.
/atom/movable/screen/parallax_home/update_parallax_motionblur(atom/movable/screen/parallax_layer/layer, new_parallax_movedir, matrix/new_transform)
	if(layer.absolute || new_parallax_movedir == NONE)
		parallax_animate_timers -= layer
		animate(layer, transform = matrix(), time = 0, flags = ANIMATION_END_NOW)
		return
	var/rush = perspective_area?.parallax_rush || 1
	if(rush <= 1)
		return ..()
	parallax_animate_timers -= layer
	// Half the native loop time for the same reason as the native steady loop: it continues a quadratic wind-up.
	animate(layer, transform = new_transform, time = 0, loop = -1, flags = ANIMATION_END_NOW)
	animate(transform = matrix(), time = PARALLAX_LOOP_TIME / layer.speed / 2 / rush)
