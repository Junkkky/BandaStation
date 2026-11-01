/// Collision tear; power is the impact speed: repairable wall tears and barrier damage.
#define SHIP_HIT_IMPACT "impact"
/// Kinetic shell; power is the heavy impact radius of a native explosion at the struck plating.
#define SHIP_HIT_KINETIC "kinetic"
/// Electromagnetic pulse; power is the heavy pulse radius at the struck plating.
#define SHIP_HIT_EMP "emp"

/** Registers the ship combat module: hull hits and the ship-to-ship combat built on them. */
/datum/modpack/space_combat
	name = "Космический бой StationTrauma"
	desc = "Попадания по корпусу кораблей овермапы и бой между кораблями."
	author = "junkky"
