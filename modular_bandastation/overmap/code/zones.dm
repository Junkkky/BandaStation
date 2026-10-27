/** Charted navigation regions use virtual coordinates in either environment. */
/datum/stationtrauma_overmap_zone
	var/name
	var/kind
	var/pos_x
	var/pos_y
	var/radius
	var/direction = 0

/datum/stationtrauma_overmap_zone/New(label, category, cx, cy, size)
	name = label
	kind = category
	pos_x = cx
	pos_y = cy
	radius = size

/** Include the swept segment so fast passage cannot skip a small region. */
/datum/stationtrauma_overmap_zone/proc/crosses(ax, ay, bx, by)
	return (bx - pos_x) ** 2 + (by - pos_y) ** 2 <= radius ** 2 || !isnull(stationtrauma_circle_hit(ax, ay, bx - ax, by - ay, pos_x, pos_y, radius))
