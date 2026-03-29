local Converter = {}

local band   = bit32.band
local bxor   = bit32.bxor
local bnot   = bit32.bnot
local rshift = bit32.rshift

local _crc = {}
for i = 0, 255 do
	local c = i
	for _ = 1, 8 do
		if band(c, 1) == 1 then c = bxor(0xEDB88320, rshift(c, 1))
		else c = rshift(c, 1) end
	end
	_crc[i] = c
end

local function crc32(s)
	local c = 0xFFFFFFFF
	for i = 1, #s do
		c = bxor(_crc[band(bxor(c, s:byte(i)), 0xFF)], rshift(c, 8))
	end
	return bxor(c, 0xFFFFFFFF)
end

local function u32(n)
	n = band(n, 0xFFFFFFFF)
	return string.char(band(rshift(n,24),0xFF), band(rshift(n,16),0xFF), band(rshift(n,8),0xFF), band(n,0xFF))
end

local function u16le(n)
	return string.char(band(n, 0xFF), band(rshift(n, 8), 0xFF))
end

local function pngChunk(t, d)
	return u32(#d) .. t .. d .. u32(crc32(t .. d))
end

local function adler32(s)
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + s:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return u32(b * 65536 + a)
end

local function encodePNG(pixels, w, h)
	local rows = {}
	for y = 0, h - 1 do
		local row = {"\x00"}
		for x = 0, w - 1 do
			local i = (y * w + x) * 4 + 1
			row[#row + 1] = string.char(
				math.max(0, math.min(255, pixels[i])),
				math.max(0, math.min(255, pixels[i+1])),
				math.max(0, math.min(255, pixels[i+2])),
				math.max(0, math.min(255, pixels[i+3]))
			)
		end
		rows[#rows + 1] = table.concat(row)
	end
	local raw  = table.concat(rows)
	local len  = #raw
	local nlen = band(bnot(len), 0xFFFF)
	local idat = "\x78\x01\x01" .. u16le(len) .. u16le(nlen) .. raw .. adler32(raw)
	return "\x89PNG\r\n\x1a\n"
		.. pngChunk("IHDR", u32(w) .. u32(h) .. "\x08\x06\x00\x00\x00")
		.. pngChunk("IDAT", idat)
		.. pngChunk("IEND", "")
end

local function parseColor(s)
	if not s or s == "" or s == "currentColor" then return 255, 255, 255 end
	if s:sub(1,1) == "#" then
		local h = s:sub(2)
		if #h == 3 then
			local r = tonumber(h:sub(1,1), 16)
			local g = tonumber(h:sub(2,2), 16)
			local b = tonumber(h:sub(3,3), 16)
			return r*17, g*17, b*17
		elseif #h == 6 then
			return tonumber(h:sub(1,2),16), tonumber(h:sub(3,4),16), tonumber(h:sub(5,6),16)
		end
	end
	local named = { white={255,255,255}, black={0,0,0}, red={255,0,0}, blue={0,0,255}, green={0,128,0} }
	local c = named[s]
	if c then return c[1], c[2], c[3] end
	return 255, 255, 255
end

local function distSeg(px, py, ax, ay, bx, by)
	local dx, dy = bx-ax, by-ay
	local lsq = dx*dx + dy*dy
	if lsq < 1e-10 then return math.sqrt((px-ax)^2 + (py-ay)^2) end
	local t = math.max(0, math.min(1, ((px-ax)*dx + (py-ay)*dy) / lsq))
	return math.sqrt((px-ax-t*dx)^2 + (py-ay-t*dy)^2)
end

local function strokePolyline(pixels, w, pts, hw, r, g, b)
	local aa = 0.75
	for k = 1, #pts - 1 do
		local ax, ay = pts[k][1], pts[k][2]
		local bx, by = pts[k+1][1], pts[k+1][2]
		local mg  = hw + aa + 1
		local x0  = math.max(0,   math.floor(math.min(ax,bx) - mg))
		local x1  = math.min(w-1, math.ceil (math.max(ax,bx) + mg))
		local y0  = math.max(0,   math.floor(math.min(ay,by) - mg))
		local y1  = math.min(w-1, math.ceil (math.max(ay,by) + mg))
		for py = y0, y1 do
			for px = x0, x1 do
				local d   = distSeg(px+0.5, py+0.5, ax, ay, bx, by)
				local cov = math.max(0, math.min(1, (hw + aa - d) / (aa * 2)))
				if cov > 0 then
					local i  = (py * w + px) * 4 + 1
					local ia = 1 - cov
					pixels[i]   = math.floor(pixels[i]   * ia + r * cov + 0.5)
					pixels[i+1] = math.floor(pixels[i+1] * ia + g * cov + 0.5)
					pixels[i+2] = math.floor(pixels[i+2] * ia + b * cov + 0.5)
					pixels[i+3] = math.min(255, math.floor(pixels[i+3] + (255 - pixels[i+3]) * cov + 0.5))
				end
			end
		end
	end
end

local function parseNums(s)
	local t = {}
	for n in s:gmatch("[+-]?%d*%.?%d+[eE]?[+-]?%d*") do
		t[#t+1] = tonumber(n)
	end
	return t
end

local function parsePath(d, scale)
	local subpaths = {}
	local cur      = {}
	local cx, cy   = 0, 0
	local sx, sy   = 0, 0
	local lcpx, lcpy = 0, 0

	local function addPt(x, y)
		cur[#cur+1] = {x * scale, y * scale}
		cx, cy = x, y
	end

	local function flush()
		if #cur > 0 then subpaths[#subpaths+1] = cur; cur = {} end
	end

	local function cubicSample(px, py, x1, y1, x2, y2, x3, y3)
		for i = 1, 24 do
			local t = i/24; local mt = 1-t
			addPt(mt^3*px + 3*mt^2*t*x1 + 3*mt*t^2*x2 + t^3*x3,
			      mt^3*py + 3*mt^2*t*y1 + 3*mt*t^2*y2 + t^3*y3)
		end
	end

	local function quadSample(px, py, x1, y1, x2, y2)
		for i = 1, 16 do
			local t = i/16; local mt = 1-t
			addPt(mt^2*px + 2*mt*t*x1 + t^2*x2, mt^2*py + 2*mt*t*y1 + t^2*y2)
		end
	end

	local function arcSample(ax, ay, rx, ry, xrot, la, sw, ex, ey)
		if (ax == ex and ay == ey) or rx == 0 or ry == 0 then addPt(ex, ey); return end
		local phi = math.rad(xrot)
		local cp, sp = math.cos(phi), math.sin(phi)
		local dx, dy = (ax-ex)/2, (ay-ey)/2
		local x1r = cp*dx + sp*dy; local y1r = -sp*dx + cp*dy
		rx, ry = math.abs(rx), math.abs(ry)
		local lam = (x1r/rx)^2 + (y1r/ry)^2
		if lam > 1 then lam = math.sqrt(lam); rx = lam*rx; ry = lam*ry end
		local num = math.max(0, (rx*ry)^2 - (rx*y1r)^2 - (ry*x1r)^2)
		local den = (rx*y1r)^2 + (ry*x1r)^2
		local k   = math.sqrt(num / math.max(den, 1e-10))
		if la == sw then k = -k end
		local cxr = k*rx*y1r/ry; local cyr = -k*ry*x1r/rx
		local mcx = cp*cxr - sp*cyr + (ax+ex)/2
		local mcy = sp*cxr + cp*cyr + (ay+ey)/2
		local function ang(ux, uy, vx, vy)
			local dot = ux*vx + uy*vy
			local len = math.sqrt((ux^2+uy^2) * (vx^2+vy^2))
			local a   = math.acos(math.max(-1, math.min(1, dot / math.max(len, 1e-10))))
			return (ux*vy - uy*vx < 0) and -a or a
		end
		local ux = (x1r-cxr)/rx; local uy = (y1r-cyr)/ry
		local vx = (-x1r-cxr)/rx; local vy = (-y1r-cyr)/ry
		local th1 = ang(1, 0, ux, uy)
		local dth = ang(ux, uy, vx, vy)
		if sw == 0 and dth > 0 then dth = dth - 2*math.pi
		elseif sw == 1 and dth < 0 then dth = dth + 2*math.pi end
		local steps = math.max(8, math.ceil(math.abs(dth) * 12))
		for i = 1, steps do
			local th = th1 + i/steps * dth
			addPt(cp*rx*math.cos(th) - sp*ry*math.sin(th) + mcx,
			      sp*rx*math.cos(th) + cp*ry*math.sin(th) + mcy)
		end
	end

	for cmd, raw in d:gmatch("([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)") do
		local a  = parseNums(raw)
		local n  = #a
		local ai = 1
		local function nxt() local v = a[ai] or 0; ai = ai+1; return v end

		if cmd == "M" then
			flush()
			local nx, ny = nxt(), nxt(); cx, cy = nx, ny; sx, sy = cx, cy
			cur[#cur+1] = {cx*scale, cy*scale}
			while ai <= n do
				local px, py = nxt(), nxt(); addPt(px, py)
			end
		elseif cmd == "m" then
			flush()
			local rx, ry = nxt(), nxt(); cx, cy = cx+rx, cy+ry; sx, sy = cx, cy
			cur[#cur+1] = {cx*scale, cy*scale}
			while ai <= n do
				local rx2, ry2 = nxt(), nxt(); addPt(cx+rx2, cy+ry2)
			end
		elseif cmd == "L" then
			while ai <= n do local px, py = nxt(), nxt(); addPt(px, py) end
		elseif cmd == "l" then
			while ai <= n do local rx, ry = nxt(), nxt(); addPt(cx+rx, cy+ry) end
		elseif cmd == "H" then
			while ai <= n do addPt(nxt(), cy) end
		elseif cmd == "h" then
			while ai <= n do addPt(cx + nxt(), cy) end
		elseif cmd == "V" then
			while ai <= n do addPt(cx, nxt()) end
		elseif cmd == "v" then
			while ai <= n do addPt(cx, cy + nxt()) end
		elseif cmd == "C" then
			while ai <= n do
				local px, py = cx, cy
				local r1,r2,r3,r4,r5,r6 = nxt(),nxt(),nxt(),nxt(),nxt(),nxt()
				lcpx, lcpy = r3, r4
				cubicSample(px,py, r1,r2, r3,r4, r5,r6)
			end
		elseif cmd == "c" then
			while ai <= n do
				local px, py = cx, cy
				local r1,r2,r3,r4,r5,r6 = nxt(),nxt(),nxt(),nxt(),nxt(),nxt()
				lcpx, lcpy = px+r3, py+r4
				cubicSample(px,py, px+r1,py+r2, px+r3,py+r4, px+r5,py+r6)
			end
		elseif cmd == "S" then
			while ai <= n do
				local px, py = cx, cy
				local r1,r2,r3,r4 = nxt(),nxt(),nxt(),nxt()
				local rx1, ry1 = 2*cx-lcpx, 2*cy-lcpy
				lcpx, lcpy = r1, r2
				cubicSample(px,py, rx1,ry1, r1,r2, r3,r4)
			end
		elseif cmd == "s" then
			while ai <= n do
				local px, py = cx, cy
				local r1,r2,r3,r4 = nxt(),nxt(),nxt(),nxt()
				local rx1, ry1 = 2*cx-lcpx, 2*cy-lcpy
				lcpx, lcpy = px+r1, py+r2
				cubicSample(px,py, rx1,ry1, px+r1,py+r2, px+r3,py+r4)
			end
		elseif cmd == "Q" then
			while ai <= n do
				local px, py = cx, cy
				local r1,r2,r3,r4 = nxt(),nxt(),nxt(),nxt()
				lcpx, lcpy = r1, r2
				quadSample(px,py, r1,r2, r3,r4)
			end
		elseif cmd == "q" then
			while ai <= n do
				local px, py = cx, cy
				local r1,r2,r3,r4 = nxt(),nxt(),nxt(),nxt()
				lcpx, lcpy = px+r1, py+r2
				quadSample(px,py, px+r1,py+r2, px+r3,py+r4)
			end
		elseif cmd == "t" then
			while ai <= n do
				local px, py = cx, cy
				local r1, r2 = nxt(), nxt()
				local rx1, ry1 = 2*cx-lcpx, 2*cy-lcpy
				lcpx, lcpy = rx1, ry1
				quadSample(px,py, rx1,ry1, px+r1,py+r2)
			end
		elseif cmd == "A" then
			while ai <= n do
				local rx,ry = nxt(),nxt(); local xr = nxt()
				local la,sw = nxt(),nxt(); local ex,ey = nxt(),nxt()
				arcSample(cx,cy, rx,ry, xr, la,sw, ex,ey)
			end
		elseif cmd == "a" then
			while ai <= n do
				local rx,ry = nxt(),nxt(); local xr = nxt()
				local la,sw = nxt(),nxt(); local rx2,ry2 = nxt(),nxt()
				arcSample(cx,cy, rx,ry, xr, la,sw, cx+rx2,cy+ry2)
			end
		elseif cmd == "Z" or cmd == "z" then
			addPt(sx, sy); flush(); cx, cy = sx, sy
		end
	end
	flush()
	return subpaths
end

function Converter.toPNG(iconNode, opts)
	opts = opts or {}
	local size  = math.floor(opts.size or 64)
	local scale = size / 24
	local hw    = (opts.stroke_width or 2) * scale / 2
	local r, g, b = parseColor(opts.color)

	local pixels = {}
	for i = 1, size * size * 4 do pixels[i] = 0 end

	for _, el in ipairs(iconNode) do
		local tag   = el.tag
		local attrs = el.attrs

		if tag == "path" then
			for _, pts in ipairs(parsePath(attrs.d or "", scale)) do
				strokePolyline(pixels, size, pts, hw, r, g, b)
			end

		elseif tag == "circle" then
			local cx  = (tonumber(attrs.cx) or 0) * scale
			local cy  = (tonumber(attrs.cy) or 0) * scale
			local rad = (tonumber(attrs.r)  or 0) * scale
			local aa  = 0.75; local mg = rad + hw + aa + 1
			for py = math.max(0, math.floor(cy-mg)), math.min(size-1, math.ceil(cy+mg)) do
				for px = math.max(0, math.floor(cx-mg)), math.min(size-1, math.ceil(cx+mg)) do
					local d   = math.abs(math.sqrt((px+0.5-cx)^2 + (py+0.5-cy)^2) - rad)
					local cov = math.max(0, math.min(1, (hw + aa - d) / (aa * 2)))
					if cov > 0 then
						local i  = (py * size + px) * 4 + 1; local ia = 1 - cov
						pixels[i]   = math.floor(pixels[i]   * ia + r * cov + 0.5)
						pixels[i+1] = math.floor(pixels[i+1] * ia + g * cov + 0.5)
						pixels[i+2] = math.floor(pixels[i+2] * ia + b * cov + 0.5)
						pixels[i+3] = math.min(255, math.floor(pixels[i+3] + (255-pixels[i+3]) * cov + 0.5))
					end
				end
			end

		elseif tag == "ellipse" then
			local ecx = (tonumber(attrs.cx) or 0) * scale
			local ecy = (tonumber(attrs.cy) or 0) * scale
			local erx = (tonumber(attrs.rx) or 0) * scale
			local ery = (tonumber(attrs.ry) or 0) * scale
			local pts = {}
			for i = 0, 64 do
				local th = i/64 * 2 * math.pi
				pts[#pts+1] = {ecx + erx*math.cos(th), ecy + ery*math.sin(th)}
			end
			strokePolyline(pixels, size, pts, hw, r, g, b)

		elseif tag == "line" then
			local lx1 = (tonumber(attrs.x1) or 0) * scale
			local ly1 = (tonumber(attrs.y1) or 0) * scale
			local lx2 = (tonumber(attrs.x2) or 0) * scale
			local ly2 = (tonumber(attrs.y2) or 0) * scale
			strokePolyline(pixels, size, {{lx1,ly1},{lx2,ly2}}, hw, r, g, b)

		elseif tag == "rect" then
			local rx = (tonumber(attrs.x)      or 0) * scale
			local ry = (tonumber(attrs.y)      or 0) * scale
			local rw = (tonumber(attrs.width)  or 0) * scale
			local rh = (tonumber(attrs.height) or 0) * scale
			strokePolyline(pixels, size,
				{{rx,ry},{rx+rw,ry},{rx+rw,ry+rh},{rx,ry+rh},{rx,ry}},
				hw, r, g, b)

		elseif tag == "polyline" or tag == "polygon" then
			local pts = {}
			for nx, ny in (attrs.points or ""):gmatch("([%-%.%d]+)[,%s]+([%-%.%d]+)") do
				pts[#pts+1] = {tonumber(nx)*scale, tonumber(ny)*scale}
			end
			if tag == "polygon" and #pts > 0 then pts[#pts+1] = pts[1] end
			strokePolyline(pixels, size, pts, hw, r, g, b)
		end
	end

	return encodePNG(pixels, size, size)
end

return Converter
