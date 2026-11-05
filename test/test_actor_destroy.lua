local previousClass = class
local previousPhysics3 = Physics3
local previousActor = package.loaded["class.Actor"]
class = require "lib.middleclass"
Physics3 = {PhysObj = class("Physics3.PhysObj")}
package.loaded["class.Actor"] = nil
local Actor = require "class.Actor"
package.loaded["class.Actor"] = previousActor
class = previousClass
Physics3 = previousPhysics3

function test_actor_destroy_runs_cleanup_once()
    local eventCalls, removeCalls = 0, 0
    local actor
    actor = setmetatable({
        components = {},
        world = {removeObject = function(_, object)
            lunatest.assert_equal(actor, object)
            removeCalls = removeCalls + 1
        end},
        event = function(_, name)
            lunatest.assert_equal("destroy", name)
            eventCalls = eventCalls + 1
        end,
    }, {__index = Actor})

    actor:destroy()
    actor:destroy()

    lunatest.assert_true(actor.destroyed)
    lunatest.assert_true(actor.deleteMe)
    lunatest.assert_equal(1, eventCalls)
    lunatest.assert_equal(1, removeCalls)
end
