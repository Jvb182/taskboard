local T, Mock = ...
local m, ns = T.client()
local P = ns.Parser

describe("Parser goals", function()
    it("reads quantities around named-color item links without leaking markup", function()
        for _, color in ipairs({ "IQ1", "ITEM_QUALITY1" }) do
            local link = "|cn" .. color .. ":|Hitem:765:::::::::|h[Silverleaf]|h|r"
            for _, text in ipairs({ "get 17 " .. link, "17x " .. link, link .. " x17" }) do
                T.eq(P.ParseGoal(text).target, 17)
                T.eq(P.ParseGoal(text).itemID, 765)
            end
            T.eq(ns.Util.Sanitize("get 17 " .. link), "get 17 [Silverleaf]")
        end
    end)

    it("keeps a linked 17-item task incomplete at 15 and completes at 17", function()
        local client, addon = T.client()
        client.Loot(765, 15)
        local card = addon.Commands:Add("get 17 |cnIQ1:|Hitem:765:::::::::|h[Silverleaf]|h|r")
        client.Advance(1)
        local board = addon.DB:GetActiveBoard()
        T.eq(card.title, "get 17 [Silverleaf]")
        T.eq(card.progress.cur, 15)
        T.eq(card.progress.target, 17)
        T.no(addon.DB:CardRole(board, card) == "done")
        client.Loot(765, 2)
        client.Advance(1)
        T.eq(addon.DB:CardRole(board, card), "done")
        T.noErrors(addon)
    end)

    local cases = {
        -- text, type, field checks
        { "Get 20 Peacebloom", "item", { itemID = 2447, target = 20, name = "Peacebloom" } },
        { "get 20 peacebloom", "item", { itemID = 2447, target = 20 } },
        { "20x Peacebloom", "item", { itemID = 2447, target = 20 } },
        { "20 Peacebloom", "item", { itemID = 2447, target = 20 } },
        { "Peacebloom x20", "item", { itemID = 2447, target = 20 } },
        { "farm 15 Silverleaf for alchemy", "item", { itemID = 765, target = 15, name = "Silverleaf" } },
        { "collect 10 Copper Ore", "item", { itemID = 2770, target = 10 } },
        { "Get 5 Totally Unknown Thing", "item", { target = 5, name = "Totally Unknown Thing" } },
        { "save 100g", "money", { target = 1000000 } },
        { "have 1g 50s", "money", { target = 15000 } },
        { "250g", "money", { target = 2500000 } },
        { "reach level 40", "level", { target = 40 } },
        { "Ding 60!", "level", { target = 60 } },
        { "lvl 30", "level", { target = 30 } },
        { "Herbalism 150", "skill", { name = "Herbalism", target = 150 } },
        { "get tailoring to 225", "skill", { name = "Tailoring", target = 225 } },
        { "first aid 300", "skill", { name = "First Aid", target = 300 } },
        { "Honored with Stormwind", "rep", { name = "Stormwind", target = 6 } },
        { "get exalted with the Argent Dawn", "rep", { name = "Argent Dawn", target = 8 } },
        { "revered timbermaw hold", "rep", { target = 7 } },
        { "quest: The Defias Brotherhood", "quest", { name = "The Defias Brotherhood" } },
    }
    for _, case in ipairs(cases) do
        it(case[1], function()
            local g = P.ParseGoal(case[1])
            T.ok(g, "parsed a goal")
            T.eq(g.type, case[2])
            for k, v in pairs(case[3]) do T.eq(g[k], v, k) end
        end)
    end

    it("reads item and quest links", function()
        local g = P.ParseGoal("Get 12 " .. m.ItemLink(765))
        T.eq(g.type, "item")
        T.eq(g.itemID, 765)
        T.eq(g.target, 12)
        T.eq(g.verified, true)
        local g2 = P.ParseGoal(m.ItemLink(2589) .. " x40")
        T.eq(g2.target, 40)
        local g3 = P.ParseGoal(m.ItemLink(2589))
        T.eq(g3.target, 1)
        local q = P.ParseGoal("|cffffff00|Hquest:176:10|h[Wanted: Hogger]|h|r")
        T.eq(q.type, "quest")
        T.eq(q.questID, 176)
    end)

    it("leaves plain tasks without a goal", function()
        for _, text in ipairs({ "Kill Hogger", "Train new spells", "Buy a mount", "Call mom", "20", "Find 2 friends to quest with" }) do
            local g = P.ParseGoal(text)
            if text == "Find 2 friends to quest with" then
                -- "find 2 X" is an item-style goal by design (pending until looted); make sure it is pending, not wrong.
                T.ok(g == nil or (g.type == "item" and not g.itemID), text)
            else
                T.eq(g, nil, text)
            end
        end
    end)

    it("item names in the built-in table are marked for verification", function()
        local g = P.ParseGoal("get 20 Mageroyal")
        T.eq(g.itemID, 785)
        T.eq(g.source, "known")
        T.no(g.verified)
    end)
end)

describe("Parser full lines", function()
    it("extracts tags, priority, reminders, repeat and column", function()
        local spec, warnings = P.Parse("Get 20 Peacebloom #herbs #Alchemy !high @bank *daily >doing")
        T.eq(spec.title, "Get 20 Peacebloom")
        T.eq(spec.tags[1], "herbs")
        T.eq(spec.tags[2], "alchemy")
        T.eq(spec.priority, 3)
        T.eq(spec.where.npc, "bank")
        T.eq(spec.recur, "daily")
        T.eq(spec.columnRole, "doing")
        T.eq(spec.goal.itemID, 2447)
        T.eq(#warnings, 0)
    end)

    it("handles zones with spaces", function()
        T.eq(P.Parse('Train @"Stormwind City"').where.zone, "Stormwind City")
        T.eq(P.Parse("Train @Stormwind_City").where.zone, "Stormwind City")
        T.eq(P.Parse("Visit @Ironforge").where.zone, "Ironforge")
    end)

    it("splits subtasks with their own goals", function()
        local spec = P.Parse("Alchemy prep; 20 Peacebloom; 20 Silverleaf; talk to trainer")
        T.eq(spec.title, "Alchemy prep")
        T.eq(spec.goal, nil)
        T.eq(#spec.subtasks, 3)
        T.eq(spec.subtasks[1].goal.itemID, 2447)
        T.eq(spec.subtasks[2].goal.itemID, 765)
        T.eq(spec.subtasks[3].goal, nil)
    end)

    it("warns about unknown items", function()
        local _, warnings = P.Parse("Get 3 Frobnicator")
        T.eq(#warnings, 1)
        T.contains(warnings[1], "Frobnicator")
    end)

    it("keeps unknown !words and lone symbols in the title", function()
        local spec = P.Parse("Kill Hogger !now # @")
        T.contains(spec.title, "!now")
        T.eq(spec.priority, 0)
    end)

    it("strips links from titles but keeps the goal", function()
        local spec = P.Parse("Get 5 " .. m.ItemLink(2589))
        T.eq(spec.title, "Get 5 [Linen Cloth]")
        T.eq(spec.goal.itemID, 2589)
    end)

    it("describes goals for humans", function()
        T.eq(P.Describe({ type = "item", name = "Peacebloom", itemID = 2447, target = 20 }), "Have 20 x Peacebloom")
        T.eq(P.Describe({ type = "money", target = 1000000 }), "Have 100g")
        T.eq(P.Describe({ type = "rep", name = "Stormwind", target = 6 }), "Honored with Stormwind")
        T.contains(P.Describe({ type = "item", name = "X", target = 2 }), "waiting for first loot")
    end)
end)

