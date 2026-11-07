-- Small reusable widgets with a consistent flat look.
local _, ns = ...
local Theme = ns.Theme

local W = {}
ns.Widgets = W

function W.Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function W.Tooltip(owner, lines)
    if not lines then return end
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local list = type(lines) == "function" and lines(self) or lines
        if type(list) == "string" then list = { list } end
        for i, line in ipairs(list) do
            if i == 1 then GameTooltip:SetText(line, 1, 1, 1) else GameTooltip:AddLine(line, 0.8, 0.82, 0.86, true) end
        end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Flat text button. onClick(self, mouseButton)
function W.Button(parent, text, width, height, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 80, height or 20)
    Theme.Panel(b, Theme.colors.button, Theme.colors.panelBorder)
    b.label = W.Text(b, "GameFontHighlightSmall", "CENTER")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text or "")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        if self.active then return end
        self:SetBackdropColor(unpack(Theme.colors.buttonHover))
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.active and Theme.colors.buttonActive or Theme.colors.button))
    end)
    if onClick then b:SetScript("OnClick", ns.Wrap("button " .. tostring(text), onClick)) end
    function b:SetActive(active)
        self.active = active and true or false
        self:SetBackdropColor(unpack(self.active and Theme.colors.buttonActive or Theme.colors.button))
    end
    function b:SetLabel(t) self.label:SetText(t) end
    W.Tooltip(b, tooltip)
    return b
end

function W.IconButton(parent, texture, size, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 18, size or 18)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(texture)
    b:SetHighlightTexture(Theme.WHITE)
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if onClick then b:SetScript("OnClick", ns.Wrap("icon button", onClick)) end
    W.Tooltip(b, tooltip)
    return b
end

-- Shift-clicked links go into whichever of these edit boxes has focus.
W.linkTargets = {}
local hooked = false
local function hookLinks()
    if hooked then return end
    local function insert(link)
        if type(link) ~= "string" then return end
        for box in pairs(W.linkTargets) do
            if box:IsVisible() and box:HasFocus() then
                box:Insert(link)
                return
            end
        end
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", insert)
        hooked = true
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", insert)
        hooked = true
    else
        ns.Log:Warn("ui", "No link insertion hook available; shift-click into Questboard won't work")
    end
end

function W.EditBox(parent, width, height, placeholder, acceptLinks)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width or 160, height or 22)
    Theme.Panel(e, Theme.colors.input, Theme.colors.inputBorder)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    e:SetTextInsets(6, 6, 2, 2)
    e:SetMaxLetters(255)
    e.placeholder = W.Text(e, "GameFontDisableSmall")
    e.placeholder:SetPoint("LEFT", 7, 0)
    e.placeholder:SetPoint("RIGHT", -6, 0)
    e.placeholder:SetText(placeholder or "")
    local function update(self)
        self.placeholder:SetShown(self:GetText() == "" and not self:HasFocus())
    end
    e:SetScript("OnEditFocusGained", function(self)
        update(self)
        self:SetBackdropBorderColor(unpack(Theme.colors.accent))
    end)
    e:SetScript("OnEditFocusLost", function(self)
        update(self)
        self:SetBackdropBorderColor(unpack(Theme.colors.inputBorder))
    end)
    e:SetScript("OnTextChanged", function(self) update(self) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    function e:Refresh() update(self) end
    if acceptLinks then
        hookLinks()
        W.linkTargets[e] = true
    end
    return e
end

function W.ProgressBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height or 10)
    bar:SetStatusBarTexture(Theme.BAR)
    bar:SetMinMaxValues(0, 1)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.45)
    bar.text = W.Text(bar, "GameFontHighlightSmall", "CENTER")
    bar.text:SetPoint("CENTER", 0, 0)
    function bar:SetProgress(frac, done, text)
        frac = frac or 0
        self:SetValue(frac)
        self:SetStatusBarColor(Theme.ProgressColor(frac, done))
        self.text:SetText(text or "")
    end
    return bar
end

function W.Check(parent, label, onToggle, tooltip)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    if c.Text then
        c.Text:SetText(label or "")
        c.Text:SetFontObject("GameFontHighlightSmall")
    end
    c:SetScript("OnClick", ns.Wrap("check " .. tostring(label), function(self)
        if onToggle then onToggle(self:GetChecked() and true or false, self) end
    end))
    W.Tooltip(c, tooltip)
    return c
end

function W.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    return scroll, content
end

-------------------------------------------------------------------------------
-- Context menu: one shared frame. items = { {text, func, disabled, checked, title, color} }
-------------------------------------------------------------------------------
local menu, blocker
local function hideMenu()
    if menu then menu:Hide() end
    if blocker then blocker:Hide() end
end
W.HideMenu = hideMenu

function W.Menu(owner, items)
    if not menu then
        blocker = CreateFrame("Button", nil, UIParent)
        blocker:SetAllPoints(UIParent)
        blocker:SetFrameStrata("FULLSCREEN")
        blocker:RegisterForClicks("AnyUp")
        blocker:SetScript("OnClick", hideMenu)
        menu = CreateFrame("Frame", "QuestboardMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        Theme.Panel(menu, Theme.colors.window, Theme.colors.windowBorder)
        menu.rows = {}
        menu:Hide()
        blocker:Hide()
    end
    local width = 150
    for i, item in ipairs(items) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(18)
            row.text = W.Text(row, "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 8, 0)
            row:SetHighlightTexture(Theme.WHITE)
            row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -4 - (i - 1) * 18)
        row:SetPoint("RIGHT", -2, 0)
        local label = item.text or ""
        if item.checked ~= nil then label = (item.checked and "|cff5cd673[x]|r " or "[  ] ") .. label end
        if item.title then label = "|cffffd100" .. label .. "|r" end
        if item.disabled then label = "|cff777777" .. ns.Util.StripLinks(label) .. "|r" end
        row.text:SetText(label)
        width = math.max(width, (row.text:GetStringWidth() or 100) + 24)
        row:SetEnabled(not item.disabled and not item.title)
        row:SetScript("OnClick", function()
            hideMenu()
            if item.func then ns.Safe("menu " .. tostring(item.text), item.func) end
        end)
        row:Show()
    end
    for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(width, #items * 18 + 8)
    menu:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    blocker:Show()
    menu:Show()
end

-- Yes/No confirmation using a StaticPopup.
StaticPopupDialogs["QUESTBOARD_CONFIRM"] = {
    text = "%s", button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, data) if data and data.func then ns.Safe("confirm", data.func) end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function W.Confirm(text, func)
    StaticPopup_Show("QUESTBOARD_CONFIRM", text, nil, { func = func })
end
