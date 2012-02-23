dofile("script/object.lua")

local activeProjectiles = { }

local function fixLeftDuck(player, originalOffset)
	local offset = (player.ducked and { x=-12, y=-29 }) or { x=0, y=0 }
	return vector.Add(offset, originalOffset)
end

local function fixRightDuck(player, originalOffset)
	local offset = (player.ducked and { x=12, y=-29 }) or { x=0, y=0 }
	return vector.Add(offset, originalOffset)
end

local function GetBulletOrigin(player)
	local pos = eapi.GetPos(player.body)
	if player.direction then
		return fixLeftDuck(player, { x = pos.x - 34, y = pos.y + 22 })
	else
		return fixRightDuck(player,{ x = pos.x + 30, y = pos.y + 22 })
	end
end

local function GetUpBulletOrigin(player)
	local pos = eapi.GetPos(player.body)
	if player.direction then
		return { pos.x + 6, pos.y + 72 }
	else
		return { pos.x - 10, pos.y + 72 }
	end
end

local function Get45BulletOrigin(player)
	local pos = eapi.GetPos(player.body)
	if player.direction then
		return { pos.x - 23, pos.y + 60 }
	else
		return { pos.x + 19, pos.y + 60 }
	end
end

local function DeleteProjectile(projectile)
	projectile.sparks.Stop()
	eapi.pointerMap[projectile.shape] = nil
	activeProjectiles[projectile.shape] = nil
	if projectile.body then
		eapi.Destroy(projectile.body)
		projectile.body = nil
	end
end

local bulletImg = nil

local function Init()
	object.RegisterHandlers("Projectile")
	bulletImg = eapi.TextureToSpriteList("image/bullet.png", {7, 7})
end

local function SterlingChangeVel(bullet)
	if bullet.contact.left or bullet.contact.right then
		bullet.velocity.x = -bullet.velocity.x		
	elseif bullet.contact.ground or bullet.contact.ceiling then
		bullet.velocity.y = -bullet.velocity.y
	end
	eapi.SetVel(bullet.body, bullet.velocity)
	bullet.contact = { }
end

local function Follow(body)
	return function()
		return eapi.GetPos(body)
	end
end

local function SterlingCommon(bullet)
	bullet.tile = eapi.NewTile(bullet.body, {-3, -3}, nil, bulletImg, -0.01)
	eapi.Animate(bullet.tile, eapi.ANIM_LOOP, 40)
	bullet.lastHitTime = -1
	bullet.damage = 1
	bullet.Collide = function()
		local now = eapi.GetTime(bullet.body)
		if now - bullet.lastHitTime < 0.01 then
			DeleteProjectile(bullet)
			return
		end
		bullet.lastHitTime = now
		eapi.PlaySound(gameWorld, "sound/ricochet.ogg")
		action.PutHitSpark(weapons.GetPos(bullet), -0.01)
		SterlingChangeVel(bullet)
		bullet.hit = false
	end

	bullet.sparks = effects.Sparks(Follow(bullet.body))

	local shape = { l = -3, r = 3, b = -3, t = 3 }
	bullet.shape = eapi.NewShape(bullet.body, nil, shape, "Projectile")
	activeProjectiles[bullet.shape] = bullet
	eapi.pointerMap[bullet.shape] = bullet

	object.DoNotHalt(bullet)
	eapi.PlaySound(gameWorld, "sound/sterling.wav")
	local DeleteBullet = function() DeleteProjectile(bullet) end
	eapi.AddTimer(bullet.body, .7, DeleteBullet)
	eapi.SetVel(bullet.body, bullet.velocity)
	return 0.2
end

local bulletSpeed = 800.0
local bulletError = 70.0

local function BulletError()
	return bulletError * (util.Random() - 0.5)
end

local cos45 = (math.sqrt(2) / 2)
local speed45 = bulletSpeed - 0.5 * bulletError

local function GetSpeed45()
	return cos45 * (speed45 + BulletError())
end

local function SterlingBullet(player)
	local dir = (player.direction and -1) or 1
	local bullet = { 
		body      = eapi.NewBody(gameWorld, GetBulletOrigin(player)),
		velocity  = { x = dir * bulletSpeed, y = BulletError() },
	}
	return SterlingCommon(bullet)
end

local function SterlingUpBullet(player)
	local bullet = { 
		body      = eapi.NewBody(gameWorld, GetUpBulletOrigin(player)),
		velocity  = { x = BulletError(), y = bulletSpeed },
	}
	return SterlingCommon(bullet)
end

local function Sterling45Bullet(player)
	local dir = (player.direction and -1) or 1
	local bullet = { 
		body      = eapi.NewBody(gameWorld, Get45BulletOrigin(player)),
		velocity  = { x = dir * GetSpeed45(), y = GetSpeed45() },
	}
	return SterlingCommon(bullet)
end

local shootMap = { ["image/sterling.png"] = SterlingBullet,
		   ["image/45-sterling.png"] = Sterling45Bullet,
		   ["image/up-sterling.png"] = SterlingUpBullet, }

local weaponHidden = true
local function MakeShoot(player)
	local function FinishShoot()
		player.shootInProgress = false
		MakeShoot(player)
	end
	if not(weaponHidden)
	   and player.control.shoot
	   and game.GetState().weaponInUse
	   and not(player.shootInProgress) then
		player.shootInProgress = true
		local interval = shootMap[game.GetState().weaponInUse](player)
		eapi.AddTimer(player.body, interval, FinishShoot)
	end      
end

local function Reset()
	activeProjectiles = { }
end

local function GetProjectile(shape)
	return activeProjectiles[shape]
end

local function GetPos(projectile)
	return vector.Add(eapi.GetPos(projectile.body), { x = 2, y = 2 })
end

local function Enable()
	weaponHidden = false
end

local function Disable()
	weaponHidden = true
end

local leftMap = { ["image/sterling.png"] = { x = -48, y = -8 },
		  ["image/45-sterling.png"] = { x = -44, y = 18 },
		  ["image/up-sterling.png"] = { x = -34, y = 32 }, }

local rightMap = { ["image/sterling.png"] = { x = -16, y = -8},
		   ["image/45-sterling.png"] = { x = -20, y = 18 }, 
		   ["image/up-sterling.png"] = { x = -30, y = 32 }, }

local function GetGunOffset(player, flipH)
	local weapon = game.GetState().weaponInUse
	if flipH then
		return fixLeftDuck(player, leftMap[weapon])
	else
		return fixRightDuck(player, rightMap[weapon])
	end
end

local function GunDirection(player)
	if game.GetState().weaponInUse then
		local flipH = player.direction or false
		local attr = {flip = {flipH, false}}
		eapi.SetAttributes(player.gunTile, attr)
		eapi.SetAttributes(player.handTile, attr)
		eapi.SetPos(player.gunTile, GetGunOffset(player, flipH))
	end
end

local weaponTypes = {
	["image/45-sterling.png"] = "sterling",		
	["image/up-sterling.png"] = "sterling",
	["image/sterling.png"]    = "sterling",
}

local function GetType()
	return weaponTypes[game.GetState().weaponInUse]
end

weapons = {
	Init = Init,
	Reset = Reset,
	Enable = Enable,
	Disable = Disable,
	MakeShoot = MakeShoot,
	GunDirection = GunDirection,
	GetProjectile = GetProjectile,
	DeleteProjectile = DeleteProjectile,
	GetType = GetType,
	GetPos = GetPos,
}
return weapons
