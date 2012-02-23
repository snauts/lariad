
-- Menu world.
local menuWorld = nil

-- Menu items.
local items = {}	-- Item table.
local selectedItem = 1	-- Selection index.

local RESUME = 1
local LOAD   = 2
local QUIT   = 3

local gray = { r = 0.7, g = 0.7, b = 0.7 }

local function BackToStartup()
	util.GoTo("Startup", nil, true)
end

local Kill = nil

local function LoadOrNewText()
	return (game.HasSaavgaam() and txt.Load) or txt.New
end

local function LoadOrNewGame()
	if game.HasSaavgaam() then 
		game.Load(nil, true)
	else
		util.NewGame()
	end
end

-- Create and display menu.
local function Show(ExitFunc, disableDim, dialogPositioner, argItems, headLine)
	menuWorld = eapi.NewWorld("Menu", 5, 11)
	if not(disableDim) then 
		eapi.SetBackgroundColor(menuWorld, {r=0,g=0,b=0,a=0.5})
	end
	local camera = util.CreateCamera(menuWorld, nil, nil, nil)

	-- Load tiles.
	local staticBody = eapi.GetStaticBody(menuWorld)
	
	selectedItem  = 1
	if argItems then
		items = argItems
	else
		-- Fill item table.
		items[RESUME] = { active = true,
				  text = txt.Resume,
				  disableKill = true,
				  fn = ExitFunc }
		items[LOAD] = { active = true,
				text = LoadOrNewText(),
				fn = LoadOrNewGame }
		items[QUIT]   = { active = true,
				  text = txt.Quit,
				  fn = BackToStartup }
		
		if not(ExitFunc) or mainPC.dead then
			items[RESUME].active = false
			selectedItem = selectedItem + 1
		end
	end
	for i, v in pairs(items) do
		if v.select then selectedItem = i end
	end

	local tiles = nil
	local function RefreshMenu()
		if tiles then
			util.Map(eapi.Destroy, tiles)
			tiles = nil
		end
		local num = 1
		local fullText = { }
		fullText[1] = headLine or txt.Menu
		fullText[2] = txt.Seperator
		for i, item in ipairs(items) do
			local mark = (num == selectedItem) and "-> " or "   "
			local str = mark .. item.text
			if not(item.active) then
				str = { str = str, ink = gray }
			end
			fullText[#fullText + 1] = str
			num = num + 1
		end		
		tiles = util.DialogBox(fullText, camera, dialogPositioner)
	end
	RefreshMenu()
	
	-- Up/down key handling.
	local function UpDown(key, keyDown)
		if not keyDown then return end

		local sel = selectedItem
		if util.Member(key, Cfg.keyUp)
		or key == eapi.MOUSE_BUTTON_WHEELUP
		or key == eapi.KEY_UP then
			while true do
				sel = sel - 1
				if sel < 1 then
					break	-- Reached top, nothing found.
				end
				if items[sel].active then
					selectedItem = sel
					util.Tik()
					break	-- Found active item.
				end
			end
		elseif util.Member(key, Cfg.keyDown)
		or key == eapi.MOUSE_BUTTON_WHEELDOWN
		or key == eapi.KEY_DOWN	then
			while true do
				sel = sel + 1
				if sel > #items then
					break	-- Reached bottom, nothing found.
				end
				if items[sel].active then
					selectedItem = sel
					util.Tik()
					break	-- Found active item.
				end
			end
		end
		
		RefreshMenu()
	end
	util.BindKeys(Cfg.keyUp, UpDown)
	util.BindKeys(Cfg.keyDown, UpDown)
	eapi.BindKey(eapi.KEY_UP, UpDown)
	eapi.BindKey(eapi.KEY_DOWN, UpDown)
	eapi.BindKey(eapi.MOUSE_BUTTON_WHEELUP, UpDown)
	eapi.BindKey(eapi.MOUSE_BUTTON_WHEELDOWN, UpDown)
	
	-- Enter selects an item.
	local function Select(key, keyDown)
		if not keyDown then return end
		local Do = items[selectedItem].fn
		if not(items[selectedItem].disableKill) then 
			Kill()
		end
		util.Click()
		local ret = Do()
		if ret == "exit" then
			ExitFunc()
		end
	end

	eapi.BindKey(eapi.KEY_RETURN, Select)
	eapi.BindKey(eapi.KEY_KP_ENTER, Select)
	eapi.BindKey(eapi.MOUSE_BUTTON_LEFT, Select)
	util.BindKeys(Cfg.keyShoot, Select)
	util.BindKeys(Cfg.keyJump, Select)
	eapi.BindKey(eapi.KEY_SPACE)
end

-- Destroy menu.
Kill = function()
	assert(menuWorld, "Menu not created yet.")

	util.BindKeys(Cfg.keyUp)
	util.BindKeys(Cfg.keyDown)
	eapi.BindKey(eapi.KEY_UP)
	eapi.BindKey(eapi.KEY_DOWN)
	eapi.BindKey(eapi.MOUSE_BUTTON_WHEELUP)
	eapi.BindKey(eapi.MOUSE_BUTTON_WHEELDOWN)
	eapi.BindKey(eapi.KEY_RETURN)
	eapi.BindKey(eapi.KEY_KP_ENTER)
	eapi.BindKey(eapi.MOUSE_BUTTON_LEFT)
	util.BindKeys(Cfg.keyShoot)
	util.BindKeys(Cfg.keyJump)

	eapi.Resume(gameWorld)
	eapi.Destroy(menuWorld)
	
	resumeTile = nil
	menuWorld = nil
	quitTile = nil
	items = { }
end

menu = {
	Show = Show,
	Kill = Kill,
}
return menu
