-- Leveled ring-buffer logger. The tail is kept in TaskboardLog (SavedVariables)
-- so logs survive /reload and can be pasted into bug reports.
local _, ns = ...

local Log = ns:NewModule("Log")
ns.Log = Log

Log.LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
Log.NAMES = { "DEBUG", "INFO", "WARN", "ERROR" }
Log.COLORS = { "ff8a8a8a", "ffd0d0d0", "ffffc04d", "ffff5555" }
Log.MAX = 300

local entries = {}      -- live buffer; becomes TaskboardLog.entries once loaded
local seenErrors = {}   -- message -> count, so chat shows each error once
Log.errorCount, Log.lastError = 0, nil
Log.printLevel = Log.LEVELS.WARN

local function now()
    return time and time() or os.time()
end

local function push(level, category, message)
    local entry = { t = now(), l = level, c = category, m = message }
    entries[#entries + 1] = entry
    if #entries > Log.MAX then
        table.remove(entries, 1)
    end
    return entry
end

local function format(fmt, ...)
    if select("#", ...) == 0 then return tostring(fmt) end
    local ok, text = pcall(string.format, fmt, ...)
    if ok then return text end
    local parts = { tostring(fmt) }
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, " ")
end

local function toChat(level, category, message)
    if not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff4fc3f7Taskboard|r |c%s[%s]|r %s: %s",
        Log.COLORS[level], Log.NAMES[level], category, message))
end

local notifying = false
function Log:Write(level, category, fmt, ...)
    local message = format(fmt, ...)
    push(level, category or "core", message)
    if level >= self.printLevel and level < self.LEVELS.ERROR then
        toChat(level, category or "core", message)
    end
    -- Guard: a failing LOG_ADDED listener logs an error, which must not re-notify forever.
    if not notifying then
        notifying = true
        ns:Fire("LOG_ADDED")
        notifying = false
    end
    return message
end

function Log:Debug(c, f, ...) return self:Write(1, c, f, ...) end
function Log:Info(c, f, ...) return self:Write(2, c, f, ...) end
function Log:Warn(c, f, ...) return self:Write(3, c, f, ...) end

function Log:Error(category, fmt, ...)
    local message = self:Write(4, category, fmt, ...)
    self.errorCount = self.errorCount + 1
    self.lastError = { t = now(), where = category, message = message }
    if not seenErrors[message] then
        seenErrors[message] = 1
        toChat(4, category, message .. " |cff8a8a8a(/tb log show for details)|r")
    else
        seenErrors[message] = seenErrors[message] + 1
    end
end

-- Called by ns.Safe for caught Lua errors.
function Log:Exception(where, message, stack)
    self:Error(where or "error", "%s", message)
    if stack and stack ~= "" then
        push(4, where or "error", "stack: " .. stack:gsub("\n", " | "))
    end
    self.lastError.stack = stack
end

function Log:SetDebug(enabled)
    self.printLevel = enabled and self.LEVELS.DEBUG or self.LEVELS.WARN
    if ns.db then ns.db.settings.debug = enabled and true or false end
end

-- Returns entries (oldest first), optionally filtered by minimum level.
function Log:GetEntries(minLevel, limit)
    local out = {}
    for i = 1, #entries do
        if entries[i].l >= (minLevel or 1) then out[#out + 1] = entries[i] end
    end
    if limit and #out > limit then
        local trimmed = {}
        for i = #out - limit + 1, #out do trimmed[#trimmed + 1] = out[i] end
        out = trimmed
    end
    return out
end

function Log:FormatEntry(e, color)
    local stamp = date and date("%H:%M:%S", e.t) or tostring(e.t)
    local level = self.NAMES[e.l] or "?"
    if color then
        return string.format("|cff8a8a8a%s|r |c%s%-5s|r %s: %s", stamp, self.COLORS[e.l] or "ffffffff", level, e.c, e.m)
    end
    return string.format("%s %-5s %s: %s", stamp, level, e.c, e.m)
end

function Log:Clear()
    for i = #entries, 1, -1 do entries[i] = nil end
    seenErrors = {}
    self:Info("log", "Log cleared")
end

function Log:Reset()
    entries, seenErrors = {}, {}
    self.errorCount, self.lastError = 0, nil
    TaskboardLog = { entries = entries, sessions = 0 }
end

function Log:Count()
    return #entries
end

function Log:OnInit()
    if TaskboardLog == nil and type(rawget(_G, "QuestboardLog")) == "table" then
        TaskboardLog = ns.Util.DeepCopy(rawget(_G, "QuestboardLog"))
    end
    TaskboardLog = type(TaskboardLog) == "table" and TaskboardLog or {}
    local saved = type(TaskboardLog.entries) == "table" and TaskboardLog.entries or {}
    -- Keep valid saved entries, then append anything logged before load.
    local merged = {}
    for _, e in ipairs(saved) do
        if type(e) == "table" and type(e.m) == "string" and type(e.l) == "number" then
            merged[#merged + 1] = e
        end
    end
    for _, e in ipairs(entries) do merged[#merged + 1] = e end
    while #merged > self.MAX do table.remove(merged, 1) end
    entries = merged
    TaskboardLog.entries = entries
    TaskboardLog.sessions = (tonumber(TaskboardLog.sessions) or 0) + 1
    self:Info("log", "Session %d started, Taskboard %s", TaskboardLog.sessions, ns.version)
end

