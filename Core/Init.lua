-- Questboard: namespace, safe dispatch, events, timers and module lifecycle.
local ADDON, ns = ...

ns.name = ADDON
ns.version = "dev"
if C_AddOns and C_AddOns.GetAddOnMetadata then
    ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
end

-- The only global Questboard creates (besides SavedVariables, slash and binding
-- names). Handy for /dump Questboard.Engine.stats while debugging.
Questboard = ns

ns.modules, ns.moduleOrder = {}, {}
ns.counters = { events = {}, errors = 0, timers = 0 }

-------------------------------------------------------------------------------
-- Safe calls: every handler runs under xpcall so one bug never breaks the UI.
-------------------------------------------------------------------------------
local function capture(err)
    local stack = debugstack and debugstack(2, 12, 0) or (debug and debug.traceback and debug.traceback()) or ""
    return { message = tostring(err), stack = stack }
end

function ns.Safe(where, fn, ...)
    local n, args = select("#", ...), { ... }
    local result = { xpcall(function() return fn(unpack(args, 1, n)) end, capture) }
    if not result[1] then
        ns.counters.errors = ns.counters.errors + 1
        local e = result[2]
        if ns.Log then
            ns.Log:Exception(where, e.message, e.stack)
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Questboard error in " .. tostring(where) .. ":|r " .. e.message)
        end
        return false
    end
    return unpack(result, 1, table.maxn(result))
end

-- Wraps a function so it always runs safely (for SetScript handlers).
function ns.Wrap(where, fn)
    return function(...) return ns.Safe(where, fn, ...) end
end

-------------------------------------------------------------------------------
-- Internal messages (pub/sub between modules and UI)
-------------------------------------------------------------------------------
local listeners = {}

function ns:On(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns:Fire(message, ...)
    local list = listeners[message]
    if not list then return end
    for i = 1, #list do
        ns.Safe("message " .. message, list[i], ...)
    end
end

-------------------------------------------------------------------------------
-- Game events
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}
ns.eventFrame = eventFrame

-- Registers fn for a game event. Returns false (and logs) if this client does
-- not know the event, instead of erroring like RegisterEvent would.
function ns:RegisterEvent(event, fn)
    if not handlers[event] then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then
            if ns.Log then ns.Log:Warn("events", "This client does not support event %s", event) end
            ns.unsupportedEvents = ns.unsupportedEvents or {}
            ns.unsupportedEvents[event] = true
            return false
        end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

function ns:HasEventHandlers(event)
    return handlers[event] ~= nil
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    ns.counters.events[event] = (ns.counters.events[event] or 0) + 1
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        ns.Safe("event " .. event, list[i], event, ...)
    end
end)

-------------------------------------------------------------------------------
-- Timers
-------------------------------------------------------------------------------
function ns.After(seconds, where, fn)
    ns.counters.timers = ns.counters.timers + 1
    C_Timer.After(seconds, function() ns.Safe(where, fn) end)
end

function ns.Ticker(seconds, where, fn)
    return C_Timer.NewTicker(seconds, function() ns.Safe(where, fn) end)
end

-------------------------------------------------------------------------------
-- Modules: OnInit after SavedVariables load, OnLogin once the player exists.
-------------------------------------------------------------------------------
function ns:NewModule(name)
    local module = { name = name }
    ns.modules[name] = module
    table.insert(ns.moduleOrder, module)
    ns[name] = module
    return module
end

local function runPhase(phase)
    for _, module in ipairs(ns.moduleOrder) do
        if module[phase] then
            ns.Safe(module.name .. ":" .. phase, module[phase], module)
        end
    end
end

ns:RegisterEvent("ADDON_LOADED", function(_, loaded)
    if loaded ~= ADDON then return end
    ns.loaded = true
    runPhase("OnInit")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    ns.loggedIn = true
    runPhase("OnLogin")
    ns:Fire("READY")
end)

ns:RegisterEvent("PLAYER_LOGOUT", function()
    runPhase("OnLogout")
end)

-- "Name-Realm" for the current character.
function ns.CharKey()
    if ns._charKey then return ns._charKey end
    local name = UnitName("player") or "Unknown"
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    realm = realm:gsub("%s", "")
    if realm == "" then return name end -- not cached: realm may not be ready yet
    ns._charKey = name .. "-" .. realm
    return ns._charKey
end

function ns.Print(fmt, ...)
    local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7Questboard|r: " .. text)
end
