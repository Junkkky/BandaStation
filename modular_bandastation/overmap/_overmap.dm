/// Small hull: any berth or seam; lands where the hull can_land.
#define ST_SHIP_SMALL "small"
/// Medium hull: any berth or seam; lands where the hull can_land.
#define ST_SHIP_MEDIUM "medium"
/// Capital hull: seam destinations only, never landing or a physical berth.
#define ST_SHIP_CAPITAL "capital"
/// Speed below which a hull counts as stopped for arrival, docking and helm state.
#define ST_NAV_STOPPED_SPEED 0.05

/** Registers the overmap module and its compile-time dependencies. */
/datum/modpack/overmap
	name = "Overmap StationTrauma"
	desc = "Общая виртуальная навигация, инерция, автопилот и контакты судов."
	author = "junkky"
