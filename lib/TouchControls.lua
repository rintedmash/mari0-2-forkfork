local controls3 = require "lib.controls3"

local TouchControls = {}
local activeTouches = {}
local activeCommands = {}

function TouchControls.getButtons(width, height)
    local radius = math.max(12, math.floor(math.min(width, height) * 0.085))
    local spacing = radius * 2 + 4
    local centerX = radius * 3 + 12
    local centerY = height - radius * 3 - 12

    return {
        {command = "left", label = "<", x = centerX - spacing, y = centerY, radius = radius},
        {command = "right", label = ">", x = centerX + spacing, y = centerY, radius = radius},
        {command = "up", label = "^", x = centerX, y = centerY - spacing, radius = radius},
        {command = "down", label = "v", x = centerX, y = centerY + spacing, radius = radius},
        {command = "run", label = "B", x = width - radius * 3 - 20, y = height - radius - 8, radius = radius},
        {command = "jump", label = "A", x = width - radius - 8, y = height - radius - 8, radius = radius},
    }
end

function TouchControls.press(id, x, y, width, height, onCommand)
    local button
    for _, candidate in ipairs(TouchControls.getButtons(width, height)) do
        local dx = x - candidate.x
        local dy = y - candidate.y
        if dx * dx + dy * dy <= candidate.radius * candidate.radius then
            button = candidate
            break
        end
    end

    if not button then
        return false
    end

    if activeTouches[id] then
        TouchControls.release(id)
    end

    local wasDown = controls3.cmdDown(button.command)
    activeTouches[id] = button.command
    activeCommands[button.command] = (activeCommands[button.command] or 0) + 1
    controls3.setVirtualCmd(button.command, true)

    if not wasDown and onCommand then
        onCommand(button.command)
    end

    return true
end

function TouchControls.release(id)
    local command = activeTouches[id]
    if not command then
        return false
    end

    activeTouches[id] = nil
    activeCommands[command] = activeCommands[command] - 1
    if activeCommands[command] == 0 then
        activeCommands[command] = nil
        controls3.setVirtualCmd(command, false)
    end

    return true
end

function TouchControls.reset()
    for command in pairs(activeCommands) do
        controls3.setVirtualCmd(command, false)
        activeCommands[command] = nil
    end
    for id in pairs(activeTouches) do
        activeTouches[id] = nil
    end
end

function TouchControls.draw(width, height)
    if not love.touch or not love.touch.isSupported or not love.touch.isSupported() then
        return
    end

    for _, button in ipairs(TouchControls.getButtons(width, height)) do
        local pressed = controls3.cmdDown(button.command)
        local radius = button.radius
        love.graphics.setColor(0.03, 0.04, 0.05, pressed and 0.68 or 0.38)
        love.graphics.circle("fill", button.x, button.y, radius)
        love.graphics.setColor(1, 1, 1, pressed and 0.95 or 0.62)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", button.x, button.y, radius)
        local font = love.graphics.getFont()
        love.graphics.printf(button.label, button.x - radius, button.y - font:getHeight() / 2, radius * 2, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return TouchControls
