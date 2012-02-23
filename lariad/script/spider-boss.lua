dofile("script/object.lua")
dofile("script/Acid.lua")

local strength = 75
local img = eapi.TextureToSpriteList("image/spider-boss.png", {256, 256})
local shadowFileName = { "image/spider-boss-small.png", filter = true }
local shadowImg = eapi.TextureToSpriteList(shadowFileName, {64, 64})

local function Speed(health)
	return math.floor(1 + 3 * health / (strength + 1))
end

local spitVelocities = {
	{ x =  600, y =  200 },
	{ x =  500, y =  175 },
	{ x =  400, y =  150 },
	{ x =  300, y =  125 },
	{ x =  200, y =  100 },
	{ x =  100, y =   75 },
	{ x =    0, y =   50 },
	{ x = -100, y =   25 },
	{ x = -200, y =    0 },
	{ x = -100, y =   25 },
	{ x =    0, y =   50 },
	{ x =  100, y =   75 },
	{ x =  200, y =  100 },
	{ x =  300, y =  125 },
	{ x =  400, y =  150 },
	{ x =  500, y =  175 },
}

local madSpit = {
	{ x = -200, y =    0 },
	{ x = -100, y =   25 },
	{ x =    0, y =   50 },
	{ x =  100, y =   75 },
	{ x =  200, y =  100 },
	{ x =  300, y =  125 },
	{ x =  400, y =  150 },
	{ x =  500, y =  175 },
	{ x =  600, y =  200 },
}

local hitRed  = { color = { r = 0.8, g = 0.4, b = 0.4 } }
local white   = { color = { r = 1.0, g = 1.0, b = 1.0 } }

local function AcidGreen(amount)
	return util.LerpColors({ r = 0.3, g = 0.9, b = 0.0 },
			       { r = 1.0, g = 1.0, b = 1.0 },
			       amount)
end

local music
util.PreloadSound("sound/boss.ogg")

local function Kick(boss)
	local spitPlace = 1
	local madTimeout = 10
	local Callback
	boss.KickCallback()
	progressBar.Init(boss.health)
	music = eapi.PlaySound(gameWorld, "sound/boss.ogg", -1, 1, 2)
	eapi.FadeOut(ambient, 2)
	local function StopAnim()
		util.Map(eapi.StopAnimation, boss.tiles)
		eapi.SetFrame(boss.tiles[1], 0)
		eapi.SetFrame(boss.tiles[2], 0)
	end
	local function Emit(vel)
		Acid.Ball(vector.Add(boss, { x = 150, y = 140 }), vel)
		eapi.PlaySound(gameWorld, "sound/spit.ogg")
	end
	local function Spit()
		StopAnim()
		Emit(spitVelocities[spitPlace % #spitVelocities + 1])
		spitPlace = spitPlace + 1
	end
	local function MadSpit()
		local i = 1
		local function SpitOut()
			if i < 5 then
				eapi.AddTimer(boss.body, 0.07, SpitOut)
				Emit(madSpit[5 + i])
				Emit(madSpit[5 - i])
				i = i + 1
			else
				Callback()
			end
		end
		effects.Fade(1.0, 0.0, 0.35, nil, boss.tile,
			     nil, nil, boss.body, AcidGreen)
		Emit(madSpit[5])
		StopAnim()
		SpitOut()
	end
	local function StartTremble()
		local dir = 1
		local times = 20
		local function Tremble()
			if times == 0 then
				dir = 0
			else
				dir = -dir
				times = times - 1
				eapi.AddTimer(boss.body, 0.1, Tremble)
			end
			local pos = { x = boss.x, y = boss.y + dir * 4 }
			eapi.SetPos(boss.body, pos)
		end
		Tremble()
	end
	local function Mad()
		StartTremble()
		eapi.PlaySound(gameWorld, "sound/powerup.ogg")
		util.AnimateTable(boss.tiles, eapi.ANIM_CLAMP, 2, 0)
		effects.Fade(0.0, 1.0, 2.0, MadSpit, boss.tile,
			     nil, nil, boss.body, AcidGreen)
	end
	Callback = function()
		local timeout = 0.2 + 0.1 * Speed(boss.health)
		if timeout > 0.45 or madTimeout > 0 then
			eapi.AddTimer(boss.body, 0.3, Spit)
			util.AnimateTable(boss.tiles, eapi.ANIM_CLAMP, 16, 0)
			eapi.AddTimer(boss.body, timeout, Callback)
			madTimeout = madTimeout - 1
		else
			eapi.AddTimer(boss.body, timeout, Mad)
			madTimeout = util.Random(8, 12)
		end		
	end
	eapi.AddTimer(boss.body, 2.0, Callback)
end

local function ShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
	if not(actor.dead) then progressBar.Decrement() end
	eapi.SetAttributes(actor.tile, hitRed)
	local function RestoreColor()
		if not(actor.dead) then
			eapi.SetAttributes(actor.tile, white)
		end
	end
	eapi.AddTimer(actor.body, 0.1, RestoreColor)
end

local shape    = { l = 32, r = 224, b = 96, t = 224 }
local killZone = { l = 96, r = 140, b = 0,  t = 192 }

local function ShowJoke()
	mainPC.StopInput()
	util.GameMessage(txt.castleJoke, camera, mainPC.StartInput)	
end

local function Die(boss)
	eapi.PlaySound(gameWorld, "sound/bone-crush.wav")
	ambient = eapi.PlaySound(gameWorld, "sound/creepy.ogg", -1, 1, 5)
	eapi.FadeOut(music, 4)
	eapi.SetAttributes(boss.tile, white)
	-- eapi.AddTimer(staticBody, 1, ShowJoke)
	boss.gravity = {x=0, y=-1500}
	boss.dead = true
	progressBar.Remove()
	boss.DeathCallback()
end

local function Put(pos, DeathCallback, KickCallback)
	local boss = {
		x		= pos.x,
		y		= pos.y,
		w		= 256,
		h		= 256,
		health		= strength,
		depth		= -4.4,
		side		= true,
		shape		= shape,
		killZone	= killZone,
		gravity		= {x=0, y=0},
		vel		= {x=0, y=0},
		restingSprite	= img,
		dieImage	= effects.ShatterImage(0, 256),
		Put		= Put,
		ShootEffect	= ShootEffect,
		Activate	= Kick,
		useGibs		= true,
		pressure	= 500,
		OnDeath		= Die,
		DeathCallback	= DeathCallback,
		KickCallback	= KickCallback,
	}
	action.MakeKicker({ l = pos.x - 100, r = pos.x + 500 + boss.w,
			    b = pos.y - 200, t = pos.y + 100 + boss.h })
	object.CompleteHalt(boss)
	action.MakeActor(boss)

	boss.tiles = { boss.tile }

	-- shadow
	local offset = { x = 8, y = -16 }
	local shadowColor = { r = 0, g = 0, b = 0, a = 0.9 }
	boss.tiles[2] = eapi.NewTile(boss.body, offset, nil, shadowImg, -4.47)
	eapi.SetAttributes(boss.tiles[2], { size = { 256, 256 },
					    flip = { true, false },
					    color = shadowColor })

	return boss
end

spiderBoss = {
	Put = Put,
}
return spiderBoss
