dofile("script/exit.lua")
dofile("script/GrayAreaRoomB.lua")

local computerScreen = {
	["swamp-map"]	= '1',
	["Waterfall"]	= '2',
	["Rocks"]	= '3',
	["Forest"]	= '4',
	["Industrial"]	= '5',
}

local navComputerPos = {x=75,y=40}
local ComputerScreen

local currentWorld = game.GetState().spaceShipLandedOn

local function NavigationComputer(pos)
	local tileID = computerScreen[currentWorld]
	local computerTile = eapi.NewTile(staticBody,
				  vector.Add(navComputerPos, {x=10,y=-20}),
				  {192, 80}, grayArea.ts[tileID], -1.45)
	eapi.SetAttributes(computerTile, { color = {r=1, g=1, b=1, a=0.7} })
	
	ComputerScreen = function()
		local tileID = computerScreen[currentWorld]
		eapi.SetSpriteList(computerTile, grayArea.ts[tileID])
	end
end

local function LispComputer(cx, cy)
   local anim = eapi.TextureToSpriteList("image/lisp-console.png", {192,80})
   local tile = eapi.NewTile(staticBody, {cx + 52, cy - 20}, nil, anim, -1.4)
   eapi.SetAttributes(tile, { color = {r=1, g=1, b=1, a=0.7} })	
   eapi.Animate(tile, eapi.ANIM_LOOP, 16)
end

local keyboardDimensions = {{0, 128}, {128, 64}}
local shipKeyboard = eapi.NewSpriteList("image/tiles.png", keyboardDimensions)

local function NavigationConsole(cx, cy)
   eapi.NewTile(staticBody, {cx + 32, cy + 30}, {128, 64}, shipKeyboard, -1.4)
   local platformSize = {{0, 256}, {128, 64}}
   local padTexture = eapi.NewSpriteList("image/tiles.png", platformSize)
   eapi.NewTile(staticBody, {cx + 32, cy}, nil, padTexture, -1.5)
end

local outsideScreen = {
	["swamp-map"]	= 'i',
	["Waterfall"]	= 'j',
	["Rocks"]	= 'k',
	["Forest"]	= 'l',
	["Industrial"]	= 'A',
}

local function PosterComputer(cx, cy)
	local tileID = outsideScreen[game.GetState().spaceShipLandedOn]
	local tile = eapi.NewTile(staticBody, {cx + 52, cy - 20},
				  nil, grayArea.ts[tileID], -0.1)
	eapi.SetAttributes(tile, { color = {r=1, g=1, b=1, a=0.7} })
end

PosterComputer(-330, 40)
NavigationComputer(navComputerPos)
NavigationConsole(105, -180)

-- Exits.
ExitRoom({l=-400, b=-180.00, r=-399, t=-80}, "EngineRoom", {350, -162},
 	 nil, nil, nil, eapi.SLIDE_LEFT)
ExitRoom({l=399, b=-180.00, r=400, t=-80}, "DeadEnd", {-350, -162},
 	 nil, nil, nil, eapi.SLIDE_RIGHT)

local worldCycle

if game.GetState().hasSterling then
	worldCycle = {
		["swamp-map"]	= "Waterfall",
		["Waterfall"]	= "Rocks",
		["Rocks"]	= "Forest",
		["Forest"]	= "Industrial",
		["Industrial"]	= "swamp-map",
	}
else
	worldCycle = {
		["swamp-map"]	= "Waterfall",
		["Waterfall"]	= "swamp-map",
	}
end

local function RunTravelCutscene()
	util.Message = "travel"
	game.GetState().playerHidden = true
	util.GoToAndPlace("EngineRoom", mainPC, {0, 0}, true)
end

local consoleActivator

local launcherImg = { 
	eapi.NewSpriteList("image/tiles.png", {{128, 128}, {32, 64}}),
	eapi.NewSpriteList("image/tiles.png", {{160, 128}, {32, 64}})
}

local launcherTile = nil
local function Launcher(i)
	if launcherTile then eapi.Destroy(launcherTile) end
	launcherTile = eapi.NewTile(staticBody, { x = -200, y = -175 },
				    nil, launcherImg[i], -0.1)
end
Launcher(2)

local function GetConsoleTxt()
	return txt.destinationTexts[currentWorld]
end

local function SwitchWorld()
	currentWorld = worldCycle[currentWorld]
	Launcher(game.GetState().spaceShipLandedOn == currentWorld and 2 or 1)
	eapi.PlaySound(gameWorld, "sound/click.ogg")
	ComputerScreen()

	consoleActivator.text = GetConsoleTxt()
	action.RemoveActivatorInfo(consoleActivator)
end

local travelInProgress = false
local function MaybeRunTravelCutscene()
	if not(currentWorld == game.GetState().spaceShipLandedOn) 
	and not(travelInProgress) then
		eapi.PlaySound(gameWorld, "sound/click.ogg")
		game.GetState().spaceShipLandedOn = currentWorld
		effects.Fade(0.0, 1.0, 1.0, RunTravelCutscene)
		travelInProgress = true
		mainPC.StopInput()
	else
		eapi.PlaySound(gameWorld, "sound/error.ogg")
	end
end

local function Launch()
	destroyer.Activate(MaybeRunTravelCutscene)
end

consoleActivator = action.MakeActivator({l=-180, b=-170, r=-170, t=-160},
					Launch, txt.launcher)

local function ChangeWorld()
	destroyer.Activate(SwitchWorld)
end

consoleActivator = action.MakeActivator({l=190, b=-176, r=210, t=-175},
					ChangeWorld, GetConsoleTxt())

action.MakeMessage(txt.monitor, {r=-170, b=10, l=-200, t=20}, txt.shipInfo)

local function NavigationTextSelector()
	return txt.navigationTexts[currentWorld]
end

action.MakeMessage(txt.navigationDisplay, {l=170, b=10, r=200, t=20},
		   NavigationTextSelector)

local targetImg = eapi.NewSpriteList("image/tiles.png", {{224, 0}, {8, 8}})

local function Target(pos)
	local tile = eapi.NewTile(staticBody, pos, nil, targetImg, -0.2)
	eapi.SetAttributes(tile, { color = { r = 1, g = 0, b = 0, a = 0.25 } })	
end

if game.GetState().startLives == 1 then
	-- no traveling hints in hard mode
elseif not(game.GetState().hasSterling) then
	Target({x=202,y=78})
elseif not(game.GetState().toolbox) then	
	Target({x=171,y=47})
else
	Target({x=106,y=31})
end
