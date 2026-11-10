local T, Mock = ...

describe("Reminders", function()
    it("fires when entering a matching zone, once per cooldown", function()
        local m, ns = T.client()
        ns.Commands:Add("Buy reagents @Ironforge")
        local count = 0
        ns:On("REMINDER", function() count = count + 1 end)
        m.state.zone, m.state.subzone = "Ironforge", "The Commons"
        m.Fire("ZONE_CHANGED_NEW_AREA")
        T.eq(count, 1)
        T.ok(m.ChatContains("Reminder:"))
        T.ok(m.ChatContains("Buy reagents @Ironforge"))
        m.Fire("ZONE_CHANGED")
        T.eq(count, 1, "cooldown prevents repeats")
        m.AdvanceTime(301)
        m.Fire("ZONE_CHANGED_NEW_AREA")
        T.eq(count, 2)
    end)

    it("matches subzones and prefixes, case-insensitively", function()
        local m, ns = T.client()
        local R = ns.Reminders
        T.ok(R.ZoneMatches("ironforge", "Ironforge", ""))
        T.ok(R.ZoneMatches("Trade Dis", "Stormwind City", "Trade District"))
        T.no(R.ZoneMatches("Orgrimmar", "Ironforge", "The Commons"))
        T.no(R.ZoneMatches("", "Ironforge", ""))
    end)

    it("fires for NPC reminders and skips done cards", function()
        local m, ns = T.client()
        local a = ns.Commands:Add("Grab mats @bank")
        local b = ns.Commands:Add("Old thing @bank")
        ns.DB:MoveCard(ns.DB:GetActiveBoard(), b.id, "done")
        local got
        ns:On("REMINDER", function(title, lines) got = lines end)
        m.Fire("BANKFRAME_OPENED")
        T.ok(got)
        T.eq(#got, 1)
        T.eq(got[1].card, a)
        T.eq(got[1].text, "Grab mats @Bank")
        T.ok(m.ChatContains("Grab mats @Bank"))
    end)

    it("smart reminders: missing items at the AH, goal items in the bank", function()
        local m, ns = T.client()
        ns.Commands:Add("Get 20 Peacebloom")
        m.Loot(2447, 4, true)
        m.state.bank[2447] = 6
        local got
        ns:On("REMINDER", function(title, lines) got = lines end)
        m.Fire("AUCTION_HOUSE_SHOW")
        T.ok(got)
        T.contains(got[1].text, "Still need 10 Peacebloom")
        got = nil
        m.Fire("BANKFRAME_OPENED")
        T.ok(got)
        T.contains(got[1].text, "6 Peacebloom in your bank")
    end)

    it("can be turned off", function()
        local m, ns = T.client()
        ns.Commands:Add("x @bank")
        ns.db.settings.reminders = false
        local fired = false
        ns:On("REMINDER", function() fired = true end)
        m.Fire("BANKFRAME_OPENED")
        T.no(fired)
    end)

    it("learns mailboxes and reminds on a later approach", function()
        local m, ns = T.client()
        ns.Commands:Add("Send items @mail")
        local titles = {}
        ns:On("REMINDER", function(title) titles[#titles + 1] = title end)
        m.Fire("MAIL_SHOW")
        T.eq(#ns.db.mailboxes, 1)
        m.Fire("MAIL_CLOSED")
        m.state.pos = { 0.60, 0.65 }; m.Advance(3)
        m.state.pos = { 0.44, 0.65 }; m.Advance(3)
        T.eq(titles[#titles], "Near a mailbox")
        T.ok(m.ChatContains("Send items @Mailbox"))
        local count = #titles
        m.Advance(15); T.eq(#titles, count)
        m.state.pos = { 0.60, 0.65 }; m.Advance(3)
        m.state.pos = { 0.44, 0.65 }; m.Advance(3)
        T.eq(#titles, count, "cooldown prevents repeated approach popups")
        T.noErrors(ns)
    end)

    it("completes check-mail tasks on opening, but leaves other mail tasks open", function()
        local m, ns = T.client()
        local check = ns.Commands:Add("Check mail @mail")
        local send = ns.Commands:Add("Send materials @mail")
        local board = ns.DB:GetActiveBoard()
        m.Fire("MAIL_SHOW")
        T.eq(ns.DB:CardRole(board, check), "done")
        T.eq(ns.DB:CardRole(board, send), "todo")
        T.noErrors(ns)
    end)

    it("uses same-map yard dimensions when world positions are unavailable", function()
        local m, ns = T.client()
        m.env.C_Map.GetWorldPosFromMapPos = nil
        ns.Commands:Add("Send items @mail")
        local titles = {}
        ns:On("REMINDER", function(title) titles[#titles + 1] = title end)
        m.Fire("MAIL_SHOW"); m.Fire("MAIL_CLOSED")
        T.eq(ns.db.mailboxes[1].continent, "map:1429")
        m.state.pos = { 0.60, 0.65 }; m.Advance(3)
        m.state.pos = { 0.44, 0.65 }; m.Advance(3)
        T.eq(titles[#titles], "Near a mailbox")
        T.noErrors(ns)
    end)
end)

