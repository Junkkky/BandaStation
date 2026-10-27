/** Pilot throttle changes a command, never the existing velocity. */
/datum/stationtrauma_overmap/proc/command_throttle(value)
	if(!IS_FINITE(value) || value < 0 || value > 100)
		return FALSE
	command_course(ordered_course)
	braking = FALSE
	throttle = value
	return TRUE

/** Cancel automation immediately, then shed velocity using available machinery and environmental drag. */
/datum/stationtrauma_overmap/proc/request_brake()
	control_revision++
	autopilot = FALSE
	autopilot_path = null
	throttle = 0
	if(speed <= 0.05)
		stop()
		return
	braking = TRUE
	helm_engaged = TRUE
	status = "Торможение"

/** Available acceleration in m/s²; propulsion adapters supply actual engine capability. */
/datum/stationtrauma_overmap/proc/get_braking_acceleration()
	return max(0, get_target_speed() / max(0.1, get_response_time()))

/** Passive first-order stopping distance is a conservative bound for submerged vessels. */
/datum/stationtrauma_overmap/proc/get_braking_distance()
	return speed * get_response_time()

/** Exact radial deceleration with linear drag; no velocity reversal or motion after stopping mid-step. */
/datum/stationtrauma_overmap/proc/integrate_braking(seconds)
	var/magnitude = sqrt(velocity_x ** 2 + velocity_y ** 2)
	if(!magnitude)
		return list(0, 0)
	var/response_time = max(0.1, get_response_time())
	var/acceleration = get_braking_acceleration()
	var/duration = acceleration ? min(seconds, response_time * log(NUM_E, 1 + magnitude / (acceleration * response_time))) : seconds
	var/decay = NUM_E ** (-duration / response_time)
	var/distance = (magnitude + acceleration * response_time) * response_time * (1 - decay) - acceleration * response_time * duration
	var/remaining = max(0, (magnitude + acceleration * response_time) * decay - acceleration * response_time)
	var/dx = velocity_x * distance / magnitude
	var/dy = velocity_y * distance / magnitude
	velocity_x *= remaining / magnitude
	velocity_y *= remaining / magnitude
	return list(dx, dy)
