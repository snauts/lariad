
-- Load tileset.
local spriteMap = {
	"abcdefgh",
	"ijklmnop",
	"qrstuvwx",
	"yzABCDEF",
	"GHIJKLMN",
	"OPQRSTUW",
	"XYZ12345",
	"67890!@#"
}
local tileset = util.TextureToTileset("image/occlusion.png", spriteMap, {64,64})

local function put(tile, x, y, z, attr, where)
	where = where or staticBody
	local tile = eapi.NewTile(where, 
				  { x = math.floor(x), y = math.floor(y) }, 
				  { x = 64, y = 64 },
				  Occlusion.tileset[tile], z)
	if attr then
		eapi.SetAttributes(tile, attr)
	end
	
	return tile
end

local function passage(x, y, z, where, wherePos, text, effect)
	for i = 1, 2, 1 do
		put('i', x,      y,      z)
		put('j', x + 64, y,      z)
		put('q', x,      y - 64, z)
		put('r', x + 64, y - 64, z)
	end
	local shape = { l = x + 54, r = x + 74, b = y - 65, t = y - 55 }
	ExitRoom(shape, where, wherePos, nil, true, text, effect)
end

local function columnParalax(offset, texturePosition)
	local scale = { 128, 256 }
	local name = {"image/occlusion.png", filter=true}
	local col = eapi.NewSpriteList(name, {texturePosition, { 62, 128 }})
	local px = eapi.NewParallax(gameWorld, col, scale, offset, {1.2,1}, 20)
	eapi.SetRepeatPattern(px, {true, false}, {800.0, 0.0})
end
	

local function column()
	columnParalax({ 400, 0 }, { 257, 64 })
	columnParalax({ 800, 0 }, { 193, 64 })
end

local filteredOcc = {"image/occlusion.png", filter=true}
local gradient = eapi.NewSpriteList(filteredOcc, {{ 129, 1}, { 62, 62 }})
local entranceFalloff = eapi.NewSpriteList(filteredOcc, {{ 1, 1}, { 62, 62 }})
local cornerFalloff = eapi.NewSpriteList(filteredOcc, {{ 321, 129}, { 62, 62 }})
local whiteFalloff = eapi.NewSpriteList(filteredOcc, {{ 321, 65}, { 62, 62 }})
local boxFalloff = eapi.NewSpriteList(filteredOcc, {{ 449, 129}, { 62, 62 }})

local dot = { }
local function LoadDot(i)
	dot[i] = eapi.NewSpriteList("image/occlusion.png", {{480, 32}, {i, i}})
end
LoadDot(1)
LoadDot(2)
LoadDot(3)

local function ChooseStalactite()
	return RandomElement({{'l', 't', true}, {'u', 'm', false}})
end

local function RandomStalactite(x, y, d, f)
	local t = ChooseStalactite()
	Occlusion.put(t[1], x, y, d, { flip = { f or false, t[3] } })
	Occlusion.put(t[2], x, y + 64, d, { flip = { f or false, t[3] } })
end

local function RandomStalagmite(x, y, d, f)
	local t = ChooseStalactite()
	Occlusion.put(t[1], x, y + 64, d, { flip = { f or false, not(t[3]) } })
	Occlusion.put(t[2], x, y, d, { flip = { f or false, not(t[3]) } })
end

local function Blackness(bb, z)
	local w = bb.r - bb.l
	local h = bb.t - bb.b
	Occlusion.put('f', bb.l, bb.b, z or -8, { size = { w, h } })
end

local function Sprite(frame)
	return eapi.NewSpriteList("image/occlusion.png", frame)
end

local function FilteredSprite(frame)
	return eapi.NewSpriteList({"image/occlusion.png", filter=true}, frame)
end

-- Exported names.
Occlusion = {
	dot = dot,
	put = put,
	column = column,
	passage = passage,
	tileset = tileset,
	gradient = gradient,
	boxFalloff = boxFalloff,
	whiteFalloff = whiteFalloff,
	cornerFalloff = cornerFalloff,
	entranceFalloff = entranceFalloff,
	RandomStalactite = RandomStalactite,
	RandomStalagmite = RandomStalagmite,
	FilteredSprite = FilteredSprite,
	Blackness = Blackness,
	Sprite = Sprite,
}
return Occlusion
