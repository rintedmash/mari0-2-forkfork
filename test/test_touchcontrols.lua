local controls3 = require "lib.controls3"
local TouchControls = require "lib.TouchControls"

local function getButton(command)
    for _, button in ipairs(TouchControls.getButtons(400, 224)) do
        if button.command == command then
            return button
        end
    end
end

function test_touch_button_holds_and_releases_virtual_command()
    TouchControls.reset()
    local button = getButton("left")
    local pressed = {}

    lunatest.assert_true(TouchControls.press("finger-1", button.x, button.y, 400, 224, function(command)
        table.insert(pressed, command)
    end))
    lunatest.assert_true(controls3.cmdDown("left"))
    lunatest.assert_equal("left", pressed[1])
    lunatest.assert_true(TouchControls.release("finger-1"))
    lunatest.assert_false(controls3.cmdDown("left"))
end

function test_multiple_touches_keep_command_held_until_last_release()
    TouchControls.reset()
    local button = getButton("jump")
    local pressed = 0
    local function onCommand()
        pressed = pressed + 1
    end

    TouchControls.press("finger-1", button.x, button.y, 400, 224, onCommand)
    TouchControls.press("finger-2", button.x, button.y, 400, 224, onCommand)
    lunatest.assert_equal(1, pressed)
    TouchControls.release("finger-1")
    lunatest.assert_true(controls3.cmdDown("jump"))
    TouchControls.release("finger-2")
    lunatest.assert_false(controls3.cmdDown("jump"))
end

function test_touches_outside_controls_are_not_captured()
    TouchControls.reset()
    lunatest.assert_false(TouchControls.press("finger-1", 0, 0, 400, 224))
    lunatest.assert_false(TouchControls.release("finger-1"))
end
