-- Options window (also linked from the game's AddOns settings page).
local _, ns = ...
local Theme, W = ns.Theme, ns.Widgets

local Options = ns:NewModule("Options")
local frame
local checks = {}
local pages, themeButtons, accentButtons, soundButtons = {}, {}, {}, {}
local opacity, opacityText, trackerOpacity, trackerOpacityText
local previewSwatches, customSwatches = {}, {}
local previewPanel, previewCard, previewTitle, contrastLabel
local nearbyInterval
local selectedPage = "general"
local tabs = {}

function Options:Page(name)
    selectedPage = name
    for key, page in pairs(pages) do page:SetShown(key == name) end
    for key, tab in pairs(tabs) do tab:SetActive(key == name) end
end

function Options:SetAppearance(key, value)
    if key ~= "theme" and key ~= "accent" and key ~= "panelOpacity" and key ~= "trackerOpacity" then return end
    ns.db.settings[key] = value
    if key == "accent" and ns.db.settings.theme == "custom" then
        for _, a in ipairs(Theme.ACCENTS) do
            if a.id == value then Theme:CustomColors().accent = ns.Util.DeepCopy(a.color) end
        end
    end
    ns:Fire("SETTINGS_CHANGED", key, value)
    self:Refresh()
end

function Options:SetCustomColor(key, r, g, b)
    if not Theme.CUSTOM_DEFAULTS[key] then return false end
    Theme:CustomColors()[key] = { r, g, b }
    Theme:CustomColors()
    ns.db.settings.theme = "custom"
    Theme:Apply(); self:Refresh()
    return true
end

function Options:OpenColorPicker(key)
    if not Theme.CUSTOM_DEFAULTS[key] then return end
    if self.picker then
        self.picker:Hide(); self.picker:LoadColor(key)
        self.picker:SetFrameLevel(frame:GetFrameLevel() + 20)
        self.picker:Show(); self.picker:Raise(); return
    end
    local f = CreateFrame("Frame", "TaskboardColorPicker", frame, "BackdropTemplate")
    self.picker = f
    f:SetSize(360, 290); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(frame:GetFrameLevel() + 20); f:EnableMouse(true)
    f:SetBackdrop(Theme.BACKDROP); f:SetBackdropColor(0.07, 0.08, 0.10, 1); f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    if not self.pickerRegistered then table.insert(UISpecialFrames, "TaskboardColorPicker"); self.pickerRegistered = true end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -14); title:SetText("Custom " .. key); title:SetTextColor(1, 0.82, 0.3)
    W.CloseButton(f)
    local draft = ns.Util.DeepCopy(Theme:CustomColors()[key])
    local swatch = f:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 16, -44); swatch:SetSize(48, 36)
    local hex = W.EditBox(f, 120, 24, "RRGGBB")
    hex:SetPoint("TOPLEFT", 80, -50); hex:SetMaxLetters(7)
    local sliders, changing = {}, false
    local function refresh()
        swatch:SetColorTexture(draft[1], draft[2], draft[3], 1)
        hex:SetText(string.format("%02X%02X%02X", math.floor(draft[1] * 255 + 0.5), math.floor(draft[2] * 255 + 0.5), math.floor(draft[3] * 255 + 0.5)))
    end
    for i, name in ipairs({ "Red", "Green", "Blue" }) do
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 16, -100 - (i - 1) * 38); label:SetText(name); label:SetTextColor(1, 1, 1)
        local slider = CreateFrame("Slider", nil, f, "BackdropTemplate")
        slider:SetPoint("TOPLEFT", 80, -98 - (i - 1) * 38); slider:SetSize(250, 18)
        slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(0, 1)
        slider:SetThumbTexture(Theme.WHITE); slider:GetThumbTexture():SetSize(14, 18)
        slider:SetBackdrop(Theme.BACKDROP); slider:SetBackdropColor(0.3, 0.3, 0.3, 1)
        slider:SetValue(draft[i]); sliders[i] = slider
        slider:SetScript("OnValueChanged", function(_, value)
            if changing then return end
            draft[i] = value; refresh()
        end)
    end
    local function readHex()
        local value = hex:GetText():gsub("^#", "")
        if not value:match("^%x%x%x%x%x%x$") then ns.Print("Use six hex digits, for example 4FC3F7."); return false end
        changing = true
        for i = 1, 3 do draft[i] = tonumber(value:sub(i * 2 - 1, i * 2), 16) / 255; sliders[i]:SetValue(draft[i]) end
        changing = false; refresh(); return true
    end
    hex:SetScript("OnEnterPressed", function() if readHex() then hex:ClearFocus() end end)
    local apply = W.Button(f, "Apply", 100, 24, function()
        if readHex() then Options:SetCustomColor(f.colorKey, unpack(draft)); f:Hide() end
    end)
    apply:SetPoint("BOTTOMRIGHT", -16, 16)
    local cancel = W.Button(f, "Cancel", 100, 24, function() f:Hide() end)
    cancel:SetPoint("RIGHT", apply, "LEFT", -8, 0)
    f.sliders, f.hex, f.applyButton, f.cancelButton = sliders, hex, apply, cancel
    function f:LoadColor(colorKey)
        self.colorKey = colorKey; title:SetText("Custom " .. colorKey)
        changing = true
        local value = Theme:CustomColors()[colorKey]
        for i = 1, 3 do draft[i] = value[i]; sliders[i]:SetValue(draft[i]) end
        changing = false; refresh()
    end
    f:LoadColor(key); f:Show(); f:Raise()
end

function Options:SetSound(kind, choice)
    if ns.db.settings.soundEvents[kind] == nil then return end
    for _, item in ipairs(ns.Toast.SOUND_CHOICES) do
        if item[1] == choice then ns.db.settings.soundEvents[kind] = choice; self:Refresh(); return end
    end
end

Options.ITEMS = {
    { "autoStart", "Move cards to In Progress when progress starts" },
    { "autoComplete", "Complete finished goals and mail checks automatically" },
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
    frame:SetSize(800, 660)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
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
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Taskboard options  |cff959ba8" .. ns.version .. "|r")
    local close = W.CloseButton(frame)
    close:SetPoint("TOPRIGHT", 2, 2)
    local nav = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 12, -54); nav:SetPoint("BOTTOMLEFT", 12, 46); nav:SetWidth(154)
    Theme.Panel(nav, Theme.colors.panel, Theme.colors.panelBorder, true)
    for i, page in ipairs({ { "general", "General" }, { "style", "Appearance" },
        { "custom", "Custom colors" }, { "tracker", "Tracker" },
        { "reminders", "Reminders" }, { "sounds", "Sounds" }, { "advanced", "Advanced" } }) do
        local key = page[1]
        tabs[key] = W.Button(nav, page[2], 134, 32, function() Options:Page(key) end)
        tabs[key]:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 38)
        pages[key] = CreateFrame("Frame", nil, frame)
        pages[key]:SetPoint("TOPLEFT", 182, -62)
        pages[key]:SetPoint("BOTTOMRIGHT", -18, 48)
    end
    local function label(parent, text, y)
        local fs = W.Text(parent, "GameFontNormal")
        fs:SetPoint("TOPLEFT", 0, y); fs:SetText(text)
        return fs
    end
    local headings = {
        general = "General", tracker = "On-screen tracker", reminders = "Reminders & goals", advanced = "Sharing & diagnostics" }
    for key, heading in pairs(headings) do label(pages[key], heading, 0) end
    local groups = {
        general = { "autoStart", "autoComplete", "progressMessages", "toasts", "sounds", "minimapShown" },
        tracker = { "trackerShown", "trackerAllOpen", "trackerLocationPulse", "trackerHideInCombat" },
        reminders = { "reminders", "smartReminders", "includeBank" },
        advanced = { "acceptShares", "debug" },
    }
    local descriptions = {}
    for _, item in ipairs(self.ITEMS) do descriptions[item[1]] = item[2] end
    for group, keys in pairs(groups) do
        for i, key in ipairs(keys) do
            local c = W.Check(pages[group], descriptions[key], function(checked) set(key, checked) end)
            c:SetPoint("TOPLEFT", 4, -34 - (i - 1) * 30)
            checks[key] = c
        end
    end
    local bindingHelp = label(pages.general, "Keyboard shortcuts\nSet keys in WoW's Key Bindings > AddOns > Taskboard:\nBoard toggle, tracker toggle, and Quick Add.", -250)
    bindingHelp:SetWidth(550); bindingHelp:SetWordWrap(true)
    local mailHelp = label(pages.reminders,
        "Mailbox reminders\nCheck mail and similar tasks use the Mail reminder automatically. Open a mailbox once to teach Taskboard its location. On later visits it checks every 3 seconds and reminds within about 35 yards; the pulse ends beyond 50 yards. With automatic completion on, opening mail completes plain check-mail tasks without goals or subtasks.", -160)
    mailHelp:SetWidth(550); mailHelp:SetWordWrap(true)
    local styleScroll, style = W.Scroll(pages.style)
    styleScroll:SetPoint("TOPLEFT", 0, 0); styleScroll:SetPoint("BOTTOMRIGHT", -20, 0)
    style:SetSize(548, 690)
    label(style, "Choose a theme", 0)
    local intro = W.Text(style, "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 0, -21)
    intro:SetText("Preview the look, then choose a preset. Changes apply immediately.")
    for i, preset in ipairs(Theme.PRESETS) do
        local b = W.Button(style, preset.name, 172, 82, function()
            Options:SetAppearance("theme", preset.id)
            if preset.id == "custom" then Options:Page("custom") end
        end)
        b:SetPoint("TOPLEFT", ((i - 1) % 3) * 182, -48 - math.floor((i - 1) / 3) * 90)
        b.label:ClearAllPoints(); b.label:SetPoint("BOTTOMLEFT", 9, 8)
        themeButtons[preset.id] = b
        local field = b:CreateTexture(nil, "ARTWORK")
        field:SetPoint("TOPLEFT", 6, -6); field:SetPoint("BOTTOMRIGHT", -6, 28)
        local color = preset.preview
        field:SetColorTexture(color[1], color[2], color[3], 1)
        local card = b:CreateTexture(nil, "OVERLAY")
        card:SetPoint("TOPLEFT", 16, -17); card:SetSize(80, 13)
        local light = preset.id == "quest_log" or preset.id == "classic_leather"
        card:SetColorTexture(light and 0.24 or 0.75, light and 0.17 or 0.80, light and 0.09 or 0.88, 0.7)
        previewSwatches[preset.id] = field
    end
    label(style, "Accent color", -330)
    for i, accent in ipairs(Theme.ACCENTS) do
        local b = W.Button(style, accent.name, 100, 30, function() Options:SetAppearance("accent", accent.id) end)
        b:SetPoint("TOPLEFT", (i - 1) * 110, -356); accentButtons[accent.id] = b
        local swatch = b:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("BOTTOMLEFT", 3, 2); swatch:SetPoint("BOTTOMRIGHT", -3, 2); swatch:SetHeight(4)
        swatch:SetColorTexture(accent.color[1], accent.color[2], accent.color[3], 1)
    end
    opacityText = label(style, "Board opacity", -410)
    opacity = CreateFrame("Slider", nil, style, "BackdropTemplate")
    opacity:SetPoint("TOPLEFT", 0, -438); opacity:SetSize(510, 18)
    opacity:SetOrientation("HORIZONTAL"); opacity:SetMinMaxValues(0.35, 1); opacity:SetValue(0.96)
    opacity:SetThumbTexture(Theme.WHITE); opacity:GetThumbTexture():SetSize(16, 20)
    Theme.Panel(opacity, Theme.colors.input, Theme.colors.panelBorder)
    opacity:SetScript("OnValueChanged", ns.Wrap("panel opacity", function(_, value)
        if math.abs(value - ns.db.settings.panelOpacity) > 0.001 then Options:SetAppearance("panelOpacity", value) end
    end))
    trackerOpacityText = label(style, "Tracker opacity", -486)
    trackerOpacity = CreateFrame("Slider", nil, style, "BackdropTemplate")
    trackerOpacity:SetPoint("TOPLEFT", 0, -514); trackerOpacity:SetSize(510, 18)
    trackerOpacity:SetOrientation("HORIZONTAL"); trackerOpacity:SetMinMaxValues(0.35, 1); trackerOpacity:SetValue(0.96)
    trackerOpacity:SetThumbTexture(Theme.WHITE); trackerOpacity:GetThumbTexture():SetSize(16, 20)
    Theme.Panel(trackerOpacity, Theme.colors.input, Theme.colors.panelBorder)
    trackerOpacity:SetScript("OnValueChanged", ns.Wrap("tracker opacity", function(_, value)
        if math.abs(value - ns.db.settings.trackerOpacity) > 0.001 then Options:SetAppearance("trackerOpacity", value) end
    end))
    local help = label(style, "Board and tracker opacity are independent. Settings, editors and Help stay solid.", -552)
    help:SetWordWrap(true); help:SetWidth(540)
    local customLink = W.Button(style, "Edit custom colors", 180, 26, function() Options:Page("custom") end)
    customLink:SetPoint("TOPLEFT", 0, -594)
    local reset = W.Button(style, "Reset appearance", 150, 26, function()
        ns.db.settings.theme, ns.db.settings.accent, ns.db.settings.panelOpacity, ns.db.settings.trackerOpacity = "midnight", "sky", 0.96, 0.96
        ns.db.settings.customColors = nil
        Theme:Apply(); Options:Refresh()
    end)
    reset:SetPoint("LEFT", customLink, "RIGHT", 12, 0)

    label(pages.custom, "Custom color studio", 0)
    local customHelp = W.Text(pages.custom, "GameFontHighlightSmall")
    customHelp:SetPoint("TOPLEFT", 0, -25); customHelp:SetWidth(550); customHelp:SetWordWrap(true)
    customHelp:SetText("Pick a color with RGB sliders or a six-digit hex value. Apply saves it and selects Custom; Cancel discards the draft.")
    for i, item in ipairs({ { "background", "Background" }, { "card", "Cards" },
        { "text", "Text" }, { "border", "Borders" }, { "accent", "Accent" } }) do
        local key = item[1]
        local button = W.Button(pages.custom, item[2], 160, 50, function() Options:OpenColorPicker(key) end)
        button:SetPoint("TOPLEFT", ((i - 1) % 3) * 182, -92 - math.floor((i - 1) / 3) * 64)
        button.label:ClearAllPoints(); button.label:SetPoint("LEFT", 42, 0)
        local swatch = button:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("LEFT", 9, 0); swatch:SetSize(24, 24)
        customSwatches[key] = swatch
    end
    contrastLabel = label(pages.custom, "", -240)
    contrastLabel:SetWidth(540); contrastLabel:SetWordWrap(true)
    label(pages.custom, "Live preview", -290)
    previewPanel = CreateFrame("Frame", nil, pages.custom, "BackdropTemplate")
    previewPanel:SetPoint("TOPLEFT", 0, -320); previewPanel:SetSize(548, 178)
    previewPanel:SetBackdrop(Theme.BACKDROP)
    previewCard = CreateFrame("Frame", nil, previewPanel, "BackdropTemplate")
    previewCard:SetPoint("TOPLEFT", 18, -36); previewCard:SetSize(300, 90)
    previewCard:SetBackdrop(Theme.BACKDROP)
    previewTitle = W.Text(previewCard, "GameFontHighlight")
    previewTitle:SetPoint("TOPLEFT", 12, -12); previewTitle:SetText("Prepare for raid night")
    local previewDetail = W.Text(previewCard, "GameFontHighlightSmall")
    previewDetail:SetPoint("TOPLEFT", 12, -38); previewDetail:SetText("Gather supplies  4/10")
    local previewNote = W.Text(previewPanel, "GameFontHighlightSmall")
    previewNote:SetPoint("BOTTOMLEFT", 18, 14); previewNote:SetText("Example card and tracker colors update as you edit.")

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
    checks.nearbySounds = W.Check(pages.sounds, "Repeat sound while nearby tasks flash", function(value) set("nearbySounds", value) end)
    checks.nearbySounds:SetPoint("TOPLEFT", 0, -270)
    nearbyInterval = W.Button(pages.sounds, "Every 30 sec", 120, 24, function()
        local items = {}
        for _, seconds in ipairs({ 15, 30, 60 }) do
            items[#items + 1] = { text = "Every " .. seconds .. " sec", checked = ns.db.settings.nearbySoundInterval == seconds,
                func = function() set("nearbySoundInterval", seconds); Options:Refresh() end }
        end
        W.Menu(nil, items)
    end)
    nearbyInterval:SetPoint("TOPRIGHT", -4, -270)
    local repeatHelp = label(pages.sounds, "Uses the Zone / NPC reminder sound. One sound per interval,\neven for several tasks. Stops when no flashing task is visible.\nOff by default; respects Play sounds and Zone/NPC reminders.", -306)
    repeatHelp:SetWidth(490); repeatHelp:SetWordWrap(true)
    local selftest = W.Button(frame, "Run self-test", 110, 22, function() ns.Commands:Handle("selftest") end)
    selftest:SetPoint("BOTTOMLEFT", 12, 10)
    local diag = W.Button(frame, "Diagnostics", 100, 22, function() ns.Commands:Handle("diag") end)
    diag:SetPoint("LEFT", selftest, "RIGHT", 6, 0)
    local resetAll = W.Button(frame, "Reset all data", 120, 22, function()
        W.Confirm("Reset Taskboard? This permanently deletes every board, task, setting, statistic, and diagnostic log on this account. Learned mailbox locations are kept. This cannot be undone.", function()
            ns.DB:ResetAll()
            if ReloadUI then ReloadUI() end
        end)
    end, "Erase tasks and settings, but keep learned mailbox locations")
    resetAll:SetPoint("BOTTOMRIGHT", -12, 10)
    resetAll.label:SetTextColor(1, 0.45, 0.4)
    frame:SetScript("OnShow", function() Options:Refresh() end)
    frame:SetScript("OnHide", function() if Options.picker then Options.picker:Hide() end end)
    self:Page(selectedPage)
end

function Options:Refresh()
    for key, c in pairs(checks) do c:SetChecked(get(key)) end
    local s = ns.db.settings
    if nearbyInterval then nearbyInterval:SetLabel("Every " .. tostring(s.nearbySoundInterval) .. " sec") end
    for id, b in pairs(themeButtons) do b:SetActive(id == s.theme) end
    for id, b in pairs(accentButtons) do b:SetActive(id == s.accent) end
    if opacity then opacity:SetValue(s.panelOpacity); opacityText:SetText(string.format("Board opacity: %d%%", s.panelOpacity * 100)) end
    if trackerOpacity then
        trackerOpacity:SetValue(s.trackerOpacity)
        trackerOpacityText:SetText(string.format("Tracker opacity: %d%%", s.trackerOpacity * 100))
    end
    local custom = Theme:CustomColors()
    for key, swatch in pairs(customSwatches) do
        local color = custom[key]
        swatch:SetColorTexture(color[1], color[2], color[3], 1)
    end
    if previewSwatches.custom then
        local color = custom.background
        previewSwatches.custom:SetColorTexture(color[1], color[2], color[3], 1)
    end
    if previewPanel then
        local c = Theme.colors
        previewPanel:SetBackdropColor(c.window[1], c.window[2], c.window[3], 1)
        previewPanel:SetBackdropBorderColor(unpack(c.windowBorder))
        previewCard:SetBackdropColor(c.card[1], c.card[2], c.card[3], 1)
        previewCard:SetBackdropBorderColor(unpack(c.cardBorder))
        previewTitle:SetTextColor(unpack(c.text))
        local ratio = math.min(Theme:ContrastRatio(custom.text, custom.background),
            Theme:ContrastRatio(custom.text, custom.card))
        contrastLabel:SetText(string.format("Custom text contrast: %.1f:1  %s",
            ratio, ratio >= 4.5 and "Readable for normal text" or "Low contrast; adjust Text or Cards"))
        contrastLabel:SetTextColor(ratio >= 4.5 and 0.35 or 1, ratio >= 4.5 and 0.85 or 0.55,
            ratio >= 4.5 and 0.50 or 0.35)
    end
    for kind, b in pairs(soundButtons) do
        local name = "Off"
        for _, choice in ipairs(ns.Toast.SOUND_CHOICES) do if choice[1] == s.soundEvents[kind] then name = choice[2] end end
        b:SetLabel(name)
    end
end

function Options:Show()
    self:Create()
    local board = ns.Board and ns.Board.frame
    local parent = board and board:IsShown() and board or UIParent
    frame:SetParent(parent)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(parent:GetFrameLevel() + 20)
    frame:Show()
    frame:Raise()
    self:Refresh()
end

function Options:Hide()
    if self.picker then self.picker:Hide() end
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
    return { frame = frame, checks = checks, pages = pages, opacity = opacity, trackerOpacity = trackerOpacity,
             customSwatches = customSwatches, previewPanel = previewPanel, contrastLabel = contrastLabel,
             themeButtons = themeButtons,
             accentButtons = accentButtons, soundButtons = soundButtons }
end

