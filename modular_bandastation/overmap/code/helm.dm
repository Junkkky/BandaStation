/** Pilot throttle changes a command, never the existing velocity. */
/datum/stationtrauma_overmap/proc/command_throttle(value)
	if(!IS_FINITE(value) || value < 0 || value > 100)
		return FALSE
	command_course(ordered_course)
	braking = FALSE
	throttle = value
	return TRUE

/** Cancel automation and brake with available propulsion and drag. */
/datum/stationtrauma_overmap/proc/request_brake()
	control_revision++
	autopilot = FALSE
	autopilot_path = null
	throttle = 0
	if(speed <= ST_NAV_STOPPED_SPEED)
		stop()
		return
	braking = TRUE
	helm_engaged = TRUE
	status = "Торможение"

/** Available braking acceleration per second; propulsion adapters supply actual engine capability. */
/datum/stationtrauma_overmap/proc/get_braking_acceleration()
	return 0

/** Stopping distance at the current speed, or null without braking capability. */
/datum/stationtrauma_overmap/proc/get_braking_distance()
	return null
