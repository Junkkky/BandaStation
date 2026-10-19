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
// Conditional liquid stiffness: short pressure pulses without storing extra litres above capacity.
#define FLOOD_WATER_HEAD_STIFFNESS 2000000
#define FLOOD_WATER_HEAD_EPSILON 1
#define FLOOD_WATER_FULL_TOLERANCE 0.01
#define FLOOD_WATER_BREACH_OPENING 0.3
// SSfloodwater: confirmed source turf, destination turf, passed litres, pre-transfer kPa, opening m2, weak leak.
#define COMSIG_STATIONTRAUMA_WATER_TRANSFER "stationtrauma_water_transfer"
// Local impulse strength: sqrt(kPa) * sqrt(opening / reference opening), not room filling speed.
#define FLOOD_WATER_IMPULSE_KNOCKDOWN 3
#define FLOOD_WATER_IMPULSE_THROW 4
#define FLOOD_WATER_IMPULSE_HURT 12
#define FLOOD_WATER_IMPULSE_REACH 2
#define FLOOD_WATER_IMPULSE_RANGE 6
#define FLOOD_WATER_IMPULSE_SPEED 3
#define FLOOD_WATER_IMPULSE_INTERVAL (0.25 SECONDS)
#define FLOOD_WATER_IMPULSE_RESET (0.75 SECONDS)
#define FLOOD_WATER_IMPULSE_REPEAT_CHANCE 2
#define FLOOD_WATER_CURRENT_DURATION (0.5 SECONDS)
#define FLOOD_WATER_DRIFT_STEPS 2
#define FLOOD_WATER_DRIFT_INTERVAL (0.2 SECONDS)
#define FLOOD_WATER_DRIFT_DURATION (1 SECONDS)
#define FLOOD_WATER_DRIFT_DAMPING 0.75
#define FLOOD_WATER_DRIFT_OBJECT_LIMIT 8
#define FLOOD_WATER_VISUAL_INTERVAL (0.75 SECONDS)
#define FLOOD_WATER_VISUAL_DURATION (0.6 SECONDS)
#define FLOOD_WATER_VISUAL_LIMIT 32
#define FLOOD_WATER_SWIM_STROKES 3
#define FLOOD_WATER_SWIM_SLOWDOWN 0.5
#define FLOOD_WATER_SWIM_CRUISE_SLOWDOWN 0.15
#define FLOOD_WATER_SWIM_CHAIN (0.75 SECONDS)
#define FLOOD_WATER_SWIM_RELEASE_DELAY (0.3 SECONDS)
#define FLOOD_WATER_SWIM_COAST_INTERVAL (0.2 SECONDS)
#define FLOOD_WATER_SWIM_COAST_DECAY (0.15 SECONDS)
#define FLOOD_WATER_IMPULSE_COOLDOWN (2.5 SECONDS)
#define FLOOD_WATER_IMPULSE_KNOCKDOWN_MAX (2 SECONDS)
// Existing wall dents/window damage create small inlets, never a second hull health pool.
#define FLOOD_WATER_LEAK_OPENING 0.0001
#define FLOOD_WATER_LEAK_MIN_DENTS 2
#define FLOOD_WATER_LEAK_MAX_DENTS 4
#define FLOOD_WATER_LEAK_WINDOW_INTEGRITY 0.6
#define COMSIG_STATIONTRAUMA_WATER_BOUNDARY_CHANGED "stationtrauma_water_boundary_changed"
#define COMSIG_STATIONTRAUMA_WATER_PRESENCE_CHANGED "stationtrauma_water_presence_changed"
#define COMSIG_STATIONTRAUMA_WATER_MASK_CHANGED "stationtrauma_water_mask_changed"
// Area: finite water component, new native depth stage (zero on removal).
#define COMSIG_STATIONTRAUMA_WATER_STAGE_CHANGED "stationtrauma_water_stage_changed"
#define COMSIG_STATIONTRAUMA_FLOOD_ALARM_CHANGED "stationtrauma_flood_alarm_changed"
// One-square-metre water footprint: a centimetre is ten litres.
#define FLOOD_WATER_LITRES_PER_CM 10
#define STATIONTRAUMA_WATER_LAYER_BIT(level) (1 << (4 + (level)))
#define STATIONTRAUMA_WATER_LAYER STATIONTRAUMA_WATER_LAYER_BIT(3)
#define STATIONTRAUMA_WATER_COLOR "#37C7B7"
#define STATIONTRAUMA_WATER_MAX_FLOW 5000
#define STATIONTRAUMA_PUMP_MIN_FLOW 1800
#define STATIONTRAUMA_PUMP_MIN_PRESSURE 80
#define STATIONTRAUMA_PUMP_MAX_PRESSURE 100
#define STATIONTRAUMA_WATER_ATMOSPHERE 1
#define STATIONTRAUMA_WATER_OCEAN_PRESSURE 60

#endif
