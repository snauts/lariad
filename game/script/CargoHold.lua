
dofile("script/GrayAreaRoomA.lua")
dofile("script/exit.lua")
dofile("script/save-point.lua")

local bigCrateDimensions = {{0, 384}, {256, 128}}
local bigCrate = eapi.NewSpriteList("image/tiles.png", bigCrateDimensions)

local smallCrateDimensions = {{256, 384}, {128, 128}}
local smallCrate = eapi.NewSpriteList("image/tiles.png", smallCrateDimensions)

local function PutCargo(pos, depth, tint)
   tint = tint or 1.0
   local size = {x=256, y=128}
   local tile = eapi.NewTile(staticBody, pos, size, bigCrate, depth)
   eapi.SetAttributes(tile, { color = { r=tint, g=tint, b=tint } })
   pos = vector.Add(pos, {x=128,y=128})
   eapi.NewShape(staticBody, pos, {l=-75,r=75,b=-10,t=-5}, "OneWayGround")
end

local function PutSmall(pos, depth, tint)
   tint = tint or 1.0
   local size = {x=128, y=128}
   local tile = eapi.NewTile(staticBody, pos, size, smallCrate, depth)
   eapi.SetAttributes(tile, { color = { r=tint, g=tint, b=tint } })
   pos = vector.Add(pos, {x=64,y=128})
   eapi.NewShape(staticBody, pos, {l=-50,r=50,b=-10,t=-5}, "OneWayGround")
end

local function Boxes(x, y)
	PutCargo({x=x-330,y=y-176}, -1.4, 0.8)
	PutSmall({x=x-67,y=y-177}, -1.4, 0.9)
	PutCargo({x=x+70,y=y-176}, -1.4, 1.0)

	PutSmall({x=x-270,y=y-66}, -1.5, 0.6)
	PutCargo({x=x-130,y=y-66}, -1.5, 0.7)
	PutSmall({x=x+140,y=y-66}, -1.5, 0.8)

	PutCargo({x=x-290,y=y+44}, -1.6, 0.4)
	PutCargo({x=x-20,y=y+44}, -1.6, 0.5)

	action.MakeMessage(txt.cargo, {l=x-230, b=y+100, r=x-220, t=y+110},
			   txt.cargoInfo)

	local skull = eapi.NewSpriteList("image/tiles.png", {{96,0},{64,64}})
	local tile = eapi.NewTile(staticBody, {x-260,y+60}, nil, skull, -1.55)
	eapi.SetAttributes(tile, { color = { r=1, g=1, b=1, a=0.4 } })
end

Boxes(10, -10)

-- Exits.
-- Exits.
local exitPosition = {
	["swamp-map"]	= {20429, 165},
	["Waterfall"]	= {-550, 83},
	["Rocks"]	= {9408, 161},
	["Forest"]	= {5972, 1383},
	["Industrial"]	= {7437, 161},
}

ExitRoom({l=-400, b=-180.00, r=-399, t=-80},
	 game.GetState().spaceShipLandedOn,
	 exitPosition[game.GetState().spaceShipLandedOn],
	 nil, nil, nil, eapi.SLIDE_LEFT)

ExitRoom({l=399, b=-180.00, r=400, t=-80}, "EngineRoom", {-350, -162},
 	 nil, nil, nil, eapi.SLIDE_RIGHT)

local exports = {
	SavePoint = {func=savePoint.Put,points=1},
	MedKit2 = {func=savePoint.Medkit2,points=1},
}
editor.Parse("script/CargoHold-edit.lua", gameWorld, exports)
