// Water-equivalent litres and joules are local to the plant, never reagents or floodwater.
#define ST_PLANT_WATER 1
#define ST_PLANT_STEAM 2
#define ST_PLANT_EXHAUST 3
#define ST_PLANT_COOLANT 4
#define ST_PLANT_SEA 5
#define ST_PLANT_WATER_HEAT 4180
#define ST_PLANT_VAPOR_ENERGY 2590400
#define ST_PLANT_AMBIENT T20C
#define ST_PLANT_BOILING (T0C + 100)
#define ST_PLANT_WARNING (T0C + 350)
#define ST_PLANT_SCRAM (T0C + 450)
#define ST_PLANT_DAMAGE (T0C + 500)
#define ST_PLANT_SERVICE (T0C + 80)

GLOBAL_VAR_INIT(stationtrauma_plant_revision, 0)
GLOBAL_LIST_EMPTY(stationtrauma_plant_parts)
GLOBAL_LIST_EMPTY(stationtrauma_plant_pipes)

/** Invalidate only the isolated plant's cached connections. */
/proc/stationtrauma_plant_changed()
	GLOB.stationtrauma_plant_revision++

/** Human-readable line names, shared by examination and the construction tool. */
/proc/stationtrauma_plant_line_name(line)
	switch(line)
		if(ST_PLANT_WATER)
			return "питательная вода"
		if(ST_PLANT_STEAM)
			return "свежий пар"
		if(ST_PLANT_EXHAUST)
			return "отработанный пар"
		if(ST_PLANT_COOLANT)
			return "аварийное охлаждение"
		if(ST_PLANT_SEA)
			return "забортное охлаждение"

/** Visual pipe colours have no chemical or atmospheric meaning. */
/proc/stationtrauma_plant_line_color(line)
	switch(line)
		if(ST_PLANT_WATER)
			return "#5188b5"
		if(ST_PLANT_STEAM)
			return "#c9c9c9"
		if(ST_PLANT_EXHAUST)
			return "#b68b64"
		if(ST_PLANT_COOLANT)
			return "#945f9f"
		if(ST_PLANT_SEA)
			return "#458d87"
