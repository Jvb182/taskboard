-- Small reusable widgets with a consistent flat look.
local _, ns = ...
local Theme = ns.Theme

local W = {}
ns.Widgets = W

function W.Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    Theme.Text(fs, font)
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

-- Our windows are ordinary addon frames, not managed Blizzard UIPanels.
-- Keep the standard artwork, but do not route closing through HideUIPanel.
function W.CloseButton(parent)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    button:SetPoint("TOPRIGHT", 2, 2)
    button:SetScript("OnClick", ns.Wrap("close window", function() parent:Hide() end))
    parent.closeButton = button
    return button
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
        ns.Log:Warn("ui", "No link insertion hook available; shift-click into Taskboard won't work")
    end
end

function W.EditBox(parent, width, height, placeholder, acceptLinks)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width or 160, height or 22)
    Theme.Panel(e, Theme.colors.input, Theme.colors.inputBorder)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    Theme.Text(e, "ChatFontNormal")
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
        Theme.Text(c.Text, "GameFontHighlightSmall")
    end
    c:SetScript("OnClick", ns.Wrap("check " .. tostring(label), function(self)
        if onToggle then onToggle(self:GetChecked() and true or false, self) end
    end))
    W.Tooltip(c, tooltip)
    return c
end

function W.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetClipsChildren(true)
    -- The template places its scrollbar outside the viewport, but parents it to
    -- the viewport. Keep it outside the clipped subtree and preserve its link
    -- to this scroll frame rather than the template's GetParent() assumption.
    local bar = scroll.ScrollBar
    if bar then
        bar:SetParent(parent)
        bar:SetFrameLevel(scroll:GetFrameLevel() + 2)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -16)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 16)
        bar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
        scroll:HookScript("OnHide", function() bar:Hide() end)
        scroll:HookScript("OnShow", function() bar:Show() end)
    end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    -- The Forever template supplies a scrollbar, but does not reliably consume
    -- wheel input over the child. Capture it on both surfaces, including at the
    -- ends of the document, so it cannot zoom the game camera underneath.
    local function refreshButtons()
        local limit = math.max(0, scroll:GetVerticalScrollRange())
        local value = scroll:GetVerticalScroll()
        if bar and bar.ScrollUpButton then bar.ScrollUpButton:SetEnabled(value > 0) end
        if bar and bar.ScrollDownButton then bar.ScrollDownButton:SetEnabled(value < limit) end
    end
    local function wheel(_, delta)
        local limit = math.max(0, scroll:GetVerticalScrollRange())
        local value = ns.Util.Clamp(scroll:GetVerticalScroll() - delta * 40, 0, limit)
        scroll:SetVerticalScroll(value)
        if scroll.ScrollBar then
            scroll.ScrollBar:SetMinMaxValues(0, limit)
            scroll.ScrollBar:SetValue(value)
        end
        refreshButtons()
    end
    scroll:EnableMouse(true)
    content:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    content:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", ns.Wrap("scroll pane", wheel))
    content:SetScript("OnMouseWheel", ns.Wrap("scroll content", wheel))
    -- A mouse-enabled host (for example a draggable Help dialog) can be the
    -- wheel target on this client. It belongs to this pane, not the game world.
    parent:EnableMouseWheel(true)
    parent:HookScript("OnMouseWheel", ns.Wrap("scroll host", wheel))
    if bar then
        bar:EnableMouse(true)
        for _, entry in ipairs({ { bar.ScrollUpButton, 1 }, { bar.ScrollDownButton, -1 } }) do
            local button, direction = entry[1], entry[2]
            if button then
                button:EnableMouse(true)
                button:SetFrameLevel(bar:GetFrameLevel() + 1)
                button:SetScript("OnClick", ns.Wrap("scroll arrow", function() wheel(nil, direction) end))
            end
        end
    end
    scroll:HookScript("OnScrollRangeChanged", refreshButtons)
    scroll:HookScript("OnVerticalScroll", refreshButtons)
    scroll:HookScript("OnShow", refreshButtons)
    return scroll, content
end

-- Localized zone and subzone names from the client's AreaTable, built in small
-- batches on first use. No dependency on another addon or external name list.
local places, placeKeys, scanning = {}, {}, false
local function rememberPlace(name)
    if type(name) ~= "string" or name == "" then return end
    local key = ns.Util.Lower(name)
    if not placeKeys[key] then placeKeys[key] = true; places[#places + 1] = name end
end
function W.LocationToken(text, cursor)
    local before = text:sub(1, cursor)
    local start, query = before:match('()@"([^"]*)$')
    local quoted = start ~= nil
    if not start then start, query = before:match('()@([^%s@";]*)$') end
    if not start or query == "" then return end
    if start > 1 and not text:sub(start - 1, start - 1):match('[%s;]') then return end
    local tail = text:sub(cursor + 1)
    local rest
    if quoted then rest = tail:find('"', 1, true) else rest = tail:find('[%s;]') end
    local finish = rest and (cursor + rest - (quoted and 0 or 1)) or #text
    return start, finish, query
end

function W.LocationSuggestions(box)
    local panel = CreateFrame("Frame", nil, box, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    panel:SetSize(300, 200)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    Theme.Panel(panel, Theme.colors.window, Theme.colors.windowBorder, true)
    panel:Hide()
    local rows, matches, selected, offset = {}, {}, 1, 0
    local start, finish, changing
    local refresh
    local hint = W.Text(panel, "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 8, 6)
    local function draw()
        for i = 1, 8 do
            local name = matches[offset + i]
            rows[i]:SetShown(name ~= nil)
            rows[i]:SetLabel(name or "")
            rows[i]:SetActive(offset + i == selected)
        end
        hint:SetText(#matches == 0 and (scanning and "Loading locations..." or "No matches; you can type a location.")
            or "Up/Down, Tab or Enter to choose; scroll for more")
        panel:SetHeight(math.min(8, #matches) * 22 + 30)
    end
    local function choose(index)
        local name = matches[index]
        if not name or not start then return end
        local text = box:GetText()
        local token = '@"' .. name .. '"'
        local prefix = text:sub(1, start - 1) .. token
        local suffix = text:sub(finish + 1)
        if suffix == "" then prefix = prefix .. " " end
        changing = true
        box:SetText(prefix .. suffix)
        box:SetCursorPosition(#prefix)
        changing = false
        panel:Hide()
        box:SetFocus()
    end
    for i = 1, 8 do
        local index = i
        rows[i] = W.Button(panel, "", 284, 22, function() choose(offset + index) end)
        rows[i]:SetPoint("TOPLEFT", 8, -4 - (i - 1) * 22)
    end
    refresh = function()
        if changing then return end
        if not box:HasFocus() or not box:IsVisible() then panel:Hide(); return end
        local query
        start, finish, query = W.LocationToken(box:GetText(), box:GetCursorPosition())
        if not query then panel:Hide(); return end
        rememberPlace(GetRealZoneText and GetRealZoneText())
        rememberPlace(GetSubZoneText and GetSubZoneText())
        if not W.locationsIndexed and not scanning then
            scanning = true
            local id = 1
            local function batch()
                if C_Map and C_Map.GetAreaInfo then
                    for n = id, math.min(id + 299, 30000) do rememberPlace(C_Map.GetAreaInfo(n)) end
                end
                id = id + 300
                if id <= 30000 and C_Map and C_Map.GetAreaInfo then ns.After(0.01, "location index", batch)
                else scanning = false; W.locationsIndexed = true end
                refresh()
            end
            ns.After(0, "location index", batch)
        end
        matches = {}
        query = ns.Util.Lower(query)
        for _, name in ipairs(places) do
            if ns.Util.Lower(name):sub(1, #query) == query then matches[#matches + 1] = name end
        end
        table.sort(matches)
        selected, offset = 1, 0
        draw(); panel:Show()
    end
    box:HookScript("OnTextChanged", refresh)
    box:HookScript("OnCursorChanged", refresh)
    box:HookScript("OnEditFocusGained", refresh)
    box:HookScript("OnHide", function() panel:Hide() end)
    -- Delay focus-loss hiding so a click on a suggestion can complete first.
    box:HookScript("OnEditFocusLost", function() ns.After(0.1, "hide locations", function()
        if not box:HasFocus() then panel:Hide() end
    end) end)
    local enter, escape = box:GetScript("OnEnterPressed"), box:GetScript("OnEscapePressed")
    box:SetScript("OnEnterPressed", ns.Wrap("choose location", function(self)
        if panel:IsShown() and matches[selected] then choose(selected) elseif enter then panel:Hide(); enter(self) end
    end))
    box:SetScript("OnTabPressed", ns.Wrap("choose location", function() if panel:IsShown() then choose(selected) end end))
    box:SetScript("OnEscapePressed", function(self)
        if panel:IsShown() then panel:Hide() elseif escape then escape(self) end
    end)
    box:SetScript("OnArrowPressed", ns.Wrap("location navigation", function(_, key)
        if not panel:IsShown() or #matches == 0 then return end
        if key == "UP" then selected = math.max(1, selected - 1)
        elseif key == "DOWN" then selected = math.min(#matches, selected + 1) else return end
        offset = math.max(0, math.min(offset, selected - 1))
        if selected > offset + 8 then offset = selected - 8 end
        draw()
    end))
    panel:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(math.max(0, #matches - 8), offset - delta))
        draw()
    end)
    return panel
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
        menu = CreateFrame("Frame", "TaskboardMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        Theme.Panel(menu, Theme.colors.window, Theme.colors.windowBorder, true)
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
StaticPopupDialogs["TASKBOARD_CONFIRM"] = {
    text = "%s", button1 = YES or "Yes", button2 = NO or "No",
    OnShow = function(self)
        self.taskboardPreviousStrata = self.taskboardPreviousStrata or self:GetFrameStrata()
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:Raise()
    end,
    OnHide = function(self)
        if self.taskboardPreviousStrata then
            self:SetFrameStrata(self.taskboardPreviousStrata)
            self.taskboardPreviousStrata = nil
        end
    end,
    OnAccept = function(_, data) if data and data.func then ns.Safe("confirm", data.func) end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function W.Confirm(text, func)
    StaticPopup_Show("TASKBOARD_CONFIRM", text, nil, { func = func })
end

