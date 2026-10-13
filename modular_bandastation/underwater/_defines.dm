#ifndef STATIONTRAUMA_WATER_DEFINES
#define STATIONTRAUMA_WATER_DEFINES

#define FLOOD_WATER_WAIST 40
#define FLOOD_WATER_DEEP 100
#define FLOOD_WATER_SUBMERGED 200
#define FLOOD_WATER_MAX_DEPTH 220
// Average fully flooded plating colour: preserve the original fade without transparent sprites.
#define FLOOD_WATER_IMMERSION_COLOR "#1f343a"
#define FLOOD_WATER_FLOW_EPSILON 0.000001
#define FLOOD_WATER_MAX_BACKLOG 0.5
#define FLOOD_WORK_SOURCES 1
#define FLOOD_WORK_FRONT 2
#define FLOOD_WORK_PUMPS 3
// Fresh water, kPa per centimetre; custom pipe displays use bar (100 kPa).
#define FLOOD_WATER_KPA_PER_CM 0.0980665
#define FLOOD_WATER_PRESSURE_EPSILON 0.0001
// Existing wall dents/window damage create small inlets, never a second hull health pool.
#define FLOOD_WATER_LEAK_OPENING 0.0001
#define FLOOD_WATER_LEAK_MIN_DENTS 2
#define FLOOD_WATER_LEAK_MAX_DENTS 4
#define FLOOD_WATER_LEAK_WINDOW_INTEGRITY 0.6
#define COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED "stationtrauma_water_boundary_changed"
#define COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED "stationtrauma_water_presence_changed"
#define COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED "stationtrauma_water_mask_changed"
#define FLOOD_WATER_TEMPERATURE (T0C + 4)
// One-square-metre water footprint: a centimetre is ten litres.
#define FLOOD_WATER_LITRES_PER_CM 10
#define STATIONTRAUMA_WATER_LAYER_BIT(level) (1 << (4 + (level)))
#define STATIONTRAUMA_WATER_LAYER STATIONTRAUMA_WATER_LAYER_BIT(3)
#define STATIONTRAUMA_WATER_COLOR "#37C7B7"
#define STATIONTRAUMA_WATER_MAX_FLOW 5000
#define STATIONTRAUMA_WATER_ATMOSPHERE 1
#define STATIONTRAUMA_WATER_OCEAN_PRESSURE 60

#endif
