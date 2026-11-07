-- Live tracking engine: re-evaluates goals when the game changes, updates card
-- progress, auto-moves cards and announces progress and completions.
local _, ns = ...
local Util, Goals, DB = ns.Util, ns.Goals, ns.DB

local Engine = ns:NewModule("Engine")
Engine.THROTTLE = 0.2
Engine.stats = { passes = 0, cardsEvaluated = 0, lastMs = 0, avgMs = 0, maxMs = 0, autoStarted = 0, autoCompleted = 0, errors = 0 }

local dirty, scheduled = {}, false

local function msNow()
    return debugprofilestop and debugprofilestop() or (os.clock() * 1000)
end

function Engine:MarkDirty(types)
    for t in pairs(types) do dirty[t] = true end
    if scheduled then return end
    scheduled = true
    ns.After(self.THROTTLE, "engine pass", function()
        scheduled = false
        Engine:Pass()
    end)
end

function Engine:MarkAll()
    self:MarkDirty(Goals.TYPES)
end

-- True if this client evaluates the card (owned by this character, or shared).
function Engine:Owns(card, board)
    if board.scope == "shared" then return true end
    return card.char == nil or card.char == ns.CharKey()
end

local function touches(card, types)
    for _, entry in ipairs(Goals.CardGoals(card)) do
        if types[entry.goal.type] then return true end
    end
    return false
end

local function announce(goal, res, previous)
    if not ns.db.settings.progressMessages or not previous then return end
    if goal.type ~= "item" and goal.type ~= "skill" then return end
    if res.cur <= previous or previous >= res.target then return end
    local text = res.text
    if res.done then text = text .. " (Complete)" end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(text, 1, 0.82, 0)
    end
end

-- Evaluates one card. Returns summary { frac, done, any, changed }.
function Engine:EvaluateCard(card, board, quiet)
    local entries = Goals.CardGoals(card)
    local total, sum, allDone, any, changed = 0, 0, true, false, false
    for _, entry in ipairs(entries) do
        local res = Goals.Evaluate(entry.goal, card)
        if res then
            local previous = entry.goal._last
            if not quiet then announce(entry.goal, res, previous) end
            entry.goal._last = res.cur
            local old = entry.owner.progress
            if not old or old.text ~= res.text or old.done ~= res.done or old.frac ~= res.frac then changed = true end
            entry.owner.progress = { cur = res.cur, target = res.target, frac = res.frac, done = res.done,
                                     text = res.text, t = Util.Now(), char = ns.CharKey() }
            if entry.owner ~= card then
                -- Subtask with a goal: checked state follows the goal.
                if res.done and not entry.owner.done and not quiet then
                    ns:Fire("SUBTASK_COMPLETED", card, board, entry.owner)
                end
                entry.owner.done = res.done
            end
            total = total + 1
            sum = sum + res.frac
            if not res.done then allDone = false end
            if res.cur > 0 then any = true end
        end
    end
    -- Manual subtasks count toward progress too.
    for _, s in ipairs(card.subtasks or {}) do
        if not s.goal then
            total = total + 1
            if s.done then sum = sum + 1; any = true else allDone = false end
        end
    end
    local summary = { frac = total > 0 and sum / total or 0, done = total > 0 and allDone, any = any, total = total }
    card._summary = summary
    self.stats.cardsEvaluated = self.stats.cardsEvaluated + 1
    return summary, changed
end

function Engine:ApplyTransitions(card, board, summary)
    if DB:IsReadOnly(board) and board.scope == "shared" then
        -- Shared boards: members do not move the owner's cards; only progress is shared.
        return
    end
    local role = DB:CardRole(board, card)
    local settings = ns.db.settings
    local hasGoals = Goals.HasGoals(card)
    -- A card the player dragged out of Done stays out until it is incomplete again.
    if card.auto.hold and not summary.done then card.auto.hold = nil end
    if summary.done and role ~= "done" and settings.autoComplete and summary.total > 0 and not card.auto.hold then
        local done = DB:ColumnByRole(board, "done")
        card.auto.completed = true
        DB:MoveCard(board, card.id, done.id, 1, "complete")
        card.completedAt = Util.Now()
        self.stats.autoCompleted = self.stats.autoCompleted + 1
        ns:Fire("CARD_COMPLETED", card, board)
    elseif hasGoals and summary.any and not summary.done and role == "todo" and settings.autoStart and not card.auto.started then
        local doing = DB:ColumnByRole(board, "doing")
        card.auto.started = true
        DB:MoveCard(board, card.id, doing.id, nil, "started")
        self.stats.autoStarted = self.stats.autoStarted + 1
        ns:Fire("CARD_STARTED", card, board)
    end
    -- A completed card whose count dropped again (crafted, sold) stays in Done
    -- and is flagged so the UI can show it.
    card._regressed = role == "done" and hasGoals and not summary.done or nil
end

function Engine:Pass(quiet)
    if not ns.db then return end
    local types = dirty
    dirty = {}
    local start = msNow()
    local changedCards = 0
    for _, entry in ipairs(DB:AllCards(false)) do
        local card, board = entry.card, entry.board
        if self:Owns(card, board) and touches(card, types) then
            local ok, summary, changed = pcall(self.EvaluateCard, self, card, board, quiet)
            if ok then
                if not quiet or ns.loggedIn then self:ApplyTransitions(card, board, summary) end
                if changed then
                    changedCards = changedCards + 1
                    ns:Fire("PROGRESS_CHANGED", card, board)
                end
            else
                self.stats.errors = self.stats.errors + 1
                ns.Log:Error("engine", "Could not evaluate '%s': %s", tostring(card.title), tostring(summary))
            end
        end
    end
    local ms = msNow() - start
    local s = self.stats
    s.passes = s.passes + 1
    s.lastMs = ms
    s.maxMs = math.max(s.maxMs, ms)
    s.avgMs = s.avgMs + (ms - s.avgMs) / math.min(s.passes, 50)
    if changedCards > 0 then
        ns.Log:Debug("engine", "Pass updated %d card(s) in %.2f ms", changedCards, ms)
        ns:Fire("BOARD_REFRESH")
    end
end

-- Re-evaluates a single card now (after editing it).
function Engine:Refresh(card, board)
    if not self:Owns(card, board) then return end
    local summary = self:EvaluateCard(card, board, true)
    self:ApplyTransitions(card, board, summary)
    ns:Fire("PROGRESS_CHANGED", card, board)
end

function Engine:OnLogin()
    for event, types in pairs(Goals.EVENTS) do
        ns:RegisterEvent(event, function() Engine:MarkDirty(types) end)
    end
    -- First pass is quiet (no "6/20" spam on login); items can take a moment.
    for _, entry in ipairs(DB:AllCards(false)) do
        if self:Owns(entry.card, entry.board) then
            pcall(self.EvaluateCard, self, entry.card, entry.board, true)
        end
    end
    ns.After(2, "engine login pass", function() Engine:MarkAll() end)

    -- Verify item IDs that came from the built-in table, and unbind wrong ones.
    ns.After(3, "item verification", function() Engine:VerifyKnownItems() end)

    ns:On("CARD_ADDED", function(card, board)
        Goals.ResetRecurring(card, Engine:Owns(card, board))
        Engine:Refresh(card, board)
    end)
    ns:On("CARD_UPDATED", function(card, board) Engine:Refresh(card, board) end)
end

function Engine:VerifyKnownItems()
    for _, entry in ipairs(DB:AllCards(true)) do
        for _, g in ipairs(Goals.CardGoals(entry.card)) do
            local goal = g.goal
            if goal.type == "item" and goal.itemID and not goal.verified then
                ns.Items:Verify(goal.itemID, goal.name or "", function(ok, actual)
                    if ok then
                        goal.verified = true
                        ns.Log:Debug("items", "Verified %s = item %d", goal.name, goal.itemID)
                    elseif actual then
                        ns.Log:Warn("items", "Item %d is '%s', not '%s'; matching by name instead", goal.itemID, actual, tostring(goal.name))
                        goal.itemID, goal.verified = nil, nil
                    end
                end)
            end
        end
    end
end

