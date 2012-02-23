dofile("script/object.lua")
dofile("script/Energy.lua")

local bigWaspStrength = 40
local stillBigWasp = eapi.TextureToSpriteList("image/big-wasp.png", {384, 192})
local shadowFileName = { "image/big-wasp-small.png", filter = true }
local shadowImg = eapi.TextureToSpriteList(shadowFileName, {96, 48})

local function GetFireballOrigin(bigWasp)
	local pos = eapi.GetPos(bigWasp.body)
	return vector.Offset(pos, 192, 128)
end

local function BigWaspSpeed(health)
	return math.floor(1 + 3 * health / (bigWaspStrength + 1))
end

local function Ground(bigWasp)	
	local function CheckHeight()
		local pos = eapi.GetPos(bigWasp.body)
		if pos.y > bigWasp.y then
			bigWasp.diveHealth = bigWasp.health
			bigWasp.ascending = false
			bigWasp.vel.y = 0
			bigWasp.Callback()
		else			
			eapi.AddTimer(bigWasp.body, 0.01, CheckHeight)
		end
	end
	local function Ascend()
		bigWasp.vel.y = 200
		CheckHeight()
	end
	if not(bigWasp.ascending) then
		energy.Put(GetFireballOrigin(bigWasp), { x =  500, y = 0 })
		energy.Put(GetFireballOrigin(bigWasp), { x = -500, y = 0 })
		eapi.AddTimer(bigWasp.body, 1.0, Ascend)
		bigWasp.gravity = { x = 0, y = 0 }
		bigWasp.ascending = true
	end
end

local music
util.PreloadSound("sound/boss.ogg")

local function KickBigWasp(bigWasp)
	local counter = 0
	object.SimpleStep(bigWasp)
	progressBar.Init(bigWasp.health)
	music = eapi.PlaySound(gameWorld, "sound/boss.ogg", -1, 1, 2)
	local function RegularMovement()
		local pos = eapi.GetPos(bigWasp.body)
		local dir = (bigWasp.toLeft and -1) or 1
		bigWasp.toLeft = (pos.x - bigWasp.x > dir * 50)
		bigWasp.vel.x = dir * 50
		bigWasp.vel.y = -bigWasp.vel.y
		if counter % BigWaspSpeed(bigWasp.health) == 0 then
			energy.Put(GetFireballOrigin(bigWasp))
		end
		eapi.AddTimer(bigWasp.body, 0.5, bigWasp.Callback)
		counter = counter + 1
	end
	local function Dive()
		bigWasp.vel =  { x = 0, y = -200 }
		bigWasp.gravity = { x = 0, y = -1500 }
	end
	local function Tremble()
		local dir = 1
		local tick = 20
		bigWasp.vel.y = 0
		local function Shake()
			dir = -dir
			tick = tick - 1
			bigWasp.vel.x = 100 * dir
			local Fn = (tick > 0) and Shake or Dive
			eapi.AddTimer(bigWasp.body, 0.05, Fn)
		end
		Shake()
	end
	bigWasp.Callback = function()
		if bigWasp.health < 0.5 * bigWaspStrength 
		and not(bigWasp.diveHealth == bigWasp.health)
		and (counter % 11) > util.Random(5, 9) then		
			eapi.PlaySound(gameWorld, "sound/powerup.ogg")
			Tremble()
			counter = 0
		else
			RegularMovement()
		end
	end
	bigWasp.Callback()

	local function BigWaspBuzz()
		if bigWasp.dead then return end
		eapi.PlaySound(gameWorld, "sound/wasp.ogg", 0, 0.5)
		eapi.AddTimer(bigWasp.body, 0.5 * util.Random(), BigWaspBuzz)
	end
	BigWaspBuzz()
end

local function BigWaspShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
	if not(actor.dead) then progressBar.Decrement() end
end

local bigWaspShape = { l=192-32, r=192+32, b=32, t=144 }

local function BigWaspDie(bigWasp)
	eapi.PlaySound(gameWorld, "sound/bone-crush.wav")
	eapi.FadeOut(music, 4)
	bigWasp.gravity = {x=0, y=-1500}
	bigWasp.dead = true
	progressBar.Remove()
	bigWasp.DeathCallback()
end

local function Put(x, y, DeathCallback)
	local bigWasp = {
		x		= x,
		y		= y,
		w		= 384,
		h		= 192,
		health		= bigWaspStrength,
		depth		= 0.1,
		side		= side or false,
		shape		= bigWaspShape,
		killZone	= bigWaspShape,
		gravity		= {x=0, y=0},
		vel		= {x=0, y=50},
		restingSprite	= stillBigWasp,
		dieImage	= effects.ShatterImage(256, 256),
		Put		= Put,
		ShootEffect	= BigWaspShootEffect,
		Activate	= KickBigWasp,
		useGibs		= true,
		pressure	= 500,
		OnDeath		= BigWaspDie,
		Ground		= Ground,
		DeathCallback	= DeathCallback,
	}
	action.MakeKicker({ l = x - 180, r = x + 180 + bigWasp.w,
			    b = y - 300, t = y + 100 + bigWasp.h })
	object.CompleteHalt(bigWasp)
	action.MakeActor(bigWasp)
	eapi.Animate(bigWasp.tile, eapi.ANIM_LOOP, 40)

	local offset = { x = 8, y = -16 }
	local shadowColor = { r = 0, g = 0, b = 0, a = 0.6 }
	local tile = eapi.NewTile(bigWasp.body, offset, nil, shadowImg, -0.1)
	eapi.SetAttributes(tile, { color = shadowColor, size = { 384, 192 } })
	eapi.Animate(tile, eapi.ANIM_LOOP, 40)

	return bigWasp
end

bigWasp = {
	Put = Put,
}
return bigWasp
