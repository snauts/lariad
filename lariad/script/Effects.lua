dofile("script/object.lua")

local function RandomEpsilon()
	return util.Random() * 0.001
end

local defaultSpriteMap = {
	"PPPP",
	"PPPP",
	"PPPP",
	"PPPP",
	"PPPP",
}

local function RemoveShape(obj)
	eapi.SetGravity(obj.body, vector.null)
	eapi.pointerMap[obj.shapeObj] = nil
	eapi.Destroy(obj.shapeObj)
	obj.shapeObj = nil
end

local function PlayGibsSquirt(obj)			
	eapi.PlaySound(gameWorld, "sound/squirt.ogg")
end

local GibsSquirt = util.WithDelay(0.1, PlayGibsSquirt)

local function Maybe(obj)
	return obj or vector.null
end

local function ShatterImage(x, y)
	return { image        = "image/shatter.png",
		 spriteOffset = { x = x, y = y } }
end

local function Shatter(image, obj, VelFN, life, spriteMap, tileSize,
		       Sound, shapeBottomAdjust, shapeLessShatter)
	local function CalculateVelocity()
		return vector.Add(Maybe(obj.vel), Maybe(VelFN and VelFN()))
	end
	local tilePos = vector.Add(eapi.GetPos(obj.body), 
				   eapi.GetPos(obj.tile))
	if tileSize then
		local xOffset = 0.5 * (eapi.GetSize(obj.tile).x - tileSize.x)
		tilePos.x = tilePos.x + xOffset
	end
	if obj.xOffset then
		tilePos.x = tilePos.x + obj.xOffset
	end
	tileSize = tileSize or eapi.GetSize(obj.tile)

	-- Split first player sprite into smaller pieces.
	spriteMap = spriteMap or defaultSpriteMap

	local numRows = #spriteMap
	local numCol = #spriteMap[1]
	local spriteSize = {tileSize.x/numCol, tileSize.y/numRows }
	
	local spriteOffset = nil
	if type(image) == "table" then
		spriteOffset = image.spriteOffset
		image = image.image
	end

	local pieceSprites = util.TextureToTileset(image, spriteMap, 
						   spriteSize, spriteOffset).P

	-- Create an array of bodies, each representing a piece of the player,
	-- so that initially they're stacked to resemble the original player's
	-- tile, and then quickly collapse.
	local tileAttr = eapi.GetAttributes(obj.tile)

	local garbage = { }

	local function CreateFragment(r, c)
		local column
		local fragment = { }
		local offset = { x = (c - 1) * spriteSize[1],
				 y = (r - 1) * spriteSize[2]}
		local pos = vector.Add(tilePos, offset)

		fragment.body = eapi.NewBody(gameWorld, pos)
		eapi.SetAttributes(fragment.body, { sleep = false })
		-- random epsilon fixes fragment flickering
		local depth = tileAttr.depth + RandomEpsilon()
		fragment.tile = eapi.NewTile(fragment.body, nil, nil, 
					     pieceSprites, depth)
		fragment.color = tileAttr.color
		eapi.SetAttributes(fragment.tile, { flip = tileAttr.flip,
						    color = fragment.color })
		
		--[[ If player is facing the other direction (its tile
		     is flipped horizontally), we need to pick the
		     sprites right to left. ]]--

		if tileAttr.flip[1] then
			column = numCol - c
		else
			column = c - 1
		end
		eapi.SetFrame(fragment.tile, (numRows - r) * numCol + column)
		
		-- Downward triangle shape.
		local box = { l = 0, r = math.floor(spriteSize[1]),
			      b = shapeBottomAdjust or 0,
			      t = math.floor(spriteSize[2]) }

		local shape
		if not(shapeLessShatter) then
			shape = eapi.NewShape(fragment.body, nil, box, "Object")
			eapi.pointerMap[shape] = fragment
			fragment.shapeObj = shape
		end
		
		fragment.Ground = function(obj)
			if Sound then Sound(obj) end
			RemoveShape(obj)
		end
		
		eapi.SetGravity(fragment.body, obj.gravity)
		eapi.SetVel(fragment.body, CalculateVelocity())
		object.CompleteHalt(fragment)

		if life then
			if c == 1 then garbage[r] = { } end
			garbage[r][c] = fragment
		end
	end

	local function Iterate(Fn)
		for r = 1, numRows do
			for c = 1, numCol do
				Fn(r, c)
			end
		end
	end

	Iterate(CreateFragment)

	if not(life) then return end

	-- Do not use FadeOut fn because then
	-- we can get along with one timer here
	local fade = 1.0
	local function Collect()
		local function FadeFragments(r, c)
			if fade > 0 then
				local fragment = garbage[r][c]
				fragment.color.a = fade
				local attr = { color = fragment.color }
				eapi.SetAttributes(fragment.tile, attr)
			else			
				object.Delete(garbage[r][c])
			end
		end
		Iterate(FadeFragments)
		if fade > 0 then
			fade = fade - 0.01
			eapi.AddTimer(garbage[1][1].body, 0.01 * life, Collect)
		end
	end
	eapi.AddTimer(garbage[1][1].body, 0.01 * life, Collect)
end

local gibsSpriteMap = {
	"PPPP",
	"PPPP",
	"PPPP",
	"PPPP",
}

local gibsTileSize = { x = 128, y = 128 }

local function Gibs(object, fn, duration)	
	effects.Shatter("image/gibs.png", object, fn, duration or 3,
			gibsSpriteMap, gibsTileSize, GibsSquirt)
end

local function FewGibs(object, fn, duration)	
	effects.Shatter("image/gibs.png", object, fn, duration or 3,
			{ "PP", "PP" }, { x = 64, y = 64 }, GibsSquirt)
end

local bloodUp
local bloodAnim
local smokeAnim
local woodAnim = { }

local function Init()
	object.RegisterHandlers("Object")
	smokeAnim = eapi.TextureToSpriteList("image/smoke.png", {64, 64})
	bloodAnim = eapi.TextureToSpriteList("image/blood.png", {64, 64})
	bloodUp = eapi.TextureToSpriteList("image/blood-up.png", {64, 64})
	for i = 0, 2, 1 do
		local name = { "image/debris" .. i .. ".png", filter = true }
		woodAnim[i] = eapi.TextureToSpriteList(name, {64, 64})
	end
end

local bloodOffset1 = {x=36, y=40}
local bloodOffset2 = {x=26, y=40}
local bloodOffsetUP = {x=34, y=30}

local function Blood(body, projectile, depth)
	depth = depth or 0.2
	local vel = projectile.velocity
	local pos = weapons.GetPos(projectile)
	local vertical = (math.abs(vel.y) > math.abs(vel.x))
	if vertical then
		pos = vector.Sub(pos, bloodOffsetUP)
	elseif projectile.flip then
		pos = vector.Sub(pos, bloodOffset1)
	else
		pos = vector.Sub(pos, bloodOffset2)
	end
	pos = vector.Sub(pos, eapi.GetPos(body))
	pos = { x=math.floor(pos.x), y=math.floor(pos.y) }
	local img = (vertical and bloodUp) or bloodAnim
	local tile = eapi.NewTile(body, pos, nil, img, depth)
	eapi.SetAttributes(tile, { flip = { vel.x > 0, vel.y > 0 }})
	eapi.Animate(tile, eapi.ANIM_CLAMP, 64)
	local function Remove()
		eapi.Destroy(tile)
	end
	eapi.PlaySound(gameWorld, "sound/squish.wav")	
	eapi.AddTimer(body, 0.5, Remove)
end

local function Fade(from, to, duration, callback,
		    tile, depth, occTile, body, colorObj)	
	depth = depth or 1
	occTile = occTile or 'f'
	local step = (to - from) / (20 * duration)
	local color = colorObj or { r = 1, g = 1, b = 1 }
	local isColorFunction = (type(colorObj) == "function")
	tile = tile or Occlusion.put(occTile, -400, -240, depth,
				     { size = { 800, 480 } },
				     camera.ptr)
	
	local function Fade()
		local alpha = math.min(1, math.max(0, from))
		if isColorFunction then
			color = colorObj(alpha)
		else
			color.a = alpha
		end
		eapi.SetAttributes(util.CallOrVal(tile), { color = color })

		if (step > 0 and from <= to) 
		or (step < 0 and from >= to) then
			eapi.AddTimer(body or staticBody, 0.05, Fade)
			from = from + step
		else 
			if callback then callback(tile) end
		end
	end

	Fade()
end

local smokeRange = 800

local function Smoke(pos, cfg)
	local Pos = nil
	local nullPos = {x = 0, y = 0}
	local ofs = { x = -32, y = -32 }

	cfg.z		= cfg.z		or 1
	cfg.life	= cfg.life	or 2
	cfg.variation	= cfg.variation	or 30
	cfg.interval	= cfg.interval	or 0.05
	cfg.vel		= cfg.vel	or {x = 0, y = 100}
	cfg.gravity	= cfg.gravity	or nullPos
	cfg.dim		= cfg.dim	or 0.05
	cfg.color	= cfg.color	or { r = 1, g = 1, b = 1 }
	cfg.sprite	= cfg.sprite	or smokeAnim

	local function Puff(body)
		local z = util.CallOrVal(cfg.z)
		local angle = cfg.variation * (util.Random() - 0.5)
		local tile = eapi.NewTile(body, ofs, nil, cfg.sprite, z)
		eapi.Animate(tile, eapi.ANIM_LOOP, 16, util.Random())
		Fade(cfg.dim, 0, cfg.life, nil, tile, nil, nil, body, cfg.color)
		eapi.SetVel(body, vector.Rotate(cfg.vel, angle))
		eapi.SetGravity(body, cfg.gravity)
	end

	Pos = ((type(pos) == "table") and (function() return pos end)) or pos
	
	local emitter = util.ParticleEmitter(Pos, cfg.life, cfg.interval, Puff)
	emitter.pos = Pos()
	if not(cfg.disableProximitySensor) then
		proximity.Create(emitter.Kick, emitter.Stop, nil,
			{ l = Pos().x - smokeRange, r = Pos().x + smokeRange,
			  b = Pos().y - smokeRange, t = Pos().y + smokeRange })
	end
	return emitter
end

local function SparkColor()
	local green = 0.2 + 0.8 * util.Random()
	return { r = 1.0, g = green, b = 0, a = 0.7 } 
end

local function Sparks(Pos, Color, cfg)
	local nullPos = {x = 0, y = 0}
	local ofs = { x = -1, y = -1 }

	cfg		= cfg		or { }
	cfg.z		= cfg.z		or -0.01
	cfg.life	= cfg.life	or 0.2
	cfg.variation	= cfg.variation	or 360
	cfg.interval	= cfg.interval	or 0.01
	cfg.vel		= cfg.vel	or {x = 0, y = 20}
	cfg.gravity	= cfg.gravity	or nullPos
	Color		= Color		or SparkColor

	local function Spark(body)
		local dot = Occlusion.dot[util.Random(1, 3)]
		local angle = cfg.variation * (util.Random() - 0.5)
		local tile = eapi.NewTile(body, ofs, nil, dot, cfg.z)
		eapi.SetAttributes(tile, { color = Color() })
		eapi.SetVel(body, vector.Rotate(cfg.vel, angle))
		eapi.SetGravity(body, cfg.gravity)
	end
	
	local emitter = util.ParticleEmitter(Pos, cfg.life, cfg.interval, Spark)
	emitter.Kick()
	return emitter
end

local debrisColor = { r = 0.23, g = 0.20, b = 0.17 }
local function DebrisDust(pos)
	local dust = Smoke(pos, { disableProximitySensor = true,
				  color = debrisColor,
				  interval = 0.02,
				  variation = 360,
				  life = 1.0,
				  dim = 0.1,
				  z = 1.0 })
	dust.Kick()
	return dust
end

local function Trash(cfg)
	local trash = { }
	trash.body = eapi.NewBody(gameWorld, cfg.pos)
	trash.tile = eapi.NewTile(trash.body, cfg.offset, nil, cfg.img, cfg.z)
	eapi.SetAttributes(trash.tile, { angle = 2 * math.pi * util.Random() })	
	eapi.Animate(trash.tile, eapi.ANIM_LOOP, 32, util.Random())
	trash.shapeObj = eapi.NewShape(trash.body, nil, cfg.shape, "Object")
	eapi.pointerMap[trash.shapeObj] = trash
	eapi.SetVel(trash.body, cfg.vel)
	eapi.SetGravity(trash.body, cfg.gravity)
	trash.Ground = object.Delete
	object.CompleteHalt(trash)
end

local function WoodTrash(pos, vel)
	Trash({ pos = pos, 
		vel = vel,
		img = woodAnim[util.Random(0, 2)], 
		offset = { -32, -32 },
		shape = { l = -16, r = 16, b = -16, t = 16 },
		gravity = { x = 0, y = -1500 },
		z = 0.9 + 0.2 * util.Random() })
end

local function Debris(pos, shape, count, ratio)
	local debris = { }
	local x = pos.x + shape.l
	local y = pos.y + shape.b
	local w = shape.r - shape.l
	local h = shape.t - shape.b
	for i = 1, count, 1 do
		local dx = w * util.Random()
		local dy = h * util.Random()
		local pos = { x = x + dx, y = y + dy }
		if util.Random() > ratio then
			WoodTrash(pos, { x = 500 * util.Random() - 250, 
					 y = 500 * util.Random() })
		else
			debris[i] = DebrisDust(pos)
		end
	end	
	local function CleanUp()
		for i = 1, count, 1 do
			if debris[i] then debris[i].Stop() end
		end
	end
	eapi.PlaySound(gameWorld, "sound/thud.ogg", 0, 1.0)
	local body = eapi.NewBody(gameWorld, pos)
	eapi.AddTimer(body, 0.5, CleanUp)
end

effects = {
	Shatter = Shatter,
	Fade = Fade,
	Blood = Blood,
	Init = Init,
	Gibs = Gibs,
	FewGibs = FewGibs,
	Smoke = Smoke,
	Sparks = Sparks,
	Debris = Debris,
	ShatterImage = ShatterImage,
}
return effects
