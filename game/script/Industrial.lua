dofile("script/exit.lua")
dofile("script/shape.lua")
dofile("script/action.lua")
dofile("script/occlusion.lua")
dofile("script/spaceship.lua")
dofile("script/Falling.lua")
dofile("script/save-point.lua")
dofile("script/Common.lua")
dofile("script/bat.lua")
dofile("script/buzzsaw.lua")
dofile("script/scrap-metal.lua")
dofile("script/bomber.lua")

LoadPlayers()
local camBox = {l=-10000,r=10000,b=-192,t=5000}
camera = util.CreateCamera(gameWorld, mainPC, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.058, g=0.117, b=0.250})

eapi.RandomSeed(1969)

staticBody = eapi.GetStaticBody(gameWorld)

local bg = { "image/industrial-bg.png", filter = true }

local function Sky(pos, depth)
	local sky = eapi.NewSpriteList(bg, {pos, {128,127}})
	local px = eapi.NewParallax(gameWorld, sky, {10000, 800}, 
				    {-5000, -100}, {0.05, 1}, depth)
	eapi.SetRepeatPattern(px, {true, false})
end
Sky({0, 1}, -100)
Sky({128, 1}, -16)
Sky({256, 1}, -25)
Sky({384, 1}, -35)

local tx = eapi.NewSpriteList({ "image/forest-bg.png" }, {{0,512},{512,512}})
local px = eapi.NewParallax(gameWorld, tx, nil, {0, 1650}, {0.1, 0.8}, -30)
eapi.SetRepeatPattern(px, { true, false })

local function Market()
	local hangar = eapi.NewSpriteList(bg, {{0, 256}, {256, 128}})
	local function Hangar(x, attr)
		local px = eapi.NewParallax(gameWorld, hangar, nil,
					    {x, 32}, {0.5, 1}, -20)
		eapi.SetRepeatPattern(px, {true, false}, {768, 0})
		eapi.SetAttributes(px, attr)
	end
	Hangar(512, { color={r=0.35, g=0.55, b=0.65} })
	Hangar(224, { color={r=0.40, g=0.60, b=0.70} })
	Hangar(0,   { color={r=0.30, g=0.50, b=0.60} })
end
Market()

local function Factories()
	local factory = eapi.NewSpriteList(bg, {{0, 128}, {384, 128}})
	local function Factory(x, attr)
		local px = eapi.NewParallax(gameWorld, factory, nil,
					    {x, 60}, {0.45, 1}, -27)
		eapi.SetRepeatPattern(px, {true, false}, {1024, 0})
		eapi.SetAttributes(px, attr)
	end
	Factory(-384, { color={r=0.60, g=0.65, b=0.70} })
	Factory(128, { color={r=0.60, g=0.65, b=0.70} })
end
Factories()

local function TallBuildings()
	local building = eapi.NewSpriteList(bg, {{384, 128}, {128, 256}})
	local function Building(pos, attr)
		local px = eapi.NewParallax(gameWorld, building, nil,
					    pos, {0.4, 1}, -30)
		eapi.SetRepeatPattern(px, {true, false}, {1024, 0})
		eapi.SetAttributes(px, attr)
	end
	Building({ -64, 50 }, { color={r=0.40, g=0.60, b=0.70} })
	Building({ 128, 50 }, { color={r=0.40, g=0.60, b=0.70} })
	Building({ 640, 50 }, { color={r=0.40, g=0.60, b=0.70} })
end
TallBuildings()

local function FillerBuildings()
	local building = eapi.NewSpriteList(bg, {{256, 256}, {128, 128}})
	local function Building(pos, scroll, depth, repeating, attr)
		local px = eapi.NewParallax(gameWorld, building, nil,
					    pos, {scroll, 1}, depth)
		eapi.SetRepeatPattern(px, {true, false}, {repeating, 0})
		eapi.SetAttributes(px, attr)
	end
	Building({ -196, -25 }, 0.5, -19, 896, {color={r=0.5,g=0.7,b=0.8}})
	Building({ 320, 75 }, 0.4, -29, 1024, {color={r=0.4,g=0.6,b=0.7}})
	Building({ 860, 75 }, 0.4, -29, 1024, {color={r=0.4,g=0.6,b=0.7}})
	Building({ -640, 25 }, 0.45, -28, 1280, {color={r=0.3,g=0.5,b=0.6}})
end
FillerBuildings()

local function Chimneys()
	local chimneys = eapi.NewSpriteList(bg, {{0, 385}, {512, 128}})
	local px = eapi.NewParallax(gameWorld, chimneys, nil,
				    {0, 140}, {0.3, 1}, -40)
	eapi.SetRepeatPattern(px, {true, false}, {0, 0})
	eapi.SetAttributes(px, {color={r=0.7,g=0.9,b=1.0}})
end
Chimneys()

local sheet = { }
sheet[1] = common.IndustrialImg({{0,0}, {64,128}})
sheet[2] = common.IndustrialImg({{64,0}, {64,128}})
sheet[3] = common.IndustrialImg({{128,0}, {64,128}})

local roof = { }
roof[1] = common.IndustrialImg({{192,0}, {64,64}})
roof[2] = common.IndustrialImg({{256,0}, {128,64}})
roof[3] = common.IndustrialImg({{384,0}, {64,64}})

local vbar = { }
vbar[0] = common.IndustrialImg({{0,128}, {16,128}})
vbar[1] = common.IndustrialImg({{16,128}, {16,128}})
vbar[2] = common.IndustrialImg({{32,128}, {16,128}})
vbar[3] = common.IndustrialImg({{48,128}, {16,128}})
local function Vbar()
	return vbar[util.Random(0, 3)]
end

local hbar = { }
hbar[0] = common.IndustrialImg({{64,128}, {64,16}})
hbar[1] = common.IndustrialImg({{64,144}, {64,16}})
hbar[2] = common.IndustrialImg({{64,160}, {64,16}})
hbar[3] = common.IndustrialImg({{64,176}, {64,16}})
local function Hbar()
	return hbar[util.Random(0, 3)]
end

local pavement = { }
pavement[0] = common.IndustrialImg({{192,64}, {64,64}})
pavement[1] = common.IndustrialImg({{256,64}, {64,64}})
pavement[2] = common.IndustrialImg({{320,64}, {64,64}})
pavement[3] = common.IndustrialImg({{384,64}, {64,64}})

local brick = { }
brick[0] = common.IndustrialImg({{0,256}, {256,128}})
brick[1] = common.IndustrialImg({{256,256}, {256,128}})

local chain = common.IndustrialImg({{0,448},{128,64}})
local hook = common.IndustrialImg({{128,448},{64,64}})

local hookImage = {
	image		= "image/industrial.png",
	spriteOffset	= { x = 128, y = 448 },
}
local function MetalCrumbleSound()
	local coin = (util.Random() > 0.5)
	local file = (coin and "sound/metal-bit1.ogg") or "sound/metal-bit2.ogg"
	eapi.PlaySound(gameWorld, file, 0, 0.5)	
end

local function SmallShed(pos)
	eapi.NewTile(staticBody, pos, nil, vbar[0], -3)	
	eapi.NewTile(staticBody, vector.Offset(pos, 12, 0), nil, sheet[1], -4)
	eapi.NewTile(staticBody, vector.Offset(pos, 72, 0), nil, vbar[0], -3)
	eapi.NewTile(staticBody, vector.Offset(pos, -20, 96), nil, roof[1], 3)	
	eapi.NewTile(staticBody, vector.Offset(pos, 44, 96), nil, roof[3], 3)
	local shape = { l = pos.x + 8, r = pos.x + 80,
			b = pos.y + 120, t = pos.y + 155 }
	eapi.NewShape(staticBody, nil, shape, "Box")
end

local function HealthDispenser(pos)
	SmallShed(pos)
	savePoint.Medkit2(vector.Offset(pos, 12, 24))
end

local function SavePointShed(pos)
	SmallShed(pos)
	savePoint.Put(vector.Offset(pos, 12, -16), -2.7, 16)
end

function PutHook(pos)
	falling.Put({ x = pos.x, y = pos.y, height = 192,
		      Crumble = util.WithDelay(0.1, MetalCrumbleSound),
		      sound = "sound/metal.ogg",
		      name = "hook",
		      restingSprite = hook,
		      dieImage = effects.ShatterImage(64, 192), })
end

local platform = { }
for i = 0, 7, 1 do
	platform[i] = common.IndustrialImg({ { i * 64, 384 }, { 64, 64 } })
end
platform[8] = common.IndustrialImg({ { 320, 192 }, { 64, 64 } })

local wayPoints = { action.WaypointFunction("left"),
		    action.WaypointFunction("right") }

local chainZ = -3
local function ChainDecorator(pos, width, offset)
	offset = offset or 63
	if (width > 0) then
		local xx = pos.x + 32
		repeat
			local yy = pos.y - 63
			if chainZ < 0 then 
				yy = yy + util.Random(12, 24)
			end
			eapi.NewTile(staticBody, {x=xx, y=yy}, nil, 
				     chain, chainZ)
			xx = xx + util.Random(64, 320)
			chainZ = -chainZ
		until xx > pos.x + width * 64 + 32
	end
end

local function PutEditorPlatform(bb, disableChains, railing)
	local function PlatformPiece(pos, n, i)
		local railingImg = platform[n + 4]
		if railing then
			railingImg = platform[railing[i] + 4]
		end
		eapi.NewTile(staticBody, pos, nil, platform[n], -2)
		eapi.NewTile(staticBody, pos, nil, railingImg, 2)
		return vector.Add(pos, { x = 64, y = 0 })
	end

	local function PutPlatform(pos, width)
		shape.Line(vector.Add(pos, { x = 32, y = 6 } ),
			   vector.Add(pos, { x = 64 * width + 160, y = 22 }),
			   "Box")
		if not(disableChains) then
			ChainDecorator(pos, width)
		end
		pos = PlatformPiece(pos, 0, 1)
		pos = PlatformPiece(pos, 1, 2)
		for i = 1, width, 1 do
			local num = (i > width / 2) and 2 or 1
			pos = PlatformPiece(pos, 2, i + 2)
		end
		PlatformPiece(pos, 3, width + 3)
end

	local pos = {x=bb.l, y=bb.t}
	PutPlatform(pos, math.floor((bb.r - bb.l) / 64), disableChains)
end

local lastPavement = 0
local function PickPavement()
	lastPavement = (lastPavement + util.Random(1, 3)) % 4
	return pavement[lastPavement]
end

local function PavementBlock(x, y, z, lightness)
	z = z or -2
	lightness = lightness or 0.5
	local variation = lightness - 0.05 + util.Random() * 0.04
	local color = { r = lightness, g = lightness, b = variation }
	local tile = eapi.NewTile(staticBody, { x, y }, nil, PickPavement(), z)
	eapi.SetAttributes(tile, { color = color })
end

local function PickBrick()
	return brick[util.Random(0, 1)]
end

local function Darken(tile)
	eapi.SetAttributes(tile, { color = {r=0.5, g=0.5, b=0.5} })
end

local function BrickRow(x, y, width)
	local offset = 170
	for i = 0, width - 1, 1 do
		Darken(eapi.NewTile(staticBody, {x + i * 192, y - offset },
				    nil, PickBrick(), -8.3))		
		offset = ((offset == 170) and 210) or 170
	end
end

local function PavementStripe(x, y, count, lightness, depth, bricksOff)
	local width = 64 * (count + 1)
	local boxShape = { l = x + 64, t = y, r = x + width, b = y - 32 }
	eapi.NewShape(staticBody, nil, boxShape, "Box")
	for i = 1, count, 1 do
		PavementBlock(x + i * 64, y - 38, depth, lightness)
	end
	Occlusion.put('f', x + 64, y - 256, -8.6, { size = { width, 256 } })
	if not(bricksOff) then
		BrickRow(x, y + 16, (count + 2) / 3)
	end
	return { x = x + count * 64, y = y } 
end

local function PavementWall(x, y, count, depth)
	depth = depth or -3
	local width = 64 * (count + 1)
	local boxShape = { l = x, b = y, r = x + 64, t = y + count * 9 + 16 }
	eapi.NewShape(staticBody, nil, boxShape, "Box")
	for i = 1, count, 1 do
		PavementBlock(x, y + i * 9, depth, 0.5)
		if i % 2 == 0 then
			PavementBlock(x + 32, y + i * 9, depth + 0.01, 0.4)
			PavementBlock(x + 96, y + i * 9, depth + 0.02, 0.2)
		end
		if i % 2 == 1 then
			PavementBlock(x + 64, y + i * 9, depth + 0.02, 0.3)
		end
		depth = depth + 0.01
	end
end

local function PavementSteps(x, y, dir, count, lightness, depth)
	local width = count + (((dir == 1) and 2) or 0)
	shape.Line({ x + 32, y }, { x + 32 * dir * width, y + 16 * count })
	for i = 1, count, 1 do
		local xx = x + i * 32 * dir
		local yy = y + i * 16
		PavementBlock(xx, yy - 38, depth, lightness)
		Occlusion.put('f', xx, yy - 256, -8.6, { size = { 64, 256 } })
		lightness = lightness + 0.05
		depth = depth + 0.01
	end
end

local function Roof(bb)
	local w = math.floor((bb.r - bb.l) / 64)
	bb.r = bb.l + w * 64
	local shape = { l = bb.l - 32, r = bb.r + 32, 
			b = bb.b + 8,  t = bb.b + 48 }
	eapi.NewShape(staticBody, nil, shape, "Box")
	ChainDecorator({ x = bb.l - 64, y = bb.b + 8 }, w - 1, 84)
	
	local pos = { x = bb.l - 64, y = bb.b - 16 }
	eapi.NewTile(staticBody, pos, nil, roof[1], 5)
	pos.x = pos.x + 64
	while pos.x < bb.r - 64 do
		eapi.NewTile(staticBody, pos, nil, roof[2], 5)
		pos.x = pos.x + 128
	end
	eapi.NewTile(staticBody, pos, nil, roof[3], 5)
end

local function Shed(pos, w, h)
	local x = pos.x + 96
	local y = pos.y - 80
	local prevSheets = { }
	local function Sheet(i)
		local candidate = util.Random(1, 4)
		if prevSheets[i] == candidate
		or prevSheets[i - 1] == candidate then
			return Sheet(i)
		else
			prevSheets[i] = candidate
			return sheet[candidate]
		end
	end
	local function Bars(xx, yy)
		if x == xx then
			local pos = {xx - 8, yy}
			eapi.NewTile(staticBody, pos, nil, Vbar(), -13)
		end
		eapi.NewTile(staticBody, {xx + 58, yy} , nil, Vbar(), -13)
		eapi.NewTile(staticBody, {xx, yy + 26} , nil, Hbar(), -14)
		eapi.NewTile(staticBody, {xx, yy + 86} , nil, Hbar(), -14)
	end
	local function PutSheet(pos, sheet)
		local tile
		if sheet then
			local rnd = 0.3 + util.Random() * 0.7
			local taint = { r = rnd, g = rnd, b = rnd }
			tile = eapi.NewTile(staticBody, pos, nil, sheet, -15)
			eapi.SetAttributes(tile, { color = taint })
		end
	end
	local function ShedColumn(xx)
		local offset = 0
		for i = 0, h - 1, 1 do
			local yy = y + i * 120
			PutSheet({xx + offset - 2, yy}, Sheet(i))
			offset = (offset + util.Random(1, 4)) % 5
			Bars(xx, yy)
		end
	end

	for i = 0, w - 1, 1 do
		ShedColumn(x + i * 64)
	end

	Roof({ l = x, r = x + w * 64, b = y + h * 120, t = y + h * 120 + 1 })

	PavementSteps(x + 128, y, -1, 5, 0.3, -2.5)
	PavementStripe(x + 96, y + 16, w - 5, 0.3, -3)
	PavementSteps(x + 128 + (w - 5) * 64, y, 1, 5, 0.3, -2.5)
	return { x = x + (w + 1) * 64 - 96, y = y + 80}
end

local pos = { x = -4096, y = -16 }
PavementStripe(pos.x - 256, pos.y, 4, nil, nil, "without-bricks")
PavementWall(pos.x - 192, pos.y - 227, 20)
Occlusion.put('a', pos.x - 128, pos.y - 256, -2.01, { size={64, 256} })
Occlusion.put('f', pos.x - 64, pos.y - 256, -2.01, { size={64, 256} })

-- tarpit
Occlusion.put('f', pos.x - 2192, pos.y - 256, 5,
	      { size={2000, 192} })
Occlusion.put('c', pos.x - 2192, pos.y - 64, 5,
	      { size={2000, 64}, flip = { false, true } })
Occlusion.put('j', pos.x - 192, pos.y - 64, 5,
	      { size={32, 64} })
Occlusion.put('r', pos.x - 192, pos.y - 256, 5,
	      { size={32, 192} })
shape.Line({ pos.x - 2192, pos.y - 96 },
	   { pos.x - 192, pos.y - 128 },
	   "PondBottom")
eapi.Collide(gameWorld, "Player", "PondBottom",
	     destroyer.Player_vs_PondBottom, 10)

pos = PavementStripe(pos.x, pos.y, 20)
pos = Shed(pos, 24, 20)
pos = PavementStripe(pos.x, pos.y, 20)
pos = Shed(pos, 8, 20)
pos = PavementStripe(pos.x, pos.y, 16)
pos = Shed(pos, 22, 8)
pos = PavementStripe(pos.x, pos.y, 24)
pos = Shed(pos, 20, 2)
pos = PavementStripe(pos.x, pos.y, 4)
pos = Shed(pos, 6, 2)
pos = PavementStripe(pos.x, pos.y, 20, nil, -7)
Spaceship(pos.x - 1000, pos.y)

local toolboxImg = eapi.NewSpriteList("image/inventory-items.png",
				      { { 32, 0 }, { 64, 32 } })

local function PutBox(pos)
	local tile = nil
	local activator = nil

	local function PickUpToolBox()
		eapi.PlaySound(gameWorld, "sound/toolbox.ogg")
		game.GetState().toolbox = true
		eapi.Destroy(tile)
	end

	local function GetToolBox()
		destroyer.Activate(PickUpToolBox)
		action.DeleteActivator(activator)
	end

	if not(game.GetState().toolbox) then
		tile = eapi.NewTile(staticBody, pos, nil, toolboxImg, -1)
		activator = action.MakeActivator({l=pos.x + 24, r=pos.x + 40,
						  b=pos.y + 8, t=pos.y + 16},
						 GetToolBox, txt.toolbox)
	end
end

local barrelImg = common.IndustrialImg({ { 448, 0}, { 64, 128 } })

local Oil1 = common.Oil(1)
local Oil2 = common.Oil(2, -1)

local function ShapelessBarrel(pos, aboveGround)
	eapi.NewTile(staticBody, pos, nil, barrelImg, 1 - 0.0001 * pos.y)
	for i = 1, 5 + util.Random(1, 4), 1 do
		Oil1({ x = math.floor(pos.x + 10 + 40 * util.Random()), 
		       y = math.floor(pos.y +  5 + 30 * util.Random()) })
	end
	if not(aboveGround) then
		for i = 1, 15 + util.Random(1, 10), 1 do
			Oil2({ x = math.floor(pos.x - 24 + 55 * util.Random()), 
			       y = math.floor(pos.y - 4 + 6 * util.Random()) })
		end
	end
end

local function Barrel(pos, aboveGround)
	ShapelessBarrel(pos, aboveGround)
	local box = { l = pos.x+8, r = pos.x+56, b = pos.y, t = pos.y + 100 }
	eapi.NewShape(staticBody, nil, box, "Box")
end

local function HorizontalBarrel(pos)
	local z = 1 - 0.0001 * pos.y
	local tileOffset = { x = -32, y = -64 }
	local body = eapi.NewBody(gameWorld, pos)
	local tile = eapi.NewTile(body, tileOffset, nil, barrelImg, z)
	eapi.SetAttributes(tile, { angle = vector.ToRadians(90) })
	eapi.NewShape(body, nil, { l = -24, r = 52, b = -32, t = 32 }, "Box")
end

local function StackedBarrel(pos)
	Barrel(pos, true)
end
	
local function Smoke(pos)
	effects.Smoke(pos, { z = 0.5,
			     dim = 0.2,
			     color = { r = 0, g = 0, b = 0 } })
end

local platformImg = common.IndustrialImg({ { 192, 448 }, { 192, 64 } })
	
local function IndustrialPlatform(bb)
	local function Create(platform)
		local body = platform.body
		eapi.SetAttributes(body, { sleep = false })		
		eapi.NewTile(body, nil, nil, platformImg, -1.0)
		local shape = { b = 4, t = 20, l = 32, r = 160 }		
		platform.shape =  eapi.NewShape(body, nil, shape, "Platform")
		return { l = -Infinity, r = Infinity, b = bb.b, t = bb.t }
	end
	local vel = { x = 0, y = 100 }
	local pos = { x = bb.l, y = bb.b } 
	local platform = util.CreateSimplePlatform(pos, vel, Create)
	return platform
end

local cableImg = common.IndustrialImg({ { 64, 192 }, { 64, 16 } })
local function Cable(bb)
	for i = bb.l, bb.r, 16 do
		local pos = { x = i, y = bb.b }
		eapi.NewTile(staticBody, pos, nil, cableImg, 0.7)
	end
end

local function IndustrialMore(box)
	return eapi.NewSpriteList("image/industrial-more.png", box)
end

local grateImg = IndustrialMore({ { 0, 0 }, { 192, 192 } })
local plateImg = IndustrialMore({ { 192, 0 }, { 160, 192 } })

local function Elevator(platform)
	local body = platform.body
	eapi.NewTile(body, { x = 0, y = 0 }, nil, platformImg, -1.0)
	eapi.NewTile(body, { x = 0, y = 152 }, nil, platformImg, 0.5)
	eapi.NewTile(body, { x = 0, y = -16 }, nil, grateImg, 1.0)
	eapi.NewTile(body, { x = 16, y = 8 }, nil, plateImg, -2.0)
	local shape = { b = 172, t = 188, l = 32, r = 160 }		
	local shapeObj = eapi.NewShape(body, nil, shape, "Box")
	local shape = { b = 4, t = 20, l = 32, r = 160 }
	platform.gears = bomber.CreateGears(body, { x = 64, y = 160 }, 0.6)
	platform.shape = eapi.NewShape(body, nil, shape, "Platform")
end

local elevators = { }

local switchImg = common.IndustrialImg({ { 128, 128 }, { 64, 64 } })
local lightImg = Occlusion.Sprite({ { 72, 192 }, { 16, 16 } })
local glowImg = Occlusion.Sprite({ { 72, 208 }, { 16, 16 } })

local function Glow(alpha)
	if game.GetState().dieselStarted then
		return { r = 0.1, g = 0.8, b = 0.1, a = alpha }
	else
		return { r = 0.8, g = 0.1, b = 0.1, a = alpha }
	end
end

local function CallSwitch(pos, handle, body)
	if not(body) then		
		body = eapi.NewBody(gameWorld, pos)
		pos = vector.null
	end
	local function Error()
		eapi.PlaySound(gameWorld, "sound/error.ogg")
	end
	local function Use()
		if game.GetState().dieselStarted then
			destroyer.Activate(elevators[handle].Activate)
		else	
			destroyer.Activate(Error)		
		end
	end
	eapi.NewTile(body, pos, nil, switchImg, -1.9)	
	local lightPos = vector.Offset(pos, 25, 50)
	local lightTile = eapi.NewTile(body, lightPos, nil, lightImg, -1.8)	
	local tile = eapi.NewTile(body, lightPos, nil, glowImg, -1.7)
	local flip = true
	local function Fader()
		flip = not(flip)
		eapi.SetAttributes(lightTile, { color = Glow(0.5) })
		effects.Fade(flip and 1 or 0, flip and 0 or 1, 1, Fader,
			     tile, nil, nil, body, Glow(1.0))
	end
	Fader()
	if handle then
		local bb = { l = pos.x + 28, r = pos.x + 38,
			     b = pos.y + 52, t = pos.y + 62 }
		action.MakeActivator(bb, Use, txt.switch, body)
	end
end

local function ElevatorPlatform(bb, handle, side)
	local platform
	local sound = nil
	local direction = side or 1
	local function Activate()
		eapi.PlaySound(gameWorld, "sound/click.ogg")
		if direction > 0 then
			platform.up()
		else
			platform.down()
		end
		platform.gears.Animate(direction)
		direction = -direction
		if sound == nil then
			local file = "sound/generator.ogg"
			sound = eapi.PlaySound(gameWorld, file, -1, 1, 0.5)
		end
	end
	local function Control(platform)
		platform.gears.Stop()
		if sound then
			eapi.FadeSound(sound, 0.5)
			sound = nil
		end
	end
	local function Create(platform)
		Elevator(platform)
		eapi.SetAttributes(platform.body, { sleep = false })
		return { l = bb.l, r = bb.r, b = -Infinity, t = Infinity }
	end
	local vel = { x = 100, y = 0 }
	local pos = { x = ((direction > 0) and bb.l) or bb.r, y = bb.b } 
	local box = { l = 88, r = 104, b = 20, t = 52 }
	platform = util.CreateSimplePlatform(pos, vel, Create, Control)
	if handle then elevators[handle] = platform end
	CallSwitch({ x = 64, y = 32 }, handle, platform.body)
	platform.Activate = Activate
end

local rampImg = common.IndustrialImg({ { 384, 448 }, { 128, 64 } })

local function Ramp(pos, hFlip)
	local tile = eapi.NewTile(staticBody, pos, nil, rampImg, -0.9)
	eapi.SetAttributes(tile, { flip = { hFlip or false, false } })
	local shape = { l = pos.x, r = pos.x + 128,
			b = pos.y, t = pos.y + 58 }
	local type = hFlip and "RightSlope" or "LeftSlope"
	eapi.NewShape(staticBody, nil, shape, type)
	local shape = { b = pos.y - 4, t = pos.y + 58 }
	if hFlip then
		shape.l = pos.x - 4
		shape.r = pos.x
	else
		shape.l = pos.x + 128
		shape.r = pos.x + 132
	end
	eapi.NewShape(staticBody, nil, shape, "Box")
	local shape = { l = pos.x, r = pos.x + 128,
			b = pos.y - 4, t = pos.y }
	eapi.NewShape(staticBody, nil, shape, "Box")
end

local armatureImg = { }
armatureImg[1] = common.IndustrialImg({ { 192, 128 }, { 64, 64 } })
armatureImg[2] = common.IndustrialImg({ { 256, 128 }, { 64, 64 } })

local function Armature(num)
	return function(pos, flip)
		local img = armatureImg[num]
		local tile = eapi.NewTile(staticBody, pos, nil, img, 0.5)
		eapi.SetAttributes(tile, { flip = { false, flip or false } })
	end
end

local engineImg = IndustrialMore({ { 0, 192 }, { 256, 128 } })
local engineShadow = Occlusion.FilteredSprite({ { 449, 129 }, { 62, 62 } })
local generatorImg = eapi.TextureToSpriteList("image/generator.png", {128, 64})
local supportImg = common.IndustrialImg({ { 128, 192 }, { 32, 32 } })
local electroImg = eapi.TextureToSpriteList("image/electricity.png", {128, 64})
local switchUpImg = common.IndustrialImg({ { 192, 192 }, { 64, 64 } })
local switchDownImg = common.IndustrialImg({ { 256, 192 }, { 64, 64 } })

local function KnifeSwitch(pos, img, z)
	return eapi.NewTile(staticBody, pos, nil, img, z)
end

local function Electricity(pos, body, z)
	local fps = 24 + util.Random() * 16
	local tile = eapi.NewTile(body, pos, nil, electroImg, z)
	eapi.Animate(tile, eapi.ANIM_LOOP, fps, util.Random())
	return tile
end

local function ElectricityField(bb)
	local j = 0
	local height = bb.t - bb.b
	local body = eapi.NewBody(gameWorld, vector.null)
	for i = bb.l, bb.r, 8 + 16 * util.Random() do
		local pos = { x = i, y = bb.b + j }
		local z = 0.9 + 0.3 * ((j < 2 * height / 3) and 1 or 0)
		Electricity(vector.Floor(pos), body, z)
		j = (j + 8 + 16 * util.Random()) % height
	end
	local floorBB = { b = bb.b, t = bb.t + 16, l = bb.l, r = bb.r + 64 }
	common.KillerFloor(floorBB, body)
	return body
end

local function Engine(pos)
	local smoke = nil
	local switch = nil
	local activator = nil
	local electricBody = nil
	local body = eapi.NewBody(gameWorld, pos)
	eapi.NewTile(body, nil, nil, engineImg, -0.5)
	local generatorPos = { x = 224, y = 20 }
	local tile = eapi.NewTile(body, generatorPos, nil, generatorImg, -0.6)
	eapi.NewTile(body, { x = 312, y = -4 }, nil, supportImg, -0.5)
	local center = eapi.NewBody(gameWorld, vector.Offset(pos, 256, 0))

	local function Shadow(offs, size, z)
 		eapi.NewTile(body, offs, size, engineShadow, z or -2.495)
	end
	Shadow({ x = 32, y = -1 }, { x = 200, y = 15 })
	Shadow({ x = 304, y = -2 }, { x = 48, y = 12 })

	local function StartDiesel()
		game.GetState().dieselStarted = true

		eapi.Animate(tile, eapi.ANIM_LOOP, 32, 0)
		
		local offset = 1
		local function Tremble()
			eapi.AddTimer(body, 0.1, Tremble)
			eapi.SetPos(body, vector.Offset(pos, offset, 0))
			offset = 1 - offset
		end
		Tremble()
		
		electricBody = ElectricityField({l=-2693,r=-1321,b=-115,t=-73})

		switch = KnifeSwitch({x=-2511,y=134}, switchDownImg, -0.9)

		local file = "sound/diesel.ogg"
		local dieselSound = eapi.PlaySound(gameWorld, file, -1, 0)
		eapi.BindVolume(dieselSound, center, mainPC.body, 500, 1000)	

		smoke = effects.Smoke(vector.Add(pos, { x = 8, y = 92 }),
				      { gravity = { x = 0, y = 50 },
					disableProximitySensor = true,
					color = { r = 0, g = 0, b = 0 },
					vel = {x = -50, y = 50},
					interval = 0.05,
					life = 1.5,
					z = -0.6, 
					dim = 0.2 })
		smoke.Kick()
	end

	local function TurnOff()
		game.GetState().dieselStarted = false

		eapi.Destroy(body)
		eapi.Destroy(switch)
		eapi.Destroy(center)
		eapi.Destroy(electricBody)
		action.RemoveActivatorInfo(activator)
		action.DeleteActivator(activator)
		mainPC.activator = nil
		smoke.Stop()
		
		Engine(pos)
	end

	if game.GetState().dieselStarted then
		StartDiesel()
	end

	local function PullSwitch()
		eapi.PlaySound(gameWorld, "sound/click.ogg")
		if not(game.GetState().dieselStarted) then
			StartDiesel()
		else
			TurnOff()
		end			
	end
	
	local function Use()
		destroyer.Activate(PullSwitch)
	end

	KnifeSwitch({x=-2511,y=134}, switchUpImg, -1.0)
	local bb = { l = -2480, r = -2476, b = 164, t = 168 }
	activator = action.MakeActivator(bb, Use, txt.switch, staticBody)
end

-- Export functions for use in level editor.
local exports = {
	FixedTrigger = {func=bomber.TriggerFixed,points=2},
	Oil2 = {func=Oil2,points=1},
	Fixed = {func=bomber.Fixed,points=1},
	HorizontalTrigger = {func=bomber.TriggerHorizontal,points=2},
	HorizontalBarrel = {func=HorizontalBarrel,points=1},
	Horizontal = {func=bomber.Horizontal,points=1},
	Bomber = {func=bomber.Put,points=2},
	ScrapMetal = {func=scrapMetal.Put,points=1},
	Engine = {func=Engine,points=1},
	KillerFloor = {func=common.KillerFloor,points=2},
	Armature1 = {func=Armature(1),points=1},
	Armature2 = {func=Armature(2),points=1},
	Buzzsaw = {func=buzzsaw.Put,points=2},
	Blocker = {func=common.Blocker,points=2,hide=false},
	CallSwitch = {func=CallSwitch,points=1},
	Ramp = {func=Ramp,points=1},
	Roof = {func=Roof,points=2},
	ElevatorPlatform = {func=ElevatorPlatform,points=2},
	Cable = {func=Cable,points=2},
	Box = {func=PutBox,points=1},
	Bat = {func=bat.Put,points=1},
	Hook = {func=PutHook,points=1},
	Barrel = {func=Barrel,points=1},
	StackedBarrel = {func=StackedBarrel,points=1},
	Platform = {func=PutEditorPlatform,points=2},
	ShapelessBarrel = {func=ShapelessBarrel,points=1,hide=true},
	Smoke = {func=Smoke,points=1},
	Kicker = {func=action.MakeKicker,points=2},
	HealthPlus = {func=destroyer.HealthPlus(6),points=1},
	HealthDispenser = {func=HealthDispenser,points=1},
	SavePointShed = {func=SavePointShed,points=1},
	IndustrialPlatform = {func=IndustrialPlatform,points=2},
	RibCage = {func=common.RibCage,points=1},
	Skull = {func=common.Skull,points=1},
}
editor.Parse("script/Industrial-edit.lua", gameWorld, exports)

eapi.PlaySound(gameWorld, "sound/city.ogg", -1, 0.8)

util.PreloadSound({ "sound/bat1.ogg",
		    "sound/bat2.ogg",
		    "sound/bat3.ogg",
		    "sound/bat4.ogg",
		    "sound/metal.ogg",
		    "sound/clunk.ogg",
		    "sound/diesel.ogg",
		    "sound/toolbox.ogg",
		    "sound/buzzsaw.ogg",
		    "sound/hit-metal.ogg",
		    "sound/metal-bit1.ogg",
		    "sound/metal-bit2.ogg" })
