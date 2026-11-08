-- Colors, fonts and backdrop helpers.
local _, ns = ...

local Theme = ns:NewModule("Theme")
local panels, texts, brands = {}, {}, {}

Theme.WHITE = "Interface\\Buttons\\WHITE8x8"
Theme.BAR = "Interface\\TargetingFrame\\UI-StatusBar"
Theme.BACKDROP = { bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

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
    self.HEX.accent = string.format("%02x%02x%02x", accent.color[1] * 255, accent.color[2] * 255, accent.color[3] * 255)
    for f, colors in pairs(panels) do
        local bg = colors[1]
        f:SetBackdropColor(bg[1], bg[2], bg[3], colors[3] and 1 or bg[4])
        f:SetBackdropBorderColor(unpack(colors[2]))
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
    frame:SetBackdrop(Theme.BACKDROP)
    bg = bg or Theme.colors.panel
    frame:SetBackdropColor(bg[1], bg[2], bg[3], opaque and 1 or bg[4])
    frame:SetBackdropBorderColor(unpack(border or Theme.colors.panelBorder))
    panels[frame] = { bg, border or Theme.colors.panelBorder, opaque }
end

function Theme.ProgressColor(frac, done)
    if done then return 0.30, 0.78, 0.40 end
    if frac >= 0.66 then return 0.55, 0.80, 0.35 end
    if frac >= 0.33 then return 0.95, 0.75, 0.25 end
    return 0.90, 0.50, 0.25
end

function Theme.RoleColor(role)
    return Theme.ROLE[role or "custom"] or Theme.ROLE.custom
end

