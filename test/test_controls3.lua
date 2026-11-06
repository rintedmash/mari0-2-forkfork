local controls3 = require "lib.controls3"

function test_modifier_keys_are_passed_as_love_key_arguments()
    local originalLove = rawget(_G, "love")
    local calls = {}
    _G.love = {
        keyboard = {
            isDown = function(...)
                local keys = {...}
                for _, key in ipairs(keys) do
                    if type(key) ~= "string" then
                        error("keyboard.isDown expects key names, not a table")
                    end
                end
                calls[#calls + 1] = keys
                return keys[1] == "lshift"
            end,
        },
    }

    controls3.setCmdTable({["+w"] = "jump"})
    local ok, commands, hasCommands = pcall(controls3.getCmdsForKey, "w")
    _G.love = originalLove

    lunatest.assert_true(ok, tostring(commands))
    lunatest.assert_true(hasCommands)
    lunatest.assert_true(commands.jump)
    lunatest.assert_equal(3, #calls)
    lunatest.assert_equal("lshift", calls[1][1])
    lunatest.assert_equal("rshift", calls[1][2])
end
