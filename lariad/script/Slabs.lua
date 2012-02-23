dofile("script/shape.lua")
dofile("script/push-block.lua")

local slabs = util.TextureToTileset("image/slabs.png", 
				    { "12xx",
				      "34xx",
				      "xxxx",
				      "xxab" },
				    { 128, 64 })

local bigSlabs = util.TextureToTileset("image/slabs.png",
				       { "12", "34" },
				       { 256, 128 })

local decors = util.TextureToTileset("image/swamp.png", tileMap8x8, { 64, 64 })

local function MakeShape(param, fn)
	if param ~= 0 then
		if not(param) then param = attr end
		fn(param)
	end
end	

local function Box(x, y, w, h, s, attrib)
	shape.Line({x, y}, {x + w, y + h}, "Box")
end

local function Fix(x, y, d, attribute)
	util.PutTileWithAttribute(staticBody, 'a',
				  slabs, {x, y}, d, attribute)
	util.PutTileWithAttribute(staticBody, 'b',
				  slabs, {x + 128, y}, d, attribute)
end

local function Small(x, y, d, attribute, shapeAttribute)
	MakeShape(shapeAttribute,
		  function (shape) Box(x + 14, y + 2, 100, 60, 10, shape) end)
	util.PutTileWithAttribute(staticBody, 
				  RandomElement({'1','2','3','3','3','3','4'}),
				  slabs, {x = math.floor(x), y = math.floor(y)},
				  d, attribute)
end

local shadingOffset = 0.000001

local function WithShadingOffset(offset, fn)
	shadingOffset = offset
	fn()
	shadingOffset = 0.000001
end

local function Big(x, y, d, attribute, shapeAttribute, id, fX, fY, h)
	MakeShape(shapeAttribute,
		  function (shape) Box(x + 16, y + 6, 224, 116, 12, shape) end)
	util.PutTileWithAttribute(staticBody, 
				  RandomElement({'2','3','4','4'}),
				  bigSlabs, { x = x, y = y }, d, attribute)
	if id then
		if not(h) then h = 112 end
		Occlusion.put(id, x, y, d + shadingOffset, 
			      { size={ x = 256, y = h }, flip={fX, fY} })
	end
end

local flameAnim = eapi.TextureToSpriteList("image/flame.png", {64, 64})
local function Lamp(x, y, d)
	eapi.Animate(eapi.NewTile(staticBody, { x = x, y = y + 84}, nil, 
				  flameAnim, d - 0.001),
		     eapi.ANIM_LOOP, 
		     32)
	util.PutTile(staticBody, 'X', decors, { x = x, y = y + 64}, d)
	util.PutTile(staticBody, '6', decors, { x = x, y = y }, d)
end

local function Scaffold(pos, d, double)
	d = d or 1.0
	local x = math.floor(pos.x)
	local y = math.floor(pos.y)
	local function Element(x)
		d = d - y / 10000
		util.PutTile(staticBody, 'Y', decors, 
			     { x = x, y = y + 64}, d)
		util.PutTile(staticBody, '7', decors,
			     { x = x, y = y}, d)
		util.PutTile(staticBody, 'Z', decors,
			     { x = x + 64, y = y + 64}, d)
		util.PutTile(staticBody, '8', decors,
			     { x = x + 64, y = y}, d)
		shape.Line({x, y + 110}, {x + 128, y + 100}, "OneWayGround")
	end
	Element(x)
	if double then
		Element(x + 120)
	end
end

local function PatchOfGrass(pos, d, dark)
	util.PutTileWithAttribute(staticBody, 'Q', decors, pos, d or 1,
				  { color = util.Gray(dark or 1) })
end

local function PotLamp(x, y, d)
	eapi.Animate(eapi.NewTile(staticBody, { x = x - 16, y = y + 28 }, nil, 
				  flameAnim, d - 0.001),
		     eapi.ANIM_LOOP, 
		     32)
	util.PutTileWithAttribute(staticBody, 'M', decors, { x = x, y = y}, d,
				  { size = { x = 32, y = 32 } })
end

local dark = {color= {r = 0.5, g = 0.5, b = 0.5}}
local darker = {color= {r = 0.25, g = 0.25, b = 0.25}}

local function MakeDarkness(flipHorizontal, z)
	z = z or 0.5
	flipHorizontal = flipHorizontal or false
	return function(box)
		local w = box.r - box.l
		local h = box.t - box.b
		eapi.SetAttributes(eapi.NewTile(staticBody,
						{ x = box.l, y = box.b}, nil,
						Occlusion.entranceFalloff, z),
				   { flip={flipHorizontal, false},
				     size={ x=w, y=h }, color={ a = alpha }})
	end
end

local wallDustColor = { r = 0.31, g = 0.32, b = 0.42 }
local wallImg = eapi.NewSpriteList("image/pyramid.png", {{0, 0}, {128, 256}})
local wallBox = { b = 0, t = 256, l = 0, r = 128 }
local wallBottom = { b = 4, t = 5, l = 0, r = 128 }

local function WallSmoke(pos, wall, num, xoffset, xvel)
	wall.dust[num] = effects.Smoke(vector.Offset(pos, xoffset, 0),
				       { vel = { x = xvel, y = 50 },
					 disableProximitySensor = true,
					 color = wallDustColor,
					 interval = 0.1,
					 variation = 90,
					 life = 1.0,
					 dim = 0.5,
					 z = -1.9, })
	eapi.AddTimer(wall.body, 0.5, wall.dust[num].Stop)
	wall.dust[num].Kick()
end

local function FallWall(pos)
	local wall = { dust = { } }
	wall.body = eapi.NewBody(gameWorld, pos)
	wall.tile = eapi.NewTile(wall.body, nil, nil, wallImg, -4.5)
	wall.shape = eapi.NewShape(wall.body, nil, wallBottom, "Object")
	eapi.pointerMap[wall.shape] = wall
	wall.gravity = { x = 0, y = -1500 }
	eapi.SetGravity(wall.body, wall.gravity)
	eapi.SetVel(wall.body, { x = 0, y = -250 })
	wall.Ground = function()
		eapi.NewShape(wall.body, nil, wallBox, "Box")
		eapi.SetGravity(wall.body, { x = 0, y = 0 })
		eapi.pointerMap[wall.shape] = nil
		eapi.Destroy(wall.shape)			       
		local bodyPos = eapi.GetPos(wall.body)
		WallSmoke(bodyPos, wall, 1, 112, 50)
		WallSmoke(bodyPos, wall, 2, 16, -50)
		eapi.PlaySound(gameWorld, "sound/stone.ogg")
	end
	object.CompleteHalt(wall)
	return wall
end

local function CrumbleWall(wall)
	effects.Shatter({ image = "image/pyramid.png",
			  spriteOffset = { x = 128, y = 0 }},
			wall, action.BlowUp(), 3, nil,
			nil, action.RockCrumble, 8)
	eapi.PlaySound(gameWorld, "sound/brick.ogg")	
	eapi.Destroy(wall.body)
	wall.body = nil
end

local cubeImg = eapi.NewSpriteList("image/pyramid.png", {{320, 0}, {64, 64}})

local function StoneCube(pos)
	pos.restingSprite = cubeImg
	pushBlock.Put(pos)
end

local fileName = { "image/pyramid.png", filter = true }
local web1Img = eapi.NewSpriteList(fileName, {{384, 0}, {64, 192}})
local web2Img = eapi.NewSpriteList(fileName, {{320, 192}, {128, 64}})
local function Web(bb, z, img, alpha, flip)
	local pos = { x = bb.l, y = bb.b }
	local size = { x = bb.r - bb.l, y = bb.t - bb.b }
	local tile = eapi.NewTile(staticBody, pos, size, img, z or 1)
	eapi.SetAttributes(tile, { flip = { flip or false, false },
				   color = { r = 1, b = 1, g = 1,
					     a = alpha or 1 } })
end

local function Web1(bb, z)
	Web(bb, z, web1Img, 0.15, false)
end

local function Web2(bb, z)
	Web(bb, z, web1Img, 0.15, true)
end

local function Web3(bb, z)
	Web(bb, z, web2Img, 0.15, false)
end

slab = {
	Web1 = Web1,
	Web2 = Web2,
	Web3 = Web3,
	CrumbleWall = CrumbleWall,
	FallWall = FallWall,
	dark = dark,
	MakeDarkness = MakeDarkness,
	darker = darker,
	Small = Small,
	Lamp = Lamp,
	PotLamp = PotLamp,
	PatchOfGrass = PatchOfGrass,
	WithShadingOffset = WithShadingOffset,
	Scaffold = Scaffold,
	StoneCube = StoneCube,
	Fix = Fix,
	Big = Big,
}
return slab
