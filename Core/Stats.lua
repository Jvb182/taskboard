-- Completion history, day streaks and counters.
local _, ns = ...
local Util = ns.Util

local Stats = ns:NewModule("Stats")
Stats.MAX_HISTORY = 500

function Stats:Record(card, board, now)
    now = now or Util.Now()
    local s = ns.db.stats
    table.insert(s.history, { t = now, title = card.title, char = card.char or ns.CharKey(), board = board.name })
    while #s.history > self.MAX_HISTORY do table.remove(s.history, 1) end
    s.total = (s.total or 0) + 1
    local today = Util.DayKey(now)
    local yesterday = Util.DayKey(now - 86400)
    if s.streak.lastDay ~= today then
        s.streak.days = (s.streak.lastDay == yesterday) and (s.streak.days + 1) or 1
        s.streak.lastDay = today
    end
end

-- Current streak in days (0 if the last completion was before yesterday).
function Stats:Streak(now)
    now = now or Util.Now()
    local s = ns.db.stats.streak
    if s.lastDay == Util.DayKey(now) or s.lastDay == Util.DayKey(now - 86400) then return s.days end
    return 0
end

function Stats:CountSince(t)
    local n = 0
    for _, h in ipairs(ns.db.stats.history) do
        if h.t >= t then n = n + 1 end
    end
    return n
end

function Stats:Summary(now)
    now = now or Util.Now()
    local today = date("*t", now)
    local startOfDay = now - (today.hour * 3600 + today.min * 60 + today.sec)
    return {
        today = self:CountSince(startOfDay),
        week = self:CountSince(now - 7 * 86400),
        total = ns.db.stats.total or 0,
        streak = self:Streak(now),
    }
end

function Stats:OnLogin()
    -- Completions from both automatic and manual moves into Done.
    ns:On("CARD_MOVED", function(card, board, from, to)
        local col = ns.DB:Column(board, to)
        if col and col.role == "done" then Stats:Record(card, board) end
    end)
end
