local function LoadItem(dimensions, shouldFilter)
	return eapi.NewSpriteList({ "image/inventory-items.png",
				    filter = shouldFilter },
				  dimensions)
end
	
local function MaybeFlip(tile, flip)
	if flip == nil then flip = (util.Random() > 0.5) end
	eapi.SetAttributes(tile, { flip = { flip, false } })
end

local skullImg = LoadItem({ {64, 192}, {64, 64} })
local function Skull(pos, z, flip)
	MaybeFlip(eapi.NewTile(staticBody, pos, nil, skullImg, z or -0.1), flip)
end

local ribCageImg = LoadItem({ {0, 192}, {64, 64} })
local function RibCage(pos, z)
	MaybeFlip(eapi.NewTile(staticBody, pos, nil, ribCageImg, z or -0.2))
end

local stainImg = { }
stainImg[1] = Occlusion.Sprite({ { 64, 192 }, { 8, 64 } })
stainImg[2] = Occlusion.Sprite({ { 72, 240 }, { 56, 16 } })
local function Oil(num, z)
	return function(p)
		z = z or 1.2
		local tile = eapi.NewTile(staticBody, p, nil, stainImg[num], z)
		eapi.SetAttributes(tile, { color = { r = 0, g = 0, b = 0 } })
	end
end

local acidColor = { r = 0.5, g = 1, b = 0, a = 0.3 } 
local barrelImg = LoadItem({ {192, 128}, {64, 128} })
local function AcidBarrel(pos, body, angle, shape, color, z)
	body = body or staticBody
	z = (z or 0.5) - 0.0001 * pos.y
	if not(shape == "disable") then
		shape = shape or { b = pos.y, t = pos.y + 100,
				   l = pos.x + 8, r = pos.x + 56 }		
		eapi.NewShape(body, nil, shape, "Box")
	end
	local tile = eapi.NewTile(body, pos, nil, barrelImg, z)
	eapi.SetAttributes(tile, { angle = angle, color = color })	

	z = z + 0.0001
	for i = 1, 3 + util.Random(1, 4), 1 do
		local p = { x = math.floor(pos.x + 10 + 40 * util.Random()), 
			    y = math.floor(pos.y +  5 + 30 * util.Random()) }
		local tile = eapi.NewTile(body, p, nil, stainImg[1], z)
		eapi.SetAttributes(tile, { color = acidColor, angle = angle })
	end
end

local function BackgroundAcidBarrel(pos)
	common.AcidBarrel(pos, staticBody, nil, "disable", util.Gray(0.5), -1)
end

local function HorizontalAcidBarrel(pos)
	local body = eapi.NewBody(gameWorld, pos)
	AcidBarrel({ x = -32, y = -64 }, body, math.pi / 2,
		   { l = -36, r = 60, b = -28, t = 28 })
end

local function FloatingBarrel(pos)
	local function Create(platform)
		local body = platform.body
		eapi.NewTile(body, nil, nil, barrelImg, 0.5)
		local shape = { b = 0, t = 100, l = 8, r = 56 }		
		platform.shape =  eapi.NewShape(body, nil, shape, "Platform")
		return { l = -Infinity, r = Infinity,
			 b = pos.y, t = pos.y + 5 }
	end
	local vel = { x = 0, y = 10 }
	local platform = util.CreateSimplePlatform(pos, vel, Create, Control)
	return platform
end

local hand = LoadItem({ {97, 1}, {30, 30} }, true)
local function HandPrint(Color, variation, z)
	return function(pos)
		local offset = { x = -15, y = -15 }
		local body = eapi.NewBody(gameWorld, pos)		
		local tile = eapi.NewTile(body, offset, nil, hand, z or -0.2)
		local angle = variation * (util.Random() - 0.5);
		eapi.SetAttributes(tile, { color = Color(), angle = angle })
		MaybeFlip(tile)
	end
end

local function ShootableBlock(bb, CreateBlock)
	local block = {
		body = eapi.NewBody(gameWorld, { x = bb.l, y = bb.b }),
		shatter = { "PPP", "PPP", "PPP" },
		gravity = { x = 0, y = -1500 },
		shouldSpark = true,
		sparkDepth = 4.0,
	}
	local tileSet = CreateBlock(bb, block)
	local ShatterTest = block.ShatterTest
	local red   = { color = { r = 0.8, g = 0.2, b = 0.2 } }
	local white = { color = { r = 1.0, g = 1.0, b = 1.0 } }
	local attributes = white
	local function Dim(tile)
		eapi.SetAttributes(tile, attributes)
	end
	local function ShatterTile(tile, id)
		block.tile = tile
		if ShatterTest and ShatterTest(tile, id) then return end
		effects.Shatter(block.Texture(), block, action.BlowUp(),
				1, block.shatter, nil, action.RockCrumble)
	end
	local function UnDim()
		attributes = white
		table.foreach(tileSet, Dim)
	end
	block.Shoot = function(projectile)
		weapons.DeleteProjectile(projectile)
		if block.health > 0 then
			block.health = block.health - 1
			if attributes == white then
				attributes = red
				table.foreach(tileSet, Dim)
				eapi.AddTimer(block.body, 0.1, UnDim)
			end
		else
			table.foreach(tileSet, ShatterTile)
			eapi.pointerMap[block.shapeObj] = nil
			eapi.Destroy(block.body)
		end
	end
	eapi.NewShape(block.body, nil, block.shape, "Box")
	action.MakeActorShape(block)
	object.DoNotHalt(block)
	return block
end

local function DarkGradient(x, y, w, h, d)
	local s = Occlusion.gradient
	local tile = eapi.NewTile(staticBody, {x = x, y = y}, nil, s, d)
	eapi.SetAttributes(tile, {size={w, h}, flip={false,true}})
end

local acid = eapi.NewSpriteList({"image/swamp.png", filter=true},
				{{ 384, 320}, { 128, 192 }})

local function Acid(x, y, w, h, d)
	local tile = eapi.NewTile(staticBody, {x = x, y = y}, nil, acid, d)
	eapi.SetAttributes(tile, { size = { w, h } })
end

local function AcidColor(alpha)
	return { r = 0.5, g = 1.0, b = 0.0, a = alpha or 1.0}
end

local function AcidPool(bb)
	local w = bb.r - bb.l
	local h = bb.t - bb.b
	Acid(bb.l, bb.b, w, h, 1.0)
	Acid(bb.l, bb.b + 8, w, h, -1.8)
	Occlusion.put('n', bb.l, bb.t - 2, -1.9, 
		      { size={ w, 64 }, color = AcidColor(0.2)})
	Occlusion.put('n', bb.l, bb.t - 22, 0.9, 
		      { size={ w, 64 }, color = AcidColor(0.4)})
	DarkGradient(bb.l, bb.b, w, h, 1.1)
	Occlusion.put('i', bb.r - h, bb.b, 1.1, { size={ h, h } })
	Occlusion.put('j', bb.l, bb.b, 1.1, { size={ h, h } })
	shape.Line({ bb.l, bb.t - 32 }, { bb.r, bb.t - 22 }, "PondBottom")
end

local function AcidVapor(pos)
	effects.Smoke(pos, { z = 0.5, dim = 0.1, color = AcidColor() })
end

local dropShape = { b = -1, t = 1, l = -1, r = 1 }
local dropImg = eapi.TextureToSpriteList("image/water-drop.png", {32, 32})
local dropSplash = eapi.TextureToSpriteList("image/water-splash.png", {64, 64})

local function WaterDrop(pos, z)
	local drop = { }
	local offset = { x = -16, y = -16 }
	drop.body = eapi.NewBody(gameWorld, pos)
	drop.shapeObj = eapi.NewShape(drop.body, nil, dropShape, "Object")
	drop.tile = eapi.NewTile(drop.body, offset, nil, dropImg, z or 1)
	eapi.Animate(drop.tile, eapi.ANIM_CLAMP, 128, 0)
	eapi.pointerMap[drop.shapeObj] = drop
	object.CompleteHalt(drop)	
	local function End()
		eapi.Destroy(drop.body)
	end
	drop.Collide = function(drop)
		if not(action.OnGround(drop)) then return end

		eapi.Destroy(drop.tile)
		eapi.Destroy(drop.shapeObj)
		eapi.pointerMap[drop.shapeObj] = nil
		eapi.SetGravity(drop.body, { x = 0, y = 0 })		
		drop.tile = eapi.NewTile(drop.body, { -32, 0 },
					 nil, dropSplash, z or 1)
		eapi.Animate(drop.tile, eapi.ANIM_CLAMP, 32, 0)
		eapi.PlaySound(gameWorld, "sound/water-drop.ogg")
		eapi.AddTimer(drop.body, 1, End)
	end
	eapi.SetGravity(drop.body, { x = 0, y = -1000 })
end

local function Rain(bb, interval, z)
	interval = interval or 3
	local y = .5 * (bb.t + bb.b)
	local body = eapi.NewBody(gameWorld, { x = .5 * (bb.l + bb.r), y = y })
	local function EmitDrop()
		WaterDrop({ x = bb.l + util.Random() * (bb.r - bb.l), y = y}, z)
 		eapi.AddTimer(body, interval - 0.5 + util.Random(), EmitDrop)
	end
	EmitDrop()
end

local black = { r = 0.0, g = 0.0, b = 0.0 }

local woodName = { "image/debris2.png", filter = true }
local fireImg = eapi.TextureToSpriteList("image/fire-ball.png", {64, 64})
local woodImg = eapi.TextureToSpriteList(woodName, {64, 64})

local function Depth()
	return 0.9 + 0.2 * util.Random()
end

local function Flame(pos)
	local flame = { }
	flame[1] = effects.Smoke(pos, { dim = 0.2,
					vel = {x = 0, y = 50},
					gravity = {x = 0, y = 50},
					variation = 45,
					sprite = fireImg,
					life = 1,
					z = Depth,
					interval = 0.01 })

	flame[2] = effects.Smoke(pos, { dim = 0.1,
					vel = {x = 0, y = 50},
					gravity = {x = 0, y = 50},
					variation = 60,			     
					z = Depth,
					color = black,
					interval = 0.02 })
	return flame
end

local function FireWood(pos, CalculateAngle, count)	
	for i = 0, count or 10, 1 do
		local gray = 0.2 + 0.6 * util.Random()
		local color = { r = gray, g = gray, b = gray }
		local angle = CalculateAngle()
		local sin = math.abs(math.sin(angle))
		local p = vector.Offset(pos, 0, -math.floor(32 * sin) + 16)
		local offset = { x = -32, y = -32 }
		local body = eapi.NewBody(gameWorld, p)
		local tile = eapi.NewTile(body, offset, nil, woodImg, Depth())
		eapi.SetAttributes(tile, { angle = angle, color = color })
		eapi.SetFrame(tile, util.Random(0, 15))
	end
end

local function Fire(pos, seed)
	eapi.RandomSeed(seed or 60)

	FireWood(pos, function() return 2 * math.pi * util.Random() end)
	Flame(pos)

	local activator
	local function Burn()
		action.DeleteActivator(activator)		
		destroyer.BurningDeath(mainPC)
	end
	local shape = { l = pos.x - 16, r = pos.x + 16,
			b = pos.y - 16, t = pos.y + 16 }
	activator = action.MakeActivator(shape, Burn, nil, staticBody, true)

	local soundBody = eapi.NewBody(gameWorld, pos)
	local function SoundCallback()
		local distance = vector.Distance(pos, eapi.GetPos(mainPC.body))
		if (distance < 640) then
			local volume = 1.0 - distance / 640
			eapi.PlaySound(gameWorld, "sound/fire.ogg", 0, volume)
		end		
		eapi.AddTimer(soundBody, 0.5 + util.Random(), SoundCallback)
	end
	SoundCallback()
end

local function KillerFloor(bb, body)
	local info = { name = "Floor",
		       body = body,
		       pos = { x = bb.l, y = bb.b },		       
		       Lethal = function() return true end,
		       w = bb.r - bb.l, h = bb.t - bb.b }
	body = body or staticBody
	local shapeObj = eapi.NewShape(body, nil, bb, "KillerActor")
	eapi.pointerMap[shapeObj] = info
	return info
end

local bedSize = {{0, 320}, {128, 64}}
local bed = eapi.NewSpriteList("image/swamp.png", bedSize)
local function Bed(pos)
	eapi.NewTile(staticBody, pos, nil, bed, 0.5)
end

local leafFrame = { { 128, 192 }, { 64, 64 } }
local leaf = eapi.NewSpriteList("image/bamboo.png", leafFrame)
local function Leaf(pos, z)
	eapi.NewTile(staticBody, pos, nil, leaf, z or 0.5)
end

local function Gibblet(pos, offset, z)
	z = z or -1.9
	offset = offset or { 32 * util.Random(0, 3), 32 * util.Random(0, 3) }
	local img = eapi.NewSpriteList("image/gibs.png", { offset, {32, 32}})
	return eapi.NewTile(staticBody, pos, { x=32, y=32 }, img, z)	
end

local function BloodColor()
	return { r = 0.1 + 0.1 * util.Random(), g = 0, b = 0, a = 0.7 }
end

local function Gradient(x, y, w, h, flipX, flipY, img, z)
	eapi.SetAttributes(eapi.NewTile(staticBody, {x, y}, nil, img, z or 20),
			   {size = { w, h }, flip = { flipX, flipY }})
end

local function Blocker(bb, type)
	eapi.NewShape(staticBody, nil, bb, type or "Box")	
end

local function IndustrialImg(box, filter)
	return eapi.NewSpriteList({"image/industrial.png",filter=filter}, box)
end

local function BatSound()
	local i = util.Random(1, 4)
	eapi.PlaySound(gameWorld, "sound/bat" .. i .. ".ogg")
end

local gullImg = eapi.TextureToSpriteList("image/gull-turn-head.png", {64, 64})
local function GullTurnHead(pos, z, flip, delay, color)
	local dir = 1
	local tileOffset = { x = -32, y = -32 }
	local body = eapi.NewBody(gameWorld, pos)
	local tile = eapi.NewTile(body, tileOffset, nil, gullImg, z or -0.5)
	eapi.SetAttributes(tile, { flip = { flip or false, false } })
	if color then eapi.SetAttributes(tile, { color = color }) end
	local function TurnHead()
		eapi.Animate(tile, eapi.ANIM_CLAMP, dir * 16)
		eapi.AddTimer(body, delay or 2, TurnHead)
		dir = -dir
	end
	eapi.AddTimer(body, util.Random(), TurnHead)
end

common = {
	BackgroundAcidBarrel = BackgroundAcidBarrel,
	GullTurnHead = GullTurnHead,
	BatSound = BatSound,
	IndustrialImg = IndustrialImg,
	Blocker = Blocker,
	Bed = Bed,
	Oil = Oil,
	Leaf = Leaf,
	Skull = Skull,
	RibCage = RibCage,
	Gibblet = Gibblet,
	Gradient = Gradient,
	AcidBarrel = AcidBarrel,
	KillerFloor = KillerFloor,
	HorizontalAcidBarrel = HorizontalAcidBarrel,
	HandPrint = HandPrint,
	BloodyHandPrint = HandPrint(BloodColor, math.pi/2, -0.95),
	ShootableBlock = ShootableBlock,
	AcidVapor = AcidVapor,
	AcidPool = AcidPool,
	FloatingBarrel = FloatingBarrel,
	WaterDrop = WaterDrop,
	Rain = Rain,
	Fire = Fire,
	FireWood = FireWood,
	LoadItem = LoadItem,
	Flame = Flame,
	black = black,
}
return common
