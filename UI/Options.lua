-- Options window (also linked from the game's AddOns settings page).
local _, ns = ...
local Theme, W = ns.Theme, ns.Widgets

local Options = ns:NewModule("Options")
local frame
local checks = {}
local pages, themeButtons, accentButtons, soundButtons = {}, {}, {}, {}
local opacity, opacityText
local selectedPage = "general"
local tabs = {}

function Options:Page(name)
    selectedPage = name
    for key, page in pairs(pages) do page:SetShown(key == name) end
    for key, tab in pairs(tabs) do tab:SetActive(key == name) end
end

function Options:SetAppearance(key, value)
    if key ~= "theme" and key ~= "accent" and key ~= "panelOpacity" then return end
    ns.db.settings[key] = value
    ns:Fire("SETTINGS_CHANGED", key, value)
    self:Refresh()
end

function Options:SetSound(kind, choice)
    if ns.db.settings.soundEvents[kind] == nil then return end
    for _, item in ipairs(ns.Toast.SOUND_CHOICES) do
        if item[1] == choice then ns.db.settings.soundEvents[kind] = choice; self:Refresh(); return end
    end
end

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
    { "trackerAllOpen", "Tracker: include all open tasks (including To Do)" },
    { "trackerLocationPulse", "Tracker: show and pulse location tasks while nearby" },
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
    if key == "trackerShown" or key == "trackerHideInCombat" or key == "trackerAllOpen" or key == "trackerLocationPulse" then ns:Fire("TRACKER_SETTINGS") end
    if key == "includeBank" then ns.Engine:MarkAll() end
end

function Options:Create()
    if frame then return end
    frame = CreateFrame("Frame", "TaskboardOptions", UIParent, "BackdropTemplate")
    frame:SetSize(540, 480)
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
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder, true)
    table.insert(UISpecialFrames, "TaskboardOptions")
    local title = W.Text(frame, "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Taskboard options  |cff959ba8" .. ns.version .. "|r")
    local close = W.CloseButton(frame)
    close:SetPoint("TOPRIGHT", 2, 2)
    for i, page in ipairs({ { "general", "General" }, { "style", "Appearance" }, { "sounds", "Sounds" } }) do
        local key = page[1]
        tabs[key] = W.Button(frame, page[2], 110, 22, function() Options:Page(key) end)
        tabs[key]:SetPoint("TOPLEFT", 12 + (i - 1) * 116, -32)
        pages[key] = CreateFrame("Frame", nil, frame)
        pages[key]:SetPoint("TOPLEFT", 12, -68)
        pages[key]:SetPoint("BOTTOMRIGHT", -12, 44)
    end
    local generalScroll, generalContent = W.Scroll(pages.general)
    generalScroll:SetPoint("TOPLEFT", 0, 0)
    generalScroll:SetPoint("BOTTOMRIGHT", -20, 0)
    generalContent:SetSize(490, #self.ITEMS * 26)
    for i, item in ipairs(self.ITEMS) do
        local c = W.Check(generalContent, item[2], function(checked) set(item[1], checked) end)
        c:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
        checks[item[1]] = c
    end

    local function label(parent, text, y)
        local fs = W.Text(parent, "GameFontNormal")
        fs:SetPoint("TOPLEFT", 0, y); fs:SetText(text)
        return fs
    end
    label(pages.style, "Theme", 0)
    for i, preset in ipairs(Theme.PRESETS) do
        local b = W.Button(pages.style, preset.name, 120, 26, function() Options:SetAppearance("theme", preset.id) end)
        b:SetPoint("TOPLEFT", ((i - 1) % 4) * 125, -24 - math.floor((i - 1) / 4) * 34); themeButtons[preset.id] = b
    end
    label(pages.style, "Accent color", -108)
    for i, accent in ipairs(Theme.ACCENTS) do
        local b = W.Button(pages.style, accent.name, 96, 26, function() Options:SetAppearance("accent", accent.id) end)
        b:SetPoint("TOPLEFT", (i - 1) * 102, -132); accentButtons[accent.id] = b
        local swatch = b:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("BOTTOMLEFT", 3, 2); swatch:SetPoint("BOTTOMRIGHT", -3, 2); swatch:SetHeight(2)
        swatch:SetColorTexture(accent.color[1], accent.color[2], accent.color[3], 1)
    end
    opacityText = label(pages.style, "Panel opacity", -184)
    opacity = CreateFrame("Slider", nil, pages.style, "BackdropTemplate")
    opacity:SetPoint("TOPLEFT", 0, -212); opacity:SetSize(420, 18)
    opacity:SetOrientation("HORIZONTAL"); opacity:SetMinMaxValues(0.35, 1); opacity:SetValue(0.96)
    opacity:SetThumbTexture(Theme.WHITE); opacity:GetThumbTexture():SetSize(16, 20)
    Theme.Panel(opacity, Theme.colors.input, Theme.colors.panelBorder)
    opacity:SetScript("OnValueChanged", ns.Wrap("panel opacity", function(_, value)
        if math.abs(value - ns.db.settings.panelOpacity) > 0.001 then Options:SetAppearance("panelOpacity", value) end
    end))
    local help = label(pages.style, "Classic skins use the original WoW frame and tooltip artwork.\nOpacity affects the board and tracker; settings and menus stay opaque.\nStatus and priority colors keep their meaning across themes.", -244)
    help:SetWordWrap(true); help:SetWidth(500)
    local reset = W.Button(pages.style, "Reset appearance", 150, 24, function()
        ns.db.settings.theme, ns.db.settings.accent, ns.db.settings.panelOpacity = "midnight", "sky", 0.96
        Theme:Apply(); Options:Refresh()
    end)
    reset:SetPoint("TOPLEFT", 0, -324)

    local soundHelp = label(pages.sounds, "Choose a sound for each event, or turn that event off.\nSounds work even when visual popups are disabled.\nVolume follows the game's sound settings.", 0)
    soundHelp:SetWordWrap(true); soundHelp:SetWidth(500)
    for i, item in ipairs({ { "move", "Status changed" }, { "complete", "Task completed" }, { "subtask", "Subtask completed" }, { "reminder", "Zone / NPC reminder" } }) do
        local kind = item[1]
        label(pages.sounds, item[2], -80 - (i - 1) * 48)
        local b = W.Button(pages.sounds, "", 140, 24, function()
            local choices = {}
            for _, choice in ipairs(ns.Toast.SOUND_CHOICES) do
                choices[#choices + 1] = { text = choice[2], checked = ns.db.settings.soundEvents[kind] == choice[1],
                    func = function() Options:SetSound(kind, choice[1]) end }
            end
            W.Menu(nil, choices)
        end)
        b:SetPoint("TOPLEFT", 220, -74 - (i - 1) * 48); soundButtons[kind] = b
        local preview = W.Button(pages.sounds, "Preview", 90, 24, function() ns.Toast:PlaySound(kind, true) end,
            "Preview respects Play sounds in General and the game's volume settings")
        preview:SetPoint("LEFT", b, "RIGHT", 10, 0)
    end
    local selftest = W.Button(frame, "Run self-test", 110, 22, function() ns.Commands:Handle("selftest") end)
    selftest:SetPoint("BOTTOMLEFT", 12, 10)
    local diag = W.Button(frame, "Diagnostics", 100, 22, function() ns.Commands:Handle("diag") end)
    diag:SetPoint("LEFT", selftest, "RIGHT", 6, 0)
    frame:SetScript("OnShow", function() Options:Refresh() end)
    self:Page(selectedPage)
end

function Options:Refresh()
    for key, c in pairs(checks) do c:SetChecked(get(key)) end
    local s = ns.db.settings
    for id, b in pairs(themeButtons) do b:SetActive(id == s.theme) end
    for id, b in pairs(accentButtons) do b:SetActive(id == s.accent) end
    if opacity then opacity:SetValue(s.panelOpacity); opacityText:SetText(string.format("Panel opacity: %d%%", s.panelOpacity * 100)) end
    for kind, b in pairs(soundButtons) do
        local name = "Off"
        for _, choice in ipairs(ns.Toast.SOUND_CHOICES) do if choice[1] == s.soundEvents[kind] then name = choice[2] end end
        b:SetLabel(name)
    end
end

function Options:Show()
    self:Create()
    frame:Show()
    self:Refresh()
end

function Options:Hide()
    if frame then frame:Hide() end
end

function Options:OnLogin()
    ns:On("SHOW_OPTIONS", function() Options:Show() end)
    -- A small page in the game's AddOns settings that opens this window.
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel = CreateFrame("Frame")
        local text = W.Text(panel, "GameFontHighlight")
        text:SetPoint("TOPLEFT", 16, -16)
        text:SetText("Taskboard: a to-do board with live goal tracking. Type /tb to open it.")
        local open = W.Button(panel, "Open Taskboard options", 180, 24, function() Options:Show() end)
        open:SetPoint("TOPLEFT", 16, -44)
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Taskboard")
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
        else
            ns.Log:Debug("options", "Settings page not registered: %s", tostring(category))
        end
    end
end

function Options:Internals()
    return { frame = frame, checks = checks, pages = pages, opacity = opacity, themeButtons = themeButtons,
             accentButtons = accentButtons, soundButtons = soundButtons }
end

