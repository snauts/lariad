dofile("script/GrayArea.lua")
dofile("script/shape.lua")

local tx = eapi.NewSpriteList("image/interior.png", {{0, 0}, {800, 480}})
eapi.NewTile(staticBody, { -400, -240 }, nil, tx, -1.9)

shape.Line({-400, -200}, {400, -180}, "Box")

shape.Line({-350, 200}, {350, 250}, "Box")

shape.Line({-380, -38}, {-350, 200}, "Box")
shape.Line({380, -38}, {350, 200}, "Box")

shape.Line({-400, -58}, {-380, -38}, "Box")
shape.Line({380, -58}, {400, -38}, "Box")

shape.Line({-350, -58}, {-380, -38}, "CeilingRightSlope")
shape.Line({380, -58}, {350, -38}, "CeilingLeftSlope")

return grayArea
