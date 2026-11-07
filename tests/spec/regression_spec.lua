local T = ...

local function grouped()
    return T.client({ setup = function(m) m.state.inGroup = true end })
end
local function shared(ns, title, cycle)
    return ns.DB.NormalizeBoard({ id = "remote", name = "Remote board", cards = {
        c = { id = "c", title = title or "Remote task", recurCycle = cycle },
    } })
end

describe("Review regressions: editor and ownership", function()
    it("commits focused fields to the original card before switching", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local a, b = ns.Commands:Add("A"), ns.Commands:Add("B")
        ns.Editor:Open(a, board)
        local ui = ns.Editor:Internals().ui
        for _, field in ipairs({ "title", "tags", "notes" }) do
            ns.Editor:Open(a, board)
            ui[field]:SetFocus()
            ui[field]:SetText("edited")
            ns.Editor:Open(b, board)
            ui[field]:ClearFocus()
        end
        T.eq(a.title, "edited")
        T.eq(a.tags[1], "edited")
        T.eq(a.notes, "edited")
        T.eq(b.title, "B")
        T.eq(#b.tags, 0)
        T.eq(b.notes, "")
        T.noErrors(ns)
    end)

    it("rebinds an open editor after an owner replaces a shared board", function()
        local m, ns = grouped()
        local old = shared(ns, "Old")
        ns.Sync:Import(old, "Alice-Forever", "PARTY", 1)
        ns.Editor:Open(old.cards.c, old)
        T.ok(ns.Sync:HandlePayload({ k = "board", v = 2, board = shared(ns, "New") }, "Alice-Forever", "PARTY"))
        local card, board = ns.Editor:Current()
        T.eq(card.title, "New")
        T.eq(board, ns.db.boards.remote)
        T.noErrors(ns)
    end)

    it("closes the editor when its board is deleted", function()
        local m, ns = T.client()
        local b = ns.DB:GetActiveBoard()
        ns.Editor:Open(ns.Commands:Add("A"), b)
        ns.DB:DeleteBoard(b)
        T.no(ns.Editor:Internals().frame:IsShown())
        T.noErrors(ns)
    end)

    it("text imports reassign goals and clear foreign progress", function()
        local ma, a = T.client({ name = "Alice" })
        local card = a.Commands:Add("20 Peacebloom")
        local text = assert(a.Serialize.Export(a.DB:GetActiveBoard()))
        local mb, b = T.client({ name = "Bob" })
        b.LogWindow:ShowImport()
        b.LogWindow:Internals().box:SetText(text)
        b.LogWindow:DoImport()
        local board = b.DB:GetActiveBoard()
        local imported = board.cards[card.id]
        T.eq(imported.char, "Bob-Forever")
        mb.Loot(2447, 20); mb.Advance(1)
        T.eq(imported.column, "done")
        T.noErrors(b)
    end)

    it("guards all shared-board mutations, including slash completion", function()
        local m, ns = grouped()
        local b = shared(ns)
        ns.Sync:Import(b, "Alice-Forever", "PARTY", 1)
        ns.DB:SetActiveBoard(b)
        ns.Commands:Done("Remote task")
        T.eq(b.cards.c.column, "todo")
        T.eq(ns.db.stats.total, 0)
        T.no(ns.DB:UpdateCard(b, b.cards.c, { title = "changed" }))
        T.no(ns.DB:DeleteCard(b, "c"))
        T.no(ns.DB:AddCard(b, { title = "added" }))
        T.no(ns.DB:RenameBoard(b, "changed"))
        T.no(ns.DB:AddColumn(b, "new"))
        T.no(ns.DB:RenameColumn(b, "todo", "changed"))
        T.no(ns.DB:RemoveColumn(b, "todo"))
        T.eq(b.cards.c.title, "Remote task")
        T.noErrors(ns)
    end)

    it("invalid updates leave the original card intact", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("Original")
        T.no(ns.DB:UpdateCard(ns.DB:GetActiveBoard(), c, { title = "" }))
        T.eq(c.title, "Original")
    end)
end)

describe("Review regressions: reset periods", function()
    it("resets hidden character boards when an alt logs in first", function()
        local ma, a = T.client({ name = "Alice" })
        local ba = a.DB:CreateBoard("Alice daily", "character")
        a.DB:SetActiveBoard(ba)
        local ca = a.Commands:Add("Daily *daily")
        a.DB:MoveCard(ba, ca.id, "done")
        local saved = ma.Logout(); saved.db.resets.nextDaily = ma.now + 10
        local mb, b = T.client({ name = "Bob", now = ma.now + 20 }, saved)
        local mc, c = T.client({ name = "Alice", now = ma.now + 30 }, mb.Logout())
        T.eq(c.db.boards[ba.id].cards[ca.id].column, "todo")
        T.eq(c.db.boards[ba.id].cards[ca.id].streak, 1)
        T.noErrors(b); T.noErrors(c)
    end)

    it("counts extra inventory in the new period without double-completing", function()
        local m, ns = T.client()
        local b = ns.DB:GetActiveBoard()
        m.Loot(2447, 7)
        local c = ns.Commands:Add("20 Peacebloom *daily")
        T.eq(c.goal.baseline, 7)
        m.Loot(2447, 20); m.Advance(1)
        T.eq(c.column, "done"); T.eq(ns.db.stats.total, 1)
        ns.Recurring:Reset("daily"); m.Advance(1)
        T.eq(c.column, "todo"); T.eq(c.progress.cur, 0)
        T.eq(ns.db.stats.total, 1)
        m.Loot(2447, 20); m.Advance(1)
        T.eq(c.column, "done"); T.eq(ns.db.stats.total, 2)
        T.noErrors(ns)
    end)

    it("persists a gain baseline through logout and reload", function()
        local m, ns = T.client()
        m.Loot(2447, 5)
        local c = ns.Commands:Add("20 Peacebloom *daily")
        m.Loot(2447, 6); m.Advance(1)
        local bid = ns.DB:GetActiveBoard().id
        local m2, n2 = T.client({ setup = function(mm) mm.Loot(2447, 11, true) end }, m.Logout())
        local c2 = n2.db.boards[bid].cards[c.id]
        T.eq(c2.goal.baseline, 5); T.eq(c2.progress.cur, 6)
        T.noErrors(n2)
    end)

    it("counts the first loot of a previously unknown recurring item", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("2 Mystery Widget *daily")
        T.eq(c.goal.baseline, 0)
        m.Loot(9999, 2); m.Advance(1)
        T.eq(c.progress.cur, 2); T.eq(c.column, "done")
    end)

    it("stock mode waits for an incomplete state before completing again", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("2 Peacebloom *daily")
        ns.DB:UpdateCard(ns.DB:GetActiveBoard(), c, { recurItems = "stock" })
        m.Loot(2447, 2); m.Advance(1)
        ns.Recurring:Reset("daily"); m.Advance(1)
        T.eq(c.column, "todo"); T.eq(ns.db.stats.total, 1)
        m.RemoveItem(2447, 2); m.Advance(1)
        m.Loot(2447, 2); m.Advance(1)
        T.eq(c.column, "done"); T.eq(ns.db.stats.total, 2)
    end)

    it("missed periods break streaks and archives stay untouched", function()
        local m, ns = T.client()
        local b = ns.DB:GetActiveBoard()
        local c = ns.Commands:Add("Daily *daily")
        local archived = ns.Commands:Add("Archived *daily")
        ns.DB:MoveCard(b, c.id, "done"); c.streak = 5
        ns.DB:MoveCard(b, archived.id, "done"); archived.archived = true
        ns.Recurring:Reset("daily", 3)
        T.eq(c.streak, 0); T.eq(archived.column, "done")
    end)

    it("owner updates preserve local baselines until the cycle changes", function()
        local m, ns = grouped()
        m.Loot(2447, 5)
        local b = shared(ns)
        b.cards.c.recur = "daily"; b.cards.c.recurCycle = 1
        b.cards.c.goal = { type = "item", itemID = 2447, name = "Peacebloom", target = 20, bank = true }
        ns.Sync:Import(b, "Alice-Forever", "PARTY", 1); m.Advance(1)
        T.eq(b.cards.c.goal.baseline, 5)
        local replacement = ns.DB.NormalizeBoard(b)
        m.Loot(2447, 3); m.Advance(1)
        ns.Sync:Import(replacement, "Alice-Forever", "PARTY", 2, b); m.Advance(1)
        T.eq(replacement.cards.c.goal.baseline, 5)
        T.eq(replacement.cards.c.progress.cur, 3)
        local nextCycle = ns.DB.NormalizeBoard(replacement); nextCycle.cards.c.recurCycle = 2
        ns.Sync:Import(nextCycle, "Alice-Forever", "PARTY", 3, replacement); m.Advance(1)
        T.eq(nextCycle.cards.c.goal.baseline, 8)
        T.eq(nextCycle.cards.c.progress.cur, 0)
    end)
end)

describe("Review regressions: sharing and serialization", function()
    it("retries throttled chunks in order, without dropping or duplicating", function()
        local m, ns = grouped()
        local send = m.env.C_ChatInfo.SendAddonMessage
        local calls = 0
        m.env.C_ChatInfo.SendAddonMessage = function(...)
            calls = calls + 1
            if calls <= 2 then return calls == 1 and 3 or 8 end
            return send(...)
        end
        local ok, count = ns.Sync:Send({ k = "test", blob = string.rep("x", 900) }, "PARTY")
        T.ok(ok)
        m.Advance(0.2); T.eq(ns.Sync:QueueLength(), count)
        m.Advance(4); T.eq(ns.Sync:QueueLength(), 0); T.eq(#m.sent, count)
        local payload
        for _, msg in ipairs(m.sent) do payload = ns.Sync.Receive("Alice", msg.text) or payload end
        T.eq(payload.blob, string.rep("x", 900)); T.noErrors(ns)
    end)

    it("abandons a whole transfer on terminal failure", function()
        local m, ns = grouped()
        m.env.C_ChatInfo.SendAddonMessage = function() return 5 end
        ns.Sync:Send({ blob = string.rep("x", 900) }, "PARTY")
        m.Advance(0.2)
        T.eq(ns.Sync:QueueLength(), 0)
        T.ok(m.ChatContains("Please share the board again"))
    end)

    it("bounds persistent throttling and queue growth", function()
        local m, ns = grouped()
        m.env.C_ChatInfo.SendAddonMessage = function() return 3 end
        ns.Sync:Send({ k = "test" }, "PARTY")
        m.Advance(30); T.eq(ns.Sync:QueueLength(), 0)
        ns.Sync.MAX_QUEUE = 1
        T.no(ns.Sync:Send({ blob = string.rep("x", 900) }, "PARTY"))
        T.eq(ns.Sync:QueueLength(), 0)
    end)

    it("rejects oversized shares before queuing any chunks", function()
        local m, ns = grouped()
        local msgs, why = ns.Sync.Encode({ blob = string.rep("a", 61000) })
        T.no(msgs); T.contains(why, "too large")
        local valid = assert(ns.Sync.Encode({ blob = string.rep("a", 59000) }))
        local result
        for _, msg in ipairs(valid) do result = ns.Sync.Receive("Alice", msg) or result end
        T.eq(#result.blob, 59000)
    end)

    it("round-trips a maximum-size normalized board through text export", function()
        local m, ns = T.client()
        local raw = { name = "Full", cards = {} }
        for i = 1, ns.DB.LIMITS.cards do
            local subs = {}
            for j = 1, ns.DB.LIMITS.subtasks do
                subs[j] = { text = string.rep("s", 200), goal = { type = "item", name = "Peacebloom", itemID = 2447, target = 20 } }
            end
            raw.cards["c" .. i] = { id = "c" .. i, title = string.rep("t", 200), notes = string.rep("n", 2000), subtasks = subs }
        end
        local b = ns.DB.NormalizeBoard(raw)
        local text, err = ns.Serialize.Export(b); T.ok(text, err)
        local back, why = ns.Serialize.Import(text); T.ok(back, why)
        T.eq(ns.Util.Count(back.cards), 400)
        T.eq(#back.cards.c400.subtasks, 25)
    end)

    it("serializer rejects non-finite and unroundtrippable values", function()
        local m, ns = T.client()
        T.no(ns.Serialize.Unpack("N1e999;"))
        T.no(ns.Serialize.Pack(string.rep("x", 65537)))
        local t = {}; for i = 1, 11000 do t[i] = i end
        T.no(ns.Serialize.Pack(t))
        T.no(ns.Serialize.Unpack("TS1:aB1S1:aB0t"))
    end)

    it("rejects whispers and cross-channel progress injection", function()
        local m, ns = grouped()
        local payload = { k = "board", v = 1, board = shared(ns) }
        for _, text in ipairs(assert(ns.Sync.Encode(payload))) do
            m.Fire("CHAT_MSG_ADDON", ns.Sync.PREFIX, text, "WHISPER", "Stranger-Forever")
        end
        T.eq(ns.Util.Count(ns.Sync.offers), 0)
        local b = shared(ns); ns.Sync:Import(b, "Alice-Forever", "PARTY", 1)
        m.state.inGuild = true
        T.no(ns.Sync:HandlePayload({ k = "prog", b = b.id, c = { c = { f = 1000 } } }, "Eve-Forever", "GUILD"))
        T.eq(ns.Util.Count(b.shared.members), 0)
    end)

    it("bounds, deduplicates and expires pending offers", function()
        local m, ns = grouped()
        local p = { k = "board", v = 1, board = shared(ns) }
        for i = 1, 20 do T.ok(ns.Sync:HandlePayload(p, "Alice-Forever", "PARTY")) end
        T.eq(ns.Util.Count(ns.Sync.offers), 1)
        T.eq(#m.popups, 1)
        local offer = next(ns.Sync.offers)
        m.now = m.now + 61
        T.no(ns.Sync:AcceptOffer(offer))
        T.eq(ns.Util.Count(ns.Sync.offers), 0)
    end)

    it("rechecks collisions and permissions when accepting an offer", function()
        local m, ns = grouped()
        local b = shared(ns)
        T.ok(ns.Sync:HandlePayload({ k = "board", v = 1, board = b }, "Alice-Forever", "PARTY"))
        local id = next(ns.Sync.offers)
        ns.db.boards[b.id] = ns.DB.NormalizeBoard({ id = b.id, name = "Local" })
        T.no(ns.Sync:AcceptOffer(id)); T.eq(ns.db.boards[b.id].name, "Local")
        ns.db.boards[b.id] = nil
        T.ok(ns.Sync:HandlePayload({ k = "board", v = 1, board = b }, "Alice-Forever", "PARTY"))
        ns.db.settings.syncAccept = "never"
        T.no(ns.Sync:AcceptOffer(next(ns.Sync.offers)))
    end)

    it("sanitizes every rendered card field while keeping note newlines", function()
        local m, ns = T.client()
        local markup = "|TInterface\\Icons\\INV_Misc_Note_01:999|tHello"
        local c = ns.DB.NormalizeCard({ title = markup, notes = markup .. "\nsecond line", subtasks = { { text = markup } } })
        T.eq(c.title, "Hello"); T.eq(c.notes, "Hello\nsecond line"); T.eq(c.subtasks[1].text, "Hello")
    end)

    it("repairs columns without duplicate truncated ids or exceeding the limit", function()
        local m, ns = T.client()
        local cols = {}; for i = 1, 8 do cols[i] = { id = "custom" .. i } end
        cols[9] = { id = string.rep("x", 30) }
        local b = ns.DB.NormalizeBoard({ columns = cols })
        T.eq(#b.columns, 8)
        T.ok(ns.DB:ColumnByRole(b, "todo")); T.ok(ns.DB:ColumnByRole(b, "doing")); T.ok(ns.DB:ColumnByRole(b, "done"))
    end)
end)

describe("Review regressions: truthful diagnostics and persistence", function()
    it("fails selftest for dangling ids and missing live APIs", function()
        local m, ns = T.client()
        table.insert(ns.DB:GetActiveBoard().order.todo, "missing")
        m.env.C_Item.GetItemCount = nil
        local p, f, lines = ns.Diagnostics:SelfTest()
        T.ok(f >= 2)
        T.contains(table.concat(lines, "\n"), "FAIL db: all boards valid")
        T.contains(table.concat(lines, "\n"), "FAIL api: GetItemCount")
    end)

    it("cleans actual SavedVariables before the mock copies them", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("20 Peacebloom *daily")
        T.ok(c._summary)
        m.Fire("PLAYER_LOGOUT")
        local db = rawget(m.env, "TaskboardDB")
        local saved = db.boards[ns.DB:GetActiveBoard().id].cards[c.id]
        T.eq(saved._summary, nil); T.eq(saved.goal._last, nil)
        T.eq(saved.goal.baseline, 0, "baseline is persistent state, not a cache")
    end)
end)

describe("Release usability", function()
    it("provides horizontal scrolling for eight columns in a narrow board", function()
        local m, ns = T.client()
        local b = ns.DB:GetActiveBoard()
        for i = 1, 5 do ns.DB:AddColumn(b, "Extra " .. i) end
        ns.Board:Show()
        local ui = ns.Board:Internals()
        ui.frame:SetWidth(600); ns.Board:Layout()
        T.ok(ui.horizontalScroll:IsShown())
        local low, high = ui.horizontalScroll:GetMinMaxValues()
        T.eq(low, 0); T.ok(high > 0)
        ui.horizontalScroll:SetValue(high)
        T.eq(ui.viewport:GetHorizontalScroll(), high)
        ui.frame:SetWidth(1600); ns.Board:Layout()
        T.no(ui.horizontalScroll:IsShown())
        T.noErrors(ns)
    end)

    it("does not recycle card frames during a drag", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("20 Peacebloom")
        ns.Board:Show()
        local f
        for _, row in ipairs(ns.Board:Internals().cards) do if row.card == c then f = row end end
        ns.Board:BeginDrag(f)
        m.Loot(2447, 1); m.Advance(1)
        T.eq(f.card, c); T.ok(ns.Board:IsDragging())
        ns.Board:EndDrag()
        T.no(ns.Board:IsDragging()); T.noErrors(ns)
    end)

    it("stop sharing cancels queued board messages", function()
        local m, ns = grouped()
        local b = ns.DB:GetActiveBoard()
        T.ok(ns.Sync:ShareBoard(b, "party")); T.ok(ns.Sync:QueueLength() > 0)
        ns.Sync:StopSharing(b)
        T.eq(ns.Sync:QueueLength(), 0)
        m.Advance(10); T.eq(#m.sent, 0)
    end)

    it("bank setting changes establish a new gain baseline", function()
        local m, ns = T.client()
        local c = ns.Commands:Add("20 Peacebloom *daily")
        m.Loot(2447, 5); m.Advance(1)
        T.eq(c.progress.cur, 5)
        ns.db.settings.includeBank = false
        ns.Engine:MarkAll(); m.Advance(1)
        T.eq(c.progress.cur, 0)
        T.eq(c.goal.baselineBank, false)
        m.Loot(2447, 2); m.Advance(1)
        T.eq(c.progress.cur, 2)
    end)
end)
