-- /tb diag (report) and /tb selftest (in-game checks).
local _, ns = ...
local Util = ns.Util

local Diag = ns:NewModule("Diagnostics")

-- Every client API Taskboard relies on. Missing ones disable a feature, they never crash.
Diag.CAPABILITIES = {
    { "C_Item.GetItemCount", "item tracking" },
    { "C_Item.GetItemInfoInstant", "item name lookup" },
    { "C_Item.GetItemNameByID", "item verification" },
    { "C_Item.RequestLoadItemDataByID", "item verification" },
    { "C_Item.GetItemIconByID", "item icons" },
    { "C_Container.GetContainerNumSlots", "bag scan" },
    { "C_Container.GetContainerItemInfo", "bag scan" },
    { "C_QuestLog.GetNumQuestLogEntries", "quest goals" },
    { "C_QuestLog.GetInfo", "quest goals" },
    { "C_QuestLog.IsQuestFlaggedCompleted", "quest goals" },
    { "C_QuestLog.GetLogIndexForQuestID", "quest goals" },
    { "C_QuestLog.IsComplete", "quest goals" },
    { "C_QuestLog.GetQuestObjectives", "quest objectives" },
    { "C_SkillInfo.GetNumSkillLines", "skill goals" },
    { "C_SkillInfo.GetSkillLineInfo", "skill goals" },
    { "C_Reputation.GetNumFactions", "reputation goals" },
    { "C_Reputation.GetFactionDataByIndex", "reputation goals" },
    { "C_Reputation.GetFactionDataByID", "reputation goals" },
    { "C_Map.GetBestMapForUnit", "map pins" },
    { "C_Map.GetPlayerMapPosition", "map pins" },
    { "C_Map.GetMapInfo", "map pins" },
    { "C_Map.SetUserWaypoint", "waypoints" },
    { "C_SuperTrack.SetSuperTrackedUserWaypoint", "waypoint arrow" },
    { "UiMapPoint.CreateFromCoordinates", "waypoints" },
    { "C_ChatInfo.SendAddonMessage", "sharing" },
    { "C_ChatInfo.RegisterAddonMessagePrefix", "sharing" },
    { "C_DateAndTime.GetSecondsUntilDailyReset", "daily cards" },
    { "C_DateAndTime.GetSecondsUntilWeeklyReset", "weekly cards" },
    { "C_Timer.After", "core" },
    { "C_Timer.NewTicker", "core" },
    { "ChatFrameUtil.InsertLink", "shift-click links" },
    { "GetMoney", "money goals" },
    { "UnitLevel", "level goals" },
    { "UnitXP", "level goals" },
    { "GetRealZoneText", "zone reminders" },
    { "PlaySound", "sounds" },
    { "IsInGroup", "sharing" },
    { "IsInRaid", "sharing" },
}

function Diag.Lookup(path)
    local value = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

function Diag:Capabilities()
    local out, missing = {}, 0
    for _, cap in ipairs(self.CAPABILITIES) do
        local ok = type(Diag.Lookup(cap[1])) == "function"
        if not ok then missing = missing + 1 end
        out[#out + 1] = { api = cap[1], feature = cap[2], ok = ok }
    end
    return out, missing
end

local function memoryKB()
    local addons = C_AddOns
    if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
    local fn = GetAddOnMemoryUsage or (addons and addons.GetAddOnMemoryUsage)
    if fn then
        local ok, kb = pcall(fn, ns.name)
        if ok then return kb end
    end
end

-- Returns the report as a list of lines (plain text, safe to copy).
function Diag:Report()
    local lines = {}
    local function add(fmt, ...) lines[#lines + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt end
    local version, build, _, interface = "?", "?", nil, "?"
    if GetBuildInfo then version, build, _, interface = GetBuildInfo() end
    add("Taskboard %s diagnostics, %s", ns.version, date("%Y-%m-%d %H:%M:%S"))
    add("Client %s (build %s), interface %s", tostring(version), tostring(build), tostring(interface))
    add("Character %s, level %s, zone %s", ns.CharKey(), tostring(UnitLevel and UnitLevel("player")),
        tostring(GetRealZoneText and GetRealZoneText()))

    local boards, cards, goals, byType, archived = 0, 0, 0, {}, 0
    for _, board in pairs(ns.db.boards) do
        boards = boards + 1
        for _, card in pairs(board.cards) do
            cards = cards + 1
            if card.archived then archived = archived + 1 end
            for _, g in ipairs(ns.Goals.CardGoals(card)) do
                goals = goals + 1
                byType[g.goal.type] = (byType[g.goal.type] or 0) + 1
            end
        end
    end
    local types = {}
    add("%s", ns.Reminders:MailboxStatus())
    for t, n in pairs(byType) do types[#types + 1] = t .. "=" .. n end
    table.sort(types)
    add("Data: %d board(s), %d card(s) (%d archived), %d goal(s) [%s], repairs at load: %d",
        boards, cards, archived, goals, table.concat(types, ", "), ns.DB.lastRepairs or 0)

    local e = ns.Engine.stats
    add("Engine: %d pass(es), %d card evaluation(s), last %.2f ms, avg %.2f ms, max %.2f ms, auto-started %d, auto-completed %d, errors %d",
        e.passes, e.cardsEvaluated, e.lastMs, e.avgMs, e.maxMs, e.autoStarted, e.autoCompleted, e.errors)
    local i = ns.Items.stats
    add("Items: %d bag scan(s), %d verified, %d mismatch(es), %d pending verification",
        i.bagScans, i.verified, i.mismatches, Util.Count(ns.Items.pending))
    local s = ns.Sync.stats
    add("Sync: sent %d, received %d, rejected %d, offers %d, imported %d, send failures %d, queue %d",
        s.sent, s.received, s.rejected, s.offers, s.imported, s.sendFailures, ns.Sync:QueueLength())
    add("Reminders shown: %d, recurring resets: %d", ns.Reminders.stats.shown, ns.Recurring.stats.resets)
    local r = ns.db.resets
    if r.nextDaily then add("Next daily reset in %s, weekly in %s", Util.Duration(r.nextDaily - Util.Now()), Util.Duration((r.nextWeekly or 0) - Util.Now())) end
    local kb = memoryKB()
    if kb then add("Memory: %.0f KB", kb) end

    local events = {}
    for name, n in pairs(ns.counters.events) do events[#events + 1] = { name, n } end
    table.sort(events, function(a, b) return a[2] > b[2] end)
    local top = {}
    for k = 1, math.min(8, #events) do top[#top + 1] = events[k][1] .. "=" .. events[k][2] end
    add("Events: %s", #top > 0 and table.concat(top, ", ") or "none yet")
    if ns.unsupportedEvents then
        local list = {}
        for name in pairs(ns.unsupportedEvents) do list[#list + 1] = name end
        table.sort(list)
        add("Unsupported events: %s", table.concat(list, ", "))
    end

    add("Errors: %d caught", ns.Log.errorCount)
    if ns.Log.lastError then
        add("Last error (%s): %s", Util.Ago(ns.Log.lastError.t), ns.Log.lastError.message)
        if ns.Log.lastError.stack then add("  %s", (ns.Log.lastError.stack:gsub("\n", "\n  "))) end
    end

    local caps, missing = self:Capabilities()
    add("APIs: %d of %d available", #caps - missing, #caps)
    for _, c in ipairs(caps) do
        if not c.ok then add("  MISSING %s (%s disabled)", c.api, c.feature) end
    end
    return lines
end

-------------------------------------------------------------------------------
-- Self-test: pure checks plus live API probes. Returns passed, failed, lines.
-------------------------------------------------------------------------------
function Diag:SelfTest()
    local passed, failed, lines = 0, 0, {}
    local function check(name, fn)
        local ok, err = pcall(fn)
        if ok and err == true then
            passed = passed + 1
            lines[#lines + 1] = "PASS " .. name
        else
            failed = failed + 1
            lines[#lines + 1] = "FAIL " .. name .. (type(err) == "string" and (": " .. err) or "")
        end
    end
    local P = ns.Parser
    check("parser: item goal", function()
        local spec = P.Parse("Get 20 Peacebloom #herbs !high")
        return spec.goal and spec.goal.type == "item" and spec.goal.target == 20 and spec.priority == 3 and spec.tags[1] == "herbs"
    end)
    check("parser: money goal", function() local g = P.ParseGoal("save 100g") return g and g.type == "money" and g.target == 1000000 end)
    check("parser: level goal", function() local g = P.ParseGoal("reach level 40") return g and g.type == "level" and g.target == 40 end)
    check("parser: rep goal", function() local g = P.ParseGoal("Honored with Stormwind") return g and g.type == "rep" and g.target == 6 end)
    check("parser: skill goal", function() local g = P.ParseGoal("Herbalism 150") return g and g.type == "skill" and g.target == 150 end)
    check("serializer: round trip", function()
        local t = { a = "x|y~z", n = 1.5, b = true, list = { 1, 2, { deep = "ok" } } }
        local back = ns.Serialize.Unpack(ns.Serialize.Pack(t))
        return back and back.a == t.a and back.list[3].deep == "ok" and back.n == 1.5
    end)
    check("serializer: rejects garbage", function() return ns.Serialize.Unpack("T S9999:x") == nil end)
    check("api: GetItemCount returns a number", function() return type(C_Item.GetItemCount(2447, false)) == "number" end)
    check("api: GetMoney", function() return type(GetMoney()) == "number" end)
    check("api: UnitLevel", function() return type(UnitLevel("player")) == "number" end)
    check("api: zone text", function() return type(GetRealZoneText()) == "string" end)
    check("api: daily reset", function() return type(C_DateAndTime.GetSecondsUntilDailyReset()) == "number" end)
    check("api: skill lines", function()
        if not C_SkillInfo then return "C_SkillInfo missing" end
        return type(C_SkillInfo.GetNumSkillLines()) == "number"
    end)
    check("api: factions", function() return type(C_Reputation.GetNumFactions()) == "number" end)
    check("api: quest log", function() return type(C_QuestLog.GetNumQuestLogEntries()) == "number" end)
    check("api: map position", function()
        local mapID = C_Map.GetBestMapForUnit("player")
        return mapID == nil or type(mapID) == "number"
    end)
    check("db: all boards valid", function()
        for _, board in pairs(ns.db.boards) do
            for _, col in ipairs(board.columns) do
                for _, id in ipairs(board.order[col.id]) do
                    if not board.cards[id] then return "dangling card id " .. id end
                end
            end
        end
        return true
    end)
    for _, line in ipairs(lines) do
        if string.sub(line, 1, 4) == "FAIL" then ns.Log:Warn("selftest", "%s", line) else ns.Log:Debug("selftest", "%s", line) end
    end
    ns.Log:Info("selftest", "Self-test: %d passed, %d failed", passed, failed)
    return passed, failed, lines
end

