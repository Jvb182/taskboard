local T, Mock = ...
local m, ns = T.client()
local U = ns.Util

describe("Util", function()
    it("parses and formats money", function()
        T.eq(U.ParseMoney("100g"), 1000000)
        T.eq(U.ParseMoney("1g 50s"), 15000)
        T.eq(U.ParseMoney("1g50s20c"), 15020)
        T.eq(U.ParseMoney("75s"), 7500)
        T.eq(U.ParseMoney("get 20 copper ore"), nil, "'20 c' followed by letters is not money")
        T.eq(U.ParseMoney("20 silverleaf"), nil)
        T.eq(U.FormatMoney(15020), "1g 50s 20c")
        T.eq(U.FormatMoney(0), "0c")
        T.eq(U.FormatMoney(1234567, true), "123g 45s")
        T.eq(U.FormatMoney(10000000, true), "1000g")
    end)

    it("splits, trims and copies", function()
        local parts = U.Split("a;b;;c", ";")
        T.eq(#parts, 4)
        T.eq(parts[3], "")
        T.eq(U.Trim("  hi  "), "hi")
        local t = { a = { b = 1 } }
        local c = U.DeepCopy(t)
        c.a.b = 2
        T.eq(t.a.b, 1)
        local d = U.ApplyDefaults({ x = 1 }, { x = 2, y = { z = 3 } })
        T.eq(d.x, 1)
        T.eq(d.y.z, 3)
    end)

    it("parses item and quest links", function()
        local id, name = U.ParseItemLink(m.ItemLink(2447))
        T.eq(id, 2447)
        T.eq(name, "Peacebloom")
        local qid, qname = U.ParseQuestLink("|cffffff00|Hquest:176:10|h[Wanted: Hogger]|h|r")
        T.eq(qid, 176)
        T.eq(qname, "Wanted: Hogger")
        T.eq(U.StripLinks("Get " .. m.ItemLink(2447) .. " x5"), "Get [Peacebloom] x5")
    end)

    it("sanitizes untrusted text", function()
        local evil = "|cffff0000Red|r |TInterface\\Icons\\Foo:0|t |Hitem:1|h[x]|h pipe| \1\2 end"
        local clean = U.Sanitize(evil, 200)
        T.no(clean:find("|", 1, true), "no escape characters left")
        T.no(clean:find("%c"), "no control characters left")
        T.contains(clean, "Red")
        T.eq(#U.Sanitize(string.rep("a", 500), 50), 50)
    end)

    it("checksums and ids", function()
        T.eq(U.Adler32("Wikipedia"), 0x11E60398)
        local seen = {}
        for _ = 1, 500 do
            local id = U.NewID("c")
            T.no(seen[id], "ids are unique")
            seen[id] = true
        end
    end)

    it("formats durations and ages", function()
        T.eq(U.Duration(90), "1m")
        T.eq(U.Duration(3 * 3600 + 60 * 5), "3h 5m")
        T.eq(U.Ago(m.now - 10, m.now), "just now")
        T.eq(U.Ago(m.now - 7200, m.now), "2h ago")
    end)
end)
