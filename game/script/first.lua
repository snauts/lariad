--[[
	This is the first and only script file executed directly by the engine.
	What happens next is then entirely up to this script.
]]--

dofile("config.lua")
dofile("script/util.lua")
if util.FileExists("setup.lua") then
	dofile("setup.lua")
end
dofile("script/vector.lua")
dofile("script/Effects.lua")
dofile("script/Menu.lua")
dofile("script/Editor.lua")

gameWorld = nil
allPlayers = {}
stopPoint = nil

-- Create main player character.
dofile("script/Destroyer.lua")
mainPC = destroyer.Create()
table.insert(allPlayers, mainPC)

dofile("script/Game.lua")

-- Load (reload) global player characters into engine.
function LoadPlayers()
	for i, PC in ipairs(allPlayers) do
		if PC.type == "Destroyer" then
			destroyer.Load(gameWorld, PC)
		else
			error("Unknown player type.")
		end
	end
end

if (util.FileExists("script/debug.lua")) then
	-- debug.lua should not be in repository
	-- it is intended to be independent for each developer
	dofile("script/debug.lua")
	if gameWorld then return end
end

-- Here goes game startup sequence
util.GoTo("Startup", nil, true)
