local T, Mock = ...

local function learn(m)
    m.Fire("MAIL_SHOW"); m.Fire("MAIL_CLOSED")
    m.state.pos = { 0.60, 0.65 }; m.Advance(3)
    m.state.pos = { 0.44, 0.65 }; m.Advance(3)
end

describe("QA checklist regressions", function()
    it("map pins survive reload and can be replaced and cleared", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Meet friends")
        local b = ns.DB:GetActiveBoard()
        ns.Editor:Open(c, b); ns.Editor:PinHere()
        local n, a = T.client(nil, m.Logout())
        local saved = a.db.boards[b.id].cards[c.id]
        T.near(saved.pin.x, 0.42)
        a.Editor:Open(saved, a.db.boards[b.id])
        n.state.pos = { 0.25, 0.75 }; a.Editor:PinHere()
        T.near(saved.pin.x, 0.25); T.near(saved.pin.y, 0.75)
        a.Editor:Internals().ui.pinClear:Click()
        T.eq(saved.pin, nil); a.Editor:ShowPin(saved); T.eq(#n.waypoints, 0); T.noErrors(a)
    end)

    it("unavailable map coordinates preserve the existing pin with an explanation", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Meet friends")
        ns.Editor:Open(c, ns.DB:GetActiveBoard()); ns.Editor:PinHere()
        m.env.C_Map.GetPlayerMapPosition = function() return nil end
        ns.Editor:PinHere()
        T.near(c.pin.x, 0.42); T.ok(m.ChatContains("position isn't available")); T.noErrors(ns)
    end)

    it("unsupported waypoint maps report coordinates without creating a waypoint", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Meet friends")
        ns.Editor:Open(c, ns.DB:GetActiveBoard()); ns.Editor:PinHere()
        m.env.C_Map.CanSetUserWaypointOnMap = function() return false end
        ns.Editor:ShowPin(c)
        T.eq(#m.waypoints, 0); T.ok(m.ChatContains("42.0, 65.0")); T.noErrors(ns)
    end)

    local liveGoals = {
        { name = "money", text = "Save 100g", event = "PLAYER_MONEY", reach = function(m) m.state.money = 1000000 end },
        { name = "level", text = "reach level 22", event = "PLAYER_LEVEL_UP", reach = function(m) m.state.level = 22 end },
        { name = "profession", text = "Herbalism 150", event = "SKILL_LINES_CHANGED", reach = function(m)
            m.state.skills = { { name = "Herbalism", rank = 150, maxRank = 150 } }
        end },
        { name = "reputation", text = "Honored with Stormwind", event = "UPDATE_FACTION", reach = function(m)
            m.state.factions = { { id = 72, name = "Stormwind", standing = 9000 } }
        end },
        { name = "quest", text = "|cffffff00|Hquest:176:10|h[Wanted: Hogger]|h|r", event = "QUEST_LOG_UPDATE", reach = function(m)
            m.state.completedQuests[176] = true
        end },
    }
    for _, case in ipairs(liveGoals) do
        it(case.name .. " tracks completion without moving when autoComplete is disabled", function()
            local m, ns = T.client()
            ns.db.settings.autoComplete = false
            local c = ns.Commands:Add(case.text)
            case.reach(m); m.Fire(case.event, 22); m.Advance(1)
            T.ok(c.progress.done); T.no(c.column == "done"); T.noErrors(ns)
        end)
        it(case.name .. " never consumes another character's progress events", function()
            local m, ns = T.client()
            local c = ns.Commands:Add(case.text)
            c.char = "Other-Forever"
            case.reach(m); m.Fire(case.event, 22); m.Advance(1)
            T.no(c.column == "done"); T.no(c.progress and c.progress.done); T.noErrors(ns)
        end)
    end

    it("mail proximity enters at 35 yards and leaves beyond 50", function()
        local m, ns = T.client(); learn(m)
        m.state.pos = { 0.471, 0.65 }; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox())
        m.state.pos = { 0.456, 0.65 }; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox())
        m.state.pos = { 0.454, 0.65 }; m.Advance(3)
        T.ok(ns.Reminders:IsNearMailbox())
        m.state.pos = { 0.469, 0.65 }; m.Advance(3)
        T.ok(ns.Reminders:IsNearMailbox())
        m.state.pos = { 0.471, 0.65 }; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox()); T.noErrors(ns)
    end)

    it("mail proximity clears when coordinates disappear and recovers", function()
        local m, ns = T.client(); learn(m)
        local get = m.env.C_Map.GetPlayerMapPosition
        m.env.C_Map.GetPlayerMapPosition = function() return nil end
        m.Advance(3); T.no(ns.Reminders:IsNearMailbox())
        m.env.C_Map.GetPlayerMapPosition = get
        m.Advance(3); T.ok(ns.Reminders:IsNearMailbox()); T.noErrors(ns)
    end)

    it("learned mailbox spots survive logout without duplicate learning", function()
        local m, ns = T.client(); learn(m)
        local n, other = T.client(nil, m.Logout())
        T.eq(#other.db.mailboxes, 1)
        n.Advance(3); T.ok(other.Reminders:IsNearMailbox())
        n.Fire("MAIL_SHOW"); T.eq(#other.db.mailboxes, 1); T.noErrors(other)
    end)

    it("enabling reminders while nearby delivers an unseen task once", function()
        local m, ns = T.client(); learn(m)
        ns.db.settings.reminders = false
        ns.Commands:Add("Send items @mail")
        local count = 0
        ns:On("REMINDER", function() count = count + 1 end)
        m.Advance(3); T.eq(count, 0)
        ns.db.settings.reminders = true
        m.Advance(3); T.eq(count, 1)
        m.Advance(9); T.eq(count, 1); T.noErrors(ns)
    end)

    it("mail opening completes todo and doing but skips archived and other owners", function()
        local m, ns = T.client()
        local b = ns.DB:GetActiveBoard()
        local todo = ns.Commands:Add("Check mail @mail")
        local doing = ns.Commands:Add("Check mailbox @mail >doing")
        local archived = ns.Commands:Add("Check my mail @mail")
        archived.archived = true
        local other = ns.Commands:Add("Check my mailbox @mail")
        other.char = "Other-Forever"
        m.Fire("MAIL_SHOW")
        T.eq(todo.column, "done"); T.eq(doing.column, "done")
        T.eq(archived.column, "todo"); T.eq(other.column, "todo"); T.noErrors(ns)
    end)

    it("closing mail does not immediately repeat the opening reminder", function()
        local m, ns = T.client()
        ns.Commands:Add("Send items @mail")
        local count = 0
        ns:On("REMINDER", function() count = count + 1 end)
        m.Fire("MAIL_SHOW"); T.eq(count, 1)
        m.Fire("MAIL_CLOSED"); m.Advance(310)
        T.eq(count, 1); T.noErrors(ns)
    end)

    it("MB15 clears nearby state after leaving with reminder popups disabled", function()
        local m, ns = T.client()
        learn(m); T.ok(ns.Reminders:IsNearMailbox())
        ns.db.settings.reminders = false
        m.state.pos = { 0.60, 0.65 }; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox())
        T.noErrors(ns)
    end)

    it("MB16 reminds once for a task created while already near", function()
        local m, ns = T.client(); learn(m)
        local count = 0
        ns:On("REMINDER", function(title) if title == "Near a mailbox" then count = count + 1 end end)
        ns.Commands:Add("Send items @mail")
        m.Advance(3); T.eq(count, 1)
        m.Advance(310); T.eq(count, 1, "staying nearby must not spam")
        T.noErrors(ns)
    end)

    it("MB17 accepts punctuation on a check-mail title", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Check mail! @mail")
        m.Fire("MAIL_SHOW")
        T.eq(c.column, "done")
    end)

    it("MB18 does not finish unrelated goals or subtasks on mailbox open", function()
        local m, ns = T.client()
        local a = ns.Commands:Add("Check mail @mail; buy vials")
        local b = ns.Commands:Add("Check mailbox @mail")
        ns.DB:UpdateCard(ns.DB:GetActiveBoard(), b, { goal = { type = "item", itemID = 2447, target = 20 } })
        m.Fire("MAIL_SHOW")
        T.no(a.column == "done"); T.no(b.column == "done")
        T.noErrors(ns)
    end)

    it("GL08 mailbox completion respects the automatic completion switch", function()
        local m, ns = T.client()
        ns.db.settings.autoComplete = false
        local c = ns.Commands:Add("Check mail @mail")
        m.Fire("MAIL_SHOW"); T.eq(c.column, "todo")
        ns.db.settings.autoComplete = true
        m.Fire("MAIL_SHOW"); T.eq(c.column, "done")
    end)

    it("LC12 keeps the last destination in mixed quoted and plain tokens", function()
        local _, ns = T.client()
        T.eq(ns.Parser.Parse('Buy vials @bank @"Stormwind City"').where.zone, "Stormwind City")
        T.eq(ns.Parser.Parse('Buy vials @"Stormwind City" @bank').where.npc, "bank")
        T.eq(ns.Parser.Parse('Buy vials @Goldshire @"Stormwind City"').where.zone, "Stormwind City")
    end)

    it("BD07 refuses ambiguous board names and allows an owner-qualified name", function()
        local ma, a = T.client({ name = "Alice" })
        local mb, b = T.client({ name = "Bob" }, ma.Logout())
        local own = b.DB:GetActiveBoard()
        b.Commands:Board("My Tasks")
        T.eq(b.DB:GetActiveBoard(), own)
        T.ok(mb.ChatContains("More than one board"))
        b.Commands:Board("My Tasks (Alice-Forever)")
        T.eq(b.DB:GetActiveBoard().owner, "Alice-Forever")
    end)

    it("BD09 new cards default to the selected character board owner", function()
        local ma, a = T.client({ name = "Alice" })
        local mb, b = T.client({ name = "Bob" }, ma.Logout())
        b.DB:SetActiveBoard(b.DB:BoardForCharacter("Alice-Forever"))
        local c = b.Commands:Add("20 Peacebloom")
        T.eq(c.char, "Alice-Forever")
        mb.Loot(2447, 20); mb.Advance(1)
        T.eq(c.column, "todo")
    end)

    it("FB11 ignores a toast whose card was deleted", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Disposable")
        local b = ns.DB:GetActiveBoard()
        ns.DB:MoveCard(b, c.id, "done"); m.Advance(0.6)
        local toast = ns.Toast:Active()[1]; T.ok(toast)
        ns.DB:DeleteCard(b, c.id)
        toast:Click("LeftButton")
        T.eq(ns.Editor:Current(), nil)
        T.noErrors(ns)
    end)

    it("EX02 import fails cleanly if no personal board can be created", function()
        local m, ns = T.client()
        local text = assert(ns.Serialize.Export(ns.DB:GetActiveBoard()))
        ns.db.boards = {}
        for i = 1, ns.DB.LIMITS.boards do
            local b = ns.DB.NormalizeBoard({ id = "b" .. i, name = "Remote", scope = "shared", shared = { from = "Other-Forever" } })
            ns.db.boards[b.id] = b
        end
        ns.LogWindow:ShowImport(); ns.LogWindow:Internals().box:SetText(text)
        ns.LogWindow:DoImport()
        T.eq(ns.Util.Count(ns.db.boards), ns.DB.LIMITS.boards)
        T.ok(m.ChatContains("Import failed")); T.noErrors(ns)
    end)
end)
