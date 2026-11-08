-- Card editor: every field of a card. Changes apply immediately.
local _, ns = ...
local Util, DB, Theme, W, Parser = ns.Util, ns.DB, ns.Theme, ns.Widgets, ns.Parser

local Editor = ns:NewModule("Editor")
local frame, content
local ui = {}
local current = { card = nil, board = nil }
local WIDTH, INNER = 340, 300

local function readOnly()
    return current.board and DB:IsReadOnly(current.board)
end

local function apply(changes)
    if not current.card or readOnly() then return end
    DB:UpdateCard(current.board, current.card, changes)
    Editor:Refresh()
end

local function section(text, y)
    local fs = W.Text(content, "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 0, y)
    fs:SetText(text)
    return fs
end

-- Row of toggle buttons. options = { {value, label} }, onPick(value)
local function choiceRow(y, options, width, onPick)
    local row = { buttons = {} }
    for i, opt in ipairs(options) do
        local b = W.Button(content, opt[2], width, 20, function() onPick(opt[1]) end)
        b:SetPoint("TOPLEFT", (i - 1) * (width + 4), y)
        b.value = opt[1]
        row.buttons[#row.buttons + 1] = b
    end
    function row:Select(value)
        for _, b in ipairs(self.buttons) do b:SetActive(b.value == value) end
    end
    return row
end

local function boxRow(y, placeholder, onCommit, acceptLinks, width)
    local box = W.EditBox(content, width or INNER, 22, placeholder, acceptLinks)
    box:SetPoint("TOPLEFT", 0, y)
    box:SetScript("OnEnterPressed", ns.Wrap("editor field", function(self)
        onCommit(self:GetText(), self)
        self:ClearFocus()
    end))
    box:HookScript("OnEditFocusLost", function(self)
        if self.commitOnBlur and not self.skipBlur then onCommit(self:GetText(), self) end
    end)
    return box
end

-------------------------------------------------------------------------------
-- Build
-------------------------------------------------------------------------------
function Editor:Create()
    if frame then return end
    frame = CreateFrame("Frame", "TaskboardEditor", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 560)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder)
    table.insert(UISpecialFrames, "TaskboardEditor")

    ui.heading = W.Text(frame, "GameFontNormal")
    ui.heading:SetPoint("TOPLEFT", 12, -10)
    ui.heading:SetText("Edit card")
    local close = W.CloseButton(frame)
    close:SetPoint("TOPRIGHT", 2, 2)

    local scroll
    scroll, content = W.Scroll(frame)
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    content:SetWidth(INNER)

    local y = 0
    section("Title", y); y = y - 14
    ui.title = boxRow(y, "Card title", function(text)
        text = Util.Trim(text)
        if text ~= "" and text ~= current.card.title then apply({ title = text }) end
    end)
    ui.title.commitOnBlur = true
    y = y - 30

    section("Column", y); y = y - 14
    ui.columnRow = { buttons = {} }
    ui.columnY = y
    y = y - 28

    section("Priority", y); y = y - 14
    ui.priority = choiceRow(y, { { 0, "None" }, { 1, "Low" }, { 2, "Medium" }, { 3, "High" } }, 71, function(v) apply({ priority = v }) end)
    y = y - 28

    section("Tags (space or comma separated)", y); y = y - 14
    ui.tags = boxRow(y, "herbs mats", function(text)
        local tags = {}
        for t in string.gmatch(text, "[^%s,#]+") do tags[#tags + 1] = t end
        apply({ tags = tags })
    end)
    ui.tags.commitOnBlur = true
    y = y - 30

    section("Goal (tracked live)", y); y = y - 14
    ui.goalText = W.Text(content, "GameFontHighlightSmall")
    ui.goalText:SetPoint("TOPLEFT", 0, y)
    ui.goalText:SetWidth(INNER)
    y = y - 16
    ui.goalBar = W.ProgressBar(content, 12)
    ui.goalBar:SetPoint("TOPLEFT", 0, y)
    ui.goalBar:SetWidth(INNER)
    y = y - 18
    ui.goal = boxRow(y, "20 Peacebloom, [item] x5, save 100g, level 40 ...", function(text, box)
        if Util.Trim(text) == "" then return end
        local goal = Parser.ParseGoal(text)
        if not goal then
            ns.Print("|cffff5555Couldn't read a goal from '%s'. Try: 20 Peacebloom, save 100g, reach level 40.|r", Util.StripLinks(text))
            return
        end
        box:SetText("")
        apply({ goal = goal })
    end, true, INNER - 60)
    ui.clearGoal = W.Button(content, "Clear", 56, 22, function() apply({ goal = false }) end, "Remove the goal")
    ui.clearGoal:SetPoint("TOPLEFT", INNER - 56, y)
    y = y - 26
    ui.bank = W.Check(content, "Count items in the bank", function(checked)
        if current.card.goal and current.card.goal.type == "item" then
            local goal = Util.DeepCopy(current.card.goal)
            goal.bank = checked
            apply({ goal = goal })
        end
    end)
    ui.bank:SetPoint("TOPLEFT", -4, y)
    y = y - 28

    section("Subtasks (each can have its own goal)", y); y = y - 16
    ui.subY = y
    ui.subRows = {}
    ui.subAdd = boxRow(y, "Add a subtask, e.g. 20 Silverleaf", function(text, box)
        text = Util.Trim(text)
        if text == "" then return end
        local subs = Util.DeepCopy(current.card.subtasks)
        subs[#subs + 1] = { text = Util.StripLinks(text), goal = Parser.ParseGoal(text), done = false }
        box:SetText("")
        apply({ subtasks = subs })
        box:SetFocus()
    end, true)

    -- Everything below the subtask list is positioned in Refresh.
    ui.lower = CreateFrame("Frame", nil, content)
    ui.lower:SetSize(INNER, 400)
    local L = ui.lower
    local function lsection(text, ly)
        local fs = W.Text(L, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 0, ly)
        fs:SetText(text)
    end
    local ly = 0
    lsection("Notes", ly); ly = ly - 14
    local notesBg = CreateFrame("Frame", nil, L, "BackdropTemplate")
    notesBg:SetPoint("TOPLEFT", 0, ly)
    notesBg:SetSize(INNER, 70)
    Theme.Panel(notesBg, Theme.colors.input, Theme.colors.inputBorder)
    ui.notes = CreateFrame("EditBox", nil, notesBg)
    ui.notes:SetMultiLine(true)
    ui.notes:SetAutoFocus(false)
    ui.notes:SetFontObject("ChatFontNormal")
    Theme.Text(ui.notes, "ChatFontNormal")
    ui.notes:SetPoint("TOPLEFT", 6, -4)
    ui.notes:SetPoint("BOTTOMRIGHT", -6, 4)
    ui.notes:SetMaxLetters(DB.LIMITS.notes)
    ui.notes:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.notes:SetScript("OnEditFocusLost", ns.Wrap("notes", function(self)
        if current.card and self:GetText() ~= current.card.notes then apply({ notes = self:GetText() }) end
    end))
    notesBg:EnableMouse(true)
    notesBg:SetScript("OnMouseDown", function() if not readOnly() then ui.notes:SetFocus() end end)
    ly = ly - 78

    lsection("Remind me", ly); ly = ly - 14
    ui.zone = W.EditBox(L, INNER - 60, 22, "Zone name, e.g. Ironforge")
    ui.zone:SetPoint("TOPLEFT", 0, ly)
    ui.zone:SetScript("OnEnterPressed", ns.Wrap("zone", function(self)
        local zone = Util.Trim(self:GetText())
        apply({ where = zone ~= "" and { zone = zone } or false })
        self:ClearFocus()
    end))
    ui.here = W.Button(L, "Here", 56, 22, function()
        local zone = GetRealZoneText and GetRealZoneText() or ""
        if zone ~= "" then apply({ where = { zone = zone } }) end
    end, "Use the zone you are in now")
    ui.here:SetPoint("TOPLEFT", INNER - 56, ly)
    ly = ly - 26
    ui.npc = {}
    local npcs = { { "none", "Off" }, { "bank", "Bank" }, { "vendor", "Vendor" }, { "mail", "Mail" }, { "ah", "AH" }, { "trainer", "Trainer" } }
    for i, opt in ipairs(npcs) do
        local b = W.Button(L, opt[2], 47, 20, function()
            if opt[1] == "none" then apply({ where = false }) else apply({ where = { npc = opt[1] } }) end
        end, opt[1] ~= "none" and ("Remind me when I open the " .. DB.NPCS[opt[1]]) or "No NPC reminder")
        b:SetPoint("TOPLEFT", (i - 1) * 51, ly)
        b.value = opt[1]
        ui.npc[#ui.npc + 1] = b
    end
    ly = ly - 28

    lsection("Repeat", ly); ly = ly - 14
    ui.recur = {}
    for i, opt in ipairs({ { "none", "Never" }, { "daily", "Daily" }, { "weekly", "Weekly" } }) do
        local b = W.Button(L, opt[2], 70, 20, function() apply({ recur = opt[1] ~= "none" and opt[1] or false }) end)
        b:SetPoint("TOPLEFT", (i - 1) * 74, ly)
        b.value = opt[1]
        ui.recur[#ui.recur + 1] = b
    end
    ui.streak = W.Text(L, "GameFontDisableSmall")
    ui.streak:SetPoint("TOPLEFT", 228, ly - 4)
    ly = ly - 28

    ui.recurItems = W.Check(L, "Items: collect extra each period (net gain)", function(checked)
        apply({ recurItems = checked and "gain" or "stock" })
    end, { "Repeating item goals", "Checked: count inventory above the amount at the start of the period.",
           "Unchecked: check your current stock; after reset, completion waits until the goal becomes incomplete first." })
    ui.recurItems:SetPoint("TOPLEFT", -4, ly)
    ly = ly - 28

    lsection("Map pin", ly); ly = ly - 14
    ui.pinText = W.Text(L, "GameFontHighlightSmall")
    ui.pinText:SetPoint("TOPLEFT", 0, ly)
    ui.pinText:SetWidth(INNER)
    ly = ly - 16
    ui.pinHere = W.Button(L, "Pin my location", 110, 20, function() Editor:PinHere() end)
    ui.pinHere:SetPoint("TOPLEFT", 0, ly)
    ui.pinShow = W.Button(L, "Show on map", 100, 20, function() Editor:ShowPin(current.card) end)
    ui.pinShow:SetPoint("TOPLEFT", 114, ly)
    ui.pinClear = W.Button(L, "Clear", 60, 20, function() apply({ pin = false }) end)
    ui.pinClear:SetPoint("TOPLEFT", 218, ly)
    ly = ly - 28

    ui.track = W.Check(L, "Show in the on-screen tracker", function(checked) apply({ track = checked }) end)
    ui.track:SetPoint("TOPLEFT", -4, ly)
    ly = ly - 28

    ui.members = W.Text(L, "GameFontHighlightSmall")
    ui.members:SetPoint("TOPLEFT", 0, ly)
    ui.members:SetWidth(INNER)
    ui.members:SetWordWrap(true)
    ui.info = W.Text(L, "GameFontDisableSmall")
    ui.info:SetPoint("TOPLEFT", ui.members, "BOTTOMLEFT", 0, -6)
    ui.info:SetWidth(INNER)
    ui.info:SetWordWrap(true)
    ui.lowerHeight = -ly + 60

    -- Footer buttons
    ui.delete = W.Button(frame, "|cffff5a5aDelete|r", 70, 22, function()
        local card, board = current.card, current.board
        W.Confirm("Delete \"" .. card.title .. "\"?", function()
            DB:DeleteCard(board, card.id)
            frame:Hide()
        end)
    end)
    ui.delete:SetPoint("BOTTOMLEFT", 12, 10)
    ui.archive = W.Button(frame, "Archive", 70, 22, function()
        apply({ archived = true })
        frame:Hide()
    end, "Hide the card without deleting it (restore from the board menu)")
    ui.archive:SetPoint("LEFT", ui.delete, "RIGHT", 6, 0)
    ui.done = W.Button(frame, "Close", 70, 22, function() frame:Hide() end)
    ui.done:SetPoint("BOTTOMRIGHT", -12, 10)

    frame:SetScript("OnHide", function()
        for _, box in ipairs({ ui.title, ui.tags, ui.goal, ui.subAdd, ui.zone, ui.notes }) do box:ClearFocus() end
        current.card, current.board = nil, nil
    end)
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
local function subtaskRow(i)
    local row = ui.subRows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, content)
    row:SetSize(INNER, 22)
    row.check = W.Check(row, "", function(checked)
        local subs = Util.DeepCopy(current.card.subtasks)
        if subs[row.index] and not subs[row.index].goal then
            subs[row.index].done = checked
            apply({ subtasks = subs })
            ns.Engine:Refresh(current.card, current.board)
        else
            row.check:SetChecked(subs[row.index] and subs[row.index].done)
        end
    end, "Subtasks with a goal check themselves")
    row.check:SetPoint("LEFT", -4, 0)
    row.text = W.Text(row, "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 20, 0)
    row.text:SetPoint("RIGHT", -24, 0)
    row.remove = W.IconButton(row, "Interface\\Buttons\\UI-StopButton", 14, function()
        local subs = Util.DeepCopy(current.card.subtasks)
        table.remove(subs, row.index)
        apply({ subtasks = subs })
    end, "Remove subtask")
    row.remove:SetPoint("RIGHT", -2, 0)
    ui.subRows[i] = row
    return row
end

function Editor:Refresh()
    local card, board = current.card, current.board
    if not frame or not frame:IsShown() or not card then return end
    if ns.db.boards[board.id] ~= board then
        local replacement = ns.db.boards[board.id]
        if replacement and replacement.cards[card.id] then
            self:Open(replacement.cards[card.id], replacement)
        else frame:Hide() end
        return
    end
    if not board.cards[card.id] then frame:Hide() return end
    local ro = readOnly()
    ui.heading:SetText(ro and "View card (shared, read-only)" or "Edit card")

    -- Never overwrite a field the player is typing in (progress events refresh often).
    if not ui.title:HasFocus() then ui.title:SetText(card.title) end
    ui.title:Refresh()

    -- Column buttons are rebuilt because boards can have custom columns.
    for _, b in ipairs(ui.columnRow.buttons) do b:Hide() end
    local n = #board.columns
    local bw = math.floor((INNER - 4 * (n - 1)) / n)
    for i, col in ipairs(board.columns) do
        local b = ui.columnRow.buttons[i]
        if not b then
            b = W.Button(content, "", bw, 20)
            ui.columnRow.buttons[i] = b
        end
        b:SetWidth(bw)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", (i - 1) * (bw + 4), ui.columnY)
        b:SetLabel(col.name)
        b:SetActive(col.id == card.column)
        b:SetScript("OnClick", ns.Wrap("editor column", function()
            if not ro then DB:MoveCard(board, card.id, col.id) Editor:Refresh() end
        end))
        b:Show()
    end

    ui.priority:Select(card.priority)
    if not ui.tags:HasFocus() then ui.tags:SetText(table.concat(card.tags, " ")) end
    ui.tags:Refresh()

    local goal = card.goal
    ui.goalText:SetText(goal and Parser.Describe(goal) or "|cff959ba8No goal. Type one below or shift-click an item.|r")
    if goal and card.progress then
        ui.goalBar:SetProgress(card.progress.frac, card.progress.done, card.progress.text)
        ui.goalBar:Show()
    else
        ui.goalBar:Hide()
    end
    ui.clearGoal:SetShown(goal ~= nil and not ro)
    ui.bank:SetShown(goal ~= nil and goal.type == "item")
    ui.bank:SetChecked(goal and goal.bank ~= false)

    -- Subtasks
    local y = ui.subY
    for i, s in ipairs(card.subtasks) do
        local row = subtaskRow(i)
        row.index = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row.check:SetChecked(s.done)
        local progress = s.progress and ("  |cffaaaaaa" .. s.progress.text .. "|r") or ""
        row.text:SetText((s.done and "|cff959ba8" or "") .. s.text .. (s.done and "|r" or "") .. progress)
        row.remove:SetShown(not ro)
        row:Show()
        y = y - 22
    end
    for i = #card.subtasks + 1, #ui.subRows do ui.subRows[i]:Hide() end
    ui.subAdd:ClearAllPoints()
    ui.subAdd:SetPoint("TOPLEFT", 0, y - 2)
    ui.subAdd:SetShown(not ro)
    y = y - 32

    ui.lower:ClearAllPoints()
    ui.lower:SetPoint("TOPLEFT", 0, y)
    if not ui.notes:HasFocus() then ui.notes:SetText(card.notes or "") end
    if not ui.zone:HasFocus() then ui.zone:SetText(card.where and card.where.zone or "") end
    ui.zone:Refresh()
    local npc = card.where and card.where.npc or (card.where and card.where.zone and "zone") or "none"
    for _, b in ipairs(ui.npc) do b:SetActive(b.value == npc) end
    for _, b in ipairs(ui.recur) do b:SetActive(b.value == (card.recur or "none")) end
    ui.streak:SetText(card.recur and ("Streak " .. (card.streak or 0)) or "")
    ui.recurItems:SetShown(card.recur ~= nil)
    ui.recurItems:SetChecked(card.recurItems ~= "stock")

    if card.pin then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(card.pin.mapID)
        ui.pinText:SetText(string.format("%s %.1f, %.1f", info and info.name or ("Map " .. card.pin.mapID), card.pin.x * 100, card.pin.y * 100))
    else
        ui.pinText:SetText("|cff959ba8No pin|r")
    end
    ui.pinShow:SetShown(card.pin ~= nil)
    ui.pinClear:SetShown(card.pin ~= nil and not ro)
    ui.track:SetChecked(card.track == true)

    local memberLines = {}
    if board.shared and board.shared.members then
        for member, cards in pairs(board.shared.members) do
            local p = cards[card.id]
            if p then
                memberLines[#memberLines + 1] = string.format("|cff8ecfff%s|r %s%s", string.match(member, "^[^%-]+") or member,
                    p.text or (math.floor(p.frac * 100) .. "%"), p.done and " |cff5cd673(done)|r" or "")
            end
        end
    end
    ui.members:SetText(#memberLines > 0 and ("Group progress:\n" .. table.concat(memberLines, "\n")) or "")
    local owner = card.char and ("Belongs to " .. card.char .. ". ") or ""
    ui.info:SetText(owner .. "Created " .. Util.Ago(card.created) .. (card.completedAt and (", completed " .. Util.Ago(card.completedAt)) or "") .. ".")

    content:SetHeight(-y + ui.lowerHeight + (#memberLines * 14))
    for _, box in ipairs({ ui.title, ui.tags, ui.goal, ui.zone, ui.notes }) do box:EnableMouse(not ro) end
    ui.delete:SetShown(not ro)
    ui.archive:SetShown(not ro)
end

-------------------------------------------------------------------------------
-- Pins
-------------------------------------------------------------------------------
function Editor:PinHere()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        ns.Print("|cffff5555Map positions aren't available in this client.|r")
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        ns.Print("|cffff5555Your position isn't available here (instances hide it).|r")
        return
    end
    local x, y = pos:GetXY()
    apply({ pin = { mapID = mapID, x = x, y = y, label = GetSubZoneText and GetSubZoneText() or "" } })
    ns.Log:Info("ui", "Pinned card to map %d at %.3f, %.3f", mapID, x, y)
end

function Editor:ShowPin(card)
    local pin = card and card.pin
    if not pin then return end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(pin.mapID)
    local where = string.format("%s %.1f, %.1f", info and info.name or ("map " .. pin.mapID), pin.x * 100, pin.y * 100)
    if UiMapPoint and C_Map.SetUserWaypoint and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(pin.mapID)) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(pin.mapID, pin.x, pin.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        ns.Print("Waypoint set: %s (%s)", where, card.title)
    else
        ns.Print("%s: %s", card.title, where)
    end
end

-------------------------------------------------------------------------------
-- Open
-------------------------------------------------------------------------------
function Editor:SyncHeight()
    if not frame then return end
    local boardFrame = ns.Board.frame
    local saved = ns.db.ui.board
    local height = boardFrame and boardFrame:GetHeight() or (saved and saved.h) or 500
    frame:SetHeight(math.max(340, math.min(1100, height)))
end

function Editor:Open(card, board)
    self:Create()
    if current.card ~= card then
        -- Blur while the old card is still current: commits cannot leak to the new one.
        for _, box in ipairs({ ui.title, ui.tags, ui.goal, ui.subAdd, ui.zone, ui.notes }) do box:ClearFocus() end
        ui.goal:SetText("")
        ui.subAdd:SetText("")
    end
    current.card, current.board = card, board
    frame:ClearAllPoints()
    local boardFrame = ns.Board.frame
    if boardFrame and boardFrame:IsShown() then
        frame:SetPoint("TOPLEFT", boardFrame, "TOPRIGHT", 4, 0)
    else
        frame:SetPoint("CENTER", 0, 0)
    end
    self:SyncHeight()
    frame:Show()
    self:Refresh()
end

function Editor:Current()
    return current.card, current.board
end

function Editor:OnLogin()
    ns:On("BOARD_RESIZED", function() Editor:SyncHeight() end)
    for _, message in ipairs({ "PROGRESS_CHANGED", "BOARD_CHANGED", "BOARD_REFRESH", "BOARDS_CHANGED" }) do
        ns:On(message, function() Editor:Refresh() end)
    end
end

function Editor:Internals()
    return { frame = frame, ui = ui }
end

