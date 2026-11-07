-- Goal card roulette + panel logic, ported from the SMB3 disassembly
-- (EndLevelCard_* / Player_GetCard / DoTimeBonus in captainsouthbird/smb3).

local GoalCards = {}

GoalCards.TYPES = {"mushroom", "flower", "star"}
GoalCards.MAX_CARDS = 3

-- Lives awarded by EndLevelCard_xUpByMatch, indexed by the card type of a
-- triple match (mushroom, flower, star) plus the no-match fallback:
-- mushroom x3 = 2 lives, flower x3 = 3 lives, star x3 = 5 lives,
-- any other third-card combo = 1 life.
GoalCards.TRIPLE_LIVES = {2, 3, 5}
GoalCards.NO_MATCH_LIVES = 1

function GoalCards.typeIndex(type)
	for i, t in ipairs(GoalCards.TYPES) do
		if t == type then
			return i
		end
	end
	return nil
end

function GoalCards.newPanel()
	local panel = {
		cards = {},
		matches = 0,
		award = 0,
	}
	return panel
end

-- Advance a spinning card index by one face (mushroom -> flower -> star).
function GoalCards.nextFace(index)
	return (index % #GoalCards.TYPES) + 1
end

-- The newest card goes into the leftmost free slot, like the status bar.
-- Returns the slot index (1-3), or nil when the panel is full.
function GoalCards.addCard(panel, cardType)
	if #panel.cards >= GoalCards.MAX_CARDS then
		return nil
	end
	if not GoalCards.typeIndex(cardType) then
		return nil
	end

	table.insert(panel.cards, cardType)
	return #panel.cards
end

-- EndLevelCard_xUpByMatch is evaluated when the panel reaches three cards:
-- a triple match awards lives by the tripled card's type; any other third
-- card awards 1 life. The panel clears afterwards, like EndLevelCard_Exit.
-- Returns the number of lives awarded (0 before the third card).
function GoalCards.evaluate(panel)
	if #panel.cards < GoalCards.MAX_CARDS then
		panel.award = 0
		return 0
	end

	local counts = {mushroom = 0, flower = 0, star = 0}
	for _, cardType in ipairs(panel.cards) do
		counts[cardType] = counts[cardType] + 1
	end

	local lives = GoalCards.NO_MATCH_LIVES
	for typeIndex, count in ipairs(GoalCards.TYPES) do
		count = counts[count]
		if count >= GoalCards.MAX_CARDS then
			lives = GoalCards.TRIPLE_LIVES[typeIndex]
			break
		end
	end

	panel.cards = {}
	panel.award = lives
	panel.matches = panel.matches + 1
	return lives
end

-- DoTimeBonus: remaining time converts into points (50 points per unit,
-- matching the SMB3 scoring).
function GoalCards.timeBonus(timeLeft)
	return math.max(0, math.floor(timeLeft or 0))
end

return GoalCards
