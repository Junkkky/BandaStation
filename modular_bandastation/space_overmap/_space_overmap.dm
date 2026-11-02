/// Astronomical units per sector unit, for crew-facing distances.
#define ST_SPACE_AU_SCALE 0.001
/// Duration of a bluespace jump between sectors.
#define ST_SPACE_JUMP_TIME (20 SECONDS)
/// Highest relative speed at which two hulls may dock.
#define ST_SPACE_DOCK_SPEED 0.5
/// How long a ship-to-ship docking request waits for an answer.
#define ST_SPACE_DOCK_REQUEST_TIME (30 SECONDS)
/// Planetary descent duration; a first landing generates the surface meanwhile.
#define ST_SPACE_LANDING_TIME (2 MINUTES)
/// Approach to a space destination before its seam is built; a first visit loads the destination meanwhile.
#define ST_SPACE_APPROACH_TIME (45 SECONDS)
/// Sent by an area when its space parallax background changes: ().
#define COMSIG_AREA_SPACE_PARALLAX_CHANGED "area_space_parallax_changed"
/// Combustion chamber phase: cold and idle.
#define SHIP_CHAMBER_OFF "off"
/// Combustion chamber phase: warming up to operating temperature.
#define SHIP_CHAMBER_STARTING "starting"
/// Combustion chamber phase: burning and feeding the engines.
#define SHIP_CHAMBER_RUNNING "running"
/// Combustion chamber phase: venting the chamber.
#define SHIP_CHAMBER_PURGING "purging"
/// Combustion chamber phase: tripped by a fault until reset.
#define SHIP_CHAMBER_LOCKED "locked"
/// Nominal hot-gas temperature required for full nozzle power and a completed warm-up.
#define SHIP_ENGINE_OPERATING_TEMPERATURE 1000
/// Constant slight deceleration of every hull per second, so a dead ship does not drift forever.
#define ST_SPACE_DRAG 0.01
/// Powered emergency manoeuvring thrusters: a tenth of a full main-engine brake, per second.
#define ST_SPACE_RCS_DECELERATION (5 / 150)

/** Registers the space overmap module and its compile-time dependencies. */
/datum/modpack/space_overmap
	name = "Space Overmap StationTrauma"
	desc = "Космические рейсы, межзвёздные переходы и экспедиционные локации."
	author = "junkky"
