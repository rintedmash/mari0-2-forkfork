local Menus = class("Menus")
local TouchControls = require "lib.TouchControls"

Menus.windowClasses = {
    mappackSelector = require("class.menu.MappackSelector"),
    mainMenu = require("class.menu.MainMenu"),
	optionsMenu = require("class.menu.OptionsMenu")
}

function Menus:newWindow(windowClass)
	table.insert(self.windows, windowClass:new(self))
end

function Menus:changeWindow(oldWindow, windowClass)
	table.remove(self.windows, 1)
	-- The window object wraps a Gui3.Canvas; remove that, not the wrapper
	self.canvas:removeChild(oldWindow.canvas)
	self:newWindow(self.windowClasses[windowClass])
end

function Menus:initialize(selectedMenu)
	self.selectedMenu = selectedMenu
end

function Menus:load()
	self.windows = {}

	self.canvas = Gui3.Canvas:new(0, 0, SCREENWIDTH, SCREENHEIGHT)
    self.canvas.gui = defaultUI
	self:newWindow(self.windowClasses[self.selectedMenu])
end



function Menus:update(dt)
    prof.push("UI")
    self.canvas:update(dt)
    self.canvas:rootmousemoved(love.mouse.getX()/VAR("scale"), love.mouse.getY()/VAR("scale"))
    prof.pop()
end

function Menus:draw()
    prof.push("UI")

    love.graphics.setColor(1, 1, 1)
    love.graphics.push()
    love.graphics.origin()
    self.canvas:rootDraw()
    love.graphics.scale(VAR("scale"), VAR("scale"))
    TouchControls.draw(SCREENWIDTH, SCREENHEIGHT, "menu")
    love.graphics.pop()

    prof.pop()
end



function Menus:mousepressed(x, y, button)
    self.canvas:rootmousemoved(x, y)
    if self.canvas:rootmousepressed(x, y, button) then
        return true
    end
end

function Menus:mousereleased(x, y, button)
    if self.canvas:rootmousereleased(x, y, button) then
        return true
    end
end

function Menus:textinput(text)
    if self.canvas:roottextinput(text) then
        return true
    end
end

function Menus:keypressed(key)
    if self.canvas:rootkeypressed(key) then
        return true
    end
end

return Menus