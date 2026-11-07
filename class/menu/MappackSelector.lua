local MappackSelector = class("MappackSelector")

local TAB_MAIN = "main"
local TAB_CUSTOM = "custom"

function MappackSelector:initialize(parent)
    self.parent = parent
	love.graphics.setBackgroundColor({0, 0, 0})

	self.canvas = Gui3.Canvas:new(0, 0, SCREENWIDTH, SCREENHEIGHT)
	self.parent.canvas:addChild(self.canvas)

	self.frame = Gui3.Image:new("img/ui/mappacks_frame.png", 0, 0)
	self.canvas:addChild(self.frame)

	-- Tabs above the mappack list
	self.tabButtons = {}
	local tabs = {
		{TAB_MAIN, "MAIN", 20},
		{TAB_CUSTOM, "CUSTOM", 110},
	}
	for i, tab in ipairs(tabs) do
		local button = Gui3.TextButton:new(tab[3], 2, tab[2], true, 0, function()
			self:setTab(tab[1])
		end)
		self.canvas:addChild(button)
		self.tabButtons[tab[1]] = button
	end

	-- Mappack list (left column)
	self.element = Gui3.Box:new(20, 16, 206, 192)
	self.element.scrollable = {false, true}
	self.element.autoArrangeChildren = true
	self.canvas:addChild(self.element)

	-- Description panel (right of the list, shows the selected mappack)
	self.descriptionBox = Gui3.Box:new(240, 16, 148, 130)
	self.descriptionBox.background = {0, 0, 0}
	self.canvas:addChild(self.descriptionBox)

	self.descriptionName = Gui3.Text:new("", 6, 6)
	self.descriptionBox:addChild(self.descriptionName)
	self.descriptionText = Gui3.Text:new("", 6, 18)
	self.descriptionBox:addChild(self.descriptionText)

	-- "Add mappack" creation panel (hidden until requested)
	self:buildCreatePanel()

	self.tab = TAB_MAIN
	self:readMappacks("mappacks/")
	self:setTab(TAB_MAIN)
end

-- MAIN: mappacks shipped with the game. CUSTOM: user-created ones
-- (marked with custom = true in their settings.lua).
function MappackSelector:isCustomMappack(settings)
	return settings.custom == true
end

function MappackSelector:readMappacks(path)
    path = path or "."

	self.mappacks = {main = {}, custom = {}}
	self.paths = {main = {}, custom = {}}
	self.folders = {main = {}, custom = {}}

    local files = love.filesystem.getDirectoryItems(path)

    for i, file in ipairs(files) do
        local fullPath = path .. file .. "/settings.lua"

		local mappackCode, errorMsg = love.filesystem.read(fullPath)
		if mappackCode then
			local data = sandbox.run(mappackCode)
			local list = self:isCustomMappack(data) and "custom" or "main"
			table.insert(self.mappacks[list], data)
			table.insert(self.paths[list], path .. file)
			table.insert(self.folders[list], file)
		end
    end
end

function MappackSelector:setTab(tab)
	self.tab = tab

	-- Highlight the active tab
	for name, button in pairs(self.tabButtons) do
		button.color.background = (name == tab) and {0.25, 0.25, 0.25} or {0, 0, 0, 0}
	end

	self:populateSelector()
end

function MappackSelector:populateSelector()
	self.element:clearChildren()

	local list = self.mappacks[self.tab]
	self.buttons = {}

	for i, mappack in ipairs(list) do
		local backgroundColor = mappack.backgroundColor
		local iconPath = self.paths[self.tab][i] .. "/" .. (mappack.icon or "")
	local icon = love.filesystem.getInfo(iconPath) and iconPath or "img/ui/default_icon.png"

		local button = Gui3.ImageButton:new(0, (i-1)*64, icon, false, false, function()
			selectedMappackPath = self.folders[self.tab][i]
			love.graphics.setBackgroundColor(backgroundColor)
			self.parent:changeWindow(self.canvas, "mainMenu")
		end)
		self.element:addChild(button)
		table.insert(self.buttons, {button = button, mappack = mappack})
	end

	if self.tab == TAB_CUSTOM then
		local addButton = Gui3.TextButton:new(0, #list*64, "+ ADD MAPPACK", true, 0, function()
			self:showCreatePanel(true)
		end)
		addButton.w = 206
		self.element:addChild(addButton)
	end

	-- Default the description to the first mappack on the tab
	self.hovered = nil
	self:setDescription(list[1])
end

function MappackSelector:setDescription(mappack)
	if mappack then
		self.descriptionName:setString(mappack.name or "???")
		self.descriptionText:setString(mappack.description or "")
	else
		self.descriptionName:setString("")
		self.descriptionText:setString("")
	end
end

function MappackSelector:update(dt)
	-- Show the description of the mappack under the mouse
	if self.buttons then
		for _, entry in ipairs(self.buttons) do
			if entry.button.mouse and entry.button.mouse[1] then
				if self.hovered ~= entry.mappack then
					self.hovered = entry.mappack
					self:setDescription(entry.mappack)
				end
			end
		end
	end

	if self.createPanel and self.createPanel.visible then
		self.nameInput:update(dt)
	end
end

function MappackSelector:buildCreatePanel()
	self.createPanel = Gui3.Box:new(70, 67, 260, 90)
	self.createPanel.background = {40/255, 40/255, 40/255}
	self.createPanel.visible = false
	self.canvas:addChild(self.createPanel)

	self.createPanel:addChild(Gui3.Text:new("MAPPACK NAME", 10, 8))

	self.nameInput = Gui3.TextInput:new(10, 22, 28, 1, "")
	self.createPanel:addChild(self.nameInput)

	self.createPanel:addChild(Gui3.TextButton:new(10, 54, "CREATE", true, 0, function()
		self:createMappack(self.nameInput:getValue())
	end))

	self.createPanel:addChild(Gui3.TextButton:new(180, 54, "CANCEL", true, 0, function()
		self:showCreatePanel(false)
	end))
end

function MappackSelector:showCreatePanel(show)
	self.createPanel.visible = show
end

-- Mappack names: lowercase letters, numbers and hyphens only
function MappackSelector:isValidMappackName(name)
	if not name or #name < 1 or #name > 32 then
		return false
	end

	return string.match(name, "^[a-z0-9][a-z0-9%-]*$") ~= nil
end

function MappackSelector:createMappack(name)
	name = string.gsub(name or "", "%s+", "")

	if not self:isValidMappackName(name) then
		return
	end

	-- Don't overwrite an existing mappack
	for _, list in pairs(self.folders) do
		for _, folder in ipairs(list) do
			if folder == name then
				return
			end
		end
	end

	local levelCode = [[return {
    levelCode = "w ★01",
	tileMaps = {"smb3-overworld", "smb3-general"},
    lookups = {
		{1, 1},  --1. Ground
		{1, 107},--2. Stage end
	},
    layers = {
        {
            y = 0,
            x = 0,
            map = {
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
				{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
			}
        }
    },
    entities = {
        {type="spawn", x=3, y=24},
    },
}
]]

	local settingsCode = table.concat({
		"return {\n",
		'    name = "', name, '",\n',
		'    description = "A brand new mappack.",\n',
		"\n",
		'    icon = "icon.png",\n',
		"\tbackgroundColor = {100/255,176/255,255/255},\n",
		"\n",
		'    players = "any",\n',
		"\n",
		'    main = "1-1.lua",\n',
		"\n",
		"\tcustom = true,\n",
		"}\n",
	})

	love.filesystem.write("mappacks/" .. name .. "/settings.lua", settingsCode)
	love.filesystem.write("mappacks/" .. name .. "/1-1.lua", levelCode)

	-- Bundle a default icon so the selector button has something to show
	local iconData = love.filesystem.read("mappacks/test_levels/icon.png")
	if iconData then
		love.filesystem.write("mappacks/" .. name .. "/icon.png", iconData)
	end

	self:showCreatePanel(false)
	self:readMappacks("mappacks/")
	self:setTab(TAB_CUSTOM)
end

return MappackSelector
