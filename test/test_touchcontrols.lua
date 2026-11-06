local controls3 = require "lib.controls3"
local TouchControls = require "lib.TouchControls"

local function findButton(command, width, height, mode)
    for _, button in ipairs(TouchControls.getButtons(width, height, mode)) do
        if button.command == command then
            return button
        end
    end
end

local function center(button)
    return button.x + button.width / 2, button.y + button.height / 2
end

function test_ge_control_layout_and_touch_zones()
    local buttons = TouchControls.getButtons(400, 224, "game")
    local expected = {"start", "portal1", "portal2", "closePortals", "left", "right", "up", "down", "use", "runlock", "run", "jump"}

    for _, command in ipairs(expected) do
        lunatest.assert_true(findButton(command, 400, 224, "game"), command .. " control is missing")
    end

    lunatest.assert_equal(11, findButton("left", 400, 224).x)
    lunatest.assert_equal(159, findButton("jump", 400, 224).y)
    lunatest.assert_equal("start", findButton("start", 400, 224, "menu").command)
    lunatest.assert_equal(1, findButton("portal1", 400, 224).mouseButton)
    lunatest.assert_equal(2, findButton("portal2", 400, 224).mouseButton)
end

function test_virtual_hold_stays_active_until_last_finger_releases()
    TouchControls.reset()
    local button = findButton("left", 400, 224)
    local x, y = center(button)

    TouchControls.press("finger-1", x, y, 400, 224)
    TouchControls.press("finger-2", x, y, 400, 224)
    lunatest.assert_true(controls3.cmdDown("left"))

    TouchControls.release("finger-1")
    lunatest.assert_true(controls3.cmdDown("left"))

    TouchControls.release("finger-2")
    lunatest.assert_false(controls3.cmdDown("left"))
end

function test_slide_releases_old_direction_and_holds_new_direction()
    TouchControls.reset()
    local left = findButton("left", 400, 224)
    local right = findButton("right", 400, 224)
    local lx, ly = center(left)
    local rx, ry = center(right)

    TouchControls.press("finger-1", lx, ly, 400, 224)
    TouchControls.move("finger-1", rx, ry, 400, 224)
    lunatest.assert_false(controls3.cmdDown("left"))
    lunatest.assert_true(controls3.cmdDown("right"))

    TouchControls.release("finger-1")
    lunatest.assert_false(controls3.cmdDown("right"))
end

function test_jump_is_emitted_once_for_duplicate_fingers()
    TouchControls.reset()
    local button = findButton("jump", 400, 224)
    local x, y = center(button)
    local pressed = 0
    local function onCommand(command, _, phase)
        if command == "jump" and phase == "press" then
            pressed = pressed + 1
        end
    end

    TouchControls.press("finger-1", x, y, 400, 224, onCommand)
    TouchControls.press("finger-2", x, y, 400, 224, onCommand)
    lunatest.assert_equal(1, pressed)

    TouchControls.release("finger-1", onCommand)
    lunatest.assert_true(controls3.cmdDown("jump"))
    TouchControls.release("finger-2", onCommand)
    lunatest.assert_false(controls3.cmdDown("jump"))
end

function test_run_lock_toggles_and_reset_clears_it()
    TouchControls.reset()
    local button = findButton("runlock", 400, 224)
    local x, y = center(button)

    TouchControls.press("finger-1", x, y, 400, 224)
    TouchControls.release("finger-1")
    lunatest.assert_true(controls3.cmdDown("run"))

    TouchControls.press("finger-2", x, y, 400, 224)
    TouchControls.release("finger-2")
    lunatest.assert_false(controls3.cmdDown("run"))

    TouchControls.press("finger-3", x, y, 400, 224)
    TouchControls.reset()
    lunatest.assert_false(controls3.cmdDown("run"))
end

function test_portal_controls_press_and_release_mouse_buttons()
    TouchControls.reset()
    local button = findButton("portal1", 400, 224)
    local x, y = center(button)
    local phases = {}
    local function onCommand(command, _, phase)
        phases[#phases + 1] = command .. ":" .. phase
    end

    TouchControls.press("finger-1", x, y, 400, 224, onCommand)
    TouchControls.release("finger-1", onCommand)
    lunatest.assert_equal("portal1:press", phases[1])
    lunatest.assert_equal("portal1:release", phases[2])
end

function test_start_button_emits_in_menu_and_game_modes()
    for _, mode in ipairs({"menu", "game"}) do
        local button = findButton("start", 400, 224, mode)
        local x, y = center(button)
        local command

        TouchControls.press("finger-1", x, y, 400, 224, function(name, _, phase)
            if phase == "press" then
                command = name
            end
        end, mode)

        lunatest.assert_equal("start", command)
        TouchControls.release("finger-1")
    end
end

function test_pointer_round_trip()
    TouchControls.setPointer(123, 45)
    local x, y = TouchControls.getPointer()
    lunatest.assert_equal(123, x)
    lunatest.assert_equal(45, y)
end

function test_touches_outside_controls_are_not_captured()
    TouchControls.reset()
    lunatest.assert_false(TouchControls.press("finger-1", 200, 112, 400, 224))
    lunatest.assert_false(TouchControls.release("finger-1"))
end
