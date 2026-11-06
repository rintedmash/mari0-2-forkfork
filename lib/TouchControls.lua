local controls3 = require "lib.controls3"

local TouchControls = {}
local activeTouches = {}
local activeButtons = {}
local activeCommands = {}
local runLocked = false
local pointerX
local pointerY

local function makeButton(command, label, x, y, width, height, shape, options)
    options = options or {}
    local virtual = options.virtual
    if virtual == nil then
        virtual = not options.mouseButton and not options.toggle and command ~= "start"
    end
    return {
        command = command,
        label = label,
        x = x,
        y = y,
        width = width,
        height = height,
        shape = shape or "square",
        virtual = virtual,
        emitOnPress = options.emitOnPress or false,
        mouseButton = options.mouseButton,
        toggle = options.toggle,
        requiresPortalGun = options.requiresPortalGun or false,
        color = options.color,
    }
end

function TouchControls.getButtons(width, height, mode)
    mode = mode or "game"
    local unit = math.min(width / 400, height / 224)
    local startWidth = 43 * unit
    local startHeight = 16 * unit
    local start = makeButton("start", "START", width - 48 * unit, 5 * unit, startWidth, startHeight, "square", {emitOnPress = true})

    if mode == "menu" or mode == "editor" then
        return {start}
    end
    if mode == "aim" then
        return {}
    end

    local dpadSize = 30 * unit
    local actionSize = 50 * unit
    local smallSize = 25 * unit
    local portalX = 6 * unit
    local runX = width - 108 * unit
    local jumpX = width - 54 * unit
    local runY = height - 55 * unit
    local jumpY = height - 65 * unit
    local dpadY = height - 65 * unit

    return {
        makeButton("portal1", "1", portalX, 73 * unit, smallSize, smallSize, "circle", {mouseButton = 1, requiresPortalGun = true, color = {0.12, 0.56, 0.98}}),
        makeButton("portal2", "2", portalX, 101 * unit, smallSize, smallSize, "circle", {mouseButton = 2, requiresPortalGun = true, color = {0.98, 0.47, 0.08}}),
        makeButton("closePortals", "R", portalX, 129 * unit, smallSize, smallSize, "circle", {virtual = true, emitOnPress = true, requiresPortalGun = true}),
        makeButton("left", "<", 11 * unit, dpadY, dpadSize, dpadSize, "square", {virtual = true}),
        makeButton("right", ">", 69 * unit, dpadY, dpadSize, dpadSize, "square", {virtual = true}),
        makeButton("up", "^", 40 * unit, 130 * unit, dpadSize, dpadSize, "square", {virtual = true}),
        makeButton("down", "v", 40 * unit, 188 * unit, dpadSize, dpadSize, "square", {virtual = true}),
        makeButton("use", "U", width - 133 * unit, runY, smallSize, smallSize, "circle", {virtual = true, emitOnPress = true}),
        makeButton("runlock", "+", width - 133 * unit, height - 30 * unit, smallSize, smallSize, "circle", {toggle = "run"}),
        makeButton("run", "B", runX, runY, actionSize, actionSize, "circle", {virtual = true, emitOnPress = true}),
        makeButton("jump", "A", jumpX, jumpY, actionSize, actionSize, "circle", {virtual = true, emitOnPress = true}),
        start,
    }
end

local function hasPortalGun()
    local activeGame = rawget(_G, "game")
    local player = activeGame and activeGame.players and activeGame.players[1]
    local actor = player and player.actor
    if not actor then
        return true
    end
    return actor.hasPortalGun == true
end

local function buttonAvailable(button)
    return not button.requiresPortalGun or hasPortalGun()
end

local function findButton(x, y, width, height, mode)
    local buttons = TouchControls.getButtons(width, height, mode)
    for i = #buttons, 1, -1 do
        local button = buttons[i]
        if buttonAvailable(button) then
            if button.shape == "circle" then
                local centerX = button.x + button.width / 2
                local centerY = button.y + button.height / 2
                local radius = math.min(button.width, button.height) / 2
                local dx = x - centerX
                local dy = y - centerY
                if dx * dx + dy * dy <= radius * radius then
                    return button
                end
            elseif x >= button.x and x <= button.x + button.width and y >= button.y and y <= button.y + button.height then
                return button
            end
        end
    end
end

local function changeVirtualState(command)
    if command == "run" then
        controls3.setVirtualCmd(command, runLocked or (activeCommands[command] or 0) > 0)
    else
        controls3.setVirtualCmd(command, (activeCommands[command] or 0) > 0)
    end
end

local function emit(onCommand, button, phase)
    if onCommand then
        onCommand(button.command, button, phase)
    end
end

local function countButton(button, delta)
    local count = (activeButtons[button.command] or 0) + delta
    if count <= 0 then
        activeButtons[button.command] = nil
        return false
    end
    activeButtons[button.command] = count
    return true
end

local function pressButton(id, button, onCommand)
    local wasDown
    if button.toggle == "run" then
        wasDown = controls3.cmdDown("run")
    elseif button.virtual then
        wasDown = controls3.cmdDown(button.command)
    end

    activeTouches[id] = button
    countButton(button, 1)

    if button.toggle == "run" then
        runLocked = not runLocked
        changeVirtualState("run")
        if runLocked and not wasDown and onCommand then
            onCommand("run", button, "press")
        end
    elseif button.virtual then
        activeCommands[button.command] = (activeCommands[button.command] or 0) + 1
        changeVirtualState(button.command)
        if not wasDown then
            emit(onCommand, button, "press")
        end
    elseif button.mouseButton or button.emitOnPress then
        emit(onCommand, button, "press")
    end
end

function TouchControls.press(id, x, y, width, height, onCommand, mode)
    local button = findButton(x, y, width, height, mode or "game")
    if not button then
        return false
    end

    if activeTouches[id] then
        TouchControls.release(id, onCommand)
    end

    pressButton(id, button, onCommand)
    return true, button
end

function TouchControls.release(id, onCommand)
    local button = activeTouches[id]
    if not button then
        return false
    end

    activeTouches[id] = nil
    local stillHeld = countButton(button, -1)

    if button.virtual then
        local count = (activeCommands[button.command] or 0) - 1
        if count <= 0 then
            activeCommands[button.command] = nil
        else
            activeCommands[button.command] = count
        end
        changeVirtualState(button.command)
    elseif button.mouseButton and not stillHeld then
        emit(onCommand, button, "release")
    end

    return true, button
end

function TouchControls.move(id, x, y, width, height, onCommand, mode)
    local current = activeTouches[id]
    local target = findButton(x, y, width, height, mode or "game")

    if current and target and current.command == target.command then
        return true, current
    end

    if current then
        TouchControls.release(id, onCommand)
    end

    if not target then
        return false
    end

    pressButton(id, target, onCommand)
    return true, target
end

function TouchControls.reset(onCommand)
    local ids = {}
    for id in pairs(activeTouches) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        TouchControls.release(id, onCommand)
    end

    activeTouches = {}
    activeButtons = {}
    activeCommands = {}
    runLocked = false
    controls3.setVirtualCmd("run", false)
    pointerX = nil
    pointerY = nil
end

function TouchControls.setPointer(x, y)
    pointerX = x
    pointerY = y
end

function TouchControls.clearPointer()
    pointerX = nil
    pointerY = nil
end

function TouchControls.getPointer()
    return pointerX, pointerY
end

function TouchControls.isSupported()
    return love.touch and love.touch.isSupported and love.touch.isSupported()
end

function TouchControls.draw(width, height, mode)
    if not TouchControls.isSupported() then
        return
    end

    for _, button in ipairs(TouchControls.getButtons(width, height, mode)) do
        if buttonAvailable(button) then
            local pressed = button.toggle == "run" and runLocked or activeButtons[button.command] ~= nil
            if button.color then
                love.graphics.setColor(button.color[1], button.color[2], button.color[3], pressed and 0.82 or 0.48)
            else
                love.graphics.setColor(0.04, 0.05, 0.07, pressed and 0.72 or 0.42)
            end

            if button.shape == "circle" then
                local radius = math.min(button.width, button.height) / 2
                love.graphics.circle("fill", button.x + button.width / 2, button.y + button.height / 2, radius)
                love.graphics.setColor(1, 1, 1, pressed and 0.95 or 0.64)
                love.graphics.circle("line", button.x + button.width / 2, button.y + button.height / 2, radius)
            else
                love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
                love.graphics.setColor(1, 1, 1, pressed and 0.95 or 0.64)
                love.graphics.rectangle("line", button.x + 0.5, button.y + 0.5, button.width - 1, button.height - 1, 5, 5)
            end

            love.graphics.setColor(1, 1, 1, pressed and 1 or 0.82)
            local font = love.graphics.getFont()
            love.graphics.printf(button.label, button.x, button.y + (button.height - font:getHeight()) / 2, button.width, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return TouchControls
