local T, Mock = ...

describe("Recurring cards", function()
    it("daily reset moves done cards back with a streak, resets unfinished streaks", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local done = ns.Commands:Add("Daily cooking *daily; fish; cook")
        ns.DB:UpdateCard(board, done, { notes = "Keep the recipe" })
        local open = ns.Commands:Add("Daily fishing *daily")
        open.streak = 4
        done.subtasks[1].done = true
        ns.DB:MoveCard(board, done.id, "done")
        T.ok(ns.db.resets.nextDaily, "next reset scheduled")
        m.AdvanceTime(3600 * 10 + 61) -- past the daily reset (ticker checks every 60s)
        T.eq(ns.DB:CardRole(board, done), "todo")
        T.eq(done.title, "Daily cooking")
        T.eq(done.notes, "Keep the recipe")
        T.eq(done.streak, 1)
        T.eq(done.subtasks[1].done, false, "subtasks cleared")
        T.eq(open.streak, 0, "missed day resets the streak")
        T.ok(ns.db.resets.nextDaily > m.now, "next reset moved forward")
        T.noErrors(ns)
    end)

    it("weekly cards are untouched by the daily reset", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local weekly = ns.Commands:Add("Raid *weekly")
        ns.DB:MoveCard(board, weekly.id, "done")
        m.state.dailyReset = m.now + 100
        ns.db.resets.nextDaily = m.now + 100
        m.state.weeklyReset = m.now + 86400 * 3
        m.AdvanceTime(200)
        T.eq(ns.DB:CardRole(board, weekly), "done")
        m.AdvanceTime(86400 * 3)
        T.eq(ns.DB:CardRole(board, weekly), "todo")
        T.eq(weekly.streak, 1)
    end)

    it("catches up on login after a reset passed while offline", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local card = ns.Commands:Add("Daily thing *daily")
        ns.DB:MoveCard(board, card.id, "done")
        local saved = m.Logout()
        saved.db.resets.nextDaily = m.now - 10
        local m2, ns2 = T.client({ now = m.now + 3600 }, saved)
        local c2 = ns2.db.boards[board.id].cards[card.id]
        T.eq(ns2.DB:CardRole(ns2.db.boards[board.id], c2), "todo")
    end)
end)

describe("Stats", function()
    it("tracks day streaks across days", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        local S = ns.Stats
        S:Record({ title = "a" }, board, m.now)
        S:Record({ title = "b" }, board, m.now + 86400)
        S:Record({ title = "c" }, board, m.now + 2 * 86400)
        T.eq(S:Streak(m.now + 2 * 86400), 3)
        T.eq(S:Streak(m.now + 5 * 86400), 0, "streak lapses")
        S:Record({ title = "d" }, board, m.now + 5 * 86400)
        T.eq(S:Streak(m.now + 5 * 86400), 1)
        T.eq(ns.db.stats.total, 4)
    end)

    it("caps history", function()
        local m, ns = T.client()
        local board = ns.DB:GetActiveBoard()
        for i = 1, 520 do ns.Stats:Record({ title = "x" .. i }, board, m.now) end
        T.eq(#ns.db.stats.history, ns.Stats.MAX_HISTORY)
        T.eq(ns.db.stats.history[#ns.db.stats.history].title, "x520")
    end)
end)


