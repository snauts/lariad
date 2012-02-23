local komodos = {}
local idle = eapi.TextureToSpriteList("image/komodo-idle.png", {256, 64})
local still = eapi.TextureToSpriteList("image/komodo.png", {256, 64})
local turn = eapi.TextureToSpriteList("image/komodo-turn.png", {256, 64})	
local die = eapi.TextureToSpriteList("image/komodo-die.png", {256, 64})	

local komodoShape1 = { l=32, b=24, r=224, t=56 }

local function KickKomodo(actor)
	action.StartStepFunction(actor)
	if actor.isDead then return nil end
	local body = actor.body
	local tile = actor.tile
	local function CallBack()
		KickKomodo(actor)
	end
	if not(actor.animation) then
		eapi.SetSpriteList(tile, still)
		eapi.SetAttributes(tile, { flip = { actor.side, false} })
		eapi.Animate(tile, eapi.ANIM_LOOP, 32)
		actor.animation = true
	end
	local distance = action.DistanceToPlayer(actor)
	if action.ShouldTurn(distance, actor.side) then
		actor.side = not(actor.side)
		eapi.SetSpriteList(tile, turn)
		eapi.SetAttributes(tile, { flip = { not(actor.side), false} })
		eapi.Animate(tile, eapi.ANIM_CLAMP, 40)
		eapi.AddTimer(body, 0.8, CallBack)
		actor.animation = false
	else
		actor.vel.x = 120 * action.GetKickDirection(actor)
		eapi.AddTimer(body, 0.1, CallBack)
	end
end

local function GibScatter(amount)
	return function()
		return { x = 1.5 * amount * util.Random() - 0.75 * amount,
			 y = amount * util.Random() }
	end
end

local function KomodoDie(actor)
	effects.Gibs(actor, GibScatter(800), 2)
	actor.isActive = true
	actor.isDead = true
	actor.vel = { x=0, y=0 }
	actor.gravity = { x=0, y=0 }
	util.RemoveFromPointerMap(actor.shapeObj)
	util.RemoveFromPointerMap(actor.killZoneObj)
	eapi.SetSpriteList(actor.tile, die)
	eapi.Animate(actor.tile, eapi.ANIM_CLAMP, 40)	
	action.MarkMobDead(actor)
end

local function KomodoShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
	actor.xOffset = 96 * ((actor.side and -1) or 1)
	effects.FewGibs(actor, GibScatter(400), 1)
end

local kDepth = 0.1
local function Put(pos, side)
	kDepth = kDepth + 0.00001
	local komodo = {
		x		= pos.x,
		y		= pos.y,
		w		= 256,
		h		= 64,
		health		= 5,
		depth		= kDepth,
		pressure	= 500,
		name		= "komodo",
		side		= side or false,
		shape		= komodoShape1,
		killZone	= komodoShape1,
		restingSprite	= idle,
		gravity		= {x=0, y=-1500},
		vel		= {x=0, y=0},
		ShootEffect	= KomodoShootEffect,
		Activate	= KickKomodo,
		Die		= KomodoDie,
		Kill		= KomodoDie,
	}
	if action.IsMobDead(komodo) then return end		
	object.VerticalHalt(komodo)
	action.MakeActor(komodo)
	eapi.Animate(komodo.tile, eapi.ANIM_LOOP, 16, util.Random())	
	return komodo
end

komodo = {
	Put = Put,
}
return komodo
