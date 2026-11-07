return {
	width = 16,
	height = 16,

	img = "img/goal/cards.png",
	quadWidth = 16,
	quadHeight = 16,
	centerX = 8,
	centerY = 8,

	dontShowOnEditor = true,

	-- Floats in place; senses the player by AABB overlap (contact events
	-- only fire for objects with a nonzero collisionMask)
	gravity = 0,
	collisionGroup = VAR("collisionCategories").POWER_UP,
	collisionMask = VAR("collisionCategories").ALWAYS_COLLIDE
		+ VAR("collisionCategories").PLAYER,

	components = {
		["smb3.goalcard"] = {},
	},
}
