dofile("script/object.lua")
dofile("script/Energy.lua")

local wasps = {}
local stillWasp = eapi.TextureToSpriteList("image/wasp.png", {128, 128})
local waspTurn = eapi.TextureToSpriteList("image/wasp-turn.png", {128, 128})	

local function GetWaspPos(wasp)
	local pos = eapi.GetPos(wasp.body)
	pos.x = pos.x + 0.5 * wasp.w
	pos.y = pos.y + 0.5 * wasp.h
	return pos
end

local function WaspDecision(wasp)
	local waspPos = GetWaspPos(wasp)
	local playerPos = eapi.GetPos(mainPC.body)
	local attackVector = vector.Sub(playerPos, waspPos)
	return vector.Normalize(attackVector, 150)
end

local function Animate(wasp, tile, turnAnim)
	if turnAnim then
		eapi.SetSpriteList(tile, waspTurn)
		eapi.Animate(tile, eapi.ANIM_CLAMP, 32)
	else
		eapi.SetSpriteList(tile, stillWasp)
		eapi.Animate(tile, eapi.ANIM_LOOP, 40, wasp.random)
	end
	action.SetDirection(wasp, tile)
end

local function MakeOverlay(wasp)
	wasp.overlay = eapi.NewTile(wasp.body, nil, nil, wasp.restingSprite, 6)
	eapi.SetAttributes(wasp.overlay,
			   { flip  = { wasp.side, false },
			     color = { r=1.0, g=1.0, b=1.0, a=0.2 } })
end

local steps = 5

local function ShouldInvadersTurn(counter)
	return counter == 0 or counter == 2 * steps
end

local function InvaderDecision(wasp, counter)
	if ShouldInvadersTurn(counter) then
		wasp.vel = { x = 0, y = -wasp.invaderSpeed }
	elseif counter < 2 * steps then
		wasp.vel = { x = wasp.invaderSpeed, y = 0 }
	else
		wasp.vel = { x = -wasp.invaderSpeed, y = 0 }
	end
	return (counter + 1) % (4 * steps)
end

local function WaspSound()
	eapi.PlaySound(gameWorld, "sound/wasp.ogg")
end

local function KickWasp(wasp)
	local counter = steps
	local tile = wasp.tile
	object.SimpleStep(wasp)
	if wasp.type == "invader" then
		effects.Fade(0, 1, 2, nil, tile, nil, nil, wasp.body)
	end
	local function KickWaspCallback()
		if not(wasp.animation) then
			Animate(wasp, wasp.tile)
			Animate(wasp, wasp.overlay)
			wasp.animation = true
		end
		local shouldTurn = false
		if wasp.type == "invader" then
			shouldTurn = ShouldInvadersTurn(counter)
			counter = InvaderDecision(wasp, counter)
		else
			local distance = action.DistanceToPlayer(wasp)
			shouldTurn = action.ShouldTurn(distance, wasp.side)
			wasp.vel = WaspDecision(wasp)
			local angle = 60 * (util.Random() - 0.5)
			wasp.vel = vector.Rotate(wasp.vel, angle)
		end
		if shouldTurn then
			Animate(wasp, wasp.tile, "turn")
			Animate(wasp, wasp.overlay, "turn")
			wasp.side = not(wasp.side)
			wasp.animation = false
		end
		eapi.AddTimer(wasp.body, 0.5, KickWaspCallback)
		eapi.AddTimer(wasp.body, 0.5 * util.Random(), WaspSound)
	end
	KickWaspCallback()
end

local function WaspShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
end

local waspShape = { l=16, r=112, b=32, t=96 }

local waspDeadly = { l=16, r=112, b=32, t=96 }

local function WaspDie(wasp)
	wasp.gravity = {x=0, y=-1500}
	eapi.Destroy(wasp.overlay)
	if not(wasp.type == "invader") then
		action.MarkMobDead(wasp)
	end
	wasp.dead = true
end

local function Collide(wasp)
	local x = wasp.vel.x
	local y = wasp.vel.y
	if wasp.type == "invader" then
		action.Die(wasp)
	elseif wasp.contact.ceiling or wasp.contact.ground then
		wasp.vel.x = util.Sign(x) * math.abs(y)
		wasp.vel.y = -util.Sign(y) * math.abs(x)
	elseif wasp.contact.left or wasp.contact.right then
		wasp.vel.x = -util.Sign(x) * math.abs(y)
		wasp.vel.y = util.Sign(y) * math.abs(x)
	end
end

local function WayPoint(wasp, waypoint)
	if waypoint == "down" then
		wasp.vel.y = -150
	end
end

local function Kill(wasp, killer)
	if killer.name == "Beam" then
		action.Die(wasp)
	end
end

local function Put(pos, side, type)
	local downForce = ((type == "invader") and 0) or -100
	type = type or "regular"
	local wasp = {
		x		= pos.x,
		y		= pos.y,
		w		= 128,
		h		= 128,
		health		= 5,
		depth		= 0.1,
		type		= type,
		side		= side or false,
		shape		= waspShape,
		killZone	= waspDeadly,
		gravity		= { x = 0, y = downForce },
		vel		= { x = 0, y = 0 },
		restingSprite	= stillWasp,
		dieImage	= effects.ShatterImage(192, 128),
		ShootEffect	= WaspShootEffect,
		Activate	= KickWasp,
		useGibs		= true,
		pressure	= 500,
		invaderSpeed	= 120,
		OnDeath		= WaspDie,
		Collide		= Collide,
		WayPointHandler = WayPoint,
		ignoreObstacle	= true,
		Kill		= Kill,
		name		= "wasp",
	}
	if action.IsMobDead(wasp) then return end		
	wasp.EmitFireBall = function(target)
		local pos = eapi.GetPos(wasp.body)
		energy.Put(vector.Offset(pos, 64, 64), target)
	end
	wasp.random = util.Random()
	object.DoNotHalt(wasp)
	action.MakeActor(wasp)
	MakeOverlay(wasp)
	Animate(wasp, wasp.tile)
	Animate(wasp, wasp.overlay)
	return wasp
end

wasp = {
	Put = Put,
}
return wasp
