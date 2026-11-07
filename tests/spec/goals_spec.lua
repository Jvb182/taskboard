local T, Mock = ...

local function role(ns, card)
    return ns.DB:CardRole(ns.DB:GetActiveBoard(), card)
end

describe("Goal types", function()
    it("money", function()
        local m, ns = T.client()
        local card = ns.Commands:Add("Save 100g for mount")
        T.eq(card.goal.type, "money")
        m.state.money = 25 * 10000
        m.Fire("PLAYER_MONEY")
        m.Advance(0.5)
        T.near(card.progress.frac, 0.25)
        T.eq(card.progress.text, "25g / 100g")
        m.state.money = 100 * 10000 + 5
        m.Fire("PLAYER_MONEY")
        m.Advance(1)
        T.eq(role(ns, card), "done")
    end)

    it("level, with XP progress inside the level", function()
        local m, ns = T.client()
        m.state.level, m.state.xp, m.state.xpMax = 20, 500, 1000
        local card = ns.Commands:Add("reach level 22")
        T.eq(card.goal.start, 20)
        m.Advance(0.5)
        T.near(card.progress.frac, 0.25, 0.001, "half a level of two")
        T.contains(card.progress.text, "20.5")
        m.state.level = 22
        m.Fire("PLAYER_LEVEL_UP", 22)
        m.Advance(1)
        T.eq(role(ns, card), "done")
    end)

    it("skill, including not-yet-learned skills", function()
        local m, ns = T.client()
        local card = ns.Commands:Add("Herbalism 150")
        m.Advance(0.5)
        T.contains(card.progress.text, "not learned")
        m.state.skills = { { name = "Professions", isHeader = true }, { name = "Herbalism", rank = 75, maxRank = 75 } }
        m.Fire("SKILL_LINES_CHANGED")
        m.Advance(0.5)
        T.eq(card.progress.cur, 75)
        T.contains(card.progress.text, "train for higher cap")
        m.state.skills[2].rank, m.state.skills[2].maxRank = 150, 150
        m.Fire("SKILL_LINES_CHANGED")
        m.Advance(1)
        T.eq(role(ns, card), "done")
    end)

    it("reputation, matched by partial name and then by ID", function()
        local m, ns = T.client()
        m.state.factions = { { id = 72, name = "Stormwind", standing = 4500 } } -- Friendly, 1500/6000
        local card = ns.Commands:Add("Honored with stormwind")
        m.Advance(0.5)
        T.eq(card.goal.factionID, 72, "bound to the faction ID")
        T.contains(card.progress.text, "Friendly 1500/6000")
        m.state.factions[1].standing = 9000
        m.Fire("UPDATE_FACTION")
        m.Advance(1)
        T.eq(role(ns, card), "done")
    end)

    it("quests: not started, objectives, ready, turned in", function()
        local m, ns = T.client()
        local card = ns.Commands:Add("|cffffff00|Hquest:176:10|h[Wanted: Hogger]|h|r")
        m.Advance(0.5)
        T.contains(card.progress.text, "not started")
        m.state.questLog = { { id = 176, title = "Wanted: Hogger" } }
        m.state.objectives[176] = { { text = "Hogger's Claw: 0/1", numFulfilled = 0, numRequired = 1, finished = false } }
        m.Fire("QUEST_LOG_UPDATE")
        m.Advance(0.5)
        T.contains(card.progress.text, "Hogger's Claw")
        T.eq(role(ns, card), "doing")
        m.state.questLog[1].complete = true
        m.Fire("QUEST_LOG_UPDATE")
        m.Advance(0.5)
        T.contains(card.progress.text, "ready to turn in")
        m.state.questLog = {}
        m.state.completedQuests[176] = true
        m.Fire("QUEST_TURNED_IN", 176, 0, 0)
        m.Advance(1)
        T.eq(role(ns, card), "done")
        T.noErrors(ns)
    end)

    it("quests by name bind once the quest is accepted", function()
        local m, ns = T.client()
        local card = ns.Commands:Add("quest: The Fargodeep Mine")
        m.Advance(0.5)
        T.contains(card.progress.text, "not in quest log yet")
        m.state.questLog = { { id = 62, title = "The Fargodeep Mine" } }
        m.Fire("QUEST_LOG_UPDATE")
        m.Advance(0.5)
        T.eq(card.goal.questID, 62)
    end)
end)
