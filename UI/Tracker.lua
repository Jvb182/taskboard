-- On-screen tracker: in-progress and tracked cards with live progress bars.
local _, ns = ...
local Util, DB, Theme, W = ns.Util, ns.DB, ns.Theme, ns.Widgets

local Tracker = ns:NewModule("Tracker")
local frame, header, rows = nil, nil, {}
local inCombat = false
local ROW_H, ROW_GAP = 36, 6
local offset = 0
local nextNearbySound

function Tracker:PulseSound(now)
    local s = ns.db.settings
    local active = false
    if s.nearbySounds and s.sounds and s.reminders and s.trackerLocationPulse and s.trackerShown
        and not (s.trackerHideInCombat and inCombat) and frame and frame:IsVisible() then
        for _, r in ipairs(rows) do
            if r:IsVisible() and r.nearby and r.card and not r.card.archived
                and DB:CardRole(r.board, r.card) ~= "done" and self:IsNearby(r.card) then active = true; break end
        end
    end
    if not active then nextNearbySound = nil; return end
    local interval = s.nearbySoundInterval
    if interval ~= 15 and interval ~= 30 and interval ~= 60 then interval = 30 end
    if not nextNearbySound then nextNearbySound = now + interval; return end
    if now >= nextNearbySound then
        ns.Toast:PlaySound("reminder")
        nextNearbySound = now + interval
    end
end

function Tracker:IsNearby(card)
    if not ns.db.settings.trackerLocationPulse or not card.where then return false end
    if card.where.npc == "mail" then return ns.Reminders:IsNearMailbox() end
    return card.where.zone and ns.Reminders.ZoneMatches(card.where.zone, GetRealZoneText(), GetSubZoneText()) or false
end

-- Cards to show, best first.
function Tracker:Entries()
    local list = {}
    for _, entry in ipairs(DB:AllCards(false)) do
        local card, board = entry.card, entry.board
        local role = DB:CardRole(board, card)
        local mine = ns.Engine:Owns(card, board)
        entry.nearby = self:IsNearby(card)
        if mine and role ~= "done" and (entry.nearby or entry.board.simpleMode or ns.db.settings.trackerAllOpen or role == "doing" or card.track) then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b)
        if a.nearby ~= b.nearby then return a.nearby end
        if (a.card.track and 1 or 0) ~= (b.card.track and 1 or 0) then return a.card.track and true or false end
        if a.card.priority ~= b.card.priority then return a.card.priority > b.card.priority end
        local fa = a.card._summary and a.card._summary.frac or 0
        local fb = b.card._summary and b.card._summary.frac or 0
        if fa ~= fb then return fa > fb end
        return a.card.created < b.card.created
    end)
    return list
end

local function savePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    ns.db.ui.tracker = { point = point, relPoint = relPoint, x = x, y = y }
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, frame)
    r:SetHeight(ROW_H)
    r.glow = r:CreateTexture(nil, "BACKGROUND")
    r.glow:SetAllPoints(r)
    r.glow:SetTexture(Theme.WHITE)
    r.glow:Hide()
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.title = W.Text(r, "GameFontHighlightSmall")
    r.title:SetPoint("TOPLEFT", 6, -4)
    r.title:SetPoint("RIGHT", -4, 0)
    r.bar = W.ProgressBar(r, 11)
    r.bar:SetPoint("BOTTOMLEFT", 6, 5)
    r.bar:SetPoint("BOTTOMRIGHT", -6, 5)
    r.divider = r:CreateTexture(nil, "BACKGROUND")
    r.divider:SetPoint("BOTTOMLEFT", 6, -3)
    r.divider:SetPoint("BOTTOMRIGHT", -6, -3)
    r.divider:SetHeight(1)
    r.divider:SetColorTexture(1, 1, 1, 0.14)
    r:SetHighlightTexture(Theme.WHITE)
    r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    r:SetScript("OnClick", ns.Wrap("tracker row", function(self, button)
        if button == "RightButton" then ns.Board:CardMenu(self.card, self.board) else ns.Editor:Open(self.card, self.board) end
    end))
    rows[i] = r
    return r
end

function Tracker:Create()
    if frame then return end
    frame = CreateFrame("Frame", "TaskboardTracker", UIParent, "BackdropTemplate")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", ns.Wrap("scroll tracker", function(_, delta)
        offset = math.max(0, offset - delta)
        Tracker:Refresh()
    end))
    frame:SetWidth(240)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    local pulseTime = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        pulseTime = (pulseTime + elapsed) % 2
        local alpha = 0.08 + 0.14 * (0.5 + 0.5 * math.sin(pulseTime * math.pi))
        for _, r in ipairs(rows) do
            if r.nearby and r:IsShown() then r.glow:SetAlpha(alpha) end
        end
    end)
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder)
    local pos = ns.db.ui.tracker or {}
    frame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x or -60, pos.y or -260)

    header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(20)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:RegisterForDrag("LeftButton")
    header.text = W.Text(header, "GameFontNormalSmall")
    header.text:SetPoint("LEFT", 6, 0)
    header:SetScript("OnDragStart", function()
        if not ns.db.settings.trackerLocked then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)
    header:SetScript("OnClick", ns.Wrap("tracker header", function(_, button)
        if button == "RightButton" then
            W.Menu(nil, {
                { text = "Taskboard tracker", title = true },
                { text = "Open board", func = function() ns.Board:Show() end },
                { text = "Show all open tasks", checked = ns.db.settings.trackerAllOpen, func = function()
                    ns.db.settings.trackerAllOpen = not ns.db.settings.trackerAllOpen
                    offset = 0
                    ns:Fire("TRACKER_SETTINGS")
                end },
                { text = "Collapse", checked = ns.db.ui.trackerCollapsed == true, func = function()
                    ns.db.ui.trackerCollapsed = not ns.db.ui.trackerCollapsed
                    Tracker:Refresh()
                end },
                { text = "Lock position", checked = ns.db.settings.trackerLocked, func = function()
                    ns.db.settings.trackerLocked = not ns.db.settings.trackerLocked
                end },
                { text = "Hide tracker", func = function() ns.Commands:Handle("tracker") end },
            })
        else
            ns.db.ui.trackerCollapsed = not ns.db.ui.trackerCollapsed
            Tracker:Refresh()
        end
    end))
    W.Tooltip(header, { "Taskboard tracker", "Click to collapse, drag to move, right-click for options." })
end

function Tracker:Refresh()
    if not ns.db then return end
    local s = ns.db.settings
    if not s.trackerShown or (s.trackerHideInCombat and inCombat) then
        if frame then frame:Hide() end
        return
    end
    self:Create()
    local entries = self:Entries()
    if #entries == 0 then frame:Hide() return end
    local collapsed = ns.db.ui.trackerCollapsed
    local shown = collapsed and 0 or math.min(#entries, s.trackerMax or 8)
    offset = math.max(0, math.min(offset, #entries - math.max(1, shown)))
    Theme.Brand(header.text, #entries > shown and not collapsed and
        string.format("  %d-%d of %d (scroll)", offset + 1, offset + shown, #entries) or string.format("  %d tasks", #entries))
    for i = 1, shown do
        local r = row(i)
        local entry = entries[offset + i]
        local card = entry.card
        r.card, r.board = card, entry.board
        r.nearby = entry.nearby
        r.glow:SetVertexColor(unpack(Theme.colors.accent))
        r.glow:SetAlpha(0.15)
        r.glow:SetShown(r.nearby)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 2, -24 - (i - 1) * (ROW_H + ROW_GAP))
        r:SetPoint("RIGHT", -2, 0)
        r.divider:SetShown(i < shown)
        local color = Theme.PRIORITY[card.priority] or Theme.PRIORITY[0]
        r.title:SetText(Util.Color(string.format("%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255), "-") .. " " .. card.title)
        local summary = card._summary
        if summary and summary.total > 0 then
            local text = card.progress and card.progress.text or (math.floor(summary.frac * 100 + 0.5) .. "%")
            r.bar:SetProgress(summary.frac, summary.done, text)
            r.bar:Show()
        else
            r.bar:Hide()
        end
        r:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    frame:SetHeight(shown > 0 and (28 + shown * ROW_H + (shown - 1) * ROW_GAP) or 22)
    frame:Show()
end

function Tracker:OnLogin()
    ns.Ticker(1, "nearby task sound", function() Tracker:PulseSound(GetTime()) end)
    local pending = false
    local function request()
        if pending then return end
        pending = true
        ns.After(0.1, "tracker refresh", function() pending = false Tracker:Refresh() end)
    end
    for _, message in ipairs({ "BOARD_CHANGED", "BOARD_REFRESH", "BOARDS_CHANGED", "PROGRESS_CHANGED", "TRACKER_SETTINGS", "SETTINGS_CHANGED" }) do
        ns:On(message, request)
    end
    ns:RegisterEvent("PLAYER_REGEN_DISABLED", function() inCombat = true Tracker:Refresh() end)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function() inCombat = false Tracker:Refresh() end)
    local function locationChanged() offset = 0; request() end
    ns:RegisterEvent("ZONE_CHANGED", locationChanged)
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", locationChanged)
    ns:RegisterEvent("ZONE_CHANGED_INDOORS", locationChanged)
    request()
end

function Tracker:Internals()
    return { frame = frame, rows = rows }
end

