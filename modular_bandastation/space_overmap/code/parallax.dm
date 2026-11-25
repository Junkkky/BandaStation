#define ST_BLUESPACE_TEXTURE_SIZE 960

/area
	/// Null retains the native background; expedition areas choose a native layer explicitly.
	var/space_parallax_background
	/// Optional fixed orbital planet layer, independent of the moving space background.
	var/space_parallax_planet
	/// Bluespace visual phase shared by all eyes in the area.
	var/space_bluespace_stage = NONE
	/// Direction of travel, retained as the tunnel fades out.
	var/space_bluespace_heading = NORTH
	/// Starting opacity and timing of the current transition.
	var/space_bluespace_from = 0
	var/space_bluespace_at = 0
	var/space_bluespace_duration = 0
	/// Opacity once the current transition finishes.
	var/space_bluespace_target = 0

/area/shuttle/stationtrauma_space
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/// Navigation owns a hull's motion: native docking would take the berth's still background mid-manoeuvre.
/area/shuttle/stationtrauma_space/onShuttleMove(turf/oldT, turf/newT, obj/docking_port/mobile/shuttle, area/fallback_area)
	var/motion = parallax_movedir
	. = ..()
	set_parallax_movedir(motion)

/// These hulls never use native transit, so the native "docked means still" rule does not apply.
/area/shuttle/stationtrauma_space/afterShuttleMove(new_parallax_dir)
	return ..(parallax_movedir)

/area/space/stationtrauma_space_home
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/stationtrauma_space_site
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/stationtrauma_space_site/asteroid
	space_parallax_background = /atom/movable/screen/parallax_layer/random/asteroids

/datum/space_level
	/// Explicit native background layer type; null retains native selection.
	var/space_parallax_background

/** Select an explicit native layer and notify subscribed viewers on change. */
/area/proc/set_space_parallax_background(background, planet, bluespace_stage = NONE, bluespace_heading = NORTH)
	SHOULD_CALL_PARENT(TRUE)
	if(!bluespace_stage)
		bluespace_heading = space_bluespace_heading
	if(space_parallax_background == background && space_parallax_planet == planet && space_bluespace_stage == bluespace_stage \
		&& space_bluespace_heading == bluespace_heading)
		return
	space_parallax_background = background
	space_parallax_planet = planet
	space_bluespace_heading = bluespace_heading
	if(space_bluespace_stage != bluespace_stage)
		space_bluespace_from = space_bluespace_opacity()
		space_bluespace_stage = bluespace_stage
		space_bluespace_at = world.time
		switch(bluespace_stage)
			if(HYPERSPACE_WARMUP)
				space_bluespace_target = ST_SPACE_JUMP_WARMUP_ALPHA
				space_bluespace_duration = ST_SPACE_JUMP_WARMUP
			if(HYPERSPACE_LAUNCH)
				space_bluespace_target = 255
				space_bluespace_duration = ST_SPACE_JUMP_REVEAL
			else
				space_bluespace_target = 0
				space_bluespace_duration = ST_SPACE_JUMP_FADE
	SEND_SIGNAL(src, COMSIG_AREA_SPACE_PARALLAX_CHANGED)

/// Evaluate the same fade for late viewers and jumps cancelled mid-transition.
/area/proc/space_bluespace_opacity()
	if(!space_bluespace_duration)
		return space_bluespace_target
	var/progress = clamp((world.time - space_bluespace_at) / space_bluespace_duration, 0, 1)
	var/weight = (1 - cos(progress * 180)) / 2
	return round(space_bluespace_from + (space_bluespace_target - space_bluespace_from) * weight)

/** Explicit area profiles take precedence over the ship level's station trait. */
/proc/stationtrauma_space_parallax(atom/viewpoint)
	var/turf/tile = get_turf(viewpoint)
	if(!tile)
		return null
	var/area/location = get_area(tile)
	if(location.space_parallax_background)
		// A hull arriving on its flight level still carries the station profile until native docking returns.
		if(location.space_parallax_background == /atom/movable/screen/parallax_layer/planet && !is_station_level(tile.z))
			return /atom/movable/screen/parallax_layer/layer_3
		return location.space_parallax_background
	var/datum/space_level/level = SSmapping.get_level(tile.z)
	if(level?.space_parallax_background)
		return level.space_parallax_background
	if(!SSmapping.current_map?.space_overmap && !length(SSstationtrauma_space_voyage.sectors))
		return null
	return is_station_level(tile.z) ? /atom/movable/screen/parallax_layer/planet : /atom/movable/screen/parallax_layer/layer_3

/atom/movable/screen/parallax_home
	/// Last selected parallax profile, used to avoid unnecessary layer rebuilds.
	var/space_background
	/// Last orbital layer type, so a biome change refreshes the planet without changing the star field.
	var/space_planet
	/// Jump layers scroll independently from the regular space background.
	var/list/atom/movable/screen/parallax_layer/bluespace_tunnel/bluespace_layers
	/// Last fade applied to the jump layers.
	var/area/bluespace_animation_area
	var/bluespace_animation_at
	var/bluespace_animation_stage
	/// Last applied parallax preference.
	var/bluespace_animated

/atom/movable/screen/parallax_home/set_perspective_area(area/new_area)
	if(perspective_area == new_area)
		return ..()
	if(perspective_area)
		UnregisterSignal(perspective_area, COMSIG_AREA_SPACE_PARALLAX_CHANGED)
	. = ..()
	RegisterSignal(new_area, COMSIG_AREA_SPACE_PARALLAX_CHANGED, PROC_REF(space_background_changed))

/** Refresh the viewer after its current area changes the native background profile. */
/atom/movable/screen/parallax_home/proc/space_background_changed(datum/source)
	SIGNAL_HANDLER
	update_parallax()

/atom/movable/screen/parallax_home/update_parallax()
	var/background = stationtrauma_space_parallax(perspective)
	var/area/location = get_area(perspective)
	var/planet = location?.space_parallax_planet
	if(background != space_background)
		space_background = background
		space_planet = planet
		// Cancel old layer timers before replacement, then let the native update restore motion.
		set_parallax_movedir(NONE, TRUE)
		regenerate_layers()
	else if(planet != space_planet)
		space_planet = planet
		// Slot three is the native planet; replace only it, preserving every moving star/gas layer.
		if(layers_to_draw >= 3 && length(parallax_layers_cached) >= 3)
			var/atom/movable/screen/parallax_layer/old_planet = parallax_layers_cached[3]
			var/timer = LAZYACCESS(parallax_animate_timers, old_planet)
			if(timer)
				deltimer(timer)
				parallax_animate_timers -= old_planet
			var/atom/movable/screen/parallax_layer/new_planet = generate_space_layer(3)
			parallax_layers_cached[3] = new_planet
			if(displaying_layers)
				vis_contents -= old_planet
				vis_contents |= new_planet
			qdel(old_planet)
	. = ..()
	update_bluespace_tunnel(location)

/// Blend in the jump layers while their client-side motion continues independently.
/atom/movable/screen/parallax_home/proc/update_bluespace_tunnel(area/location)
	var/remaining = location ? max(0, location.space_bluespace_at + location.space_bluespace_duration - world.time) : 0
	var/target = location?.space_bluespace_target || 0
	if(!displaying_layers || (!target && (!remaining || !location?.space_bluespace_from)))
		if(length(bluespace_layers))
			vis_contents -= bluespace_layers
			QDEL_LIST(bluespace_layers)
		bluespace_animation_area = null
		return
	if(!length(bluespace_layers))
		var/static/list/layer_types = list(
			/atom/movable/screen/parallax_layer/bluespace_tunnel,
			/atom/movable/screen/parallax_layer/bluespace_tunnel/mist,
			/atom/movable/screen/parallax_layer/bluespace_tunnel/stars,
			/atom/movable/screen/parallax_layer/bluespace_tunnel/streaks,
		)
		bluespace_layers = list()
		for(var/layer_type in layer_types)
			bluespace_layers += new layer_type(null, null, src, location.space_bluespace_heading, FALSE)
			bluespace_layers += new layer_type(null, null, src, location.space_bluespace_heading, TRUE)
		bluespace_animated = animate_parallax
	var/atom/movable/screen/parallax_layer/bluespace_tunnel/nebula = bluespace_layers[1]
	if(!(nebula in vis_contents))
		vis_contents |= bluespace_layers
	if(nebula.dir != location.space_bluespace_heading || bluespace_animated != animate_parallax)
		for(var/atom/movable/screen/parallax_layer/bluespace_tunnel/jump_layer as anything in bluespace_layers)
			jump_layer.setDir(location.space_bluespace_heading)
			jump_layer.update_o(owner?.view || world.view)
		bluespace_animated = animate_parallax
	if(bluespace_animation_area == location && bluespace_animation_at == location.space_bluespace_at \
		&& bluespace_animation_stage == location.space_bluespace_stage)
		return
	bluespace_animation_area = location
	bluespace_animation_at = location.space_bluespace_at
	bluespace_animation_stage = location.space_bluespace_stage
	var/start_opacity = location.space_bluespace_opacity()
	for(var/atom/movable/screen/parallax_layer/bluespace_tunnel/jump_layer as anything in bluespace_layers)
		animate(jump_layer, alpha = start_opacity, time = 0, flags = ANIMATION_END_NOW, tag = "bluespace_fade")
		animate(alpha = target, time = remaining, easing = SINE_EASING | EASE_IN | EASE_OUT)
	if(!target)
		addtimer(CALLBACK(src, PROC_REF(update_parallax)), remaining + world.tick_lag, TIMER_UNIQUE | TIMER_OVERRIDE)

/atom/movable/screen/parallax_layer/bluespace_tunnel
	icon = 'modular_bandastation/space_overmap/icons/bluespace_tunnel.dmi'
	icon_state = "nebula"
	appearance_flags = APPEARANCE_UI
	blend_mode = BLEND_OVERLAY
	alpha = 0
	layer = 40
	absolute = TRUE
	dir = NORTH
	/// Time for one seamless pass of the texture.
	var/scroll_period = 16 SECONDS
	/// The second tile fills the area behind the first as it scrolls.
	var/trailing_tile = FALSE

/atom/movable/screen/parallax_layer/bluespace_tunnel/mist
	icon_state = "mist"
	layer = 41
	scroll_period = 8 SECONDS

/atom/movable/screen/parallax_layer/bluespace_tunnel/stars
	icon_state = "stars"
	layer = 42
	scroll_period = 6 SECONDS

/atom/movable/screen/parallax_layer/bluespace_tunnel/streaks
	icon_state = "streaks"
	layer = 43
	scroll_period = 1 SECONDS

/atom/movable/screen/parallax_layer/bluespace_tunnel/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/home, heading, trailing)
	dir = heading
	trailing_tile = trailing
	return ..(mapload, hud_owner, home)

/atom/movable/screen/parallax_layer/bluespace_tunnel/update_o(new_view)
	var/list/view_size = getviewsize(new_view)
	var/rotation = dir2angle(dir)
	var/heading_x = sin(rotation)
	var/heading_y = cos(rotation)
	var/projected_view = max(view_size[1], view_size[2]) * (abs(heading_x) + abs(heading_y))
	var/side = max(ST_BLUESPACE_TEXTURE_SIZE, projected_view * ICON_SIZE_ALL)
	// The parallax home is positioned for the native 15-tile texture.
	var/center_offset = (ICON_SIZE_ALL * 15 - ST_BLUESPACE_TEXTURE_SIZE) / 2
	var/matrix/fitted = matrix()
	fitted.Scale(side / ST_BLUESPACE_TEXTURE_SIZE)
	fitted.Turn(rotation)
	fitted.Translate(center_offset, center_offset)
	animate(src, tag = "bluespace_scroll")
	if(!home.animate_parallax)
		if(trailing_tile)
			fitted.Translate(-side * heading_x, -side * heading_y)
		transform = fitted
		return
	var/matrix/shifted = matrix(fitted)
	if(trailing_tile)
		fitted.Translate(-side * heading_x, -side * heading_y)
	else
		shifted.Translate(side * heading_x, side * heading_y)
	transform = fitted
	// As in shuttle transit, resetting by one tile introduces no visible seam.
	animate(src, transform = shifted, time = 0, loop = -1, flags = ANIMATION_END_NOW, tag = "bluespace_scroll")
	animate(transform = fitted, time = scroll_period)

#undef ST_BLUESPACE_TEXTURE_SIZE

/** Preserve native quality settings without inheriting the round-wide random asteroid/gas layer. */
/atom/movable/screen/parallax_home/generate_space_layer(index)
	var/area/location = get_area(perspective)
	var/planet = location?.space_parallax_planet
	if(index == 3 && planet)
		return new planet(null, null, src)
	var/background = stationtrauma_space_parallax(perspective)
	if(background)
		if(index == 4)
			var/layer_type = background == /atom/movable/screen/parallax_layer/planet ? /atom/movable/screen/parallax_layer/layer_3 : background
			return new layer_type(null, null, src)
		if(index == 5)
			return background == /atom/movable/screen/parallax_layer/random/asteroids ? new /atom/movable/screen/parallax_layer/layer_3(null, null, src) : null
	return ..()

/atom/movable/screen/parallax_layer/planet/on_z_change(atom/source)
	// SIGNAL_HANDLER is inherited from the original definition; redeclaring it breaks DreamChecker.
	. = ..()
	var/background = stationtrauma_space_parallax(home?.perspective)
	if(background)
		SetInvisibility(background == /atom/movable/screen/parallax_layer/planet ? INVISIBILITY_NONE : INVISIBILITY_ABSTRACT, id = type)

/datum/stationtrauma_overmap/space
	/// Last selected parallax profile, used to avoid unnecessary layer rebuilds.
	var/space_background
	/// Last orbital planet layer type published to the hull and its flight level.
	var/space_planet
	/// Last jump effect sent to viewers.
	var/published_bluespace_stage = NONE
	var/published_bluespace_heading = NONE

/**
 * A single world drawn over the native space layers without tiling.
 *
 * Like the native station planet it shifts with the viewer's own movement, but it takes no part in the hull's motion loop.
 */
/atom/movable/screen/parallax_layer/expedition_planet
	icon = 'modular_bandastation/space_overmap/icons/planets.dmi'
	icon_state = "barren"
	blend_mode = BLEND_OVERLAY
	absolute = TRUE
	speed = 3
	layer = 30

/atom/movable/screen/parallax_layer/expedition_planet/update_o(new_view)
	return

/atom/movable/screen/parallax_layer/expedition_planet/frozen
	icon_state = "frozen"

/atom/movable/screen/parallax_layer/expedition_planet/arid
	icon_state = "arid"

/atom/movable/screen/parallax_layer/expedition_planet/lush
	icon_state = "lush"

/atom/movable/screen/parallax_layer/expedition_planet/lava
	icon_state = "lava"

/// The barren world darkened to ash by its war.
/atom/movable/screen/parallax_layer/expedition_planet/dead
	icon_state = "barren"
	color = "#8a7c6c"

/// The station's own native planet, seen from a flight level near the station.
/atom/movable/screen/parallax_layer/expedition_planet/station
	icon = 'icons/effects/parallax.dmi'
	icon_state = "planet"

/** Show the nearest charted world in the existing approach band, including descent/ascent but not the surface. */
/datum/stationtrauma_overmap/space/proc/parallax_planet()
	var/datum/stationtrauma_overmap_site/space/site = parallax_site()
	var/datum/stationtrauma_overmap_site/space/planet/planet = site
	if(istype(planet))
		return planet.parallax_layer
	return site ? /atom/movable/screen/parallax_layer/expedition_planet/station : null

/datum/stationtrauma_overmap/space/proc/parallax_site()
	if(!vessel || jump_phase >= HYPERSPACE_LAUNCH)
		return null
	var/datum/stationtrauma_overmap_site/space/planet/approaching = approach_site?.pad_parent || approach_site
	if(istype(approaching) && !approaching.failed)
		if(approach_departing || vessel.z != approaching.berth?.z)
			return approaching
		return null
	if(docked && vessel.z == docked.berth?.z && (docked.landing || docked.physical_docking))
		return null
	var/closest_distance = INFINITY
	var/datum/stationtrauma_overmap_site/space/closest_site
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/space/site = sites[id]
		var/datum/stationtrauma_overmap_site/space/planet/planet = site
		// The station's planet stays in view from the flight level while the hull is near it.
		// Trade outposts dock physically too, but only the station itself orbits its planet.
		var/layer = istype(planet) ? planet.parallax_layer : site.physical_docking && site.berth && is_station_level(site.berth.z) ? /atom/movable/screen/parallax_layer/expedition_planet/station : null
		if(!layer || site.failed || !knows_site(site))
			continue
		// A just-relocated hull can reach the surface before dock() publishes its destination.
		if(site.berth && vessel.z == site.berth.z)
			continue
		var/distance = distance_to(site)
		if(distance <= radius + site.radius + ST_NAV_APPROACH + 5 && distance < closest_distance)
			closest_distance = distance
			closest_site = site
	return closest_site

/** Choose the ship background from its dock or the current asteroid region. */
/datum/stationtrauma_overmap/space/proc/parallax_background()
	// The station background belongs to the station level: a hull already moved to its flight level sees open space.
	if(docked?.physical_docking && vessel.z == docked.berth?.z && is_station_level(vessel.z))
		return /atom/movable/screen/parallax_layer/planet
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		if(zone.kind == "asteroids" && (pos_x - zone.pos_x) ** 2 + (pos_y - zone.pos_y) ** 2 <= zone.radius ** 2)
			return /atom/movable/screen/parallax_layer/random/asteroids
	return /atom/movable/screen/parallax_layer/layer_3
