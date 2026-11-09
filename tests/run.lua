-- Test runner. Run from the addon folder:
--   python tests/run.py        (uses lupa's Lua 5.1; pip install lupa)
--   lua5.1 tests/run.lua       (if you have a standalone Lua 5.1)
QB_TEST_ROOT = QB_TEST_ROOT or "tests/"
QB_ADDON_ROOT = QB_ADDON_ROOT or "./"

local Mock = dofile(QB_TEST_ROOT .. "wowmock.lua")

local T = { passed = 0, failed = 0, failures = {}, current = {}, results = {} }

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.ok(value, msg)
    if not value then error(msg or "expected a truthy value", 2) end
    return value
end

function T.no(value, msg)
    if value then error((msg or "expected a falsy value") .. ", got " .. fmt(value), 2) end
end

function T.contains(haystack, needle, msg)
    if type(haystack) ~= "string" or not string.find(haystack, needle, 1, true) then
        error((msg and (msg .. ": ") or "") .. fmt(needle) .. " not found in " .. fmt(haystack), 2)
    end
end

function T.near(actual, expected, tolerance, msg)
    if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1e-6) then
        error((msg and (msg .. ": ") or "") .. "expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.errors(fn, msg)
    local ok = pcall(fn)
    if ok then error(msg or "expected an error", 2) end
end

-- A fresh logged-in client. Returns mock, ns.
function T.client(opts, saved)
    local m = Mock.new(opts)
    if opts and opts.setup then opts.setup(m) end
    local ns = m.Login(saved)
    m.Advance(0.01)
    return m, ns
end

-- Counts caught Lua errors; tests assert none slipped through.
function T.noErrors(ns, where)
    if ns.Log.errorCount > 0 then
        local e = ns.Log.lastError
        error((where or "") .. " addon logged " .. ns.Log.errorCount .. " error(s); last: " .. tostring(e and e.message) ..
            "\n" .. tostring(e and e.stack), 2)
    end
end

function describe(name, fn)
    table.insert(T.current, name)
    fn()
    table.remove(T.current)
end

function it(name, fn)
    local full = table.concat(T.current, " > ") .. " > " .. name
    local ok, err = xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)
    T.results[#T.results + 1] = { name = full, spec = T.spec, passed = ok, error = not ok and err or nil }
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        T.failures[#T.failures + 1] = { name = full, err = err }
    end
end

local SPECS = {
    "static_spec", "util_spec", "serialize_spec", "db_spec", "parser_spec", "items_spec", "engine_spec",
    "goals_spec", "reminders_spec", "recurring_spec", "sync_spec", "ui_spec", "persistence_spec", "conformance_spec", "regression_spec", "personalization_spec", "qa_audit_spec", "layout_style_spec", "scroll_spec",
}

local only = QB_ONLY
if only then
    local found = false
    for _, spec in ipairs(SPECS) do if spec == only then found = true end end
    assert(found, "Unknown spec: " .. tostring(only))
end
for _, spec in ipairs(SPECS) do
    if not only or only == spec then
        T.spec = spec
        local chunk = assert(loadfile(QB_TEST_ROOT .. "spec/" .. spec .. ".lua"))
        local ok, err = pcall(chunk, T, Mock)
        if not ok then
            T.failed = T.failed + 1
            T.failures[#T.failures + 1] = { name = spec .. " (load)", err = tostring(err) }
        end
    end
end

print(string.format("\n%d passed, %d failed", T.passed, T.failed))
for _, f in ipairs(T.failures) do
    print("\nFAIL " .. f.name .. "\n  " .. tostring(f.err):gsub("\n", "\n  "))
end
QB_RESULT = { passed = T.passed, failed = T.failed, tests = T.results }
return T.failed

