local arrowCount	= 9
local STATE_RESTING	= 1
local STATE_ATTACKING	= 2
local STATE_RETREATING	= 3

local img = eapi.TextureToSpriteList("image/arrow.png", {64, 64})

local function Animate(x, i, dir)
	if not(x.tile) then return end
	eapi.Animate(x.tile, eapi.ANIM_LOOP, dir * 16, 0.5 * i / arrowCount)
end
	
local function Attack(x, i)
	eapi.SetVel(x.body, { x = 50 * i, y = -20 * x.dir * i })
	Animate(x, i, 1.5)
end

local function Retreat(x, i)
	eapi.SetVel(x.body, { x = -10 * i, y = 4 * x.dir *i })
	Animate(x, i, -1)
end

local function Rest(x, i)
	eapi.SetVel(x.body, { x = 0, y = 0 })
	if x.tile then eapi.StopAnimation(x.tile) end
end

local function Init(x, i)
	local box = { l = -16, r = 16, b = -16, t = 16 }
	x.killer = common.KillerFloor(box, x.body)
	x.killer.KillPlayer = destroyer.ShatterDeath
	if x.tile then
		eapi.SetAttributes(x.tile, { flip = { false, x.dir < 0 } })
	end
end

local function ForAll(arrow, Fn)
	for i = 1, arrowCount, 1 do
		Fn(arrow.tail[i], i)
	end
	Fn(arrow, arrowCount)
end

local function Diff(arrow)
	local p1 = eapi.GetPos(arrow.tail[1].body)
	local p2 = eapi.GetPos(arrow.body)
	return vector.Distance(p1, p2)
end

local function DoAttack(arrow)
	eapi.PlaySound(gameWorld, "sound/slash.ogg")
	arrow.waitingForAttack = false
	arrow.state = STATE_ATTACKING
	ForAll(arrow, Attack)
end

local wallDustColor = { r = 0.31, g = 0.32, b = 0.42 }

local function Dust(arrow)
	local pos = eapi.GetPos(arrow.body)
	arrow.dust = effects.Smoke(vector.Offset(pos, 16, -16),
				   { vel = { x = 0, y = -70 },
				     disableProximitySensor = true,
				     color = wallDustColor,
				     interval = 0.05,
				     variation = 30,
				     life = 1.0,
				     dim = 0.2,
				     z = -1.9, })
	local function StopDust()
		arrow.dust.Stop()
		arrow.dust = nil
	end
	eapi.AddTimer(arrow.body, 0.5, StopDust)
	arrow.dust.Kick()	
end

local function Collide(arrow)
	if arrow.state == STATE_RESTING and not(arrow.waitingForAttack) then
		local wait = 1.5 + 0.5 * util.Random()
		eapi.AddTimer(arrow.body, wait, function() DoAttack(arrow) end)
		arrow.waitingForAttack = true
	elseif arrow.state == STATE_ATTACKING and Diff(arrow) > 200 then
		eapi.PlaySound(gameWorld, "sound/gears.ogg")
		arrow.state = STATE_RETREATING
		ForAll(arrow, Retreat)
		Dust(arrow)
	elseif arrow.state == STATE_RETREATING and Diff(arrow) < 100 then
		arrow.state = STATE_RESTING
		ForAll(arrow, Rest)
	end
end

local function SubArrow(arrow, i)
	local z = arrow.depth - 0.1 + 0.001 * i
	local subArrowBody = eapi.NewBody(gameWorld, arrow)
	local tile = eapi.NewTile(subArrowBody, arrow.tileOffset, nil,
				  arrow.restingSprite, z)
	return { body = subArrowBody, tile = tile }
end

local function Kick(arrow)
	arrow.waitingForAttack = true
	DoAttack(arrow)
end

local function GetShape(dir)
	if dir > 0 then 
		return { l = 20, r = 24, b = -16, t = -12 }
	else
		return { l = 20, r = 24, b = 12, t = 16 }
	end
end

local function PutPut(pos, dir)
	local arrow = {
		x		= pos.x,
		y		= pos.y,
		w		= 64,
		h		= 64,
		health		= 1,
		depth		= -1.1,
		tileOffset	= { x = -32, y = -32 },
		shape		= GetShape(dir),
		gravity		= { x = 0, y = 0 },
		vel		= { x = 0, y = 0 },
		restingSprite	= img,
		dir		= dir,
		tail		= { },
		Collide		= Collide,
		Activate	= Kick,
		Die		= function() end,
		state		= STATE_RESTING,
	}

	object.CompleteHalt(arrow)
	action.MakeActor(arrow)
	eapi.Destroy(arrow.tile)
	arrow.tile = nil

	for i = 1, arrowCount, 1 do
		local x = SubArrow(arrow, i)
		arrow.tail[i] = x
		x.dir = dir
	end

	ForAll(arrow, Init)

	eapi.AddTimer(arrow.body, util.Random(), arrow.MaybeActivate)
	
	for i = 1, 3, 1 do 
		local attr = { size = { 48, 48 }, flip = { false, dir < 0 } }
		Occlusion.put('v', pos.x - 8, pos.y - 32, -1.01, attr)
	end

	return arrow
end

local function Delete(arrow)
	if arrow.dust then arrow.dust.Stop() print("Bene") end
	for i = 1, arrowCount, 1 do
		object.Delete(arrow.tail[i].killer)
	end
	arrow.Delete()
end

local function Put(bb, dir)
	local arrow = nil
	local pos = { x = 0.5 * (bb.r + bb.l), y = 0.5 * (bb.t + bb.b) }
	proximity.Create(function() arrow = PutPut(pos, dir or 1) end, 
			 function() Delete(arrow) end, 
			 nil, bb)	
end

arrows = {
	Put = Put,
}
return arrows
