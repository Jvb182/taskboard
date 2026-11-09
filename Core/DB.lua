-- SavedVariables schema, defaults, migrations, repair and board/card CRUD.
local _, ns = ...
local Util = ns.Util

local DB = ns:NewModule("DB")
DB.SCHEMA = 1

DB.LIMITS = { boards = 30, columns = 8, cards = 12000, title = 200, notes = 2000, tags = 8, tag = 24,
              subtasks = 25, boardName = 40, columnName = 24 }

DB.PRIORITIES = { [0] = "None", "Low", "Medium", "High" }
DB.NPCS = { bank = "Bank", vendor = "Vendor", mail = "Mailbox", ah = "Auction House", trainer = "Trainer" }

DB.defaults = {
    schema = DB.SCHEMA,
    settings = {
        autoStart = true, autoComplete = true, progressMessages = true, toasts = true, sounds = true,
        reminders = true, smartReminders = true, includeBank = true, trackerShown = true,
        trackerLocked = false, trackerHideInCombat = false, trackerAllOpen = false, trackerLocationPulse = true, trackerMax = 8, onlyMine = false,
        syncAccept = "ask", debug = false, minimap = { angle = 200, hide = false },
        theme = "midnight", accent = "sky", panelOpacity = 0.96,
        soundEvents = { move = "click", complete = "quest", subtask = "click", reminder = "chime" },
    },
    boards = {},
    mailboxes = {}, -- learned mailbox world positions; shared across characters
    stats = { history = {}, total = 0, streak = { days = 0, lastDay = "" } },
    ui = {},
    resets = {},
}

local function defaultColumns()
    return {
        { id = "todo", name = "To Do", role = "todo" },
        { id = "doing", name = "In Progress", role = "doing" },
        { id = "done", name = "Done", role = "done" },
    }
end

-------------------------------------------------------------------------------
-- Validation (also used for imported and synced data, which is untrusted)
-------------------------------------------------------------------------------
local GOAL_TYPES = { item = true, money = true, level = true, skill = true, rep = true, quest = true }

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return Util.Clamp(math.floor(v), lo, hi)
end

-- IDs are never clamped: an out-of-range ID is invalid, not "the nearest ID".
local function id(v, hi)
    v = tonumber(v)
    if not v or v ~= v or v < 1 or v > hi or v ~= math.floor(v) then return nil end
    return v
end

function DB.NormalizeGoal(g)
    if type(g) ~= "table" or not GOAL_TYPES[g.type] then return nil end
    local out = { type = g.type }
    if g.type == "item" then
        out.itemID = id(g.itemID, 10000000)
        out.name = Util.Sanitize(g.name or "", 80)
        out.target = num(g.target, 1, 100000) or 1
        out.bank = g.bank ~= false
        out.verified = g.verified == true or nil
        out.baseline = num(g.baseline, 0, 1000000000)
        if type(g.baselineBank) == "boolean" then out.baselineBank = g.baselineBank end
        if not out.itemID and out.name == "" then return nil end
    elseif g.type == "money" then
        out.target = num(g.target, 1, 1e12)
        if not out.target then return nil end
    elseif g.type == "level" then
        out.target = num(g.target, 2, 200)
        out.start = num(g.start, 1, 200)
        if not out.target then return nil end
    elseif g.type == "skill" then
        out.name = Util.Sanitize(g.name or "", 40)
        out.target = num(g.target, 1, 1000)
        if out.name == "" or not out.target then return nil end
    elseif g.type == "rep" then
        out.name = Util.Sanitize(g.name or "", 60)
        out.factionID = id(g.factionID, 100000)
        out.target = num(g.target, 1, 8) or 5
        if out.name == "" and not out.factionID then return nil end
    elseif g.type == "quest" then
        out.questID = id(g.questID, 10000000)
        out.name = Util.Sanitize(g.name or "", 100)
        if not out.questID and out.name == "" then return nil end
    end
    return out
end

-- Returns a clean copy of a card, or nil if it is unusable.
function DB.NormalizeCard(c, columnIDs)
    if type(c) ~= "table" then return nil end
    local L = DB.LIMITS
    local title = Util.Sanitize(c.title or "", L.title)
    if title == "" then return nil end
    if #title > L.title then title = string.sub(title, 1, L.title) end
    local out = {
        id = type(c.id) == "string" and #c.id <= 40 and c.id or Util.NewID("c"),
        title = title,
        notes = type(c.notes) == "string" and Util.PlainNotes(c.notes, L.notes) or "",
        priority = num(c.priority, 0, 3) or 0,
        column = c.column,
        created = num(c.created, 0, 4e9) or Util.Now(),
        updated = num(c.updated, 0, 4e9) or Util.Now(),
        completedAt = num(c.completedAt, 0, 4e9),
        char = type(c.char) == "string" and string.sub(c.char, 1, 64) or nil,
        goal = DB.NormalizeGoal(c.goal),
        recur = (c.recur == "daily" or c.recur == "weekly") and c.recur or nil,
        recurItems = c.recurItems == "stock" and "stock" or "gain",
        recurCycle = num(c.recurCycle, 0, 4e9),
        streak = num(c.streak, 0, 100000) or 0,
        archived = c.archived == true or nil,
        track = c.track == true or nil,
        auto = type(c.auto) == "table" and { started = c.auto.started == true or nil, completed = c.auto.completed == true or nil,
                                             hold = c.auto.hold == true or nil } or {},
        tags = {}, subtasks = {},
    }
    if columnIDs and not columnIDs[out.column] then out.column = nil end
    if type(c.tags) == "table" then
        for _, tag in ipairs(c.tags) do
            local t = Util.Lower(Util.Sanitize(tag, L.tag)):gsub("[^%w%-_]", "")
            if t ~= "" and #out.tags < L.tags and not Util.IndexOf(out.tags, t) then out.tags[#out.tags + 1] = t end
        end
    end
    if type(c.subtasks) == "table" then
        for _, s in ipairs(c.subtasks) do
            if type(s) == "table" and #out.subtasks < L.subtasks then
                local text = Util.Sanitize(s.text or "", L.title)
                if text ~= "" then
                    out.subtasks[#out.subtasks + 1] = {
                        id = type(s.id) == "string" and #s.id <= 40 and s.id or Util.NewID("s"),
                        text = string.sub(text, 1, L.title), done = s.done == true, goal = DB.NormalizeGoal(s.goal),
                    }
                end
            end
        end
    end
    out.reminderExplicit = c.reminderExplicit == true or c.where == false or nil
    if type(c.where) == "table" then
        if type(c.where.zone) == "string" and Util.Trim(c.where.zone) ~= "" then
            out.where = { zone = Util.Sanitize(c.where.zone, 60) }
        elseif DB.NPCS[c.where.npc] then
            out.where = { npc = c.where.npc }
        end
    end
    if not out.where and not out.reminderExplicit and ns.Parser and ns.Parser.IsMailCheck(out.title) then
        out.where = { npc = "mail" }
    end
    if type(c.pin) == "table" and id(c.pin.mapID, 100000) and tonumber(c.pin.x) and tonumber(c.pin.y) then
        out.pin = { mapID = id(c.pin.mapID, 100000), x = Util.Clamp(tonumber(c.pin.x), 0, 1),
                    y = Util.Clamp(tonumber(c.pin.y), 0, 1), label = Util.Sanitize(c.pin.label or "", 60) }
    end
    if type(c.progress) == "table" then
        out.progress = { cur = tonumber(c.progress.cur) or 0, target = tonumber(c.progress.target) or 0,
                         frac = Util.Clamp(tonumber(c.progress.frac) or 0, 0, 1), done = c.progress.done == true,
                         text = Util.Sanitize(c.progress.text or "", 80), t = num(c.progress.t, 0, 4e9) }
    end
    return out
end

function DB.NormalizeBoard(b)
    if type(b) ~= "table" then return nil end
    local L = DB.LIMITS
    local out = {
        id = type(b.id) == "string" and #b.id <= 40 and b.id or Util.NewID("b"),
        name = Util.Sanitize(b.name or "Board", L.boardName),
        scope = (b.scope == "character" or b.scope == "shared") and b.scope or "account",
        owner = type(b.owner) == "string" and string.sub(b.owner, 1, 64) or nil,
        created = num(b.created, 0, 4e9) or Util.Now(),
        columns = {}, cards = {}, order = {},
    }
    if out.name == "" then out.name = "Board" end
    local ids, roles = {}, {}
    if type(b.columns) == "table" then
        for _, col in ipairs(b.columns) do
            if type(col) == "table" and type(col.id) == "string" and #col.id > 0 and #col.id <= 24 and not ids[col.id] and #out.columns < L.columns then
                local role = (col.role == "todo" or col.role == "doing" or col.role == "done") and not roles[col.role] and col.role or nil
                if role then roles[role] = true end
                out.columns[#out.columns + 1] = { id = string.sub(col.id, 1, 24), name = Util.Sanitize(col.name or col.id, L.columnName), role = role }
                ids[out.columns[#out.columns].id] = true
            end
        end
    end
    -- Every board needs the three roles; add any that are missing.
    for _, def in ipairs(defaultColumns()) do
        if not roles[def.role] then
            if #out.columns >= L.columns then
                for i = #out.columns, 1, -1 do
                    if not out.columns[i].role then ids[out.columns[i].id] = nil; table.remove(out.columns, i); break end
                end
            end
            local id = ids[def.id] and (def.id .. "_" .. Util.NewID()) or def.id
            def.id = id
            ids[id] = true
            if def.role == "todo" then table.insert(out.columns, 1, def) else table.insert(out.columns, def) end
        end
    end
    local count = 0
    if type(b.cards) == "table" then
        for _, c in pairs(b.cards) do
            if count >= L.cards then break end
            local card = DB.NormalizeCard(c, ids)
            if card and not out.cards[card.id] then
                card.column = card.column or out.columns[1].id
                out.cards[card.id] = card
                count = count + 1
            end
        end
    end
    -- Rebuild order from saved order, then append any cards it missed.
    local placed = {}
    for _, col in ipairs(out.columns) do
        out.order[col.id] = {}
        local saved = type(b.order) == "table" and b.order[col.id]
        if type(saved) == "table" then
            for _, id in ipairs(saved) do
                local card = out.cards[id]
                if card and card.column == col.id and not placed[id] then
                    table.insert(out.order[col.id], id)
                    placed[id] = true
                end
            end
        end
    end
    for id, card in pairs(out.cards) do
        if not placed[id] then table.insert(out.order[card.column], id) end
    end
    if out.scope == "shared" and type(b.shared) == "table" then
        out.shared = { from = Util.Sanitize(b.shared.from or "", 64), version = num(b.shared.version, 0, 1e9) or 0,
                       channel = (b.shared.channel == "PARTY" or b.shared.channel == "RAID" or b.shared.channel == "GUILD") and b.shared.channel or nil,
                       members = type(b.shared.members) == "table" and b.shared.members or {} }
    elseif type(b.shared) == "table" and b.shared.channel then
        -- A board this player shared keeps its channel and member progress.
        out.shared = { owner = true, version = num(b.shared.version, 0, 1e9) or 0, channel = b.shared.channel,
                       members = type(b.shared.members) == "table" and b.shared.members or {} }
    end
    return out
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------
local migrations = {
    -- [2] = function(db) ... end,
}

-- Replaces any saved value whose type doesn't match the default (e.g. a
-- corrupted file with boards = "x"), recursively. Unknown extra keys are kept.
local function conform(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] ~= nil and type(target[k]) ~= type(v) then
            ns.Log:Warn("db", "Saved '%s' had the wrong type (%s); reset to default", tostring(k), type(target[k]))
            target[k] = Util.DeepCopy(v)
        elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
            conform(target[k], v)
        end
    end
end

function DB:Load(saved)
    local db = type(saved) == "table" and saved or {}
    conform(db, DB.defaults)
    local from = tonumber(db.schema) or DB.SCHEMA
    for v = from + 1, DB.SCHEMA do
        if migrations[v] then
            migrations[v](db)
            ns.Log:Info("db", "Migrated saved data to schema %d", v)
        end
    end
    Util.ApplyDefaults(db, DB.defaults)
    db.schema = DB.SCHEMA
    self:Repair(db)
    return db
end

function DB:Repair(db)
    local repaired, boards = 0, {}
    for id, board in pairs(db.boards) do
        local clean = DB.NormalizeBoard(board)
        if clean then
            if clean.id ~= id then repaired = repaired + 1 end
            local before = type(board.cards) == "table" and Util.Count(board.cards) or 0
            if Util.Count(clean.cards) ~= before then repaired = repaired + 1 end
            boards[clean.id] = clean
        else
            repaired = repaired + 1
        end
    end
    db.boards = boards
    if type(db.stats.history) ~= "table" then db.stats.history = {} end
    if repaired > 0 then ns.Log:Warn("db", "Repaired %d problem(s) in saved data", repaired) end
    self.lastRepairs = repaired
    return repaired
end

function DB:OnInit()
    if TaskboardDB == nil and type(rawget(_G, "QuestboardDB")) == "table" then
        TaskboardDB = Util.DeepCopy(rawget(_G, "QuestboardDB"))
        ns.Log:Info("migration", "Copied Questboard boards and settings into Taskboard. Legacy data was left intact.")
    end
    ns.db = self:Load(TaskboardDB)
    -- Saved default labels outlive source-code renames. Update only exact
    -- legacy defaults once; keep custom titles, notes and shared boards intact.
    if not ns.db.taskboardBrandingUpdated then
        local oldNotes = "Add cards with /qb add, or type in the box at the top of the board.\n\n" ..
            "Try: Get 20 Peacebloom #herbs !high\nShift-click an item link into the box to track it live."
        for _, board in pairs(ns.db.boards) do
            if board.scope ~= "shared" then
                if board.name == "My Quests" then board.name = "My Tasks" end
                for _, card in pairs(board.cards) do
                    if card.title == "Welcome to Questboard! Right-click me" then
                        card.title = "Welcome to Taskboard! Right-click me"
                        if card.notes == oldNotes then card.notes = oldNotes:gsub("/qb", "/tb") end
                        for _, subtask in ipairs(card.subtasks) do
                            if subtask.text == "Open the board with /qb" then subtask.text = "Open the board with /tb" end
                        end
                    end
                end
            end
        end
        ns.db.taskboardBrandingUpdated = true
    end
    TaskboardDB = ns.db
    ns.Log:SetDebug(ns.db.settings.debug)
    ns.Log:Info("db", "Loaded %d board(s)", Util.Count(ns.db.boards))
end

function DB:OnLogin()
    local me = ns.CharKey()
    if Util.Count(ns.db.boards) == 0 then
        local board = self:CreateBoard("My Tasks", "character")
        self:AddCard(board, { title = "Welcome to Taskboard! Right-click me", notes =
            "Add cards with /tb add, or type in the box at the top of the board.\n\n" ..
            "Try: Get 20 Peacebloom #herbs !high\nShift-click an item link into the box to track it live.",
            subtasks = { { text = "Open the board with /tb" }, { text = "Add a card that tracks an item" }, { text = "Drag a card to In Progress" } } })
        ns.Log:Info("db", "Created the default board for %s", me)
    end
    if not ns.db.oneBoardPerCharacter then
        self:ConsolidateBoards()
        ns.db.oneBoardPerCharacter = true
    end
    local own = self:BoardForCharacter(me)
    if not own then own = self:CreateBoard("My Tasks", "character") end
    if own then
        ns.db.ui.activeBoard = own.id
    elseif not ns.db.ui.activeBoard or not ns.db.boards[ns.db.ui.activeBoard] then
        ns.db.ui.activeBoard = self:FirstVisibleBoard()
    end
end

function DB:OnLogout()
    -- SavedVariables serialize the actual tables, not our wire serializer.
    local function clean(t)
        for k, v in pairs(t) do
            if type(k) == "string" and string.sub(k, 1, 1) == "_" then t[k] = nil
            elseif type(v) == "table" then clean(v) end
        end
    end
    clean(ns.db)
end

-------------------------------------------------------------------------------
-- Boards
-------------------------------------------------------------------------------
function DB:IsVisible(board)
    return true -- character boards are available to every character on the account
end

function DB:BoardForCharacter(owner)
    for _, board in pairs(ns.db.boards) do
        if board.scope == "character" and board.owner == owner then return board end
    end
end

-- Migrate the old many-board layout without discarding cards. Incoming shared
-- boards remain separate; local cards are grouped by their assigned character.
function DB:ConsolidateBoards()
    local originals = {}
    for _, board in pairs(ns.db.boards) do originals[#originals + 1] = board end
    table.sort(originals, function(a, b)
        if a.created ~= b.created then return a.created < b.created end
        return a.id < b.id
    end)
    local result, targets, emptySources, count = {}, {}, {}, 0
    local function destination(owner, source)
        owner = type(owner) == "string" and owner ~= "" and owner or ns.CharKey()
        if targets[owner] then return targets[owner] end
        local board = DB.NormalizeBoard({ name = source.name, scope = "character", owner = owner,
            columns = Util.DeepCopy(source.columns), created = source.created })
        board.id = source.id
        if result[board.id] then board.id = Util.NewID("b") end
        result[board.id], targets[owner] = board, board
        return board
    end
    local function targetColumn(target, sourceColumn)
        if sourceColumn.role then return DB:ColumnByRole(target, sourceColumn.role).id end
        for _, col in ipairs(target.columns) do
            if not col.role and col.name == sourceColumn.name then return col.id end
        end
        if #target.columns >= DB.LIMITS.columns then return DB:ColumnByRole(target, "doing").id end
        local id = sourceColumn.id
        if target.order[id] then id = Util.NewID("k") end
        local col = { id = id, name = sourceColumn.name }
        table.insert(target.columns, #target.columns, col)
        target.order[id] = {}
        return id
    end
    for _, source in ipairs(originals) do
        if source.scope == "shared" then
            result[source.id] = source
        else
            if not next(source.cards) then emptySources[#emptySources + 1] = source end
            for _, col in ipairs(source.columns) do
                for _, cardID in ipairs(source.order[col.id] or {}) do
                    local card = source.cards[cardID]
                    if card then
                        local owner = card.char or source.owner or ns.CharKey()
                        local target = destination(owner, source)
                        local targetID = targetColumn(target, col)
                        if target.cards[card.id] then card.id = Util.NewID("c") end
                        card.char, card.column = owner, targetID
                        target.cards[card.id] = card
                        table.insert(target.order[targetID], card.id)
                        count = count + 1
                    end
                end
            end
        end
    end
    for _, source in ipairs(emptySources) do
        local owner = source.owner or ns.CharKey()
        if not targets[owner] then destination(owner, source) end
    end
    ns.db.boards = result
    ns.Log:Info("db", "Consolidated %d local board(s) into %d character board(s); kept %d cards",
        #originals, Util.Count(targets), count)
    ns:Fire("BOARDS_CHANGED")
end

function DB:FirstVisibleBoard()
    local best
    for id, board in pairs(ns.db.boards) do
        if self:IsVisible(board) and (not best or board.created < ns.db.boards[best].created) then best = id end
    end
    return best
end

function DB:VisibleBoards()
    local list = {}
    for _, board in pairs(ns.db.boards) do
        if self:IsVisible(board) then list[#list + 1] = board end
    end
    table.sort(list, function(a, b)
        if a.created ~= b.created then return a.created < b.created end
        return a.id < b.id
    end)
    return list
end

function DB:CreateBoard(name, scope)
    if scope ~= "shared" then
        local existing = self:BoardForCharacter(ns.CharKey())
        if existing then return existing end
        scope = "character"
    end
    if Util.Count(ns.db.boards) >= DB.LIMITS.boards then
        return nil, "too many boards"
    end
    local board = DB.NormalizeBoard({ name = name, scope = scope, owner = scope == "character" and ns.CharKey() or nil, columns = defaultColumns() })
    ns.db.boards[board.id] = board
    ns.Log:Info("db", "Created board '%s' (%s)", board.name, board.scope)
    ns:Fire("BOARDS_CHANGED")
    return board
end

function DB:DeleteBoard(board)
    ns.db.boards[board.id] = nil
    if ns.db.ui.activeBoard == board.id then ns.db.ui.activeBoard = self:FirstVisibleBoard() end
    ns.Log:Info("db", "Deleted board '%s'", board.name)
    ns:Fire("BOARDS_CHANGED")
end

function DB:RenameBoard(board, name)
    if not self:CanEdit(board) then return false, "this board is read-only" end
    name = Util.Sanitize(name, DB.LIMITS.boardName)
    if name == "" then return false end
    board.name = name
    ns:Fire("BOARDS_CHANGED")
    return true
end

function DB:GetActiveBoard()
    local id = ns.db.ui.activeBoard
    local board = id and ns.db.boards[id]
    if board and self:IsVisible(board) then return board end
    ns.db.ui.activeBoard = self:FirstVisibleBoard()
    return ns.db.ui.activeBoard and ns.db.boards[ns.db.ui.activeBoard]
end

function DB:SetActiveBoard(board)
    ns.db.ui.activeBoard = board.id
    ns:Fire("BOARDS_CHANGED")
end

function DB:IsReadOnly(board)
    return board and board.scope == "shared" and board.shared and board.shared.from ~= nil and board.shared.from ~= ""
        and board.shared.from ~= ns.CharKey()
end

function DB:CanEdit(board)
    return board and ns.db.boards[board.id] == board and not self:IsReadOnly(board)
end

function DB:ColumnByRole(board, role)
    for _, col in ipairs(board.columns) do
        if col.role == role then return col end
    end
end

function DB:Column(board, id)
    for i, col in ipairs(board.columns) do
        if col.id == id then return col, i end
    end
end

function DB:AddColumn(board, name)
    if not self:CanEdit(board) then return nil, "this board is read-only" end
    if #board.columns >= DB.LIMITS.columns then return nil, "too many columns" end
    name = Util.Sanitize(name, DB.LIMITS.columnName)
    if name == "" then return nil, "empty name" end
    local col = { id = Util.NewID("k"), name = name }
    -- New columns go just before Done.
    local _, doneIndex = self:Column(board, self:ColumnByRole(board, "done").id)
    table.insert(board.columns, doneIndex, col)
    board.order[col.id] = {}
    ns:Fire("BOARD_CHANGED", board)
    return col
end

function DB:RenameColumn(board, id, name)
    if not self:CanEdit(board) then return false, "this board is read-only" end
    local col = self:Column(board, id)
    name = Util.Sanitize(name, DB.LIMITS.columnName)
    if not col or name == "" then return false end
    col.name = name
    ns:Fire("BOARD_CHANGED", board)
    return true
end

function DB:RemoveColumn(board, id)
    if not self:CanEdit(board) then return false, "this board is read-only" end
    local col, index = self:Column(board, id)
    if not col then return false, "no such column" end
    if col.role then return false, "the To Do, In Progress and Done columns can be renamed but not removed" end
    if #board.order[id] > 0 then return false, "move its cards out first" end
    table.remove(board.columns, index)
    board.order[id] = nil
    ns:Fire("BOARD_CHANGED", board)
    return true
end

-------------------------------------------------------------------------------
-- Cards
-------------------------------------------------------------------------------
function DB:AddCard(board, spec, columnID, index)
    if not self:CanEdit(board) then return nil, "this board is read-only" end
    if Util.Count(board.cards) >= DB.LIMITS.cards then return nil, "this board is full" end
    spec = Util.DeepCopy(spec)
    spec.id = nil
    spec.char = spec.char or (board.scope ~= "shared" and (board.owner or ns.CharKey()) or nil)
    local ids = {}
    for _, col in ipairs(board.columns) do ids[col.id] = true end
    local card = DB.NormalizeCard(spec, ids)
    if not card then return nil, "a card needs a title" end
    local col = (columnID and self:Column(board, columnID)) or (spec.columnRole and self:ColumnByRole(board, spec.columnRole)) or self:ColumnByRole(board, "todo")
    card.column = col.id
    if col.role == "done" then card.completedAt = Util.Now() end
    board.cards[card.id] = card
    local list = board.order[col.id]
    table.insert(list, Util.Clamp(index or (#list + 1), 1, #list + 1), card.id)
    ns.Log:Info("cards", "Added '%s' to %s", card.title, col.name)
    ns:Fire("CARD_ADDED", card, board)
    ns:Fire("BOARD_CHANGED", board)
    return card
end

function DB:FindCard(cardID)
    for _, board in pairs(ns.db.boards) do
        if board.cards[cardID] then return board.cards[cardID], board end
    end
end

function DB:MoveCard(board, cardID, columnID, index, reason)
    if not self:CanEdit(board) then return false, "this board is read-only" end
    local card = board.cards[cardID]
    local col = self:Column(board, columnID)
    if not card or not col then return false end
    local from = board.order[card.column]
    local oldIndex = Util.IndexOf(from, cardID)
    if oldIndex then table.remove(from, oldIndex) end
    local to = board.order[col.id]
    if index and col.id == card.column and oldIndex and oldIndex < index then index = index - 1 end
    table.insert(to, Util.Clamp(index or (#to + 1), 1, #to + 1), cardID)
    local previous = card.column
    card.column = col.id
    card.updated = Util.Now()
    if previous ~= col.id then
        local fromCol = self:Column(board, previous)
        if col.role == "done" then
            card.completedAt = card.completedAt or Util.Now()
        elseif fromCol and fromCol.role == "done" then
            card.completedAt = nil
            card.auto.completed = nil
            -- Moved out of Done by hand: don't immediately auto-complete it again.
            if not reason then card.auto.hold = true end
        end
        ns.Log:Info("cards", "Moved '%s' to %s%s", card.title, col.name, reason and (" (" .. reason .. ")") or "")
        ns:Fire("CARD_MOVED", card, board, previous, col.id, reason)
    end
    ns:Fire("BOARD_CHANGED", board)
    return true
end

function DB:UpdateCard(board, card, changes)
    if not self:CanEdit(board) or board.cards[card.id] ~= card then return false, "this card is read-only or no longer exists" end
    local candidate = Util.DeepCopy(card)
    local previousManual = {}
    for _, sub in ipairs(card.subtasks) do if not sub.goal then previousManual[sub.id] = sub.done end end
    for k, v in pairs(changes) do candidate[k] = v end
    local ids = {}
    for _, col in ipairs(board.columns) do ids[col.id] = true end
    local clean = DB.NormalizeCard(candidate, ids)
    if not clean then return false end
    clean.id, clean.column = card.id, card.column
    clean.updated = Util.Now()
    -- Keep runtime caches; replace everything else in place so references stay valid.
    for k in pairs(card) do
        if string.sub(k, 1, 1) ~= "_" then card[k] = nil end
    end
    for k, v in pairs(clean) do card[k] = v end
    if changes.recur ~= nil or changes.recurItems ~= nil then
        card.recurCycle = Util.Now()
        ns.Goals.ResetRecurring(card, ns.Engine:Owns(card, board))
    end
    ns:Fire("CARD_UPDATED", card, board)
    for _, sub in ipairs(card.subtasks) do
        if not sub.goal and sub.done and previousManual[sub.id] == false then ns:Fire("SUBTASK_COMPLETED", card, board, sub) end
    end
    ns:Fire("BOARD_CHANGED", board)
    return true
end

function DB:DeleteCard(board, cardID)
    if not self:CanEdit(board) then return false, "this board is read-only" end
    local card = board.cards[cardID]
    if not card then return false end
    local list = board.order[card.column]
    local i = list and Util.IndexOf(list, cardID)
    if i then table.remove(list, i) end
    board.cards[cardID] = nil
    ns.Log:Info("cards", "Deleted '%s'", card.title)
    ns:Fire("CARD_DELETED", card, board)
    ns:Fire("BOARD_CHANGED", board)
    return true
end

function DB:CardRole(board, card)
    local col = self:Column(board, card.column)
    return col and col.role
end

-- Cards in a column, in order, honoring the board filter.
function DB:CardsIn(board, columnID, filter)
    local out = {}
    for _, id in ipairs(board.order[columnID] or {}) do
        local card = board.cards[id]
        if card and not card.archived and (not filter or filter(card)) then out[#out + 1] = card end
    end
    return out
end

function DB:AllCards(includeArchived, includeHidden)
    local out = {}
    for _, board in pairs(ns.db.boards) do
        if includeHidden or self:IsVisible(board) then
            for _, col in ipairs(board.columns) do
                for _, id in ipairs(board.order[col.id]) do
                    local card = board.cards[id]
                    if card and (includeArchived or not card.archived) then out[#out + 1] = { card = card, board = board } end
                end
            end
        end
    end
    return out
end

