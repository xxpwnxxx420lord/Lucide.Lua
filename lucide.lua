local ROOT      = "https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/refs/heads/main/"
local CACHE_DIR = "lucide_cache/"
local CHUNKS    = 9

local function loadRemote(path)
	return loadstring(game:HttpGet(ROOT .. path, true))()
end

makefolder(CACHE_DIR)

local Converter = loadRemote("Converter.lua")

local IconData = {}

for i = 1, CHUNKS do
	local chunk = loadRemote(string.format("icons/chunk_%02d.lua", i))
	for name, node in pairs(chunk) do
		IconData[name] = node
		local alias = name:gsub("%-", "_")
		if alias ~= name then
			IconData[alias] = node
		end
	end
end

local module = {}

function module:geticon(name, opts)
	local node = IconData[name]
	assert(node, "[lucide] icon not found: " .. tostring(name))

	opts = opts or {}
	local size  = math.floor(opts.size or 64)
	local color = opts.color or "#ffffff"
	local sw    = opts.stroke_width or 2

	local safeColor = color:gsub("[^%w%-#]", "")
	local cacheKey  = name .. "_s" .. size .. "_sw" .. sw .. "_c" .. safeColor
	local filePath  = CACHE_DIR .. cacheKey .. ".png"

	if not isfile(filePath) then
		writefile(filePath, Converter.toPNG(node, { size = size, color = color, stroke_width = sw }))
	end

	return getcustomasset(filePath)
end

return module
