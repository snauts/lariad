dofile("script/object.lua")

local blobs = {}
local stillBlob = eapi.TextureToSpriteList("image/blob.png", {128, 64})

local function KickBlob(blob)
	eapi.PlaySound(gameWorld, "sound/snarl.ogg")	
	local function KickBlobCallback()
		eapi.Animate(blob.tile, eapi.ANIM_CLAMP, 40)	
		eapi.PlaySound(gameWorld, "sound/splat.ogg")	
		local dir = action.GetKickDirection(blob)
		eapi.SetGravity(blob.body, blob.gravity)
		eapi.SetVel(blob.body, { x = dir * 200, y = 400 })
		eapi.AddTimer(blob.body, 0.9, KickBlobCallback)
	end
	KickBlobCallback()
end

local function TouchInactiveBlob()
	local state = true
	return function ()
		       if state then
			       state = false
		       end
	       end
end

local function BlobShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
end

local function BlobWakeCondition()
	return game.GetState().hasSterling
end

local blobShape = { l=16, r=112, b=0, t=64 }

local blobBottom = { l=32, r=96, b=-4, t=48 }

local function Put(pos)
	local blob = {
		x		= pos.x,
		y		= pos.y,
		w		= 128,
		h		= 64,
		name		= "blob",
		health		= 5,
		depth		= 0.1,
		pressure	= 1000,
		shape		= blobShape,
		killZone	= blobBottom,
		gravity		= {x=0, y=-1500},
		restingSprite	= stillBlob,
		dieImage	= effects.ShatterImage(0, 128),
		TouchInactive	= TouchInactiveBlob(),
		ShootEffect	= BlobShootEffect,
		WakeCondition	= BlobWakeCondition,
		OnDeath		= action.MarkMobDead,
		Activate	= KickBlob,
		useGibs		= true,		
	}
	if action.IsMobDead(blob) then return end		
	action.MakeKicker({ l = pos.x - 320, r = pos.x + 320 + blob.w,
			    b = pos.y -  16, t = pos.y + 256 + blob.h })
	object.CompleteHalt(blob)
	action.MakeActor(blob)
	blobs[blob] = blob
end

local function Refresh()
	local oldBlobs = blobs
	blobs = { }
	for _, blob in pairs(oldBlobs) do
		blob.Delete()
		Put(blob)
	end
end

blob = {
	Put = Put,
	Refresh = Refresh,
}
return blob
