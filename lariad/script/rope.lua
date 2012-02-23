local function MakeRope(corner, flip)
	flip = flip or false
	local frame = { corner, { 64, 64 } }
	local ropeImg = eapi.NewSpriteList("image/bamboo.png", frame)

	return function(pos, z, body)
		z = z or 0.6
		body = body or staticBody
		local tile = eapi.NewTile(body, pos, nil, ropeImg, z)
		eapi.SetAttributes(tile, { flip = { flip, false } })
		return tile
	end
end

local Vertical = MakeRope({192, 64})
local Horizontal = MakeRope({0, 64})
local SteepRight = MakeRope({128, 64})
local SteepLeft = MakeRope({128, 64}, true)

local verticalImage = {
	image		= "image/bamboo.png",
	spriteOffset	= { x = 192, y = 64 },
}

local ropeShatter = { "P", "P", "P", "P" }

local function Hang(bb, holderBottom, ropeBottom)
	local hang = { }
	hang.shouldSpark = true
	local height = bb.t - bb.b
	ropeBottom = ropeBottom or 1
	hang.gravity = { x = 0, y = -1500 }
	local diff = math.floor(0.5 * (bb.r - bb.l))
	hang.shape = { l = -4, r = 4, b = ropeBottom, t = height }
	hang.body = eapi.NewBody(gameWorld, { x = bb.l + diff, y = bb.b })

	local function Holder(shape)
		eapi.NewShape(hang.body, nil, shape, "Box")
	end
	holderBottom = holderBottom or 0
	Holder({ b = 0, t = 2 + holderBottom, l = -diff,     r =  diff     })
	Holder({ b = 0, t = ropeBottom, l = -diff,     r = -diff + 2 })
	Holder({ b = 0, t = ropeBottom, l =  diff - 2, r =  diff     })

	local function Pos(i)
		return { x = -32, y = i }
	end

	local tiles = { }
	for i = 0, height, 48 do
		tiles[i] = Vertical(Pos(i), 0.4, hang.body)
	end

	hang.Shoot = function(projectile)
		for i = 0, height, 48 do
			hang.tile = tiles[i]
			effects.Shatter(verticalImage, hang,
					action.BlowUp(300),
					0.5, ropeShatter)
		end
		weapons.DeleteProjectile(projectile)
		eapi.Destroy(hang.body)
	end
		
	action.MakeActorShape(hang)
	object.DoNotHalt(hang)
end

rope = {
	Vertical = Vertical,
	Horizontal = Horizontal,
	SteepRight = SteepRight,
	SteepLeft = SteepLeft,
	Hang = Hang,
}
return rope
