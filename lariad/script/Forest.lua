dofile("script/exit.lua")
dofile("script/shape.lua")
dofile("script/occlusion.lua")
dofile("script/spaceship.lua")
dofile("script/Falling.lua")
dofile("script/action.lua")
dofile("script/wasp.lua")
dofile("script/big-wasp.lua")
dofile("script/wood.lua")
dofile("script/Common.lua")
dofile("script/Beam.lua")
dofile("script/save-point.lua")

LoadPlayers()
if util.msg == "FromNiche" then	
	camera = util.CreateCamera(gameWorld)
	eapi.SetBackgroundColor(gameWorld, { r=0.0, g=0.0, b=0.0 })
else
	local camBox = { l = -11000, r = 21200, b = -300, t = 2000 }
	camera = util.CreateCamera(gameWorld, mainPC, camBox)
	eapi.SetBackgroundColor(gameWorld, { r=0.4, g=0.4, b=0.8 })
end
eapi.RandomSeed(1945)
staticBody = eapi.GetStaticBody(gameWorld)

local function LoadTexture(name)
	return util.TextureToTileset(name, tileMap8x8, {64, 64})
end

local forestTexture = LoadTexture("image/forest.png")
local forestMoreTexture = LoadTexture("image/forest-more.png")

function ForestTile(pos, id, depth, attributes, texture)
	pos.x = math.floor(pos.x)
	pos.y = math.floor(pos.y)
	util.PutTileWithAttribute(staticBody, id, texture or forestTexture,
				  pos, depth, attributes)
end

local lastGravel = nil
local gravelColumn = { }
local function GravelElement(x, y)
	local id = RandomElement({'m','n','o'})
	local prevHash = (50000 * (x - 64)) + y
	if id == lastGravel or gravelColumn[prevHash] == id then
		return GravelElement(x, y)
	else
		gravelColumn[(50000 * x) + y] = id
		gravelColumn[prevHash] = nil
		lastGravel = id
		return id
	end
end

function Gravel(pos, bottom, attrib, depth)
	bottom = bottom or -400
	local x = pos.x
	local y = pos.y	
	while y >= bottom do
		local id = GravelElement(x, y)
		ForestTile({ x = x, y = y }, id, depth or 3.0, attrib)
		y = y - 64 
	end
end

local elm1Texture = { "image/elm1.png" }
local elm2Texture = { "image/elm2.png" }
local elmSizes = { { 202, 256 }, { 202, 256 }, { 310, 512 }, { 512, 512 } }
local elmSprites = { eapi.NewSpriteList(elm1Texture, {{310, 0}, elmSizes[1]}),
		     eapi.NewSpriteList(elm1Texture, {{310,256}, elmSizes[2]}),
		     eapi.NewSpriteList(elm1Texture, {{ 0, 0 }, elmSizes[3]}),
		     eapi.NewSpriteList(elm2Texture, {{ 0, 0 }, elmSizes[4]})}

local leafAnim = eapi.TextureToSpriteList("image/elm-leaf.png", {64, 32})

local leafRange = 800

local function LeafEmitter(pos)
	local nullPos = {x = 0, y = 0}
	local function FallingLeaf(body)
		local tile = eapi.NewTile(body, nullPos, nil, leafAnim, -0.1)
		eapi.Animate(tile, eapi.ANIM_LOOP, 32, 64.0 * util.Random())
		eapi.SetGravity(body, { x = 0, y = -45 })
	end

	local function LeafPosition()
		return { x = pos.x - 64 + 64 * util.Random(), y = pos.y }
	end
	
	local emitter = util.ParticleEmitter(LeafPosition, 3.5, 1, FallingLeaf)
	emitter.pos = pos

	proximity.Create(emitter.Kick, emitter.Stop, nil,
			 { l = pos.x - leafRange, r = pos.x + leafRange,
			   b = pos.y - leafRange, t = pos.y + leafRange })
end
	     
function Tree(pos, num, z, c, attr, body)
	-- particle leaves ar emited only by large
	-- and light trees that are in foreground
	z = z or 1
	num = num or 1
	if c == 1 and (num == 3 or num == 4) then
		LeafEmitter({ x = pos.x, y = pos.y + 256 })
	end

	c = c or 1.0
	local size = elmSizes[num]
	local size2 = { x = size[1], y = size[2] }
 	local pos2 = { x = pos.x - size[1] / 2, y = pos.y }
	local tile = eapi.NewTile(body or staticBody, pos2,
				  size2, elmSprites[num], z)
	local colorAttr = { color = { r = c, g = c, b = c } }
	eapi.SetAttributes(tile, util.JoinTables(colorAttr, attr or { }))
end

local function Grass(pos, id, depth)
	ForestTile(pos, id, depth)
	Gravel(vector.Offset(pos, 0, -64))
end

local function GravelBlock(bb, attrib, depth)
	for i = bb.l, bb.r, 64 do
		Gravel({ x = i, y = bb.t }, bb.b, attrib, depth)
	end
end

local dark = {color={r=0.4, g=0.4, b=0.4}}

local function DarkBlock(bb)
	GravelBlock(bb, dark, -3.0)
end

function Boulder(pos, num, z, shapeType)
	local flipV, flipH
	local id = ({'e','f','g'})[(num % 3) + 1]
	num = math.floor(num / 3)
	flipH = (num % 2 == 1) and true
	num = math.floor(num / 2)		
	ForestTile(pos, id, z, { flip = { flipH, false } })
	if not(shapeType == "no-shape") then
		shapeType = shapeType or "Box"
		shape.Line({pos.x+16,pos.y}, {pos.x+48,pos.y+32}, shapeType)
	end
end

local function EditBoulder(pos)
	Boulder(pos, util.Random(0, 5), 5.5, "OneWayGround")
end

local bgTexture = { "image/forest-bg.png" }
local function BackGround(win, s, o, p, d)
	local tx = eapi.NewSpriteList(bgTexture, win)
	local px = eapi.NewParallax(gameWorld, tx, s, o, p, d)
	eapi.SetRepeatPattern(px, {true,false})
end

if not(util.msg == "FromNiche") then
	BackGround({{ 0, 0 }, { 512, 512 }}, { 1280, 1280 },
		   { 0, -256 }, { 0.5, 0.5 }, -100)
	BackGround({{ 0, 512 }, { 512, 512 }}, { 512, 512 },
		   { 0, 512 }, { 0.5, 0.5 }, -99)
	BackGround({{ 512, 0 }, { 512, 256 }}, { 512, 256 },
		   { 512, 64 }, { 0.7, 0.6 }, -98)
	BackGround({{ 512, 512 }, { 512, 512 }}, { 512, 512 },
		   { 512, -128 }, { 0.75, 0.7 }, -97)
	BackGround({{ 512, 512 }, { 512, 512 }}, { 512, 512 },
		   { 512, -288 }, { 0.8, 0.8 }, -96)
end

local function LongGrass(pos)
	Grass(pos, 'a', 4.5)
	Grass({ x = pos.x + 64,  y = pos.y }, 'b', 4.5)
	Grass({ x = pos.x + 128, y = pos.y }, 'c', 4.5)
	Grass({ x = pos.x + 192, y = pos.y }, 'd', 4.5)
	return{ x = pos.x + 256, y = pos.y }
end	

local function EndGrass(pos)
	Grass(pos, 'r', 4.5)
	return { x = pos.x + 64, y = pos.y}
end	

local structureHeight = 1366

local platform = { "image/landing-platform.png" }

local Landpad = eapi.NewSpriteList(platform, {{ 0, 0 }, { 256, 96 }})
local PadLeftSide = eapi.NewSpriteList(platform, {{ 0, 266 }, { 512, 246 }})
local PadGround = eapi.NewSpriteList(platform, {{ 320, 400 }, { 192, 112 }})
local BarLeftSide = eapi.NewSpriteList(platform, {{ 0, 230 }, { 512, 36 }})
local BarGround = eapi.NewSpriteList(platform, {{ 320, 230 }, { 192, 36 }})
local SpotLight = eapi.NewSpriteList(platform, {{ 256, 0 }, { 256, 230 }})
local Elevator = eapi.NewSpriteList(platform, {{ 0, 100 }, { 240, 130 }})

local function Jitter()
	return util.Random(0, 16) - 8
end

local function PileOfBoulders(pos, width, height, shapeType, z)
	z = z or 6.0
	if height == 0 then
		print("ERROR: PileOfBoulders -- height must not be zero")
	end
	for dy = 0, height, 16 do
		local offset = 0.5 * width * math.pow(dy / height, 2.0)
		for dx = 0 + offset, width - offset, 16 do
			Boulder({ x = pos.x + dx - 32 + Jitter(),
				  y = pos.y + dy - 32 + Jitter() },
				util.Random(0, 5),
				z + util.Random(),
				shapeType)
		end
	end
end

local function LandingSupport(pos)
	for y = pos.y, pos.y + structureHeight, 96 do
		eapi.NewTile(staticBody, { x = pos.x, y = y },
			     nil, Landpad, 2.0)
	end
	Gravel(vector.Add(pos, { x = 0, y = -64 }))
	Gravel(vector.Add(pos, { x = 64, y = -64 }))
	Gravel(vector.Add(pos, { x = 128, y = -64 }))
	Gravel(vector.Add(pos, { x = 192, y = -64 }))
	PileOfBoulders(pos, 256, 64)
	return { x = pos.x + 256, y = pos.y }
end

local insectAnim = eapi.TextureToSpriteList("image/insects.png", {64,64})

local function Moth(x, y, depth, offset)
	local tile = util.PutAnimTile(staticBody, insectAnim, {x=x, y=y},
				      depth, eapi.ANIM_LOOP, 24, offset)
	eapi.SetAttributes(tile, { color = { r = 0.7, g = 0.9, b = 0.7 } })
end

local generatorSound = nil

local function LandingPadTop(pos)
	local x = pos.x - 64
	local y = pos.y + structureHeight + 48
	eapi.NewTile(staticBody, { x = x, y = y }, nil, PadLeftSide, -8)
	eapi.NewTile(staticBody, { x = x, y = y + 9 }, nil, BarLeftSide, 3)
	eapi.NewTile(staticBody, { x = x + 66, y = y + 32 },
		     nil, SpotLight, 2.9)
	Moth(x + 150, y + 180, 1.0, 0)
	Moth(x + 150, y + 180, 1.0, 0.5)
	local underPlatform = nil

	local platformTop = y + 16
	local platformBottom = y - structureHeight - 48

	local function ElevatorPlatform(platform)
		local body = platform.body
		platform.downJumpDisabled = true
		eapi.NewTile(body, { x=0, y=0 }, nil, Elevator, -5)
		platform.shape = shape.Line({ 46, 32 }, { 228, 0 },
					    "Platform", nil, body)
		return {l = -Infinity, r = Infinity,
			b = platformBottom, t = platformTop}
	end

	local function PlatformStop()
		if generatorSound then
			eapi.FadeSound(generatorSound, 0.5)
		end
		mainPC.StartInput()
	end

	local function FakeBox()
		-- disables stepping under platform when it's landed
		return shape.Line({ pos.x + 48, pos.y + 32}, 
				  { pos.x + 230, pos.y + 0 },
				  "Box")
	end

	local elevatorPos = platformTop;
	if not(game.GetState().previousRoom == "CargoHold")
	and game.GetState().spaceShipLandedOn == "Forest" then
		elevatorPos = platformBottom
		FakeBox()
	end

	local buttons = util.CreateSimplePlatform({x=x + 66, y=elevatorPos },
	    {x=0, y=100}, ElevatorPlatform, PlatformStop)

	local function Click()
		eapi.PlaySound(gameWorld, "sound/click.ogg")
	end

	local function HummingWrap(fn)
		return function()
			generatorSound = eapi.PlaySound(gameWorld,
			    "sound/generator.ogg", -1, 1, 0.5)			
			fn()
		end
	end

	local function TravelDown()
		if not(underPlatform) then
			underPlatform = FakeBox()
		end
		destroyer.Activate(Click, HummingWrap(buttons.down))
		mainPC.StopInput()
	end
	action.MakeActivator({l=pos.x + 130, b= -150 + structureHeight,
			      r=pos.x + 146, t= -140 + structureHeight},
			     TravelDown, txt.goDown)

	local function TravelUp()
		destroyer.Activate(Click, HummingWrap(buttons.up))
		mainPC.StopInput()
	end
	if game.GetState().spaceShipLandedOn == "Forest" then
		action.MakeActivator({l=pos.x + 130, b=-210,
				      r=pos.x + 146, t=-202},
				     TravelUp, txt.goUp)
	end

	shape.Line({ pos.x + 16, y + 48 }, { pos.x + 48, y + 16 }, "Box")
	shape.Line({ pos.x + 230, y + 48 }, { pos.x + 2048, y + 16 }, "Box")
	shape.Line({ pos.x - 48, y + 52 }, { pos.x + 16 , y + 16 }, "Box")
	shape.Line({ pos.x - 48, y + 128 }, { pos.x - 80 , y + 16 }, "Box")
	shape.Line({ pos.x + 32, y + 240 }, { pos.x + 136 , y + 235 }, "Box")
	shape.Line({ pos.x - 48, y + 128 }, { pos.x + 32 , y + 235 },
		   "CeilingRightSlope")
	for i = 0, 7, 1 do
		local p = { x = x + i * 192 + 512, y = y }
		eapi.NewTile(staticBody, p, nil, PadGround, -8)
		eapi.NewTile(staticBody, vector.Offset(p, 0, 9),
			     nil, BarGround, 3)
	end
	Spaceship(pos.x + 920, structureHeight - 160)
end

function LandingZone(pos)
	shape.Line({ pos.x, pos.y }, { pos.x + 1536, pos.y - 16 }, "Box")
	Tree(vector.Offset(pos, 680, 0), 3, 1.0, 1.0)
	LandingPadTop(pos)
	pos = LongGrass( pos)
	pos = LandingSupport(pos)
	pos = LongGrass(pos)
	Tree(vector.Offset(pos, 64, 0), 1, -1.0, 0.9)
	Tree(vector.Offset(pos, 128, -16), 2, -1.1, 0.7)
	pos = LongGrass(pos)
	pos = LandingSupport(pos)
	pos = LongGrass(pos)
end

local function BackBeam(pos, flipH)
	local dx = 20
	flipH = not(not(flipH))
	local attr = { flip = { flipH, false } }
	ForestTile(vector.Offset(pos, 0, 192), 'y', -2.0, attr)
	ForestTile(vector.Offset(pos, 0, 128), 'G', -2.0, attr)
	ForestTile(vector.Offset(pos, 0, 64), 'O', -2.0, attr)
	ForestTile(pos, 'X', -2.0, attr)
	if flipH then dx = 0 end
	Occlusion.put('a', pos.x + dx, pos.y, -1.9, 
		      { size={40, 227}, flip = { flipH, false } })
end

local function FrontBeam(pos, flipH)
	flipH = not(not(flipH))
	local attr = { flip = { flipH, false } }
	ForestTile(vector.Offset(pos, 0, 192), 'z', 2.0, attr)
	ForestTile(vector.Offset(pos, 0, 128), 'H', 2.0, attr)
	ForestTile(vector.Offset(pos, 0, 64), 'P', 2.0, attr)
	ForestTile(pos, 'Y', 2.0, attr)
end

local function TopPlanks(pos, flipH)
	local dx = 64
	flipH = not(not(flipH))
	if flipH then dx = 0 end
	local attr = { flip = { flipH, false } }
	ForestTile(vector.Offset(pos, 64 - dx, 0), '6', -2.1, attr)
	ForestTile(vector.Offset(pos, dx, 0), '7', -2.1, attr)
end

function GravelOcclude(id, x, y)
	while y >= -400 do
		Occlusion.put(id, x, y, 3.5, { size={512, 64} })
		y = y - 64 
	end
end

function MineEntrance(pos)
	shape.Line({ pos.x, pos.y }, { pos.x + 512, pos.y - 16 }, "Box")
	Tree(vector.Offset(pos, 64, 0), 1, -1.0, 0.9)
	Tree(vector.Offset(pos, 120, -16), 2, -1.1, 0.75)
	Tree(vector.Offset(pos, 160, -32), 1, 1.0, 0.6)
	Tree(vector.Offset(pos, 200, -48), 2, -1.1, 0.5)
	pos = LongGrass(pos)
	pos = EndGrass(pos)
	PileOfBoulders(vector.Add(pos, {x=16,y=-16}), 64, 16, "no-shape")
	PileOfBoulders(vector.Add(pos, {x=70,y=-16}), 32, 512, "no-shape")
	PileOfBoulders(vector.Add(pos, {x=0,y=128}), 128, 400, "no-shape", -4.0)
	FrontBeam(vector.Add(pos, {x=0,y=-64}))
	BackBeam(vector.Add(pos, {x=-44,y=-64}))
	TopPlanks(vector.Add(pos, {x=-64,y=140}))
	shape.Line({ pos.x - 32, pos.y + 175 }, 
		   { pos.x, pos.y + 512 }, "Box")
	shape.Line({ pos.x - 32, pos.y + 175 }, 
		   { pos.x + 192, pos.y + 165 }, "Box")
	shape.Line({ pos.x + 192, pos.y + 175 }, 
		   { pos.x + 224, pos.y - 16 }, "Box")
	Gravel(vector.Add(pos, { x = 0, y = -64 }))
 	for i = 0, 512, 64 do
		Gravel(vector.Add(pos, { x = i + 64, y = 512 }))
	end
	GravelOcclude('a', pos.x + 128, pos.y + 512)
	ExitRoom({l=pos.x+160, b=pos.y, r=pos.x+176, t=pos.y+160 }, 
		 "Mine2", { 64, 0 }, nil, nil, nil, eapi.SLIDE_RIGHT)
end

local function CavernEntrance(pos)
	shape.Line({ pos.x, pos.y + 8 }, { pos.x - 512, pos.y - 8 }, "Box")
	FrontBeam(vector.Add(pos, {x=-80,y=-56}), true)
	BackBeam(vector.Add(pos, {x=44-80,y=-56}), true)
	TopPlanks(vector.Add(pos, {x=-80,y=148}), true)
	shape.Line({ pos.x, pos.y + 183 }, 
		   { pos.x + 32, pos.y + 512 }, "Box")
	shape.Line({ pos.x + 32, pos.y + 183 }, 
		   { pos.x - 192, pos.y + 173 }, "Box")
	shape.Line({ pos.x - 192, pos.y + 183 }, 
		   { pos.x - 224, pos.y - 8 }, "Box")
	Gravel(vector.Add(pos, { x = -64, y = -64 }))
 	for i = -128, -768, -64 do
		Gravel(vector.Add(pos, { x = i, y = 512 }))
	end
	GravelOcclude('b', pos.x - 768, pos.y + 512)
	PileOfBoulders(vector.Add(pos, {x=-96,y=-16}), 64, 32, "no-shape")
	PileOfBoulders(vector.Add(pos, {x=-96,y=-16}), 32, 512, "no-shape")
	PileOfBoulders(vector.Add(pos, {x=-64,y=128}), 64, 400, "no-shape", -4.0)
	ExitRoom({l=pos.x-176, b=pos.y, r=pos.x-160, t=pos.y+160 }, 
		 "Mine1", { 320, 0 }, nil, nil, nil, eapi.SLIDE_LEFT)
end

local function PutBoulder(pos)
	local size = { x = 192, y = 192 }
	local img = eapi.NewSpriteList("image/boulder.png", {{0, 0}, size})
	return eapi.NewTile(staticBody, pos, size, img, 1)
end

local start = { x=-10500, y=512 }

if game.GetState().spaceShipLandedOn == "Forest" then
	if game.GetState().boulderCutscene then
		PutBoulder(vector.Add(start, { x=-126, y=-2 }))
	else
		mainPC.DisableInput()
		util.CameraTracking.call(nil)
		game.GetState().boulderCutscene = true
		
		local tile = PutBoulder(vector.Add(start, { x=-200, y=-2 }))
		eapi.SetPos(camera.ptr, vector.Add(start, { x=100, y=88 }))

		local function BackToPlayer()
			util.CameraTracking.call(mainPC)
			mainPC.EnableInput()
		end

		local function PushBoulder()
			local pos = eapi.GetPos(tile)
			if pos.x < start.x - 126 then
				pos.x = pos.x + 1
				eapi.SetPos(tile, pos)
				eapi.AddTimer(gameWorld, 0.05, PushBoulder)
			else
				eapi.AddTimer(gameWorld, 0.5, BackToPlayer)
			end
		end
		PushBoulder()
	end
	shape.Line(vector.Add(start, { x=20, y=183 }),
		   vector.Add(start, { x=-30, y=-8 }), "Box")	
end

local lastRowElem = nil
local function RowOfItems(pos, offset, symbols, n, attr, depth)
	local candidate = RandomElement(symbols)
	if lastRowElem == candidate then
		return RowOfItems(pos, offset, symbols, n, attr, depth)
	end
	lastRowElem = candidate
	ForestTile(pos, candidate, depth or 3.0, attr, forestMoreTexture)
	if n > 0 then
		local newPos = vector.Add(pos, offset)
		RowOfItems(newPos, offset, symbols, n - 1, attr, depth)
	end
end

local function GravelBottomRow(bb, attrib, depth)
	local n = math.floor((bb.r - bb.l) / 64)
	RowOfItems({x = bb.l, y = bb.b}, {x = 64, y = 0},
		   {'b', 'c', 'd'}, n, attrib, depth)
end

local function DarkBottomRow(bb)
	GravelBottomRow(bb, dark, -3.0)
end

local function GravelTopRow(bb, attrib, depth)
	local n = math.floor((bb.r - bb.l) / 64)
	RowOfItems({x = bb.l, y = bb.b}, {x = 64, y = 0}, 
		   {'H', 'I', 'J'}, n, attrib, depth)
end

local function DarkTopRow(bb)
	GravelTopRow(bb, dark, -3.0)
end

local function GravelLeftColumn(bb, attrib, depth)
	local n = math.floor((bb.t - bb.b) / 64)
	RowOfItems({x = bb.l, y = bb.b}, {x = 0, y = 64},
		   {'m', 'u', 'C'}, n, attrib, depth)
end

local function DarkLeftColumn(bb)
	GravelLeftColumn(bb, dark, -3.0)
end

local function GravelRightColumn(bb, attrib, depth)
	local n = math.floor((bb.t - bb.b) / 64)
	RowOfItems({x = bb.l, y = bb.b}, {x = 0, y = 64},
		   {'i', 'q', 'y'}, n, attrib, depth)
end

local function DarkRightColumn(bb)
	GravelRightColumn(bb, dark, -3.0)
end

local function GravelTile(pos, id, z)
	ForestTile(pos, id, z or 3.0, nil, forestMoreTexture)
end

local function GravelNECorner(pos) GravelTile(pos, 'e') end

local function GravelNWCorner(pos) GravelTile(pos, 'a') end

local function GravelGrassECorner(pos) GravelTile(pos, 'k', 5) end

local function GravelGrassWCorner(pos) GravelTile(pos, 'j', 5) end

local function GravelSECorner(pos) GravelTile(pos, 'K') end

local function GravelSWCorner(pos) GravelTile(pos, 'G') end

local function FixBB(bb)
	local bbb = { b = bb.b, t = bb.t, l = bb.l, r = bb.r }
	bbb.b = bb.t - 64 * math.floor((bb.t - bb.b - 1) / 64)
	bbb.r = bb.l + 64 * math.floor((bb.r - bb.l - 1) / 64)
	return bbb
end

local function CompleteBlock(bb)
	bb = FixBB(bb)
	GravelBlock(bb, nil, 1.0)
	GravelTopRow({ t = bb.b - 64, b = bb.b - 64, l = bb.l, r = bb.r })
	GravelBottomRow({ t = bb.t + 64, b = bb.t + 64, l = bb.l, r = bb.r })
	GravelLeftColumn({ t = bb.t, b = bb.b, l = bb.r + 64, r = bb.r + 64 })
	GravelRightColumn({ l = bb.l - 64, r = bb.l - 64, t = bb.t, b = bb.b })
	GravelSWCorner({ x = bb.l - 64, y = bb.b - 64 })
	GravelNWCorner({ x = bb.l - 64, y = bb.t + 64 })
	GravelSECorner({ x = bb.r + 64, y = bb.b - 64 })
	GravelNECorner({ x = bb.r + 64, y = bb.t + 64 })
	return bb
end

local function BlockTexture()
	local offset = util.Random(0, 2) * 64
	return { image = "image/forest.png",
		 spriteOffset = { x = 256 + offset, y = 64 } }
end

local blockTable = { m = true, n = true, o = true }

local function ShootableGravelBlock(bb, block)
	bb = FixBB(bb)
	local tileSet = { }
	local w = bb.r - bb.l + 64
	local h = bb.t - bb.b + 64
	local zz = 5 + util.Random()
	local OldPutTile = util.PutTileWithAttribute
	local function NewPutTile(body, id, img, pos, z, ...)
		local tile = OldPutTile(block.body, id, img, pos, zz, ...)
		tileSet[tile] = id
		return tile
	end
	util.PutTileWithAttribute = NewPutTile
	CompleteBlock({ l = 0, b = -64, r = w, t = h - 64 })
	util.PutTileWithAttribute = OldPutTile
	block.ShatterTest = function(tile, id) return not(blockTable[id]) end
	block.shape = { l = 0, b = 0, r = w, t = h }
	block.Texture = BlockTexture
	block.health = 5
	return tileSet
end

local function ShootableBlock(bb)
	common.ShootableBlock(bb, ShootableGravelBlock)
end

local dustColor = { r = 0.63, g = 0.51, b = 0.42 }
local function BeamBridge(bb, dir)
	local dust
	local angle = 0
	local acceleration = -0.01 * dir
	local finishAngle = 0.5 * math.pi
	local middle = 0.5 * (bb.r - bb.l)
	local pivot = { x = bb.l + middle, y = bb.b + middle }
	local body = eapi.NewBody(gameWorld, pivot)
	local tilePos = { x = -middle, y = -middle }
	local tileSize = { x = bb.r - bb.l, y = bb.t - bb.b }
	local tile = eapi.NewTile(body, tilePos, tileSize, fallBeam.img, -1)
	eapi.SetAttributes(tile, { flip = { dir > 0, false } })
	local upShape = { l = -middle, r = tileSize.x - middle,
			  b = -middle, t = tileSize.y - middle }
	local downShape = { b = -middle, t = tileSize.x - middle - 8 }
	downShape.l = (dir < 0 and -middle) or (middle - tileSize.y)
	downShape.r = (dir < 0 and tileSize.y - middle) or middle
	local shape = eapi.NewShape(body, nil, upShape, "Box")
	
	local dustPos = { x = ((dir < 0) and bb.l) or bb.r, y = bb.b }
	dustPos.x = dustPos.x + ((dir < 0 and downShape.r) or downShape.l)

	local function Fall()
		angle = angle - acceleration
		angle = math.max(angle, -finishAngle)
		angle = math.min(angle, finishAngle)		
		acceleration = 1.05 * acceleration
		eapi.SetAttributes(tile, { angle = angle })
		if math.abs(angle) < finishAngle then
			eapi.AddTimer(body, 0.03, Fall)
		else
			eapi.NewShape(body, nil, downShape, "OneWayGround")
			eapi.Destroy(shape)
			mainPC.StartInput()
			dust = effects.Smoke(dustPos,
					     { vel = {x = dir * 75, y = 75 },
					       disableProximitySensor = true,
					       color = dustColor,
					       interval = 0.01,
					       variation = 180,
					       life = 1.0,
					       z = -0.5, })
			eapi.AddTimer(body, 1.0, dust.Stop)
			eapi.PlaySound(gameWorld, "sound/thud.ogg", 0, 0.5)
			dust.Kick()
		end
	end
	local activator
	local function PushLog()
		mainPC.StopInput()
		action.DeleteActivator(activator)
		local pos = eapi.GetPos(mainPC.body)
		pos = vector.Add(pos, { x = -32 * dir, y = 32 })
		action.PutHitSpark(pos, 0.5)
		eapi.PlaySound(gameWorld, "sound/punch.ogg")
		eapi.PlaySound(gameWorld, "sound/squeak.ogg")
		Fall()
	end
	local pushShape = { l = dir * middle - 16, r = dir * middle + 16,
		            b = -middle, t = -middle + tileSize.y }
	activator = action.MakeActivator(pushShape, PushLog, nil, body, true)
end

local function BeamBridgeLeft(bb)
	BeamBridge(bb, 1)
end

local function BeamBridgeRight(bb)
	BeamBridge(bb, -1)
end

local woodPlatform = eapi.NewSpriteList("image/forest-more.png", 
					{{ 384, 0 }, { 128, 32 }})

local function WoodenPlatform(bb, Control, yPos)
	local function Create(platform)
		local body = platform.body
		eapi.NewTile(body, nil, nil, woodPlatform, -2.5)
		local shape = { b = 0, t = 24, l = 24, r = 104 }		
		platform.shape =  eapi.NewShape(body, nil, shape, "Platform")
		return { l = -Infinity, r = Infinity, b = bb.b, t = bb.t }
	end
	local vel = { x = 0, y = -100 }
	local yRandom = bb.b + util.Random() * (bb.t - bb.b)
	local pos = { x = bb.l, y = yPos or yRandom } 
	local platform = util.CreateSimplePlatform(pos, vel, Create, Control)
	return platform
end

local bigWaspPlatform
local function BigWaspPlatform(bb)
	bigWaspPlatform = WoodenPlatform(bb, true, bb.t)	
end

local function StartBigWaspPlatform()
	game.GetState().bigWaspDead = true
	bigWaspPlatform.ctrl = nil
	bigWaspPlatform.up()	
end

local function BigWasp(pos)
	if not game.GetState().bigWaspDead then
		bigWasp.Put(pos.x, pos.y, StartBigWaspPlatform)
	else
		eapi.AddTimer(staticBody, 0, StartBigWaspPlatform)
	end
end

eapi.Collide(gameWorld, "Player", "PondBottom",
	     destroyer.Player_vs_PondBottom, 10)

local WaypointDown = action.WaypointFunction("down")

local function TreeCenter(pos)
	return { x = 0, y = -0.5 * pos[2] }
end

local function FallenTree(pos, dir, num, dim)
	local body = eapi.NewBody(gameWorld, pos)
	Tree(TreeCenter(elmSizes[num]), num, -1.0, dim or 0.99,
	     { angle = 0.5 * (dir or 1) * math.pi }, body)
end

local function FireWood(pos)
	local function CalculateAngle()
		return math.pi * (0.4 + 0.2 * util.Random())
	end
	common.FireWood(pos, CalculateAngle, 5)
end

local function Stompade(bb, height)
	local body = nil

	local function PlaceBeam(pos)
		fallBeam.Put({ x = pos.x, 
			       y = bb.b + height,
			       vel = { x = 0, y = -500 },
			       top = 128 })
	end

	local function DelayBeam()
		if body and not(mainPC.dead) then 
			local pos = eapi.GetPos(mainPC.body)
			eapi.AddTimer(body, .45, function() PlaceBeam(pos) end)
			eapi.AddTimer(body, .45, DelayBeam)
		end
	end

	local function Start()
		if not(body) then
			body = eapi.NewBody(gameWorld, { x = bb.l, y = bb.b })
			eapi.SetAttributes(body, { sleep = false })
			DelayBeam()
		end
	end

	local function Stop()
		if body then
			eapi.Destroy(body)
			body = nil
		end
	end
	
	proximity.Create(Start, Stop, nil, bb)
end

local function HorizontalWoodenPlatform(bb)
	local platform
	local activator	
	local direction = 1
	local comeback = nil
	local function ChangeDirection()
		if direction > 0 then 
			platform.up()
		else
			platform.down()
		end
		direction = -direction
	end
	local function ComeBack()
		ChangeDirection()
		action.DeleteActivator(comeback)
		comeback = nil
	end
	local function Move()
		ChangeDirection()
		local box = { b = bb.b, t = bb.b + 256 }
		if platform.vel.x < 0 then
			box.l = bb.r + 192
			box.r = bb.r + 200
		else
			box.l = bb.l - 40
			box.r = bb.l - 32
		end
		comeback = action.MakeActivator(box, ComeBack, nil, body, true)
		action.DeleteActivator(activator)
	end
	local function Control(platform)		
		local body = platform.body
		local box = { b = 24, t = 32, l = 48, r = 80 }
		if comeback then action.DeleteActivator(comeback) end
		activator = action.MakeActivator(box, Move, nil, body, true)
	end
	local function Create(platform)
		local body = platform.body
		eapi.SetAttributes(body, { sleep = false })
		eapi.NewTile(body, nil, nil, woodPlatform, -2.5)
		local shape = { b = 0, t = 24, l = 24, r = 104 }		
		platform.shape =  eapi.NewShape(body, nil, shape, "Platform")
		return { l = bb.l, r = bb.r, b = -Infinity, t = Infinity }
	end
	local fromMine1 = (game.GetState().previousRoom == "Mine1")
	local vel = { x = (fromMine1 and 100) or -100, y = 0 }
	local pos = { x = (fromMine1 and bb.l) or bb.r, y = bb.b } 
	platform = util.CreateSimplePlatform(pos, vel, Create, Control)
end

local function CompleteGravelBlock(bb)
	local shape = CompleteBlock(bb)
	shape.t = shape.t + 64
	shape.r = shape.r + 64
	eapi.NewShape(staticBody, nil, shape, "Box")
end

local stickImg = { }
for i = 1, 3, 1 do
	local box = { { i * 64, 128 }, { 64, 64 } }
	stickImg[i] = eapi.NewSpriteList("image/forest-more.png", box)
end
local function RowOfKillerSticks(bb)
	local last = 1
	local length = bb.r - bb.l
	local function PutSticks(x)
		local n = util.Random(1, 3)
		if n == last then n = (n + 1) % 3 end
		local pos =  { x = bb.l + x, y = bb.b }
		eapi.NewTile(staticBody, pos, nil, stickImg[n], 1)
		if x < length - 64 then
			PutSticks(x + util.Random(48, 64))
		end
	end
	PutSticks(0)

	local info = { pos = { x = bb.l, y = bb.b }, w = length, h = 48 }
	local shape = { l = bb.l + 16, r = bb.r - 16, b = bb.b, t = bb.b + 48 }
	local shapeObj = eapi.NewShape(staticBody, nil, shape, "KillerActor")
	eapi.pointerMap[shapeObj] = info
end

local function IterateInvaders(Fn)
	for i = 1, 5, 1 do
		for j = 1, 3, 1 do
			Fn(i, j)
		end
	end
end

local function PutInvaders(pos, TheEnd)
	local invaders = { }
	IterateInvaders(function(i, j)
		if j == 1 then invaders[i] = { } end
		local x = pos.x + 100 * i
		local y = pos.y + 100 * j
		invaders[i][j] = wasp.Put({ x = x, y = y }, false, "invader")
		invaders[i][j].MaybeActivate()
	end)
	local function Bombard()
		local dead = 0
		if mainPC.dead then return end
		local distance = 1000000000
		local closest = { i = 1, j = 1 }
		IterateInvaders(function(i, j)
			local obj = invaders[i][j]
			if obj.dead then
				dead = dead + 1
			else
				local len = action.DistanceToPlayer(obj)
				len = math.abs(len) + j
				if len < distance then
					distance = len
					closest = { i = i, j = j }
				end
			end			
		end)
		if distance == 1000000000 then
			TheEnd()
			return
		elseif distance < 128 then
			local attacker = invaders[closest.i][closest.j]
			attacker.EmitFireBall({ x = 0, y = -400 })
		end
		local timeout = ((dead > 7) and 1) or 2
		eapi.AddTimer(staticBody, timeout, Bombard)
	end
	eapi.AddTimer(staticBody, 3, Bombard)
end

local function Invaders(pos)
	local activator
	local bottom = pos.y - 250
	local function BB(n)
		return { l = pos.x + n, r = pos.x + n + 1, 
			 b = bottom, t = pos.y + 90 }
	end
	local function MakePlatforms()
		WoodenPlatform(BB(-120), nil, bottom + 1)
		WoodenPlatform(BB( 790), nil, bottom + 1)
	end
	local function TheEnd()
		eapi.AddTimer(staticBody, 1, MakePlatforms)
		game.GetState().invadersComplete = true
	end	
	local function Put()		
		PutInvaders(pos, TheEnd)
		action.DeleteActivator(activator)
	end
	if game.GetState().invadersComplete then
		Put = util.Noop
		TheEnd()
	end
	local MakeNotice = wood.Notice(txt.invaderNotice, Put)
	activator = MakeNotice(vector.Offset(pos, 400, -200))
end

local function Charlie(pos)
	local img = eapi.TextureToSpriteList("image/charlie.png", { 64, 128 })
	local tile = eapi.NewTile(staticBody, pos, nil, img, -0.5)
	eapi.Animate(tile, eapi.ANIM_LOOP, 16)
	eapi.SetAttributes(tile, { flip = { true, false } } )
	local shape = { l = pos.x + 32 - 8, b = pos.y + 64 - 8, 
			r = pos.x + 32 + 8, t = pos.y + 64 + 8 }
	if game.GetState().spaceShipLandedOn == "Forest" then
		action.MakeMessage(txt.charlie, shape, txt.charlieTalk1)
	else
		action.MakeMessage(txt.charlie, shape, txt.charlieTalk2)
	end
end

local exports = {
	Tree = {func=Tree,points=1,hide=true},
	FallenTree = {func=FallenTree,points=1,hide=true},
	Boulder = {func=Boulder,points=1,hide=true},
	GrassTop = {func=ForestTile,points=1,hide=true},
	LandingZone = {func=LandingZone,points=1,hide=true},
	MineEntrance = {func=MineEntrance,points=1,hide=true},
	ForestTile = {func=ForestTile,points=1,hide=true},
	Gravel = {func=Gravel,points=1,hide=true},
	HealthPlus = {func=destroyer.HealthPlus(5, true),points=1,hide=true},
	Kicker = {func=action.MakeKicker,points=2,hide=false},
	Wasp = {func=wasp.Put,points=1,hide=false},
	BigWasp = {func=BigWasp,points=1,hide=true},
	EditBoulder = {func=EditBoulder,points=1,hide=true},
	GravelBlock = {func=GravelBlock,points=2},
	Blocker = {func=common.Blocker,points=2,hide=false},
	DarkBlock = {func=DarkBlock,points=2,hide=false},
	DarkBottomRow = {func=DarkBottomRow,points=2,hide=false},
	DarkTopRow = {func=DarkTopRow,points=2,hide=false},
	DarkLeftColumn = {func=DarkLeftColumn,points=2,hide=false},
	DarkRightColumn = {func=DarkRightColumn,points=2,hide=false},
	GravelBottomRow = {func=GravelBottomRow,points=2,hide=false},
	GravelTopRow = {func=GravelTopRow,points=2,hide=false},
	GravelLeftColumn = {func=GravelLeftColumn,points=2,hide=false},
	GravelRightColumn = {func=GravelRightColumn,points=2,hide=false},
	GravelGrassWCorner = {func=GravelGrassWCorner,points=1,hide=false},
	GravelGrassECorner = {func=GravelGrassECorner,points=1,hide=false},
	GravelNWCorner = {func=GravelNWCorner,points=1,hide=false},
	GravelNECorner = {func=GravelNECorner,points=1,hide=false},
	GravelSWCorner = {func=GravelSWCorner,points=1,hide=false},
	GravelSECorner = {func=GravelSECorner,points=1,hide=false},
	ShootableBlock = {func=ShootableBlock,points=2,hide=true},
	BeamBridgeLeft = {func=BeamBridgeLeft,points=2,hide=true},
	BeamBridgeRight = {func=BeamBridgeRight,points=2,hide=true},	
	RibCage = {func=common.RibCage,points=1,hide=true},
	Skull = {func=common.Skull,points=1,hide=true},
	CompleteGravelBlock = {func=CompleteGravelBlock, points=2,hide=false},
	FloatingBarrel = {func=common.FloatingBarrel,points=1,hide=true},
	WoodenPlatform = {func=WoodenPlatform,points=2,hide=false},
	BigWaspPlatform = {func=BigWaspPlatform,points=2,hide=true},
	AcidVapor = {func=common.AcidVapor,points=1, hide=true},
	AcidPool = {func=common.AcidPool,points=2, hide=true},
	AcidBarrel = {func=common.AcidBarrel,points=1,hide=true},
	WaypointDown = {func=WaypointDown,points=1, hide=true},
	FallingBeam = {func=fallBeam.Put,points=1,hide=true},
	BackLog = {func=wood.Log(-1.5),points=1,hide=true},
	FireWood = {func=FireWood,points=1,hide=true},
	Fire = {func=common.Fire,points=1,hide=true},
	Stompade = {func=Stompade,points=2,hide=true},
	WaterDrop = {func=common.Rain,points=2,hide=true},
	Invaders = {func=Invaders,points=1,hide=true},
	Charlie = {func=Charlie,points=1,hide=false},

	RowOfKillerSticks = {func=RowOfKillerSticks,points=2,hide=false},

	RunTunnelNotice = {func=wood.Notice(txt.runTunnelNotice),
			   points=1, hide=true},
	HorizontalAcidBarrel = {func=common.HorizontalAcidBarrel,
				points=1, hide=true},
	HorizontalWoodenPlatform = {func=HorizontalWoodenPlatform,
				    points=2, hide=true},
}

if util.msg == "FromNiche" then	
	util.msg = nil
	forest = exports
	return forest
else
	editor.Parse("script/Forest-edit.lua", gameWorld, exports)
	eapi.PlaySound(gameWorld, "sound/forest.ogg", -1, 0.5)
	CavernEntrance(start)

	Occlusion.passage(-1550, -120, -0.1, "Niche1",
			  { -86, -113 }, txt.niche, eapi.ZOOM_OUT)
	Occlusion.passage(10600, -180, -0.1, "Niche2",
			  { 96, -113 }, txt.niche, eapi.ZOOM_OUT)
	
	if game.GetState().startLives > 1 then		
		savePoint.Put({x=13610,y=-250})
	end

	util.PreloadSound({ "sound/thud.ogg",
			    "sound/wasp.ogg",
			    "sound/squeak.ogg" })
end
