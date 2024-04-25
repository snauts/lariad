dofile("script/Energy.lua")

local holderImg = common.IndustrialImg({ { 64, 208 }, { 64, 48 } })
local gearImg = eapi.TextureToSpriteList("image/gear.png", {32, 32})

local function CreateGears(body, pos, z)
	eapi.NewTile(body, vector.Offset(pos, 0, 4), nil, holderImg, z)
	eapi.NewTile(body, pos, nil, holderImg, z + 0.2)
	local function Gear(x)
		local pos2 = vector.Offset(pos, x, 19)
		return eapi.NewTile(body, pos2, nil, gearImg, z + 0.1)
	end
	local gears = { tiles = { } }
	gears.tiles[1] = Gear(-4)
	gears.tiles[2] = Gear(36)
	gears.Stop = function()
		util.Map(eapi.StopAnimation, gears.tiles)
	end
	gears.Animate = function(dir)
		local function AnimateGear(tile)
			eapi.Animate(tile, eapi.ANIM_LOOP, 16 * dir, 0.1)
		end
		util.Map(AnimateGear, gears.tiles)
	end
	return gears
end

local function SetVelocity(bomber)
	bomber.gears.Animate(bomber.dir)
	eapi.SetVel(bomber.body, { x = bomber.dir * 500, y = 0 })
end

local function KickBomber(bomber)
	SetVelocity(bomber)
	local function CallBack()
		local pos = eapi.GetPos(bomber.body)
		if (bomber.dir > 0 and pos.x > bomber.bb.r)
		or (bomber.dir < 0 and pos.x < bomber.bb.l) then
			bomber.dir = -bomber.dir
			SetVelocity(bomber)
		end
		eapi.AddTimer(bomber.body, 0.1, CallBack)
	end
	CallBack()

	local function Bomb()
		local pos = eapi.GetPos(bomber.body)
		local xVel = 300 * bomber.dir
		local gravity = { x = -2 * xVel, y = 0 }
		if bomber.isBombing then
			energy.Put(pos, { x = xVel, y = -500 }, -2.2, gravity)
		end
		eapi.AddTimer(bomber.body, 0.15, Bomb)		
	end
	Bomb()
end

local nozzleImg = common.IndustrialImg({{ 320, 128 }, { 64, 64 }})

local function Put(bb)
	local bomber = {
		x		= bb.l,
		y		= bb.b,
		w		= 64,
		h		= 32,
		dir		= 1,
		bb		= bb,
		health		= 42,
		depth		= -2,
		isBombing	= false,
		tileOffset	= { x = -32, y = -32 },
		shape		= { l = -32, r = 32, b = -32, t = 32 },
		killZone	= { l = -32, r = 32, b = -32, t = 32 },
		restingSprite	= nozzleImg,
		Activate	= KickBomber,
		Shoot		= function(projectile) end,
	}
	
	object.CompleteHalt(bomber)
	action.MakeActor(bomber)
	bomber.MaybeActivate()

	proximity.Create(function() bomber.isBombing = true end, 
			 function() bomber.isBombing = false end, 
			 nil, { l = bb.l - 200, r = bb.r + 400,
				b = bb.b - 280, t = bb.b + 70 })

	eapi.SetAttributes(bomber.body, { sleep = false })
	bomber.gears = CreateGears(bomber.body, { x = -32, y = 16 }, -1.5)
end

local fixedBomber = { }

local function TriggerFixed(bb, state)
	state = state or fixedBomber
	proximity.Create(function() state.on = true end, 
			 function() state.on = false end, 
			 nil, bb)
end

local function Fixed(pos, pattern, state, vel, attributes)
	local num = 0
	pattern = pattern or { 1 }
	state = state or fixedBomber
	vel = vel or { x = 0, y = -400 }
	local tileOffset = { x = -32, y = -32 }
	local body = eapi.NewBody(gameWorld, pos)
	local tile = eapi.NewTile(body, tileOffset, nil, nozzleImg, -2.5)
	if attributes then eapi.SetAttributes(tile, attributes) end
	local function EmitBall()
		if state.on then
			energy.Put(pos, vel, -2.6)
		end
		local i = (num % #pattern) + 1
		eapi.AddTimer(body, pattern[i], EmitBall)
		num = num + 1
	end
	eapi.AddTimer(body, util.Random(), EmitBall)
end

local horizontalBomber = { }

local function TriggerHorizontal(bb)
	TriggerFixed(bb, horizontalBomber)
end

local function Horizontal(pos, pattern)
	Fixed(pos, pattern, horizontalBomber, { x = 400, y = 0 },
	      { angle = vector.ToRadians(90) })
end

bomber = {
	Horizontal = Horizontal,
	TriggerHorizontal = TriggerHorizontal,
	CreateGears = CreateGears,
	TriggerFixed = TriggerFixed,
	Fixed = Fixed,
	Put = Put,
}
return bomber
