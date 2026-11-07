-- Daily and weekly repeating cards, reset at the server's daily/weekly reset.
local _, ns = ...
local Util, DB = ns.Util, ns.DB

local Recurring = ns:NewModule("Recurring")
Recurring.stats = { resets = 0, lastCheck = 0 }

local function untilReset(kind)
    local api = C_DateAndTime
    local fn = api and (kind == "daily" and api.GetSecondsUntilDailyReset or api.GetSecondsUntilWeeklyReset)
    if fn then
        local ok, seconds = pcall(fn)
        if ok and type(seconds) == "number" and seconds >= 0 then return seconds end
    end
    -- Fallback: local midnight (daily) or 7 days.
    local now = time()
    local t = date("*t", now)
    local midnight = now + (24 - t.hour) * 3600 - t.min * 60 - t.sec
    if kind == "daily" then return midnight - now end
    return midnight - now + ((8 - t.wday) % 7) * 86400 -- next Monday
end

function Recurring:NextReset(kind, now)
    return (now or Util.Now()) + untilReset(kind)
end

-- Resets repeating cards of `kind`. Done cards grow their streak; unfinished ones lose it.
function Recurring:Reset(kind, missed)
    local count = 0
    for _, entry in ipairs(DB:AllCards(true, true)) do
        local card, board = entry.card, entry.board
        if card.recur == kind and not card.archived and not DB:IsReadOnly(board) then
            local role = DB:CardRole(board, card)
            if role == "done" and (missed or 1) == 1 then card.streak = (card.streak or 0) + 1 else card.streak = 0 end
            for _, s in ipairs(card.subtasks) do s.done, s.progress = false, nil end
            card.auto = { hold = true }
            card.recurCycle = Util.Now()
            card.completedAt = nil
            card.progress = nil
            card._summary, card._regressed = nil, nil
            ns.Goals.ResetRecurring(card, ns.Engine:Owns(card, board))
            if role ~= "todo" then
                DB:MoveCard(board, card.id, DB:ColumnByRole(board, "todo").id, nil, kind .. " reset")
            else
                ns:Fire("BOARD_CHANGED", board)
            end
            count = count + 1
        end
    end
    if count > 0 then
        self.stats.resets = self.stats.resets + count
        ns.Log:Info("recurring", "%s reset: %d card(s) back in To Do", kind, count)
        ns.Engine:MarkAll()
        ns:Fire("BOARD_REFRESH")
    end
    return count
end

function Recurring:Check(now)
    now = now or Util.Now()
    self.stats.lastCheck = now
    local r = ns.db.resets
    for _, kind in ipairs({ "daily", "weekly" }) do
        local key = kind == "daily" and "nextDaily" or "nextWeekly"
        if not r[key] then
            r[key] = self:NextReset(kind, now)
        elseif now >= r[key] then
            local period = kind == "daily" and 86400 or 604800
            self:Reset(kind, math.floor((now - r[key]) / period) + 1)
            r[key] = self:NextReset(kind, now)
            -- Guard against an API that returns 0 right at reset time.
            if r[key] <= now then r[key] = now + (kind == "daily" and 86400 or 604800) end
        end
    end
end

function Recurring:OnLogin()
    self:Check()
    self.ticker = ns.Ticker(60, "recurring check", function() Recurring:Check() end)
end

