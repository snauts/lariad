dofile("script/exit.lua")
dofile("script/occlusion.lua")
dofile("script/Slabs.lua")
dofile("script/action.lua")
dofile("script/spider.lua")
dofile("script/Teleporter.lua")
dofile("script/Acid.lua")
dofile("script/Common.lua")
dofile("script/save-point.lua")
dofile("script/spider-boss.lua")
dofile("script/Arrows.lua")

LoadPlayers()
local levelDimensions = { l = -10000, r = 10000, b = -10000, t = 10000 }
camera = util.CreateCamera(gameWorld, mainPC, levelDimensions)
eapi.SetBackgroundColor(gameWorld, {r = 0, g = 0, b = 0})

eapi.RandomSeed(42)
staticBody = eapi.GetStaticBody(gameWorld)

local epsilon = 0.00001

local flipBackground = false
local disableLowerSlab = false
local disableUpperSlab = false
local tunnelDepth = -1.0

local function WithTunnelDepth(depth, fn)
	tunnelDepth = depth
	fn()
	tunnelDepth = -1.0
end

local function WithoutLowerSlab(fn)
	disableLowerSlab = true
	fn()
	disableLowerSlab = false
end

local function WithoutUpperSlab(fn)
	disableUpperSlab = true
	fn()
	disableUpperSlab = false
end

local function WithFlippedBackground(fn)
	flipBackground = true
	fn()
	flipBackground = false
end

local function BrickBackground(x, y, height, flip)
	if flipBackground then flip = 1 - flip end
	for i = 1, math.floor(height / 56) + 4, 1 do
		local q = (i + flip) % 2
		local d = -5.0 - util.Random()
		slab.Small(x + 64 * q, y + i * 56 , d, slab.darker, 0)
		slab.Small(x + 125 + 64 * q, y + i * 56, d, slab.darker, 0)
	end
end

local Jump = action.WaypointFunction("jump")
local MidJump = action.WaypointFunction("mid-jump")
local BackJump = action.WaypointFunction("jump-back")
local LongJump = action.WaypointFunction("long-jump")

local function TunnelElement(x, y, d, flip, height)
	if not(height) then height = 256 end
	if not(flip) then flip = 0 end
	local boolFlip = (flip == 0)

	Jump({ x = x + (boolFlip and 256 or 0), y = y + 132})
	BackJump({ x = x + (boolFlip and 256 or 0), y = y + 72})

	Jump({ x = x + 128, y = y + 188})
	BackJump({ x = x + 128, y = y + 138})

	slab.Big(x, y, d, nil, nil, 'g', boolFlip, true)
	slab.Small(x + (128 * flip), y + 116, d + epsilon)

	slab.Big(x, y + 128 + height, d - epsilon,
		 nil, nil, 'g', not(boolFlip), false)
	slab.Small(x + (128 * (1 - flip)), y + height + 76, d - epsilon)

	BrickBackground(x, y, height, flip)

	if not(disableLowerSlab) then 
		slab.Big(x, y - 112, d - epsilon, nil, nil, 'd', boolFlip,true)
	end	
	if not(disableUpperSlab) then
		slab.Big(x, y + 240 + height, d, nil, nil,
			 'd', not(boolFlip), false, 128)
	end
end

local function FlatElement(x, y, d, flip, height)
	if not(height) then height = 200 end
	if not(flip) then flip = 0 end

	slab.Big(x, y, d)
	slab.Big(x, y + 128 + height, d)

	BrickBackground(x, y, height, flip)

	if not(disableLowerSlab) then 
		slab.Big(x, y - 112, d - epsilon, nil, nil, 'c', false, true)
	end
	if not(disableUpperSlab) then
		slab.Big(x, y + 240 + height, d + epsilon,
			 nil, nil, 'c', false, false, 128)
	end
end

local function PyramidPotLamp(x, y)
	slab.PotLamp(x, y, -0.1)
	slab.Small(x - 16, y - 28, -0.11,
		   { size = {64, 32}, color = { r=0.8, g=0.7, b=0.6 } }, 0)
end

local function DiagonalTunnel(x, y, n, flip, height)
	if n > 0 then
		if not(flip) then flip = 0 end
		local yOffset = -112 * (2 * flip - 1)
		TunnelElement(x, y, tunnelDepth, flip, height)
		if n % 2 == 0 then PyramidPotLamp(x + 110, y + 240) end
		DiagonalTunnel(x - 250, y + yOffset, n - 1, flip, height)
	end
end

local function FlatTunnel(x, y, n, flip, height, lamp)
	if n > 0 then
		if n % 2 == 0 and lamp then 
			slab.Lamp(x + 100, y + 118, -0.1)
		end
		FlatElement(x, y, tunnelDepth, flip, height)
		FlatTunnel(x - 250, y, n - 1, flip, height, lamp)
	end
end

local function VerticalWall(x, y, d, tile, height)
	if height > 0 then		
		slab.Big(x, y, d, nil, nil, tile, false, true)
		VerticalWall(x, y - 112, d - epsilon, tile, height - 1)
	end
end

local function StepSlab(x, y, d)
	if not(d) then d = -0.5 end
	slab.Small(x, y, d, { size = {64, 32} }, 0)
	shape.Line({x + 16, y + 32}, {x + 48, y + 32}, "OneWayGround")
end

local function KingChamber()
	WithoutUpperSlab(
		function()
			FlatTunnel(-250 * 27,  56 * 23, 1, 1)
			FlatTunnel(-250 * 30,  56 * 23, 1, 1)
		end)

	BrickBackground(-250 * 27, 56 * 27, 200, 1)
	VerticalWall(-250 * 27, 56 * 33, -1.5, nil, 2)
	FlatTunnel(-250 * 28,  56 * 23, 2, 1, 312)
	VerticalWall(-250 * 30, 56 * 33, -1.5, nil, 2)
	FlatTunnel(-250 * 31,  56 * 23, 3, 1, 400)
	VerticalWall(-250 * 34, 56 * 35, -1.5, 'b', 8)
	BrickBackground(-250 * 34, 56 * 23, 300, 1)
	Occlusion.put('e', -250 * 34,  56 * 21, -0.5, 
		      { size={256, 118}, flip={false, true} })
end

local function ActivatePyramidTeleporter()
	local function MaybeFix()
		if game.GetState().toolbox then		
			game.GetState().teleporterFixed = true
			util.GameMessage(txt.teleporterFix, camera,
					 ActivatePyramidTeleporter)	
		else
			mainPC.StartInput()
		end
	end
	
	if game.GetState().teleporterFixed then
		teleporter.Use("Mine2", {6358, 489}, true)
	else
		mainPC.StopInput()
		util.GameMessage(txt.teleporterInfo, camera)		
		util.GameMessage(txt.teleporterBad, camera, MaybeFix)	
	end
end

local function QueenChamber()
	WithoutUpperSlab(function() FlatTunnel(-250 * 27,  56 * 1, 1, 1) end)
	VerticalWall(-250 * 27, 56 * 11, -1.5, nil, 2)
	FlatTunnel(-250 * 28,  56 * 1, 2, 1, 312)
	VerticalWall(-250 * 30, 56 * 9, -1.5, 'b', 6)
	BrickBackground(-250 * 30, 56 * 1, 200, 1)
	Occlusion.put('e', -250 * 30,  -56 * 1, -0.5, 
		      { size={256, 118}, flip={false, true} })
	
	teleporter.Put(-7175, 160, ActivatePyramidTeleporter, true, true)
end

local function SmallSlabStack(x, y, height) 
	if height > 0 then
		slab.Small(x, y, -1.0)		
		SmallSlabStack(x, y + 56, height - 1) 
	end
end

local function ThePit()
	local function ToThePit() DiagonalTunnel(-250 * 27, -56 * 49, 1, 1) end
	slab.WithShadingOffset(3.0, function () WithoutLowerSlab(ToThePit) end)
	WithTunnelDepth(
		1.2, function() FlatTunnel(-250 * 28, -56 * 57, 6, 1, 648) end)
	slab.Fix(-250 * 27, -56 * 49, 1.3)
	VerticalWall(-250 * 27, -56 * 51, 1.2, 'a', 5)
	Occlusion.put('e', -250 * 27, -56 * 59, -0.5, 
		      { size={256, 118}, flip={true, true} })
	VerticalWall(-250 * 34, -56 * 43, 1.2, 'b', 9)
	Occlusion.put('e', -250 * 34, -56 * 59, -0.5, 
		      { size={256, 118}, flip={false, true} })
	BrickBackground(-250 * 34, -56 * 59, 600, 1)
	VerticalWall(-250 * 33, -56 * 53 + 32, -1.5, nil, 2)
	for i = -1, 3, 1 do
		local h = 4 + i
		if h == 3 then h = 4 end
		SmallSlabStack(-250 * 30.4 + (i * 230) - 64, -56 * 55 + 16, h)
	end
	common.AcidPool({ l = -8300, r = -6720, b = -3108, t = -2868 })
end

eapi.Collide(gameWorld, "Player", "PondBottom",
	     destroyer.Player_vs_PondBottom, 10)

local function Tunnels() 
	FlatTunnel(-250, 0, 1)
	DiagonalTunnel(-250 * 2, -56, 5, 1)
 	WithoutLowerSlab(function() DiagonalTunnel(-250*7, -56*11, 1, 1) end)
	VerticalWall(-250 * 7, -56 * 13, -1.5, 'a', 4)
	slab.Big(-250 * 7, -56 * 21, -1.6, nil, nil, 'd', false, true)
	FlatTunnel(-250 * 8, -56 * 19, 1, 1, 592)
	BrickBackground(-250 * 9, -56 * 19, 600, 1)
	for i = 16.5, 10.5, -1.5 do StepSlab(-250 * 7.6, -56 * i) end

	local function Shaft(x, id, flip)
		local function top() FlatTunnel(x,  56 * 1, 1, 0) end
		local function low() FlatTunnel(x, -56 * 31, 1, 0) end
		WithoutLowerSlab(function() WithTunnelDepth(-0.9, top) end)
		WithoutUpperSlab(function() WithTunnelDepth(-1.6, low) end)

		VerticalWall(x, -56 * 3, -1.5, id, 10)
		slab.Big(x, -56 * 1, -1.0, nil, nil, 'g', flip, true)
		slab.Big(x, -56 * 23, -1.6, nil, nil, 'g', flip, false, 128)
	end

	function InvertedBackground()
		WithoutLowerSlab(
			function() DiagonalTunnel(-250 * 9, -56 * 11, 1) end)

		WithoutUpperSlab(
			function() DiagonalTunnel(-250 * 9, -56 * 20, 1, 1) end)
		
		DiagonalTunnel(-250 * 10, -56 * 9, 5)
		DiagonalTunnel(-250 * 10, -56 * 22, 5, 1)
		
		Shaft(-250 * 16, 'a', false)
		Shaft(-250 * 18, 'b', true)
		
		BrickBackground(-250 * 18, -56 * 24, 1200, 1)
		StepSlab(-250 * 16 - 48, 2.6 * 56 + 1, -3.0)
		StepSlab(-250 * 17 - 16, 2.6 * 56 + 1, -3.0)
	end
	WithFlippedBackground(InvertedBackground)

	FlatTunnel(-250 * 17, -56 * 31, 1, 1, 1992)
	FlatTunnel(-250 * 15,  56 * 1, 1, 1)
	FlatTunnel(-250 * 15, -56 * 31, 1, 1)

	slab.Lamp(-4330, -1618, -0.1)
	slab.Lamp(-3980, -1618, -0.1)

	PyramidPotLamp(-4330, 240, -0.1)
	PyramidPotLamp(-3950, 240, -0.1)

	-- to queen
	WithoutUpperSlab(
		function()
			FlatTunnel(-250 * 19,  56 * 1, 1, 1, 312)
			FlatTunnel(-250 * 21,  56 * 1, 1, 1)
		end)

	VerticalWall(-250 * 19, 56 * 19 - 8, -1.5, 'a', 5)
	FlatTunnel(-250 * 22,  56 * 1, 5, 1, nil, true)
	FlatTunnel(-250 * 20,  56 * 1, 1, 1, 984)
	slab.Big(-250 * 19, 56 * 21 - 8, -1.4, nil, nil, 'd', false, false, 128)
	slab.Big(-250 * 21, 56 * 9, -1.5, nil, nil, 'g', true, false, 128)
	Occlusion.put('g', -250 * 19,  56 * 9, -0.5, 
		      { size={256, 118}, flip={false, false} })

	-- to king
	flipBackground = true
	WithoutLowerSlab(
		function() DiagonalTunnel(-250 * 21, 56 * 11, 1, 0, 512) end)

	DiagonalTunnel(-250 * 22, 56 * 13, 5, 0, 512)
	flipBackground = false
	BrickBackground(-250 * 21, 56 * 7, 200, 1)
	for i = 11.5, 3, -1.5 do StepSlab(-250 * 19.6, 56 * i) end

	-- to pit
	DiagonalTunnel(-250 * 19, -56 * 33, 7, 1)
	DiagonalTunnel(-250 * 26, -56 * 47, 1, 1)
end

local function Ambush(pos)
	local dead = 20
	local spiders = 20
	local volume = 0.05
	local activator
	local leftWall
	local rightWall
	if game.GetState().pyramidAmbush then return end

	local function PlaySuspense()
		if dead <= 0 then return end
		eapi.PlaySound(gameWorld, "sound/suspense.ogg", 0, volume)
		eapi.AddTimer(staticBody, 0.5, PlaySuspense)
	end
	local function EndAmbush()
		game.GetState().pyramidAmbush = true
		slab.CrumbleWall(leftWall)
		slab.CrumbleWall(rightWall)
	end

	local function EmitSpider()
		local jumper
		volume = 1.0
		if spiders > 0 then
			local xvary = 10 + 150 * util.Random()
			local place = { x = pos.x + xvary, y = pos.y + 512 }
			jumper = spider.Put(place, nil, "jumper")
			jumper.MaybeActivate()
			local OldOnDeath = jumper.OnDeath
			jumper.OnDeath = function(actor)
				OldOnDeath(actor)
				dead = dead - 1
				if dead > 0 then return end
				eapi.AddTimer(staticBody, 2, EndAmbush)
			end
			local delay = 0.2 + util.Random()
			eapi.AddTimer(staticBody, delay, EmitSpider)
			spiders = spiders - 1
		end
	end

	local function Trigger2()
		action.DeleteActivator(activator)
		rightWall = slab.FallWall(vector.Offset(pos, 600, 208))
		eapi.AddTimer(staticBody, 3, EmitSpider)
		volume = 0.2
	end

	local function Trigger1()
		local x = pos.x + 500
		action.DeleteActivator(activator)
		leftWall = slab.FallWall(vector.Offset(pos, -216, 208))
		activator = action.MakeActivator(
			{ l = x, r = x + 16, b = pos.y, t = pos.y + 256 },
			Trigger2, nil, staticBody, true)
		PlaySuspense()
	end

	activator = action.MakeActivator(
		{ l = pos.x, r = pos.x + 16, b = pos.y, t = pos.y + 256 },
		Trigger1, nil, staticBody, true)
	
end

local blockingWall = nil
local function TeleporterFallWall(pos) 
	local activator

	local function WallDown()
		action.DeleteActivator(activator)
		if not(game.GetState().bigSpiderDead) then
			local wallPos = vector.Offset(pos, -216, 208)
			blockingWall = slab.FallWall(wallPos)
		end
	end

	local bb = { l = pos.x, r = pos.x + 16, b = pos.y, t = pos.y + 256 }
	activator = action.MakeActivator(bb, WallDown, nil, staticBody, true)	
end

local bigWeb = eapi.NewSpriteList("image/big-web.png", {{0, 0}, {800, 480}})
local function SpiderBoss(pos)
	local wall
	local tile = eapi.NewTile(staticBody, pos, nil, bigWeb, -4.5)
	eapi.SetAttributes(tile, { color = { r = 1, g = 1, b = 1, a = 0.25 } })	
	local pos2 = vector.Offset(pos, 2, -8)
	local tile = eapi.NewTile(staticBody, pos2, nil, bigWeb, -4.6)
	eapi.SetAttributes(tile, { color = { r = 0, g = 0, b = 0, a = 0.9 } })	

	local function Die()
		slab.CrumbleWall(wall)
		game.GetState().bigSpiderDead = true
		if blockingWall then
			slab.CrumbleWall(blockingWall)
		end
	end
	local function Kick()
		wall = slab.FallWall(vector.Offset(pos, 850, 256))
	end
	if not(game.GetState().bigSpiderDead) then	
		spiderBoss.Put(vector.Offset(pos, 10, 240), Die, Kick)
	end
end

local function Occlude(bb, tile, z)
	Occlusion.put(tile or 'b', bb.l, bb.b, z or -1, 
		      { size = { bb.r - bb.l, bb.t - bb.b } })
end

if util.msg == "FromCrypt" then
	util.msg = nil
else
	Tunnels()
	KingChamber()
	QueenChamber()
	ThePit()

	TeleporterFallWall({ x = -5005, y = 170 })

	Occlusion.put('a', -256, -2 * 56, 5.0, { size={ 256, 12 * 56 } })
	Occlusion.put('f', 0, -2 * 56, 5.0, { size={ 128, 12 * 56 } })

	ExitRoom({ l=0, b=0, r=1, t=256 }, "Rocks", {-10330, 2443},
		 nil, nil, nil, eapi.SLIDE_RIGHT)

	local exports = {
		AcidBarrel = {func=common.BackgroundAcidBarrel,points=1},
		Occlude = {func=Occlude,points=2},
		Arrow = {func=arrows.Put,points=2},
		Spider = {func=spider.Put,points=1},
		BackJump = {func=BackJump,points=1},
		LongJump = {func=LongJump,points=1},
		MidJump = {func=MidJump,points=1},
		Jump = {func=Jump,points=1},
		Acid = {func=Acid.Put,points=1},
		AcidVapor = {func=common.AcidVapor,points=1},
		SavePoint = {func=savePoint.Put,points=1},
		MedKit3 = {func=savePoint.Medkit3,points=1},
		HealthPlus = {func=destroyer.HealthPlus(3),points=1},
		Ambush = {func=Ambush,points=1,hide=true},
		SpiderBoss = {func=SpiderBoss,points=1},
		Kicker = {func=action.MakeKicker,points=2},
		RibCage = {func=common.RibCage,points=1},
		Skull = {func=common.Skull,points=1},
		Web1 = {func=slab.Web1,points=2},
		Web2 = {func=slab.Web2,points=2},
		Web3 = {func=slab.Web3,points=2},
	}
	editor.Parse("script/Pyramid-edit.lua", gameWorld, exports)
	
	teleporter.Arrive()

	util.PreloadSound({ "sound/slash.ogg",
			    "sound/gears.ogg",
			    "sound/chshsh.ogg",
			    "sound/suspense.ogg",
			    "sound/drip.ogg",
			    "sound/brick.ogg",
			    "sound/plop.ogg",
			    "sound/spit.ogg",
			    "sound/hit.ogg" })

	if game.GetState().startLives > 1 then	
		savePoint.Put({x=-5972,y=1136})
	end
end

ambient = eapi.PlaySound(gameWorld, "sound/creepy.ogg", -1, 0.9)

pyramid = {
	DiagonalTunnel = DiagonalTunnel,
	FlatTunnel = FlatTunnel,
	PutSpider = PutSpider,
}
return pyramid
