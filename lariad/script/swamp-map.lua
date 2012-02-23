dofile("script/Frog.lua")
dofile("script/exit.lua")
dofile("script/shape.lua")
dofile("script/spaceship.lua")
dofile("script/action.lua")
dofile("script/wood.lua")
dofile("script/spider.lua")
dofile("script/Common.lua")
dofile("script/push-block.lua")
dofile("script/shooting-plant.lua")

LoadPlayers()
local camBox = {l=-500,r=21000,b=-130,t=2000}
camera = util.CreateCamera(gameWorld, mainPC, camBox)

eapi.RandomSeed(42)
staticBody = eapi.GetStaticBody(gameWorld)

local tileset = util.TextureToTileset("image/swamp.png", util.map8x8, {64,64})

local pineMap = {
	"12",
	"34"
}
local pineset = util.TextureToTileset("image/pines.png", pineMap, {256,256})

local function PutPine(pos, tileID, z, attr)
	z = z or 0.5
	local img = pineset[tileID or RandomElement({ '1', '2', '3', '4' })]
	local tile = eapi.NewTile(staticBody, pos, {x=256, y=256}, img, z)
	if attr then eapi.SetAttributes(tile, attr) end
end

local function DarkPine(pos)
	PutPine(pos, nil, -0.5, { color = util.Gray(0.7) })
end

-- Three insect tiles.
insectAnim = eapi.TextureToSpriteList("image/insects.png", {64,64})

local treeTexture = {"image/trees.png", filter=true}
local treeSprite1 = eapi.NewSpriteList(treeTexture, {{0,0},{284,350}})
local treeSprite2 = eapi.NewSpriteList(treeTexture, {{287,0},{216,250}})
local treeSprite3 = eapi.NewSpriteList(treeTexture, {{304,256},{181,180}})

local px = eapi.NewParallax(gameWorld, treeSprite1, nil, nil, {0.24,1}, -10)
eapi.SetRepeatPattern(px, {true, false}, {400.0, 0.0})

px = eapi.NewParallax(gameWorld, treeSprite2, nil, {100,8}, {0.12,1}, -11)
eapi.SetRepeatPattern(px, {true, false}, {200.0, 0.0})

px = eapi.NewParallax(gameWorld, treeSprite3, nil, {100,16}, {0.06,1}, -12)
eapi.SetRepeatPattern(px, {true, false}, {50.0, 0.0})

local function PutReyleigh(pos, depth)
	local bg = eapi.NewSpriteList(treeTexture, {pos, {100,99}})
	px = eapi.NewParallax(gameWorld, bg, {100000,1000}, 
			 {-1000, -300}, {0.05, 1}, depth)
	eapi.SetRepeatPattern(px, {true, false})
end
PutReyleigh({  0, 413}, -100)
PutReyleigh({100, 413}, -9.5)
PutReyleigh({100, 413}, -10.5)
PutReyleigh({100, 413}, -11.5)

swampmoonSprite = eapi.NewSpriteList(treeTexture, {{201,412},{100,100}})
px = eapi.NewParallax(gameWorld, swampmoonSprite, 
		      nil, {280, 200}, {0.02, 1}, -90)
eapi.SetRepeatPattern(px, {false,false})

eapi.SetBackgroundColor(gameWorld, {r=0.047, g=0.310, b=0.729, a=1.0})

eapi.SetAttributes(eapi.NewTile(staticBody, {-2000, 700}, nil,
				Occlusion.whiteFalloff, -95),
		   { size = { 24000, 600 }, flip = { false, true },
		     color = { r = 0.005, g = 0.035, b = 0.09 }})

local tx = eapi.NewSpriteList({ "image/forest-bg.png" }, {{0,512},{512,512}})
local px = eapi.NewParallax(gameWorld, tx, nil, {0, 700}, {0.5, 0.9}, -90)
eapi.SetRepeatPattern(px, { true, false })

local pond = { }
for i = 0, 3, 1 do
	local area = { { i * 64 + 256, 0 }, { 64, 64 } }
	pond[i] = eapi.NewSpriteList("image/wood.png", area)
end

local pondMap = { }
pondMap['k'] = 0
pondMap['l'] = 1
pondMap['m'] = 2
pondMap['n'] = 3

local Jump = action.WaypointFunction("jump")
local function SwampTile(tile, x, y, z)
	local pos = { x = util.Round(x), y = util.Round(y) }
	local pondIndex = pondMap[tile]
	if pondIndex then
		eapi.NewTile(staticBody, pos, nil, pond[pondIndex], z)
		Jump({ x = x + 32, y = y + 64 })
		z = -5
	end
	return util.PutTile(staticBody, tile, tileset, pos, z)
end

local function Tile(pos, id, z)	
	local tile = SwampTile(id, pos.x, pos.y, z)
	if id == 'f' then
		action.Stompable(pos, tile)
	end
end

SwampTile('i', -64, -192, 1)
SwampTile('j', -64, -128, 1)
SwampTile('m', -64, -64, 1)

for i=-128,-1024,-64 do
	SwampTile('i', i, -192, 1)
	SwampTile('j', i, -128, 1)
	SwampTile('l', i, -64, 1)
end

-- reed house
house_offset = 32
SwampTile('q', 0   + house_offset, 128, -1)
SwampTile('r', 64  + house_offset, 128, -1)
SwampTile('s', 128 + house_offset, 128, -1)
SwampTile('t', 192 + house_offset, 128, -1)

SwampTile('y', 0   + house_offset, 64, -1)
SwampTile('z', 64  + house_offset, 64, -1)
SwampTile('A', 128 + house_offset, 64, -1)
SwampTile('B', 192 + house_offset, 64, -1)

SwampTile('G', 0   + house_offset, 0, -1)
SwampTile('H', 64  + house_offset, 0, -1)
SwampTile('I', 128 + house_offset, 0, -1)
SwampTile('J', 192 + house_offset, 0, -1)

ExitRoom({l=150,r=160,b=5,t=10}, "ReedHouse", {0,-65}, 
	 nil, true, txt.hut, eapi.ZOOM_OUT)

-- sign
util.PutTile(staticBody, 'u', tileset, {-32, 0}, -1)

-- spaceship
Spaceship(20000, 0)

local function SwampInsect(pos, z, fps)
	z = z or -0.9
	fps = fps or 24
	local tile = util.PutAnimTile(staticBody, insectAnim, 
				      pos, z, eapi.ANIM_LOOP, fps)
	eapi.SetAttributes(tile, { color = { r = 0.1, g = 0.1, b = 0.1 } })	
end

SwampInsect({ x = -128, y = 0 }, 1, 24)
SwampInsect({ x = -128, y = 0 }, 1, 32)
SwampInsect({ x = -150, y = 0 }, 1, 28)

action.MakeMessage(txt.sign, {l=0, b=8, r=16, t=24}, txt.drownInfo)

action.MakeMessage(txt.roof, {l=140, b=270, r=160, t=280}, txt.roofInfo)

local function LeftBoot(pos)
	util.PutTile(staticBody, 'R', tileset, pos, -1)
	action.MakeMessage(txt.boot, 
			   { l = pos.x + 40, b = pos.y + 30,
			     r = pos.x + 60, t = pos.y + 40 },
			   txt.bootInfo1)
end

local function RightBoot(pos)
	util.PutTile(staticBody, 'R', tileset, pos, -1)
	action.MakeMessage(txt.boot,
			   { l = pos.x + 10, b = pos.y + 30,
			     r = pos.x + 30, t = pos.y + 40 },
			   txt.bootInfo2)
end

local function Hand(x, y)
	local activator
	local depth = 100
	local body = eapi.NewBody(gameWorld, { x, y })
	local tile = util.PutTile(body, 'S', tileset, {0, 0}, -1)

	local function GoDown()
		if depth > 0 then
			local pos = eapi.GetPos(body)
			pos = vector.Add(pos, {x=1, y=-1})
			eapi.SetPos(body, pos)
			eapi.AddTimer(gameWorld, 0.05, GoDown) 		
			depth = depth - 1
		else
			eapi.Destroy(body)
		end
	end
	local function HandSink()
		game.GetState().gotPDA = true;
		action.DeleteActivator(activator)
		eapi.Destroy(tile)
		tile = util.PutTile(body, 'T', tileset, {0, 0}, -2)
		eapi.PlaySound(gameWorld, "sound/bubbling.wav")
		GoDown()
	end
	local box = { l = x, b = y + 40, r = x + 35, t = y + 60 }
	local handTxt = action.LineByLine(txt.handInfo)
	activator = action.MakeMessage(txt.hand, box, handTxt, HandSink)
end

if not(game.GetState().gotPDA) then
	Hand(18495, -45)
end

local function Herbs(pos)
	util.PutTile(staticBody, 'N', tileset, pos, 0.5)
end

local function Herbs(pos)
	SwampTile('N', pos.x, pos.y, 0.5)
end

local function SwampShape(bb, type)
	eapi.NewShape(staticBody, nil, bb, type)
end

-- This is the lake to the left of reed house.
SwampShape({l=-1024,r=0,b=-40,t=-32}, "PondBottom")

-- Reed house roof.
SwampShape({l=66,r=251,b=118,t=124}, "OneWayGround")
SwampShape({l=112,r=194,b=170,t=175}, "OneWayGround")

-- Safety net
SwampShape({l=-2100,r=-2000,b=-600,t=0}, "Box")
SwampShape({l=22000,r=22100,b=-600,t=0}, "Box")
SwampShape({l=-2000,r=22000,b=-600,t=-500}, "Box")

local function BottlesMsg(pos)
	action.MakeMessage(txt.bottles,
			   { l = pos.x + 28, r = pos.x + 36, 
			     b = pos.y +  8, t = pos.y + 16 },
			   txt.bottlesInfo)
end

local function SwampSteam(pos)
	effects.Smoke(pos, { z = -5.0, dim = 0.1 })
end

local cubeImg = eapi.NewSpriteList("image/swamp.png", {{320, 128}, {64, 64}})

local function StumpCube(pos)
	pos.restingSprite = cubeImg
	pos.top = -24
	pos.edge = -4
	pushBlock.Put(pos)
end

local function StumpCubePool(pos)
	pos.bottom = -12
	StumpCube(pos)
end

local function Pond(bb)
	local width = math.floor((bb.r - bb.l) / 64)
	local farside = bb.l + (width + 1) * 64
	for i = 0, width, 1 do
		local pos = { x = bb.l + i * 64, y = bb.b }
		if i == 0 then
			Tile(pos, 'k', 2)
		elseif i == width then
			Tile(pos, 'm', 2)
		else
			Tile(pos, 'l', 2)
		end	
	end
	local function Wall(x, y)
		local shape = { l = x - 4, r = x + 4, b = y + 32, t = y + 64 }
		eapi.NewShape(staticBody, nil, shape, "Box")
	end
	Wall(bb.l, bb.b)
	Wall(farside, bb.b)
	local shape = { l = bb.l, r = farside, b = bb.b + 24, t = bb.b + 32 }
	eapi.NewShape(staticBody, nil, shape, "PondBottom")
	
end

local function PlankPlatform(bb)
	local function Create(platform)
		platform.shape = wood.Plank({ l = 0, r = bb.l - bb.r,
					      b = 0, t = bb.t - bb.b },
					    "Platform", -1, 8, platform.body)
		return { l = -Infinity, r = Infinity, b = bb.b, t = bb.t }
	end
	local vel = { x = 0, y = 100 }
	local pos = { x = bb.l, y = bb.b } 
	local platform = util.CreateSimplePlatform(pos, vel, Create)
	return platform
end

local function SpiderMaze(pos, maze)
	maze = maze or { "___^_____^_^__",
			 "_*__^_*_^___^_",
			 "__*___*___*___" }
	local length = 128 * #(maze[1])
	local function Plank(h, Fn)
		Fn = Fn or wood.Plank
		Fn({ l = pos.x, r = pos.x + length, 
		     b = pos.y + h, t = pos.y + h + 1 })
	end
	local function PutSpider(dx, dy, up)
		local function Shape(h, bCompension, tCompension)
			return { l = pos.x + dx, r = pos.x + dx + 128,
				 b = pos.y + dy + 8 + h - bCompension,
				 t = pos.y + dy + 128 - h + tCompension}
		end
		wood.Log(-1.5)(vector.Offset(pos, dx - 16, dy))
		wood.LogOcclusion(vector.Offset(pos, dx - 12, dy + 100))
		wood.Log(-1.5)(vector.Offset(pos, dx + 112, dy))
		wood.LogOcclusion(vector.Offset(pos, dx + 116, dy + 100))
		local vPosOffset = up and 70 or 63
		local spiderPos = vector.Offset(pos, dx + 64, dy + vPosOffset)
		local type = up and "sitter_up" or "sitter_down"
		spider.Put(spiderPos, false, type)
		local offset = up and 0 or 128
		action.MakeKicker(Shape(16, offset, 128 - offset))
		wood.Web(-1.6)(Shape(0, 0, 0))
	end
	for y = 1, #maze, 1 do 
		local dy = (y - 1) * 120
		for x = 1, #(maze[1]), 1 do 
			local sym = string.sub(maze[#maze - y + 1], x, x)
			if not(sym == '_') then
				PutSpider((x - 1) * 128, dy + 10, sym == '^')
			end
		end
		Plank(dy)
	end
	Plank(120 * #maze + 8, wood.FrontPlank)
end

local function Parallax(pos, img, size, scroll, alpha)
	local px = eapi.NewParallax(gameWorld, img, size, pos, scroll, 10)
	eapi.SetRepeatPattern(px, { false, false })
	eapi.SetAttributes(px, { color = { r = 1, g = 1, b = 1, a = alpha } })
	return px
end

local function FogParallax(pos, scroll, alpha, img1, img2)
	Parallax(pos, img1, { 512, 128 }, scroll, alpha)
	local pos2 = vector.Offset(pos, 0, -256)
	Parallax(pos2, img2, { 512, 256 }, scroll, alpha)
end

local fog1 = eapi.NewSpriteList("image/fog.png", {{0, 128}, {512, 128}})
local fog2 = eapi.NewSpriteList("image/fog.png", {{0, 384}, {256, 128}})
local fog3 = eapi.NewSpriteList("image/fog.png", {{0, 0}, {512, 128}})
local fog4 = eapi.NewSpriteList("image/occlusion.png", {{448, 0}, {64, 64}})
local fog5 = eapi.NewSpriteList("image/fog.png", {{0, 256}, {512, 128}})
local fog6 = eapi.NewSpriteList("image/fog.png", {{256, 384}, {256, 128}})

local function Fog(pos, scroll, count, alpha)
	FogParallax(vector.Offset(pos, 0, 0), scroll, alpha, fog1, fog2)
	
	for i = 1, count - 2, 1 do
		local pos2 = vector.Offset(pos, i * 512, 0)
		FogParallax(pos2, scroll, alpha, fog3, fog4)
	end
	
	local pos2 = vector.Offset(pos, (count - 1) * 512, 0)
	FogParallax(pos2, scroll, alpha, fog5, fog6)
end

local function PutFog(offset, length, alpha)
	Fog({ x = offset + 384, y =  64 },  { 1.10, 1.04 }, length, alpha)
	Fog({ x = offset + 192, y =  16 },  { 1.15, 1.07 }, length + 2, alpha)
	Fog({ x = offset +   0, y = -16 },  { 1.20, 1.10 }, length + 4, alpha)
	Fog({ x = offset - 192, y = -128 }, { 1.25, 1.13 }, length + 6, alpha)
end

PutFog(1000, 3, 0.4)
PutFog(8500, 10, 0.9)
PutFog(19000, 3, 0.3)

local dropSplashName = { "image/water-splash.png", filter=1 }
local dropSplash = eapi.TextureToSpriteList(dropSplashName, {64, 64})

local function Splash(pos, offset)
	local tile = nil
	local done = false
	local body = eapi.NewBody(gameWorld, pos)
	action.MakeActivator({ b = 124, t = 132, l = -4, r = 4 },
			     function() done = false end,
			     nil, body, true)	

	local function RemoveSplashTile()
		eapi.Destroy(tile)
		tile = nil
	end
	local function EmitDrops()
		if done or tile then return end
		eapi.PlaySound(gameWorld, "sound/slosh.ogg")
		tile = eapi.NewTile(body,
				    { x = -64, y = offset or 96 },
				    { 128, 128 }, dropSplash, -1)
		eapi.Animate(tile, eapi.ANIM_CLAMP, 32, 0)
		eapi.AddTimer(body, 1, RemoveSplashTile)
		done = true
	end
	action.MakeActivator({ b = -4, t = 4, l = -4, r = 4 },
			     EmitDrops, nil, body, true)	
end

local function Gas(pos)
	local activator
	local function Steam(Position)
		return effects.Smoke(Position,
				     { z = 0.5, dim = 0.5, life = 1,
				       disableProximitySensor = true,
				       inverval = 0.01, variation = 30,
				       vel = { x = 0, y = 50 } })	
	end
	local function Outburst()
		local gas
		action.DeleteActivator(activator)
		local function Position()
			return eapi.GetPos(mainPC.body)
		end
		local offset = (eapi.GetPos(mainPC.body).x - pos.x) + 56
		mainPC.vel = { x = -700 - offset * 2.2, y = 800 }
		gas = Steam(Position)
		eapi.PlaySound(gameWorld, "sound/steam.ogg")
		local function Stop()
			mainPC.StartInput()
			gas.Stop()
			Gas(pos)
		end
		eapi.AddTimer(staticBody, 1, Stop)
		mainPC.StopInput()
		gas.Kick()
	end
	activator = action.MakeActivator({ b = pos.y -  4, t = pos.y + 64,
					   l = pos.x - 32, r = pos.x + 32 },
					 Outburst, nil, staticBody, true)	
end

local function Obstacle(bb)
	local done = false
	local function Bump()
		if done then return end
		eapi.PlaySound(gameWorld, "sound/hit.ogg")	
		mainPC.vel.x = -300 * util.Sign(mainPC.vel.x)
		mainPC.vel.y = 300
		done = true
	end
	action.MakeActivator(bb, Bump, nil, staticBody, true)	

	local function Undo()
		done = false
	end
	local bb1 = { b = bb.b - 128, t = bb.t + 128,
		      l = bb.l - 64, r = bb.l - 56}
	local bb2 = { b = bb.b - 128, t = bb.t + 128,
		      l = bb.r + 56, r = bb.r + 64}
	action.MakeActivator(bb1, Undo, nil, staticBody, true)	
	action.MakeActivator(bb2, Undo, nil, staticBody, true)	
end

local function Snarl(bb)
	local blowup = { }
	local a1, a2, gas1, gas2, body, shape
	local function Position()
		return eapi.GetPos(body)
	end
	local function Smoke(yvel, var)
		local gas = effects.Smoke(Position,
					  { z = 0.5, dim = 0.7, life = 1,
					    disableProximitySensor = true,
					    inverval = 0.01, variation = var,
					    vel = { x = 0, y = yvel } })
		gas.Kick()
		return gas
	end
	local function End()
		for i = 1, 10, 1 do
			blowup[i].Stop()
		end
		eapi.Destroy(body)
	end
	local function BlowUp()
		if blowup[1] then return end
		for i = 1, 10, 1 do
			blowup[i] = Smoke(150, 180)
			blowup[i].Kick()
		end
		eapi.AddTimer(body, 0.5, End)
		eapi.PlaySound(gameWorld, "sound/chshsh.ogg")	
		eapi.SetVel(body, { x = 0, y = 0 })
		eapi.pointerMap[shape] = nil
		eapi.Destroy(shape)
		gas1.Stop()
		gas2.Stop()
	end
	local function Start(x, dir)
		action.DeleteActivator(a1)
		action.DeleteActivator(a2)
		eapi.PlaySound(gameWorld, "sound/snarl.ogg")	
		body = eapi.NewBody(gameWorld, { x = x, y = bb.b + 128 })
		eapi.SetVel(body, { x = 150 * dir, y = 0 })
		local shapeDef = { l = -4, r = 4, b = -96, t = 96 }
		shape = eapi.NewShape(body, nil, shapeDef, "Snarl")
		eapi.pointerMap[shape] = BlowUp
		eapi.AddTimer(body, 4.5, BlowUp)	
		gas1 = Smoke(140, 30)
		gas2 = Smoke(160, 45)
	end	
	local function Start1() Start(bb.r + 192, -1) end
	local function Start2() Start(bb.l - 192, 1) end
	local bb1 = { b = bb.b, t = bb.t, l = bb.l - 8, r = bb.l }
	local bb2 = { b = bb.b, t = bb.t, l = bb.r, r = bb.r + 8 }
	a1 = action.MakeActivator(bb1, Start1, nil, staticBody, true)	
	a2 = action.MakeActivator(bb2, Start2, nil, staticBody, true)	
end

local function CollideSnarl(world, playerShape, snarlShape, resolve)
	eapi.pointerMap[snarlShape]()
end

eapi.Collide(gameWorld, "Player", "Snarl", CollideSnarl, 50)

local spiderAnim = eapi.TextureToSpriteList("image/spider.png", {128, 64})

local function SpiderThrow(bb)
	local gas = { }
	local body, activator
	local function Position()
		return eapi.GetPos(body)
	end
	local function Steam()
		steam = effects.Smoke(Position,
				      { z = 1.1, dim = 0.4, life = 1,
					disableProximitySensor = true,
					inverval = 0.01, variation = 90,
					vel = { x = 0, y = 50 } })
		steam.Kick()
		return steam
	end
	local function Delete()
		eapi.Destroy(body)
		for i = 1, 3, 1 do
			gas[i].Stop()
		end
	end
	local function Throw()
		action.DeleteActivator(activator)
		local dir = util.Sign(mainPC.vel.x)
		local middle = 0.5 * (bb.r + bb.l)
		local pos = { x = middle + dir * 256, y = bb.b - 96 }
		body = eapi.NewBody(gameWorld, pos)
		local tile = eapi.NewTile(body, {-64, -32}, nil, spiderAnim, 1)
		local color = util.Gray(1.0)
		local flip = { dir < 0, false }
		color["a"] = 0.5
		eapi.PlaySound(gameWorld, "sound/chshsh.ogg")
		eapi.SetVel(body, { x = -dir * 500, y = 900 })
		eapi.SetGravity(body, { x = 0, y = -1500 })
		eapi.SetAttributes(tile, { flip = flip, color = color })
		eapi.Animate(tile, eapi.ANIM_LOOP, 80)
		eapi.AddTimer(body, 1.5, Delete)
		for i = 1, 3, 1 do
			gas[i] = Steam()
		end
	end
	activator = action.MakeActivator(bb, Throw, nil, staticBody, true)
end

local function Darkness(bb)
	local w = bb.r - bb.l
	local h = bb.t - bb.b
	Occlusion.put('f', bb.l, bb.b, -3, { size = { w, h } }, staticBody)
end

local function EnterWitchHouse(bb)
	ExitRoom(bb, "WitchHouse", {-237, -131}, 
		 nil, true, txt.witchHouse, eapi.ZOOM_OUT)
end

local function Moss(pos)
	Tile(pos, "f", 3)
end

local exports = {
	Moss = {func=Moss,points=1},
	Tile = {func=Tile,points=1,hide=true},
	Shape = {func=SwampShape,points=2,hide=true},
	PutPine = {func=PutPine,points=1,hide=true},
	Insect = {func=SwampInsect,points=1,hide=true},
	Frog = {func=frog.PutFrog,points=1,hide=true},
	Steam = {func=SwampSteam,points=1},
	Plank = {func=wood.Plank,points=2},
	FrontPlank = {func=wood.FrontPlank,points=2},
	FrontLog = {func=wood.Log(0.9),points=1},
	BackLog = {func=wood.Log(-1.5),points=1},
	Blocker = {func=common.Blocker,points=2},
	Herbs = {func=Herbs,points=1},
	LogOcclusion = {func=wood.LogOcclusion,points=1},
	SideOcclusion = {func=wood.SideOcclusion,points=1},
	Web = {func=wood.Web(-1.2),points=2},
	DeadSpider = {func=spider.Dead(-1),points=1},
	Spider = {func=spider.Put,points=1},
	Kicker = {func=action.MakeKicker,points=2,hide=false},
	Bottle1Front = {func=wood.Bottle(1, 0.5) ,points=1},
	Bottle1Back = {func=wood.Bottle(1, -0.5) ,points=1},
	Bottle2Front = {func=wood.Bottle(2, 0.5) ,points=1},
	Bottle2Back = {func=wood.Bottle(2, -0.5) ,points=1},
	Chair = {func=wood.Chair,points=1},
	Nest = {func=wood.Nest,points=1},
	BottlesMsg = {func=BottlesMsg,points=1},
	Droping0 = {func=wood.Droping(0, -1.4),points=1},
	Droping1 = {func=wood.Droping(1, -0.9),points=1},
	Droping2 = {func=wood.Droping(1, 1.5),points=1},
	DuckJump = {func=wood.DuckJump,points=1},
	BirdNestNotice = {func=wood.BirdNestNotice,points=1},
	DeadSpiderNotice = {func=wood.DeadSpiderNotice,points=1},
	HealthPlus = {func=destroyer.HealthPlus(4),points=1},
	StumpCube = {func=StumpCube,points=1},
	StumpCubePool = {func=StumpCubePool,points=1},
	Pond = {func=Pond,points=2},
	Pine = {func=PutPine,points=1},
	DarkPine = {func=DarkPine,points=1},
	SpiderMaze = {func=SpiderMaze,points=1,hide=false},
	PlankPlatform = {func=PlankPlatform,points=2},
	LeftBoot = {func=LeftBoot,points=1},
	RightBoot = {func=RightBoot,points=1},
	Splash = {func=Splash,points=1},
	Obstacle = {func=Obstacle,points=2},
	Snarl = {func=Snarl,points=2},
	Darkness = {func=Darkness,points=2},
	SpiderThrow = {func=SpiderThrow,points=2},
	EnterWitchHouse = {func=EnterWitchHouse,points=2},
	Gas = {func=Gas,points=1},
	Skull = {func=common.Skull,points=1},
	RibCage = {func=common.RibCage,points=1},
	BloodyHandPrint = {func=common.BloodyHandPrint,points=1},
	WallPlank = {func=wood.WallPlank,points=1},
	Plant = {func=plant.Put,points=1},
	Tutorial = {func=proximity.Tutorial,points=2},
}
editor.Parse("script/swamp-edit.lua", gameWorld, exports)

eapi.PlaySound(gameWorld, "sound/frogs.ogg", -1, 0.5)

eapi.Collide(gameWorld, "Player", "PondBottom",
	     destroyer.Player_vs_PondBottom, 100)

local function DrownSpider(world, actorShape, pondShape, resolve)
	local actor = eapi.pointerMap[actorShape]
	if actor.name == "spider" then 
		actor.Drown(actor) 
	else
		object.Box(world, actorShape, pondShape, resolve)
	end
end

eapi.Collide(gameWorld, "Actor", "PondBottom", DrownSpider, 200)

if game.GetState().startLives == 1 then 
	spider.Put({x=17222,y=1},true)
	action.MakeKicker({l=13401,r=13949,b=-39,t=415})
	plant.Put({x=13643,y=121})
end

util.PreloadSound({ "sound/croak.ogg",
		    "sound/slosh.ogg",
		    "sound/chshsh.ogg",
		    "sound/plop.ogg",
		    "sound/hit.ogg" })
