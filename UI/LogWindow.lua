-- Copyable text window used for the log, diagnostics, export and import.
local _, ns = ...
local Util, DB, Theme, W = ns.Util, ns.DB, ns.Theme, ns.Widgets

local LogWindow = ns:NewModule("LogWindow")
local frame, box, scroll, titleText, buttons
local mode = "log"        -- log | diag | export | import
local minLevel = 1

local function setText(text, editable)
    frame.editable = editable
    frame.text = text
    box:SetText(text)
    box:SetCursorPosition(0)
end

function LogWindow:Create()
    if frame then return end
    frame = CreateFrame("Frame", "TaskboardLogWindow", UIParent, "BackdropTemplate")
    frame:SetSize(680, 420)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder, true)
    table.insert(UISpecialFrames, "TaskboardLogWindow")

    titleText = W.Text(frame, "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 12, -10)
    local close = W.CloseButton(frame)
    close:SetPoint("TOPRIGHT", 2, 2)

    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", 10, -32)
    bg:SetPoint("BOTTOMRIGHT", -10, 40)
    Theme.Panel(bg, Theme.colors.input, Theme.colors.inputBorder)
    scroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    Theme.Text(box, "ChatFontNormal")
    box:SetWidth(620)
    box:SetMaxLetters(0)
    scroll:SetScrollChild(box)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Hide() end)
    -- Read-only modes: typing is undone, but selecting and copying works.
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not frame.editable then self:SetText(frame.text or "") end
    end)
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() box:SetFocus() end)

    buttons = {}
    local function button(key, label, width, fn, tooltip)
        local b = W.Button(frame, label, width, 22, fn, tooltip)
        buttons[key] = b
        return b
    end
    button("log", "Log", 60, function() LogWindow:ShowLog() end)
    button("diag", "Diagnostics", 90, function() LogWindow:ShowDiag() end)
    button("level", "All levels", 90, function()
        minLevel = minLevel % 4 + 1
        LogWindow:ShowLog()
    end, "Cycle the minimum level shown")
    button("select", "Select all", 80, function() box:SetFocus() box:HighlightText() end, "Then press Ctrl+C to copy")
    button("clear", "Clear log", 80, function() ns.Log:Clear() LogWindow:ShowLog() end)
    button("import", "Import", 80, function() LogWindow:DoImport() end)
    buttons.log:SetPoint("BOTTOMLEFT", 10, 10)
    buttons.diag:SetPoint("LEFT", buttons.log, "RIGHT", 6, 0)
    buttons.level:SetPoint("LEFT", buttons.diag, "RIGHT", 6, 0)
    buttons.clear:SetPoint("LEFT", buttons.level, "RIGHT", 6, 0)
    buttons.select:SetPoint("BOTTOMRIGHT", -10, 10)
    buttons.import:SetPoint("RIGHT", buttons.select, "LEFT", -6, 0)

    ns:On("LOG_ADDED", function()
        if frame:IsShown() and mode == "log" and not box:HasFocus() then LogWindow:ShowLog() end
    end)
end

local function setMode(m)
    mode = m
    local logButtons = m == "log" or m == "diag"
    buttons.log:SetShown(logButtons)
    buttons.diag:SetShown(logButtons)
    buttons.level:SetShown(m == "log")
    buttons.clear:SetShown(m == "log")
    buttons.import:SetShown(m == "import")
    buttons.select:SetShown(m ~= "import")
    buttons.log:SetActive(m == "log")
    buttons.diag:SetActive(m == "diag")
end

function LogWindow:ShowLog()
    self:Create()
    setMode("log")
    titleText:SetText("Taskboard log")
    buttons.level:SetLabel(minLevel == 1 and "All levels" or (ns.Log.NAMES[minLevel] .. "+"))
    local lines = {}
    for _, e in ipairs(ns.Log:GetEntries(minLevel)) do lines[#lines + 1] = ns.Log:FormatEntry(e) end
    if #lines == 0 then lines[1] = "(empty)" end
    setText(table.concat(lines, "\n"), false)
    frame:Show()
    -- Newest lines at the bottom: scroll there.
    ns.After(0, "log scroll", function() scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end)
end

function LogWindow:ShowDiag(lines)
    self:Create()
    setMode("diag")
    titleText:SetText("Taskboard diagnostics (paste this into bug reports)")
    lines = lines or ns.Diagnostics:Report()
    local recent = {}
    for _, e in ipairs(ns.Log:GetEntries(3, 20)) do recent[#recent + 1] = ns.Log:FormatEntry(e) end
    local text = table.concat(lines, "\n") .. "\n\nRecent warnings and errors:\n" .. (#recent > 0 and table.concat(recent, "\n") or "(none)")
    setText(text, false)
    frame:Show()
end

function LogWindow:ShowExport()
    self:Create()
    setMode("export")
    local board = DB:GetActiveBoard()
    titleText:SetText("Export \"" .. board.name .. "\": copy this text")
    local copy = Util.DeepCopy(board)
    copy.shared = nil
    for _, card in pairs(copy.cards) do card.progress = nil end
    local text, err = ns.Serialize.Export(copy)
    setText(text or ("Export failed: " .. tostring(err)), false)
    frame:Show()
    box:SetFocus()
    box:HighlightText()
end

function LogWindow:ShowImport()
    self:Create()
    setMode("import")
    titleText:SetText("Import a board: paste the export text, then click Import")
    setText("", true)
    frame:Show()
    box:SetFocus()
end

function LogWindow:DoImport()
    local data, err = ns.Serialize.Import(box:GetText())
    if not data then ns.Print("|cffff5555Import failed: %s|r", tostring(err)) return end
    local board = DB.NormalizeBoard(data)
    if not board then ns.Print("|cffff5555Import failed: not a board|r") return end
    local target = DB:BoardForCharacter(ns.CharKey())
    if not target then target = DB:CreateBoard("My Tasks", "character") end
    if Util.Count(target.cards) + Util.Count(board.cards) > DB.LIMITS.cards then
        ns.Print("Import failed: this character's board would exceed the card limit.")
        return
    end
    local count = 0
    for _, col in ipairs(board.columns) do
        local dest = col.role and DB:ColumnByRole(target, col.role) or nil
        if not dest then
            for _, candidate in ipairs(target.columns) do
                if not candidate.role and candidate.name == col.name then dest = candidate; break end
            end
        end
        if not dest and #target.columns < DB.LIMITS.columns then dest = DB:AddColumn(target, col.name) end
        if not dest then dest = DB:ColumnByRole(target, "doing") end
        for _, id in ipairs(board.order[col.id] or {}) do
            local card = board.cards[id]
            if card then
                card.char, card.progress, card.auto = ns.CharKey(), nil, {}
                for _, entry in ipairs(ns.Goals.CardGoals(card)) do
                    entry.goal.baseline, entry.goal.baselineBank = nil, nil
                    entry.owner.progress = nil
                end
                local added = DB:AddCard(target, card, dest.id)
                if added then count = count + 1 end
            end
        end
    end
    DB:SetActiveBoard(target)
    ns.Log:Info("db", "Imported %d card(s) from '%s'", count, board.name)
    ns.Print("Imported %d card(s) into %s.", count, target.name)
    ns.Engine:MarkAll()
    frame:Hide()
end

function LogWindow:OnLogin()
    ns:On("SHOW_LOG", function() LogWindow:ShowLog() end)
    ns:On("DIAG_REPORT", function(lines) LogWindow:ShowDiag(lines) end)
    ns:On("SHOW_EXPORT", function() LogWindow:ShowExport() end)
    ns:On("SHOW_IMPORT", function() LogWindow:ShowImport() end)
end

function LogWindow:Internals()
    return { frame = frame, box = box, mode = mode }
end

