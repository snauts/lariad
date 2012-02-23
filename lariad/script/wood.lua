local plank = { }
local wide = { }
for i = 0, 3, 1 do
	plank[i] = eapi.NewSpriteList("image/wood.png", {{i*64, 0}, {64, 32}})
	wide[i] = eapi.NewSpriteList("image/wood.png", {{i*64, 192}, {64, 32}})
end

local wallPlank = { }
for i = 1, 3, 1 do
	local frame = { { (i - 1) * 64, 256}, { 64, 256 } }
	wallPlank[i] = eapi.NewSpriteList("image/wood.png", frame)
end
wallPlank[4] = eapi.NewSpriteList("image/wood.png", {{ 0, 384}, { 64, 128 }})

local function WallPlank(pos, z, i)
	z = z or -2
	i = i or util.Random(1, 3)
	eapi.NewTile(staticBody, pos, nil, wallPlank[i], z)
end

local function Plank(bb, type, depth, bottom, body, img)
	depth = depth or -1
	img = img or plank
	body = body or staticBody
	local width = math.floor(math.max(3, (bb.r - bb.l) / 64))

	local function PlankPiece(pos, n)
		eapi.NewTile(body, pos, nil, img[n], depth)
		return vector.Add(pos, { x = 64, y = 0 })
	end

	local function DrawPlank(pos)
		pos = PlankPiece(pos, 0)
		pos = PlankPiece(pos, 1)
		for i = 4, width, 1 do
			pos = PlankPiece(pos, 2)
		end
		PlankPiece(pos, 3)
	end

	bottom = bottom or 8
	type = type or "OneWayGround"
	local pos = { x = bb.l, y = bb.b }
	local shape = { l = bb.l + 32,
			r = bb.l + width * 64 - 32,
			b = bb.b + bottom,
			t = bb.b + 24 }
	DrawPlank(pos)
	return eapi.NewShape(body, nil, shape, type)
end	

local function FrontPlank(bb)
	Plank(bb, "Box", 1, 16, nil, wide)
end	

local log = eapi.NewSpriteList({"image/swamp.png"}, {{224, 384}, {32, 128}})

local function Log(depth)
	return function(pos)
	       eapi.NewTile(staticBody, pos, nil, log, depth + pos.y / 10000)
	end
end

local function LogOcclusion(pos)
	Occlusion.put('c', pos.x, pos.y, -1.4, { size={24, 24} })
end

local function SideOcclusion(pos, flip)
	Occlusion.put('g', pos.x, pos.y, -1.4,
		      { size = { 24, 24 }, flip = { flip or false, false } })
end

local webImgSpec = { "image/wood.png", filter = true }
local webImg = eapi.NewSpriteList(webImgSpec, {{ 1, 33 }, { 126, 126 }})

local function Web(z)
	return function(bb)
		local w = bb.r - bb.l
		local h = bb.t - bb.b
		local tile = eapi.NewTile(staticBody, 
					  { x = bb.l, y = bb.b },
					  { x = w, y = h },
					  webImg, z)
	end
end

local bottle = { }
bottle[1] = eapi.NewSpriteList("image/wood.png", {{192, 32}, {32, 32}})
bottle[2] = eapi.NewSpriteList("image/wood.png", {{224, 32}, {32, 32}})

local function Bottle(num, z)
	return function(pos)
		local epsilon = 0.00001 * pos.y
		eapi.NewTile(staticBody, pos, nil, bottle[num], z - epsilon)
	end
end

local chair = eapi.NewSpriteList("image/wood.png", {{128, 32}, {64, 64}})

local function Chair(pos)
	eapi.NewTile(staticBody, pos, nil, chair, -0.5)
	action.MakeMessage(txt.chair,
			   { l = pos.x + 28, r = pos.x + 36, 
			     b = pos.y +  8, t = pos.y + 16 },
			   txt.chairInfo)
end

local nest = eapi.NewSpriteList("image/wood.png", {{128, 96}, {64, 64}})

local function Nest(pos)
	eapi.NewTile(staticBody, pos, nil, nest, 2)
end

local droping = { }
for i = 0, 1, 1 do
	local pos = {i * 32, 160}
	droping[i] = eapi.NewSpriteList("image/wood.png", {pos, {32, 32}})
end

local function Droping(n, z)
	return function(pos)
		eapi.NewTile(staticBody, pos, nil, droping[n], z)
	end
end

local duckJump = eapi.NewSpriteList("image/wood.png", {{192, 64}, {64, 64}})
local aybabtu = eapi.NewSpriteList("image/wood.png", {{448, 128}, {64, 64}})

local function InfoTable(pos, text, info, callback, img)
	local box = { l = pos.x + 28, r = pos.x + 36,
		      b = pos.y +  8, t = pos.y + 16 }
	eapi.NewTile(staticBody, pos, nil, img or duckJump, -0.5)
	return action.MakeMessage(text, box, info, callback)
end

local function DuckJump(pos)
	InfoTable(pos, txt.notice, txt.duckJumpInfo, nil, aybabtu)
end

local function BirdNestNotice(pos)
	InfoTable(pos, txt.notice, txt.nestNotice)
end

local function DeadSpiderNotice(pos)
	InfoTable(pos, txt.notice, txt.deadSpiderNotice)
end

local function Notice(text, callback, subtext)
	return function(pos)
		return InfoTable(pos, subtext or txt.notice, text, callback)
	end
end

local frame = { { 256, 128 }, { 64, 64 } }
local sittingGullImg = eapi.NewSpriteList("image/wood.png", frame)

local function SittingGull(pos)
	eapi.NewTile(staticBody, pos, nil, sittingGullImg, 3)
end

local frame = { { 448, 64 }, { 64, 64 } }
local roastImg = eapi.NewSpriteList("image/wood.png", frame)
local function Roast(pos)
	eapi.NewTile(staticBody, pos, nil, roastImg, 1)
end

local frame = { { 192, 256 }, { 32, 128 } }
local roastHolderImg = eapi.NewSpriteList("image/wood.png", frame)
local function RoastHolder(pos)
	eapi.NewTile(staticBody, pos, nil, roastHolderImg, 1)
end

local frame = { { 192, 384 }, { 32, 32 } }
local roastBarImg = eapi.NewSpriteList("image/wood.png", frame)
local function RoastBar(pos, z)
	eapi.NewTile(staticBody, pos, nil, roastBarImg, z or 0.9)
end

wood = {
	Roast = Roast,
	RoastBar = RoastBar,
	RoastHolder = RoastHolder,
	SittingGull = SittingGull,
	Notice = Notice,
	DeadSpiderNotice = DeadSpiderNotice,
	BirdNestNotice = BirdNestNotice,
	DuckJump = DuckJump,
	Droping = Droping,
	Nest = Nest,
	Chair = Chair,
	Bottle = Bottle,
	WallPlank = WallPlank,
	LogOcclusion = LogOcclusion,
	SideOcclusion = SideOcclusion,
	FrontPlank = FrontPlank,
	Plank = Plank,
	Log = Log,
	Web = Web,
}
return wood
