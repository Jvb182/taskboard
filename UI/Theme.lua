-- Colors, fonts and backdrop helpers.
local _, ns = ...

local Theme = ns:NewModule("Theme")
local panels, texts, brands = {}, {}, {}

Theme.WHITE = "Interface\\Buttons\\WHITE8x8"
Theme.BAR = "Interface\\TargetingFrame\\UI-StatusBar"
Theme.BACKDROP = { bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
Theme.CLASSIC_WINDOW = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 7, right = 7, top = 7, bottom = 7 } }
Theme.CLASSIC_PANEL = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } }

Theme.colors = {
    window = { 0.055, 0.063, 0.082, 0.96 },
    windowBorder = { 0.20, 0.23, 0.30, 1 },
    panel = { 0.09, 0.10, 0.13, 0.95 },
    panelBorder = { 0.17, 0.19, 0.25, 1 },
    card = { 0.13, 0.145, 0.18, 1 },
    cardHover = { 0.17, 0.19, 0.24, 1 },
    cardBorder = { 0.22, 0.25, 0.32, 1 },
    cardDone = { 0.10, 0.13, 0.11, 1 },
    input = { 0.04, 0.045, 0.06, 1 },
    inputBorder = { 0.25, 0.28, 0.36, 1 },
    button = { 0.16, 0.18, 0.23, 1 },
    buttonHover = { 0.22, 0.25, 0.32, 1 },
    buttonActive = { 0.18, 0.36, 0.52, 1 },
    accent = { 0.31, 0.76, 0.97, 1 },
    text = { 0.92, 0.93, 0.95, 1 },
    muted = { 0.58, 0.61, 0.67, 1 },
    good = { 0.36, 0.84, 0.45, 1 },
    warn = { 1, 0.72, 0.30, 1 },
    bad = { 1, 0.35, 0.35, 1 },
    dropLine = { 0.31, 0.76, 0.97, 0.9 },
}

Theme.ROLE = {
    todo = { 0.45, 0.55, 0.80, 1 },
    doing = { 1.00, 0.72, 0.25, 1 },
    done = { 0.36, 0.84, 0.45, 1 },
    custom = { 0.70, 0.55, 0.95, 1 },
}

Theme.PRIORITY = {
    [0] = { 0.30, 0.33, 0.40, 1 },
    [1] = { 0.40, 0.65, 1.00, 1 },
    [2] = { 1.00, 0.65, 0.20, 1 },
    [3] = { 1.00, 0.30, 0.30, 1 },
}

Theme.HEX = { accent = "4fc3f7", muted = "959ba8", good = "5cd673", warn = "ffb84d", bad = "ff5a5a", gold = "ffd100" }

Theme.PRESETS = {
    { id = "midnight", name = "Midnight", tint = { 0, 0, 0 } },
    { id = "parchment", name = "Warm leather", tint = { 0.065, 0.033, -0.025 } },
    { id = "forest", name = "Forest", tint = { -0.015, 0.035, -0.005 } },
    { id = "violet", name = "Arcane", tint = { 0.035, -0.005, 0.055 } },
    { id = "contrast", name = "High contrast", tint = { -0.04, -0.04, -0.04 } },
    { id = "classic_stone", name = "Classic stone", tint = { 0.025, 0.015, 0.005 }, classic = true },
    { id = "classic_leather", name = "Classic leather", tint = { 0.085, 0.045, 0.005 }, classic = true },
    { id = "quest_log", name = "Quest parchment", tint = { 0, 0, 0 } },
    { id = "custom", name = "Custom", tint = { 0, 0, 0 } },
}
Theme.ACCENTS = {
    { id = "sky", name = "Sky", color = { 0.31, 0.76, 0.97 } },
    { id = "gold", name = "Gold", color = { 1, 0.79, 0.30 } },
    { id = "mint", name = "Mint", color = { 0.34, 0.88, 0.64 } },
    { id = "rose", name = "Rose", color = { 1, 0.47, 0.65 } },
    { id = "lilac", name = "Lilac", color = { 0.73, 0.59, 1 } },
}
local defaults = ns.Util.DeepCopy(Theme.colors)
local backgrounds = { window = true, panel = true, card = true, cardHover = true, cardDone = true,
    input = true, button = true, buttonHover = true, buttonActive = true }

Theme.CUSTOM_DEFAULTS = { background = { 0.055, 0.063, 0.082 }, text = { 0.92, 0.93, 0.95 },
    border = { 0.25, 0.28, 0.36 }, accent = { 0.31, 0.76, 0.97 } }

function Theme:CustomColors()
    local saved = ns.db.settings.customColors
    if type(saved) ~= "table" then saved = {}; ns.db.settings.customColors = saved end
    for key, fallback in pairs(self.CUSTOM_DEFAULTS) do
        if type(saved[key]) ~= "table" then saved[key] = {} end
        for i = 1, 3 do
            local v = tonumber(saved[key][i])
            if not v or v ~= v or v == math.huge or v == -math.huge then v = fallback[i] end
            saved[key][i] = ns.Util.Clamp(v, 0, 1)
        end
    end
    return saved
end

function Theme:IsParchment()
    local theme = ns.db.settings.theme
    return theme == "quest_log" or theme == "classic_stone" or theme == "classic_leather"
end

function Theme:Decorate(frame, bg, opaque)
    -- Some Blizzard classic textures contain alpha even at backdrop alpha 1.
    if opaque and not frame.taskboardSolid then
        -- Keep opaque dialogs above the backdrop fill when switching skins.
        frame.taskboardSolid = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        frame.taskboardSolid:SetAllPoints()
    end
    if frame.taskboardSolid then
        frame.taskboardSolid:SetDrawLayer("BACKGROUND", 1)
        frame.taskboardSolid:SetColorTexture(bg[1], bg[2], bg[3], 1)
        frame.taskboardSolid:SetShown(opaque == true)
    end
    local quest = self:IsParchment() and (bg == self.colors.window or bg == self.colors.panel)
    if quest and not frame.taskboardParchment then
        local art = frame:CreateTexture(nil, "BORDER")
        art:SetPoint("TOPLEFT", 7, -7); art:SetPoint("BOTTOMRIGHT", -7, 7)
        frame.taskboardParchment = art
        local available = not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo("QuestBG-Parchment")
        frame.taskboardParchmentOK = available and pcall(art.SetAtlas, art, "QuestBG-Parchment")
        if not frame.taskboardParchmentOK then
            art:SetTexture("Interface\\QuestFrame\\QuestBG")
            frame.taskboardParchmentOK = true
        end
    end
    if frame.taskboardParchment then
        frame.taskboardParchment:SetShown(quest and frame.taskboardParchmentOK)
        frame.taskboardParchment:SetAlpha(opaque and 1 or ns.db.settings.panelOpacity)
    end
end

function Theme.Text(region, font)
    local key = string.find(font or "", "Disable", 1, true) and "muted" or
        (string.find(font or "", "Normal", 1, true) and font ~= "ChatFontNormal" and "accent" or "text")
    texts[region] = key
    region:SetTextColor(unpack(Theme.colors[key]))
end

function Theme.Brand(region, suffix)
    brands[region] = suffix or ""
    region:SetText("|cff" .. Theme.HEX.accent .. "Task|rboard" .. (suffix or ""))
end

function Theme:Apply()
    local s = ns.db.settings
    local preset, accent = self.PRESETS[1], self.ACCENTS[1]
    for _, p in ipairs(self.PRESETS) do if p.id == s.theme then preset = p end end
    for _, a in ipairs(self.ACCENTS) do if a.id == s.accent then accent = a end end
    s.theme, s.accent = preset.id, accent.id
    local opacity = tonumber(s.panelOpacity)
    if not opacity or opacity ~= opacity then opacity = 0.96 end
    s.panelOpacity = ns.Util.Clamp(opacity, 0.35, 1)
    for key, color in pairs(self.colors) do
        local base = defaults[key]
        for i = 1, 4 do color[i] = base[i] end
        if backgrounds[key] then
            for i = 1, 3 do color[i] = ns.Util.Clamp(base[i] + preset.tint[i], 0.01, 0.4) end
            color[4] = s.panelOpacity
        end
    end
    for i = 1, 3 do
        self.colors.accent[i], self.colors.dropLine[i] = accent.color[i], accent.color[i]
        self.colors.buttonActive[i] = accent.color[i] * 0.4
    end
    if preset.id == "contrast" then
        for i = 1, 3 do self.colors.text[i] = 1; self.colors.muted[i] = 0.8; self.colors.panelBorder[i] = 0.55 end
    end
    if preset.id == "custom" or self:IsParchment() then
        local palette = preset.id == "custom" and self:CustomColors() or {
            background = { 0.88, 0.79, 0.60 }, text = { 0.18, 0.12, 0.06 },
            border = { 0.44, 0.31, 0.16 }, accent = { accent.color[1] * 0.42, accent.color[2] * 0.42, accent.color[3] * 0.42 } }
        for key, color in pairs(self.colors) do
            if backgrounds[key] then
                local amount = (key == "cardHover" or key == "buttonHover") and 0.16 or
                    (key == "window" or key == "panel") and 0 or 0.06
                for i = 1, 3 do color[i] = palette.background[i] * (1 - amount) + palette.text[i] * amount end
            elseif key:find("Border", 1, true) then
                for i = 1, 3 do color[i] = palette.border[i] end
            end
        end
        for i = 1, 3 do
            self.colors.text[i] = palette.text[i]
            self.colors.muted[i] = palette.text[i] * 0.75 + palette.background[i] * 0.25
            self.colors.accent[i], self.colors.dropLine[i] = palette.accent[i], palette.accent[i]
            self.colors.buttonActive[i] = palette.background[i] * 0.75 + palette.accent[i] * 0.25
        end
    end
    self.HEX.accent = string.format("%02x%02x%02x", self.colors.accent[1] * 255, self.colors.accent[2] * 255, self.colors.accent[3] * 255)
    for f, colors in pairs(panels) do
        local bg = colors[1]
        f:SetBackdrop(preset.classic and (bg == self.colors.window and self.CLASSIC_WINDOW or self.CLASSIC_PANEL) or self.BACKDROP)
        local fill = f.active and bg == self.colors.button and self.colors.buttonActive or bg
        f:SetBackdropColor(fill[1], fill[2], fill[3], colors[3] and 1 or fill[4])
        f:SetBackdropBorderColor(unpack(colors[2]))
        self:Decorate(f, bg, colors[3])
    end
    for region, key in pairs(texts) do region:SetTextColor(unpack(self.colors[key])) end
    for region, suffix in pairs(brands) do self.Brand(region, suffix) end
    ns:Fire("BOARD_REFRESH")
end

function Theme:OnLogin()
    self:Apply()
    ns:On("SETTINGS_CHANGED", function(key)
        if key == "theme" or key == "accent" or key == "panelOpacity" then Theme:Apply() end
    end)
end

function Theme.Panel(frame, bg, border, opaque)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    bg = bg or Theme.colors.panel
    local selected = ns.db and ns.db.settings and ns.db.settings.theme or "midnight"
    local classic = selected == "classic_stone" or selected == "classic_leather"
    frame:SetBackdrop(classic and (bg == Theme.colors.window and Theme.CLASSIC_WINDOW or Theme.CLASSIC_PANEL) or Theme.BACKDROP)
    frame:SetBackdropColor(bg[1], bg[2], bg[3], opaque and 1 or bg[4])
    frame:SetBackdropBorderColor(unpack(border or Theme.colors.panelBorder))
    panels[frame] = { bg, border or Theme.colors.panelBorder, opaque }
    Theme:Decorate(frame, bg, opaque)
end

function Theme.ProgressColor(frac, done)
    if done then return 0.30, 0.78, 0.40 end
    if frac >= 0.66 then return 0.55, 0.80, 0.35 end
    if frac >= 0.33 then return 0.95, 0.75, 0.25 end
    return 0.90, 0.50, 0.25
end

function Theme.RoleColor(role)
    if Theme:IsParchment() then
        local c = Theme.ROLE[role or "custom"] or Theme.ROLE.custom
        return { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1 }
    end
    return Theme.ROLE[role or "custom"] or Theme.ROLE.custom
end

