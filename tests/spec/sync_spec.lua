local T, Mock = ...

-- Delivers everything `from` sent to `to`, as if over the party channel.
local function deliver(from, to, sender, reverse)
    local list = from.sent
    from.sent = {}
    if reverse then
        local r = {}
        for i = #list, 1, -1 do r[#r + 1] = list[i] end
        list = r
    end
    for _, msg in ipairs(list) do
        to.Fire("CHAT_MSG_ADDON", msg.prefix, msg.text, msg.channel, sender)
    end
    return #list
end

local function grouped(name)
    return { name = name, setup = function(m) m.state.inGroup = true end }
end

describe("Sync wire format", function()
    it("chunks big payloads and reassembles them in any order", function()
        local m, ns = T.client()
        local S = ns.Sync
        local payload = { k = "test", blob = string.rep("abc|~:", 400) }
        local messages = assert(S.Encode(payload))
        T.ok(#messages > 3, "split into several messages")
        for _, text in ipairs(messages) do T.ok(#text <= 255, "fits an addon message") end
        local result
        for i = #messages, 1, -1 do
            local got, err = S.Receive("Bob-Forever", messages[i])
            T.no(err)
            if got then result = got end
        end
        T.eq(result.blob, payload.blob)
    end)

    it("rejects malformed and oversized messages", function()
        local m, ns = T.client()
        local S = ns.Sync
        for _, bad in ipairs({ "", "nope", "1:0:1:x", "1:2:1:x", "1:1:999:x", "zz:1:1:x" }) do
            local got, err = S.Receive("Eve", bad)
            T.eq(got, nil)
            T.ok(err, "error for " .. bad)
        end
        -- One sender can't hold unlimited partial messages.
        for i = 1, 3 do S.Receive("Eve", string.format("%x:1:5:aaaa", i)) end
        local _, err = S.Receive("Eve", "ff:1:5:aaaa")
        T.contains(err, "too many partial")
        -- A message that grows past the size cap is dropped.
        local big = string.rep("x", 230)
        local sizeError
        for i = 1, 299 do
            local _, e = S.Receive("Mallory", "aa:" .. i .. ":300:" .. big)
            if e then sizeError = sizeError or e end
        end
        T.contains(sizeError, "too large")
        -- Garbage that reassembles fine but doesn't decode is rejected.
        local _, err2 = S.Receive("Trent", "1:1:1:T S5:x")
        T.ok(err2)
    end)
end)

describe("Sharing between two players", function()
    it("declines an offer without importing and accepts a fresh offer", function()
        local m, ns = T.client(grouped("Bob"))
        local board = ns.DB.NormalizeBoard({ id = "offered-qa", name = "Offered", cards = {
            c = { id = "c", title = "Shared task" },
        } })
        T.ok(ns.Sync:HandlePayload({ k = "board", v = 1, board = board }, "Alice-Forever", "PARTY"))
        T.eq(#m.popups, 1)
        m.CancelPopup()
        T.eq(ns.db.boards[board.id], nil)
        T.eq(next(ns.Sync.offers), nil)
        T.ok(ns.Sync:HandlePayload({ k = "board", v = 2, board = board }, "Alice-Forever", "PARTY"))
        m.AcceptPopup()
        T.ok(ns.db.boards[board.id])
        T.noErrors(ns)
    end)

    it("shares and accepts in raid and guild channels", function()
        for _, case in ipairs({ { "raid", "RAID" }, { "guild", "GUILD" } }) do
            local function member(name)
                return T.client({ name = name, setup = function(mm)
                    mm.state.inGroup, mm.state.inRaid, mm.state.inGuild = true, true, true
                end })
            end
            local mA, nsA = member("Alice")
            local mB, nsB = member("Bob")
            local board = nsA.DB:GetActiveBoard()
            local ok, channel = nsA.Sync:ShareBoard(board, case[1])
            T.ok(ok); T.eq(channel, case[2])
            mA.Advance(5)
            T.ok(deliver(mA, mB, "Alice-Forever") > 0)
            T.eq(#mB.popups, 1)
            mB.AcceptPopup()
            T.eq(nsB.db.boards[board.id].shared.channel, case[2])
            T.noErrors(nsA); T.noErrors(nsB)
        end
    end)

    it("closes a recipient editor when the owner removes its open card", function()
        local mA, nsA = T.client(grouped("Alice"))
        local mB, nsB = T.client(grouped("Bob"))
        local own = nsA.DB:GetActiveBoard()
        local card = nsA.Commands:Add("Remove shared card")
        T.ok(nsA.Sync:ShareBoard(own, "party"))
        mA.Advance(5); deliver(mA, mB, "Alice-Forever"); mB.AcceptPopup()
        local received = nsB.db.boards[own.id]
        nsB.Editor:Open(received.cards[card.id], received)
        T.ok(nsB.Editor:Internals().frame:IsShown())
        nsA.DB:DeleteCard(own, card.id)
        mA.Advance(8); deliver(mA, mB, "Alice-Forever")
        T.no(nsB.Editor:Internals().frame:IsShown())
        T.eq(nsB.db.boards[own.id].cards[card.id], nil)
        T.noErrors(nsA); T.noErrors(nsB)
    end)

    it("retains owner and recipient boards with their permissions after both reload", function()
        local mA, nsA = T.client(grouped("Alice"))
        local mB, nsB = T.client(grouped("Bob"))
        local own = nsA.DB:GetActiveBoard()
        local bobOwn = nsB.DB:GetActiveBoard()
        local card = nsA.Commands:Add("Persist shared task")
        T.ok(nsA.Sync:ShareBoard(own, "party"))
        mA.Advance(5); deliver(mA, mB, "Alice-Forever"); mB.AcceptPopup()
        local _, alice = T.client(grouped("Alice"), mA.Logout())
        local _, bob = T.client(grouped("Bob"), mB.Logout())
        T.ok(alice.db.boards[own.id].shared.owner)
        T.ok(bob.db.boards[bobOwn.id], "recipient kept a separate personal board")
        local received = bob.db.boards[own.id]
        T.eq(received.scope, "shared")
        T.ok(bob.DB:IsReadOnly(received))
        T.eq(received.cards[card.id].title, "Persist shared task")
        T.noErrors(alice); T.noErrors(bob)
    end)

    it("lets a recipient set a local tracker preference in the editor across owner updates", function()
        local m, ns = T.client(grouped("Bob"))
        local source = ns.DB.NormalizeBoard({ id = "remote-qa", name = "Alice board", cards = {
            c = { id = "c", title = "Shared errand" },
        } })
        local received = ns.Sync:Import(source, "Alice-Forever", "PARTY", 1)
        ns.Editor:Open(received.cards.c, received)
        local checkbox = ns.Editor:Internals().ui.track
        checkbox:SetChecked(true) -- the mock Click does not toggle CheckButton state
        checkbox:Click()
        T.ok(received.cards.c.track)
        T.ok(ns.Sync:HandlePayload({ k = "board", v = 2, board = source }, "Alice-Forever", "PARTY"))
        T.ok(ns.db.boards[received.id].cards.c.track)
        local _, restored = T.client(grouped("Bob"), m.Logout())
        T.ok(restored.db.boards[received.id].cards.c.track)
        T.noErrors(ns); T.noErrors(restored)
    end)

    it("shares a board, accepts it, and syncs member progress back", function()
        local mA, nsA = T.client(grouped("Alice"))
        local mB, nsB = T.client(grouped("Bob"))
        local boardA = nsA.DB:GetActiveBoard()
        local card = nsA.Commands:Add("Raid prep: Get 10 Peacebloom")
        local ok, channel = nsA.Sync:ShareBoard(boardA, "party")
        T.ok(ok, tostring(channel))
        T.eq(channel, "PARTY")
        mA.Advance(5)
        T.ok(deliver(mA, mB, "Alice-Forever") > 0, "messages sent")
        T.eq(#mB.popups, 1, "Bob is asked first")
        T.contains(mB.popups[1].text, "Alice")
        mB.AcceptPopup()
        local boardB = nsB.db.boards[boardA.id]
        T.ok(boardB, "Bob has the board")
        T.eq(boardB.scope, "shared")
        T.ok(nsB.DB:IsReadOnly(boardB))
        local cardB = boardB.cards[card.id]
        T.ok(cardB)
        T.eq(cardB.goal.itemID, 2447)
        T.eq(nsB.DB:GetActiveBoard(), boardB, "switched to the shared board")

        -- Bob loots; his progress reaches Alice.
        mB.Loot(2447, 4)
        mB.Advance(4)
        T.eq(cardB.progress.text, "Peacebloom 4/10", "Bob tracks his own bags")
        T.ok(deliver(mB, mA, "Bob-Forever") > 0)
        local member = boardA.shared.members["Bob-Forever"]
        T.ok(member, "Alice sees Bob")
        T.near(member[card.id].frac, 0.4, 0.001)
        T.eq(member[card.id].text, "Peacebloom 4/10")
        mA.Loot(2447, 2)
        mA.Advance(1)
        T.eq(card.progress.cur, 2, "Alice sees her own bags")
        T.eq(cardB.progress.cur, 4, "Bob keeps separate progress")

        -- Members can't move the owner's cards.
        mB.Loot(2447, 10)
        mB.Advance(2)
        T.eq(nsB.DB:CardRole(boardB, cardB), "todo")
        T.noErrors(nsA, "Alice")
        T.noErrors(nsB, "Bob")
    end)

    it("updates members silently when the owner changes the board", function()
        local mA, nsA = T.client(grouped("Alice"))
        local mB, nsB = T.client(grouped("Bob"))
        local boardA = nsA.DB:GetActiveBoard()
        nsA.Sync:ShareBoard(boardA, "party")
        mA.Advance(5)
        deliver(mA, mB, "Alice-Forever")
        mB.AcceptPopup()
        nsA.Commands:Add("New task added later")
        mA.Advance(8)
        deliver(mA, mB, "Alice-Forever")
        T.eq(#mB.popups, 0, "no second prompt")
        local found = false
        for _, c in pairs(nsB.db.boards[boardA.id].cards) do if c.title == "New task added later" then found = true end end
        T.ok(found, "member copy updated")
    end)

    it("sanitizes hostile boards", function()
        local mB, nsB = T.client(grouped("Bob"))
        local evil = { k = "board", v = 1, board = {
            id = "evil", name = "|cffff0000Free gold|r |Hurl:x|h[click]|h", columns = {},
            cards = {},
        } }
        for i = 1, 20 do
            evil.board.cards["c" .. i] = { id = "c" .. i, title = "|TInterface\\x:999|t" .. string.rep("A", 300), column = "todo",
                notes = string.rep("n", 2100), goal = { type = "item", itemID = -5, target = 1e9, name = "|cff00ff00x|r" } }
        end
        local messages = assert(nsB.Sync.Encode(evil))
        for _, text in ipairs(messages) do mB.Fire("CHAT_MSG_ADDON", "QBRD1", text, "PARTY", "Eve-Forever") end
        T.eq(#mB.popups, 1)
        mB.AcceptPopup()
        local board = nsB.db.boards.evil
        T.ok(board)
        T.no(board.name:find("|", 1, true), "no escapes in name")
        local n = 0
        for _, c in pairs(board.cards) do
            n = n + 1
            T.ok(#c.title <= nsB.DB.LIMITS.title)
            T.ok(#c.notes <= nsB.DB.LIMITS.notes)
            T.ok(not c.goal.itemID, "negative item id dropped")
            T.ok(c.goal.target <= 100000, "target clamped")
        end
        T.eq(n, 20)
        -- Card count is capped too (checked directly; such a board is too big to send).
        local many = { name = "many", cards = {} }
        for i = 1, nsB.DB.LIMITS.cards + 50 do many.cards["c" .. i] = { title = "t" .. i } end
        local count = 0
        for _ in pairs(nsB.DB.NormalizeBoard(many).cards) do count = count + 1 end
        T.eq(count, nsB.DB.LIMITS.cards)
        T.noErrors(nsB)
    end)

    it("ignores its own messages and respects 'never'", function()
        local mB, nsB = T.client(grouped("Bob"))
        nsB.db.settings.syncAccept = "never"
        local messages = nsB.Sync.Encode({ k = "board", v = 1, board = { id = "x", name = "x", cards = {} } })
        for _, text in ipairs(messages) do mB.Fire("CHAT_MSG_ADDON", "QBRD1", text, "PARTY", "Alice-Forever") end
        T.eq(#mB.popups, 0)
        nsB.db.settings.syncAccept = "ask"
        for _, text in ipairs(nsB.Sync.Encode({ k = "board", v = 1, board = { id = "y", name = "y", cards = {} } })) do
            mB.Fire("CHAT_MSG_ADDON", "QBRD1", text, "PARTY", "Bob-Forever")
        end
        T.eq(#mB.popups, 0, "own messages ignored")
    end)

    it("never lets a received board overwrite a local one", function()
        local mB, nsB = T.client(grouped("Bob"))
        local mine = nsB.DB:GetActiveBoard()
        local fake = { k = "board", v = 99, board = { id = mine.id, name = "Gotcha", cards = {} } }
        for _, text in ipairs(nsB.Sync.Encode(fake)) do mB.Fire("CHAT_MSG_ADDON", "QBRD1", text, "PARTY", "Eve-Forever") end
        T.eq(#mB.popups, 0)
        T.eq(nsB.db.boards[mine.id].name, "My Tasks")
    end)

    it("a failing log listener can't recurse forever", function()
        local m, ns = T.client()
        ns:On("LOG_ADDED", function() error("listener bug") end)
        ns.Log:Info("test", "trigger")
        T.ok(ns.Log.errorCount >= 1)
        T.ok(ns.Log.errorCount < 5, "bounded")
    end)

    it("explains when you can't share", function()
        local m, ns = T.client()
        local ok, why = ns.Sync:ShareBoard(ns.DB:GetActiveBoard(), "party")
        T.no(ok)
        T.contains(why, "not in a party")
    end)
end)


