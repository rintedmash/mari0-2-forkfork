return {
	width = 16,
	height = 16,

	-- The template image is only a placeholder; the Level swaps in the real
	-- powerup sprites per face
	img = "img/actors/mushroom.png",
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
