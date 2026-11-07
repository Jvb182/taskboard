-- Pure helpers: strings, tables, money, time, links, ids.
local _, ns = ...

local Util = {}
ns.Util = Util

function Util.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.Lower(s)
    return string.lower(tostring(s or ""))
end

-- Splits on a single literal separator character.
function Util.Split(s, sep)
    local out = {}
    s = tostring(s or "")
    local start = 1
    while true do
        local i = string.find(s, sep, start, true)
        if not i then
            out[#out + 1] = string.sub(s, start)
            break
        end
        out[#out + 1] = string.sub(s, start, i - 1)
        start = i + #sep
    end
    return out
end

function Util.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Util.DeepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, x in pairs(v) do out[Util.DeepCopy(k, seen)] = Util.DeepCopy(x, seen) end
    return out
end

-- Fills missing keys in target from defaults (recursively). Never overwrites.
function Util.ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = Util.DeepCopy(v)
        elseif type(v) == "table" and type(target[k]) == "table" then
            Util.ApplyDefaults(target[k], v)
        end
    end
    return target
end

function Util.IndexOf(list, value)
    for i = 1, #list do
        if list[i] == value then return i end
    end
end

function Util.Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-------------------------------------------------------------------------------
-- IDs
-------------------------------------------------------------------------------
local idCounter = 0
function Util.NewID(prefix)
    idCounter = (idCounter + 1) % 0x10000
    local t = time and time() or os.time()
    return string.format("%s%x%04x%03x", prefix or "", t, idCounter, math.random(0, 0xfff))
end

-------------------------------------------------------------------------------
-- Money
-------------------------------------------------------------------------------
function Util.FormatMoney(copper, short)
    copper = math.floor(tonumber(copper) or 0)
    local negative = copper < 0
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 and not (short and g >= 1000) then parts[#parts + 1] = s .. "s" end
    if (c > 0 and not (short and g > 0)) or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return (negative and "-" or "") .. table.concat(parts, " ")
end

-- "100g", "1g 50s", "1g50s20c", "75s" -> copper. Returns nil if no money token.
function Util.ParseMoney(text)
    text = Util.Lower(text)
    local total, found = 0, false
    for amount, unit in string.gmatch(text, "(%d+)%s*([gsc])%f[%A]") do
        found = true
        amount = tonumber(amount)
        if unit == "g" then total = total + amount * 10000
        elseif unit == "s" then total = total + amount * 100
        else total = total + amount end
    end
    return found and total or nil
end

-------------------------------------------------------------------------------
-- Time
-------------------------------------------------------------------------------
function Util.Now()
    return (GetServerTime and GetServerTime()) or (time and time()) or os.time()
end

function Util.DayKey(t)
    return date("%Y-%m-%d", t or Util.Now())
end

function Util.Ago(t, now)
    local d = (now or Util.Now()) - (t or 0)
    if d < 60 then return "just now" end
    if d < 3600 then return math.floor(d / 60) .. "m ago" end
    if d < 86400 then return math.floor(d / 3600) .. "h ago" end
    return math.floor(d / 86400) .. "d ago"
end

function Util.Duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
    if seconds < 86400 then return string.format("%dh %dm", seconds / 3600, (seconds % 3600) / 60) end
    return string.format("%dd %dh", seconds / 86400, (seconds % 86400) / 3600)
end

-------------------------------------------------------------------------------
-- Links and escape sequences
-------------------------------------------------------------------------------
function Util.ParseItemLink(text)
    local id, name = string.match(tostring(text or ""), "|Hitem:(%d+)[^|]*|h%[(.-)%]|h")
    if id then return tonumber(id), name end
end

function Util.ParseQuestLink(text)
    local id, name = string.match(tostring(text or ""), "|Hquest:(%d+)[^|]*|h%[(.-)%]|h")
    if id then return tonumber(id), name end
end

-- Replaces every hyperlink with its [Name] and removes all other escapes.
function Util.StripLinks(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
    return text
end

-- For text from other players: no escape sequences at all, bounded length.
function Util.Sanitize(text, maxLen)
    text = Util.StripLinks(text):gsub("|", "/"):gsub("[%c]", " ")
    text = Util.Trim(text)
    if maxLen and #text > maxLen then text = string.sub(text, 1, maxLen) end
    return text
end

-- Notes keep line breaks, but never interpret player-supplied rendering escapes.
function Util.PlainNotes(text, maxLen)
    text = Util.StripLinks(text):gsub("|", "/"):gsub("\r\n", "\n"):gsub("[%z\1-\8\11-\31\127]", " ")
    return string.sub(text, 1, maxLen or #text)
end

function Util.Color(hex, text)
    return "|cff" .. hex .. tostring(text) .. "|r"
end

function Util.Icon(texture, size)
    return string.format("|T%s:%d:%d:0:0|t", tostring(texture), size or 14, size or 14)
end

-------------------------------------------------------------------------------
-- Checksums (export strings)
-------------------------------------------------------------------------------
function Util.Adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + string.byte(s, i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

