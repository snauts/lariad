dofile("script/action.lua")
dofile("script/occlusion.lua")
dofile("script/shape.lua")
dofile("script/exit.lua")
dofile("script/Common.lua")

LoadPlayers()
camera = util.CreateCamera(gameWorld)
eapi.SetBackgroundColor(gameWorld, {r=0.0,g=0.0,b=0.0})

local tileMap = {
   "CCKCC",
   "CCKCC",
   "CCKCC",
}

local tileset = util.TextureToTileset("image/swamp.png", util.map8x8, {64,64})

staticBody = eapi.GetStaticBody(gameWorld)
util.CreateTiles(staticBody, tileMap,  tileset, {x=-160,y=-144}, nil, -1)
util.CreateTiles(staticBody, {"DDDDDDD"}, tileset, {x=-224,y=-144}, nil, 1)

for i = 0,2,1 do
   util.PutTile(staticBody, 'w', tileset, { 128, -140 + (i * 64)}, 0.9)
   util.PutTile(staticBody, 'w', tileset, {-192, -140 + (i * 64)}, 0.9)
end

for i = -2,1,1 do
   util.PutTile(staticBody, 'L', tileset, { (i * 64), 30}, 0.9)
end

util.PutTile(staticBody, 'F', tileset, { -192, 30}, 0.9)
util.PutTile(staticBody, 'E', tileset, { 128, 30}, 0.9)

-- Create ground, ceiling, wall shapes.
eapi.NewShape(staticBody, nil, {l=-200,r=200,b=-100,t=-84}, "Box")
eapi.NewShape(staticBody, nil, {l=-200,r=200,b=50,t=70}, "Box")
eapi.NewShape(staticBody, nil, {l=-180,r=-150,b=-90,t=50}, "Box")
eapi.NewShape(staticBody, nil, {l=150,r=180,b=-90,t=50}, "Box")

local treeTexture = {"image/trees.png", filter=true}
swampBGSprite = eapi.NewSpriteList(treeTexture, {{0,412},{100,100}})
eapi.NewTile(staticBody, { -100, -140 }, { 200, 200 }, swampBGSprite, -2)

for i = 0,3,1 do
   eapi.NewTile(staticBody, { 125, -102 + (i * 32) }, { 32, 32 },
		Occlusion.tileset['a'], -0.99)
   eapi.NewTile(staticBody, { -157, -102 + (i * 32) }, { 32, 32 },
		Occlusion.tileset['b'], -0.99)
end

for i = 1,3,1 do	
   eapi.NewTile(staticBody, { 125 - (i * 32), 26 }, { 32, 32 },
		Occlusion.tileset['c'], -0.99)
   eapi.NewTile(staticBody, { -157 + (i * 32), 26 }, { 32, 32 },
		Occlusion.tileset['c'], -0.99)
end

eapi.NewTile(staticBody, {  125, 26 }, { 32, 32 }, Occlusion.tileset['d'], -0.9)
eapi.NewTile(staticBody, { -157, 26 }, { 32, 32 }, Occlusion.tileset['e'], -0.9)

eapi.NewTile(staticBody, {  160, -144 }, { 64, 64 }, Occlusion.tileset['a'], 2)
eapi.NewTile(staticBody, { -224, -144 }, { 64, 64 }, Occlusion.tileset['b'], 2)

util.PutTile(staticBody, 'f', tileset, {   0, -120 }, -1.5)
util.PutTile(staticBody, 'f', tileset, { -35, -125 }, -1.5)
util.PutTile(staticBody, 'f', tileset, { -70, -115 }, -1.5)

local tile = util.PutTile(staticBody, 'M', tileset, { 61, -90 }, -0.9)
eapi.SetAttributes(tile, { flip = { true, false } })
effects.Smoke({ x=93, y=-28},
	      { vel = { x = 0, y = 50 },
		life = 1.5,
		interval = 0.05,
		variation = 50,
		z = -0.92})

util.PutTile(staticBody, 'N', tileset, { 50, -10 }, -0.95)
util.PutTile(staticBody, 'N', tileset, { 30, -15 }, -0.95)
util.PutTile(staticBody, 'N', tileset, { 80, -20 }, -0.95)


local bedSize = { { 1, 321 }, { 126, 62 } }
local bedPos = { x = -140, y = -97 }
local bed = eapi.NewSpriteList({ "image/swamp.png", filter = true }, bedSize)
local tile = eapi.NewTile(staticBody, bedPos, { x = 140, y = 64 }, bed, 0.5)
eapi.SetAttributes(tile, { flip = { true, false } })

action.MakeMessage(txt.cauldron, {l=85, b=-70, r=95, t=-60}, 
		   txt.cauldronInfo)

ExitRoom({l=-5,r=5,b=-78,t=-70}, "swamp-map", {155,12}, 
	 nil, true, txt.swamp, eapi.ZOOM_IN)
proximity.Tutorial({l=-5,r=150,b=-78,t=-70}, 3)

eapi.PlaySound(gameWorld, "sound/frogs.ogg", -1, 0.1)
