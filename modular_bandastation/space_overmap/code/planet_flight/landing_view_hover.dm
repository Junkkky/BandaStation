// Adapted from Voidcrew PR #588 (Jackriip), AGPL-3.0. See ../../ATTRIBUTION.md.

/**
 * # The planet below
 *
 * A ship flying over a planet has it under the hull for as long as it stays there: the people aboard see it
 * come up as the ship arrives over it and fall away as it leaves. A landing starts from this picture and a
 * takeoff ends on it, so from open space to the ground and back there is always something outside.
 *
 * Made of the same planet as the landing view, held at one size. A handful of screen objects for everyone
 * aboard: it costs nothing to keep.
 */

/// How long the planet takes to come up under a ship that arrives over it, and to fall away when it leaves
#define HOVER_ARRIVE (2.4 SECONDS)
#define HOVER_LEAVE (2 SECONDS)
/// How often the view checks that the ship and its hull are still where it thinks they are
#define HOVER_CHECK (2 SECONDS)
/// Size the planet eases to on an orbital approach, where the descent takes over from it
#define HOVER_APPROACH_SIZE 2.4
/// Least time the approach zoom takes, for a ship whose approach is already well under way
#define HOVER_APPROACH_LEAST (3 SECONDS)
/// After its zoom the planet keeps closing in this much more over this long, while the descent waits for its ground:
/// too slowly for the handover to show, however far the clients' clocks run ahead, and never quite still
#define HOVER_APPROACH_CREEP 1.2
#define HOVER_APPROACH_CREEP_TIME (60 SECONDS)

/// The view of the planet this ship is flying over, if it is over one
/datum/landing_view/hover
	var/datum/stationtrauma_overmap/space/navigation
	/// The planet below
	var/datum/stationtrauma_overmap_site/space/planet/site
	/// The planet's size and opacity
	var/datum/landing_track/size
	var/datum/landing_track/opacity
	/// Its pieces: see /datum/landing_view/proc/new_planet()
	var/list/grains
	var/datum/landing_view_piece/shade
	var/datum/landing_view_piece/air
	/// TRUE once the ship has left and the planet is falling away
	var/leaving = FALSE
	/// Where the hull's port stood when this was made: a hull that has moved needs a new view
	var/turf/port_turf
	var/next_check = 0
	/// TRUE once the orbital approach has been planned (see plan_approach())
	var/approach_planned = FALSE

/**
 * * hull_turfs - the hull's turfs in transit
 * * arriving - FALSE to have the planet there at once, at full size: the end of a climb out
 */
/datum/landing_view/hover/New(obj/docking_port/mobile/shuttle, list/hull_turfs, datum/stationtrauma_overmap_site/space/planet/site, datum/stationtrauma_overmap/space/navigation, arriving = TRUE)
	..(shuttle, hull_turfs, null, 0)
	if(ended)
		return
	src.navigation = navigation
	src.site = site
	port_turf = get_turf(shuttle)
	palette = landing_view_palette_for(site)
	var/list/planet = new_planet()
	grains = planet[1]
	shade = planet[2]
	var/datum/landing_view_piece/whole = grains[1][1]
	size = whole.scale
	air = new_air(whole)
	if(arriving)
		play(LANDING_HOVER_FAR, LANDING_HOVER_SIZE, 0, 255, HOVER_ARRIVE, LANDING_CURVE_OUT)
	else
		play(LANDING_HOVER_SIZE, LANDING_HOVER_SIZE, 255, 255, 0)
	next_check = world.time + HOVER_CHECK
	sync_viewers()

/datum/landing_view/hover/Destroy(force)
	if(navigation?.planet_hover == src)
		navigation.planet_hover = null
	navigation = null
	site = null
	grains = null
	shade = null
	air = null
	port_turf = null
	return ..()

/// Moves the planet from one size and opacity to another over [time], then on to [creep_size] over [creep_time]
/datum/landing_view/hover/proc/play(from_size, to_size, from_opacity, to_opacity, time, curve = LANDING_CURVE_LINEAR, creep_size, creep_time = 0)
	var/now = world.time
	size.times = list()
	size.values = list()
	size.curves = list()
	size.mark(now, from_size)
	opacity = new
	opacity.mark(now, from_opacity)
	air.alpha = new
	air.alpha.mark(now, from_opacity * 0.92)
	if(time)
		size.mark(now + time, to_size, curve)
		if(creep_time)
			size.mark(now + time + creep_time, creep_size)
		// solid all the way but for an instant at its smallest: a planet that fades lets the stars show through it
		if(to_opacity > from_opacity)
			opacity.mark(now + 0.2 SECONDS, to_opacity)
			air.alpha.mark(now + 0.2 SECONDS, to_opacity * 0.92)
		else
			opacity.mark(now + time - 0.2 SECONDS, from_opacity)
			air.alpha.mark(now + time - 0.2 SECONDS, from_opacity * 0.92)
			opacity.mark(now + time, to_opacity)
			air.alpha.mark(now + time, to_opacity * 0.92)
	for(var/list/grain as anything in grains)
		for(var/datum/landing_view_piece/sheet as anything in grain)
			sheet.alpha = new
	chain_detail(grains, size, opacity, LANDING_PLANET_DETAIL)
	shade.alpha = opacity
	show(shade)
	show(air)

/**
 * The planet grows under a ship on its orbital approach, easing to HOVER_APPROACH_SIZE by [started] + [duration],
 * then closing in only very slowly while the descent waits for its ground: the descent takes over from a planet barely
 * growing, so the handover cannot jerk even though clients play the zoom by their own clock, ahead of world.time under
 * time dilation, and the ship never seems to hang still. Planned once, for the same reason.
 */
/datum/landing_view/hover/proc/plan_approach(started, duration)
	if(approach_planned || leaving || ended)
		return
	approach_planned = TRUE
	var/now = world.time
	var/current = size.at(now)
	var/reached = max(current, HOVER_APPROACH_SIZE)
	play(current, reached, opacity.at(now), 255, max(HOVER_APPROACH_LEAST, started + duration - now), LANDING_CURVE_OUT, reached * HOVER_APPROACH_CREEP, HOVER_APPROACH_CREEP_TIME)

/datum/landing_view/hover/proc/settle_after_approach()
	if(size.at(size.end_time()) > LANDING_HOVER_SIZE)
		play(size.at(world.time), LANDING_HOVER_SIZE, opacity.at(world.time), 255, HOVER_LEAVE, LANDING_CURVE_OUT)

/// The ship has left the planet behind: it falls away, and then the view deletes itself
/datum/landing_view/hover/proc/leave()
	if(leaving || ended)
		return
	leaving = TRUE
	play(size.at(world.time), LANDING_HOVER_FAR, opacity.at(world.time), 0, HOVER_LEAVE, LANDING_CURVE_IN)
	// a hard reference: the ship may let go of us before then
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), HOVER_LEAVE)

/datum/landing_view/hover/sync_viewers()
	. = ..()
	if(ended || leaving || world.time < next_check)
		return
	next_check = world.time + HOVER_CHECK
	var/datum/stationtrauma_overmap/space/our_navigation = navigation
	if(QDELETED(our_navigation) || QDELETED(shuttle))
		qdel(src)
	else if(get_turf(shuttle) != port_turf)
		// the hull stands somewhere else now: the same planet, around where it is
		qdel(src)
		our_navigation.update_planet_hover(FALSE)
	else
		our_navigation.update_planet_hover()
