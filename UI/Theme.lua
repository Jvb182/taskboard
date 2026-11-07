-- Colors, fonts and backdrop helpers.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

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

function Theme.Panel(frame, bg, border)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop(Theme.BACKDROP)
    frame:SetBackdropColor(unpack(bg or Theme.colors.panel))
    frame:SetBackdropBorderColor(unpack(border or Theme.colors.panelBorder))
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
