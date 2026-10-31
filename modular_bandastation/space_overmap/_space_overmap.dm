// AI EDIT START - space overmap module integration
#define ST_SPACE_AU_SCALE 0.001
#define ST_SPACE_JUMP_TIME (20 SECONDS)
#define ST_SPACE_DOCK_SPEED 0.5
#define ST_SPACE_DOCK_REQUEST_TIME (30 SECONDS)
/// Planetary descent duration; a first landing generates the surface meanwhile.
#define ST_SPACE_LANDING_TIME (2 MINUTES)
#define COMSIG_AREA_SPACE_PARALLAX_CHANGED "area_space_parallax_changed"
#define SHIP_CHAMBER_OFF "off"
#define SHIP_CHAMBER_STARTING "starting"
#define SHIP_CHAMBER_RUNNING "running"
#define SHIP_CHAMBER_PURGING "purging"
#define SHIP_CHAMBER_LOCKED "locked"
/// Nominal hot-gas temperature required for full nozzle power and a completed warm-up.
#define SHIP_ENGINE_OPERATING_TEMPERATURE 1000

/** Registers the space overmap module and its compile-time dependencies. */
/datum/modpack/space_overmap
	name = "Space Overmap StationTrauma"
	desc = "Космические рейсы, межзвёздные переходы и экспедиционные локации."
	author = "junkky"
// AI EDIT END
