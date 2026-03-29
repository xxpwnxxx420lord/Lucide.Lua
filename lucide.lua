local ROOT      = "lucide/"
local CACHE_DIR = ROOT .. "cache/"
local ICONS_DIR = ROOT .. "icons/"
local CHUNKS    = 9

local function loadFile(path: string): any
	return loadstring(readfile(path))()
end

if not isfolder(ROOT)      then makefolder(ROOT)      end
if not isfolder(CACHE_DIR) then makefolder(CACHE_DIR) end

local Renderer = loadFile(ROOT .. "Renderer.lua")

local IconData: {[string]: {{tag: string, attrs: {[string]: string}}}} = {}

for i = 1, CHUNKS do
	local chunk: {[string]: {{tag: string, attrs: {[string]: string}}}} = loadFile(ICONS_DIR .. string.format("chunk_%02d.lua", i))
	for name, node in pairs(chunk) do
		IconData[name] = node
		local alias = name:gsub("%-", "_")
		if alias ~= name then
			IconData[alias] = node
		end
	end
end

local module = {}

function module:geticon(name: string, opts: {size: number?, color: string?, stroke_width: number?}?): string
	local node = IconData[name]
	assert(node, "[lucide] icon not found: " .. tostring(name))

	local resolvedOpts: {size: number?, color: string?, stroke_width: number?} = opts or {}
	local size  = tostring(resolvedOpts.size         or 24)
	local color = (resolvedOpts.color or "currentColor"):gsub("[^%w%-#]", "")
	local sw    = tostring(resolvedOpts.stroke_width or 2)

	local cacheKey = name .. "_s" .. size .. "_sw" .. sw .. "_c" .. color
	local filePath = CACHE_DIR .. cacheKey .. ".svg"

	if not isfile(filePath) then
		writefile(filePath, Renderer.toSVG(node, resolvedOpts))
	end

	return getcustomasset(filePath)
end

return module
