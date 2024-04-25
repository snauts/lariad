dofile("script/exit.lua")
dofile("script/Common.lua")

-- doNotInitCamera is dirty hack,
-- Djikstra is probably rolling in his grave

doNotInitCamera = true 
dofile("script/GrayAreaRoomB.lua")
doNotInitCamera = nil

camera = util.CreateCamera(gameWorld, { -300, -150 })

shape.Line({-100,-25}, {-150,-180}, "Box")

Occlusion.put('a', -300, -240, 10.0, { size={100, 160} })
Occlusion.put('b', -400, -240, 10.0, { size={100, 160} })
Occlusion.put('d', -300,  -80, 10.0, { size={100, 20} })
Occlusion.put('e', -400,  -80, 10.0, { size={100, 20} })
Occlusion.put('c', -400,  -240, 10.0, { size={200, 40}, flip = {false,true} })
Occlusion.put('f', -400,  -60, 10.0, { size={200, 300} })
Occlusion.put('f', -200, -240, 10.0, { size={600, 480} })
Occlusion.put('f', -1000, -440, 10.0, { size={600, 880} })

common.Bed({x = -360, y = -205})

-- Exits.
ExitRoom({l=-400, b=-180.00, r=-399, t=-80}, "CommandBridge", {350, -162},
 	 nil, nil, nil, eapi.SLIDE_LEFT)

action.MakeMessage(txt.wall, {l=-160, b=-170, r=-150, t=-160}, txt.darkInfo)
