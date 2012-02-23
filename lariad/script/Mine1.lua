dofile("script/occlusion.lua")
dofile("script/exit.lua")
dofile("script/shape.lua")
dofile("script/Boss.lua")
dofile("script/save-point.lua")
dofile("script/Common.lua")

LoadPlayers()

dofile("script/Mine.lua")

local camBox = {l=-6000,r=1000,b=-2770,t=1000}
camera = util.CreateCamera(gameWorld, mainPC, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.0, g=0.0, b=0.0})

eapi.RandomSeed(2941)

staticBody = eapi.GetStaticBody(gameWorld)

local revWallEndSize = {{0, 64}, {128, 256}}
local revWallEnd = eapi.NewSpriteList("image/mines-more.png", revWallEndSize)

local function BossRoom(x, y, w)
	-- front stalactites
	local ww = w * 128
	local i = -64
	local j = 0
	repeat
		local yy = y - 64 + util.Random(0, 32) - j
		Occlusion.RandomStalactite(x + i, yy - 32, 10,
					   util.ToBeOrNotToBe())
		Occlusion.put('f', x + i, yy - 256, 10, { size={64, 256} })
		local yyy = y - 64 + util.Random(0, 32) + 192
		Occlusion.RandomStalagmite(x + i, yyy, 10, util.ToBeOrNotToBe())
		Occlusion.put('f', x + i, yyy + 128, 10, { size={64, 256} })
		i = i + util.Random(24, 40)
		if i > 128 and i < 224 then
			j = j + util.Random(32, 48)
		end
		if i > ww - 256 and i < ww - 128 and j > 0 then 
			j = j - util.Random(32, 48)
		end
	until i > ww

	-- walk shape
	shape.Line({ x, y }, { x + 96, y - 48 }, "Box")
	shape.Line({ x + 96, y }, { x + 256, y - 160 })
	shape.Line({ x + 256, y - 160 }, { x + w * 128 - 256, y - 224 }, "Box")
	shape.Line({ x + ww - 96, y }, { x + ww - 256, y - 160 })
	shape.Line({ x + ww, y }, { x + ww - 96, y - 48 }, "Box")
	shape.Line({ x, y + 256 }, { x + w * 128, y + 306 }, "Box")

	Mine.CavernEntrance(x, y, ww, true)
	Mine.CavernEntrance(x + ww - 128, y, ww, false, revWallEnd)

	local function Parallax(offset, scroll, depth, img, yoffset, color)
		Mine.Parallax(x, y, offset, scroll, depth, img, yoffset, color)
	end
	local function ColumnStripe(offset, scroll, depth, color)
		for i = 0, 3, 1 do
			Parallax(offset, scroll, depth, nil, nil, color)
			offset = offset + util.Random(500, 600)
		end
	end
	ColumnStripe(557, 0.95, -10.5)
	ColumnStripe(607, 0.9, nil, { r = 0.4, g = 0.4, b = 0.4 })
	ColumnStripe(709, 0.85, -12, { r = 0.2, g = 0.2, b = 0.2 })

 	Occlusion.put('c', x, y - 128, -5, 
		      { size={3000, 32}, flip = { false, true } })

	for i = 0, 4, 1 do
		Parallax(500 + i * 512, 0.87, -11.1, Mine.glowWorm, 64)
		Parallax(300 + i * 512, 0.925, -10.7, Mine.glowWorm, 60)
		Parallax(150 + i * 512, 0.975, -10.3, Mine.glowWorm, 56)
	end
end

local function Mine1(x, y)
	Occlusion.put('f', x + 256 + 64, y-152, 10.0, { size={2048, 1024} })

	ExitRoom({ l = x + 360, b = y - 24, r = x + 380, t = y + 232 },
		 "Forest", { -10630, 537 }, nil, nil, nil, eapi.SLIDE_RIGHT)

	Mine.Entrance(x + 256, y, true)

	Mine.Tunnel(x - 128 * 7, y, 10)

	Mine.HorizontalGradient(x - 7*128, y - 24, 8*128, 256, true, 0.7)
	Mine.HorizontalGradient(x - 8*128, y - 24, 128, 256, false, 0.7)

	Occlusion.put('w', x - 7*128, y - 24, 9,
		      { flip = { true, false },
			size={128, 256},			
			multiply=true })

	Mine.FlowerTunnel(x - 128 * 17, y, 10)

	Mine.RightShaft(x - 128 * 19, y + 128, 6)

	Mine.FlowerTunnel(x - 128 * 21, y - 128 * 3, 2, nil, true)

	Mine.RightShaft(x - 128 * 23, y - 128 * 2, 7)

	Mine.CrystalTunnel(x - 128 * 27, y - 128 * 7, 4, nil, true)

	Mine.RightShaft(x - 128 * 29, y - 128 * 6, 8)

	Mine.FlowerTunnel(x - 128 * 32, y - 128 * 12, 3, nil, true)

	Mine.RightChute(x - 128 * 34, y - 128 * 11, 6)

	Mine.BlueTunnel(x - 128 * 32, y - 128 * 15, 10)
	Mine.BlueTunnel(x - 128 * 44, y - 128 * 15, 10)

	Mine.RightShaftInv(x - 128 * 46, y - 128 * 14, 8)
	Mine.LeftShaftInv(x - 128 * 22, y - 128 * 14, 8)

	Mine.BlueTunnel(x - 128 * 44, y - 128 * 20, 1)
	Mine.BlueTunnel(x - 128 * 23, y - 128 * 20, 1)

	BossRoom(x - 128 * 43, y - 128 * 20, 20)
end

Mine1(0, 0)

local function MinesMoreImg(frame)
	return eapi.NewSpriteList("image/mines-more.png", frame)
end
local chainImg = MinesMoreImg({ { 128, 64 }, { 16, 128 } })
local grateImg = MinesMoreImg({ { 384, 0 }, { 128, 128 } })
local boxImg = MinesMoreImg({ { 256, 0 }, { 128, 128 } })

local function Dim(tile)
	eapi.SetAttributes(tile, { color = util.Gray(0.7) })
end

local function Cage(pos, chainCount)
	local tiles = { }
	tiles[1] = eapi.NewTile(staticBody, pos, nil, boxImg, -0.6)
	tiles[2] = eapi.NewTile(staticBody, pos, nil, grateImg, -0.4)
	if chainCount == 1 then		
		local pos2 = vector.Offset(pos, 56, 96)
		tiles[3] = eapi.NewTile(staticBody, pos2, nil, chainImg, -0.7)
	else
		local pos2 = vector.Offset(pos, 56 - 32, 96)
		tiles[3] = eapi.NewTile(staticBody, pos2, nil, chainImg, -0.7)
		local pos3 = vector.Offset(pos, 56 + 32, 96)
		tiles[4] = eapi.NewTile(staticBody, pos3, nil, chainImg, -0.7)
	end
	util.Map(Dim, tiles)
end

local exports = {
	GullTurnHead = {func=common.GullTurnHead,points=1},
	Cage = {func=Cage,points=1},
	Boss = {func=boss.Put,points=1},
	SavePoint = {func=savePoint.Put,points=1},
	MedKit = {func=savePoint.Medkit,points=1},
	WaterDrop = {func=common.Rain,points=2},
}
editor.Parse("script/Mine1-edit.lua", gameWorld, exports)

ambient = eapi.PlaySound(gameWorld, "sound/creepy.ogg", -1, 0.9)
