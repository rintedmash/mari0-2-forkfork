local Component = require "class.Component"
local goalcard = class("smb3.goalcard", Component)

-- Reports player contact to the Level, which runs the whole
-- goal sequence (see Level:updateGoalSequence).
function goalcard:rightContact(dt, actorEvent, obj2)
	self:resolve(obj2)
end

function goalcard:leftContact(dt, actorEvent, obj2)
	self:resolve(obj2)
end

function goalcard:topContact(dt, actorEvent, obj2)
	self:resolve(obj2)
end

function goalcard:bottomContact(dt, actorEvent, obj2)
	self:resolve(obj2)
end

function goalcard:resolve(obj2)
	if obj2.player then
		if io.stdout then io.stdout:flush() end
		self.actor.world:collectGoalCard()
	end
end

return goalcard
