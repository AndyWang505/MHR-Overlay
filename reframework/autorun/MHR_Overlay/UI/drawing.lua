local drawing = {};
local config;
local table_helpers;
local unicode_helpers;

drawing.font = nil;

function drawing.init_font()
	local cached_config = config.current_config.global_settings.UI_font;
	drawing.font = d2d.Font.new(cached_config.family, cached_config.size, cached_config.bold, cached_config.italic);
end

function drawing.argb_color_to_abgr_color(argb_color)
	local alpha = (argb_color >> 24) & 0xFF;
	local red = (argb_color >> 16) & 0xFF;
	local green = (argb_color >> 8) & 0xFF;
	local blue = argb_color & 0xFF;

	local abgr_color = 0x1000000 * alpha + 0x10000 * blue + 0x100 * green + red;

	return abgr_color;
end

function drawing.color_to_argb(color)
	local alpha = (color >> 24) & 0xFF;
	local red = (color >> 16) & 0xFF;
	local green = (color >> 8) & 0xFF;
	local blue = color & 0xFF;

	return alpha, red, green, blue;
end

function drawing.argb_to_color(alpha, red, green, blue)
	return 0x1000000 * alpha + 0x10000 * red + 0x100 * green + blue;
end

function drawing.limit_text_size(text, size_limit)
	if d2d == nil or size_limit <= 0 then
		return text;
	end

	local limited_text = text;
	while limited_text ~= "..." do
		local text_width, text_height = drawing.font:measure(limited_text);

		if text_width < size_limit then
			break
		else
			limited_text = unicode_helpers.sub(limited_text, 1, -5) .. "...";
		end
	end

	return limited_text;
end

function drawing.scale_color_opacity(color, scale)
	local alpha, red, green, blue = drawing.color_to_argb(color);
	local new_alpha = math.floor(alpha * scale);
	if new_alpha < 0 then
		new_alpha = 0;
	end
	if new_alpha > 255 then
		new_alpha = 255;
	end

	return drawing.argb_to_color(new_alpha, red, green, blue);
end

function drawing.scale_bar_opacity(bar, scale)
	if bar == nil or scale == nil or not bar.visibility then
		return;
	end

	bar.colors.foreground = drawing.scale_color_opacity(bar.colors.foreground, scale);
	bar.colors.background = drawing.scale_color_opacity(bar.colors.background, scale);
end

function drawing.scale_label_opacity(label, scale)
	if label == nil or scale == nil or not label.visibility then
		return;
	end

	label.color = drawing.scale_color_opacity(label.color, scale);
	label.shadow.color = drawing.scale_color_opacity(label.shadow.color, scale);
end

function drawing.draw_label(label, position, opacity_scale, ...)
	if label == nil or not label.visibility then
		return;
	end

	local text = string.format(label.text, table.unpack({...}));
	local position_x = position.x + label.offset.x;
	local position_y = position.y + label.offset.y;

	if label.shadow.visibility then
		local new_shadow_color = label.shadow.color;

		if opacity_scale < 1 then
			new_shadow_color = drawing.scale_color_opacity(new_shadow_color, opacity_scale);
		end

		if d2d ~= nil then
			d2d.text(drawing.font, text, position_x + label.shadow.offset.x, position_y + label.shadow.offset.y, new_shadow_color);
		else
			new_shadow_color = drawing.argb_color_to_abgr_color(new_shadow_color);
			draw.text(text, position_x + label.shadow.offset.x, position_y + label.shadow.offset.y, new_shadow_color);
		end
	end

	local new_color = label.color;
	if opacity_scale < 1 then
		new_color = drawing.scale_color_opacity(new_color, opacity_scale);
	end

	if d2d ~= nil then
		d2d.text(drawing.font, text, position_x, position_y, new_color);
	else
		new_color = drawing.argb_color_to_abgr_color(new_color);
		draw.text(text, position_x, position_y, new_color);
	end

end

function drawing.draw_bar(bar, position, opacity_scale, percentage)

	if bar == nil or not bar.visibility then
		return;
	end

	if percentage > 1 then
		percentage = 1;
	end

	if percentage < 0 then
		percentage = 0;
	end

	local outline_visibility = bar.outline.visibility;
	local style = bar.outline.style; -- Inside/Center/Outside

	local outline_thickness = bar.outline.thickness;
	if not outline_visibility then
		outline_thickness = 0;
	end

	local half_outline_thickness = outline_thickness / 2;

	local outline_offset = bar.outline.offset;

	if outline_thickness == 0 then
		outline_offset = 0;
	end
	local half_outline_offset = outline_offset / 2;

	local outline_position_x = 0;
	local outline_position_y = 0;

	local outline_width = 0;
	local outline_height = 0;

	local position_x = 0;
	local position_y = 0;

	local foreground_width = 0;
	local background_width = 0;
	local height = 0;

	if style == "Inside" then
		outline_position_x = position.x + bar.offset.x + half_outline_thickness;
		outline_position_y = position.y + bar.offset.y + half_outline_thickness;

		outline_width = bar.size.width - outline_thickness;
		outline_height = bar.size.height - outline_thickness;

		position_x = outline_position_x + half_outline_thickness + outline_offset;
		position_y = outline_position_y + half_outline_thickness + outline_offset;

		local width = outline_width - outline_thickness - outline_offset - outline_offset;
		foreground_width = width * percentage;
		background_width = width - foreground_width;

		height = outline_height - outline_thickness - outline_offset - outline_offset;

	elseif style == "Center" then
		outline_position_x = position.x + bar.offset.x - half_outline_offset;
		outline_position_y = position.y + bar.offset.y - half_outline_offset;

		outline_width = bar.size.width + outline_offset;
		outline_height = bar.size.height + outline_offset;

		position_x = outline_position_x + half_outline_thickness + outline_offset;
		position_y = outline_position_y + half_outline_thickness + outline_offset;

		local width = outline_width - outline_thickness - outline_offset - outline_offset;
		foreground_width = width * percentage;
		background_width = width - foreground_width;

		height = outline_height - outline_thickness - outline_offset - outline_offset;

	else
		position_x = position.x + bar.offset.x;
		position_y = position.y + bar.offset.y;

		local width = bar.size.width;
		height = bar.size.height;

		foreground_width = width * percentage;
		background_width = width - foreground_width;

		outline_position_x = position_x - half_outline_thickness - outline_offset;
		outline_position_y = position_y - half_outline_thickness - outline_offset;

		outline_width = width + outline_thickness + outline_offset + outline_offset;
		outline_height = height + outline_thickness + outline_offset + outline_offset;
	end

	local foreground_color = bar.colors.foreground;
	local background_color = bar.colors.background;
	local outline_color = bar.colors.outline;

	if opacity_scale < 1 then
		foreground_color = drawing.scale_color_opacity(foreground_color, opacity_scale);
		background_color = drawing.scale_color_opacity(background_color, opacity_scale);
		outline_color = drawing.scale_color_opacity(outline_color, opacity_scale);
	end

	local use_d2d = d2d ~= nil;

	-- outline
	if outline_thickness ~= 0 then
		if use_d2d then
			d2d.outline_rect(outline_position_x, outline_position_y, outline_width, outline_height, outline_thickness,
				outline_color);
		else
			outline_color = drawing.argb_color_to_abgr_color(outline_color);
			draw.outline_rect(outline_position_x, outline_position_y, outline_width, outline_height, outline_color);
		end
	end

	-- foreground
	if foreground_width ~= 0 then
		if use_d2d then
			d2d.fill_rect(position_x, position_y, foreground_width, height, foreground_color);

		else
			foreground_color = drawing.argb_color_to_abgr_color(foreground_color);
			draw.filled_rect(position_x, position_y, foreground_width, height, foreground_color)
		end
	end

	-- background
	if background_width ~= 0 then
		if use_d2d then
			d2d.fill_rect(position_x + foreground_width, position_y, background_width, height, background_color);
		else
			background_color = drawing.argb_color_to_abgr_color(background_color);
			draw.filled_rect(position_x + foreground_width, position_y, background_width, height, background_color)
		end
	end
end

function drawing.draw_capture_line(health_UI, position, opacity_scale, percentage)
	if health_UI == nil or not health_UI.visibility or health_UI.bar == nil or not health_UI.bar.visibility or
		health_UI.bar.capture_line == nil or not health_UI.bar.capture_line.visibility or percentage >= 1 or percentage <= 0 then
		return;
	end

	local position_x =
		position.x + health_UI.bar.offset.x + health_UI.bar.capture_line.offset.x + health_UI.bar.size.width * percentage;
	local position_y = position.y + health_UI.bar.offset.y + health_UI.bar.capture_line.offset.y;

	local color = health_UI.bar.capture_line.color;

	if opacity_scale < 1 then
		color = drawing.scale_color_opacity(color, opacity_scale);
	end

	if d2d ~= nil then
		d2d.fill_rect(position_x, position_y, health_UI.bar.capture_line.size.width, health_UI.bar.capture_line.size.height,
			color);
	else
		color = drawing.argb_color_to_abgr_color(color);
		draw.filled_rect(position_x, position_y, health_UI.bar.capture_line.size.width,
			health_UI.bar.capture_line.size.height, color)
	end
end

function drawing.init_module()
	config = require("MHR_Overlay.Misc.config");
	table_helpers = require("MHR_Overlay.Misc.table_helpers");
	unicode_helpers = require("MHR_Overlay.Misc.unicode_helpers");
end

return drawing;
