local lunatest = require "test.lunatest"
local GoalCards = require "lib.goalcards"

function test_next_face_cycles()
    lunatest.assert_equal(2, GoalCards.nextFace(1))
    lunatest.assert_equal(3, GoalCards.nextFace(2))
    lunatest.assert_equal(1, GoalCards.nextFace(3))
end

function test_add_card_fills_slots()
    local panel = GoalCards.newPanel()
    lunatest.assert_equal(1, GoalCards.addCard(panel, "mushroom"))
    lunatest.assert_equal(2, GoalCards.addCard(panel, "star"))
    lunatest.assert_equal(3, GoalCards.addCard(panel, "flower"))
    lunatest.assert_equal(nil, GoalCards.addCard(panel, "mushroom"))
end

function test_rejects_invalid_type()
    local panel = GoalCards.newPanel()
    lunatest.assert_equal(nil, GoalCards.addCard(panel, "goomba"))
end

function test_triple_match_lives_by_type()
    -- xUpByMatch: mushroom x3 = 2, flower x3 = 3, star x3 = 5
    for i, cardType in ipairs({"mushroom", "flower", "star"}) do
        local panel = GoalCards.newPanel()
        for _ = 1, 3 do
            GoalCards.addCard(panel, cardType)
        end
        lunatest.assert_equal(GoalCards.TRIPLE_LIVES[i], GoalCards.evaluate(panel))
        lunatest.assert_equal(0, #panel.cards)
    end
end

function test_partial_panel_never_awards()
    local panel = GoalCards.newPanel()
    GoalCards.addCard(panel, "mushroom")
    GoalCards.addCard(panel, "mushroom")
    lunatest.assert_equal(0, GoalCards.evaluate(panel))
    lunatest.assert_equal(2, #panel.cards)
end

function test_non_matching_third_card_awards_one()
    -- Var5 = 4 in the decomp: third card without a triple = 1 life
    local panel = GoalCards.newPanel()
    GoalCards.addCard(panel, "mushroom")
    GoalCards.addCard(panel, "flower")
    GoalCards.addCard(panel, "mushroom")
    lunatest.assert_equal(1, GoalCards.evaluate(panel))
    lunatest.assert_equal(0, #panel.cards)
end

function test_all_different_full_panel_awards_one()
    local panel = GoalCards.newPanel()
    GoalCards.addCard(panel, "mushroom")
    GoalCards.addCard(panel, "flower")
    GoalCards.addCard(panel, "star")
    lunatest.assert_equal(1, GoalCards.evaluate(panel))
    lunatest.assert_equal(0, #panel.cards)
end

function test_no_award_with_single_card()
    local panel = GoalCards.newPanel()
    GoalCards.addCard(panel, "mushroom")
    GoalCards.addCard(panel, "mushroom")
    lunatest.assert_equal(0, GoalCards.evaluate(panel))
    lunatest.assert_equal(2, #panel.cards)
end

function test_time_bonus()
    lunatest.assert_equal(150, GoalCards.timeBonus(150.7))
    lunatest.assert_equal(0, GoalCards.timeBonus(-5))
    lunatest.assert_equal(0, GoalCards.timeBonus(nil))
end

return lunatest
