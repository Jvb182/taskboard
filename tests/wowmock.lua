-- A mock WoW: Forever client for offline tests.
--
-- * Widgets only expose methods that exist in the real client's widget API
--   (from tests/fixtures/forever_api.lua). Calling anything else errors.
-- * C_* namespaces, globals, events, templates and fonts are checked against
--   the same fixture. Reads of unknown globals and missing APIs are recorded.
-- * Game state (bags, bank, money, level, skills, reputations, quests, zone,
--   map position, group) is simulated and can be changed by tests.
local API = dofile((QB_TEST_ROOT or "tests/") .. "fixtures/forever_api.lua")

local Mock = {}
Mock.API = API

-------------------------------------------------------------------------------
-- Widget method sets from the fixture
-------------------------------------------------------------------------------
local function union(...)
    local out = {}
    for _, name in ipairs({ ... }) do
        local set = API.widgets[name]
        assert(set, "fixture has no widget API " .. name)
        for k in pairs(set) do out[k] = true end
    end
    return out
end

local COMMON = { "SimpleObjectAPI", "SimpleFrameScriptObjectAPI", "SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI", "SimpleAnimatableObjectAPI" }
local function with(base, ...)
    local list = {}
    for _, v in ipairs(base) do list[#list + 1] = v end
    for _, v in ipairs({ ... }) do list[#list + 1] = v end
    return list
end
local FRAME = with(COMMON, "SimpleFrameAPI")
Mock.METHODS = {
    Frame = union(unpack(FRAME)),
    Button = union(unpack(with(FRAME, "SimpleButtonAPI"))),
    CheckButton = union(unpack(with(FRAME, "SimpleButtonAPI", "SimpleCheckboxAPI"))),
    EditBox = union(unpack(with(FRAME, "SimpleEditBoxAPI"))),
    ScrollFrame = union(unpack(with(FRAME, "SimpleScrollFrameAPI"))),
    StatusBar = union(unpack(with(FRAME, "SimpleStatusBarAPI"))),
    Slider = union(unpack(with(FRAME, "SimpleSliderAPI"))),
    Texture = union(unpack(with(COMMON, "SimpleRegionAPI", "SimpleTextureBaseAPI", "SimpleTextureAPI"))),
    FontString = union(unpack(with(COMMON, "SimpleRegionAPI", "SimpleFontStringAPI"))),
}
Mock.METHODS.GameTooltip = Mock.METHODS.Frame

-- Globals that exist in the client but are not in the generated docs.
Mock.UNDOCUMENTED = {
    CreateFrame = true, IsInGroup = true, IsInRaid = true, GetNumGroupMembers = true, hooksecurefunc = true, debugstack = true,
    NUM_BAG_SLOTS = true, NUM_TOTAL_EQUIPPED_BAG_SLOTS = true, UISpecialFrames = true, StaticPopupDialogs = true,
    Minimap = true, UIParent = true, GameTooltip = true, DEFAULT_CHAT_FRAME = true, UIErrorsFrame = true,
    SlashCmdList = true, SOUNDKIT = true, YES = true, NO = true, ACCEPT = true, DECLINE = true,
    BackdropTemplateMixin = true, Mixin = true, ChatFrameUtil = true, UiMapPoint = true, Settings = true,
}

-------------------------------------------------------------------------------
-- Environment
-------------------------------------------------------------------------------
function Mock.new(opts)
    opts = opts or {}
    local m = {
        now = opts.now or 1762500000, clock = 0, timers = {}, frames = {}, eventFrames = {}, focus = nil,
        chat = {}, errorsFrame = {}, popups = {}, sounds = {}, sent = {}, prefixes = {}, waypoints = {},
        unknownGlobals = {}, missingAPI = {}, unmocked = {}, globalWrites = {}, mouseOver = {},
        cursor = { 500, 500 }, links = {},
    }
    m.state = {
        name = opts.name or "Testchar", realm = opts.realm or "Forever",
        money = 0, level = 20, xp = 0, xpMax = 1000, zone = "Elwynn Forest", subzone = "Goldshire",
        bags = {}, bank = {}, skills = {}, factions = {}, questLog = {}, completedQuests = {}, objectives = {},
        mapID = 1429, pos = { 0.42, 0.65 }, inGroup = false, inRaid = false, inGuild = false, inCombat = false,
        dailyReset = 1762500000 + 3600 * 10, weeklyReset = 1762500000 + 86400 * 3,
    }
    m.items = {
        [2447] = { name = "Peacebloom", cached = true }, [765] = { name = "Silverleaf", cached = true },
        [2589] = { name = "Linen Cloth", cached = true }, [2770] = { name = "Copper Ore", cached = false },
        [785] = { name = "Mageroyal", cached = false }, [3820] = { name = "Stranglekelp", cached = false },
        [9999] = { name = "Mystery Widget", cached = false },
    }

    local env = {}
    m.env = env
    for _, k in ipairs({ "string", "table", "math", "pairs", "ipairs", "type", "tostring", "tonumber", "select",
                         "unpack", "next", "pcall", "xpcall", "error", "assert", "setmetatable", "getmetatable",
                         "rawget", "rawset", "rawequal", "print", "coroutine" }) do
        env[k] = _G[k]
    end
    env._G = env
    env.time = function(t) if t then return os.time(t) end return m.now end
    env.date = function(fmt, t) return os.date(fmt, t or m.now) end
    env.GetTime = function() return m.clock end
    env.GetServerTime = function() return m.now end
    env.debugprofilestop = function() return m.clock * 1000 end
    env.debugstack = function() return "mock stack" end
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.strsplit = function(sep, s) local out = {} for part in string.gmatch(s, "[^" .. sep .. "]+") do out[#out + 1] = part end return unpack(out) end
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.format, env.tinsert, env.tremove = string.format, table.insert, table.remove
    env.YES, env.NO, env.ACCEPT, env.DECLINE = "Yes", "No", "Accept", "Decline"
    env.NUM_BAG_SLOTS, env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, 4

    ---------------------------------------------------------------------------
    -- Timers
    ---------------------------------------------------------------------------
    local timerSeq = 0
    local function addTimer(delay, fn, interval)
        timerSeq = timerSeq + 1
        local t = { at = m.clock + math.max(delay, 0), fn = fn, interval = interval, seq = timerSeq }
        m.timers[#m.timers + 1] = t
        return t
    end
    env.C_Timer = {
        After = function(delay, fn) addTimer(delay, fn) end,
        NewTicker = function(interval, fn)
            local t = addTimer(interval, fn, interval)
            return { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled end }
        end,
        NewTimer = function(delay, fn)
            local t = addTimer(delay, fn)
            return { Cancel = function() t.cancelled = true end }
        end,
    }
    function m.Advance(seconds)
        local target = m.clock + (seconds or 0)
        for _ = 1, 100000 do
            local nextT, idx
            for i, t in ipairs(m.timers) do
                if not t.cancelled and t.at <= target and (not nextT or t.at < nextT.at or (t.at == nextT.at and t.seq < nextT.seq)) then nextT, idx = t, i end
            end
            if not nextT then break end
            m.clock = math.max(m.clock, nextT.at)
            if nextT.interval then nextT.at = nextT.at + nextT.interval else table.remove(m.timers, idx) end
            nextT.fn()
        end
        m.clock = target
        for i = #m.timers, 1, -1 do if m.timers[i].cancelled then table.remove(m.timers, i) end end
    end
    function m.AdvanceTime(seconds)
        m.now = m.now + seconds
        m.Advance(seconds)
    end

    ---------------------------------------------------------------------------
    -- Widgets
    ---------------------------------------------------------------------------
    local Widget = {}

    local function checkFont(font)
        if type(font) == "string" then
            if not API.templates[font] then error("unknown font object " .. font, 3) end
        elseif type(font) ~= "table" then
            error("bad font object", 3)
        end
    end

    local impl = {}
    impl.SetPoint = function(self, point, rel, relPoint, x, y)
        if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
        self._points[#self._points + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
    end
    impl.ClearAllPoints = function(self) self._points = {} end
    impl.GetPoint = function(self, i)
        local p = self._points[i or 1]
        if p then return p[1], p[2] or self._parent, p[3], p[4], p[5] end
    end
    impl.GetNumPoints = function(self) return #self._points end
    impl.SetAllPoints = function(self, rel) self._points = { { "ALL", rel } } end
    impl.SetSize = function(self, w, h) self._w, self._h = w, h end
    impl.SetWidth = function(self, w) self._w = w end
    impl.SetHeight = function(self, h) self._h = h end
    impl.GetWidth = function(self)
        if self._w and self._w > 0 then return self._w end
        return self._parent and self._parent:GetWidth() or 800
    end
    impl.GetHeight = function(self) return self._h or 20 end
    impl.GetSize = function(self) return self:GetWidth(), self:GetHeight() end
    impl.Show = function(self)
        local was = self:IsVisible()
        self._shown = true
        if not was and self:IsVisible() and self._scripts.OnShow then self._scripts.OnShow(self) end
    end
    impl.Hide = function(self)
        local was = self:IsVisible()
        self._shown = false
        if was and self._scripts.OnHide then self._scripts.OnHide(self) end
        if m.focus and was then
            local f = m.focus
            while f do
                if f == self then m.focus = nil break end
                f = f._parent
            end
        end
    end
    impl.SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end
    impl.IsShown = function(self) return self._shown end
    impl.IsVisible = function(self)
        local f = self
        while f do
            if not f._shown then return false end
            f = f._parent
        end
        return true
    end
    impl.SetParent = function(self, parent) self._parent = parent end
    impl.GetParent = function(self) return self._parent end
    impl.SetFrameLevel = function(self, level) self._level = level end
    impl.GetFrameLevel = function(self)
        if self._level then return self._level end
        return self._parent and (self._parent:GetFrameLevel() + 1) or 0
    end
    impl.GetName = function(self) return self._name end
    impl.GetObjectType = function(self) return self._type end
    impl.SetScript = function(self, name, fn) self._scripts[name] = fn end
    impl.GetScript = function(self, name) return self._scripts[name] end
    impl.HookScript = function(self, name, fn)
        local old = self._scripts[name]
        self._scripts[name] = function(...) if old then old(...) end return fn(...) end
    end
    impl.SetAlpha = function(self, a) self._alpha = a end
    impl.GetAlpha = function(self) return self._alpha or 1 end
    impl.CreateTexture = function(self, name) return Widget.new("Texture", name, self) end
    impl.CreateFontString = function(self, name, layer, font)
        local fs = Widget.new("FontString", name, self)
        if font then checkFont(font) end
        return fs
    end
    impl.SetText = function(self, text)
        local old = self._text
        self._text = text ~= nil and tostring(text) or ""
        if self._type == "EditBox" then self._cursor = #self._text end
        if self._type == "EditBox" and self._scripts.OnTextChanged and old ~= self._text then self._scripts.OnTextChanged(self, false) end
        if self.Text and self._type ~= "EditBox" and self._type ~= "FontString" then self.Text:SetText(text) end
    end
    impl.SetFormattedText = function(self, fmt, ...) self:SetText(string.format(fmt, ...)) end
    impl.GetText = function(self) return self._text or "" end
    impl.GetCursorPosition = function(self) return self._cursor or #(self._text or "") end
    impl.SetCursorPosition = function(self, value)
        self._cursor = math.max(0, math.min(#(self._text or ""), value))
        if self._scripts.OnCursorChanged then self._scripts.OnCursorChanged(self) end
    end
    impl.GetStringWidth = function(self) return #(self._text or "") * 6 end
    impl.GetStringHeight = function() return 12 end
    impl.SetFontObject = function(self, font) checkFont(font) self._font = font end
    impl.SetNormalFontObject = function(self, font) checkFont(font) end
    impl.SetHighlightFontObject = function(self, font) checkFont(font) end
    impl.SetChecked = function(self, v) self._checked = v and true or false end
    impl.GetChecked = function(self) return self._checked or false end
    impl.SetValue = function(self, v)
        local value = math.max(self._min or 0, math.min(self._max or 1, v))
        local changed = value ~= self._value
        self._value = value
        if changed and self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, value) end
    end
    impl.GetValue = function(self) return self._value or 0 end
    impl.SetMinMaxValues = function(self, lo, hi) self._min, self._max = lo, hi end
    impl.GetMinMaxValues = function(self) return self._min or 0, self._max or 1 end
    impl.SetEnabled = function(self, v) self._enabled = v and true or false end
    impl.Enable = function(self) self._enabled = true end
    impl.Disable = function(self) self._enabled = false end
    impl.IsEnabled = function(self) return self._enabled ~= false end
    impl.EnableMouse = function(self, v) self._mouse = v ~= false end
    impl.IsMouseEnabled = function(self) return self._mouse end
    impl.IsMouseOver = function(self) return m.mouseOver[self] == true end
    impl.GetEffectiveScale = function() return 1 end
    impl.GetScale = function() return 1 end
    impl.GetLeft = function(self) return self._left or 100 end
    impl.GetTop = function(self) return self._top or 600 end
    impl.GetBottom = function(self) return (self._top or 600) - self:GetHeight() end
    impl.GetRight = function(self) return (self._left or 100) + self:GetWidth() end
    impl.GetCenter = function(self) return (self._left or 100) + self:GetWidth() / 2, (self._top or 600) - self:GetHeight() / 2 end
    impl.SetFocus = function(self)
        if m.focus and m.focus ~= self and m.focus._scripts.OnEditFocusLost then
            local old = m.focus
            m.focus = nil
            old._scripts.OnEditFocusLost(old)
        end
        m.focus = self
        if self._scripts.OnEditFocusGained then self._scripts.OnEditFocusGained(self) end
    end
    impl.ClearFocus = function(self)
        if m.focus == self then
            m.focus = nil
            if self._scripts.OnEditFocusLost then self._scripts.OnEditFocusLost(self) end
        end
    end
    impl.HasFocus = function(self) return m.focus == self end
    impl.Insert = function(self, text) self:SetText((self._text or "") .. text) end
    impl.SetScrollChild = function(self, child) self._scrollChild = child end
    impl.GetScrollChild = function(self) return self._scrollChild end
    impl.GetVerticalScrollRange = function() return 0 end
    impl.GetVerticalScroll = function(self) return self._scroll or 0 end
    impl.SetVerticalScroll = function(self, v) self._scroll = v end
    impl.RegisterEvent = function(self, event)
        if not API.events[event] then error("Attempt to register unknown event \"" .. tostring(event) .. "\"", 2) end
        m.eventFrames[event] = m.eventFrames[event] or {}
        table.insert(m.eventFrames[event], self)
    end
    impl.UnregisterEvent = function(self, event)
        local list = m.eventFrames[event] or {}
        for i = #list, 1, -1 do if list[i] == self then table.remove(list, i) end end
    end
    impl.SetHighlightTexture = function(self, tex)
        self._highlight = type(tex) == "table" and tex or Widget.new("Texture", nil, self)
    end
    impl.GetHighlightTexture = function(self)
        self._highlight = self._highlight or Widget.new("Texture", nil, self)
        return self._highlight
    end
    impl.SetNormalTexture = function(self) end
    impl.SetPushedTexture = function(self) end
    impl.SetThumbTexture = function(self, tex)
        self._thumb = type(tex) == "table" and tex or Widget.new("Texture", nil, self)
    end
    impl.GetThumbTexture = function(self) return self._thumb end
    impl.SetHorizontalScroll = function(self, value) self._horizontalScroll = value end
    impl.GetHorizontalScroll = function(self) return self._horizontalScroll or 0 end
    impl.SetTexture = function(self, tex) self._texture = tex end
    impl.GetTexture = function(self) return self._texture end
    impl.SetColorTexture = function(self, r, g, b, a) self._color = { r, g, b, a } end
    impl.SetVertexColor = function(self, r, g, b, a) self._vertex = { r, g, b, a } end
    impl.SetTextColor = function(self, r, g, b, a) self._textColor = { r, g, b, a } end
    impl.Click = function(self, button)
        if self._enabled ~= false and self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton", false) end
    end
    impl.StartMoving = function() end
    impl.StopMovingOrSizing = function() end
    impl.StartSizing = function() end
    impl.CreateAnimationGroup = function() error("animations are not mocked") end

    Widget.new = function(kind, name, parent, template)
        local methods = Mock.METHODS[kind]
        assert(methods, "mock does not support widget type " .. tostring(kind))
        local w = { _type = kind, _name = name, _parent = parent, _points = {}, _scripts = {}, _shown = kind ~= "Frame" or true }
        w._shown = true
        setmetatable(w, { __index = function(t, k)
            if impl[k] and methods[k] then return impl[k] end
            if methods[k] then
                return function() end -- real method, behavior not needed by tests
            end
            return nil
        end })
        m.frames[#m.frames + 1] = w
        if name then rawset(env, name, w) end
        return w
    end

    local function applyTemplate(w, template)
        for t in string.gmatch(template, "[^,%s]+") do
            if not API.templates[t] then error("unknown template " .. t, 3) end
            if t == "BackdropTemplate" then
                for k, fn in pairs(env.BackdropTemplateMixin) do w[k] = fn end
            elseif t == "UIPanelButtonTemplate" then
                w.Text = Widget.new("FontString", nil, w)
            elseif t == "UICheckButtonTemplate" then
                w.Text = Widget.new("FontString", nil, w)
                w.text = w.Text
            elseif t == "UIPanelScrollFrameTemplate" then
                w.ScrollBar = Widget.new("Slider", nil, w)
            elseif t == "InputBoxTemplate" then
                w.Left = Widget.new("Texture", nil, w)
            end
        end
    end

    env.BackdropTemplateMixin = {
        SetBackdrop = function(self, b) self._backdrop = b end,
        GetBackdrop = function(self) return self._backdrop end,
        SetBackdropColor = function(self, r, g, b, a) self._bg = { r, g, b, a } end,
        SetBackdropBorderColor = function(self, r, g, b, a) self._border = { r, g, b, a } end,
        ApplyBackdrop = function() end,
    }
    env.Mixin = function(target, ...)
        for _, mixin in ipairs({ ... }) do for k, v in pairs(mixin) do target[k] = v end end
        return target
    end

    env.CreateFrame = function(kind, name, parent, template)
        if not Mock.METHODS[kind] then error("CreateFrame: unknown frame type " .. tostring(kind), 2) end
        local w = Widget.new(kind, name, parent)
        if template then applyTemplate(w, template) end
        if kind == "EditBox" then w._text = "" end
        return w
    end
    m.Widget = Widget

    env.UIParent = env.CreateFrame("Frame", "UIParent")
    env.UIParent._w, env.UIParent._h = 1920, 1080
    env.Minimap = env.CreateFrame("Frame", "Minimap", env.UIParent)
    env.Minimap._w, env.Minimap._h = 140, 140
    env.UISpecialFrames = {}
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(which, a1, a2, data)
        local dialog = env.StaticPopupDialogs[which]
        assert(dialog, "StaticPopup_Show: unknown dialog " .. tostring(which))
        local popup = { which = which, text = string.format(dialog.text, a1 or "", a2 or ""), data = data, dialog = dialog }
        m.popups[#m.popups + 1] = popup
        return popup
    end
    function m.AcceptPopup(i)
        local p = table.remove(m.popups, i or #m.popups)
        if p and p.dialog.OnAccept then p.dialog.OnAccept({}, p.data) end
        return p
    end
    function m.CancelPopup(i)
        local p = table.remove(m.popups, i or #m.popups)
        if p and p.dialog.OnCancel then p.dialog.OnCancel({}, p.data) end
        return p
    end

    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) m.chat[#m.chat + 1] = text end }
    env.UIErrorsFrame = { AddMessage = function(_, text) m.errorsFrame[#m.errorsFrame + 1] = text end }
    env.GameTooltip = env.CreateFrame("Frame", "GameTooltip", env.UIParent)
    env.GameTooltip._type = "GameTooltip"
    local tooltipLines = {}
    m.tooltip = tooltipLines
    rawset(env.GameTooltip, "SetOwner", function() for i = #tooltipLines, 1, -1 do tooltipLines[i] = nil end end)
    rawset(env.GameTooltip, "SetText", function(_, text) tooltipLines[#tooltipLines + 1] = text end)
    rawset(env.GameTooltip, "AddLine", function(_, text) tooltipLines[#tooltipLines + 1] = text end)

    env.SlashCmdList = {}
    function m.Slash(line)
        local cmd, rest = string.match(line, "^(/%S+)%s*(.-)$")
        for key, fn in pairs(env.SlashCmdList) do
            for i = 1, 9 do
                local alias = rawget(env, "SLASH_" .. key .. i)
                if alias and string.lower(alias) == string.lower(cmd) then return fn(rest) end
            end
        end
        error("no slash command " .. tostring(cmd))
    end

    env.SOUNDKIT = {}
    local soundID = 1
    for name in pairs(API.soundkit) do env.SOUNDKIT[name] = soundID soundID = soundID + 1 end
    env.PlaySound = function(id) m.sounds[#m.sounds + 1] = id return true end

    env.hooksecurefunc = function(a, b, c)
        local tbl, name, fn = a, b, c
        if type(a) == "string" then tbl, name, fn = env, a, b end
        local old = tbl[name]
        assert(type(old) == "function", "hooksecurefunc: no function " .. tostring(name))
        tbl[name] = function(...)
            local r = { old(...) }
            fn(...)
            return unpack(r)
        end
    end
    env.ChatFrameUtil = { InsertLink = function() return false end, GetActiveWindow = function() return nil end }
    function m.ShiftClickLink(link) return env.ChatFrameUtil.InsertLink(link) end

    env.GetCursorPosition = function() return m.cursor[1], m.cursor[2] end
    env.IsShiftKeyDown = function() return false end
    env.InCombatLockdown = function() return m.state.inCombat end
    env.GetBuildInfo = function() return "1.60.1", "70862", "Nov 7 2026", 16001 end
    env.C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "1.0.0-test" or nil end }
    env.UnitName = function(unit) if unit == "player" then return m.state.name end end
    env.GetRealmName = function() return m.state.realm end
    env.GetNormalizedRealmName = function() return m.state.realm end
    env.UnitLevel = function() return m.state.level end
    env.UnitXP = function() return m.state.xp end
    env.UnitXPMax = function() return m.state.xpMax end
    env.GetMoney = function() return m.state.money end
    env.GetRealZoneText = function() return m.state.zone end
    env.GetZoneText = function() return m.state.zone end
    env.GetSubZoneText = function() return m.state.subzone end
    env.IsInGroup = function() return m.state.inGroup end
    env.IsInRaid = function() return m.state.inRaid end
    env.IsInGuild = function() return m.state.inGuild end

    ---------------------------------------------------------------------------
    -- Items, bags, bank
    ---------------------------------------------------------------------------
    local function link(id)
        local item = m.items[id]
        return string.format("|cffffffff|Hitem:%d::::::::20:::::|h[%s]|h|r", id, item and item.name or "?")
    end
    m.ItemLink = link
    function m.BagCount(id)
        local n = 0
        for _, bag in pairs(m.state.bags) do for _, slot in pairs(bag) do if slot.itemID == id then n = n + slot.count end end end
        return n
    end
    env.C_Item = {
        GetItemCount = function(id, includeBank)
            if type(id) ~= "number" then error("mock GetItemCount expects an itemID") end
            return m.BagCount(id) + (includeBank and (m.state.bank[id] or 0) or 0)
        end,
        GetItemInfoInstant = function(what)
            if type(what) == "number" then return m.items[what] and what or nil end
            for id, item in pairs(m.items) do
                if item.cached and string.lower(item.name) == string.lower(what) then return id end
            end
        end,
        GetItemNameByID = function(id) local item = m.items[id] return item and item.cached and item.name or nil end,
        GetItemIconByID = function(id) return m.items[id] and 134000 + id or nil end,
        RequestLoadItemDataByID = function(id)
            env.C_Timer.After(0.5, function()
                local item = m.items[id]
                if item then item.cached = true end
                m.Fire("ITEM_DATA_LOAD_RESULT", id, item ~= nil)
            end)
        end,
        GetItemInfo = function(id) local item = m.items[id] return item and item.cached and item.name or nil end,
    }
    env.C_Container = {
        GetContainerNumSlots = function(bag) return (bag >= 0 and bag <= 4) and 16 or 0 end,
        GetContainerItemInfo = function(bag, slot)
            local s = m.state.bags[bag] and m.state.bags[bag][slot]
            if not s then return nil end
            return { itemID = s.itemID, stackCount = s.count, hyperlink = link(s.itemID), iconFileID = 134000 + s.itemID }
        end,
    }
    -- Adds items to the first free slot and fires the bag event (like looting).
    function m.Loot(id, count, silent)
        for bag = 0, 4 do
            m.state.bags[bag] = m.state.bags[bag] or {}
            for slot = 1, 16 do
                local s = m.state.bags[bag][slot]
                if s and s.itemID == id then
                    s.count = s.count + count
                    if not silent then m.Fire("BAG_UPDATE_DELAYED") end
                    return
                end
            end
        end
        for bag = 0, 4 do
            for slot = 1, 16 do
                if not m.state.bags[bag][slot] then
                    m.state.bags[bag][slot] = { itemID = id, count = count }
                    if not silent then m.Fire("BAG_UPDATE_DELAYED") end
                    return
                end
            end
        end
    end
    function m.RemoveItem(id, count)
        for bag = 0, 4 do
            for slot, s in pairs(m.state.bags[bag] or {}) do
                if s.itemID == id then
                    s.count = s.count - count
                    if s.count <= 0 then m.state.bags[bag][slot] = nil end
                    m.Fire("BAG_UPDATE_DELAYED")
                    return
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Skills, reputation, quests, map, chat, time
    ---------------------------------------------------------------------------
    env.C_SkillInfo = {
        GetNumSkillLines = function() return #m.state.skills end,
        GetSkillLineInfo = function(i)
            local s = m.state.skills[i]
            if not s then return nil end
            return { skillID = i, name = s.name, isHeader = s.isHeader or false, isCollapsed = false, rank = s.rank or 0,
                     tempPoints = 0, modifier = 0, maxRank = s.maxRank or 300, isAbandonable = true, stepCost = 0,
                     rankCost = 0, minLevel = 0, costType = 0, parentSkillLineID = 0, skillLineCategoryID = 0, description = "" }
        end,
    }
    local THRESHOLDS = { -42000, -6000, -3000, 0, 3000, 9000, 21000, 42000, 42999 }
    local function factionData(f)
        local reaction = 1
        for i = 1, 8 do if f.standing >= THRESHOLDS[i] then reaction = i end end
        return { factionID = f.id, name = f.name, description = "", reaction = reaction,
                 currentReactionThreshold = THRESHOLDS[reaction], nextReactionThreshold = THRESHOLDS[reaction + 1],
                 currentStanding = f.standing, atWarWith = false, canToggleAtWar = false, isChild = false,
                 isHeader = f.isHeader or false, isHeaderWithRep = false, isCollapsed = false, isWatched = false,
                 hasBonusRepGain = false, canSetInactive = false, isAccountWide = false }
    end
    env.C_Reputation = {
        GetNumFactions = function() return #m.state.factions end,
        GetFactionDataByIndex = function(i) local f = m.state.factions[i] return f and factionData(f) end,
        GetFactionDataByID = function(id)
            for _, f in ipairs(m.state.factions) do if f.id == id then return factionData(f) end end
        end,
    }
    env.C_QuestLog = {
        GetNumQuestLogEntries = function() return #m.state.questLog, #m.state.questLog end,
        GetInfo = function(i)
            local q = m.state.questLog[i]
            return q and { title = q.title, questLogIndex = i, questID = q.id, level = 10, isHeader = false } or nil
        end,
        GetLogIndexForQuestID = function(id)
            for i, q in ipairs(m.state.questLog) do if q.id == id then return i end end
        end,
        IsComplete = function(id)
            for _, q in ipairs(m.state.questLog) do if q.id == id then return q.complete == true end end
            return false
        end,
        IsQuestFlaggedCompleted = function(id) return m.state.completedQuests[id] == true end,
        GetQuestObjectives = function(id) return m.state.objectives[id] or {} end,
        GetTitleForQuestID = function(id)
            for _, q in ipairs(m.state.questLog) do if q.id == id then return q.title end end
        end,
    }
    env.C_Map = {
        GetAreaInfo = function(id) return (m.state.areas or {})[id] end,
        GetBestMapForUnit = function() return m.state.mapID end,
        GetPlayerMapPosition = function(mapID)
            if not m.state.pos then return nil end
            local x, y = m.state.pos[1], m.state.pos[2]
            return { GetXY = function() return x, y end, x = x, y = y }
        end,
        GetMapInfo = function(id) return { mapID = id, name = id == 1429 and "Elwynn Forest" or ("Map " .. id) } end,
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point) m.waypoints[#m.waypoints + 1] = point return true end,
    }
    env.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) m.superTracked = v end }
    env.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, position = { x = x, y = y } } end }
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix) m.prefixes[prefix] = true return true end,
        SendAddonMessage = function(prefix, text, channel, target)
            assert(m.prefixes[prefix], "prefix not registered")
            assert(#text <= 255, "addon message too long: " .. #text)
            assert(not string.find(text, "%z"), "addon message contains NUL")
            m.sent[#m.sent + 1] = { prefix = prefix, text = text, channel = channel }
            return 0
        end,
    }
    env.C_DateAndTime = {
        GetSecondsUntilDailyReset = function() return math.max(0, m.state.dailyReset - m.now) end,
        GetSecondsUntilWeeklyReset = function() return math.max(0, m.state.weeklyReset - m.now) end,
    }
    if opts.settingsAPI ~= false then
        env.Settings = {
            RegisterCanvasLayoutCategory = function(frame, name) m.settingsCategory = name return { name = name } end,
            RegisterAddOnCategory = function(cat) m.settingsRegistered = cat end,
        }
    end

    ---------------------------------------------------------------------------
    -- Fixture-checked namespaces and globals
    ---------------------------------------------------------------------------
    for nsName, impls in pairs(env) do
        if type(nsName) == "string" and string.sub(nsName, 1, 2) == "C_" and type(impls) == "table" then
            local real = API.namespaces[nsName]
            for fn in pairs(impls) do
                if not (real and real[fn]) then error("mock defines " .. nsName .. "." .. fn .. " which the Forever client does not have") end
            end
            setmetatable(impls, { __index = function(_, fn)
                if real and real[fn] then
                    m.unmocked[nsName .. "." .. fn] = true
                    return function() end
                end
                m.missingAPI[nsName .. "." .. fn] = true
                return nil
            end })
        end
    end
    local function baseName(name)
        return string.match(name, "^[^%.:]+")
    end
    local luaBase = {}
    for name in pairs(API.luaGlobals) do luaBase[baseName(name)] = true end

    -- Every global the mock provides must exist in the real client too, so a
    -- misspelled or removed API can't pass the tests just because we mocked it.
    local LUA_STD = { string = 1, table = 1, math = 1, pairs = 1, ipairs = 1, type = 1, tostring = 1, tonumber = 1,
        select = 1, unpack = 1, next = 1, pcall = 1, xpcall = 1, error = 1, assert = 1, setmetatable = 1,
        getmetatable = 1, rawget = 1, rawset = 1, rawequal = 1, print = 1, coroutine = 1, _G = 1, time = 1, date = 1,
        wipe = 1, strsplit = 1, strtrim = 1, format = 1, tinsert = 1, tremove = 1 }
    for k, v in pairs(env) do
        if type(k) == "string" and not LUA_STD[k] and string.sub(k, 1, 2) ~= "C_" and type(v) == "function"
            and not API.globals[k] and not luaBase[k] and not Mock.UNDOCUMENTED[k] then
            error("mock defines global " .. k .. " which the Forever client does not have")
        end
    end
    setmetatable(env, {
        __index = function(_, k)
            if API.namespaces[k] then
                m.unmocked[k] = true
                local real = API.namespaces[k]
                local proxy = setmetatable({}, { __index = function(_, fn)
                    if real[fn] then m.unmocked[k .. "." .. fn] = true return function() end end
                    m.missingAPI[k .. "." .. fn] = true
                end })
                rawset(env, k, proxy)
                return proxy
            end
            if API.globals[k] or Mock.UNDOCUMENTED[k] then
                m.unmocked[k] = true
                return function() end
            end
            if luaBase[k] then
                m.unmocked[k] = true
                return nil
            end
            m.unknownGlobals[k] = true
            return nil
        end,
        __newindex = function(t, k, v)
            m.globalWrites[k] = true
            rawset(t, k, v)
        end,
    })

    ---------------------------------------------------------------------------
    -- Events
    ---------------------------------------------------------------------------
    function m.Fire(event, ...)
        if not API.events[event] then error("test fired unknown event " .. event) end
        local list = m.eventFrames[event]
        if not list then return end
        local copy = {}
        for i, f in ipairs(list) do copy[i] = f end
        for _, f in ipairs(copy) do
            if f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
        end
    end

    ---------------------------------------------------------------------------
    -- Loading the addon from its .toc
    ---------------------------------------------------------------------------
    function m.LoadAddon(root, saved)
        root = root or (QB_ADDON_ROOT or "./")
        if saved then
            env.TaskboardDB = saved.db
            env.TaskboardLog = saved.log
        end
        m.globalWrites = {}
        local toc = assert(io.open(root .. "Taskboard.toc", "r"))
        local files = {}
        for line in toc:lines() do
            line = line:gsub("\r", "")
            if line ~= "" and not string.match(line, "^##") then files[#files + 1] = (line:gsub("\\", "/")) end
        end
        toc:close()
        m.ns = {}
        for _, file in ipairs(files) do
            local chunk = assert(loadfile(root .. file))
            setfenv(chunk, env)
            chunk("Taskboard", m.ns)
        end
        m.files = files
        return m.ns
    end

    function m.Login(saved)
        local ns = m.LoadAddon(nil, saved)
        m.Fire("ADDON_LOADED", "Taskboard")
        m.Fire("PLAYER_LOGIN")
        m.Fire("PLAYER_ENTERING_WORLD", true, false)
        return ns
    end

    -- Simulates logout: returns the SavedVariables as a deep copy.
    function m.Logout()
        m.Fire("PLAYER_LOGOUT")
        local function copy(v, seen)
            if type(v) ~= "table" then return v end
            seen = seen or {}
            if seen[v] then return seen[v] end
            local out = {}
            seen[v] = out
            for k, x in pairs(v) do
                if type(x) ~= "function" then out[copy(k, seen)] = copy(x, seen) end
            end
            return out
        end
        return { db = copy(rawget(env, "TaskboardDB")), log = copy(rawget(env, "TaskboardLog")) }
    end

    -- Finds visible widgets whose text contains `text`.
    function m.FindByText(text, kind)
        local out = {}
        for _, f in ipairs(m.frames) do
            local t = f._text or (f.label and f.label._text) or (f.Text and f.Text._text)
            if t and string.find(t, text, 1, true) and f:IsVisible() and (not kind or f._type == kind) then out[#out + 1] = f end
        end
        return out
    end

    function m.ChatContains(text)
        for _, line in ipairs(m.chat) do if string.find(line, text, 1, true) then return true end end
        return false
    end

    return m
end

return Mock

