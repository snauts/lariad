dofile("script/exit.lua")
dofile("script/occlusion.lua")
dofile("script/Cave.lua")
dofile("script/action.lua")
dofile("script/shape.lua")
dofile("script/spaceship.lua")
dofile("script/Falling.lua")
dofile("script/save-point.lua")
dofile("script/Common.lua")
dofile("script/rope.lua")

LoadPlayers()
local camBox = {l=-7200,r=-500,b=-10000,t=10000}
camera = util.CreateCamera(gameWorld, mainPC, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.0, g=0.0, b=0.0})

eapi.RandomSeed(42)

staticBody = eapi.GetStaticBody(gameWorld)

for j = 0, 2, 1 do
	DecoratorField(-1024 - j * 2560, -352, 1920, 160, 128)
end

local stalactiteImage = {
	image		= "image/bamboo.png",
	spriteOffset	= { x = 64, y = 192 },
}

local function PutStalactite(pos)
	falling.Put({ x = pos.x, y = pos.y,
		      name = "stalactite",
		      Crumble = action.RockCrumble,
		      restingSprite = bamboo['f'],
		      dieImage = effects.ShatterImage(0, 192), 
		      sound = "sound/stone.ogg" })
end

local function PutBag(x, y)
	local bag = { }
	bag.shouldSpark = true
	bag.shape = { l = 16, r = 48, b = 0, t = 64 }
	rope.Vertical({ x = x, y = y }, -0.1)
	bag.body = eapi.NewBody(gameWorld, {x, y - 40})
	local sprite = eapi.TextureToSpriteList("image/bag.png", {64, 64})
	local tile = eapi.NewTile(bag.body, {0, 0}, nil, sprite, -0.11)
	local bagState = game.GetState().healthPlus[1]

	bag.Shoot = function(projectile)
		eapi.Animate(tile, eapi.ANIM_CLAMP, 32)
		if not(bagState) then
			bagState = true
			local pos = { x = x + 16, y = y - 40 }
			destroyer.HealthPlus(1, true)(pos)
		end
		weapons.DeleteProjectile(projectile)
	end
		
	if bagState then
		eapi.SetFrame(tile, 31)
	else
		eapi.SetFrame(tile, 0)
	end

	action.MakeActorShape(bag)
end

PutBag(-1730, -2300)

local dx = 0
local function BambooTile(tile, x, y, should_flip, z)
	local pos = { x = x + dx, y = y }
	util.PutTileWithAttribute(staticBody, tile, bamboo, pos, 
				  z or -1, {flip = {should_flip, false}})
	dx = dx + 64
end

local function RopeTile(tile, x, y, dy, z, should_flip)
	rope.Vertical({x = x + dx, y = y + math.floor(dy / 2)}, z + (z * 0.1))
	BambooTile(tile, x, y + dy, not(should_flip), z)
end

local function BridgeRope(x, y, depth, len)
	dx = 0
	RopeTile('7', x, y, 47, depth, true)
	RopeTile('6', x, y, 27, depth, true)
	for i = 0, len do
		RopeTile('5', x, y, 16, depth, false)
	end
	RopeTile('6', x, y, 27, depth, false)
	RopeTile('7', x, y, 47, depth, false)

	util.PutTileWithAttribute(staticBody, '4', bamboo,
				  { x = x + dx,  y = y + 40 },
				  depth, { flip = { true, false } })
	util.PutTile(staticBody, '4', bamboo, { x = x - 64, y = y + 40 }, depth)
end

local function BambooBridge(x, y)
	dx = 0
	y = y + 14
	BambooTile('3', x, y + 8, true)
	BambooTile('2', x, y, true)
	for i = 0, 5 do
		BambooTile('1', x, y, false)
	end
	BambooTile('2', x, y, false)
	BambooTile('3', x, y + 8, false)

	BridgeRope(x, y, -1.1, 5)
	BridgeRope(x - 32, y - 12,  0.8, 6)

	y = y + 4
	shape.Line({x      , y + 46},{x +  32, y + 24})
	shape.Line({x +  32, y + 24},{x + 128, y + 20})
	shape.Line({x + 128, y + 20},{x + 512, y + 20})
	shape.Line({x + 512, y + 20},{x + 608, y + 24})
	shape.Line({x + 608, y + 24},{x + 640, y + 46})
end

local function BambooBridgePos(pos)
	BambooBridge(pos.x, pos.y)
end

local function RockPlant(pos, depth, type)
	local tile = util.PutTile(staticBody, type, bamboo, pos, depth)
	action.Stompable(pos, tile)
end

local fixx
local elevatorSet
local flipElevator
	
local function RockSlab(x, y, tiles)
	for i = 0, 3, 1 do
		WaterfallTile(tiles[i+1], fixx(-i), y, 1)	
	end
end

local function ElevatorEntrance(x, y)
	DarkRock('s', fixx(-1), y + 0 * 64, -2)
	DarkRock(elevatorSet[1], fixx(-1), y + 1 * 64, -2)
	DarkRock(elevatorSet[2], fixx(-1), y + 3 * 64, -2)
	DarkRock('t', fixx(-1), y + 4 * 64, -2)

	DarkRock('t', fixx(-2), y + 0 * 64, -2)
	DarkRock('s', fixx(-2), y + 1 * 64, -2)
	DarkRock(elevatorSet[3], fixx(-2), y + 2 * 64, -2)
	DarkRock('t', fixx(-2), y + 3 * 64, -2)
	DarkRock('s', fixx(-2), y + 4 * 64, -2)
end

local function LeftWall()
	return RandomElement({'i','q','y'})
end

local function RightWall()
	return RandomElement({'C','u','m'})
end

local function Wall(flip)
	if xor(flip, flipElevator) then
		return LeftWall()
	else
		return RightWall()
	end
end

local spacing = 6
local function ElevatorShaft(x, y, d)

	ElevatorEntrance(x, y)
	RockSlab(x, y, {elevatorSet[4],'b','c',elevatorSet[5]})
	RockSlab(x, y + 4 * 64, {elevatorSet[6],'H','J',elevatorSet[7]})

	local dd = -4 * (d + 1) / 2
	for i = dd, dd + 2 * d * spacing, d do 
		local yy = y - i * 64
		for j = -3, -6, -1 do 
			DarkRock(SolidRock(), fixx(j), yy, -2)
		end
		WaterfallTile(Wall(false), fixx(-6), yy, 1)
		for j = -7, -9, -1 do 
			WaterfallTile(SolidRock(), fixx(j), yy, 1)
		end
	end
	for i = dd - d, dd - 4 * d, -d do 
		local yy = y - i * 64
		for j = -1,-9,-1 do
			WaterfallTile(SolidRock(), fixx(j), yy, 1)
		end
		WaterfallTile(Wall(false), fixx(0), yy, 1)
	end
	dd = -(dd + 4) + d
	for i = dd, dd + spacing * d - d, d do 
		local yy = y - i * 64
		WaterfallTile(Wall(true), fixx(-3), yy, 1)
		WaterfallTile(SolidRock(), fixx(-2), yy, 1)
		WaterfallTile(SolidRock(), fixx(-1), yy, 1)
		WaterfallTile(Wall(false), fixx(0), yy, 1)
	end

	local yy = -8
	if flipElevator then xx = fixx(0)  else xx = fixx(-3) end
	xx = xx + 16
	local DecoreDown = function(c1, c2)
		PutDecorator(xx + 16 * util.Random(0, c1),
			     yy + y - 64 - 16 * util.Random(0, c2))
	end
	local DecoreUp = function(c1, c2)
		PutDecorator(xx + 16 * util.Random(0, c1),
			     yy + y + 4 * 64 + 16 * util.Random(0, c2))
	end
	for i=0, 16, 1 do
		if d > 0 then DecoreUp(7, 8) else DecoreDown(7, 8) end
	end
	yy = ((d > 0) and 0) or 16
	if flipElevator then xx = fixx(0) else xx = fixx(-3) end
	for i=1, 31, 1 do
		if d > 0 then DecoreDown(8, 21) else DecoreUp(8, 21) end
	end

	if flipElevator then xx = fixx(-6) else xx = fixx(-9) end
	yy = d * 4 * 64
	for i=0, 32, 1 do
		if d > 0 then DecoreDown(8, 40) else DecoreUp(8, 40) end
	end

	if flipElevator then xx = fixx(-4) else xx = fixx(-9) end
	yy = d * 7 * 64
	for i=0, 32, 1 do
		if d > 0 then DecoreDown(16, 8) else DecoreUp(16, 8) end
	end
end

local function ShaftBottomSlopeType(d)
	if d == 0 then
		return "CeilingLeftSlope"
	else
		return "CeilingRightSlope"
	end
end

local function ElevatorShaftShape(x, y, h, d)
	if flipElevator then x = x + 64 end
	local backwall = fixx(-5.125 + d)
	local frontwall = fixx(-2.875 + d)
	local ceiling1 = y + 4 * 64 + 8
	local ceiling2 = h + 3 * 64 + 8
	shape.Line({x, ceiling1}, {backwall, ceiling1}, "Box")
	local slabX = backwall - 100 * d
	shape.Line({slabX, ceiling1}, {slabX, h - 10}, nil, 100)
	local slabX = frontwall + 100 + 99 * d
	shape.Line({slabX, ceiling2 + 64}, {slabX, y}, nil, 101)
	shape.Line({x, ceiling2 + 100},
		   {fixx(-2 + d), ceiling2 + 100}, "Box", 100)
	shape.Line({frontwall, y}, {fixx(-2 + d), y + 64}, nil, 100)
	shape.Line({fixx(-2 + d), ceiling2},
		   {frontwall, ceiling2 + 64}, ShaftBottomSlopeType(d), 100)
	shape.Line({fixx(-2 + d), y + 64}, {x, y + 64}, nil, 100)
	shape.Line({backwall, h}, {x, h}, nil)
	local x1 = math.min(fixx(-1 + d), fixx(-2 + d))
	local x2 = math.max(fixx(-1 + d), fixx(-2 + d))	
end

local function ElevatorBlock(x, y, flip)
	flipElevator = flip
	if flip then 
		elevatorSet = {'r','7','q', 'a', 'e', 'G', 'K'}
	else
		elevatorSet = {'X','6','u', 'e', 'a', 'K', 'G'}
	end
	fixx = function (q)
		       if flip then
			       return x - q * 64
		       else
			       return x + q * 64
		       end
	       end

	local h = y - (2 * spacing + 4) * 64
	ElevatorShaft(x, y, 1)
	ElevatorShaft(x, h - 64, -1)
	for j = -3, -5, -1 do 
		WaterfallTile(RandomElement({'H','I','J'}), fixx(j), y + 4 * 64, 2)
		WaterfallTile(RandomElement({'b','c','d'}), fixx(j), h - 64, 2)
	end
	WaterfallTile(SolidRock(), fixx(-6), y + 4 * 64, 3)
	WaterfallTile(SolidRock(), fixx(-6), y + 3 * 64, 3)
	WaterfallTile(SolidRock(), fixx(-5), y + 4 * 64, 3)
	WaterfallTile(elevatorSet[2], fixx(-5), y + 3 * 64, 3)

	WaterfallTile(SolidRock(), fixx(-6), h - 64, 3)
	WaterfallTile(SolidRock(), fixx(-6), h,      3)
	WaterfallTile(SolidRock(), fixx(-5), h - 64, 3)
	WaterfallTile(elevatorSet[1], fixx(-5), h, 3)

	if flipElevator then d = 1 else d = 0 end
	ElevatorShaftShape(x, y, h, -d)

	local function BambooPlatform(platform)
		local body = platform.body
		eapi.SetAttributes(body, { sleep = false })
		util.CreateTiles(body, {"11"}, bamboo, nil, nil, -0.9)
		platform.shape = shape.Line({ 0, 0 }, { 128, 24 }, 
					    "Platform", nil, body)
		return {l = -Infinity, r = Infinity, b = h + 4, t = y + 32}
	end
	local platformPos = { x=fixx(-5 + d), y = h + 4 + 384 }
	util.CreateSimplePlatform(platformPos, {x=0, y=-200}, BambooPlatform)
	if flip then x = x - 576 end
	BambooBridge(x, h - 64)
end

local function ElevatorBlockPos(pos, flip)
	ElevatorBlock(pos.x, pos.y, flip)
end

local function RockColumn(x, y, t1, t2, t3, t4, t5, h2)
	local h1 = 5
	local h3 = 8
	for i = 0, (h1 - 1), 1 do
		WaterfallTile(t1(), x, y + (i + h2 + 1) * 64, 1)
	end
	WaterfallTile(t2, x, (y + 64), 1)
	for i = -1, h2, 1 do		
		DarkRock(t3(), x, y + i * 64, -1)
	end
	WaterfallTile(t4, x, (y + h2 * 64), 1)
	for i = 0, (h3 - 1), 1 do
		WaterfallTile(t5(), x, y - i * 64, 1)
	end
end

local function Empty()
	return ' '
end

local function LeftEntry(x, y, h, subtleFix)
	RockColumn(x, y, LeftWall,  'a', Empty, 'G', LeftWall, h)
	RockColumn(x + 64, y, SolidRock, 'b', Empty, 'H', SolidRock, h)
	RockColumn(x + 128, y, SolidRock, 'b', Empty, 'H', SolidRock, h)

	DarkRock(SolidRock(), x + 64, y + 64, -1)
	DarkRock('r',	      x + 64, y + 2 * 64, -1)
	DarkRock('7',	      x + 64, y + (h - 1) * 64, -1)
	DarkRock(SolidRock(), x + 64, y + h * 64, -1)

	DarkRock(SolidRock(), x + 2 * 64, y + 64, -1)
	DarkRock(SolidRock(), x + 2 * 64, y + 2 * 64, -1)
	DarkRock(SolidRock(), x + 2 * 64, y + (h - 1) * 64, -1)
	DarkRock(SolidRock(), x + 2 * 64, y + h * 64, -1)

	for i = 3, h - 2, 1 do		
		DarkRock(LeftWall(), x + 128, y + i * 64, -1)
	end
	shape.Line({x + 64, y + 2 * 64},
		   {x + 3 * 64, y + 2 * 64 - 12},
		   subtleFix)
	shape.Line({x + 64, y + h * 64 + 64},
		   {x + 3 * 64, y + h * 64 + 64},
		   "Box")
end

local function RightEntry(x, y, h)
	RockColumn(x + 128, y, RightWall, 'e', Empty, 'K', RightWall, h)
	RockColumn(x + 64, y, SolidRock, 'b', Empty, 'H', SolidRock, h)
	RockColumn(x, y, SolidRock, 'b', Empty, 'H', SolidRock, h)

	WaterfallTile('v', x - 64, y + h * 64, 2)
	DarkRock(SolidRock(), x + 64, y + 64, -1)
	DarkRock('X',	      x + 64, y + 2 * 64, -1)
	DarkRock('6',	      x + 64, y + (h - 1) * 64, -1)
	DarkRock(SolidRock(), x + 64, y + h * 64, -1)

	DarkRock(SolidRock(), x, y + 64, -1)
	DarkRock(SolidRock(), x, y + 2 * 64, -1)
	DarkRock(SolidRock(), x, y + (h - 1) * 64, -1)
	DarkRock(SolidRock(), x, y + h * 64, -1)

	for i = 3, h - 2, 1 do		
		DarkRock(RightWall(), x, y + i * 64, -1)
	end
	shape.Line({x, y + 2 * 64 - 12},{x + 2 * 64, y + 2 * 64})
	shape.Line({x, y + h * 64 + 64},
		   {x + 2 * 64, y + h * 64 + 64}, 
		   "Box")
end

local function LeftEntryPos(pos, h, subtleFix)
	LeftEntry(pos.x, pos.y, h, subtleFix)
end

local function RightEntryPos(pos, h)
	RightEntry(pos.x, pos.y, h)
end

local function SimpleColumn(pos, t1, t2, h)
	RockColumn(pos.x, pos.y, SolidRock, t1, SolidRock, t2, SolidRock, h)
end

local function CaveExit(x, y)
	LeftEntry(x, y, 5, "Box")
	shape.Line({x + 3 * 64, y + 2 * 64}, {x + 7 * 64, y + 2 * 64})
	local darkFront = 4
	local darkBack = 6
	local darkLow = 1
	local darkHigh = 5
	for i = 3, darkBack - 1, 1 do
		SimpleColumn({ x = x + i * 64, y = y }, 'b', 'H', 5)
	end
	for i = -5, 10, 1 do
		if i < darkLow or i > darkHigh then 
			xi = darkFront
		else 
			xi = darkBack - 1
		end
		Occlusion.put('a', x + xi * 64, y + i * 64, 10)
	end
	for i = -5, 10, 1 do
		if i < darkLow or i > darkHigh then 
			xi = darkFront + 1
		else 
			xi = darkBack
		end
		for j = xi, 16, 1 do
			Occlusion.put('f', x + j * 64, y + i * 64, 10)
		end
	end
	for i = darkFront + 1, darkBack, 1 do
		Occlusion.put('c', x + i * 64, y + darkHigh * 64, 10)
		Occlusion.put('c', x + i * 64, y + darkLow * 64, 10,
			      { flip = { false, true } })
	end

	Occlusion.put('g', x + darkFront * 64, y + darkHigh * 64, 10)
	Occlusion.put('g', x + darkFront * 64, y + darkLow * 64, 10,
		      { flip = { false, true } })

	DecoratorField(x, y - 2.50 * 64, 320, 160, 32)
	DecoratorField(x, y + 5.00 * 64, 320, 160, 32)
end

local function CaveExitPos(pos)
	CaveExit(pos.x, pos.y)
end

local bg = eapi.NewSpriteList("image/blue-rock-bg.png", {{0, 0}, {512, 512}})
eapi.NewParallax(gameWorld, bg, nil, nil, {0.75, 0.75}, -11)

local anim = eapi.TextureToSpriteList("image/waterfall.png", {128, 128})
local px1 = eapi.NewParallax(gameWorld, anim, nil, nil, {0.8, 0.8}, -10)
eapi.Animate(px1, eapi.ANIM_LOOP, 50)
local px2 = eapi.NewParallax(gameWorld, anim, {256, 256}, nil, {0.8, 0.8}, -9.9)
eapi.Animate(px2, eapi.ANIM_LOOP, 40)

Occlusion.passage(-6912, -1093, -0.1, "SideCave",
		  {264,731}, txt.sideCave, eapi.ZOOM_OUT)

Occlusion.passage(-6912, -3333, -0.1, "SideCave", 
		  {264,-38}, txt.sideCave, eapi.ZOOM_OUT)

ExitRoom({r=-614.00, b=-3520.00, l=-615.00, t=-3300.00 }, "DarkCave", { 64, 0 },
	 nil, nil, nil, eapi.SLIDE_RIGHT)

Spaceship(-1000, -64)

local bb1 = eapi.NewSpriteList("image/billboard1.png", {{ 0, 0}, { 256, 256 }})
local bb2 = eapi.NewSpriteList("image/billboard2.png", {{ 0, 0}, { 256, 256 }})
eapi.NewTile(staticBody, { -2600, -72 }, { 256, 256 }, bb1, -1)
eapi.NewTile(staticBody, { -5200, -72 }, { 256, 256 }, bb2, -1)

action.MakeMessage(txt.warn1Sign, {l=-2490, b=-35, r=-2460, t=-30},
		   txt.warning1)
action.MakeMessage(txt.warn2Sign, {l=-5090, b=-35, r=-5060, t=-30},
		   txt.warning2)

eapi.PlaySound(gameWorld, "sound/waterfall.ogg", -1, 0.5)

local function BambooBlood(pos)
	util.PutTile(staticBody, 'h', bamboo, pos, 0.6)
end

local function WaterfallTilePos(pos, tile, z, attr)	
	WaterfallTile(tile, pos.x, pos.y, z, attr)	
end

local function HorizontalPlatform(bb)
	local function Platform(platform)
		local body = platform.body
		eapi.SetAttributes(body, { sleep = false })
		util.CreateTiles(body, {"11"}, bamboo, nil, nil, -0.85)
		platform.shape = shape.Line({ 0, 0 }, { 128, 24 }, 
					    "Platform", nil, body)
		return {l = bb.l, r = bb.r, b = -Infinity, t = Infinity }
	end
	local pos = { x = bb.l + util.Random() * (bb.r - bb.l), y = bb.b }
	util.CreateSimplePlatform(pos, { x = 120, y = 0 }, Platform)
end

local function AnimateIvy(pos, tile, flip)
	local time = -2
	local bb = { l = pos.x + 15, r = pos.x + 17,
		     b = pos.y, t = pos.y + 256 }
	local function Animate()
		local now = eapi.GetTime(staticBody)
		if now - time > 2.0 then
			local dir = util.Sign(mainPC.vel.x)
			if flip then dir = -dir end
			eapi.Animate(tile, eapi.ANIM_CLAMP, dir * 16, 0)
			time = now
		end
	end
	proximity.Create(Animate, function() end, nil, bb)	
end

local ivyImg = eapi.TextureToSpriteList("image/ivy.png", {32, 256})
local function Ivy(pos, z, flip)
	local tile = eapi.NewTile(staticBody, pos, nil, ivyImg, z)
	eapi.SetAttributes(tile, { flip = { flip, false } })
	if flip then eapi.SetAttributes(tile, { color = util.Gray(0.6) }) end
	AnimateIvy(pos, tile, flip)
end

local function Ivy1(pos)
	Ivy(pos, 0.5, false)
end

local function Ivy2(pos)
	Ivy(pos, -0.5, true)
end

local function WaterDrop(bb)
	common.Rain(bb, nil, util.Random() - 0.5)
end

-- Export functions for use in level editor.
local exports = {
	Ivy1 = {func=Ivy1,points=1},
	Ivy2 = {func=Ivy2,points=1},
	HorizontalPlatform = {func=HorizontalPlatform,points=2},
	WaterfallTile = {func=WaterfallTilePos,points=1},
	RockPlant = {func=RockPlant,points=1},
	Blocker = {func=common.Blocker,points=2},
	SimpleColumn = {func=SimpleColumn,points=1},
	RightEntry = {func=RightEntryPos,points=1},
	LeftEntry = {func=LeftEntryPos,points=1},
	ElevatorBlock = {func=ElevatorBlockPos,points=1},
	CaveExit = {func=CaveExitPos,points=1},
	BambooBridge = {func=BambooBridgePos,points=1},
	PutSpike = {func=cave.PutSpike,points=1},
	PutStalactite = {func=PutStalactite,points=1},
	SavePoint = {func=savePoint.Put,points=1},
	RibCage = {func=common.RibCage,points=1},
	Skull = {func=common.Skull,points=1},
	BambooBlood = {func=BambooBlood,points=1},
	HandPrint = {func=common.BloodyHandPrint,points=1},
	Kicker = {func=action.MakeKicker,points=2},
	WaterDrop = {func=WaterDrop,points=2},
}
editor.Parse("script/Waterfall-edit.lua", gameWorld, exports)

if game.GetState().startLives > 1 then		
	savePoint.Medkit3({x=-4468,y=-3421})
end
