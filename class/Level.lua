local Actor = require("class.Actor")
local Level = class("Level", Physics3.World)
local BlockBounce = require("class.BlockBounce")
local Viewport = require("class.Viewport")
local GoalCards = require("lib.goalcards")
-- The roulette and status-bar panel use the actual powerup sprites as the
-- card faces (mushroom / fire flower / star), like the SMB3 goal panel
local goalCardImages = {
	love.graphics.newImage("img/actors/mushroom.png"),
	love.graphics.newImage("img/actors/fire_flower.png"),
	love.graphics.newImage("img/actors/starman.png"),
}
local goalCardQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
-- Constant exit-run speed after grabbing the goal card (SMB3 walks off
-- at walk speed while the legs animate faster)
local GOAL_RUNSPEED = 90

function Level:initialize(path, players)
    self.players = players or (game and game.players) or {}
	self.path = path
    
    local mapCode = love.filesystem.read(path)
    local data = sandbox.run(mapCode)
	self.currentLevel = data

    -- Init before loadLevel: the initial spawn pass may attach the goal
    -- sequence and queue sprouts while the level loads
    self.pendingSprouts = {}
    self.pendingGoalSequence = nil
    self.goalSequence = nil

    self:loadLevel(data)

    self.timeLeft = 400

    -- SMB3-style level entry: the level fades in from black while the
    -- player stands still (Palette_PrepareFadeIn / Palette_DoFadeIn, 4
    -- discrete palette steps, 5 frames each)
    self.entryFade = nil

    self:mappackFeatureSetup()
end

-- Read mappack-level feature flags and set up SMB3-style sequences
function Level:mappackFeatureSetup()
    local settings = game and game.mappack and game.mappack.settings
    if not settings then
        return
    end

    -- Entry fade-in: fade the level in from black while the player stands
    -- still. Skipped when arriving through a warp exit (the pipe-exit
    -- animation plays instead, like LevelInit_PipeExit*).
    if settings.entryFade ~= false and #self.players > 0
        and not self.players[1].exitEntry then
        self.entryFade = { level = 4, tick = 0 }
        controls3.locked = true
    end

end

function Level:mergeGoalCardEntities()
	-- The goal_block marker (the "level clear" object) IS the item roulette:
	-- retyping the first marker entity into a goal_card makes the normal
	-- spawn pipeline place the card right where the block was, so there is
	-- a single object instead of a decoration block plus a floating card.
	for _, entity in ipairs(self.currentLevel.entities or {}) do
		if entity.type == "goal_block" then
			local entityComponents = entity.components or {}
			local warpArgs = entityComponents["actReact.tag.warp"]

			-- The card is the exit now; drop the old warp behaviour
			entityComponents["actReact.tag.warp"] = nil
			entity.components = entityComponents

			if not self.pendingGoalSequence then
				entity.type = "goal_card"
				self.pendingGoalSequence = {exit = warpArgs or nil}
			end
		end
	end
end

-- Called from spawnActors when the merged goal_card actor appears
function Level:attachGoalSequence(card)
	self.goalSequence = {
		state = "roulette",
		card = card,
		minX = card.x - 24,
		maxX = card.x + 24,
		spinTimer = 0,
		spinSpeed = 0.08,
		speed = 86,
		face = 1,
		direction = 1,
		exit = self.pendingGoalSequence and self.pendingGoalSequence.exit or nil,
		timer = 0,
	}
	card.img = goalCardImages[1]
	card.quad = goalCardQuad
	card.goalSequence = self.goalSequence
end

function Level:loadLevel(data)
    self.data = data
	self.currentLevel = data

    Physics3.World.initialize(self)
    Physics3.World.loadLevel(self, self.data)

    self.backgroundColor = {
        (self.data.backgroundColor and self.data.backgroundColor[1] or 181)/255,
        (self.data.backgroundColor and self.data.backgroundColor[2] or 235)/255,
        (self.data.backgroundColor and self.data.backgroundColor[3] or 242)/255
    }

    love.graphics.setBackgroundColor(self.backgroundColor)
	self.levelCode = self.data.levelCode or ""
	self.background = self.data.background or nil
	self.wrapX = self.data.wrapX or false	
	self.wrapY = self.data.wrapY or false	
	self.music = self.data.music or nil
	love.audio.stop()
	playMusic(self.music)
	love.mouse.setCursor(love.mouse.getSystemCursor("arrow"))

    self.spawnLine = 0
    self.spawnI = 1

    self.portalProjectiles = {} -- Portal projectiles, duh.

    self.spawnList = {}
	self.exitList = {}
	self.entitiesInBlocks = {}

    -- The goal marker becomes the card itself: retype goal_block entities
    -- into goal_card before the spawn list is built, so the bouncing
    -- roulette IS the level-clear object (SMB3's EndLevelCard)
    self:mergeGoalCardEntities()

    -- Parse entities
    for _, entity in ipairs(self.data.entities) do
        local actorTemplate = actorTemplates[entity.type]

        if entity.type == "spawn" then
            self.spawnX = entity.x
            self.spawnY = entity.y
		elseif entity.type == "pipe_exit" then
			if entity.exitId then
				self.exitList[entity.exitId] = entity
			end
        elseif actorTemplate and not VAR("debug").noEnemies then -- is entity
            -- Extract custom properties
            local customProperties = {}
            for propertyKey, propertyValue in pairs(entity) do
                if propertyKey ~= "type" and propertyKey ~= "x" and propertyKey ~= "y" then
                    customProperties[propertyKey] = propertyValue
                end
            end
            
			local spawnOffsetX = actorTemplate.spawnOffsetX or 0
			local spawnOffsetY = actorTemplate.spawnOffsetY or 0

			local tileOverlap = self:getTile(entity.x, entity.y)
			
			if tileOverlap and (tileOverlap.props.holdsItems or tileOverlap.props.breakable) then
				self.entitiesInBlocks[entity.x] = self.entitiesInBlocks[entity.x] or {}
				self.entitiesInBlocks[entity.x][entity.y] = entity.type
			else
				table.insert(self.spawnList, {
					actorTemplate = actorTemplate,
					x = entity.x + spawnOffsetX,
					y = entity.y + spawnOffsetY,
					customProperties = customProperties,
				})
			end
        end
    end

    table.sort(self.spawnList, function(a, b) return a.x<b.x end)

    self.actors = {}
	
	if not self.spawnX or not self.spawnY then
		self.spawnX = 2
		self.spawnY = 12
	end
	
    local x, y = self:coordinateToWorld(self.spawnX-.5, self.spawnY)

    for i = 1, #self.players do
        local player = self.players[i]
		local mario
		
		player.exitEntry = player.exitId and self.exitList[player.exitId] and true or false

		if player.exitId and self.exitList[player.exitId] then
			local exitX, exitY = self:coordinateToWorld(self.exitList[player.exitId].x, self.exitList[player.exitId].y)
			mario = Actor:new(self, exitX, exitY, actorTemplates["smb3_" .. player.powerUp])
		else
			mario = Actor:new(self, x, y, actorTemplates["smb3_" .. player.powerUp])
		end
		player.exitId = 0

        mario.player = player
        player.actor = mario
		mario:event("playerAssigned")

        -- apply settings like character palette and portal colors
        if player.palette then
            mario.palette = player.palette
        end

        table.insert(self.actors, mario)
    end

    self.viewports = {}
    if #self.players > 0 then
        table.insert(self.viewports, Viewport:new(self, 0, 0, CAMERAWIDTH, CAMERAHEIGHT, self.players[1].actor))
    else
        table.insert(self.viewports, Viewport:new(self, 0, 0, CAMERAWIDTH, CAMERAHEIGHT, nil))
    end

    self.camera = self.viewports[1].camera

    self:spawnActors(self.viewports[1].camera.x/self.tileSize+self.camera.w/16+VAR("enemiesSpawnAhead"))
end

function Level:updatePendingSprouts(dt)
	for i = #self.pendingSprouts, 1, -1 do
		local sprout = self.pendingSprouts[i]
		sprout.timer = sprout.timer - dt

		if sprout.timer <= 0 then
			table.remove(self.pendingSprouts, i)

			if self.destroyed then
				return
			end

			local template = actorTemplates[sprout.template]
			if template then
				local item = Actor:new(self, sprout.x, sprout.y, template)
				item:addComponent(components["misc.emerge"], {rise = sprout.rise})
				table.insert(self.actors, item)
			end
		end
	end
end
function Level:update(dt)
    self.timeLeft = math.max(0, self.timeLeft-(60/42)*dt) -- that's 42.86% more second, per second!

    self:updatePendingSprouts(dt)
    self:updateEntryFade(dt)
    self:updateGoalSequence(dt)

    prof.push("Portal Projectiles")
    updateGroup(self.portalProjectiles, dt)
    prof.pop()

    prof.push("Actor Cleanup")
    for i = #self.actors, 1, -1 do
		if self.actors[i].y > self:getYEnd()*self.tileSize+.5 then
			self.actors[i]:destroy()
		end
        if self.actors[i].destroyed or self.actors[i].deleteMe then
            table.remove(self.actors, i)
        end
    end
    prof.pop()
    
    prof.push("World")
    Physics3.World.update(self, dt)
    prof.pop()

    updateGroup(self.viewports, dt)

    prof.push("Post Update")
    for _, obj in ipairs(self.objects) do
        if obj.postUpdate then
            obj:postUpdate(dt)
        end
    end
    prof.pop()

	--Level boundary/border wrap-around
    if #self.players > 0 and self.players[1].actor.y > self:getYEnd()*self.tileSize+.5 then
		if self.wrapY then
			self.players[1].actor.y = -1
		else
			self.players[1].actor:event("getKilled")
			self.players[1].actor:event("getHurt")
		end
    end
	
    if self.wrapX and #self.players > 0 then
		if self.players[1].actor.x > self:getXEnd()*self.tileSize - 8 then
			self.players[1].actor.x = -8
		elseif self.players[1].actor.x < -8 then
			self.players[1].actor.x = self:getXEnd()*self.tileSize - 8
		end
    end

    local newSpawnLine = self.camera.x/self.tileSize+self.camera.w/16+VAR("enemiesSpawnAhead")
    if newSpawnLine > self.spawnLine then
        self:spawnActors(newSpawnLine)
    end
end

-- The card itself just reports contact; all sequencing lives here.
function Level:collectGoalCard()
    local seq = self.goalSequence
    if not seq or seq.state ~= "roulette" then
        return
    end
    seq.state = "collected"
    seq.timer = 0
    seq.stoppedFace = seq.face

    -- The card freezes in place (it was bouncing on a real velocity)
    seq.card.speed[1] = 0
    seq.card.speed[2] = 0

    -- Add the stopped card to the status-bar panel, like Player_GetCard
    game.cardPanel = game.cardPanel or GoalCards.newPanel()
    seq.panelSlot = GoalCards.addCard(game.cardPanel, GoalCards.TYPES[seq.face])

    -- The time counts down into score while the banners run, like DoTimeBonus
    self.timeBonusScore = math.floor(self.timeLeft) * 50
    self.timeLeft = 0

    playSound("level_clear")
    playMusic(nil)

    for _, viewport in ipairs(self.viewports) do
        viewport.frozen = true
    end

    controls3.locked = true
    controls3.clearForced()

    self.players[1].score = self.players[1].score + self.timeBonusScore

    -- SMB3: Mario's velocity cancels out on the spot; he falls onto the
    -- floor and then runs off to the right (handled in the update below)
    local player = self.players[1].actor
    if player then
        player.speed[1] = 0
        player.speed[2] = 0
        player.runAnimationBoost = 2
    end

    seq.courseClearShown = true
    seq.bannerTime = 0
end

function Level:updateGoalSequence(dt)
    local seq = self.goalSequence
    if not seq then
        return
    end

    seq.timer = seq.timer + dt

    if seq.state == "roulette" then
        -- Bounce the card between its bounds. Move it through speed[] (not
        -- direct x mutation) so the physics sweep generates contact events
        -- when the bouncing card reaches a standing player, like the original
        local card = seq.card
        card.speed[1] = seq.direction*seq.speed
        if card.x < seq.minX then
            card.x = seq.minX
            seq.direction = 1
        elseif card.x > seq.maxX then
            card.x = seq.maxX
            seq.direction = -1
        end

        -- Cycle the card face, like EndLevelCard_SetFrameToCard
        seq.spinTimer = seq.spinTimer + dt
        while seq.spinTimer >= seq.spinSpeed do
            seq.spinTimer = seq.spinTimer - seq.spinSpeed
            seq.face = GoalCards.nextFace(seq.face)
            card.img = goalCardImages[seq.face]
            card.quad = goalCardQuad
        end
    elseif seq.state == "collected" then
        -- Run off to the right at a constant speed (the faster feet are the
        -- runAnimationBoost set on collect, like SMB3's exit walk)
        local player = self.players[1].actor
        if player then
            if player.onGround then
                player.speed[1] = GOAL_RUNSPEED
            else
                player.speed[1] = 0
            end
        end

        -- "COURSE CLEAR !" shows first; "YOU GOT A CARD" appears later
        seq.bannerTime = seq.bannerTime + dt

        if seq.bannerTime >= 2.2 and not seq.gotCardShown then
            seq.gotCardShown = true
        elseif seq.gotCardShown and seq.bannerTime >= 2 and not seq.award then
            seq.award = GoalCards.evaluate(game.cardPanel)
            seq.bannerTime = 0

            if seq.award > 0 then
                seq.bannerText = seq.award == 1 and "1 LIFE!" or (seq.award .. " LIVES!")
                self.players[1].lives = self.players[1].lives + seq.award
                playSound("one_up")
            end
        elseif seq.award ~= nil and seq.bannerTime >= 1.5 then
            self:finishGoalSequence()
        end
    end
end

function Level:finishGoalSequence()
    local seq = self.goalSequence
    controls3.locked = false
    controls3.clearForced()

    for _, viewport in ipairs(self.viewports) do
        viewport.frozen = false
    end

    seq.card:destroy()
    self.goalSequence = nil

    local exit = seq.exit
    if exit and exit.level then
        game:changeLevel(exit.level)
    else
        game:changeLevel(nil)
    end
end

function Level:updateEntryFade(dt)
    local fade = self.entryFade
    if not fade then
        return
    end

    -- Palette_DoFadeIn: Fade_Tick reloads to 4 and Fade_Level decrements
    -- every 5 frames; at Fade_Level 0 the fade ends and control unlocks
    fade.tick = fade.tick + dt*60
    while fade.tick >= 5 and fade.level > 0 do
        fade.tick = fade.tick - 5
        fade.level = fade.level - 1
    end

    if fade.level <= 0 then
        self.entryFade = nil
        controls3.locked = false
    end
end

function Level:draw()
    for _, viewport in ipairs(self.viewports) do
        viewport.camera:attach()

        Physics3.World.draw(self)

        viewport.camera:detach()
    end

    -- Entry fade-in: 4 discrete black overlay steps, like the NES palette fade
    if self.entryFade then
        love.graphics.setColor(0, 0, 0, self.entryFade.level/4)
        love.graphics.rectangle("fill", 0, 0, SCREENWIDTH, SCREENHEIGHT)
        love.graphics.setColor(1, 1, 1)
    end

    -- Goal sequence banners: "COURSE CLEAR !" up top first, "YOU GOT A CARD"
    -- (with the won card in its box) underneath when it appears, like the
    -- SMB3 course clear screen
    if self.goalSequence and self.goalSequence.courseClearShown then
        local seq = self.goalSequence

        love.graphics.setFont(fontOutlined)
        love.graphics.setColor(1, 1, 1)

        self:printCenteredBanner("COURSE CLEAR !", 32)

        if seq.gotCardShown then
            local text = seq.award and seq.award > 0
                and (seq.award == 1 and "YOU GOT 1 LIFE!" or ("YOU GOT " .. seq.award .. " LIVES!"))
                or "YOU GOT A CARD"
            local tx = self:printCenteredBanner(text, 56)

            if not seq.award or seq.award == 0 then
                -- The won card in its box, like the SMB3 card display
                local cardImg = goalCardImages[seq.stoppedFace or 1]
                local bx = math.floor((SCREENWIDTH + fontOutlined:getWidth(text))/2) + 8
                love.graphics.rectangle("fill", bx, 52, 20, 20)
                love.graphics.draw(cardImg, goalCardQuad, bx+2, 54)
            end
        end
    end
end

function Level:printCenteredBanner(text, y)
    local x = math.floor((SCREENWIDTH - fontOutlined:getWidth(text))/2)
    love.graphics.print(text, x, y)
    return x + fontOutlined:getWidth(text)
end

function Level:drawBehindObjects()
    for _, portalProjectile in ipairs(self.portalProjectiles) do
        portalProjectile:draw()
    end
end

function Level:cmdpressed(cmds)
    if #self.players == 0 then return end
    
    if cmds["jump"] then
        self.players[1].actor:event("jump")
    end

    if cmds["run"] then
        self.players[1].actor:event("action")
    end

    if cmds["closePortals"] then
        self.players[1].actor:event("closePortals")
    end
	
    if cmds["use"] then
        self.players[1].actor:event("use")
    end

    if cmds["debug.star"] then -- debug
        self.players[1].actor:event("getStar")
    end
end

function Level:mousepressed(x, y, button)
    for _, obj in ipairs(self.objects) do
        obj:event("click", 0, button)
    end
end

function Level:spawnActors(untilX)
    while self.spawnI <= #self.spawnList and untilX > self.spawnList[self.spawnI].x do -- Spawn next enemy
        toSpawn = self.spawnList[self.spawnI]
        local x, y = self:coordinateToWorld(toSpawn.x-.5, toSpawn.y)
        local actor = Actor:new(self, x, y, toSpawn.actorTemplate, toSpawn.customProperties)

        table.insert(self.actors, actor)

        -- The merged goal card carries the whole clear sequence
        if toSpawn.actorTemplate == actorTemplates["goal_card"]
            and not self.goalSequence and self.pendingGoalSequence then
            self:attachGoalSequence(actor)
        end

        self.spawnI = self.spawnI + 1

        -- Update untilX so enemies spawn in groups
        --untilX = untilX + 2
    end

    self.spawnLine = untilX
end

function Level:bumpBlock(cell, actor, dontBreak)
    local tile = cell.tile

    if tile.props.breakable or tile.props.holdsItems or tile.props.noteblock then
		-- Collect coins above
		if cell.layer.map[cell.x][cell.y - 1].tile then
			if cell.layer.map[cell.x][cell.y - 1].tile.props.coin then
				self:collectCoin(actor, cell.layer, cell.x, cell.y - 1)
			end
		end

        -- Check what's inside
        local item = tile.props.defaultItem
		local entityInBlock = false
		if self.entitiesInBlocks[cell.x] and self.entitiesInBlocks[cell.x][cell.y] then
			item = self.entitiesInBlocks[cell.x][cell.y]
			entityInBlock = true
		end
		
		if item then
			-- Give the item
			if item == "coin" then
				self:collectCoin(actor)
			else
				-- The item rises out of the block once the block is done
				-- bouncing, like in SMB3 (until then it stays hidden inside)
				table.insert(self.pendingSprouts, {
					timer = VAR("blockBounceTime"),
					x = cell.x*16+8,
					y = cell.y*16 + 16,
					rise = 16,
					template = item,
				})
				playSound("mushroom_appear")
			end
			-- Turn it into another tile
			if tile.props.turnsInto then
				local turnIntoTile = tile.tileMap.tiles[tile.props.turnsInto]

				cell.layer:setCoordinate(cell.x, cell.y, turnIntoTile)
			end
			if entityInBlock then
				self.entitiesInBlocks[cell.x][cell.y] = nil
			end
		else
			-- Break it
			if tile.props.breakable and not dontBreak then
				cell.layer:setCoordinate(cell.x, cell.y, nil)
				cell.layer.map[cell.x][cell.y].tile = nil
				playSound("block_break")
				return
			else
				playSound("block")
			end
		end

        -- Make it bounce
        cell.layer:bounceCell(cell.x, cell.y)
	else
		playSound("block")
    end
end

function Level:bounceOnBlock(cell, actor)
    local tile = cell.tile
	if tile.props.noteblock then
		-- Make it bounce
		cell.layer:bounceCell(cell.x, cell.y, "down")

		-- Turn it into another tile
        if tile.props.turnsInto then
            local turnIntoTile = tile.tileMap.tiles[tile.props.turnsInto]

            cell.layer:setCoordinate(cell.x, cell.y, turnIntoTile)
        end
		
        -- Check what's inside
        local item = tile.props.defaultItem
        if item == "coin" then
            self:collectCoin(actor)
		elseif item then
			-- Noteblocks push the item out below, once the bounce is done
			table.insert(self.pendingSprouts, {
				timer = VAR("blockBounceTime"),
				x = cell.x*16+8,
				y = cell.y*16 + 16,
				rise = -16,
				template = item,
			})
			playSound("mushroom_appear")
        end
	end
end

function Level:collectCoin(actor, layer, x, y)
    if layer then
		layer:setCoordinate(x, y, nil)
        layer.map[x][y].tile = nil
    end
	playSound("coin")
    actor.player.coins = actor.player.coins + 1
end

function Level:objVisible(x, y, w, h)
    local lx, ty = self.camera:worldCoords(0, 0)
    local rx, by = self.camera:worldCoords(self.camera.w, self.camera.h)

    return x+w > lx and x < rx and
        y+h > ty and y < by
end

function Level:resize(w, h)
    self.camera.w = w
    self.camera.h = CAMERAHEIGHT
end

return Level
