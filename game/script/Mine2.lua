dofile("script/occlusion.lua")
dofile("script/exit.lua")
dofile("script/shape.lua")
dofile("script/action.lua")
dofile("script/Teleporter.lua")
dofile("script/save-point.lua")
dofile("script/Common.lua")

LoadPlayers()

dofile("script/Mine.lua")

local camBox = {l=-1000,r=7000,b=-1000,t=1000}
camera = util.CreateCamera(gameWorld, mainPC, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.0, g=0.0, b=0.0})

eapi.RandomSeed(1492)

staticBody = eapi.GetStaticBody(gameWorld)

local function ActivateMineTeleporter()
	if game.GetState().teleporterFixed then
		teleporter.Use("Pyramid", {-7110, 297}, false)
	else
		local count = 5
		local volume = 1
		local function Clicker()
			eapi.PlaySound(gameWorld, "sound/click.ogg", 0, volume)
			volume = ((volume > 0.7) and 0.5) or 1.0
			if count > 0 then
				eapi.AddTimer(mainPC.body, 0.25, Clicker)
				count = count - 1
			end
		end
		Clicker()
		mainPC.StopInput()
		util.GameMessage(txt.teleporterDoesNotWork,
				 camera, mainPC.StartInput)
	end
end

local function TeleporterRoom(x, y)
	-- front stalactites
	local i = -64
	local j = 0
	repeat
		local yy = y - 64 + util.Random(0, 32) - j
		Occlusion.RandomStalactite(x + i, yy - 32, 10,
					   util.ToBeOrNotToBe())
		Occlusion.put('f', x + i, yy - 256, 10, { size={64, 256} })
		local yyy = y - 64 + util.Random(0, 32) + 192
		Occlusion.RandomStalagmite(x + i, yyy, 10, util.ToBeOrNotToBe())
		Occlusion.put('f', x + i, yyy + 128, 10, { size={64, 256} })
		i = i + util.Random(24, 40)
		if i > 128 and i < 224 then
			j = j + util.Random(32, 48)
		end
	until i > 1000

	-- darkness
	Mine.HorizontalGradient(x + 896, y - 384, 128, 1024, false, 1.0)
	Occlusion.put('f', x + 1024, y - 384, 10.0, { size={512, 1024} })

	-- walk shape
	shape.Line({ x, y }, { x + 96, y - 48 }, "Box")
	shape.Line({ x + 96, y }, { x + 256, y - 160 })
	shape.Line({ x + 256, y - 160 }, { x + 1024, y - 224 }, "Box")
	shape.Line({ x + 1024, y - 160 }, { x + 1152, y + 768 }, "Box")	
	shape.Line({ x, y + 256 }, { x + 1024, y + 306 }, "Box")

	Mine.CavernEntrance(x, y, ww, true)

	local function Parallax(offset, scroll, depth, img, yoffset, color)
		Mine.Parallax(x, y, offset, scroll, depth, img, yoffset, color)
	end
	Parallax(-384, 0.9, nil, nil, nil, { r = 0.4, g = 0.4, b = 0.4 } )
	Parallax(64, 0.9, nil, nil, nil, { r = 0.4, g = 0.4, b = 0.4 } )
	Parallax(-736, 0.85, -12, nil, nil, { r = 0.2, g = 0.2, b = 0.2 } )
	Parallax(-320, 0.85, -12, nil, nil, { r = 0.2, g = 0.2, b = 0.2 } )
	Parallax(96, 0.95, -10.5)

 	Occlusion.put('c', x, y - 128, -5, 
		      { size={2000, 32}, flip = { false, true } })

	Parallax(-768, 0.87, -11.1, Mine.glowWorm, 64)
	Parallax(-256, 0.87, -11.1, Mine.glowWorm, 64)
	Parallax(128, 0.87, -11.1, Mine.glowWorm, 64)

	Parallax(-512, 0.925, -10.7, Mine.glowWorm, 60)
	Parallax(0, 0.925, -10.7, Mine.glowWorm, 60)

	Parallax(-256, 0.975, -10.3, Mine.glowWorm, 56)
	Parallax(256, 0.975, -10.3, Mine.glowWorm, 56)

	teleporter.Put(x + 600, y - 160, ActivateMineTeleporter)
end

local function Mine2(x, y)
	-- occlude left of entrance 
	Occlusion.put('f', x-1024, y-152, 10.0, { size={1024, 1024} })

	Mine.Entrance(x, y)

	Mine.Tunnel(x, y, 10)

	-- occlude entering light
	Mine.HorizontalGradient(x, y - 24, 9*128 + 64, 256, false, 0.7)
	Mine.HorizontalGradient(x + 9 * 128 + 64, y - 24, 64, 256, true, 0.7)

	Mine.LeftShaft(x + 10 * 128, y + 128, 6)
	
	-- light tunnel from crystals
	Occlusion.put('w', x + 8 * 128, y - 24, 9,
		      { size={256, 256}, multiply=true })

	ExitRoom({l=x, b=y-24, r=x+16, t=y+232 }, "Forest",
		 { 20923, 17 }, nil, nil, nil, eapi.SLIDE_LEFT)

	Mine.FlowerTunnel(x + 12 * 128, y - 3 * 128, 10)

	Mine.RightShaft(x + 22 * 128, y + 2 * 128, 7)

	Mine.FlowerTunnel(x + 24 * 128, y + 128, 3)

	Mine.LeftShaft(x + 27 * 128, y + 256, 6)

	Mine.CrystalTunnel(x + 29 * 128, y - 2 * 128, 5)

	Mine.RightShaft(x + 34 * 128, y + 5 * 128, 9)

	Mine.CrystalTunnel(x + 36 * 128, y + 512, 7)

	TeleporterRoom(x + 43 * 128, y + 512)
end

Mine2(0, 0)

teleporter.Arrive()

eapi.PlaySound(gameWorld, "sound/creepy.ogg", -1, 0.9)

local exports = {
	SavePoint = {func=savePoint.Put,points=1},
	MedKit = {func=savePoint.Medkit,points=1},
	WaterDrop = {func=common.Rain,points=2},
}
editor.Parse("script/Mine2-edit.lua", gameWorld, exports)
