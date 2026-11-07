local T, Mock = ...
local m, ns = T.client()
local S = ns.Serialize

local function deepEq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

describe("Serialize", function()
    it("round-trips nested data with awkward strings", function()
        local data = { s = "pipe | tilde ~ colon : nul-free \n newline", n = -12.5, big = 1e15, t = true, f = false,
                       list = { 1, 2, 3, { x = "y" } }, [7] = "seven", empty = {}, unicode = "caf\195\169" }
        local packed = assert(S.Pack(data))
        T.ok(deepEq(S.Unpack(packed), data))
    end)

    it("skips private keys and functions", function()
        local back = S.Unpack(S.Pack({ keep = 1, _cache = 2, fn = function() end }))
        T.eq(back.keep, 1)
        T.eq(back._cache, nil)
        T.eq(back.fn, nil)
    end)

    it("refuses non-finite numbers and over-deep tables", function()
        T.no(S.Pack({ x = 1 / 0 }))
        local deep = {}
        local cur = deep
        for _ = 1, 30 do cur.n = {} cur = cur.n end
        T.no(S.Pack(deep))
    end)

    it("rejects malformed input without erroring", function()
        local bad = { "", "X", "T", "S5:ab", "S-1:", "S99999999:x", "N;", "Nabc;", "B2", "TS1:aS1:b", "TN1;N2;t extra",
                      "TS1:aTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT", "T" .. string.rep("N1;N1;", 20001) .. "t" }
        for _, s in ipairs(bad) do
            local v, err = S.Unpack(s)
            T.eq(v, nil, "rejects " .. s:sub(1, 20))
            T.ok(err, "returns a reason")
        end
    end)

    it("survives random garbage (fuzz)", function()
        math.randomseed(1234)
        for _ = 1, 400 do
            local len = math.random(0, 60)
            local chars = {}
            for i = 1, len do chars[i] = string.char(({ 83, 84, 116, 78, 66, 58, 59, 48, 49, 57, 97 })[math.random(1, 11)]) end
            local ok = pcall(S.Unpack, table.concat(chars))
            T.ok(ok, "Unpack never throws")
        end
    end)

    it("escapes to printable ASCII only", function()
        local raw = "a|b~c\n\0\255"
        local e = S.Escape(raw)
        T.no(e:find("[|%c\128-\255]"), "escaped has no pipes, control or high bytes")
        T.eq(S.Unescape(e), raw)
        T.no(S.Unescape("~Z1"), "bad escape rejected")
        T.no(S.Unescape("abc~4"), "truncated escape rejected")
    end)

    it("exports and imports with a checksum", function()
        local data = { name = "Board", cards = { a = { title = "x" } } }
        local text = S.Export(data)
        T.contains(text, "QB1:")
        T.ok(deepEq(S.Import(text), data))
        T.ok(deepEq(S.Import("  " .. text .. "\n"), data), "tolerates whitespace")
        local tampered = text:sub(1, -3) .. "X" .. text:sub(-1)
        local v, err = S.Import(tampered)
        T.eq(v, nil)
        T.ok(err)
        T.eq(S.Import("hello"), nil)
        T.eq(S.Import(text:sub(1, #text - 10)), nil, "truncated text fails")
    end)
end)
