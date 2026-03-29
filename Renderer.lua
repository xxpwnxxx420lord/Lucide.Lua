local Renderer = {}

local defaults = {
	xmlns           = "http://www.w3.org/2000/svg",
	width           = 24,
	height          = 24,
	viewBox         = "0 0 24 24",
	fill            = "none",
	stroke          = "currentColor",
	stroke_width    = 2,
	stroke_linecap  = "round",
	stroke_linejoin = "round",
}

function Renderer.toSVG(iconNode: {{tag: string, attrs: {[string]: string}}}, opts: {size: number?, color: string?, stroke_width: number?}): string
	local size  = opts.size         or defaults.width
	local color = opts.color        or defaults.stroke
	local sw    = opts.stroke_width or defaults.stroke_width

	local root = '<svg'
		.. ' xmlns="'           .. defaults.xmlns           .. '"'
		.. ' width="'           .. size                     .. '"'
		.. ' height="'          .. size                     .. '"'
		.. ' viewBox="'         .. defaults.viewBox         .. '"'
		.. ' fill="'            .. defaults.fill            .. '"'
		.. ' stroke="'          .. color                    .. '"'
		.. ' stroke-width="'    .. sw                       .. '"'
		.. ' stroke-linecap="'  .. defaults.stroke_linecap  .. '"'
		.. ' stroke-linejoin="' .. defaults.stroke_linejoin .. '"'
		.. '>'

	local children = {}
	for _, el in ipairs(iconNode) do
		local parts = {}
		for k, v in pairs(el.attrs) do
			parts[#parts + 1] = k:gsub("_", "-") .. '="' .. v .. '"'
		end
		children[#children + 1] = "<" .. el.tag .. " " .. table.concat(parts, " ") .. "/>"
	end

	return root .. table.concat(children) .. "</svg>"
end

return Renderer
