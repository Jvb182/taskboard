-- Safe serializer for sync messages and export strings.
-- Never uses loadstring; the decoder is strict and bounded.
local _, ns = ...

local Serialize = {}
ns.Serialize = Serialize

local MAX_DEPTH, MAX_ITEMS, MAX_STRING = 12, 20000, 65536

-- Format: S<len>:<bytes> | N<number>; | B1 | B0 | T ... t  (tables are key,value pairs)
local function encode(v, out, depth)
    local kind = type(v)
    if kind == "string" then
        out[#out + 1] = "S" .. #v .. ":" .. v
    elseif kind == "number" then
        if v ~= v or v == math.huge or v == -math.huge then error("cannot serialize non-finite number") end
        out[#out + 1] = "N" .. string.format("%.17g", v) .. ";"
    elseif kind == "boolean" then
        out[#out + 1] = v and "B1" or "B0"
    elseif kind == "table" then
        if depth > MAX_DEPTH then error("table nested too deeply") end
        out[#out + 1] = "T"
        for k, x in pairs(v) do
            local kt, xt = type(k), type(x)
            -- Underscore keys are runtime caches and are never serialized.
            local private = kt == "string" and string.sub(k, 1, 1) == "_"
            if not private and (kt == "string" or kt == "number")
                and (xt == "string" or xt == "number" or xt == "boolean" or xt == "table") then
                encode(k, out, depth + 1)
                encode(x, out, depth + 1)
            end
        end
        out[#out + 1] = "t"
    else
        error("cannot serialize " .. kind)
    end
end

function Serialize.Pack(v)
    local out = {}
    local ok, err = pcall(encode, v, out, 0)
    if not ok then return nil, err end
    return table.concat(out)
end

function Serialize.Unpack(s)
    if type(s) ~= "string" then return nil, "not a string" end
    local pos, items, len = 1, 0, #s

    local function read(depth)
        if depth > MAX_DEPTH then error("too deep") end
        items = items + 1
        if items > MAX_ITEMS then error("too many items") end
        local tag = string.sub(s, pos, pos)
        if tag == "S" then
            local colon = string.find(s, ":", pos + 1, true)
            if not colon then error("bad string header") end
            local n = tonumber(string.sub(s, pos + 1, colon - 1))
            if not n or n < 0 or n > MAX_STRING or n ~= math.floor(n) then error("bad string length") end
            if colon + n > len then error("string past end") end
            local value = string.sub(s, colon + 1, colon + n)
            pos = colon + n + 1
            return value
        elseif tag == "N" then
            local semi = string.find(s, ";", pos + 1, true)
            if not semi then error("bad number") end
            local value = tonumber(string.sub(s, pos + 1, semi - 1))
            if not value or value ~= value then error("bad number") end
            pos = semi + 1
            return value
        elseif tag == "B" then
            local b = string.sub(s, pos + 1, pos + 1)
            pos = pos + 2
            if b == "1" then return true elseif b == "0" then return false end
            error("bad boolean")
        elseif tag == "T" then
            pos = pos + 1
            local t = {}
            while true do
                if pos > len then error("unterminated table") end
                if string.sub(s, pos, pos) == "t" then
                    pos = pos + 1
                    return t
                end
                local k = read(depth + 1)
                if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
                t[k] = read(depth + 1)
            end
        end
        error("unexpected '" .. tag .. "' at " .. pos)
    end

    local ok, value = pcall(read, 0)
    if not ok then return nil, value end
    if pos <= len then return nil, "trailing data" end
    return value
end

-- Transport encoding: only printable ASCII without '|' or '~' leaves the addon.
function Serialize.Escape(s)
    return (s:gsub("[%c~|\128-\255]", function(c) return string.format("~%02X", string.byte(c)) end))
end

function Serialize.Unescape(s)
    if string.find(s, "~[^%x]") or string.find(s, "~%x[^%x]") or string.find(s, "~%x?$") then
        return nil, "bad escape"
    end
    return (s:gsub("~(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- Export string: QB1:<adler32 hex>:<escaped payload>
function Serialize.Export(v)
    local packed, err = Serialize.Pack(v)
    if not packed then return nil, err end
    return string.format("QB1:%08x:%s", ns.Util.Adler32(packed), Serialize.Escape(packed))
end

function Serialize.Import(text)
    text = ns.Util.Trim(text)
    local sum, body = string.match(text, "^QB1:(%x+):(.*)$")
    if not sum then return nil, "not a Questboard export string" end
    local packed, err = Serialize.Unescape(body)
    if not packed then return nil, err end
    if tonumber(sum, 16) ~= ns.Util.Adler32(packed) then return nil, "checksum mismatch (string damaged or cut off)" end
    return Serialize.Unpack(packed)
end
