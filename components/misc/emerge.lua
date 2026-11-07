local Component = require "class.Component"
local emerge = class("misc.emerge", Component)

-- Rises an item out of a block after the block finishes bouncing, like
-- SMB3/SMB1 item blocks. While rising the actor is static, inert (no other
-- component receives events) and drawn behind the tiles, like the original.
emerge.argList = {
	{ "rise", "number", 16 },
	{ "time", "number", 0.5 },
}

function emerge:initialize(actor, args)
	Component.initialize(self, actor, args)

	self.startY = actor.y
	self.t = 0

	actor.static = true
	actor.speed[1] = 0
	actor.speed[2] = 0

	-- Inert + drawn behind the block until fully emerged
	actor.emerging = true
	actor.eventBlocker = self
end

function emerge:update(dt)
	self.t = self.t + dt

	if self.t < self.time then
		self.actor.y = self.startY - self.rise * (self.t / self.time)
	else
		self.actor.y = self.startY - self.rise
		self.actor.static = false
		self.actor.emerging = false
		self.actor.eventBlocker = nil
		self.actor:removeComponent("misc.emerge")
	end
end

return emerge
