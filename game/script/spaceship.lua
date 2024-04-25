
function Spaceship(x, y)
	util.CameraTracking.stop("spaceship", { x = x + 512, y = y + 512 })
	local staticBody = eapi.GetStaticBody(gameWorld)
	local ssSprite = eapi.NewSpriteList("image/ramp.png",
					    {{ 0, 0 }, { 256, 256 }})
	eapi.NewTile(staticBody, { x = x + 128, y = y - 16 },
		     { x = 256, y = 256 }, ssSprite, -7)

	ssSprite = eapi.NewSpriteList("image/spaceship.png",
				      {{ 0, 0}, { 1024, 1024 }})
	eapi.NewTile(staticBody, { x = x, y = y - 16 },
		     { x = 1024, y = 1024 }, ssSprite, 7)

	local y = y + 10;
	
	-- Hatch door slope.
	local function Hatch(bb, side)
		eapi.NewShape(staticBody, nil, bb, "LeftSlope")
		if side then
			bb.l = bb.r
			bb.r = side
			eapi.NewShape(staticBody, nil, bb, "Box")
		end
	end
	Hatch({l = x + 177, r = x + 213, b = y + 25, t = y + 40},  x + 329)
	Hatch({l = x + 213, r = x + 255, b = y + 40, t = y + 66},  x + 329)
	Hatch({l = x + 255, r = x + 289, b = y + 66, t = y + 97},  x + 329)
	Hatch({l = x + 289, r = x + 316, b = y + 97, t = y + 136}, x + 329)
	Hatch({l = x + 316, r = x + 329, b = y + 136, t = y + 150})
	
	-- Vertical door edge at the bottom.
	eapi.NewShape(staticBody, nil, {l=x+170,r=x+329,b=y-10,t=y+25}, "Box")
	
	-- Inside spaceship floor and ceiling.
	eapi.NewShape(staticBody, nil, {l=x+329,r=x+900,b=y+136,t=y+150}, "Box")
	eapi.NewShape(staticBody, nil, {l=x+231,r=x+900,b=y+291,t=y+295}, "Box")
	eapi.NewShape(staticBody, nil, {l=x+175,r=x+231,b=y+225,t=y+291}, "CeilingRightSlope")
	
	-- Outside ship shape.
	eapi.NewShape(staticBody, nil, {l=x+112,r=x+175,b=y+225,t=y+310}, "CeilingLeftSlope")

	ExitRoom({l=x+480,r=x+490,b=y+155,t=y+285}, "CargoHold", 
		 {-350, -162}, nil, nil, nil, eapi.SLIDE_RIGHT)
end
