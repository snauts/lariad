dofile("script/Proximity.lua")

local beamSize = {{64, 192}, {64, 256}}
local beam = eapi.NewSpriteList("image/forest.png", beamSize)

local function Entrance(x, y, rev)
	rev = rev or false
	local xx = (rev and x+32) or x-16
	local tile = eapi.NewTile(staticBody, {xx, y-48}, {64,256}, beam, 9)
	eapi.SetAttributes(tile, {size={64, 320}, flip={not(rev), false}})

	local xx = (rev and x-16) or x+32
	local tile = eapi.NewTile(staticBody, {xx, y-10}, {64,256}, beam, -9)
	eapi.SetAttributes(tile, {size={64, 256}, flip={not(rev), false}})
	
	local xx = (rev and x-38) or x+90
	Occlusion.put('b', xx, y+6, -8.0, {size={28, 256}, flip={rev,false}})
	local xx = (rev and x-10) or x+80
	Occlusion.put('a', xx, y+6, -8.0, {size={10, 256}, flip={rev,false}})
	
	-- put it four times to make it more intense
	local xx = (rev and x+48) or x
	for i=0, 3, 1 do
		Occlusion.put('b', xx, y-25, 10.0, 
			      { size={28, 256},
				flip={rev,false}})
	end

	local attr = { size={82,16}, flip={rev,true}, color={a=0.2} }
	Occlusion.put('c', x, y+6, -8.0, attr)
end

local tunnelSize = {{128, 64}, {128, 256}}
local tunnelImg = eapi.NewSpriteList("image/forest.png", tunnelSize)

local function VerticalGradient(x, y, w, h, flip)
	eapi.SetAttributes(eapi.NewTile(staticBody, {x, y}, nil, 
					Occlusion.gradient, 10),
			   {size={w, h}, flip={false, flip or false}})
end

local function HorizontalGradient(x, y, w, h, flip, alpha)
	eapi.SetAttributes(eapi.NewTile(staticBody, {x, y}, nil,
					Occlusion.entranceFalloff, 10),
			   {size={ w, h }, flip={ flip or false, false },
			    color={ a = alpha }})
end

local function Tunnel(x, y, len)
	for i = 0, len-1, 1 do
		local ix = x + i * 128
		local iy = y - 24
		Occlusion.put('c', ix, iy, 10.0,
			      { size={128, 32}, flip={false, true} })
		eapi.NewTile(staticBody, {ix, iy}, 
			     {128, 256}, tunnelImg, -10)
	end
	Occlusion.put('f', x, y + 232, 10.0, { size={len*128, 128} })
	Occlusion.put('f', x, y - 152, 10.0, { size={len*128, 128} })	
	eapi.NewShape(staticBody, nil, { b=y-50, t=y, l=x, r=x+len*128 }, "Box")
	local box = { b=y+256, t=y+306, l=x, r=x+len*128 }
	eapi.NewShape(staticBody, nil, box, "Box")

	-- occlude ceiling
	VerticalGradient(x, y + 8, len*128, 224)
end

local fade = eapi.TextureToSpriteList("image/flower-fade.png", {128, 128})
local flower1 = eapi.TextureToSpriteList("image/flower1.png", {64, 64})
local flower2 = eapi.TextureToSpriteList("image/flower2.png", {64, 64})

local flowerSpeed = 64

local function FadeInFlower(flower)
	if flower.state == "on" then return nil end	
	eapi.Animate(flower.tile, eapi.ANIM_CLAMP, flowerSpeed, 0)
	eapi.Animate(flower.fade, eapi.ANIM_CLAMP, flowerSpeed, 0)
	flower.state = "on"
end

local function FadeOutFlower(flower)
	if flower.state == "off" then return nil end
	eapi.Animate(flower.tile, eapi.ANIM_CLAMP, -flowerSpeed, 0)
	eapi.Animate(flower.fade, eapi.ANIM_CLAMP, -flowerSpeed, 0)
	flower.state = "off"
end

local function PutFlower(x, y, type, depth)
	type = type or flower1
	depth = depth or -5.0	
	local flower = { pos = {x = x, y = y}, state = "off" }
	flower.tile = util.PutAnimTile(staticBody, type, 
				       {x - 32, y - 32}, depth, 
				       eapi.ANIM_CLAMP, flowerSpeed)

	eapi.StopAnimation(flower.tile)
	eapi.SetFrame(flower.tile, 0)
	
	local w = 256
	local h = 768
	flower.fade = util.PutAnimTile(staticBody, fade, 
				       {x - w / 2, y - h / 2}, 9.0,
				       eapi.ANIM_CLAMP, flowerSpeed)

	
	eapi.SetAttributes(flower.fade, { color = {a=0.15}, size = {w,h} })
	eapi.StopAnimation(flower.fade)
	eapi.SetFrame(flower.fade, 0)

	local d = 80

	proximity.Create(FadeInFlower, FadeOutFlower, flower,
			 { l = x - d, r = x + d, b = y - 2 * d, t = y + d })

end

local mulGlow = { r=0.4, g=0.7, b=1.0, a=1.0 }

local function BlueTunnel(x, y, len)	
	Tunnel(x, y, len)
	Occlusion.put('h', x, y-24, 9, 
		      { size={len*128, 256}, 
			color=mulGlow, multiply=true })
end

local function FlowerTunnel(x, y, len)	
	BlueTunnel(x, y, len)

	local xoff = 64
	local yoff = -8
	while xoff < (len - 0.5) * 128 do		
		if yoff >= 32 then
			PutFlower(x + xoff, y + yoff - 8)
		elseif yoff >= 12  then
			PutFlower(x + xoff, y + yoff - 8, flower2)
		else
			PutFlower(x + xoff, y + yoff - 8, flower2, 5)
		end
		xoff = xoff + util.Random(16, 32)
		yoff = (yoff + util.Random(32, 64)) % 120
	end
end

local crystal = util.TextureToTileset("image/forest.png", util.map8x8, {64,64})
local dust = eapi.TextureToSpriteList("image/animated-dust.png", {128, 128})

local lastCrystalTile
local function PickCrystal()
       local id = RandomElement({'Z','1','8'})
       if id == lastCrystalTile then
	       return PickCrystal()
       else
	       lastCrystalTile = id
	       return crystal[id]
       end       
end

local function PutCrystal(x, y, d, flipY)
	local tile = eapi.NewTile(staticBody, { x, y }, nil, PickCrystal(), d)
	eapi.SetAttributes(tile, { flip = { false, flipY or false } })

	local dTile = util.PutAnimTile(staticBody, dust, 
				       {x - 32, y - 32}, d,
				       eapi.ANIM_LOOP, 0)
		
	eapi.SetAttributes(dTile, { color = { r=1.0, g=1.0, b=1.0, a=0.7 }})
	eapi.Animate(dTile, eapi.ANIM_LOOP, util.Random(32, 48), util.Random())
end

local logSize = {{128, 320}, {128, 64}}
local log = eapi.NewSpriteList("image/forest.png", logSize)

local function RowOfSteppingLogs(x, y, h, flip)
	local hh = 0
	flip = flip or false	
	while hh < h - 32 do
		local yy = y + hh
		local xx = x - util.Random(0, 32);
		local tile = eapi.NewTile(staticBody, { xx, yy }, 
					  nil, log, -2)
 		eapi.SetAttributes(tile, {color={r=0.5,g=0.5,b=0.5},
					  flip={flip, false}})
		shape.Line({xx+32, yy+32},{xx+96, yy+56}, "OneWayGround")
		hh = hh + 96
	end
end

local shaftSize = {{256, 128}, {256, 128}}
local shaft = eapi.NewSpriteList("image/forest.png", shaftSize)
 
local planksSize = {{0, 0}, {256, 64}}
local planks = eapi.NewSpriteList("image/mines-more.png", planksSize)

local function Shaft(x, y, h)
	assert(h >= 6, "shaft is too short")
	local bottom = y + 232 - h * 128
	for i = 0, h-1, 1 do
		local offset = bottom + i * 128
		eapi.NewTile(staticBody, {x, offset}, nil, shaft, -10)
	end

	Occlusion.put('b', x, bottom+256, 10, { size={64, (h-5)*128} })
	Occlusion.put('a', x + 192, bottom+256, 10, { size={64, (h-5)*128} })

	Occlusion.put('b', x, bottom+(h-1)*128, 10, { size={64, 128} })
	Occlusion.put('a', x + 192, bottom+(h-1)*128, 10, { size={64, 128} })
	
	local box = { b=bottom-50, t=bottom + 24, l=x, r=x+256 }
	eapi.NewShape(staticBody, nil, box, "Box")
	box = { b=y+182, t=y+232, l=x, r=x+256 }
	eapi.NewShape(staticBody, nil, box, "Box")
	
	Occlusion.put('h', x, bottom, 9,
		      { size={256, h*128}, color=Mine.mulGlow, multiply=true })
	Occlusion.put('f', x, bottom-64, 10.0, { size={256, 64} })
	Occlusion.put('f', x, y + 232, 10.0, { size={256, 64} })

	local i = -32
	while i < 288 do
		local top = bottom + (h-1)*128 + util.Random(0,16)
		Occlusion.RandomStalagmite(x+i, top, 10, util.ToBeOrNotToBe())
		i = i + util.Random(16, 32)
	end
	local i = 0
	while i < 256 do
		local top = bottom + (h-1)*128 + util.Random(8,24)
		PutCrystal(x+i, top, -2, true)
		i = i + util.Random(16, 32)
	end


 	Occlusion.put('c', x, bottom, 10, 
		      { size={256, 16}, flip = { false, true } })

	eapi.NewTile(staticBody, { x, bottom - 20 }, nil, planks, -8)

	return bottom
end

local internode1Size = {{384, 256}, {128, 256}}
local internode1 = eapi.NewSpriteList("image/forest.png", internode1Size)

local internode2Size = {{256, 256}, {128, 256}}
local internode2 = eapi.NewSpriteList("image/forest.png", internode2Size)

local function BottomLeftExit(x, y, bottom)
	eapi.NewTile(staticBody, {x + 192, bottom}, nil, internode2, -9)
	Occlusion.put('a', x + 192, bottom + 248, 10, { size={64, 8} }) 
 	Occlusion.put('v', x + 192, bottom + 24, 10,
		      { size={ 64, 224 }, flip={ true, false } })
end

local function BottomRightExit(x, y, bottom)
	eapi.NewTile(staticBody, {x - 64, bottom}, nil, internode1, -9)
	Occlusion.put('b', x, bottom + 248, 10, { size={64, 8} }) 
 	Occlusion.put('v', x, bottom + 24, 10, { size={64, 224} })
end

local function ShaftWall(x, y, h)
	Occlusion.put('f', x, y, 10.0, { size = { 128, h * 128 } })
	local wall = { l = x, r = x + 128, b = y, t = y + h * 128 }
	eapi.NewShape(staticBody, nil, wall, "Box")
end

local function UpperEntrance(x, y, xoffset, img, flip)
	Occlusion.put('v', x, y - 152, 10,
		      { size={ 64, 32 }, flip={ flip, true }})
	Occlusion.put('v', x, y - 120, 10,
		      { size={ 64, 224 }, flip={ flip, false }})
	eapi.NewTile(staticBody, {x + xoffset, y - 152}, nil, img, -9)
end

local function OccludeWall(c, x, y) 
	Occlusion.put(c, x, y, 10, { size = { 64, 256 } })
end

local function LeftShaft(x, y, h)
	local bottom = Shaft(x, y, h)
	OccludeWall('a', x + 192, bottom + (h - 3) * 128)
	OccludeWall('b', x, bottom)

	ShaftWall(x + 256, bottom + 256, h - 2)
	ShaftWall(x - 128, bottom,       h - 3)

	UpperEntrance(x, y, -64, internode1, false)
	BottomLeftExit(x, y, bottom)
	RowOfSteppingLogs(x - 32, bottom + 32, (h - 3) * 128)
end

local function RightShaft(x, y, h)
	local bottom = Shaft(x, y, h)
	OccludeWall('b', x, bottom + (h - 3) * 128)
	OccludeWall('a', x + 192, bottom)

	ShaftWall(x + 256, bottom,       h - 3)
	ShaftWall(x - 128,  bottom + 256, h - 2)

	UpperEntrance(x + 192, y, 0, internode2, true)
	BottomRightExit(x, y, bottom)	
	RowOfSteppingLogs(x + 200, bottom + 32, (h - 3) * 128 - 32, true)
end

local function LeftShaftInv(x, y, h)
	local bottom = Shaft(x, y, h)
	OccludeWall('a', x + 192, bottom + (h - 3) * 128)
	OccludeWall('a', x + 192, bottom)

	ShaftWall(x + 256, bottom, h)
	ShaftWall(x - 128,  bottom + 256, h - 5)

	UpperEntrance(x, y, -64, internode1, false)
	BottomRightExit(x, y, bottom)
	RowOfSteppingLogs(x + 200, bottom + 32, (h - 2) * 128 - 32, true)
end

local function RightShaftInv(x, y, h)
	local bottom = Shaft(x, y, h)
	OccludeWall('b', x, bottom + (h - 3) * 128)
	OccludeWall('b', x, bottom)

	ShaftWall(x + 256, bottom + 256, h - 5)
	ShaftWall(x - 128,  bottom, h)

	UpperEntrance(x + 192, y, 0, internode2, true)
	BottomLeftExit(x, y, bottom)	
	RowOfSteppingLogs(x - 32, bottom + 32, (h - 2) * 128)
end

local function RightChute(x, y, h)
	local bottom = Shaft(x, y, h)
	OccludeWall('b', x, bottom + (h - 3) * 128)

	ShaftWall(x + 256, bottom + 256, h - 5)
	ShaftWall(x - 128,  bottom + 256, h - 2)

	UpperEntrance(x + 192, y, 0, internode2, true)
	BottomRightExit(x, y, bottom)
	BottomLeftExit(x, y, bottom)
end

local function CrystalTunnel(x, y, len)	
	BlueTunnel(x, y, len)

	local xoff = 64
	local yoff = 0
	while xoff < (len - 1) * 128 do		
		if yoff >= 10  then
			PutCrystal(x + xoff, y + yoff - 16, -5 - yoff * 0.01) 
		else
			PutCrystal(x + xoff, y + yoff - 32, 5 - yoff * 0.01)
		end
		xoff = xoff + util.Random(24, 64)
		yoff = (yoff + util.Random(0, 13)) % 20
	end
end

local wallEndSize = {{0, 0}, {128, 256}}
local wallEnd = eapi.NewSpriteList("image/mines.png", wallEndSize)
local columns = eapi.NewSpriteList("image/mines.png", {{128, 0}, {384, 360}})
local glowWorm = eapi.NewSpriteList("image/mines.png", {{0, 360}, {512, 152}})

local function Parallax(x, y, offset, scroll, depth, img, yoffset, color)
	depth = depth or -11
	img = img or columns
	yoffset = yoffset or -128
	local px = eapi.NewParallax(gameWorld, img, nil, 
				    { x + offset, y + yoffset },
				    { scroll, 1 }, depth)
	eapi.SetRepeatPattern(px, { false, false })
	if color then
		eapi.SetAttributes(px, { color = color })
	end
end

local function CavernEntrance(x, y, ww, flip, img)
	img = img or wallEnd
	local side = (flip and 1) or -1
	eapi.NewTile(staticBody, {x, y - 24}, nil, img, -8)
	Mine.VerticalGradient(x, y + 8, 128, 224)
	local tile = eapi.NewTile(staticBody, {x + side * 128, y + 8},
				  nil, Occlusion.cornerFalloff, 10)
	local attr = { size={ 128, 224 }, flip = { not(flip), false } }
	eapi.SetAttributes(tile, attr)
	Occlusion.put('w', x, y - 280, 9,
		      { size = { 128, 544 },
			flip = { flip, false },
			multiply = true })
end

Mine = {
	beam = beam,
	Tunnel = Tunnel,
	VerticalGradient = VerticalGradient,
	HorizontalGradient = HorizontalGradient,
	FlowerTunnel = FlowerTunnel,
	Entrance = Entrance,
	mulGlow = mulGlow,
	LeftShaft = LeftShaft,
	RightShaft = RightShaft,
	LeftShaftInv = LeftShaftInv,
	RightShaftInv = RightShaftInv,
	RightChute = RightChute,
	PutCrystal = PutCrystal,
	CrystalTunnel = CrystalTunnel,
	BlueTunnel = BlueTunnel,
	FlowerTunnel = FlowerTunnel,
	CrystalTunnel = CrystalTunnel,
	CavernEntrance = CavernEntrance,
	Parallax = Parallax,
	glowWorm = glowWorm,
}
return Mine
