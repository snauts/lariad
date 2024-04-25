dofile("script/action.lua")

LoadPlayers()
camera = util.CreateCamera(gameWorld)
eapi.SetBackgroundColor(gameWorld, {r=0.0, g=0.0, b=0.0})

staticBody = eapi.GetStaticBody(gameWorld)

local tx = eapi.NewSpriteList("image/spaceship-bg.png", {{0, 0}, {800, 480}})
eapi.NewTile(staticBody, {x=-400,y=-240}, nil, tx, -2.1)

-- Load tileset.
local spriteMap = {
	"7_9ab{}AG",
	"[+]cd31C  ",
	"(-ITK    ",
	"LJitk)   "
}
local tileset = util.TextureToTileset("image/tiles.png", spriteMap, {32,32})

local holdLeds = false

-- Exported names.
grayArea = {
	holdLeds = holdLeds,
	tileset = tileset
}

dofile("script/leds.lua")

local c1 = eapi.PlaySound(gameWorld, "sound/computer1.ogg", -1, 0.01)
local c2 = eapi.PlaySound(gameWorld, "sound/computer2.ogg", -1, 0.01)

local function SetupVolumes()
	eapi.SetVolume(c1, 0.01 + 0.03 * util.Random())
	eapi.SetVolume(c2, 0.01 + 0.03 * util.Random())
	eapi.AddTimer(gameWorld, 0.5, SetupVolumes)
end

SetupVolumes()

return grayArea
