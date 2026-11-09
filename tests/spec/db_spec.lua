local T, Mock = ...

describe("DB", function()
    it("creates a default board with a welcome card on first login", function()
        local m, ns = T.client()
        local boards = ns.DB:VisibleBoards()
        T.eq(#boards, 1)
        local board = boards[1]
        T.eq(board.name, "My Tasks")
        T.eq(#board.columns, 3)
        T.eq(board.columns[1].role, "todo")
        T.eq(board.columns[3].role, "done")
        T.eq(#board.order.todo, 1)
        local welcome = board.cards[board.order.todo[1]]
        T.eq(welcome.title, "Welcome to Taskboard - start here")
        T.contains(welcome.notes, "Quick Add")
        T.contains(welcome.notes, "shift-clicking an item")
        T.contains(welcome.notes, "/tb")
        T.eq(#welcome.subtasks, 3)
        T.eq(ns.DB:GetActiveBoard(), board)
        T.noErrors(ns)
    end)

    it("adds, moves, reorders and deletes cards", function()
        local m, ns = T.client()
        local DB = ns.DB
        local board = DB:GetActiveBoard()
        local a = DB:AddCard(board, { title = "A" })
        local b = DB:AddCard(board, { title = "B" })
        local c = DB:AddCard(board, { title = "C" })
        T.eq(board.order.todo[4], c.id)
        T.eq(a.char, "Testchar-Forever", "cards belong to the current character")
        DB:MoveCard(board, c.id, "todo", 1)
        T.eq(board.order.todo[1], c.id, "moved to top")
        DB:MoveCard(board, c.id, "todo", 4)
        T.eq(board.order.todo[3], c.id, "moving down within a column accounts for removal")
        DB:MoveCard(board, a.id, "done")
        T.eq(a.column, "done")
        T.ok(a.completedAt, "completion time set")
        DB:MoveCard(board, a.id, "doing")
        T.eq(a.completedAt, nil, "cleared when leaving Done")
        T.ok(a.auto.hold, "manual move out of Done holds auto-complete")
        T.ok(DB:DeleteCard(board, b.id))
        T.eq(board.cards[b.id], nil)
        for _, list in pairs(board.order) do
            for _, id in ipairs(list) do T.ok(board.cards[id], "no dangling ids") end
        end
        T.noErrors(ns)
    end)

    it("manages columns and protects the core roles", function()
        local m, ns = T.client()
        local DB = ns.DB
        local board = DB:GetActiveBoard()
        local col = DB:AddColumn(board, "Blocked")
        T.eq(board.columns[3].id, col.id, "new columns go before Done")
        T.ok(DB:RenameColumn(board, "todo", "Backlog"))
        T.eq(board.columns[1].name, "Backlog")
        T.eq(board.columns[1].role, "todo", "renaming keeps the role")
        local ok, err = DB:RemoveColumn(board, "done")
        T.no(ok)
        T.ok(err)
        local card = DB:AddCard(board, { title = "x" }, col.id)
        T.no(DB:RemoveColumn(board, col.id), "can't remove a column with cards")
        DB:MoveCard(board, card.id, "todo")
        T.ok(DB:RemoveColumn(board, col.id))
    end)

    it("repairs damaged saved data", function()
        local saved = { db = {
            schema = 1,
            boards = {
                b1 = { id = "b1", name = "Broken", columns = { { id = "todo", name = "To Do", role = "todo" }, { id = "x", role = "nonsense" } },
                       cards = {
                           c1 = { id = "c1", title = "ok", column = "todo" },
                           c2 = { id = "c2", title = "", column = "todo" },
                           c3 = { id = "c3", title = "orphan", column = "gone" },
                           c4 = "not a table",
                           c5 = { id = "c5", title = "bad goal", column = "todo", goal = { type = "hack", target = "x" } },
                       },
                       order = { todo = { "c1", "c1", "missing" } } },
                junk = "nope",
            },
            settings = { autoStart = false },
        } }
        local m, ns = T.client(nil, saved)
        local board = ns.db.boards.b1
        T.ok(board, "board kept")
        T.eq(ns.db.settings.autoStart, false, "settings kept")
        T.eq(ns.db.settings.autoComplete, true, "missing settings defaulted")
        T.ok(ns.DB:ColumnByRole(board, "doing"), "missing roles added")
        T.ok(ns.DB:ColumnByRole(board, "done"))
        T.ok(board.cards.c1)
        T.eq(board.cards.c2, nil, "empty title dropped")
        T.ok(board.cards.c3, "orphan card kept")
        T.eq(board.cards.c3.column, board.columns[1].id, "orphan moved to first column")
        T.eq(board.cards.c5.goal, nil, "invalid goal removed")
        local seen = {}
        for _, list in pairs(board.order) do
            for _, id in ipairs(list) do
                T.no(seen[id], "each card placed once")
                seen[id] = true
                T.ok(board.cards[id])
            end
        end
        T.ok(seen.c3 and seen.c1 and seen.c5)
        T.eq(ns.db.boards.junk, nil)
        T.ok(ns.DB.lastRepairs > 0)
        T.noErrors(ns)
    end)

    it("enforces limits on untrusted cards", function()
        local m, ns = T.client()
        local card = ns.DB.NormalizeCard({ title = string.rep("x", 1000), notes = string.rep("n", 5000), priority = 99,
            tags = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }, subtasks = (function()
                local s = {} for i = 1, 40 do s[i] = { text = "s" .. i } end return s end)() })
        T.eq(#card.title, ns.DB.LIMITS.title)
        T.eq(#card.notes, ns.DB.LIMITS.notes)
        T.eq(card.priority, 3)
        T.eq(#card.tags, ns.DB.LIMITS.tags)
        T.eq(#card.subtasks, ns.DB.LIMITS.subtasks)
    end)

    it("gives each character one board and makes both boards visible on alts", function()
        local m, ns = T.client()
        local mine = ns.DB:GetActiveBoard()
        T.eq(mine.owner, "Testchar-Forever")
        T.eq(ns.DB:CreateBoard("Extra", "character"), mine)
        local saved = m.Logout()
        local m2, ns2 = T.client({ name = "Altchar" }, saved)
        T.eq(#ns2.DB:VisibleBoards(), 2)
        T.eq(ns2.DB:GetActiveBoard().owner, "Altchar-Forever")
        T.ok(ns2.db.boards[mine.id])
    end)

    it("merges older local boards by character without losing card status", function()
        local saved = { db = { boards = {
            a = { id = "a", name = "First", cards = {
                c1 = { id = "c1", title = "To do", char = "Testchar-Forever", column = "todo" },
                c2 = { id = "c2", title = "Alt task", char = "Altchar-Forever", column = "doing" },
            } },
            b = { id = "b", name = "Second", scope = "character", owner = "Testchar-Forever", cards = {
                c3 = { id = "c3", title = "Finished", char = "Testchar-Forever", column = "done" },
            } },
        } } }
        local m, ns = T.client(nil, saved)
        T.eq(#ns.DB:VisibleBoards(), 2)
        local own = ns.DB:BoardForCharacter("Testchar-Forever")
        local alt = ns.DB:BoardForCharacter("Altchar-Forever")
        T.ok(own.cards.c1 and own.cards.c3 and alt.cards.c2)
        T.eq(ns.DB:CardRole(own, own.cards.c3), "done")
        local _, again = T.client(nil, m.Logout())
        T.eq(#again.DB:VisibleBoards(), 2)
        T.noErrors(ns); T.noErrors(again)
    end)
end)
