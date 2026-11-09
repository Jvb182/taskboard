-- Slash commands: /tb, /taskboard, /todo
local _, ns = ...
local Util, DB = ns.Util, ns.DB

local Commands = ns:NewModule("Commands")

local HELP = {
    "|cff4fc3f7Taskboard|r commands:",
    "  /tb  - open or close the board",
    "  /tb add <text>  (or /todo <text>) - add a card, e.g. Get 20 Peacebloom #herbs !high",
    "      goals: 20 Peacebloom, [item link] x5, save 100g, reach level 40, Herbalism 150,",
    "      Honored with Stormwind, [quest link]   extras: #tag !high @Ironforge @bank *daily >doing ; subtask",
    "  /tb list - list your open cards",
    "  /tb done <number or text> - mark a card done",
    "  /tb tracker - show or hide the on-screen tracker",
    "  /tb board <name> - switch boards; use Name (Character-Realm) for duplicate names",
    "  /tb share party|raid|guild - share the current board",
    "  /tb export / import - copy a board as text",
    "  /tb log [n] | log show | log clear  - recent log lines",
    "  /tb debug on|off - verbose logging",
    "  /tb diag - diagnostics report     /tb selftest - in-game checks",
    "  /tb options - settings",
}

-- Adds a card from quick-add text to the active board. Returns card or nil, err.
function Commands:Add(text)
    text = Util.Trim(text)
    if text == "" then return nil, "type something after /tb add" end
    local board = DB:GetActiveBoard()
    if not board then return nil, "no board" end
    if DB:IsReadOnly(board) then return nil, "this board is shared with you and is read-only" end
    local spec, warnings = ns.Parser.Parse(text)
    local card, err = DB:AddCard(board, spec)
    if not card then return nil, err end
    local goalText = card.goal and (" - tracking: " .. ns.Parser.Describe(card.goal)) or ""
    ns.Print("Added |cffffffff%s|r%s", card.title, goalText)
    for _, w in ipairs(warnings) do ns.Print("|cffffc04d%s|r", w) end
    return card
end

local function openCards()
    local list = {}
    for _, entry in ipairs(DB:AllCards(false)) do
        if DB:CardRole(entry.board, entry.card) ~= "done" and DB:GetActiveBoard() == entry.board then
            list[#list + 1] = entry
        end
    end
    return list
end

function Commands:List()
    local list = openCards()
    if #list == 0 then ns.Print("No open cards. Add one with /tb add <text>.") return end
    for i, entry in ipairs(list) do
        local card = entry.card
        local col = DB:Column(entry.board, card.column)
        local progress = card.progress and (" |cffaaaaaa" .. card.progress.text .. "|r") or ""
        ns.Print("%d. [%s] %s%s", i, col and col.name or "?", card.title, progress)
    end
end

function Commands:Done(arg)
    local list = openCards()
    local n = tonumber(arg)
    local target = n and list[n]
    if not target then
        local want = Util.Lower(arg)
        for _, entry in ipairs(list) do
            if want ~= "" and string.find(Util.Lower(entry.card.title), want, 1, true) then target = entry break end
        end
    end
    if not target then ns.Print("No open card matches '%s'. Try /tb list.", tostring(arg)) return end
    local ok, err = DB:MoveCard(target.board, target.card.id, DB:ColumnByRole(target.board, "done").id, 1)
    if not ok then ns.Print("Cannot complete card: %s", err or "card unavailable") return end
    ns.Print("Done: %s", target.card.title)
end

function Commands:Board(name)
    name = Util.Trim(name)
    local function label(b)
        local owner = b.owner or (b.shared and b.shared.from)
        return owner and (b.name .. " (" .. owner .. ")") or b.name
    end
    if name == "" then
        for _, b in ipairs(DB:VisibleBoards()) do
            ns.Print("%s%s [%s] (%d cards)", b == DB:GetActiveBoard() and "> " or "  ", label(b), b.id, Util.Count(b.cards))
        end
        return
    end
    local matches = {}
    for _, b in ipairs(DB:VisibleBoards()) do
        if Util.Lower(b.name) == Util.Lower(name) or Util.Lower(label(b)) == Util.Lower(name) or b.id == name then
            matches[#matches + 1] = b
        end
    end
    if #matches == 1 then
        DB:SetActiveBoard(matches[1])
        ns.Print("Switched to %s", label(matches[1]))
        return
    elseif #matches > 1 then
        ns.Print("More than one board matches '%s'. Use the full Name (Character-Realm) or board ID from /tb board.", name)
        return
    end
    ns.Print("No board named '%s'. Each character has one board; use /tb board to list them.", name)
end

function Commands:Handle(msg)
    msg = Util.Trim(msg)
    local cmd, rest = string.match(msg, "^(%S+)%s*(.-)$")
    cmd = Util.Lower(cmd or "")
    ns.Log:Debug("commands", "/tb %s", msg)

    if cmd == "" then
        ns:Fire("TOGGLE_BOARD")
    elseif cmd == "add" or cmd == "a" or cmd == "new" then
        local _, err = self:Add(rest)
        if err then ns.Print("|cffff5555%s|r", err) end
    elseif cmd == "list" or cmd == "ls" then
        self:List()
    elseif cmd == "done" then
        self:Done(rest)
    elseif cmd == "tracker" then
        ns.db.settings.trackerShown = not ns.db.settings.trackerShown
        ns:Fire("TRACKER_SETTINGS")
        ns.Print("Tracker %s", ns.db.settings.trackerShown and "shown" or "hidden")
    elseif cmd == "board" or cmd == "boards" then
        self:Board(rest)
    elseif cmd == "share" then
        local ok, info = ns.Sync:ShareBoard(DB:GetActiveBoard(), rest ~= "" and rest or nil)
        if ok then ns.Print("Sharing this board with your %s.", Util.Lower(info)) else ns.Print("|cffff5555Can't share: %s|r", info) end
    elseif cmd == "unshare" then
        ns.Sync:StopSharing(DB:GetActiveBoard())
    elseif cmd == "export" then
        ns:Fire("SHOW_EXPORT")
    elseif cmd == "import" then
        ns:Fire("SHOW_IMPORT")
    elseif cmd == "log" then
        local sub = Util.Lower(rest)
        if sub == "show" then
            ns:Fire("SHOW_LOG")
        elseif sub == "clear" then
            ns.Log:Clear()
        else
            local n = tonumber(rest) or 15
            for _, e in ipairs(ns.Log:GetEntries(1, n)) do DEFAULT_CHAT_FRAME:AddMessage(ns.Log:FormatEntry(e, true)) end
        end
    elseif cmd == "debug" then
        local on = Util.Lower(rest) ~= "off" and (Util.Lower(rest) == "on" or not ns.db.settings.debug)
        ns.Log:SetDebug(on)
        ns.Print("Debug logging %s", on and "on" or "off")
    elseif cmd == "diag" or cmd == "diagnostics" then
        local lines = ns.Diagnostics:Report()
        for _, line in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("|cff8ecfff" .. line .. "|r") end
        ns:Fire("DIAG_REPORT", lines)
    elseif cmd == "selftest" then
        local passed, failed, lines = ns.Diagnostics:SelfTest()
        for _, line in ipairs(lines) do
            if string.sub(line, 1, 4) == "FAIL" then DEFAULT_CHAT_FRAME:AddMessage("|cffff5555" .. line .. "|r") end
        end
        ns.Print("Self-test: |cff55ff55%d passed|r, %s%d failed|r", passed, failed > 0 and "|cffff5555" or "|cff55ff55", failed)
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        ns:Fire("SHOW_OPTIONS")
    elseif cmd == "refresh" then
        ns.Engine:MarkAll()
    elseif cmd == "help" or cmd == "?" then
        ns:Fire("SHOW_HELP")
        for _, line in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage(line) end
    else
        -- Anything else is treated as a new card: "/tb Get 20 Peacebloom".
        local _, err = self:Add(msg)
        if err then ns.Print("|cffff5555%s|r", err) end
    end
end

function Commands:OnInit()
    ns.Widgets.InstallChatLocations()
    SLASH_TASKBOARD1, SLASH_TASKBOARD2 = "/tb", "/taskboard"
    SlashCmdList.TASKBOARD = function(msg) ns.Safe("slash /tb", Commands.Handle, Commands, msg) end
    SLASH_TASKBOARDTODO1 = "/todo"
    SlashCmdList.TASKBOARDTODO = function(msg)
        ns.Safe("slash /todo", function()
            if Util.Trim(msg) == "" then ns:Fire("TOGGLE_BOARD") else Commands:Handle("add " .. msg) end
        end)
    end
    BINDING_HEADER_QUESTBOARD = "Taskboard"
    BINDING_NAME_QUESTBOARD_TOGGLE = "Open or close the board"
    BINDING_NAME_QUESTBOARD_TRACKER = "Show or hide the tracker"
    BINDING_NAME_QUESTBOARD_QUICKADD = "Quick add a card"
end

-- Key binding entry points (Bindings.xml).
function ns:ToggleBoard() ns:Fire("TOGGLE_BOARD") end
function ns:ToggleTracker() Commands:Handle("tracker") end
function ns:QuickAdd() ns:Fire("QUICK_ADD") end

