dofile("script/object.lua")

local bats = {}
local stillBat = eapi.TextureToSpriteList("image/bat-sleeps.png", {256, 128})
local flyBat = eapi.TextureToSpriteList("image/bat.png", {256, 128})

local function BatVerticalDecision(body, distance)
	local heightDiff = action.HeightDifference(body)
	if heightDiff > -64 then
		return util.Random(480, 520)
	elseif math.abs(distance) < 128 then
		return util.Random(190, 210)
	else
		return util.Random(320, 350)
	end
end

local function KickBat(bat)
	local tile = bat.tile
	object.SimpleStep(bat)
	local function KickBatCallback()
		if not(bat.animation) then
			eapi.SetSpriteList(tile, flyBat)
			local fps = 60 + math.floor(4 * util.Random())
			eapi.Animate(tile, eapi.ANIM_LOOP, fps)
			bat.animation = true
		end
		local distance = action.DistanceToPlayer(bat)
		local direction = bat.wayX or action.GetKickDirection(bat)
		local velY = BatVerticalDecision(bat.body, distance)
		bat.vel = { x = direction * 100, y = velY }
		eapi.AddTimer(bat.body, 0.5, KickBatCallback)
		common.BatSound()
		bat.wayX = nil
	end
	KickBatCallback()
end

local table = { }

local function Register(bat)
	if bat.groupID then
		if table[bat.groupID] == nil then
			table[bat.groupID] = { }
		end
		table[bat.groupID][bat] = bat
	end
end

local function RaiseGroup(groupID)
	local function Raise(id)
		util.Map(action.MaybeActivate, table[id])
	end
	if type(groupID) == "table" then
		for _, v in pairs(groupID) do			
			Raise(v)
		end
	else
		Raise(groupID)
	end
end

local function BatShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
	RaiseGroup(actor.groupID)
end

local function WayPoint(bat, waypoint)
	if waypoint == "left" then
		bat.wayX = -1
	elseif waypoint == "right" then
		bat.wayX = 1
	end
end

local batShape = { l=96, r=160, b=32, t=104 }

local function Put(pos, groupID, z)
	z = z or -1
	local bat = {
		x		= pos.x,
		y		= pos.y,		
		w		= 256,
		h		= 128,
		health		= 3,
		depth		= z,
		name		= "bat",
		side		= false,
		shape		= batShape,
		killZone	= batShape,
		groupID		= groupID,
		gravity		= {x=0, y=-1500},
		vel		= {x=0, y=0},
		restingSprite	= stillBat,
		dieImage	= effects.ShatterImage(256, 0),
		ShootEffect	= BatShootEffect,
		pressure	= 500,
		Activate	= KickBat,
		wakeupDelay	= 0.5 * util.Random(),
		OnDeath		= action.MarkMobDead,
		WayPointHandler = WayPoint,
		useGibs		= true,
	}
	if action.IsMobDead(bat) then return end		
	object.CompleteHalt(bat)
	action.MakeActor(bat)
	Register(bat)
end

bat = {
	Put = Put,
	RaiseGroup = RaiseGroup,
}
return bat
