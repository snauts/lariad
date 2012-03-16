dofile("script/save-point.lua")
dofile("script/exit.lua")
dofile("script/occlusion.lua")
dofile("script/Slabs.lua")
dofile("script/action.lua")
dofile("script/komodo.lua")
dofile("script/shape.lua")
dofile("script/spaceship.lua")
dofile("script/spider.lua")
dofile("script/Common.lua")
dofile("script/wood.lua")
dofile("script/rope.lua")

LoadPlayers()
local levelDimensions = { l=-20000, r=12000, b=-1000, t=5000 }
camera = util.CreateCamera(gameWorld, mainPC, levelDimensions)
eapi.SetBackgroundColor(gameWorld, {r = 0.25, g = 0.30, b = 0.4})

eapi.RandomSeed(42)
staticBody = eapi.GetStaticBody(gameWorld)

shape.Line({ -20000, 0 }, { 12000, -350 }, "Box")

local function MountainParallax()
	-- mountain range of "aliasing artifacts"
	local texture = {"image/mountains.png", filter=true}
	local strip1 = eapi.NewSpriteList(texture, {{0, 0},   {1024, 128}})
	local strip2 = eapi.NewSpriteList(texture, {{0, 128}, {1024, 256}})
	local strip3 = eapi.NewSpriteList(texture, {{0, 384}, {1024, 512}})

	local sky = eapi.NewSpriteList(texture, {{0, 896}, {1024, 15}})
	local blue = eapi.NewSpriteList(texture, {{0, 928}, {1024, 32}})
	local fog = eapi.NewSpriteList(texture, {{0, 960}, {1024, 64}})
	local block = eapi.NewSpriteList(texture, {{0, 916}, {1024, 8}})
	
	local px

	px = eapi.NewParallax(gameWorld, strip3, nil, {0, -450}, {1.1, 1.2}, 10)
	eapi.SetRepeatPattern(px, {true, false}, {0.0, 0.0})
	
	px = eapi.NewParallax(gameWorld, strip2, nil, {0, -50}, {0.9, 1.0}, -11)
	eapi.SetRepeatPattern(px, {true, false}, {0.0, 0.0})
	
	px = eapi.NewParallax(gameWorld, strip1, nil, {0, 100}, {0.5, 0.8}, -13)
	eapi.SetRepeatPattern(px, {true, false}, {0.0, 0.0})

	px = eapi.NewParallax(gameWorld, fog, nil, {0, -17}, {1.0, 1.0}, 5)
	eapi.SetRepeatPattern(px, {true, false}, {0.0, 0.0})

	px = eapi.NewParallax(gameWorld, block, {1024, 256},
			      {0, -17-256}, {1.0, 1.0}, 5)
	eapi.SetRepeatPattern(px, {true, false}, {0.0, 0.0})

	px = eapi.NewParallax(gameWorld, blue, {30000,6000},
			      {-20000, -1000}, {1, 1}, -10)
	px = eapi.NewParallax(gameWorld, blue, {30000,6000},
			      {-20000, -1000}, {1, 1}, -12)
	px = eapi.NewParallax(gameWorld, sky, {25000,2500},
			      {-13000, 250}, {0.1, 0.8}, -9)
	eapi.SetRepeatPattern(px, {false, false}, {0.0, 0.0})
end

MountainParallax()

local tx = eapi.NewSpriteList({ "image/forest-bg.png" }, {{0,512},{512,512}})
local px = eapi.NewParallax(gameWorld, tx, nil, {0, 1900}, {0.1, 0.8}, -4.5)
eapi.SetRepeatPattern(px, { true, false })

local Jump = action.WaypointFunction("jump")
local BackJump = action.WaypointFunction("jump-back")

local function RowOfSlabs(x, y, n, d, offset)
	slab.Small(x, y, d)
	slab.PotLamp(x + 48, y + 58, -0.1)
	Jump({ x = x + 4, y = y + 130 })
	Jump({ x = x + 124, y = y + 70 })
	BackJump({ x = x + 4, y = y + 80 })
	BackJump({ x = x + 124, y = y + 20 })
	for i = 1, n, 1 do
		x = x - 245
		d = d - 0.00001
		slab.Big(x, y, d)
		if i > offset then
			slab.Small(x - 64, y + 96, d  - 0.00002, slab.dark, 0)
		else
			slab.Small(x - 64, y + 56, d  - 0.00002, slab.dark, 0)
		end
	end
end

local function PyramidEntrance(x, y)
	for i = 0, 3, 1 do
		local tmp = 0.5
		slab.Small(x, y + 42 + i * 58, -0.5, nil, 0)
		slab.Small(x - 60, y + i * 58, 1.5, nil, 0)
		Occlusion.put('f', x - 4, y + i * 64 + 4, 0.1)
		Occlusion.put('b', x + 60, y + i * 64 - 12, 0.1)
		for j = 1, 3, 1 do
			slab.Small(x - 240*j - 64, y + i*116 - 32, -3, nil, 0)
			slab.Big(x - 240*j - 40, y + i*116 - 4, tmp, nil, 0)
			tmp = tmp - 0.01
		end
	end
	slab.Small(x - 60, y - 58, 1.5, nil, 0)
	slab.Small(x + 64, y - 58, 1.5, nil, 0)
	slab.Big(x - 100, y + 220, 0.6, nil, 0)
	shape.Line({x - 150, y}, {x - 100, y + 220}, "Box")
	shape.Line({x - 100, y + 220}, {x + 100, y + 270}, "Box")
	ExitRoom({ l=x-1, t=y+200, r=x, b=y }, "Pyramid", {-50 ,140},
		 nil, nil, nil, eapi.SLIDE_LEFT)
end

local function PyramidWall(x, y, n, d)
	slab.Lamp(x + 950, -10, -0.1)
	for i = 1, n, 1 do
		local offset = util.Random(0, 2)
		RowOfSlabs(x, y, 10, d, offset);
		d = d + 0.001
		y = y + 116
		x = x - (248 + 256 * offset)
	end
	RowOfSlabs(x, y, 10, d, 2);
	y = y + 116
	x = x - 760
	PyramidEntrance(x - 40, y - 4)
	slab.Lamp(x + 300, y , -0.1)
	slab.Lamp(x + 550, y , -0.1)
end

PyramidWall(0, -16, 20, -1)

-- spaceship
if game.GetState().spaceShipLandedOn == "Rocks" then
	Spaceship(9000, 0)
end

local function Epsilon(pos)
	return pos.y * 0.00001 - pos.x * 0.000001
end

local function SmallSlab(pos)
	slab.Small(pos.x, pos.y, -1.5 + Epsilon(pos), slab.darker, 0)
end	

local function SlabWall(bb)
	-- exports.SlabWall.func({l=4401,r=6249,b=-2,t=901})
	local offset = 0
	for y = bb.b, bb.t - 56, 56 do
		for x = bb.l, bb.r - 120, 120 do
			SmallSlab({ x = x + offset, y = y })
		end
		offset = ((offset == 0) and 64) or 0
	end
	Occlusion.Blackness(bb)
end

local function FrontSlab(pos)
	local epsilon = pos.y * 0.00001 - pos.x * 0.000001
	slab.Small(pos.x, pos.y, 1.1 + Epsilon(pos))
end	

local function BigSlab(pos, z)
	slab.Big(pos.x, pos.y, 1.1 + Epsilon(pos))
end

local function Lamp(pos, z)
	slab.PotLamp(pos.x, pos.y, z or 2.0)
end

local function CryptExit(box)
	ExitRoom(box, "Crypt", {-170, 0}, nil, nil, nil, eapi.SLIDE_RIGHT)
end

local vlog = eapi.NewSpriteList({"image/swamp.png"}, {{192, 384}, {32, 128}})
local hlog = eapi.NewSpriteList({"image/swamp.png"}, {{256, 384}, {128, 32}})

local function VerticalLog(pos)
	eapi.NewTile(staticBody, pos, nil, vlog, 1.0 - pos.y / 10000)
end

local function BackVerticalLog(pos)
	eapi.NewTile(staticBody, pos, nil, vlog, -1.0 - pos.y / 10000)
end

local function LongVerticalLog(pos)
	for i = 0, 5, 1 do
		VerticalLog({ x = pos.x, y = pos.y + i * 100 })
	end
end

local function HorizontalLog(pos, z)
	eapi.NewTile(staticBody, pos, nil, hlog, (z or 1) - pos.y / 10000)
	shape.Line({pos.x, pos.y+22}, {pos.x+128, pos.y+12}, "OneWayGround")
end

local graveImg = { }
for i = 1, 4, 1 do
	local frame = { { 257, (i - 1) * 64 + 1 }, { 62, 62 } }
	local filename = { "image/pyramid.png", filter = true }
	graveImg[i] = eapi.NewSpriteList(filename, frame)
end
local function GraveStone(pos, id, angle, text, color)
	id = id or util.Random(1, 4)
	local offset = { x = -32, y = -32 }
	local body = eapi.NewBody(gameWorld, pos)
	local tile = eapi.NewTile(body, offset, nil, graveImg[id], -3)
	eapi.SetAttributes(tile, { angle = angle, color = color })

	if text then
		local box = { l = -8, r = 8, b = -8, t = 8 }
		return action.MakeMessage(txt.grave, box, text, nil, body)
	end
end

local function GraveStoneInfo(pos)
	GraveStone(pos, 1, -0.4, txt.graveInfo, {r=0.7, g=0.7, b=0.7})
end

local function GraveStoneHead(pos)
	GraveStone(pos, 3, 0.3, txt.graveHead, {r=0.8, g=0.8, b=0.9})
end

local function GraveStoneKomodo(pos)
	GraveStone(pos, 4, 0.5, txt.graveKomodo, {r=0.7, g=0.7, b=0.8})
end

local function LogPlatform(bb)
	local function Create(platform)
		local body = platform.body
		eapi.NewTile(body, nil, nil, hlog, 1.0)
		local shape = { b = 12, t = 22, l = 0, r = 128 }		
		platform.shape =  eapi.NewShape(body, nil, shape, "Platform")
		return { l = -Infinity, r = Infinity, b = bb.b, t = bb.t }
	end
	local vel = { x = 0, y = 100 }
	local pos = { x = bb.l, y = bb.b } 
	local platform = util.CreateSimplePlatform(pos, vel, Create)
	return platform
end

local flagImg = eapi.TextureToSpriteList("image/ant-flag.png", {128, 256})

local function Flag(pos, z)
	local tile = eapi.NewTile(staticBody, pos, nil, flagImg, z or 0.5)
	eapi.Animate(tile, eapi.ANIM_LOOP, util.Random(8, 16), util.Random())
end

local function Ladder(bb)
	for i = bb.b, bb.t, 48 do
		rope.Vertical({ x = bb.l - 10, y = i })
		rope.Vertical({ x = bb.l + 70, y = i })
	end
	for i = bb.b + 50, bb.t, 100 do
		HorizontalLog({ x = bb.l, y = i })
	end
end

local Barracks = wood.Notice(txt.barracksInfo, nil, txt.barracks)
local Temple   = wood.Notice(txt.templeNotice, nil, txt.temple)
local Sickhouse = wood.Notice(txt.sickhouseInfo, nil, txt.sickhouse)
local Urgent = wood.Notice(txt.urgentInfo, nil, txt.urgent)

local deadTreeFrame = { { 0, 256 }, { 320, 256 } }
local deadTreeImg = eapi.NewSpriteList("image/pyramid.png", deadTreeFrame)
local function DeadTree(pos)
	eapi.NewTile(staticBody, pos, nil, deadTreeImg, -2)
end

local flaskImg = { }
for i = 1, 2, 1 do
	local frame = { { 96 + 32 * i, 0 }, { 32, 32 } }
	flaskImg[i] = eapi.NewSpriteList("image/inventory-items.png", frame)
end
local function FlaskPicture(i)
	return { image		= "image/inventory-items.png",
		 spriteOffset	= { x = 96 + 32 * i, y = 0 } }
end
local function Flask(pos, i)
	local flask = { }
	flask.shouldSpark = true
	flask.gravity = { x = 0, y = -1500 }
	flask.body = eapi.NewBody(gameWorld, pos)
	flask.shape = { l = 8, r = 24, b = 8, t = 24 }
	flask.tile = eapi.NewTile(flask.body, nil, nil, flaskImg[i or 1], 0.5)
	flask.Shoot = function(projectile)
		eapi.PlaySound(gameWorld, "sound/glass.ogg")	
		effects.Shatter(FlaskPicture(i or 1), flask, 
				action.BlowUp(300), 0.5)
		weapons.DeleteProjectile(projectile)
		eapi.Destroy(flask.body)
	end
	action.MakeActorShape(flask)
	object.DoNotHalt(flask)
end

local spikeImg = { }
for i = 1, 2, 1 do
	local frame = { { 320, 64 * i }, { 64, 64 } }
	spikeImg[i] = eapi.NewSpriteList("image/pyramid.png", frame)
end
local function Spike(pos, flip)
	local img = spikeImg[util.Random(1, 2)]
	local tile = eapi.NewTile(staticBody, pos, nil, img, 0.3)
	eapi.SetAttributes(tile, { flip = { false, flip or false } })
end
local function InvertedSpike(pos)
	Spike(pos, true)
end

local function Gibblet(pos)
	common.Gibblet(pos, nil, 0.2)
end

local LongJump = action.WaypointFunction("long-jump")

local exports = {	
	LongJump = {func=LongJump,points=1,hide=true},
	SmallSlab = {func=SmallSlab,points=1,hide=true},
	FrontSlab = {func=FrontSlab,points=1,hide=true},
	BigSlab = {func=BigSlab,points=1,hide=true},
	Darkness = {func=slab.MakeDarkness(),points=2,hide=true},
	CryptExit = {func=CryptExit,points=2,hide=true},
	Lamp = {func=Lamp,points=1,hide=true},
	Scaffold  = {func=slab.Scaffold,points=1,hide=true},
	VerticalLog = {func=VerticalLog,points=1,hide=true},
	LongVerticalLog = {func=LongVerticalLog,points=1,hide=true},
	HorizontalLog = {func=HorizontalLog,points=1,hide=true},
	Rope = {func=rope.Vertical,points=1,hide=true},
	RopeHorizontal = {func=rope.Horizontal,points=1,hide=true},
	RopeSteepRight = {func=rope.SteepRight,points=1,hide=true},
	RopeSteepLeft = {func=rope.SteepLeft,points=1,hide=true},
	Spider = {func=spider.Put,points=1,hide=false},
	Jump = {func=Jump,points=1,hide=true},
	BackJump = {func=BackJump,points=1,hide=true},
	HelmetNotice = {func=wood.Notice(txt.helmetNotice),points=1,hide=true},
	TempleNotice = {func=Temple,points=1,hide=true},
	SickhouseNotice = {func=Sickhouse,points=1,hide=true},
	UrgentNotice = {func=Urgent,points=1,hide=true},
	BarracksNotice = {func=Barracks,points=1,hide=true},
	BackVerticalLog = {func=BackVerticalLog,points=1,hide=true},
	Komodo = {func=komodo.Put,points=1,hide=true},
	GraveStone = {func=GraveStone,points=1,hide=true},
	GraveStoneInfo = {func=GraveStoneInfo,points=1,hide=true},
	GraveStoneHead = {func=GraveStoneHead,points=1,hide=true},
	GraveStoneKomodo = {func=GraveStoneKomodo,points=1,hide=true},
	PatchOfGrass = {func=slab.PatchOfGrass,points=1,hide=true},
	Blackness = {func=Occlusion.Blackness,points=2,hide=true},
	LogPlatform = {func=LogPlatform,points=2,hide=true},
	Kicker = {func=action.MakeKicker,points=2,hide=false},
	RibCage = {func=common.RibCage,points=1,hide=false},
	Skull = {func=common.Skull,points=1,hide=false},
	StoneCube = {func=slab.StoneCube,points=1,hide=false},
	Flag = {func=Flag,points=1,hide=true},
	SlabWall = {func=SlabWall,points=2,hide=true},
	Ladder = {func=Ladder,points=2,hide=true},
	Bed = {func=common.Bed,points=1,hide=true},
	Hang = {func=rope.Hang,points=2,hide=true},
	Web = {func=wood.Web(0.3),points=2,hide=true},
	DeadTree = {func=DeadTree,points=1,hide=true},
	Leaf = {func=common.Leaf,points=1,hide=true},	
	Flask = {func=Flask,points=1,hide=true},	
	Spike = {func=Spike,points=1,hide=true},	
	InvertedSpike = {func=InvertedSpike,points=1,hide=true},	
	KillerFloor = {func=common.KillerFloor,points=2,hide=true},
	MedKit = {func=savePoint.Medkit,points=1,hide=true},
	Gibblet = {func=Gibblet,points=1,hide=true},
}
editor.Parse("script/Rocks-edit.lua", gameWorld, exports)

eapi.PlaySound(gameWorld, "sound/wind.ogg", -1, 0.7)

util.PreloadSound({ "sound/glass.ogg" })
