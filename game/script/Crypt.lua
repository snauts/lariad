util.msg = "FromCrypt"

dofile("script/Pyramid.lua")
dofile("script/bat.lua")

pyramid.DiagonalTunnel(900, -650, 5, 0) 
pyramid.FlatTunnel(1650, -650, 3, 0)
pyramid.FlatTunnel(-350, -146, 1, 1)

local function BigSlab(pos)
	slab.Big(pos.x, pos.y, 1.0)
end

local spillImg = eapi.NewSpriteList("image/spill.png", {{896, 480}, {128, 32}})

local function Altar(pos)
	eapi.NewTile(staticBody, { x = pos.x+16, y = pos.y+56 },
		     { x = 96, y = 16 }, spillImg, -2.0)
	common.Gibblet({ x = pos.x + 32, y = pos.y + 56 }, { 0, 0 })
	common.Gibblet({ x = pos.x + 64, y = pos.y + 56 }, { 0, 32 })
	action.MakeMessage(txt.altar, { l = pos.x + 60, r = pos.x + 68,
				        b = pos.y + 24, t = pos.y + 32}, 
			   txt.altarInfo)
	slab.Small(pos.x, pos.y, -2.5, nil, 0)
end	

local function DeadBody(pos)
	local fallImg = eapi.NewSpriteList("image/player-fall.png",
					   { {384, 384}, {128, 128} })
	eapi.NewTile(staticBody, pos, { x = 128, y = 128 }, fallImg, -0.5)
	eapi.NewTile(staticBody, pos, nil, spillImg, -0.6)	
	action.MakeMessage(txt.deadOriginal, { l = pos.x + 60, r = pos.x + 68,
				        b = pos.y + 24, t = pos.y + 32}, 
			   txt.deadOriginalInfo)
end

local function HangingBody(pos)
	local size = { x = 64, y = 128 }
	local box = { { 64, 384 }, { 64, 128 } }
	local hangImg = eapi.NewSpriteList("image/player-wo-hand.png", box)
	local tile = eapi.NewTile(staticBody, pos, size, hangImg, -2.5)
	eapi.SetAttributes(tile, { flip = { false, true } })
	common.Gibblet({ x = pos.x + 4, y = pos.y + 64 }, { 0, 64 }, -2.45)

	local hangImg = eapi.NewSpriteList("image/player-hand.png", box)
	common.Gibblet({ x = pos.x + 18, y = pos.y -66 }, { 0, 64 }, -0.55)
	common.Gibblet({ x = pos.x + 10, y = pos.y -75 }, { 32, 0 }, -0.6)
	eapi.NewTile(staticBody, { x = pos.x + 16, y = pos.y - 115 },
		     size, hangImg, -0.5)

	local ropeImg = eapi.NewSpriteList("image/bamboo.png", 
					   { { 192, 64 }, { 64, 64 } })
	eapi.NewTile(staticBody, { x = pos.x - 7, y = pos.y + 98 },
		     { x = 64, y = 64 }, ropeImg, -2.4)
	local ropeImg = eapi.NewSpriteList("image/bamboo.png", 
					   { { 0, 64 }, { 16, 16 } })
	eapi.NewTile(staticBody, { x = pos.x + 16, y = pos.y + 106 },
		     { x = 16, y = 8 }, ropeImg, -2.4)
	
	
end

local function Lamp(pos)
	slab.PotLamp(pos.x, pos.y, -2.5)
end

local function BackToRocks(box)
	ExitRoom(box, "Rocks", {10715, 16}, nil, nil, nil, eapi.SLIDE_LEFT)
end

Occlusion.put('f', -700, -300, 10.0, { size={500, 800} })

local exports = {
	Bat = {func=bat.Put,points=1},
	DeadBody = {func=DeadBody,points=1},
	Hanging = {func=HangingBody,points=1},
	BigSlab = {func=BigSlab,points=1},
	Altar = {func=Altar,points=1},
	Lamp = {func=Lamp,points=1},
	Spider = {func=spider.Put,points=1},
	BackToRocks = {func=BackToRocks,points=2},
	Darkness = {func=slab.MakeDarkness(true, 10),points=2},
	SavePoint = {func=savePoint.Put,points=1},
	HeatlhPlus = {func=destroyer.HealthPlus(2),points=1},
	Kicker = {func=action.MakeKicker,points=2},
}
editor.Parse("script/Crypt-edit.lua", gameWorld, exports)
