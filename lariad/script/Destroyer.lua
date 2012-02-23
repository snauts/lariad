dofile("script/Weapon.lua")

local defaultPlayerShape = { l = -25, r = 25, b = -16, t = 96 }

local function GenericDeath(player)
	player.dead = true
	eapi.pointerMap[player.shape] = nil	
	eapi.Destroy(player.shape)
	player.shape = nil
	player.DisableInput()
	destroyer.HideWeapon(player)
	eapi.AddTimer(staticBody, 4, util.GameOver)
	player.vel = { x = 0, y = 0 }
end

local function DrowningDeath(player)
	GenericDeath(player)
	eapi.PlaySound(gameWorld, "sound/bubbling.wav")

	-- Drowning animation & sound.
	eapi.SetPos(player.tile, {-64,-28})
	local drownAnim = eapi.TextureToSpriteList("image/drown.png", {128, 128})
	eapi.SetSpriteList(player.tile, drownAnim)
	eapi.Animate(player.tile, eapi.ANIM_LOOP, 24)
	
	-- Replace normal player step function with the one below. Each step it
	-- will move player downward a little bit as if drowning.
	local startPos = eapi.GetPos(player.body)
	local function DrownStep()
		local pos = eapi.GetPos(player.body)
		
		-- Move only a certain distance. Then remain there.
		if pos.y > startPos.y - 128 then
			pos.y = pos.y - 0.2
			eapi.SetPos(player.body, pos)
		else
			-- Once we've hit the bottom, do the game-over sequence
			-- and remove step function.
			eapi.SetStepFunc(player.body, nil, nil)
		end
	end
	eapi.SetStepFunc(player.body, DrownStep, nil)
end

local function FlamePos(x, y)
	local pos = eapi.GetPos(mainPC.body)
	return { x = math.floor(pos.x),
		 y = math.floor(pos.y + 64 * util.Random()) }
end

local transparent = { color = { r = 1.0, g = 1.0, b = 1.0, a = 0.5 } }
local solid	  = { color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 } }

local function SetColor(player, color)
	eapi.SetAttributes(player.tile, color)
	
	if player.handTile then
		eapi.SetAttributes(player.handTile, color)
	end
	if player.gunTile then
		eapi.SetAttributes(player.gunTile, color)
	end
end

local function BurningDeath(player)	
	if player.burning then return end
	eapi.PlaySound(gameWorld, "sound/fry.ogg")
	player.burning = true

	local flame = common.Flame(FlamePos)

	local function Crumble()
		return { x = 200 * util.Random() - 100, y = 0 }
	end

	local function Die()
		flame[1].Stop()
		flame[2].Stop()
		GenericDeath(player)
		effects.Shatter(effects.ShatterImage(128, 128),
				player, Crumble, 10.0)	
		eapi.Destroy(player.tile)
	end
	
	local function GetTile() return player.tile end
	effects.Fade(1, 0.1, 2, Die, GetTile, nil, nil, player.body,
		     function(a)
			     local color = { r = a, g = a, b = a }
			     SetColor(player, { color = color })
			     return color
		     end)
end

local function PlayerHit(player, killer, amount)
	local pos = eapi.GetPos(player.body)
	local dir = (action.Center(killer).x > pos.x)
	player.vel = { x = ((dir and -1) or 1) * amount, y = 300 }
end

local function PlayerSparks(player, killer)
	local pos = eapi.GetPos(player.body)
	pos.y = pos.y + ((player.ducked and 4) or 36)
	local diff = vector.Normalize(vector.Sub(action.Center(killer), pos))
	diff.x = math.floor(diff.x * ((player.ducked and 48) or 16))
	diff.y = math.floor(diff.y * ((player.ducked and 24) or 56))
	action.PutHitSpark(vector.Add(pos, diff))
end

local function PlayerLives(player, killer)
	local function StopInvincibility()
		SetColor(player, solid)
		player.invincible = false
	end
	if not(player.invincible) then 
		PlayerSparks(player, killer)
		game.GetState().lives = game.GetState().lives - 1
		progressBar.Lives()
		eapi.PlaySound(gameWorld, "sound/punch.ogg")
		if game.GetState().lives < 0.5 then return false end
		eapi.AddTimer(gameWorld, 2, StopInvincibility)
		SetColor(player, transparent)
		PlayerHit(player, killer, 400)
		player.invincible = true
	end
	return true
end

local function ShatterDeath(player, killer)
	if PlayerLives(player, killer) then return end

	eapi.PlaySound(gameWorld, "sound/bone-crush.wav")

	local function Explode()
		local scale = 300
		return { x=2 * scale * util.Random() - scale,
			 y=2 * scale * util.Random() - scale }
	end

	GenericDeath(player)
	effects.Shatter(effects.ShatterImage(128, 128), player, Explode, 10.0)
	effects.Gibs(player, Explode)

	-- Remove player's tile, shape, and step function.
	eapi.Destroy(player.tile)
	player.gravity = { x = 0, y = 0 }
end

local function Flies(pos, player)
	local anim = eapi.TextureToSpriteList("image/insects.png", {64, 64})
	local tile = util.PutAnimTile(player.body, anim, pos, 1, 
				      eapi.ANIM_LOOP, 24, 0)
	eapi.SetAttributes(tile, { color = { r = 0.1, g = 0.1, b = 0.1 } })
end

local function FallDeath(player, killer)
	if PlayerLives(player, killer) then return end

	GenericDeath(player)

	local shape = defaultPlayerShape
	player.shape = eapi.NewShape(player.body, nil, shape, "Object")
	eapi.pointerMap[player.shape] = player
	object.CompleteHalt(player)
	object.SimpleStep(player)
	PlayerHit(player, killer, 200)
	
	local fallAnim = eapi.TextureToSpriteList("image/player-fall.png",
						  {128, 128})
	eapi.SetPos(player.tile, {-64, -28})
	eapi.SetSpriteList(player.tile, fallAnim)
	eapi.Animate(player.tile, eapi.ANIM_CLAMP, 32)

	local flyCount = 3
	local flyPos = { { x =  0,  y = -12 },
			 { x = -64, y = -6 },
			 { x = -32, y =  0 } }
	local function ShowFlies()
		Flies(flyPos[flyCount], player)
		flyCount = flyCount - 1;
		if flyCount > 0 then
			eapi.AddTimer(gameWorld, 1.5, ShowFlies)
		end
	end

	local function StartSpill()
		local spillAnim = eapi.TextureToSpriteList("image/spill.png",
							   {128, 32})
		local tile = eapi.NewTile(player.body, {-64, -28},
					  nil, spillAnim, -0.1)
		eapi.Animate(tile, eapi.ANIM_CLAMP, 32)				
		eapi.AddTimer(gameWorld, 2, ShowFlies)	
	end
	eapi.AddTimer(gameWorld, 0.5, StartSpill)	
end

local function PlayerVsSpikes(event, playerShape)
	local player = eapi.pointerMap[playerShape]
	ShatterDeath(player)
end

local function Player_vs_PondBottom(world, playerShape, groundShape, resolve)
	local player = eapi.pointerMap[playerShape]
	DrowningDeath(player)
end

local function AdjustVel(player, move, dir, More, Less) 
	if move then
		if not(player.control.shoot) then
			local inv = dir < 0
			player.direction = inv
			eapi.SetAttributes(player.tile, {flip = {inv, false}})
		end
		weapons.GunDirection(player)
		if player.contact.ground then
			-- Walking on ground.
			player.vel.x = player.vel.x + dir * 10
			if More(dir * player.maxWalkSpeed) then
				player.vel.x = dir * player.maxWalkSpeed
			end
		else
			-- Flying through air.
			player.vel.x = player.vel.x + dir * 5
			if More(dir * player.maxWalkSpeed) then
				player.vel.x = 1.2 * dir * player.maxWalkSpeed
			end
		end
	elseif More(0) and not move then
		if player.contact.ground then
			-- Ground friction.
			player.vel.x = player.vel.x - dir * 5
			if Less(0) then
				player.vel.x = 0
			end
		else
			-- Air resistance.
			player.vel.x = 0.99 * player.vel.x
			if Less(0) then
				player.vel.x = 0
			end
		end
	end
end

local function EnableJumpSound()
	mainPC.disableJumpSound = false
end

local function PlayerStep(world, body)
	local player = eapi.pointerMap[body]
	local pos = eapi.GetPos(body)
	
	local worldData = eapi.GetData(world)
	local now = worldData.now
	local stepSec = worldData.stepSec
	
	local moveLeft = false
	local moveRight = false

	if player.ducked or (player.control.left and player.control.right) then
		moveLeft, moveRight = false, false
	else
		moveLeft = player.control.left
		moveRight = player.control.right
	end
	
	local function LessThan(val)
		return (player.vel.x < val)
	end
	local function MoreThan(val)
		return (player.vel.x > val)
	end
	
	AdjustVel(player, moveRight, 1, MoreThan, LessThan)
	AdjustVel(player, moveLeft, -1, LessThan, MoreThan)
	
	-- Apply downward velocity in case we're moving down a slope.
	local slope = player.contact.leftSlope
	if slope and player.vel.x < 0 then
		-- We're moving left on a left-slope.
		local num = math.floor(player.vel.x * stepSec) * slope.h
		local den = (slope.w * stepSec)
		player.vel.y = num / den
	end
	slope = player.contact.rightSlope
	if slope and player.vel.x > 0 then
		-- We're moving right on a right-slope.
		local num = math.floor(player.vel.x * stepSec) * slope.h
		local den = (slope.w * stepSec)
		player.vel.y = -num / den
	end
	
	-- Jumping.
	if player.control.jump then
		if player.contact.onewayGround and player.control.down then
			player.downJump = true
			player.control.jump = false
		elseif player.contact.ground 
			and not player.ducked
			and not player.jumpInProgress then
			if player.contact.platform then
				local platform = player.contact.platform
				local vel = object.GetVel(platform)
				player.vel.x = player.vel.x + vel.x
			end
			player.vel.y = 200
			player.jumpBucket = 500
			player.jumpInProgress = true
			if not(player.disableJumpSound) then
				eapi.PlaySound(gameWorld, "sound/grunt.ogg")
				eapi.AddTimer(player.body, 0.2, EnableJumpSound)
				player.disableJumpSound = true
			end
		elseif player.jumpBucket > 0 then
			local amount = 4000 * eapi.GetData(world).stepSec
			player.jumpBucket = player.jumpBucket - amount
			player.vel.y = player.vel.y + amount
		else
			player.control.jump = false
		end
	end
	
	-- Apply gravity to velocity.
	player.vel = vector.Add(player.vel, vector.Scale(player.gravity, stepSec))
	
	-- Update player position.
	local newPos = vector.Add(pos, vector.Scale(player.vel, stepSec))
	eapi.SetPos(player.body, newPos)
	
	-- Save and reset contact state.
	player.prevContact = player.contact
	player.contact = {}
end

local function ChangePlayerJumpTile(player, offset, inJump)
	local sprite = nil
	local attribs = eapi.GetAttributes(player.tile)
	eapi.Destroy(player.tile)
	if not(inJump) and not(game.GetState().weaponInUse) then
		sprite = player.walkAnim
	elseif not(inJump) and game.GetState().weaponInUse then
		sprite = player.handlessAnim
	elseif not(game.GetState().weaponInUse) then
		sprite = player.jumpSprite
	else
		sprite = player.jump2Sprite
	end
	player.tile = eapi.NewTile(player.body, offset, nil, sprite, 0)
	eapi.SetAttributes(player.tile, attribs)
	player.jumpTile = inJump
end

local function PlayerAfterStep(world, body)
	local player = eapi.pointerMap[body]
	local bodyData = eapi.GetData(body)
	
	if not(player.prevContact.ground) and player.contact.ground then
		eapi.PlaySound(gameWorld, "sound/bump.ogg")
	end

	-- If we were in contact with a platform before, but not anymore, unlink
	-- player.
	if player.prevContact.platform and (not player.contact.platform) then
		eapi.Unlink(player.body)
	end
	
	-- Note: we compute the change in position ourselves because the
	-- .deltaPos value provided by engine is the actual change in (rounded)
	-- position. Even if position did not change due to rouning in previous
	-- step, player might still be moving and must be animated accordingly.
	local deltaPos = vector.Sub(bodyData.pos, bodyData.prevPos)
	
	-- Assume we're not moving if touching left or right wall.
	if (player.contact.left or player.contact.right) then
		deltaPos.x = 0
	end
	
	if player.contact.ground then
		if not(player.ducked) and player.jumpTile then
			ChangePlayerJumpTile(player, { -32, -28 }, false)
		end
		
		-- Walking animation.
		local move = player.control.right or player.control.left
		if deltaPos.x ~= 0 and move then
			local dir = -1
			if ((player.vel.x > 0 and not player.direction) or
		           ((player.vel.x < 0 and player.direction)))  then
				dir = 1
			end

			eapi.SetAnimPos(player.tile, player.animPos)
			if game.GetState().weaponInUse then
				eapi.SetAnimPos(player.gunTile, player.animPos)
				eapi.SetAnimPos(player.handTile, player.animPos)
			end

			local tmp = player.animSpeed * math.abs(deltaPos.x)
			player.animPos = player.animPos + dir * tmp
		else
			-- Pick the frame where player looks as if standing still.			
			if not(player.ducked) then
				eapi.SetFrame(player.tile, 8)
			end
			if game.GetState().weaponInUse then
				eapi.SetFrame(player.gunTile, 8)
				eapi.SetFrame(player.handTile, 8)
			end
		end
	else
		-- Jumping animation.
		if not(player.ducked) and not(player.jumpTile) then
			ChangePlayerJumpTile(player, { -64, -28 }, true)
		end
		if game.GetState().weaponInUse then
			eapi.SetFrame(player.gunTile, 10)
			eapi.SetFrame(player.handTile, 10)
		end
	end
	
	-- .downJump is used to signal one-way-ground collision handler that
	-- player must be allowed to fall through. Reset this value since
	-- collision handlers have been executed already.
	player.downJump = false
	
	if player.activator then
		if player.activator.active then
			player.activator.active = false
		else
			action.RemoveActivatorInfo(player.activator)
			player.activator = nil
		end
	end	
end

local Duck = nil

local weapon45Map = {
	["sterling"] = "image/45-sterling.png",
}

local weaponUpMap = {
	["sterling"] = "image/up-sterling.png",
}

local weaponDownMap = {
	["sterling"] = "image/sterling.png",
}

-- aimUp is GameState value to retain its value between level changes
local function WeaponUp(player)
	if player.ducked
	   or player.inputDisabled
	   or (player.activator and player.control.up) then return end

	local control = player.control
	player.aimUp = control.up or control.maybe45
	local aimSideways = control.right or control.left or control.maybe45
	player.aim45 = player.aimUp and aimSideways
	local weapon = weapons.GetType()

	if player.aim45 then
		destroyer.UseWeapon(player, weapon45Map[weapon])
	elseif player.aimUp then
		destroyer.UseWeapon(player, weaponUpMap[weapon])
	else
		destroyer.UseWeapon(player, weaponDownMap[weapon])
		if player.control.down then
			Duck(player, true)
		end
	end
end

local function DestroyHandTile(player)
	if player.handTile then
		eapi.Destroy(player.handTile)
		player.handTile = nil
	end
end

local function DuckHandTile(player)
	player.handTile = eapi.NewTile(player.body, nil, nil, 
				       player.handAnim, 0.02)

	if player.direction then
		eapi.SetPos(player.handTile, {-44, -58})
		eapi.SetAttributes(player.handTile, {flip={true, false}})
	else
		eapi.SetPos(player.handTile, {-20, -58})
		eapi.SetAttributes(player.handTile, {flip={false, false}})
	end

	if player.invincible then
		eapi.SetAttributes(player.handTile, transparent)
	end
end

local function CreatePlayerShape(player, shouldDestroy, shape)
	shape = shape or defaultPlayerShape
	if player.shape then
		eapi.pointerMap[player.shape] = nil
		if shouldDestroy then
			eapi.Destroy(player.shape)
		end
	end
	player.shape = eapi.NewShape(player.body, nil, shape, "Player")
	eapi.pointerMap[player.shape] = player
end

Duck = function(player, keyDown)
	if player.inputDisabled or player.aimUp then return end

	player.ducked = keyDown
	DestroyHandTile(player)
	if keyDown then
		DuckHandTile(player)
		weapons.GunDirection(player)
		eapi.SetSpriteList(player.tile, player.duckSprite)
		local duckShape = { l = -25, r = 25, b = -16, t = 32 }
		CreatePlayerShape(player, true, duckShape)
		eapi.SetPos(player.tile, {-64, -28})
	else
		player.handTile = nil
		CreatePlayerShape(player, true)
		destroyer.Restore(player)
		if player.control.up then
			WeaponUp(player)
		end
	end
end

--[[
	Make our destroyer player character appear engine-side:
		* load player Body, Shape, and Tile objects,
		* bind movement keys,
		* set step and after-step functions.
]]--

local ActivateLock = false

local function Load(world, player)
	weapons.Reset()
	player.activator = nil
	ActivateLock = false
	player.shootInProgress = false
	player.jumpInProgress = false	-- reset jumping state.
	player.maxWalkSpeed = 250
	player.jumpBucket = 0
	player.id = "player"
	player.handTile = nil
	player.gunTile = nil	
	player.dead = false
	player.invincible = false
	player.burning = false
	player.ducked = false

	-- Clear out stale body references, and create a new body.
	if player.body then
		eapi.pointerMap[player.body] = nil
	end
	player.body = eapi.NewBody(world, {0,0})
	eapi.pointerMap[player.body] = player

	-- Clear out stale shape references, and create a new shape.
	CreatePlayerShape(player)
	
	-- Velocity and gravity.
	player.vel = {x=0,y=0}
	player.gravity = {x=0,y=-1500}
	
	-- Animations.
	player.walkAnim
		= eapi.TextureToSpriteList("image/player.png", {64, 128})
	player.handAnim
		= eapi.TextureToSpriteList("image/player-hand.png", {64, 128})
	player.upHandAnim
		= eapi.TextureToSpriteList("image/up-hand.png", {64, 128})
	player.hand45Anim
		= eapi.TextureToSpriteList("image/45-hand.png", {64, 128})
	player.handlessAnim
		= eapi.TextureToSpriteList("image/player-wo-hand.png", {64, 128})

	player.duckSprite = eapi.NewSpriteList("image/player-duck.png", 
					       { { 0, 0 }, { 128, 128 } })
	player.jumpSprite = eapi.NewSpriteList("image/player-duck.png", 
					       { { 0, 128 }, { 128, 128 } })
	player.jump2Sprite = eapi.NewSpriteList("image/player-duck.png",
						{ { 0, 256 }, { 128, 128 } })

	local function MoveLeft(key, keyDown)
		player.control.left = keyDown
		if player.aimUp then 
			WeaponUp(player)
		end
	end
	local function MoveRight(key, keyDown)
		player.control.right = keyDown
		if player.aimUp then 
			WeaponUp(player)
		end
	end
	local function MoveUp(key, keyDown)
		player.control.up = keyDown
		WeaponUp(player)
	end
	local function MoveDown(key, keyDown)
		player.control.down = keyDown
		Duck(player, keyDown)
	end
	local function Jump(key, keyDown)
		player.control.jump = keyDown
	end
	local function Aim45(key, keyDown)
		player.control.maybe45 = keyDown
		WeaponUp(player)
	end
	local function Shoot(key, keyDown)
		player.control.shoot = keyDown
		weapons.MakeShoot(player)
	end
	player.Up = function()
		return player.control.up and not(player.aimUp)
	end

	player.EnableInput = function()
		player.inputDisabled = false
		eapi.SetStepFunc(player.body, PlayerStep, PlayerAfterStep)
	end

	player.DisableInput = function()
		player.inputDisabled = true
		eapi.SetStepFunc(player.body, nil, nil)
	end

	-- Bind keys.
	player.StartInput = function ()
		eapi.BindKey(eapi.KEY_SPACE, util.MakeMessageFinish())
		util.BindKeys(Cfg.keyLeft, MoveLeft)
		util.BindKeys(Cfg.keyRight, MoveRight)
		util.BindKeys(Cfg.keyUp, MoveUp)
		util.BindKeys(Cfg.keyDown, MoveDown)
		--eapi.BindKey(eapi.KEY_c, Aim45)
		util.BindKeys(Cfg.keyJump, util.MakeMessageFinish(Jump))
		util.BindKeys(Cfg.keyShoot, util.MakeMessageFinish(Shoot))	
	end

	player.StopInput = function ()
		player.control = {}
		local skipFn = util.MakeMessageFinish()
		eapi.BindKey(eapi.KEY_SPACE, skipFn)
		util.BindKeys(Cfg.keyLeft)
		util.BindKeys(Cfg.keyRight)
		util.BindKeys(Cfg.keyUp)
		util.BindKeys(Cfg.keyDown)
		--eapi.BindKey(eapi.KEY_c)
		util.BindKeys(Cfg.keyJump, skipFn)
		util.BindKeys(Cfg.keyShoot, skipFn)
	end

	-- Create main player tile and set its sprite list.
	if not(game.GetState().playerHidden) then
		player.tile = eapi.NewTile(player.body, {-32,-28}, nil, player.walkAnim, 0)
		
		destroyer.UseWeapon(player)
		player.StartInput()
		
		-- Set step functions.
		player.EnableInput()
	else
		-- Install dialog stop functions
		player.StopInput()
	end


	object.VerticalHalt(player)

	-- Register collision handlers.
	object.RegisterHandlers("Player", 70)

	if player.ducked then 
		Duck(player, true)
	end

	util.PreloadSound({ "sound/bone-crush.wav",
			    "sound/punch.ogg",
			    "sound/grunt.ogg",
			    "sound/bump.ogg",
			    "sound/fry.ogg" })
end

local function Create()
	local player = {}
	player.type = "Destroyer"
	player.contact = {}
	player.prevContact = {}
	player.control = {}

	-- Constants.
	player.animSpeed = 0.01
	player.animPos = 0.0

	return player
end

local function Place(player, position, flipH)
	if not(game.GetState().playerHidden) then
		eapi.SetPos(player.body, position)
		player.direction = flipH
		if flipH then
			eapi.SetAttributes(player.tile, {flip={true, false}})
		end
		weapons.GunDirection(player)
		progressBar.Lives(true)
	end
end

local function Restore(player)
	eapi.StopAnimation(player.tile)
	eapi.SetPos(player.tile, player.jumpTile and {-64,-28} or {-32,-28})
	local sprite = nil
	if not(game.GetState().weaponInUse) then
		sprite = player.jumpSprite
	else
		sprite = player.jump2Sprite
	end
	sprite = player.jumpTile and sprite or player.walkAnim
	eapi.SetSpriteList(player.tile, sprite)
	destroyer.UseWeapon(player)
	player.EnableInput()
end
	
function Activate(DoTheActualActivation, DoPostActivation)
	local function SecondAfterAnim()
		if mainPC.dead then return end

		Restore(mainPC)
		ActivateLock = false
		if DoPostActivation then
			DoPostActivation()
		end
	end
	local function Continue()
		eapi.Animate(mainPC.tile, eapi.ANIM_CLAMP, -24)
		eapi.AddTimer(mainPC.body, 0.333, SecondAfterAnim)
	end
	local function AfterAnim()
		if mainPC.dead then return end

		local shouldWait = false
		if DoTheActualActivation then
			shouldWait = DoTheActualActivation(Continue)
		end
		if not(shouldWait) then 
			Continue()
		end
	end
	if not(ActivateLock) and not(mainPC.ducked) then
		ActivateLock = true
		destroyer.Turn(mainPC)
		eapi.AddTimer(mainPC.body, 0.333, AfterAnim)
	end
end

local function ShowWeapon(player, weapon)
	local handAnim
	weapons.Enable()
	
	if player.aim45 then		
		handAnim = player.hand45Anim
	elseif player.aimUp then		
		handAnim = player.upHandAnim
	else
		handAnim = player.handAnim
	end

	-- Gun and its animation.
	player.gunAnim = eapi.TextureToSpriteList(weapon, {64, 64})
	player.gunTile = eapi.NewTile(player.body, {-16, -8},
				      nil, player.gunAnim, 0.01)

	-- Hand and its animation.
	player.handTile = eapi.NewTile(player.body, {-32, -28}, nil, 
				       handAnim, 0.02)
	
	-- Replace normal animatino with handless animation.
	local jumpSprite = player.jumpTile and player.jump2Sprite
	eapi.SetSpriteList(player.tile, jumpSprite or player.handlessAnim)
	weapons.GunDirection(player)
end

local function HideWeapon(player)
	weapons.Disable()
	if game.GetState().weaponInUse then
		DestroyHandTile(player)
		if player.gunTile then
			eapi.Destroy(player.gunTile)
			player.gunTile = nil
		end
	end
end

local function UseWeapon(player, weapon)
	weapon = weapon or game.GetState().weaponInUse
	game.GetState().weaponInUse = weapon
	HideWeapon(player)
	if weapon and not(game.GetState().playerHidden) then
		ShowWeapon(player, weapon)
		if player.invincible then
			SetColor(player, transparent)
		end
	end
end

local function Turn(player)
	HideWeapon(player)
	player.DisableInput()
	
	-- Adjust tile position (player-turn.png has different
	-- sprite size than the walking animation).
	eapi.SetPos(player.tile, {-48, -29})
	player.vel.x = 0
	player.vel.y = 0
	
	-- Assign turning animation to tile and let it animate.
	local turnAnim = eapi.TextureToSpriteList("image/player-turn.png", {96, 128})
	eapi.SetSpriteList(player.tile, turnAnim)
	eapi.Animate(player.tile, eapi.ANIM_CLAMP, 24)
end

local function HealthPlus(num)
	local hp = { }
	local zero = {x = 0, y = 0}
	local box = { l = 14, r = 18, b = 14, t = 18 }
	local shape = { l = 7, b = 3, r = 25, t = 27 }
	local function TakeHealthPlus()
		object.Delete(hp)
		game.GetState().healthPlus[num] = true
		game.GetState().lives = game.GetState().lives + 1
		game.GetState().maxLives = game.GetState().maxLives + 1
		eapi.PlaySound(gameWorld, "sound/clang.ogg")
		progressBar.Lives()
	end
	
	local function Act()
		destroyer.Activate(TakeHealthPlus)
		action.DeleteActivator(hp.act)
	end

	local img = game.ItemTile('a')

	local function ForEditor(pos)
		if game.GetState().healthPlus[num] then return end
		hp.body = eapi.NewBody(gameWorld, pos)
		hp.tile = eapi.NewTile(hp.body, zero, nil, img, -0.2)
		hp.act = action.MakeActivator(box, Act, txt.healthPlus, hp.body)
		hp.shapeObj = eapi.NewShape(hp.body, nil, shape, "Object")
		eapi.pointerMap[hp.shapeObj] = hp
		object.CompleteHalt(hp)
		hp.vel = { x = 0, y = 0 }
		hp.gravity = { x = 0, y = -1500 }
		object.SimpleStep(hp)
	end
	return ForEditor
end

destroyer = {
	HealthPlus = HealthPlus,
	FallDeath = FallDeath,
	ShatterDeath = ShatterDeath,
	BurningDeath = BurningDeath,
	HideWeapon = HideWeapon,
	UseWeapon = UseWeapon,
	Activate = Activate,
	Restore = Restore,
	Create = Create,
	Load = Load,
	Turn = Turn,
	Place = Place,
	WeaponUp = WeaponUp,
	
	Player_vs_PondBottom = Player_vs_PondBottom,
}
return destroyer
