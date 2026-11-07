-- The board window: columns of cards with drag and drop, search and filters.
local _, ns = ...
local Util, DB, Theme, W = ns.Util, ns.DB, ns.Theme, ns.Widgets

local Board = ns:NewModule("Board")
Board.CARD_GAP = 6
Board.CARD_H = 44
Board.BAR_H = 14
Board.filter = { text = "", tag = nil }

local frame, columnsHost, columnsViewport, horizontalScroll, footer, addBox, searchBox, boardButton, mineCheck, tagButton
local columnFrames = {}
local cardPool, usedCards = {}, {}
local dirty = true
local drag
local examplesFrame

function Board:ShowExamples()
    if not examplesFrame then
        examplesFrame = CreateFrame("Frame", "TaskboardExamples", frame, "BackdropTemplate")
        examplesFrame:SetSize(520, 430)
        examplesFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        examplesFrame:SetFrameStrata("DIALOG")
        examplesFrame:SetClampedToScreen(true)
        examplesFrame:EnableMouse(true)
        Theme.Panel(examplesFrame, Theme.colors.window, Theme.colors.windowBorder)
        table.insert(UISpecialFrames, "TaskboardExamples")
        local title = W.Text(examplesFrame, "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("Quick Add examples")
        local close = CreateFrame("Button", nil, examplesFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        local scroll, content = W.Scroll(examplesFrame)
        scroll:SetPoint("TOPLEFT", 16, -44)
        scroll:SetPoint("BOTTOMRIGHT", -34, 16)
        content:SetSize(464, 760)
        local lines = {
            "Type an example into Quick Add, then press Enter.",
            "For item or quest links, focus the box and shift-click the link.",
            "", "ITEMS AND OTHER GOALS",
            "get 17 Silverleaf",
            "Get 20 Peacebloom #herbs !high",
            "[shift-click an item] x17",
            "save 10g 50s",
            "reach level 40",
            "Herbalism 150",
            "Honored with Stormwind",
            "quest: The Defias Brotherhood",
            "", "REMINDERS",
            "Visit the trainer @Ironforge",
            'Buy supplies @"Stormwind City"',
            "Sort supplies @bank",
            "Buy vials @vendor",
            "Check mail @mail",
            "List auctions @ah",
            "Learn new skills @trainer",
            "", "REPEATING TASKS AND ORGANIZATION",
            "Check auctions *daily",
            "Plan dungeon runs *weekly",
            "Organize bags #chores !low",
            "Prepare for tonight !high >doing",
            "Alchemy prep; 20 Peacebloom; 20 Silverleaf; buy vials",
            "", "SYNTAX AT A GLANCE",
            "#tag groups tasks; !low, !med or !high sets priority.",
            "@zone or @bank adds a reminder; quote multiword zones.",
            "*daily or *weekly repeats a task; >doing sets its status.",
            "A semicolon starts a new subtask.",
            "Item goals normally count items you already own.",
            "Repeating item goals default to gains above a starting count.",
        }
        for i, line in ipairs(lines) do
            local text = W.Text(content, "GameFontHighlightSmall")
            text:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
            text:SetWidth(464)
            text:SetText(line)
        end
    end
    examplesFrame:Show()
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function activeBoard()
    return DB:GetActiveBoard()
end

local function matchesFilter(card)
    local f = Board.filter
    if ns.db.settings.onlyMine and card.char and card.char ~= ns.CharKey() then return false end
    if f.tag and not Util.IndexOf(card.tags, f.tag) then return false end
    if f.text ~= "" then
        local hay = Util.Lower(card.title .. " " .. (card.notes or "") .. " #" .. table.concat(card.tags, " #"))
        if not string.find(hay, f.text, 1, true) then return false end
    end
    return true
end
Board.MatchesFilter = matchesFilter

local function cardHeight(card)
    local h = Board.CARD_H
    if ns.Goals.HasGoals(card) or #card.subtasks > 0 then h = h + Board.BAR_H end
    return h
end
Board.CardHeight = cardHeight

local function shortChar(key)
    return key and (string.match(key, "^([^%-]+)") or key) or ""
end

-------------------------------------------------------------------------------
-- Card tooltip and menu
-------------------------------------------------------------------------------
local function cardTooltip(card, board)
    local lines = { card.title }
    if card.notes and card.notes ~= "" then lines[#lines + 1] = card.notes end
    if card.goal then
        lines[#lines + 1] = "|cffffd100Goal:|r " .. ns.Parser.Describe(card.goal)
        if card.progress then lines[#lines + 1] = "   " .. card.progress.text end
    end
    for _, s in ipairs(card.subtasks) do
        local mark = s.done and "|cff5cd673[x]|r " or "[  ] "
        lines[#lines + 1] = mark .. s.text .. (s.progress and ("  |cffaaaaaa" .. s.progress.text .. "|r") or "")
    end
    if card.where then
        lines[#lines + 1] = "|cffffd100Reminder:|r " .. (card.where.zone or DB.NPCS[card.where.npc] or "?")
    end
    if card.recur then lines[#lines + 1] = string.format("|cffffd100Repeats %s|r, streak %d", card.recur, card.streak or 0) end
    if card.char and card.char ~= ns.CharKey() then
        local seen = card.progress and card.progress.t and (", last seen " .. Util.Ago(card.progress.t)) or ""
        lines[#lines + 1] = "|cff959ba8Belongs to " .. card.char .. seen .. "|r"
    end
    if board.shared and board.shared.members then
        for member, cards in pairs(board.shared.members) do
            local p = cards[card.id]
            if p then lines[#lines + 1] = string.format("|cff8ecfff%s|r: %s", shortChar(member), p.text or (math.floor(p.frac * 100) .. "%")) end
        end
    end
    if card._regressed then lines[#lines + 1] = "|cffffb84dCompleted earlier, but the count has dropped since.|r" end
    lines[#lines + 1] = "|cff777777Click to edit, right-click for options, drag to move|r"
    return lines
end

function Board:CardMenu(card, board)
    local readOnly = DB:IsReadOnly(board)
    local items = { { text = card.title, title = true } }
    items[#items + 1] = { text = readOnly and "View" or "Edit", func = function() ns.Editor:Open(card, board) end }
    if not readOnly then
        for _, col in ipairs(board.columns) do
            if col.id ~= card.column then
                items[#items + 1] = { text = "Move to " .. col.name, func = function() DB:MoveCard(board, card.id, col.id) end }
            end
        end
        items[#items + 1] = { text = "Move to top", func = function() DB:MoveCard(board, card.id, card.column, 1) end }
    end
    items[#items + 1] = { text = "Show in tracker", checked = card.track == true, func = function()
        card.track = not card.track or nil
        ns:Fire("BOARD_REFRESH")
    end }
    if card.pin then items[#items + 1] = { text = "Show on map", func = function() ns.Editor:ShowPin(card) end } end
    if not readOnly then
        items[#items + 1] = { text = "Duplicate", func = function()
            local copy = Util.DeepCopy(card)
            copy.title = card.title .. " (copy)"
            copy.progress, copy.auto, copy.completedAt = nil, nil, nil
            DB:AddCard(board, copy, card.column)
        end }
        items[#items + 1] = { text = "Archive", func = function() DB:UpdateCard(board, card, { archived = true }) end }
        items[#items + 1] = { text = "|cffff5a5aDelete|r", func = function()
            W.Confirm("Delete \"" .. card.title .. "\"?", function() DB:DeleteCard(board, card.id) end)
        end }
    end
    W.Menu(nil, items)
end

-------------------------------------------------------------------------------
-- Card frames (pooled)
-------------------------------------------------------------------------------
local function createCard()
    local c = CreateFrame("Button", nil, columnsHost, "BackdropTemplate")
    Theme.Panel(c, Theme.colors.card, Theme.colors.cardBorder)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:RegisterForDrag("LeftButton")
    c.stripe = c:CreateTexture(nil, "ARTWORK")
    c.stripe:SetPoint("TOPLEFT", 1, -1)
    c.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    c.stripe:SetWidth(3)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(22, 22)
    c.icon:SetPoint("TOPLEFT", 8, -6)
    c.title = W.Text(c, "GameFontHighlight")
    c.meta = W.Text(c, "GameFontDisableSmall")
    c.check = c:CreateTexture(nil, "OVERLAY")
    c.check:SetSize(14, 14)
    c.check:SetPoint("TOPRIGHT", -5, -5)
    c.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    c.bar = W.ProgressBar(c, 11)
    c.bar:SetPoint("BOTTOMLEFT", 8, 6)
    c.bar:SetPoint("BOTTOMRIGHT", -6, 6)

    c:SetScript("OnEnter", function(self)
        if drag then return end
        self:SetBackdropColor(unpack(Theme.colors.cardHover))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, line in ipairs(cardTooltip(self.card, self.board)) do
            if i == 1 then GameTooltip:SetText(line, 1, 1, 1, 1, true) else GameTooltip:AddLine(line, 0.85, 0.87, 0.9, true) end
        end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.isDone and Theme.colors.cardDone or Theme.colors.card))
        GameTooltip:Hide()
    end)
    c:SetScript("OnClick", ns.Wrap("card click", function(self, button)
        if button == "RightButton" then Board:CardMenu(self.card, self.board)
        else ns.Editor:Open(self.card, self.board) end
    end))
    c:SetScript("OnDragStart", ns.Wrap("card drag", function(self) Board:BeginDrag(self) end))
    c:SetScript("OnDragStop", ns.Wrap("card drop", function() Board:EndDrag() end))
    return c
end

local function acquireCard()
    local c = table.remove(cardPool) or createCard()
    usedCards[#usedCards + 1] = c
    c:Show()
    return c
end

local function releaseCards()
    for i = #usedCards, 1, -1 do
        local c = usedCards[i]
        c:Hide()
        c:ClearAllPoints()
        c.card, c.board = nil, nil
        cardPool[#cardPool + 1] = c
        usedCards[i] = nil
    end
end

local function metaText(card, board)
    local parts = {}
    for _, tag in ipairs(card.tags) do parts[#parts + 1] = "#" .. tag end
    if #card.subtasks > 0 then
        local n = 0
        for _, s in ipairs(card.subtasks) do if s.done then n = n + 1 end end
        parts[#parts + 1] = n .. "/" .. #card.subtasks
    end
    if card.recur then parts[#parts + 1] = (card.recur == "daily" and "Daily" or "Weekly") .. (card.streak > 0 and (" x" .. card.streak) or "") end
    if card.where then parts[#parts + 1] = "@" .. (card.where.zone or DB.NPCS[card.where.npc] or "?") end
    if card.pin then parts[#parts + 1] = "Pin" end
    if card.track then parts[#parts + 1] = "Tracked" end
    if card.char and card.char ~= ns.CharKey() then parts[#parts + 1] = "|cff8ecfff" .. shortChar(card.char) .. "|r" end
    if board.shared and board.shared.members and Util.Count(board.shared.members) > 0 then
        parts[#parts + 1] = Util.Count(board.shared.members) .. " in group"
    end
    if card._regressed then parts[#parts + 1] = "|cffffb84dcount dropped|r" end
    return table.concat(parts, "  ")
end

local function paintCard(c, card, board, width)
    c.card, c.board = card, board
    local role = DB:CardRole(board, card)
    c.isDone = role == "done"
    c:SetSize(width, cardHeight(card))
    c:SetBackdropColor(unpack(c.isDone and Theme.colors.cardDone or Theme.colors.card))
    c:SetAlpha(1)
    c.stripe:SetColorTexture(unpack(Theme.PRIORITY[card.priority] or Theme.PRIORITY[0]))
    local hasGoal = ns.Goals.HasGoals(card)
    local left = 9
    if card.goal then
        c.icon:SetTexture(ns.Goals.Icon(card.goal))
        c.icon:Show()
        left = 36
    else
        c.icon:Hide()
    end
    c.title:ClearAllPoints()
    c.title:SetPoint("TOPLEFT", left, -7)
    c.title:SetPoint("RIGHT", c.isDone and -22 or -6, 0)
    c.title:SetText(card.title)
    c.title:SetTextColor(unpack(c.isDone and Theme.colors.muted or Theme.colors.text))
    c.meta:ClearAllPoints()
    c.meta:SetPoint("TOPLEFT", left, -24)
    c.meta:SetPoint("RIGHT", -6, 0)
    c.meta:SetText(metaText(card, board))
    c.check:SetShown(c.isDone)
    if hasGoal or #card.subtasks > 0 then
        local s = card._summary
        local text
        if card.goal and card.progress then
            text = card.progress.text
        elseif s then
            text = math.floor((s.frac or 0) * 100 + 0.5) .. "%"
        end
        c.bar:SetProgress(s and s.frac or (card.progress and card.progress.frac) or 0, s and s.done or c.isDone, text)
        c.bar:Show()
    else
        c.bar:Hide()
    end
end

-------------------------------------------------------------------------------
-- Columns
-------------------------------------------------------------------------------
local function createColumn()
    local col = CreateFrame("Frame", nil, columnsHost, "BackdropTemplate")
    Theme.Panel(col, Theme.colors.panel, Theme.colors.panelBorder)
    col.band = col:CreateTexture(nil, "ARTWORK")
    col.band:SetPoint("TOPLEFT", 1, -1)
    col.band:SetPoint("TOPRIGHT", -1, -1)
    col.band:SetHeight(2)
    col.header = CreateFrame("Button", nil, col)
    col.header:SetPoint("TOPLEFT", 0, 0)
    col.header:SetPoint("TOPRIGHT", 0, 0)
    col.header:SetHeight(24)
    col.header:RegisterForClicks("RightButtonUp")
    col.title = W.Text(col.header, "GameFontNormal")
    col.title:SetPoint("LEFT", 8, -1)
    col.count = W.Text(col.header, "GameFontDisableSmall", "RIGHT")
    col.count:SetPoint("RIGHT", -8, -1)
    col.scroll, col.content = W.Scroll(col)
    col.scroll:SetPoint("TOPLEFT", 4, -26)
    col.scroll:SetPoint("BOTTOMRIGHT", -24, 4)
    col.dropLine = col:CreateTexture(nil, "OVERLAY")
    col.dropLine:SetHeight(2)
    col.dropLine:SetColorTexture(unpack(Theme.colors.dropLine))
    col.dropLine:Hide()
    col.empty = W.Text(col, "GameFontDisableSmall", "CENTER")
    col.empty:SetPoint("TOP", 0, -40)
    col.header:SetScript("OnClick", ns.Wrap("column menu", function() Board:ColumnMenu(col.column) end))
    return col
end

function Board:ColumnMenu(column)
    local board = activeBoard()
    if not board or not column or DB:IsReadOnly(board) then return end
    W.Menu(nil, {
        { text = column.name, title = true },
        { text = "Rename", func = function() Board:Prompt("Rename column", column.name, function(text) DB:RenameColumn(board, column.id, text) end) end },
        { text = "Add column", func = function() Board:Prompt("New column name", "", function(text)
            local _, err = DB:AddColumn(board, text)
            if err then ns.Print("|cffff5555%s|r", err) end
        end) end },
        { text = "Remove column", disabled = column.role ~= nil, func = function()
            local ok, err = DB:RemoveColumn(board, column.id)
            if not ok then ns.Print("|cffff5555%s|r", err) end
        end },
        { text = "Archive all cards here", disabled = column.role ~= "done", func = function()
            for _, card in ipairs(DB:CardsIn(board, column.id)) do card.archived = true end
            ns:Fire("BOARD_CHANGED", board)
        end },
    })
end

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
function Board:Layout()
    if not frame or not frame:IsShown() then dirty = true return end
    if drag then dirty = true return end -- never recycle the frame holding an active drag
    dirty = false
    local board = activeBoard()
    releaseCards()
    if not board then
        for _, col in ipairs(columnFrames) do col:Hide() end
        boardButton:SetLabel("New board")
        footer:SetText("Create a board from the board menu.")
        horizontalScroll:Hide()
        return
    end
    boardButton:SetLabel(board.name .. (DB:IsReadOnly(board) and " (shared)" or ""))
    local n = #board.columns
    local gap = 8
    local viewportW = math.max(1, frame:GetWidth() - 24)
    local hostW = math.max(viewportW, n * 140 + gap * (n - 1))
    columnsHost:SetSize(hostW, math.max(10, frame:GetHeight() - 116))
    local scrollRange = math.max(0, hostW - viewportW)
    horizontalScroll:SetMinMaxValues(0, scrollRange)
    horizontalScroll:SetValue(math.min(horizontalScroll:GetValue() or 0, scrollRange))
    horizontalScroll:SetShown(scrollRange > 0)
    horizontalScroll:GetThumbTexture():SetVertexColor(unpack(Theme.colors.accent))
    columnsViewport:SetHorizontalScroll(horizontalScroll:GetValue() or 0)
    local colW = math.max(140, math.floor((hostW - gap * (n - 1)) / n))
    for i, column in ipairs(board.columns) do
        local col = columnFrames[i] or createColumn()
        columnFrames[i] = col
        col.column = column
        col:ClearAllPoints()
        col:SetPoint("TOPLEFT", columnsHost, "TOPLEFT", (i - 1) * (colW + gap), 0)
        col:SetPoint("BOTTOM", columnsHost, "BOTTOM", 0, 0)
        col:SetWidth(colW)
        col:Show()
        local color = Theme.RoleColor(column.role)
        col.band:SetColorTexture(unpack(color))
        col.title:SetText(column.name)
        col.title:SetTextColor(color[1], color[2], color[3])
        local cards = DB:CardsIn(board, column.id, matchesFilter)
        col.count:SetText(#cards)
        col.cards = cards
        local width = colW - 30
        col.content:SetWidth(width)
        local y = 0
        col.slots = {}
        for _, card in ipairs(cards) do
            local c = acquireCard()
            c:SetParent(col.content)
            paintCard(c, card, board, width)
            c:SetPoint("TOPLEFT", col.content, "TOPLEFT", 0, -y)
            col.slots[#col.slots + 1] = { top = y, height = c:GetHeight(), card = card }
            y = y + c:GetHeight() + Board.CARD_GAP
        end
        col.content:SetHeight(math.max(y, 10))
        col.empty:SetText(#cards == 0 and (Board.filter.text ~= "" and "No matches" or "Drop cards here") or "")
    end
    for i = n + 1, #columnFrames do columnFrames[i]:Hide() end

    local s = ns.Stats:Summary()
    footer:SetText(string.format("Today |cffffffff%d|r     This week |cffffffff%d|r     Streak |cffffffff%d|r day%s     Total |cffffffff%d|r",
        s.today, s.week, s.streak, s.streak == 1 and "" or "s", s.total))
    ns:Fire("BOARD_LAID_OUT", board)
end

function Board:RequestLayout()
    if dirty and self.pending then return end
    dirty = true
    if not frame or not frame:IsShown() then return end
    if self.pending then return end
    self.pending = true
    ns.After(0, "board layout", function()
        Board.pending = false
        Board:Layout()
    end)
end

-------------------------------------------------------------------------------
-- Drag and drop
-------------------------------------------------------------------------------
local ghost
local function cursorUI()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

-- Which column and index the cursor is over. Returns colFrame, index.
function Board:DropTarget()
    for _, col in ipairs(columnFrames) do
        if col:IsShown() and col:IsMouseOver() then
            local _, y = cursorUI()
            local top = col.content:GetTop()
            if not top then return col, #(col.slots or {}) + 1 end
            local offset = top - y
            local index = #col.slots + 1
            for i, slot in ipairs(col.slots) do
                if offset < slot.top + slot.height / 2 then index = i break end
            end
            return col, index
        end
    end
end

function Board:BeginDrag(cardFrame)
    local board = cardFrame.board
    if not board or DB:IsReadOnly(board) then return end
    W.HideMenu()
    GameTooltip:Hide()
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ghost:SetFrameStrata("TOOLTIP")
        Theme.Panel(ghost, Theme.colors.cardHover, Theme.colors.accent)
        ghost.text = W.Text(ghost, "GameFontHighlight")
        ghost.text:SetPoint("LEFT", 8, 0)
        ghost.text:SetPoint("RIGHT", -8, 0)
        ghost:SetScript("OnUpdate", function(self)
            local x, y = cursorUI()
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - self.dx, y + self.dy)
            Board:ShowDropLine()
        end)
    end
    local x, y = cursorUI()
    ghost.dx = x - (cardFrame:GetLeft() or x)
    ghost.dy = (cardFrame:GetTop() or y) - y
    ghost:SetSize(cardFrame:GetWidth(), 28)
    ghost.text:SetText(cardFrame.card.title)
    ghost:Show()
    cardFrame:SetAlpha(0.35)
    drag = { frame = cardFrame, card = cardFrame.card, board = board }
    ns.Log:Debug("ui", "Dragging '%s'", cardFrame.card.title)
end

function Board:ShowDropLine()
    for _, col in ipairs(columnFrames) do col.dropLine:Hide() end
    local col, index = self:DropTarget()
    if not col then return end
    local slot = col.slots[index]
    local y = slot and slot.top or (col.slots[#col.slots] and (col.slots[#col.slots].top + col.slots[#col.slots].height + Board.CARD_GAP)) or 0
    col.dropLine:ClearAllPoints()
    col.dropLine:SetPoint("TOPLEFT", col.content, "TOPLEFT", 0, -y + Board.CARD_GAP / 2)
    col.dropLine:SetPoint("RIGHT", col.content, "RIGHT", 0, 0)
    col.dropLine:Show()
end

function Board:EndDrag()
    if not drag then return end
    local current = drag
    drag = nil
    if ghost then ghost:Hide() end
    for _, col in ipairs(columnFrames) do col.dropLine:Hide() end
    current.frame:SetAlpha(1)
    local col, index = self:DropTarget()
    if col and col.column then
        self:Drop(current.board, current.card, col.column.id, index, col.cards)
    end
    self:Layout()
end

-- Converts a visible (filtered) index to an index in the full column order.
function Board:Drop(board, card, columnID, visibleIndex, visibleCards)
    local order = board.order[columnID]
    local index
    local before = visibleCards and visibleCards[visibleIndex]
    if before and before.id ~= card.id then
        index = Util.IndexOf(order, before.id)
    elseif before and before.id == card.id then
        return false -- dropped onto itself
    end
    return DB:MoveCard(board, card.id, columnID, index)
end

function Board:IsDragging()
    return drag ~= nil
end

-------------------------------------------------------------------------------
-- Prompt (single-line text input dialog)
-------------------------------------------------------------------------------
local prompt
function Board:Prompt(title, value, onAccept)
    if not prompt then
        prompt = CreateFrame("Frame", "TaskboardPrompt", UIParent, "BackdropTemplate")
        prompt:SetSize(300, 90)
        prompt:SetPoint("CENTER", 0, 120)
        prompt:SetFrameStrata("DIALOG")
        Theme.Panel(prompt, Theme.colors.window, Theme.colors.windowBorder)
        prompt.title = W.Text(prompt, "GameFontNormal")
        prompt.title:SetPoint("TOPLEFT", 12, -10)
        prompt.box = W.EditBox(prompt, 276, 22, "")
        prompt.box:SetPoint("TOP", 0, -32)
        prompt.ok = W.Button(prompt, "OK", 80, 20, function() prompt.box:GetScript("OnEnterPressed")(prompt.box) end)
        prompt.ok:SetPoint("BOTTOMRIGHT", -12, 10)
        prompt.cancel = W.Button(prompt, "Cancel", 80, 20, function() prompt:Hide() end)
        prompt.cancel:SetPoint("RIGHT", prompt.ok, "LEFT", -6, 0)
        prompt.box:SetScript("OnEscapePressed", function() prompt:Hide() end)
        table.insert(UISpecialFrames, "TaskboardPrompt")
    end
    prompt.title:SetText(title)
    prompt.box:SetText(value or "")
    prompt.box:SetScript("OnEnterPressed", ns.Wrap("prompt accept", function(self)
        local text = Util.Trim(self:GetText())
        prompt:Hide()
        if text ~= "" then onAccept(text) end
    end))
    prompt:Show()
    prompt.box:SetFocus()
    prompt.box:HighlightText()
end

-------------------------------------------------------------------------------
-- Board menu, tags
-------------------------------------------------------------------------------
function Board:BoardMenu()
    local items = { { text = "Boards", title = true } }
    local current = activeBoard()
    for _, b in ipairs(DB:VisibleBoards()) do
        local label = b.name .. (b.scope == "character" and " (this character)" or b.scope == "shared" and (" (from " .. shortChar(b.shared and b.shared.from) .. ")") or "")
        items[#items + 1] = { text = label, checked = b == current, func = function() DB:SetActiveBoard(b) end }
    end
    items[#items + 1] = { text = "New board (all characters)", func = function()
        Board:Prompt("New board name", "", function(text) local b = DB:CreateBoard(text, "account") if b then DB:SetActiveBoard(b) end end)
    end }
    items[#items + 1] = { text = "New board (this character only)", func = function()
        Board:Prompt("New board name", "", function(text) local b = DB:CreateBoard(text, "character") if b then DB:SetActiveBoard(b) end end)
    end }
    if current then
        items[#items + 1] = { text = "Rename this board", disabled = DB:IsReadOnly(current), func = function()
            Board:Prompt("Rename board", current.name, function(text) DB:RenameBoard(current, text) end)
        end }
        items[#items + 1] = { text = "Share with group", disabled = DB:IsReadOnly(current), func = function() ns.Commands:Handle("share group") end }
        items[#items + 1] = { text = "Share with guild", disabled = DB:IsReadOnly(current), func = function() ns.Commands:Handle("share guild") end }
        if current.shared and current.shared.owner then
            items[#items + 1] = { text = "Stop sharing", func = function() ns.Sync:StopSharing(current) end }
        end
        items[#items + 1] = { text = "Export as text", func = function() ns:Fire("SHOW_EXPORT") end }
        items[#items + 1] = { text = "Import from text", func = function() ns:Fire("SHOW_IMPORT") end }
        items[#items + 1] = { text = "Show archived cards", func = function() Board:ArchiveMenu(current) end }
        items[#items + 1] = { text = "|cffff5a5aDelete this board|r", disabled = #DB:VisibleBoards() <= 1, func = function()
            W.Confirm("Delete the board \"" .. current.name .. "\" and all its cards?", function() DB:DeleteBoard(current) end)
        end }
    end
    W.Menu(nil, items)
end

function Board:ArchiveMenu(board)
    local items = { { text = "Archived (click to restore)", title = true } }
    for _, card in pairs(board.cards) do
        if card.archived then
            items[#items + 1] = { text = card.title, func = function() DB:UpdateCard(board, card, { archived = false }) end }
        end
        if #items > 25 then break end
    end
    if #items == 1 then items[#items + 1] = { text = "Nothing archived", disabled = true } end
    W.Menu(nil, items)
end

function Board:TagMenu()
    local board = activeBoard()
    if not board then return end
    local tags = {}
    for _, card in pairs(board.cards) do
        for _, t in ipairs(card.tags) do tags[t] = (tags[t] or 0) + 1 end
    end
    local items = { { text = "Filter by tag", title = true }, { text = "All cards", checked = Board.filter.tag == nil, func = function() Board:SetTag(nil) end } }
    local sorted = {}
    for t in pairs(tags) do sorted[#sorted + 1] = t end
    table.sort(sorted)
    for _, t in ipairs(sorted) do
        items[#items + 1] = { text = "#" .. t .. " (" .. tags[t] .. ")", checked = Board.filter.tag == t, func = function() Board:SetTag(t) end }
    end
    W.Menu(nil, items)
end

function Board:SetTag(tag)
    Board.filter.tag = tag
    tagButton:SetLabel(tag and ("#" .. tag) or "Tags")
    tagButton:SetActive(tag ~= nil)
    self:Layout()
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function savePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    ns.db.ui.board = { point = point, relPoint = relPoint, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight() }
end

function Board:Create()
    if frame then return frame end
    frame = CreateFrame("Frame", "TaskboardFrame", UIParent, "BackdropTemplate")
    self.frame = frame
    local pos = ns.db.ui.board or {}
    frame:SetSize(pos.w or 820, pos.h or 500)
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 40)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(600, 340, 1600, 1100)
    frame:EnableMouse(true)
    frame:Hide()
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder)
    table.insert(UISpecialFrames, "TaskboardFrame")

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    -- The drag strip must sit above the mouse-enabled window background;
    -- header buttons sit one level higher so they remain clickable.
    titleBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)

    local title = W.Text(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -8)
    Theme.Brand(title)

    boardButton = W.Button(frame, "Board", 150, 20, function() Board:BoardMenu() end, "Switch, create, share or export boards")
    boardButton:SetPoint("LEFT", title, "RIGHT", 12, 0)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local options = W.IconButton(frame, "Interface\\Buttons\\UI-OptionsButton", 16, function() ns:Fire("SHOW_OPTIONS") end, "Options")
    options:SetPoint("RIGHT", close, "LEFT", -4, 0)
    local logButton = W.Button(frame, "Log", 40, 18, function() ns:Fire("SHOW_LOG") end, { "Log and diagnostics", "Copy this into bug reports." })
    logButton:SetPoint("RIGHT", options, "LEFT", -6, 0)
    local examplesButton = W.Button(frame, "Examples", 76, 18, function() Board:ShowExamples() end)
    examplesButton:SetPoint("RIGHT", logButton, "LEFT", -6, 0)
    for _, button in ipairs({ boardButton, close, options, logButton, examplesButton }) do
        button:SetFrameLevel(titleBar:GetFrameLevel() + 1)
    end

    addBox = W.EditBox(frame, 300, 24, "Add a card: Get 20 Peacebloom #herbs !high   (shift-click items)", true)
    addBox:SetPoint("TOPLEFT", 12, -36)
    addBox:SetPoint("RIGHT", frame, "RIGHT", -310, 0)
    addBox:SetMaxLetters(400)
    addBox:SetScript("OnEnterPressed", ns.Wrap("quick add", function(self)
        local text = self:GetText()
        if Util.Trim(text) == "" then self:ClearFocus() return end
        local card, err = ns.Commands:Add(text)
        if card then self:SetText("") else ns.Print("|cffff5555%s|r", err) end
    end))
    -- Attached after the submit handler so Enter first accepts a location.
    W.LocationSuggestions(addBox)
    local addButton = W.Button(frame, "Add", 50, 24, function() addBox:GetScript("OnEnterPressed")(addBox) end)
    addButton:SetPoint("LEFT", addBox, "RIGHT", 4, 0)

    searchBox = W.EditBox(frame, 120, 24, "Search")
    searchBox:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        self:Refresh()
        Board.filter.text = Util.Lower(Util.Trim(self:GetText()))
        Board:Layout()
    end)
    tagButton = W.Button(frame, "Tags", 50, 24, function() Board:TagMenu() end, "Filter by tag")
    tagButton:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
    mineCheck = W.Check(frame, "Mine", function(checked)
        ns.db.settings.onlyMine = checked
        Board:Layout()
    end, { "Only this character", "Hide cards that belong to your other characters." })
    mineCheck:SetPoint("LEFT", tagButton, "RIGHT", 4, 0)

    columnsViewport = CreateFrame("ScrollFrame", nil, frame)
    columnsViewport:SetPoint("TOPLEFT", 12, -68)
    columnsViewport:SetPoint("BOTTOMRIGHT", -12, 48)
    columnsHost = CreateFrame("Frame", nil, columnsViewport)
    columnsHost:SetSize(796, 384)
    columnsViewport:SetScrollChild(columnsHost)
    horizontalScroll = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    horizontalScroll:SetPoint("BOTTOMLEFT", 12, 31)
    horizontalScroll:SetPoint("BOTTOMRIGHT", -12, 31)
    horizontalScroll:SetHeight(12)
    horizontalScroll:SetOrientation("HORIZONTAL")
    horizontalScroll:SetMinMaxValues(0, 0)
    horizontalScroll:SetValue(0)
    horizontalScroll:SetThumbTexture(Theme.WHITE)
    horizontalScroll:GetThumbTexture():SetSize(40, 10)
    horizontalScroll:GetThumbTexture():SetVertexColor(unpack(Theme.colors.accent))
    Theme.Panel(horizontalScroll, Theme.colors.input, Theme.colors.panelBorder)
    horizontalScroll:SetScript("OnValueChanged", ns.Wrap("horizontal board scroll", function(_, value)
        columnsViewport:SetHorizontalScroll(value)
    end))
    W.Tooltip(horizontalScroll, "Scroll sideways to reach more columns")

    footer = W.Text(frame, "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", 14, 10)

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() savePosition() Board:Layout() end)

    frame:SetScript("OnShow", function() mineCheck:SetChecked(ns.db.settings.onlyMine) Board:Layout() end)
    frame:SetScript("OnSizeChanged", function() Board:RequestLayout() end)
    frame:SetScript("OnHide", function()
        if drag then Board:EndDrag() end
        W.HideMenu()
    end)
    return frame
end

function Board:Toggle()
    self:Create()
    frame:SetShown(not frame:IsShown())
end

function Board:Show()
    self:Create()
    frame:Show()
end

function Board:FocusAdd()
    self:Show()
    addBox:SetFocus()
end

function Board:IsShown()
    return frame and frame:IsShown()
end

function Board:OnLogin()
    ns:On("TOGGLE_BOARD", function() Board:Toggle() end)
    ns:On("QUICK_ADD", function() Board:FocusAdd() end)
    for _, message in ipairs({ "BOARD_CHANGED", "BOARD_REFRESH", "BOARDS_CHANGED", "PROGRESS_CHANGED" }) do
        ns:On(message, function() Board:RequestLayout() end)
    end
end

-- Test and debugging access.
function Board:Internals()
    return { frame = frame, columns = columnFrames, cards = usedCards, addBox = addBox, searchBox = searchBox,
             horizontalScroll = horizontalScroll, viewport = columnsViewport }
end

