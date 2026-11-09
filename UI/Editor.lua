-- Card editor: every field of a card. Changes apply immediately.
local _, ns = ...
local Util, DB, Theme, W, Parser = ns.Util, ns.DB, ns.Theme, ns.Widgets, ns.Parser

local Editor = ns:NewModule("Editor")
local frame, content, scrollContent
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
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder, true)
    table.insert(UISpecialFrames, "TaskboardEditor")

    -- Only the title strip starts a drag; controls must retain their own
    -- mouse press/release sequence, including buttons outside the scroll pane.
    ui.titleBar = CreateFrame("Frame", nil, frame)
    ui.titleBar:SetPoint("TOPLEFT", 0, 0)
    ui.titleBar:SetPoint("TOPRIGHT", 0, 0)
    ui.titleBar:SetHeight(28)
    ui.titleBar:EnableMouse(true)
    ui.titleBar:RegisterForDrag("LeftButton")
    ui.titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    ui.titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    ui.heading = W.Text(ui.titleBar, "GameFontNormal")
    ui.heading:SetPoint("TOPLEFT", 12, -10)
    ui.heading:SetText("Edit card")
    local close = W.CloseButton(frame)
    close:SetPoint("TOPRIGHT", 2, 2)

    local scroll
    scroll, content = W.Scroll(frame)
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    content:SetWidth(INNER)
    scrollContent = content

    local y = 0
    section("Title", y); y = y - 14
    ui.title = boxRow(y, "Card title", function(text)
        text = Util.Trim(text)
        if text ~= "" and text ~= current.card.title then apply({ title = text }) end
    end)
    ui.title.commitOnBlur = true
    y = y - 30

    -- Keep the remaining fields together so their content can resize with subtasks.
    ui.fieldsY = y
    ui.fields = CreateFrame("Frame", nil, scrollContent)
    ui.fields:SetWidth(INNER)
    content = ui.fields
    y = 0

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
        b.selectedMark = b:CreateTexture(nil, "ARTWORK")
        b.selectedMark:SetTexture(Theme.WHITE)
        b.selectedMark:SetPoint("BOTTOMLEFT", 3, 3)
        b.selectedMark:SetPoint("BOTTOMRIGHT", -3, 3)
        b.selectedMark:SetHeight(3)
        b.selectedMark:Hide()
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

    ui.track = W.Check(L, "Show in the on-screen tracker", function(checked)
        if readOnly() then
            -- Tracking a received card is this player's own preference.
            if current.card then
                current.card.track = checked or nil
                ns:Fire("BOARD_REFRESH")
                Editor:Refresh()
            end
        else
            apply({ track = checked })
        end
    end)
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
    -- Keep controls above the mouse-enabled scroll child as well as its paint
    -- clip: some clients still hit-test that child's overflowing bounds.
    ui.footer = CreateFrame("Frame", nil, frame)
    ui.footer:SetPoint("BOTTOMLEFT", 0, 0)
    ui.footer:SetPoint("BOTTOMRIGHT", 0, 0)
    ui.footer:SetHeight(36)
    ui.footer:EnableMouse(true)
    ui.footer:SetFrameLevel(scroll:GetFrameLevel() + 5)
    ui.delete = W.Button(ui.footer, "|cffff5a5aDelete|r", 70, 22, function()
        local card, board = current.card, current.board
        W.Confirm("Delete \"" .. card.title .. "\"?", function()
            DB:DeleteCard(board, card.id)
            frame:Hide()
        end)
    end)
    ui.delete:SetPoint("BOTTOMLEFT", 12, 10)
    ui.archive = W.Button(ui.footer, "Archive", 70, 22, function()
        apply({ archived = true })
        frame:Hide()
    end, "Hide the card without deleting it (restore from the board menu)")
    ui.archive:SetPoint("LEFT", ui.delete, "RIGHT", 6, 0)
    ui.done = W.Button(ui.footer, "Close", 70, 22, function() frame:Hide() end)
    for _, button in ipairs({ ui.delete, ui.archive, ui.done }) do
        button:EnableMouse(true)
    end
    ui.done:SetPoint("BOTTOMRIGHT", -12, 10)

    frame:SetScript("OnHide", function()
        for _, box in ipairs({ ui.title, ui.tags, ui.goal, ui.subAdd, ui.zone, ui.notes }) do box:ClearFocus() end
        for _, row in ipairs(ui.subRows) do if row.edit and row.edit:HasFocus() then row.edit:ClearFocus() end end
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
        local sub = subs[row.index]
        if sub and not sub.goal then
            sub.done = checked
            apply({ subtasks = subs })
            ns.Engine:Refresh(current.card, current.board)
        elseif checked and sub and sub.goal and sub.goal.type == "item" and not sub.goal.itemID then
            row.check:SetChecked(false)
            local card, board, subID = current.card, current.board, sub.id
            W.Confirm("Taskboard has not identified '" .. (sub.goal.name or sub.text) .. "' as an item yet. Mark this subtask done manually and stop item tracking?", function()
                if DB:IsReadOnly(board) then return end
                local updated = Util.DeepCopy(card.subtasks)
                for _, entry in ipairs(updated) do
                    if entry.id == subID then
                        entry.goal, entry.progress, entry.done = nil, nil, true
                        break
                    end
                end
                if DB:UpdateCard(board, card, { subtasks = updated }) then
                    for _, entry in ipairs(card.subtasks) do
                        if entry.id == subID then ns:Fire("SUBTASK_COMPLETED", card, board, entry); break end
                    end
                    ns.Engine:Refresh(card, board)
                end
            end)
        else
            row.check:SetChecked(sub and sub.done)
        end
    end, "Tracked subtasks check themselves. Click an unknown item goal to finish it manually.")
    row.check:SetPoint("LEFT", -4, 0)
    row.text = W.Text(row, "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 20, 0)
    row.text:SetPoint("RIGHT", -24, 0)
    row.edit = W.EditBox(row, INNER - 44, 20, "Edit subtask", true)
    row.edit:SetPoint("LEFT", 20, 0)
    row.edit:Hide()
    local function finishEdit(save)
        if not row.editing then return end
        row.editing = false
        local card, board, subID = row.editCard, row.editBoard, row.editSubID
        local text = Util.StripLinks(Util.Trim(row.edit:GetText()))
        row.edit:ClearFocus()
        row.edit:Hide(); row.text:Show(); row.editHit:Show()
        row.editCard, row.editBoard, row.editSubID = nil, nil, nil
        if not save or text == "" or not card or not board or DB:IsReadOnly(board) then return end
        local subs = Util.DeepCopy(card.subtasks)
        for _, sub in ipairs(subs) do
            if sub.id == subID and sub.text ~= text then
                sub.text = text
                sub.goal = Parser.ParseGoal(text)
                if sub.goal then sub.done = false; sub.progress = nil end
                if DB:UpdateCard(board, card, { subtasks = subs }) then
                    ns.Engine:Refresh(card, board)
                    if current.card == card then Editor:Refresh() end
                end
                return
            end
        end
    end
    row.finishEdit = finishEdit
    row.edit:SetScript("OnEnterPressed", ns.Wrap("edit subtask", function() finishEdit(true) end))
    row.edit:SetScript("OnEscapePressed", ns.Wrap("cancel subtask edit", function() finishEdit(false) end))
    row.edit:HookScript("OnEditFocusLost", ns.Wrap("save subtask edit", function() finishEdit(true) end))
    row.editHit = CreateFrame("Button", nil, row)
    row.editHit:SetPoint("LEFT", 20, 0)
    row.editHit:SetPoint("RIGHT", -24, 0)
    row.editHit:SetHeight(22)
    row.editHit:RegisterForClicks("LeftButtonUp")
    row.editHit:SetScript("OnClick", ns.Wrap("edit subtask", function()
        if readOnly() or not current.card or not current.card.subtasks[row.index] then return end
        row.editCard, row.editBoard = current.card, current.board
        row.editSubID = current.card.subtasks[row.index].id
        row.editing = true
        row.edit:SetText(current.card.subtasks[row.index].text)
        row.text:Hide(); row.editHit:Hide(); row.edit:Show()
        row.edit:SetFocus(); row.edit:HighlightText()
    end))
    W.Tooltip(row.editHit, "Click to edit subtask")
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

    local fieldOffset = -ui.fieldsY
    ui.fields:ClearAllPoints()
    ui.fields:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -fieldOffset)

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
        if row.editing and row.editCard ~= card then row.finishEdit(true) end
        row.index = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row.check:SetChecked(s.done)
        local progress = s.progress and ("  |cffaaaaaa" .. s.progress.text .. "|r") or ""
        row.text:SetText((s.done and "|cff959ba8" or "") .. s.text .. (s.done and "|r" or "") .. progress)
        row.editHit:EnableMouse(not ro)
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
    for _, b in ipairs(ui.recur) do
        local selected = b.value == (card.recur or "none")
        b:SetActive(selected)
        b.selectedMark:SetVertexColor(unpack(Theme.colors.accent))
        b.selectedMark:SetShown(selected)
        b.label:SetTextColor(unpack(selected and Theme.colors.accent or Theme.colors.text))
    end
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

    local fieldsHeight = -y + ui.lowerHeight + (#memberLines * 14)
    content:SetHeight(fieldsHeight)
    scrollContent:SetHeight(fieldOffset + fieldsHeight)
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

function Editor:Open(card, board, source)
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
    local trackerFrame = source == "tracker" and ns.Tracker and ns.Tracker:Internals().frame
    local anchor = trackerFrame and trackerFrame:IsShown() and trackerFrame
        or boardFrame and boardFrame:IsShown() and boardFrame
    if anchor then
        frame:SetParent(anchor)
        local left, right = anchor:GetLeft(), anchor:GetRight()
        local rightSpace = right and UIParent:GetWidth() - right or 0
        local leftSpace = left or 0
        if rightSpace < WIDTH + 4 and leftSpace > rightSpace then
            frame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
        else
            frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
        end
    else
        frame:SetParent(UIParent)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(frame:GetParent():GetFrameLevel() + 20)
    for _, control in ipairs({ ui.footer, ui.titleBar, frame.closeButton, ui.delete, ui.archive, ui.done }) do
        control:SetFrameStrata("DIALOG")
    end
    ui.footer:SetFrameLevel(frame:GetFrameLevel() + 10)
    ui.titleBar:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.closeButton:SetFrameLevel(frame:GetFrameLevel() + 12)
    self:SyncHeight()
    frame:Show()
    frame:Raise()
    self:Refresh()
end

function Editor:Current()
    return current.card, current.board
end

function Editor:Hide()
    if not frame then return end
    for _, box in ipairs({ ui.title, ui.tags, ui.goal, ui.subAdd, ui.zone, ui.notes }) do box:ClearFocus() end
    frame:Hide()
    current.card, current.board = nil, nil
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

