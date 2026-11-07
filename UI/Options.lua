-- Options window (also linked from the game's AddOns settings page).
local _, ns = ...
local Theme, W = ns.Theme, ns.Widgets

local Options = ns:NewModule("Options")
local frame
local checks = {}

Options.ITEMS = {
    { "autoStart", "Move cards to In Progress when progress starts" },
    { "autoComplete", "Move cards to Done when their goals are complete" },
    { "progressMessages", "Show \"Peacebloom 6/20\" messages as you loot" },
    { "toasts", "Show completion and reminder popups" },
    { "sounds", "Play sounds" },
    { "reminders", "Zone and NPC reminders" },
    { "smartReminders", "Smart reminders: missing items at the AH, goal items in the bank" },
    { "includeBank", "Count items in the bank toward goals" },
    { "trackerShown", "Show the on-screen tracker" },
    { "trackerHideInCombat", "Hide the tracker in combat" },
    { "minimapShown", "Show the minimap button" },
    { "acceptShares", "Allow party, raid and guild members to offer shared boards" },
    { "debug", "Debug logging (verbose, shown in chat)" },
}

local function get(key)
    local s = ns.db.settings
    if key == "minimapShown" then return not s.minimap.hide end
    if key == "acceptShares" then return s.syncAccept ~= "never" end
    return s[key] == true
end

local function set(key, value)
    local s = ns.db.settings
    if key == "minimapShown" then s.minimap.hide = not value
    elseif key == "acceptShares" then s.syncAccept = value and "ask" or "never"
    elseif key == "debug" then ns.Log:SetDebug(value)
    else s[key] = value end
    ns.Log:Info("options", "%s = %s", key, tostring(value))
    ns:Fire("SETTINGS_CHANGED", key, value)
    if key == "trackerShown" or key == "trackerHideInCombat" then ns:Fire("TRACKER_SETTINGS") end
    if key == "includeBank" then ns.Engine:MarkAll() end
end

function Options:Create()
    if frame then return end
    frame = CreateFrame("Frame", "QuestboardOptions", UIParent, "BackdropTemplate")
    frame:SetSize(420, 70 + #self.ITEMS * 26)
    frame:SetPoint("CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder)
    table.insert(UISpecialFrames, "QuestboardOptions")
    local title = W.Text(frame, "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Questboard options  |cff959ba8" .. ns.version .. "|r")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    for i, item in ipairs(self.ITEMS) do
        local c = W.Check(frame, item[2], function(checked) set(item[1], checked) end)
        c:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 26)
        checks[item[1]] = c
    end
    local selftest = W.Button(frame, "Run self-test", 110, 22, function() ns.Commands:Handle("selftest") end)
    selftest:SetPoint("BOTTOMLEFT", 12, 10)
    local diag = W.Button(frame, "Diagnostics", 100, 22, function() ns.Commands:Handle("diag") end)
    diag:SetPoint("LEFT", selftest, "RIGHT", 6, 0)
    frame:SetScript("OnShow", function() Options:Refresh() end)
end

function Options:Refresh()
    for key, c in pairs(checks) do c:SetChecked(get(key)) end
end

function Options:Show()
    self:Create()
    frame:Show()
    self:Refresh()
end

function Options:OnLogin()
    ns:On("SHOW_OPTIONS", function() Options:Show() end)
    -- A small page in the game's AddOns settings that opens this window.
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel = CreateFrame("Frame")
        local text = W.Text(panel, "GameFontHighlight")
        text:SetPoint("TOPLEFT", 16, -16)
        text:SetText("Questboard: a to-do board with live goal tracking. Type /qb to open it.")
        local open = W.Button(panel, "Open Questboard options", 180, 24, function() Options:Show() end)
        open:SetPoint("TOPLEFT", 16, -44)
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Questboard")
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
        else
            ns.Log:Debug("options", "Settings page not registered: %s", tostring(category))
        end
    end
end

function Options:Internals()
    return { frame = frame, checks = checks }
end
