local T, Mock = ...

describe("SavedVariables", function()
    it("everything survives a /reload, and runtime caches are not saved", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local a = ns.Commands:Add("Get 20 Peacebloom #herbs !high @bank *daily; 5 Silverleaf")
        local b = ns.Commands:Add("Second")
        m.Loot(2447, 6)
        m.Advance(1)
        ns.DB:MoveCard(board, b.id, "todo", 1)
        ns.db.settings.sounds = false
        m.Slash("/tb")
        local saved = m.Logout()

        -- Runtime caches (keys starting with "_") are never written.
        local function scan(t, path)
            for k, v in pairs(t) do
                T.no(type(k) == "string" and k:sub(1, 1) == "_", "saved cache key at " .. path .. "." .. tostring(k))
                if type(v) == "table" then scan(v, path .. "." .. tostring(k)) end
            end
        end
        scan(saved.db, "TaskboardDB")

        local m2, ns2 = T.client(nil, saved)
        local board2 = ns2.db.boards[board.id]
        T.ok(board2)
        local a2 = board2.cards[a.id]
        T.eq(a2.title, "Get 20 Peacebloom")
        T.eq(a2.priority, 3)
        T.eq(a2.tags[1], "herbs")
        T.eq(a2.where.npc, "bank")
        T.eq(a2.recur, "daily")
        T.eq(a2.goal.itemID, 2447)
        T.eq(a2.subtasks[1].goal.itemID, 765)
        T.eq(ns2.DB:CardRole(board2, a2), "doing")
        T.eq(board2.order.todo[1], b.id, "order kept")
        T.eq(ns2.db.settings.sounds, false)
        T.eq(rawget(m2.env, "TaskboardLog").sessions, 2)
        T.ok(#ns2.Log:GetEntries() > 3, "log tail kept across sessions")
        -- Live tracking resumes after login (bags are per-session in the mock; refill them).
        m2.Loot(2447, 20)
        m2.Advance(3)
        T.eq(a2.progress.text, "Peacebloom (extra this day) 20/20")
        T.noErrors(ns2)
    end)

    it("starts cleanly from nil, empty or garbage saved variables", function()
        for _, saved in ipairs({ { db = nil }, { db = {} }, { db = "oops", log = 7 }, { db = { boards = "x", settings = 5, stats = {} } } }) do
            local ok, err = pcall(function()
                local m, ns = T.client(nil, saved)
                T.eq(#ns.DB:VisibleBoards(), 1)
                T.noErrors(ns)
            end)
            T.ok(ok, tostring(err))
        end
    end)

    it("caps the persisted log", function()
        local m, ns = T.client()
        for i = 1, 500 do ns.Log:Info("test", "line %d", i) end
        T.eq(ns.Log:Count(), ns.Log.MAX)
        local saved = m.Logout()
        T.eq(#saved.log.entries, ns.Log.MAX)
        T.contains(saved.log.entries[#saved.log.entries].m, "line 500")
    end)
end)

