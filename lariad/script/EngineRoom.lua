dofile("script/GrayAreaRoomA.lua")
dofile("script/exit.lua")

local engSp = eapi.NewSpriteList("image/engine.png", {{0, 0}, {512, 384}})
eapi.NewTile(staticBody, {-256, -180}, {512, 386}, engSp, -1.5)

local lightTileset = eapi.TextureToSpriteList("image/engine-lights.png",{16,64})

lightIndex = 0
lightSpeed = 0.05
lightDirection = -1

local lights = {}

function LightTimer()
	local lightsDone = 1
	local indexUpdate = 0

	for i, light in ipairs(lights) do
		if grayArea.holdLeds then
			lightsDone = 0
			if light.progress >= 0.5 then
				light.progress = light.progress - lightSpeed
			else
				light.progress = light.progress + lightSpeed
			end
			eapi.SetAnimPos(light.tile, light.progress)
		elseif light.progress <= 1.0 then 
			lightsDone = 0
			eapi.SetAnimPos(light.tile, light.progress)
			if lightIndex == light.num or light.progress > 0.0 then
				light.progress = light.progress + lightSpeed
				indexUpdate = 1
			end
		else
			eapi.SetAnimPos(light.tile, 0.0)
		end
	end

	if indexUpdate and lightDirection == -1 then
		lightIndex = lightIndex + 1;
	else
		lightIndex = lightIndex - 1;
	end

	local time = lightSpeed;
	if lightsDone == 1 then
		for i, light in ipairs(lights) do light.progress = 0.0 end      
		lightDirection = -lightDirection
		time = 1.0
	end
	eapi.AddTimer(gameWorld, time, LightTimer, lights)
end

eapi.AddTimer(gameWorld, 0.5, LightTimer, lights)

lightNum = 0
local function PutLight(pos)
	local light = {}
	light.progress = 0.0
	light.num = lightNum
	light.tile = eapi.NewTile(staticBody, pos, nil, lightTileset, -1.0)
	eapi.SetAnimPos(light.tile, 0)
	table.insert(lights, light)
	lightNum = lightNum + 1
end

for x = -128, 128, 24 do 
	PutLight({x, -20})
end

local generatorSound = eapi.PlaySound(gameWorld, "sound/generator.ogg", -1, 0)
local coreBody = eapi.NewBody(gameWorld, { x = 0, y = -100 })
eapi.BindVolume(generatorSound, coreBody, mainPC.body, 100, 350)

action.MakeMessage(txt.core, {l=-20, b=-180, r=20, t=-160}, txt.coreInfo)

-- Exits.
ExitRoom({l=-400, b=-180.00, r=-399, t=-80}, "CargoHold", {350, -162},
	 nil, nil, nil, eapi.SLIDE_LEFT)
ExitRoom({l=399, b=-180.00, r=400, t=-80}, "CommandBridge", {-350, -162},
	 nil, nil, nil, eapi.SLIDE_RIGHT)


-- Testing
local speedup = 0.5
local is_shake = false
local amplitude = 0
local max_amplitude = 10
local originalPos = eapi.GetPos(camera.ptr) -- in EngineRoom camera is static

local function Shaking()
	if is_shake or math.abs(amplitude) > (speedup - 0.001) then 
		local amount = (amplitude + amplitude * util.Random()) / 2
		eapi.SetPos(camera.ptr, vector.Add(originalPos, {x=0, y=amount}))
		eapi.AddTimer(gameWorld, 0.1, Shaking) 
	else
		eapi.SetPos(camera.ptr, originalPos)
		grayArea.holdLeds = false
		grayArea.fadeLeds()
	end
	if amplitude > 0 then 
		if is_shake then
			amplitude = math.min(amplitude + speedup, max_amplitude)
		else 
			amplitude = amplitude - speedup
		end
	end
	amplitude = -amplitude
end

local function ShakeInProgress()
	return is_shake or amplitude > 0
end

local function StartShake()
	if not(ShakeInProgress()) then
		amplitude = 1
		is_shake = true
		grayArea.holdLeds = true
		eapi.AddTimer(gameWorld, 1.0, Shaking)
	end
end

local function StopShake()
	if ShakeInProgress() then
		is_shake = false
	end
end

local function TravelMessage(tile)
	local function GoBackToPlayer()
		game.GetState().playerHidden = false
		game.GetState().longTravelCutscene = false
		util.GoToAndPlace("DeadEnd", mainPC, {-300, -162}, true)
	end
	local function FinalFade()
		effects.Fade(0.0, 1.0, 1.0, GoBackToPlayer, tile)
		fadeVolume = true
	end
	local function StopTraveling()
		eapi.AddTimer(staticBody, 8.0, FinalFade)
		StopShake()
	end
	local function AfterTravelMessage()
		effects.Fade(1.0, 0.0, 4.0, StopTraveling, tile)
	end
	local AfterMessageCallback = AfterTravelMessage
	if not(game.GetState().longTravelCutscene) then
		AfterMessageCallback = GoBackToPlayer
	end
	util.GameMessage(txt.travelMessage, camera, AfterMessageCallback)
	eapi.AddTimer(staticBody, 3.0, util.MessageDone)
end

local function TravelCutscene()
	if not(game.GetState().longTravelCutscene) then
		effects.Fade(1.0, 1.0, 0, TravelMessage)
	elseif not(ShakeInProgress()) then
		StartShake()
		effects.Fade(-1.0, 1.001, 8.0, TravelMessage)
	end
end

if util.Message == "travel" then
	TravelCutscene()
	util.Message = nil
end

