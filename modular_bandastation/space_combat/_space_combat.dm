/// Collision tear; power is the impact speed: repairable wall tears and barrier damage.
#define SHIP_HIT_IMPACT "impact"
/// Kinetic shell; power is the heavy impact radius of a native explosion at the struck plating.
#define SHIP_HIT_KINETIC "kinetic"
/// Electromagnetic pulse; power is the heavy pulse radius at the struck plating.
#define SHIP_HIT_EMP "emp"

/// Maximum distance a prototype shell travels in the sector.
#define ST_AUTOCANNON_RANGE 260
/// Velocity of the prototype shell, in sector units per second.
#define ST_AUTOCANNON_SPEED 55
/// Keep confirmed impacts past a normal console refresh.
#define ST_KINETIC_IMPACT_MEMORY (2 SECONDS)
/// Speed multiplier for the physical projectile segment.
#define ST_AUTOCANNON_LOCAL_SPEED 3
/// Half angle of the mount, measured from its axis.
#define ST_AUTOCANNON_ARC 45
/// Maximum deviation in degrees per round, biased towards the selected bearing.
#define ST_AUTOCANNON_SPREAD 1.5
/// Time to cycle the feed after the last round of a burst.
#define ST_AUTOCANNON_RELOAD (3 SECONDS)
/// Energy taken from the gun area for each shell.
#define ST_AUTOCANNON_SHOT_ENERGY (5 KILO JOULES)
#define ST_AUTOCANNON_CAPACITY (3 * ST_AUTOCANNON_SHOT_ENERGY)

/// Maximum combat load on the patrol ship's electrical network.
#define ST_COMBAT_BUS_POWER (60 KILO WATTS)
/// Power required for a fully open set of drive regulators.
#define ST_COMBAT_ENGINE_POWER (25 KILO WATTS)
#define ST_SHIP_SHIELD_HOLD_POWER (5 KILO WATTS)
#define ST_SHIP_SHIELD_CAPACITY (120 KILO JOULES)
#define ST_SHIP_SHIELD_START_CHARGE (30 KILO JOULES)
#define ST_SHIP_SHIELD_KINETIC_IMPACT (45 KILO JOULES)
#define ST_SHIP_SHIELD_RECOVERY (4 SECONDS)

/// A pod can follow a ship within this distance from the launch point.
#define ST_DROP_POD_RANGE 260
#define ST_DROP_POD_SPEED 25
#define ST_DROP_POD_PREPARE (4 SECONDS)
#define ST_DROP_POD_MIN_FLIGHT (5 SECONDS)
/// Terminal braking indication before the scheduled touchdown.
#define ST_DROP_POD_BRAKING_TIME (2 SECONDS)
#define ST_DROP_POD_REPORT_TIME (30 SECONDS)
/// Iron sheets held by a launch rack for one capsule.
#define ST_DROP_POD_IRON_COST 10
/// Time for one loaded rack to assemble a launchable capsule.
#define ST_DROP_POD_ASSEMBLY_TIME (10 SECONDS)
/// Gas volume of a fitted cabin, in litres.
#define ST_DROP_POD_CABIN_VOLUME 500
/// Time an opened, spent capsule remains on the landing tile.
#define ST_DROP_POD_SPENT_TIME (5 SECONDS)

/// Hostile capture keeps the target free to manoeuvre for this long.
#define ST_BOARDING_TIME (ST_SPACE_MOORING_TIME + 15 SECONDS)
/// Highest absolute speed of either hull during a hostile approach, in sector units per second.
#define ST_BOARDING_SPEED 1
/// Uninterrupted powered preparation to break a hostile collar.
#define ST_BOARDING_RELEASE_TIME (90 SECONDS)

/** Registers the ship combat module: hull hits and the ship-to-ship combat built on them. */
/datum/modpack/space_combat
	name = "Космический бой StationTrauma"
	desc = "Попадания по корпусу кораблей овермапы и бой между кораблями."
	author = "junkky"
