dofile("script/GrayAreaRoomB.lua")
dofile("script/exit.lua")

local computerScreen = {
	["swamp-map"]	= 'i',
	["Waterfall"]	= 'j',
	["Rocks"]	= 'k',
	["Forest"]	= 'l',
	["Industrial"]	= 'A',
}

local function PosterComputer(cx, cy)
	local tileID = computerScreen[game.GetState().spaceShipLandedOn]
	local tile = eapi.NewTile(staticBody, {cx + 52, cy - 20},
				  nil, grayArea.ts[tileID], -0.1)
	eapi.SetAttributes(tile, { color = {r=1, g=1, b=1, a=0.7} })
end

local function TapeComputer(cx, cy)
	local ts = util.TextureToTileset("image/tape-deck.png", { "1" },
					 { 192, 80 })
	local tile = eapi.NewTile(staticBody, {cx + 10, cy - 20},
				  {192,80}, ts['1'], -1.45)
	eapi.SetAttributes(tile, { color = {r=1, g=1, b=1, a=0.7} })		

	-- Two tiles with a rotating tape animation.
	local anim = eapi.TextureToSpriteList("image/tape-reel.png", {64,64})
	local tile = eapi.NewTile(staticBody, {cx + 28 + 96, cy - 9},
				  nil, anim, -1.4)
	eapi.Animate(tile, eapi.ANIM_LOOP, 16)
	tile = eapi.NewTile(staticBody, {cx + 28, cy - 9}, nil, anim, -1.4)
	eapi.Animate(tile, eapi.ANIM_LOOP, 16)
end

PosterComputer(-330, 40)
TapeComputer(75, 40)

-- Exits.
local exitPosition = {
	["swamp-map"]	= {20429, 165},
	["Waterfall"]	= {-550, 83},
	["Rocks"]	= {9408, 161},
	["Forest"]	= {5972, 1383},
	["Industrial"]	= {7437, 161},
}

action.MakeMessage(txt.monitor, {r=-170, b=10, l=-200, t=20}, txt.shipInfo)

action.MakeMessage(txt.backup, {l=170, b=10, r=200, t=20}, txt.backupMsg)

ExitRoom({l=-400, b=-180.00, r=-399, t=-80},
	 game.GetState().spaceShipLandedOn,
	 exitPosition[game.GetState().spaceShipLandedOn],
	 nil, nil, nil, eapi.SLIDE_LEFT)

ExitRoom({l=399, b=-180.00, r=400, t=-80},
	 "EngineRoom", {-350, -162},
	 nil, nil, nil, eapi.SLIDE_RIGHT)
