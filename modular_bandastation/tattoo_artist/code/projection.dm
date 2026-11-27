/// Row keys are BYOND Y coordinates. The columns in each row include only opaque skin.
/proc/tattoo_skin_rows(icon/skin)
	var/list/rows = list()
	for(var/y in 1 to 32)
		var/list/columns = list()
		for(var/x in 1 to 32)
			if(skin.GetPixel(x, y))
				columns += x
		if(length(columns))
			rows["[y]"] = columns
	return rows

/// Use the same physical height and the same fraction of the visible row on the turned limb.
/// When the target is narrower, even a one-pixel stroke must land on at least one actual pixel.
/datum/tattoo_design/proc/project_tattoo_frame(icon/source_frame, list/source_rows, list/target_rows, list/locations, icon/blank)
	var/icon/frame = icon(blank)
	var/source_bottom = text2num(source_rows[1])
	var/source_height = text2num(source_rows[length(source_rows)]) - source_bottom + 1
	var/target_bottom = text2num(target_rows[1])
	var/target_top = text2num(target_rows[length(target_rows)])
	var/target_height = target_top - target_bottom + 1
	// Some species have gaps. Resolve those rows to the nearest visible part of the silhouette.
	var/list/nearest_y = new/list(32)
	for(var/y in target_bottom to target_top)
		for(var/key in target_rows)
			var/row_y = text2num(key)
			if(isnull(nearest_y[y]) || abs(row_y - y) < abs(nearest_y[y] - y))
				nearest_y[y] = row_y
	for(var/location in ink_locations)
		var/x = (location - 1) % 32 + 1
		var/y = FLOOR((location - 1) / 32, 1) + 1
		var/list/source_columns = source_rows["[y]"]
		var/column = source_columns.Find(x) - 1
		var/color = source_frame.GetPixel(x, y)
		var/low_y = target_bottom + FLOOR((y - source_bottom) * target_height / source_height, 1)
		var/high_y = max(low_y, target_bottom + FLOOR((y - source_bottom + 1) * target_height / source_height, 1) - 1)
		for(var/mapped_y in low_y to high_y)
			var/target_y = nearest_y[mapped_y]
			var/list/target_columns = target_rows["[target_y]"]
			var/low_column = 1 + FLOOR(column * length(target_columns) / length(source_columns), 1)
			var/high_column = max(low_column, FLOOR((column + 1) * length(target_columns) / length(source_columns), 1))
			for(var/index in low_column to high_column)
				var/target_x = target_columns[index]
				frame.DrawBox(color, target_x, target_y)
				locations |= (target_y - 1) * 32 + target_x
	return frame

/// Render an enlarged crop on actual skin. The drawn side retains its full 64×64 detail.
/proc/tattoo_view_image(icon/skin, icon/ink, skin_color, left, bottom, right, top)
	var/size = ink.Width()
	var/padding = size / 32
	if(skin_color)
		skin.Blend(skin_color, ICON_MULTIPLY)
	skin.Scale(size, size)
	skin.Blend(ink, ICON_OVERLAY)
	skin.Crop(max(1, left - padding), max(1, bottom - padding), min(size, right + padding), min(size, top + padding))
	skin.Scale(skin.Width() * 256 / size, skin.Height() * 256 / size)
	return "data:image/png;base64,[icon2base64(skin)]"

/datum/tattoo_design/proc/build_tattoo_views(list/projection_skins, skin_color, icon/source_frame, icon/blank, make_previews)
	var/list/source_rows = tattoo_skin_rows(projection_skins["[side]"])
	ink_by_direction = list()
	if(make_previews)
		view_previews = list()
	for(var/direction in GLOB.cardinals)
		var/icon/frame
		var/preview
		if(direction == side)
			frame = source_frame
			ink_by_direction["[direction]"] = ink_locations
			preview = examine_image_url
		else
			var/icon/skin = projection_skins["[direction]"]
			var/list/locations = list()
			frame = project_tattoo_frame(source_frame, source_rows, tattoo_skin_rows(skin), locations, blank)
			ink_by_direction["[direction]"] = locations
			if(make_previews)
				var/left = 33
				var/right = 0
				var/bottom = 33
				var/top = 0
				for(var/location in locations)
					var/x = (location - 1) % 32 + 1
					var/y = FLOOR((location - 1) / 32, 1) + 1
					left = min(left, x)
					right = max(right, x)
					bottom = min(bottom, y)
					top = max(top, y)
				preview = tattoo_view_image(skin, frame, skin_color, left, bottom, right, top)
		world_icon.Insert(frame, icon_state = "", dir = direction)
		if(make_previews && preview)
			view_previews += list(list("direction" = direction, "image" = preview))
