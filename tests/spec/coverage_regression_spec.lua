local T, Mock = ...

describe("High-risk QA coverage", function()
    it("IN03-04 BD11-16 preserves rich migrated cards, overflow and shared boards across edits and reloads", function()
        local columns = {
            { id = "todo", name = "To Do", role = "todo" },
            { id = "doing", name = "In Progress", role = "doing" },
            { id = "done", name = "Done", role = "done" },
        }
        for i = 1, 5 do columns[#columns + 1] = { id = "extra" .. i, name = "Stage " .. i } end
        local saved = { db = { boards = {
            first = { id = "first", name = "First", created = 100, columns = columns,
                cards = {
                    rich = { id = "rich", title = "Prepare supplies", notes = "Keep these notes", char = "Testchar-Forever",
                        column = "todo", priority = 3, tags = { "herbs", "urgent" }, recur = "daily",
                        goal = { type = "item", itemID = 765, name = "Silverleaf", target = 17 },
                        subtasks = { { id = "step", text = "Buy vials", done = true } } },
                    alt = { id = "alt", title = "Alt task", char = "Altchar-Forever", column = "doing" },
                    archived = { id = "archived", title = "Old result", char = "Testchar-Forever",
                        column = "done", archived = true, completedAt = 123 },
                }, order = { todo = { "rich" }, doing = { "alt" }, done = { "archived" } } },
            second = { id = "second", name = "Second", created = 200,
                columns = { { id = "todo", name = "To Do", role = "todo" },
                            { id = "doing", name = "In Progress", role = "doing" },
                            { id = "done", name = "Done", role = "done" },
                            { id = "review", name = "Review" } },
                cards = { overflow = { id = "overflow", title = "Review me", char = "Testchar-Forever", column = "review" } },
                order = { review = { "overflow" } } },
            shared = { id = "shared", name = "Friend's board", scope = "shared", owner = "Friend-Forever",
                shared = { from = "Friend-Forever", version = 2 },
                cards = { foreign = { id = "foreign", title = "Read only", column = "todo" } } },
        } } }
        local m, ns = T.client(nil, saved)
        local own = ns.DB:BoardForCharacter("Testchar-Forever")
        local alt = ns.DB:BoardForCharacter("Altchar-Forever")
        T.ok(own and alt)
        T.eq(ns.Util.Count(ns.db.boards), 3)
        T.eq(#own.columns, 8)
        T.eq(ns.DB:CardRole(own, own.cards.overflow), "doing", "overflow custom column maps to In Progress")
        T.eq(ns.DB:CardRole(own, own.cards.archived), "done")
        T.eq(own.cards.archived.archived, true)
        T.eq(own.cards.rich.notes, "Keep these notes")
        T.eq(own.cards.rich.priority, 3)
        T.eq(own.cards.rich.tags[1], "herbs")
        T.eq(own.cards.rich.goal.target, 17)
        T.eq(own.cards.rich.recur, "daily")
        T.eq(own.cards.rich.subtasks[1].done, true)
        T.ok(alt.cards.alt)
        T.ok(ns.db.boards.shared.cards.foreign)
        T.no(ns.DB:CanEdit(ns.db.boards.shared))
        T.ok(ns.DB:UpdateCard(own, own.cards.rich, { title = "Edited after upgrade" }))
        local firstSave = m.Logout()
        local n, again = T.client(nil, firstSave)
        T.eq(again.DB:BoardForCharacter("Testchar-Forever").cards.rich.title, "Edited after upgrade")
        T.eq(again.Util.Count(again.db.boards), 3)
        local _, third = T.client(nil, n.Logout())
        T.eq(third.Util.Count(third.db.boards), 3)
        T.eq(third.DB:BoardForCharacter("Testchar-Forever").cards.rich.title, "Edited after upgrade")
        T.noErrors(ns); T.noErrors(again); T.noErrors(third)
    end)

    it("TR11 TR17 locks tracker dragging and persists position and visibility across reload", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        T.ok(ns.DB:AddCard(board, { title = "Pinned task", track = true }))
        ns.Tracker:Refresh()
        local frame = ns.Tracker:Internals().frame
        local header
        for _, candidate in ipairs(m.frames) do
            if candidate._parent == frame and candidate:GetScript("OnDragStart") then header = candidate; break end
        end
        T.ok(header, "tracker drag handle exists")
        local starts = 0
        frame.StartMoving = function() starts = starts + 1 end
        header:GetScript("OnDragStart")(header)
        T.eq(starts, 1)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", m.env.UIParent, "TOPLEFT", 120, -150)
        header:GetScript("OnDragStop")(header)
        T.eq(ns.db.ui.tracker.x, 120)
        ns.db.settings.trackerLocked = true
        header:GetScript("OnDragStart")(header)
        T.eq(starts, 1, "locked tracker cannot start moving")
        ns.db.ui.trackerCollapsed = true
        ns.db.settings.trackerShown = false
        local n, again = T.client(nil, m.Logout())
        T.eq(again.db.ui.tracker.x, 120)
        T.eq(again.db.ui.tracker.y, -150)
        T.eq(again.db.ui.trackerCollapsed, true)
        T.eq(again.db.settings.trackerShown, false)
        T.eq(again.db.settings.trackerLocked, true)
        again.db.settings.trackerShown = true
        again.Tracker:Refresh()
        local point, _, _, x, y = again.Tracker:Internals().frame:GetPoint(1)
        T.eq(point, "TOPLEFT"); T.eq(x, 120); T.eq(y, -150)
        local reloadedHeader
        for _, candidate in ipairs(n.frames) do
            if candidate._parent == again.Tracker:Internals().frame and candidate:GetScript("OnDragStart") then
                reloadedHeader = candidate; break
            end
        end
        T.ok(reloadedHeader)
        local resumed = 0
        again.Tracker:Internals().frame.StartMoving = function() resumed = resumed + 1 end
        reloadedHeader:GetScript("OnDragStart")(reloadedHeader)
        T.eq(resumed, 0)
        again.db.settings.trackerLocked = false
        reloadedHeader:GetScript("OnDragStart")(reloadedHeader)
        T.eq(resumed, 1, "unlock restores drag after reload")
        T.noErrors(ns); T.noErrors(again)
    end)

    it("RC16 completes a daily check-mail task once per period", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local card = ns.Commands:Add("Check mail @mail *daily")
        m.Fire("MAIL_SHOW")
        T.eq(ns.DB:CardRole(board, card), "done")
        T.eq(ns.db.stats.total, 1)
        m.Fire("MAIL_CLOSED")
        ns.db.resets.nextDaily = m.now + 2
        m.AdvanceTime(65)
        T.eq(ns.DB:CardRole(board, card), "todo")
        T.eq(ns.db.stats.total, 1, "reset adds no completion")
        m.Fire("MAIL_SHOW")
        T.eq(ns.DB:CardRole(board, card), "done")
        T.eq(ns.db.stats.total, 2)
        m.Fire("MAIL_CLOSED"); m.Fire("MAIL_SHOW")
        T.eq(ns.db.stats.total, 2, "repeat mail open adds no duplicate completion")
        T.noErrors(ns)
    end)

    it("MB08 MB19 keeps learned mailbox locations separate across maps and missing coordinates", function()
        local m, ns = T.client()
        m.Fire("MAIL_SHOW"); m.Fire("MAIL_CLOSED")
        T.eq(#ns.db.mailboxes, 1)
        m.state.mapID = 1453
        m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox(), "same coordinates on another map are not a mailbox")
        m.Fire("MAIL_SHOW"); m.Fire("MAIL_CLOSED")
        T.eq(#ns.db.mailboxes, 2)
        m.state.pos = { 0.60, 0.65 }; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox())
        m.state.pos = { 0.42, 0.65 }; m.Advance(3)
        T.ok(ns.Reminders:IsNearMailbox(), "second map mailbox is active")
        m.state.mapID = 1454; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox(), "a third map has no learned mailbox")
        local get = m.env.C_Map.GetPlayerMapPosition
        m.env.C_Map.GetPlayerMapPosition = function() return nil end
        m.state.mapID = 1429; m.Advance(3)
        T.no(ns.Reminders:IsNearMailbox(), "missing coordinates do not reuse an old spot")
        m.env.C_Map.GetPlayerMapPosition = get
        m.Advance(3)
        T.ok(ns.Reminders:IsNearMailbox(), "proximity recovers when coordinates return")
        T.noErrors(ns)
    end)
end)
