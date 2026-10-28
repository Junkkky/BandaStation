/// A Z change uses the immediate path even when entering stationary space.
/atom/movable/screen/parallax_home/update_parallax_motionblur(atom/movable/screen/parallax_layer/layer, new_parallax_movedir, matrix/new_transform)
	if(new_parallax_movedir == NONE)
		parallax_animate_timers -= layer
		animate(layer, transform = matrix(), time = 0, flags = ANIMATION_END_NOW)
		return
	return ..()
