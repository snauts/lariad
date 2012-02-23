dofile("script/object.lua")

local Put
local spiders = {}
local walkSpider = eapi.TextureToSpriteList("image/spider.png", {128, 64})
local stillSpider = eapi.TextureToSpriteList("image/spider-idle.png", {128, 64})

local function SpiderScatter()
	return { x =   500 * util.Random() - 250,
		 y =  1000 * util.Random() }
end

local function SetVelocity(spider, x, y)
	if x then spider.vel.x = x end
	if y then spider.vel.y = y end
	spider.side = spider.vel.x < 0
	action.SetDirection(spider)
end

local function CalculateVelocity(spider)
	local direction = action.GetKickDirection(spider)
	local distance = action.DistanceToPlayer(spider)
	local diff = action.HeightDifference(spider.body)
	if not action.OnGround(spider) or spider.type == "jumper" then
		return
	elseif math.abs(distance + 16) < 192 and diff > -24 then
		SetVelocity(spider, 120 * direction, 620)
	else
		SetVelocity(spider, 120 * direction, 0)
	end
end

local function Animate(spider)
	if not(spider.animation) then
		eapi.SetSpriteList(spider.tile, walkSpider)
		action.SetDirection(spider)
		eapi.Animate(spider.tile, eapi.ANIM_LOOP, 40)
		spider.animation = true
	end
end

local function IdleAnimate(spider)
	action.SetDirection(spider)
	eapi.Animate(spider.tile, eapi.ANIM_LOOP, 16, util.Random())
end

local function PlaySpiderSound()
	action.AlternateSounds("sound/spider1.ogg", "sound/spider2.ogg")
end

local function KickSpider(spider)
	if spider.type == "patrol" then
		spider.type = "regular"
	end
	if string.sub(spider.type, 1, 6) == "sitter" then
		local pos = vector.Offset(spider, -64, -32)
		local new = Put(pos, spider.side)
		new.parent = spider
		new.MaybeActivate()
		spider.Delete()
		return
	end

	spider.contact.ground = true
	action.StartStepFunction(spider)
 	local function KickSpiderCallback()
		PlaySpiderSound()
		Animate(spider)
		CalculateVelocity(spider)
		eapi.AddTimer(spider.body, 0.5, KickSpiderCallback)
	end
	KickSpiderCallback()
end

local function SpiderShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
end

local spiderShape  = { l=8, r=120, b=16, t=56 }

local function ShouldDownJump(spider)
	local diff = action.HeightDifference(spider.body)
	return (spider.contact.onewayGround and diff < -24)
end

local function SpiderSkid(spider)
	if not(action.OnGround(spider)) then return end

	local direction = action.GetKickDirection(spider)
	if spider.type == "jumper" then
		SetVelocity(spider, 120 * direction)
		if not(spider.timer) then
			spider.timer = true
			local function Jumpy()
				spider.timer = false
				SetVelocity(spider, 300 * direction, 400)
			end	
			eapi.AddTimer(spider.body, 0.5, Jumpy)
		end
	elseif math.abs(spider.vel.x) > 200 then
		SetVelocity(spider, 120 * direction)
	end

	spider.downJump = ShouldDownJump(spider)
end

local function WayPoint(spider, waypoint)
	if action.OnGround(spider) then
		local diff = action.HeightDifference(spider.body)
		local direction = action.GetKickDirection(spider)
		if waypoint == "jump" then
			spider.contact.ground = false
			local yVel = diff < 0 and 300 or 500
			SetVelocity(spider, 200 * direction, yVel)
		elseif waypoint == "jump-back" then
			direction = (spider.side and -1) or 1
			spider.contact.ground = false
			SetVelocity(spider, -200 * direction, 200)
		elseif waypoint == "mid-jump" then
			spider.contact.ground = false
			SetVelocity(spider, 300 * direction, 600)
		elseif waypoint == "long-jump" then
			spider.contact.ground = false
			SetVelocity(spider, 500 * direction, 600)
		end
	end
end

local function MarkDead(spider)
	if not(spider.type == "jumper") then
		action.MarkMobDead(spider.parent or spider)
	end
end

local function Drown(spider)
	util.RemoveFromPointerMap(spider.killZoneObj)
	util.RemoveFromPointerMap(spider.shapeObj)
	spider.shapeObj = nil
	spider.killZoneObj = nil
	spider.gravity = vector.null	
	local tile = spider.tile
	local dir = (spider.side and 1) or -1
	local maxAngle = (math.pi / 3)
	local speed = 0.02
	local angle = 0
	spider.vel = { x = 0, y = dir * 60 }
	local function Rotate()
		eapi.SetAttributes(tile, { angle = angle })
		angle = angle - dir * speed * maxAngle
		if math.abs(angle) < maxAngle then
			eapi.AddTimer(spider.body, speed, Rotate)
		else
			spider.vel = { x = 0, y = -50 }
			eapi.AddTimer(spider.body, 1, spider.Delete)
		end
	end
	Rotate()
	MarkDead(spider)
	eapi.PlaySound(gameWorld, "sound/bubbling.wav")
end

local function Patrol(spider)	
	local function Patroling()
		if spider.type == "patrol" then 
			action.StartStepFunction(spider)
			local pos = eapi.GetPos(spider.body)
			local diff = pos.x - spider.x
			if (spider.side and diff < -spider.range)
			or (not(spider.side) and diff > spider.range) then
				spider.side = not(spider.side)
				spider.animation = false
			end
			local dir = spider.side and -1 or 1
			eapi.AddTimer(spider.body, 0.1, Patroling)
			spider.vel.x = dir * 60
			Animate(spider)
		end
	end
	Patroling()
end

local spiderHealth = {
	["regular"] = 5,
	["patrol"]  = 5,
	["sitter_up"]  = 4,
	["sitter_down"]  = 4,
	["jumper"]  = 2,
}

local function IsSitter(spider)
	return string.sub(spider.type, 1, 6) == "sitter"
end

local function SpiderDie(spider)
	action.Crush(0.8)()
	MarkDead(spider)
end

Put = function(pos, side, type, range)
	type = type or "regular"
	side = side or false
	local spider = {
		x		= pos.x,
		y		= pos.y,
		w		= 128,
		h		= 64,
		name		= "spider",
		type		= type,
		health		= spiderHealth[type],
		depth		= 0.1,
		side		= side,
		shape		= spiderShape,
		killZone	= spiderShape,
		gravity		= {x=0, y=-1500},
		vel		= {x=0, y=0},
		restingSprite	= stillSpider,
		range		= range,
		dieImage	= effects.ShatterImage(0, 64),
		ShootEffect	= SpiderShootEffect,
		Scatter		= SpiderScatter,
		Activate	= KickSpider,
		Collide		= SpiderSkid,
		useGibs		= true,
		Drown		= Drown,
		WayPointHandler = WayPoint,
		OnDeath		= SpiderDie,
		Kill		= action.Die,
	}
	if action.IsMobDead(spider) then return end
	if IsSitter(spider) then
		local name = "image/wood.png"
		local frame = { { 320, 64 }, { 128, 128 } }
		spider.tileOffset = { x = -64, y = -64 }
		spider.vFlip = 	(type == "sitter_up")
		spider.restingSprite = eapi.NewSpriteList(name, frame)
		local shape  = { l = -42, r = 42, b = -38, t = 48 }
		spider.killZone = shape
		spider.shape = shape
	end
	object.VerticalHalt(spider)
	action.MakeActor(spider)
	if not(IsSitter(spider)) then
		IdleAnimate(spider)
	end
	Patrol(spider)
	return spider
end

local function Dead(z)
	return function(pos)
		local tile = eapi.NewTile(staticBody, pos, nil, stillSpider, z)
		eapi.SetAttributes(tile, { flip = { false, true } })
	end
end

spider = {
	Dead = Dead,
	Put = Put,
}
return spider
