--Mari0 2 - MIT License.
local gameStartTime = love.timer.getTime()
local lovetest = require "test/lovetest"
require "errorhandler"
require "loop"

local TouchControls = require "lib.TouchControls"
local touchOwners = {}
local touchInputLogged = {}
local forceTouchControls = os.getenv("MARI0_FORCE_TOUCH_CONTROLS") == "1"
local forcedMouseTouch = false
local forcedMouseTouchId = "mari0-forced-desktop-touch"
local fitToScreen = false
local Game, Editor, Menus

local function isHandheldOS()
    if type(love) ~= "table" or not love.system or not love.system.getOS then
        return false
    end

    local osName = love.system.getOS()
    return osName == "Android" or osName == "iOS"
end

function love.load(arg)
	if lovetest.detect(arg) then
		lovetest.run()
	end

    require "util"

    fitToScreen = isHandheldOS() or os.getenv("MARI0_FORCE_FIT") == "1"

    if fitToScreen then
        -- Handhelds already run fullscreen: requesting a 400x224 surface gets
        -- it stretched non-uniformly across the screen and desynchronizes
        -- touch coordinates. Keep the native surface and scale the logical
        -- view to fit it instead.
        if love.graphics.getWidth() == 0 then
            love.window.setMode(0, 0, {
                vsync = VAR("vsync"),
                resizable = true,
                msaa = VAR("msaa"),
            })
        end
        setVAR("scale", math.min(love.graphics.getWidth()/400, love.graphics.getHeight()/224))
    else
        love.window.setMode(400*VAR("scale"), 224*VAR("scale"), {
            vsync = VAR("vsync"),
            resizable = true,
            msaa = VAR("msaa"),
            minwidth = 243*VAR("scale"),
            minheight = 165*VAR("scale"),
        })
    end

    love.graphics.setDefaultFilter("nearest", "nearest")

    fontOutlined = love.graphics.newImageFont("img/font-outlined.png",
        [[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~¡¢£€¥Šš§©ª«¬▯®¯°±²³Žµ¶·ž¹º»ŒœŸ¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ∩⇔→⇒◔★⛫𓉴🔫🌐🌱🍄🏜️🏰🔨🚢🛦]])
	love.graphics.setFont(fontOutlined)

	local splash = "NOW LOADING..."
	love.graphics.print(splash, 400*VAR("scale")/2-fontOutlined:getWidth(splash)*3/2, 224*VAR("scale")/2, 0, 3)
	love.graphics.present()

    love.window.setTitle("Mari0 2")
    love.window.setIcon(love.image.newImageData("img/icon.png"))

    -- Libs
    utf8 = require "utf8"
    class = require "lib.middleclass"
    sandbox = require "lib.sandbox"
    Easing = require "lib.Easing"
	paletteShader = require "lib.paletteShader"
	i18n = require "lib.i18n"
	i18n.load()
	i18n.configure({
	  currentLocale = VAR("locale")
	})
	print(i18n.t("startMsg"))
    if VAR("debug").jprof then
        PROF_CAPTURE = true
    end
    prof = require "lib.jprof.jprof"
    prof.enabled(false)
    if VAR("debug").jprof then
        PROF_CAPTURE = true
    end	

    -- Self written libs
    Color3 = require "lib.Color3"
    Physics3 = require "lib.Physics3"
    Gui3 = require "lib.Gui3"
    FrameDebug3 = require "lib.FrameDebug3"
    controls3 = require "lib.controls3"
    controls3.setCmdTable(require "controls")

    -- Loaders
    SETTINGS = require "settingsLoader"
    require "actorTemplateLoader"
    require "componentLoader"
	require "soundLoader"

    -- Misc
    require "cheats"

    -- States
    Game = require "state.Game"
    Editor = require "state.Editor"
	Menus = require "state.Menus"

    debugCandyImg = love.graphics.newImage("img/debug-candy.png")
    debugCandyImg:setWrap("repeat")

    defaultUI = Gui3:new("img/gui/default")

	love.graphics.clear(0,0,0)
    local GameStateManager3 = require "lib.GameStateManager3"
    gameStateManager = GameStateManager3:new()

    if fitToScreen then
        love.resize(love.graphics.getWidth(), love.graphics.getHeight())
    else
        love.resize(400*VAR("scale"), 224*VAR("scale"))
    end
    TouchControls.setPointer(SCREENWIDTH / 2, SCREENHEIGHT / 2)

    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
    local windowWidth, windowHeight = love.window.getMode()
    print(string.format(
        "MARI0_VIDEO os=%s drawable=%dx%d window=%dx%d desktop=%dx%d scale=%.3f logical=%dx%d touchSupported=%s fitToScreen=%s",
        love.system.getOS(),
        love.graphics.getWidth(), love.graphics.getHeight(),
        windowWidth, windowHeight,
        desktopWidth, desktopHeight,
        VAR("scale"), SCREENWIDTH, SCREENHEIGHT,
        tostring(TouchControls.isSupported()), tostring(fitToScreen)
    ))

    -- Alright let's go do the stuff
	selectedMappackPath = VAR("debug").mappack

	if not VAR("debug").skipTitle then
		gameStateManager:addState(Menus:new("mainMenu"))
    else
		editorEnabled = true
		game = Game:new(selectedMappackPath, 1)

		gameStateManager:loadState(game)
		gameStateManager:addState(Editor:new(game.level))
    end

    gameStateManager:event("resize", SCREENWIDTH, SCREENHEIGHT)

	print(love.timer.getTime() - gameStartTime)
    prof.enabled(true)
    print("MARI0_2_STARTUP_COMPLETE")
    if io.stdout then
        io.stdout:flush()
    end
end

function newGame(mappack, editorEnabled, players)
	local players = players or 1
    if mappack then
        table.remove(gameStateManager.activeStates, players)
        game = Game:new(mappack, players, editorEnabled)
        gameStateManager:loadState(game)
		
		if editorEnabled then
			gameStateManager:addState(Editor:new(game.level))
		end
		
        gameStateManager:event("resize", SCREENWIDTH, SCREENHEIGHT)
	else
		print("No mappack")
    end
end

function playLevel(path, players)
	local players = players or 1
	if path then
        table.remove(gameStateManager.activeStates, players)
        game = Game:new(nil, players, false, path)
        gameStateManager:loadState(game)
		
		gameStateManager:event("resize", SCREENWIDTH, SCREENHEIGHT)
	else
		print("No level")
	end
end

function returnToMenu()
	love.audio.stop()
	love.mouse.setCursor(love.mouse.getSystemCursor("arrow"))
	table.remove(gameStateManager.activeStates, 1)
	table.remove(gameStateManager.activeStates, 1)
	gameStateManager:addState(Menus:new("mainMenu"))
end

function love.update(dt)
    if VAR("debug").lovebird then
        require("lib/lovebird").update()
    end

    dt = math.min(1/60, dt) -- Min 60 FPS

    dt = FrameDebug3.update(dt)

    if not dt then
        return
    end

    gameStateManager:event("update", dt)
end

local function setColorBasedOn(key)
    if controls3.cmdDown(key) then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.2, 0.2, 0.2)
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(VAR("scale"), VAR("scale"))

    gameStateManager:event("draw")

    -- For the stream
    if VAR("debug").input and not TouchControls.isSupported() then
        setColorBasedOn("up")
        love.graphics.rectangle("fill", 16, SCREENHEIGHT-32, 8, 8)
        setColorBasedOn("left")
        love.graphics.rectangle("fill", 8, SCREENHEIGHT-24, 8, 8)
        setColorBasedOn("right")
        love.graphics.rectangle("fill", 24, SCREENHEIGHT-24, 8, 8)
        setColorBasedOn("down")
        love.graphics.rectangle("fill", 16, SCREENHEIGHT-16, 8, 8)

        setColorBasedOn("run")
        love.graphics.rectangle("fill", 60, SCREENHEIGHT-20, 8, 8)
        setColorBasedOn("jump")
        love.graphics.rectangle("fill", 72, SCREENHEIGHT-20, 8, 8)


        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.pop()
end

function love.keypressed(key)
    local cmds, any = controls3.getCmdsForKey(key)

    if cmds["quit"] then
        returnToMenu()
    end

    -- debug
    if cmds["debug.pausePlay"] then
        FrameDebug3.pausePlay()
    end

    if cmds["debug.frameAdvance"] then
        FrameDebug3.frameAdvance()
    end

    if any then
        gameStateManager:event("cmdpressed", cmds)
    end

    gameStateManager:event("keypressed", key)
end

function love.textinput(text)
    gameStateManager:event("textinput", text)
end

function love.mousepressed(x, y, button, istouch)
    if istouch then
        return
    end
    if forceTouchControls and button == 1 then
        forcedMouseTouch = true
        love.touchpressed(forcedMouseTouchId, x, y)
        return
    end

    TouchControls.clearPointer()
    x, y = x/VAR("scale"), y/VAR("scale")

    gameStateManager:event("mousepressed", x, y, button)
end

function love.mousereleased(x, y, button, istouch)
    if istouch then
        return
    end
    if forceTouchControls and button == 1 and forcedMouseTouch then
        forcedMouseTouch = false
        love.touchreleased(forcedMouseTouchId, x, y)
        return
    end

    x, y = x/VAR("scale"), y/VAR("scale")

    gameStateManager:event("mousereleased", x, y, button)
end

function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then
        return
    end
    if forceTouchControls and forcedMouseTouch then
        love.touchmoved(forcedMouseTouchId, x, y, dx, dy)
        return
    end

    TouchControls.clearPointer()
    dx, dy = dx/VAR("scale"), dy/VAR("scale")

    gameStateManager:event("mousemoved", dx, dy)
end

local function currentTouchMode()
    if Editor and gameStateManager:hasActiveState(Editor) then
        return "editor"
    end
    if Game and gameStateManager:hasActiveState(Game) then
        if not game.uiVisible then
            return "aim"
        end
        return "game"
    end
    return "menu"
end

local function markTouchInput(name)
    if not touchInputLogged[name] then
        touchInputLogged[name] = true
        print("MARI0_2_TOUCH_" .. name .. "_OK")
        if io.stdout then
            io.stdout:flush()
        end
    end
end

local function handleTouchCommand(command, button, phase, mode)
    if command == "start" and phase == "press" then
        if mode == "menu" then
            newGame(selectedMappackPath, false, 1)
            if gameStateManager:hasActiveState(Game) then
                markTouchInput("START")
            end
        else
            returnToMenu()
        end
    elseif button.mouseButton then
        local x, y = TouchControls.getPointer()
        if not x or not y then
            x, y = SCREENWIDTH / 2, SCREENHEIGHT / 2
        end
        if phase == "press" then
            markTouchInput(string.upper(command))
            gameStateManager:event("mousepressed", x, y, button.mouseButton)
        elseif phase == "release" then
            gameStateManager:event("mousereleased", x, y, button.mouseButton)
        end
    elseif phase == "press" and button.toggle == "run" then
        markTouchInput("RUNLOCK")
    elseif phase == "press" and button.virtual then
        if command == "jump" and controls3.cmdDown("jump") then
            markTouchInput("JUMP")
        elseif command ~= "jump" then
            markTouchInput(string.upper(command))
        end
        if button.emitOnPress then
            gameStateManager:event("cmdpressed", {[command] = true})
        end
    end
end

function love.touchpressed(id, x, y)
    local scale = VAR("scale")
    local mode = currentTouchMode()
    local logicalX, logicalY = x / scale, y / scale
    local onCommand = function(command, button, phase)
        handleTouchCommand(command, button, phase, mode)
    end
    local handled, button = TouchControls.press(id, logicalX, logicalY, SCREENWIDTH, SCREENHEIGHT, onCommand, mode)

    if handled then
        if button.command == "left" then
            markTouchInput("LEFT")
        end
        touchOwners[id] = "control"
        return
    end

    TouchControls.setPointer(logicalX, logicalY)
    if mode == "game" or mode == "aim" then
        touchOwners[id] = {kind = "aim", x = x, y = y}
        return
    end

    touchOwners[id] = {kind = "mouse", x = x, y = y}
    gameStateManager:event("mousepressed", logicalX, logicalY, 1)
end

function love.touchreleased(id, x, y)
    local owner = touchOwners[id]
    touchOwners[id] = nil

    if owner == "control" then
        TouchControls.release(id, function(command, button, phase)
            handleTouchCommand(command, button, phase, currentTouchMode())
        end)
    elseif owner then
        TouchControls.setPointer(x / VAR("scale"), y / VAR("scale"))
        if owner.kind == "mouse" then
            local scale = VAR("scale")
            gameStateManager:event("mousereleased", x / scale, y / scale, 1)
        end
    end
end

function love.touchmoved(id, x, y, dx, dy)
    local owner = touchOwners[id]
    if not owner then
        return
    end

    local scale = VAR("scale")
    local logicalX, logicalY = x / scale, y / scale
    local mode = currentTouchMode()
    local onCommand = function(command, button, phase)
        handleTouchCommand(command, button, phase, mode)
    end
    local handled = TouchControls.move(id, logicalX, logicalY, SCREENWIDTH, SCREENHEIGHT, onCommand, mode)

    if handled then
        touchOwners[id] = "control"
        return
    end

    if owner == "control" then
        return
    end

    TouchControls.setPointer(logicalX, logicalY)
    owner.x, owner.y = x, y
    if owner.kind == "mouse" then
        gameStateManager:event("mousemoved", dx / scale, dy / scale)
    end
end

function love.focus(focused)
    if not focused then
        forcedMouseTouch = false
        for id, owner in pairs(touchOwners) do
            if owner ~= "control" and owner.kind == "mouse" then
                love.mousereleased(owner.x, owner.y, 1)
            end
            touchOwners[id] = nil
        end
        TouchControls.reset(function(command, button, phase)
            handleTouchCommand(command, button, phase, currentTouchMode())
        end)
    end
end

function love.resize(w, h)
    if fitToScreen then
        local fitScale = math.min(w/400, h/224)
        if fitScale > 0 then
            setVAR("scale", fitScale)
        end
    end

    SCREENWIDTH = w/VAR("scale")
    SCREENHEIGHT = h/VAR("scale")

    updateSizes()

    print(string.format(
        "MARI0_VIDEO_SETTLED window=%dx%d scale=%.3f logical=%dx%d touchSupported=%s fitToScreen=%s",
        w, h, VAR("scale"), SCREENWIDTH, SCREENHEIGHT,
        tostring(TouchControls.isSupported()), tostring(fitToScreen)
    ))

    gameStateManager:event("resize", SCREENWIDTH, SCREENHEIGHT)
end

function love.quit()
    if PROF_CAPTURE then
        prof.write("lastrun.prof")
    end
end

function updateSizes()
    CAMERAWIDTH = SCREENWIDTH
    CAMERAHEIGHT = SCREENHEIGHT

    -- Remove the UI's height if present
    if (not game or game.uiVisible) and ui then
        CAMERAHEIGHT = CAMERAHEIGHT-ui.height
    end

    RIGHTSCROLLBORDER = VAR("cameraScrollRightBorder")
    LEFTSCROLLBORDER = VAR("cameraScrollLeftBorder")

    DOWNSCROLLBORDER = VAR("cameraScrollDownBorder")
    UPSCROLLBORDER = VAR("cameraScrollUpBorder")

    debugCandyQuad = love.graphics.newQuad(0, 0, SCREENWIDTH, SCREENHEIGHT, 8, 8)
end

function love.wheelmoved(x, y)
    gameStateManager:event("wheelmoved", x, y)
end

function updateGroup(group, dt)
	for i = #group, 1, -1 do
		if group[i]:update(dt) or group[i].deleteMe then
			table.remove(group, i)
		end
	end
end

function playMusic(music)
	if VAR("debug").musicDisabled then return end
    playSound(music, 1)
end

function playSound(sound, volume)
	volume = volume or 1

    if not sound then
        print("Sound not specified")
        return
    end
	
	if not sounds[sound] then
        print("Sound not found")
        return
	end

    sounds[sound]:stop()
	sounds[sound]:setVolume(volume)
    sounds[sound]:play()
end

function worldArrow(x, y, xDir, yDir)
    local scale = math.sqrt(xDir^2+yDir^2)/8
    local angle = math.atan2(yDir, xDir)
    local arrowTipScale = 0.2

    --body
    local x2, y2 = x+math.cos(angle)*scale, y+math.sin(angle)*scale

    love.graphics.line(x, y, x2, y2)

    --tipleft (m'lady)
    local x3 = x2+math.cos(angle-math.pi*0.75)*scale*arrowTipScale
    local y3 = y2+math.sin(angle-math.pi*0.75)*scale*arrowTipScale
    love.graphics.line(x2, y2, x3, y3)

    --tipright
    local x4 = x2+math.cos(angle+math.pi*0.75)*scale*arrowTipScale
    local y4 = y2+math.sin(angle+math.pi*0.75)*scale*arrowTipScale
    love.graphics.line(x2, y2, x4, y4)
end
