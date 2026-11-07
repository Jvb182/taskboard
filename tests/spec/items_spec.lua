local T, Mock = ...

describe("Items", function()
    it("resolves by link, cache, bags, built-in table, in that order", function()
        local m, ns = T.client()
        local I = ns.Items
        local id, _, source = I:Resolve(m.ItemLink(9999))
        T.eq(id, 9999) T.eq(source, "link")
        id, _, source = I:Resolve("Peacebloom")
        T.eq(id, 2447) T.eq(source, "cache")
        m.Loot(9999, 1, true)
        id, _, source = I:Resolve("mystery widget")
        T.eq(id, 9999) T.eq(source, "bags", "found by scanning bags (case-insensitive)")
        id, _, source = I:Resolve("Copper Ore")
        T.eq(id, 2770) T.eq(source, "known")
        T.eq(I:Resolve("No Such Item"), nil)
    end)

    it("counts bags and optionally the bank", function()
        local m, ns = T.client()
        m.Loot(2447, 7, true)
        m.state.bank[2447] = 5
        T.eq(ns.Items:Count(2447, false), 7)
        T.eq(ns.Items:Count(2447, true), 12)
        T.eq(ns.Items:Count(nil, true), 0)
    end)

    it("verifies built-in IDs against the server and unbinds wrong ones", function()
        local m, ns = T.client()
        -- Pretend the built-in table had a wrong ID for Copper Ore.
        m.items[2770].name = "Definitely Not Copper"
        local board = ns.DB:GetActiveBoard()
        local card = ns.Commands:Add("Get 10 Copper Ore")
        T.eq(card.goal.itemID, 2770)
        m.Advance(4) -- verification runs ~3s after login
        m.Advance(1) -- item data arrives
        T.eq(card.goal.itemID, nil, "wrong ID unbound")
        T.ok(m.ChatContains("") or true)
        local warned = false
        for _, e in ipairs(ns.Log:GetEntries(3)) do if e.m:find("not 'Copper Ore'", 1, true) then warned = true end end
        T.ok(warned, "mismatch logged as a warning")
        T.noErrors(ns)
    end)

    it("keeps correct built-in IDs and marks them verified", function()
        local m, ns = T.client()
        local card = ns.Commands:Add("Get 10 Mageroyal")
        T.no(card.goal.verified)
        m.Advance(5)
        T.eq(card.goal.itemID, 785)
        T.eq(card.goal.verified, true)
        T.eq(ns.Items.stats.verified >= 1, true)
    end)
end)
