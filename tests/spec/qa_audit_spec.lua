local T, Mock = ...

local function learn(m)
    m.Fire("MAIL_SHOW"); m.Fire("MAIL_CLOSED")
    m.state.pos = { 0.60, 0.65 }; m.Advance(3)
    m.state.pos = { 0.44, 0.65 }; m.Advance(3)
end

describe("QA checklist regressions", function()
    it("recognizes plain mailbox errands but preserves explicit destinations", function()
        local m, ns = T.client()
        for _, title in ipairs({ "check mail", "Check mailbox!", "open mail", "Visit the mailbox", "Open my mail box" }) do
            local c = ns.Commands:Add(title); T.eq(c.where.npc, "mail")
        end
        T.eq(ns.Commands:Add("check mail @Goldshire").where.zone, "Goldshire")
        T.eq(ns.Commands:Add("Send items @mailbox").where.npc, "mail")
        T.eq(ns.Commands:Add("Check email").where, nil)
        T.eq(ns.Commands:Add("Check mail armor prices").where, nil)
    end)

    it("keeps mailbox reminder Off after edits and reload", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Open mail")
        local b = ns.DB:GetActiveBoard()
        ns.DB:UpdateCard(b, c, { where = false })
        ns.DB:UpdateCard(b, c, { notes = "later" }); T.eq(c.where, nil)
        local n, a = T.client(nil, m.Logout())
        T.eq(a.db.boards[b.id].cards[c.id].where, nil); T.noErrors(a)
    end)

    it("upgrades an existing plain mailbox task and completes only eligible plain tasks", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Open mail")
        local b = ns.DB:GetActiveBoard(); c.where = nil
        local n, a = T.client(nil, m.Logout())
        local saved = a.db.boards[b.id].cards[c.id]
        T.eq(saved.where.npc, "mail")
        local sub = a.Commands:Add("open mailbox; send items")
        n.Fire("MAIL_SHOW"); T.eq(saved.column, "done"); T.eq(sub.column, "todo")
    end)

    it("mailbox alias reminds after learning on continent zero and explains diagnostics", function()
        local m, ns = T.client()
        m.env.C_Map.GetWorldPosFromMapPos = function(_, pos) return 0, { x = pos.x * 1000 - 9300, y = pos.y * 1000 } end
        local c = ns.Commands:Add("Send items @mailbox")
        local count = 0
        ns:On("REMINDER", function(title) if title == "Near a mailbox" then count = count + 1 end end)
        learn(m); T.eq(count, 1); T.eq(c.column, "todo")
        T.contains(ns.Reminders:MailboxStatus(), "1 eligible task(s)")
        T.contains(ns.Reminders:MailboxStatus(), "20.0 yards")
        T.noErrors(ns)
    end)

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

    it("GL10 shows current money and decreases before reaching the target", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Save 100g")
        m.state.money = 75 * 10000; m.Fire("PLAYER_MONEY"); m.Advance(0.5)
        T.eq(c.progress.text, "75g / 100g")
        m.state.money = 20 * 10000; m.Fire("PLAYER_MONEY"); m.Advance(0.5)
        T.eq(c.progress.text, "20g / 100g")
        T.no(c.column == "done")
        m.state.money = 100 * 10000; m.Fire("PLAYER_MONEY"); m.Advance(1)
        T.eq(c.column, "done"); T.noErrors(ns)
    end)

    it("RM08-10 matches only the opened NPC type", function()
        local m, ns = T.client()
        local bank = ns.Commands:Add("Sort supplies @bank")
        local vendor = ns.Commands:Add("Buy vials @vendor")
        local auction = ns.Commands:Add("List auctions @ah")
        local got
        ns:On("REMINDER", function(_, lines) got = lines end)
        local cases = { { "BANKFRAME_OPENED", bank }, { "MERCHANT_SHOW", vendor },
            { "AUCTION_HOUSE_SHOW", auction } }
        for _, case in ipairs(cases) do
            got = nil; m.Fire(case[1])
            T.ok(got); T.eq(#got, 1); T.eq(got[1].card, case[2])
        end
        T.noErrors(ns)
    end)

    it("RM12 and RM15 keep explicit reminders when smart suggestions are off", function()
        local m, ns = T.client()
        ns.Commands:Add("Buy vials @bank")
        ns.Commands:Add("Get 20 Peacebloom")
        m.state.bank[2447] = 6
        local got
        ns:On("REMINDER", function(_, lines) got = lines end)
        ns.db.settings.reminders = false
        m.Fire("BANKFRAME_OPENED"); T.eq(got, nil)
        ns.db.settings.reminders = true
        ns.db.settings.smartReminders = false
        m.Fire("BANKFRAME_OPENED")
        T.ok(got); T.eq(#got, 1); T.eq(got[1].card.title, "Buy vials")
        got = nil; m.Fire("AUCTION_HOUSE_SHOW"); T.eq(got, nil)
        T.noErrors(ns)
    end)

    it("MB10-12 completes check-mail title variants but not other mail errands", function()
        local m, ns = T.client()
        local checks = {}
        for _, title in ipairs({ "Mail", "Mailbox", "Check mailbox", "Check my mail", "Check my mailbox", "cHeCk MaIl" }) do
            checks[#checks + 1] = ns.Commands:Add(title .. " @mail")
        end
        local send = ns.Commands:Add("Send materials @mail")
        local collect = ns.Commands:Add("Collect auction proceeds @mail")
        m.Fire("MAIL_SHOW")
        for _, c in ipairs(checks) do T.eq(c.column, "done") end
        T.eq(send.column, "todo"); T.eq(collect.column, "todo")
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

    it("reset all data needs confirmation and survives reload without old cards", function()
        local m, ns = T.client()
        ns.Commands:Add("Old task")
        ns.db.settings.theme = "classic_stone"
        ns.db.mailboxes = { { continent = 1, x = 10, y = 20 } }
        ns.db.stats.total = 42
        ns.Options:Show()
        local buttons = m.FindByText("Reset all data", "Button")
        T.eq(#buttons, 1)
        buttons[1]:Click(); T.contains(m.popups[#m.popups].text, "cannot be undone")
        m.CancelPopup(); T.eq(ns.db.settings.theme, "classic_stone")
        T.ok(ns.DB:GetActiveBoard().cards and ns.Util.Count(ns.DB:GetActiveBoard().cards) > 0)
        buttons[1]:Click(); m.AcceptPopup()
        T.eq(ns.db.settings.theme, "midnight")
        T.eq(ns.db.settings.autoComplete, true)
        T.eq(#ns.db.mailboxes, 0)
        T.eq(ns.db.stats.total, 0)
        T.eq(ns.Util.Count(ns.db.boards), 1)
        T.eq(ns.Util.Count(ns.DB:GetActiveBoard().cards), 0)
        T.eq(#m.env.TaskboardLog.entries, 0)
        local saved = m.Logout()
        local m2, ns2 = T.client(nil, saved)
        T.eq(ns2.Util.Count(ns2.DB:GetActiveBoard().cards), 0)
        T.eq(ns2.db.settings.theme, "midnight")
        T.eq(#ns2.db.mailboxes, 0)
        T.noErrors(ns); T.noErrors(ns2)
    end)
end)

describe("Remaining agent-run QA checks", function()
    it("ED16 keeps filtered edits and live progress on the intended card", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local tracked = ns.Commands:Add("Get 5 Peacebloom #qa")
        local other = ns.Commands:Add("Unrelated task #qa")
        local owner = tracked.char
        ns.Board:Show()
        ns.Board.filter.text = "Peacebloom"
        ns.Board:Layout()
        ns.Editor:Open(tracked, board)
        T.ok(ns.DB:UpdateCard(board, tracked, { notes = "Filtered edit" }))
        m.Loot(2447, 2); m.Advance(1)
        T.eq(tracked.progress.cur, 2)
        T.ok(ns.DB:MoveCard(board, tracked.id, "doing"))
        T.eq(tracked.notes, "Filtered edit")
        T.eq(tracked.char, owner)
        T.eq(other.column, "todo")
        T.eq(other.notes, "")
        ns.Board.filter.text = ""
        ns.Board:Layout()
        T.eq(board.cards[tracked.id], tracked)
        T.eq(board.cards[other.id], other)
        T.noErrors(ns)
    end)

    it("GL19 refresh does not repeat completion statistics or feedback", function()
        local m, ns = T.client()
        local card = ns.Commands:Add("Save 100g")
        m.state.money = 100 * 10000
        m.Fire("PLAYER_MONEY"); m.Advance(1)
        T.eq(card.column, "done")
        local total, sounds = ns.db.stats.total, #m.sounds
        m.Slash("/tb refresh"); m.Advance(1)
        m.Slash("/tb refresh"); m.Advance(1)
        T.eq(card.column, "done")
        T.eq(ns.db.stats.total, total)
        T.eq(#m.sounds, sounds)
        T.noErrors(ns)
    end)

    it("MP02 and MP05 keep a pin separate from the current position and reminders", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local card = ns.Commands:Add("Meet friends")
        ns.Editor:Open(card, board)
        ns.Editor:PinHere()
        local x, y = card.pin.x, card.pin.y
        m.state.pos = { 0.25, 0.75 }
        ns.Editor:ShowPin(card)
        local waypoint = m.waypoints[#m.waypoints]
        T.ok(waypoint)
        T.near(waypoint.position.x, x)
        T.near(waypoint.position.y, y)
        T.eq(card.where, nil)
        local reminders = ns.Reminders.stats.shown
        m.state.pos = { x, y }; m.Fire("ZONE_CHANGED_NEW_AREA"); m.Advance(3)
        T.eq(ns.Reminders.stats.shown, reminders)
        T.eq(card.column, "todo")
        T.noErrors(ns)
    end)

    it("DG03 parses representative Help examples and executes documented commands", function()
        local m, ns = T.client()
        local plain = ns.Commands:Add("Visit the auction house")
        local item = ns.Commands:Add("get 17 Silverleaf")
        local destination = ns.Commands:Add('Buy supplies @"Stormwind City"')
        local repeatCard = ns.Commands:Add("Check auctions *daily")
        T.eq(plain.goal, nil)
        T.eq(item.goal.target, 17)
        T.eq(destination.where.zone, "Stormwind City")
        T.eq(repeatCard.recur, "daily")
        m.Slash("/tb list")
        T.ok(m.ChatContains("Visit the auction house"))
        m.Slash("/tb options")
        T.ok(ns.Options:Internals().frame:IsShown())
        m.Slash("/tb help")
        T.ok(ns.Help.frame:IsShown())
        T.noErrors(ns)
    end)

    it("DG10 lays out and filters two hundred varied cards across eight columns", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        for i = 1, 5 do T.ok(ns.DB:AddColumn(board, "Stage " .. i)) end
        local columns = ns.DB:StatusColumns(board)
        T.eq(#columns, 8)
        for i = 1, 200 do
            local text = string.format("QA performance task %03d with a long but readable title", i)
            if i % 7 == 0 then text = text .. "; first step; second step" end
            local card = ns.Commands:Add(text)
            T.ok(card)
            T.ok(ns.DB:MoveCard(board, card.id, columns[(i % 8) + 1].id))
        end
        ns.Board:Show(); ns.Board:Layout()
        T.eq(ns.Util.Count(board.cards), 201)
        ns.Board.filter.text = "performance task 179"
        ns.Board:Layout()
        T.eq(ns.Board:Internals().columns[1].count:GetText(), "0")
        T.noErrors(ns)
    end)
end)

