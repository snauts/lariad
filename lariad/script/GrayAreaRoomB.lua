dofile("script/GrayArea.lua")
dofile("script/shape.lua")

local tx = eapi.NewSpriteList("image/inside.png", {{0, 0}, {800, 480}})
eapi.NewTile(staticBody, { -400, -240 }, nil, tx, -1.9)

shape.Line({-400, -200}, {400, -180}, "Box")
shape.Line({-400, -58}, {-350, 200}, "Box")
shape.Line({-350, 200}, {350, 250}, "Box")
shape.Line({350, -58}, {400, 200}, "Box")

eapi.NewShape(staticBody, nil, {l=-350,r=-116,b=-58,t=-4}, "Box")
eapi.NewShape(staticBody, nil, {l=116 ,r= 350,b=-58,t=-4}, "Box")

eapi.NewShape(staticBody, nil, {l=-116,r=-84,b=-28,t=-4}, "Box")
eapi.NewShape(staticBody, nil, {l= 84,r= 116,b=-28,t=-4}, "Box")

eapi.NewShape(staticBody, nil, {l=-116,r=-84,b=-58,t=-28}, "CeilingRightSlope")
eapi.NewShape(staticBody, nil, {l= 84,r= 116,b=-58,t=-28}, "CeilingLeftSlope")

local platformSize = {{0, 192}, {128, 64}}
local platformTexture = eapi.NewSpriteList("image/tiles.png", platformSize)

function SpaceShipPlatform(platform)
	local body = platform.body
	eapi.NewTile(body, { 0, 0 }, nil, platformTexture, -0.5)
	
	platform.shape = shape.Line({0, 20}, {128, 44}, "Platform", nil, body)
	return {l = -Infinity, r = Infinity, b = -196, t = -48}
end

util.CreateSimplePlatform({x=-64,y=-195}, {x=0,y=60}, SpaceShipPlatform)


grayArea.ts = util.TextureToTileset("image/computer-screens.png",
				    { "1234",
				      "5678",
				      "abcd",
				      "efgh",
				      "ijkl",
				      "ABCD",
				      "EFGH",
				      "IJKL" }, 
				    { 192, 80 })

return grayArea
