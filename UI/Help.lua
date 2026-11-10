-- In-game reference. Examples are displayed as text and never create tasks.
local _, ns = ...
local W, Theme = ns.Widgets, ns.Theme
local Help = ns:NewModule("Help")
Help.SECTIONS = {
    { id = "quick", title = "Quick Add", entries = {
        { "h", "Start here" },
        { "p", "Open the board with /tb, /taskboard, or the minimap button. Type in Quick Add and press Enter, or use /tb add followed by your task. /todo also adds tasks. Ordinary text creates a manual task." },
        { "e", "Visit the auction house" },
        { "e", "/tb add Prepare for tonight" },
        { "h", "Items and other live goals" },
        { "p", "Focus Quick Add, then shift-click an item or quest link. Keep the quantity outside the item link. Each task and each subtask can have one live goal; use subtasks to combine several goals." },
        { "e", "get 17 Silverleaf" },
        { "e", "20 Peacebloom" },
        { "e", "[shift-click an item here] x17" },
        { "e", "save 10g 50s" },
        { "e", "reach level 40" },
        { "e", "Herbalism 150" },
        { "e", "Honored with Stormwind" },
        { "e", "quest: The Defias Brotherhood" },
        { "p", "The bracketed item example is a placeholder: insert a real link. Typed item names work too; unknown names can stay pending until matching loot identifies them. If a pending subtask is not a real item, click its checkbox and confirm to finish it manually. For a whole-card item goal, use Clear in the card editor to remove tracking. A quest goal completes when the quest is turned in, not merely ready to turn in." },
        { "h", "Tags, priority and starting status" },
        { "e", "Organize bags #chores !low" },
        { "e", "Prepare potions #alchemy !med >doing" },
        { "e", "Repair equipment !high >todo" },
        { "e", "Urgent pickup !urgent >wip" },
        { "e", "Finished preparations >done" },
        { "p", "Use #tag to group tasks. Priority is !low (!l, !1), !med (!medium, !m, !2), or !high (!h, !3, !urgent). Start in >todo, >doing (also >progress or >wip), or >done. Drag cards between board columns to change their status later." },
        { "h", "Locations and NPC reminders" },
        { "p", "Type @ plus a letter to suggest zones and towns, not NPC names. @g narrows to @go for Goldshire. Suggestions work in Quick Add and while typing a /tb or /todo task in chat. Click a result or use Up/Down and Tab/Enter. Enter first accepts the location; press it again to add the task. Scroll for more matches, or Escape to dismiss. Multiword names are quoted automatically. You can type a missing location manually. In the card editor's Remind me field, type the place name without @ to get suggestions." },
        { "e", "Buy vials @Goldshire" },
        { "e", 'Buy supplies @"Stormwind City"' },
        { "h", "Supported NPC type tags" },
        { "p", "NPC tags work by type: @bank, @vendor (also @merchant), @mail (also @mailbox), @ah (also @auction or @auctionhouse), and @trainer. Bank, merchant, mail, auction and trainer tags trigger when the matching window opens. Mail can also remind near a mailbox Taskboard has learned." },
        { "e", "Sort supplies @bank" },
        { "e", "Buy vials @vendor" },
        { "e", "Buy vials @merchant" },
        { "e", "Check mail @mail" },
        { "e", "Send herbs @mailbox" },
        { "e", "List auctions @ah" },
        { "e", "List auctions @auction" },
        { "e", "List auctions @auctionhouse" },
        { "e", "Learn new skills @trainer" },
        { "p", "Specific NPCs are not supported. Any other @word is treated as a location name: @innkeeper will not trigger when you talk to an innkeeper. Use Talk to innkeeper @Goldshire for a reminder on entering Goldshire, or make Talk to innkeeper a manual task. Sending items at @mailbox stays manual; only supported check-mail tasks can auto-complete on opening mail." },
        { "p", "Each task has one reminder destination: either a location or an NPC type. If you type several @ tokens, the last parsed destination wins. Use separate tasks for separate destinations." },
        { "h", "Repeating tasks" },
        { "e", "Check auctions *daily" },
        { "e", "Visit the trainer @trainer *weekly" },
        { "p", "Use *daily or *weekly to repeat a task at the server reset. Without either token, the task never repeats. Change Never, Daily or Weekly in the card editor. See Tracking & reminders for inventory baselines and reset rules." },
        { "h", "Subtasks" },
        { "e", "Alchemy prep; 20 Peacebloom; 20 Silverleaf; buy vials" },
        { "e", "Alchemy prep #herbs !high @bank *daily; 20 Peacebloom; buy vials" },
        { "p", "A semicolon starts a subtask. Live goals update their checkboxes; manual subtasks can be checked off. Click a subtask's text in the card editor to change it; Enter saves and Escape cancels. Tags, reminder, repeat and starting-status tokens apply to the whole task, even when entered after a semicolon." },
    } },
    { id = "tracking", title = "Tracking & reminders", entries = {
        { "h", "Progress and automatic movement" },
        { "p", "Taskboard tracks items, current money, level/XP, profession skill, reputation and quest turn-ins. With automatic movement enabled, progress starts a task and completing all its goals/subtasks moves it to Done. Goals already met can complete immediately when added." },
        { "e", "get 17 Silverleaf: 15 owned means 15/17; two more completes it." },
        { "p", "Money goals track current money, not lifetime earnings. Finished tasks stay in Done if you later spend or sell their items. If you manually move a completed task out of Done, it waits until its goal becomes incomplete before automatically completing again. Manual tasks without goals must be moved or marked done by you." },
        { "h", "Bank counting" },
        { "p", "Both the task's Count items in the bank checkbox and the General bank-counting setting must be enabled. Counts come from the game client; Taskboard does not keep a separate bank inventory cache. Availability away from the bank depends on the client. This does not scan other characters' or guild inventories." },
        { "h", "Daily and weekly tasks" },
        { "p", "Repeating tasks reset at the server's daily or weekly reset. Daily or Weekly appears on the board card and on-screen tracker. Saved boards for offline characters are reset too; archived tasks are left alone. Missing a period breaks the task's streak." },
        { "p", "Repeating item goals default to net inventory gained above a starting amount, not total loot. Spending or selling reduces that gain. Baselines survive reloads; an offline character gets its new baseline at the next login. Changing bank-counting settings starts a fresh baseline." },
        { "e", "Hold 15 Silverleaf, then add get 17 Silverleaf *daily: gain 17 more." },
        { "p", "To count current stock instead, uncheck Items: collect extra each period (net gain) in the editor. After reset, a stock goal must drop below its target before it can automatically complete again." },
        { "h", "Arrival and NPC reminders" },
        { "p", "@Goldshire reminds you each time you enter a matching zone or subzone. Leave and return to get another popup; duplicate zone events while you stay there do not repeat it. Matching is case-insensitive and accepts a name prefix. Arrival does not complete a task, move it, or limit where its goal counts. Reminders apply to unfinished, unarchived tasks evaluated by your character." },
        { "p", "Plain Mail, Mailbox, Check mail, Check mailbox, Open mail and Visit the mailbox tasks automatically get a Mail reminder, without an @ token. Change it or choose Off in the editor. Bank, vendor, auction house and trainer reminders trigger when their windows open. Taskboard learns mailbox spots when you open them; on later visits, mail tasks remind you within 35 yards and pulse until you move more than 50 yards away. With automatic completion enabled, opening mail completes these plain mail-check tasks without goals or subtasks; other mail tasks stay open. Smart reminders list missing goal items at the auction house and goal items stored in your bank." },
        { "p", "The editor's zone field and Here button also attach reminders. Map pins are separate: Pin my location saves coordinates; Show on map sets a waypoint. A pin alone is not an arrival reminder." },
        { "h", "On-screen tracker" },
        { "p", "Location tasks can pulse gently while you are in their matching zone or subzone. They appear at the top even when still in To Do; the pulse stops when you leave or finish/archive the task. General > Tracker: show and pulse location tasks while nearby controls this independently of arrival popups. Hiding the tracker or hiding it in combat still takes priority." },
        { "p", "The tracker automatically lists In Progress tasks and tasks marked Show in tracker. Unchecking Show in tracker does not hide an In Progress task. Done and archived tasks are excluded. Click a tracker task to open its editor." },
        { "e", "/tb tracker - hide or show the whole tracker" },
        { "p", "To include manual To Do tasks such as Buy vials @Goldshire, enable Tracker: include all open tasks in General settings, or right-click the tracker header and choose Show all open tasks. Done, archived and other characters' tasks remain excluded. Scroll the tracker to reach tasks beyond its visible rows; the header shows your position." },
        { "p", "You can hide the tracker and still open the board with /tb or the minimap. Click the tracker header to collapse it; drag it to move. Right-click its header to open the board, lock its position or hide it. Right-click a tracker task for its card menu. General settings can hide it in combat. Preferences persist across reloads." },
        { "h", "Progress feedback and statistics" },
        { "p", "Progress messages show counts as goals advance. Completion/reminder popups and sounds have separate controls. The board footer summarizes completions today and this week, your day streak and total completions." },
    } },
    { id = "settings", title = "Settings & sharing", entries = {
        { "h", "Boards, cards and layout" },
        { "p", "Board settings > Simple mode (To Do / Done) is saved separately for each character's board. Standard is the default. Switching to Simple moves tasks from In Progress and custom columns to To Do while preserving their progress. The old column names are kept for switching back, but old task positions are not restored. New custom columns require Standard mode." },
        { "p", "Board settings > Show completed hides or reveals the Done column without deleting tasks or completion history. Simple mode with Show completed off is a single To Do list. You can still complete tasks through the editor or card menu. Live goals, reminders, subtasks and automatic completion continue working; automatic starting does not move Simple-mode tasks. The tracker includes your open Simple-mode tasks, unless you hide the tracker." },
        { "p", "Closing the main board also closes Settings, Help, the color picker and the card editor. Focused edits are saved before the editor closes. Reopening the board leaves these extra windows closed until you open them again." },
        { "p", "Drag the title or empty top bar to move the main board; use the bottom-right grip to resize it. Its position and size are saved. The card editor follows the board's height as you resize, including when opened from the tracker. Its fields stay scrollable. Scroll the board sideways when extra columns do not fit." },
        { "p", "Each character has one board, and every character on your account can switch to the others' boards. Click the board name at the top to see and switch between all your character and received shared boards. Board settings beside it handles Simple mode, Show completed, rename, sharing, archive, export, import and deletion for the selected board. Existing local boards are merged by card owner on upgrade; cards and their status are kept. Search filters text, Tags filters by tag, and Mine hides cards belonging to other characters." },
        { "e", "/tb board - list boards; /tb board Name - switch to an existing board" },
        { "p", "Drag cards between columns or reorder them. Right-click a card to edit, move, duplicate, archive or delete it. The editor changes title, notes, goals, subtasks, tags, priority, reminder, repeat, tracker and map pin settings. Shared cards have editing restrictions." },
        { "p", "Click a column header and choose Move column left or Move column right to rearrange your board. Column order is saved with that character's board, and tasks stay in their columns. Hidden columns keep their saved slots. The same menu renames columns, adds columns or removes empty custom columns. Core To Do/In Progress/Done roles stay intact even when renamed or reordered. Done columns can archive their tasks. Board settings > Show archived cards lets you restore an archived task; deletion is permanent." },
        { "h", "General settings" },
        { "e", "/tb options" },
        { "p", "General controls automatic starting/completion, progress messages, popups, the sound master switch, reminders, smart reminders, bank counting, tracker visibility, hiding in combat, the minimap button, share offers and debug logging." },
        { "p", "Reset all data at the bottom of Settings asks for confirmation, then permanently clears every board, task, setting, statistic and diagnostic log on this account. Learned mailbox locations are kept. Taskboard reloads the UI with one empty board for the current character. Cancel leaves your data intact." },
        { "p", "Bind Open or close the board, Show or hide the tracker, and Quick add a card in the game's Key Bindings > AddOns. Left-click the minimap button for the board, right-click it for the tracker, or drag it to reposition it." },
        { "h", "Appearance" },
        { "p", "Choose Midnight, Warm leather, Forest, Arcane, High contrast, Classic stone, Classic leather, Quest parchment or Custom. Classic stone uses a dark Blizzard dialog background with light text. Classic leather and Quest parchment use warm quest parchment with dark text; the Classic skins retain Blizzard window borders. Accent choices are Sky, Gold, Mint, Rose and Lilac. Board and tracker opacity ranges from 35% to 100%; text stays opaque. Settings, editor, Help, logs and popup menus have a solid backing, even when classic artwork contains transparency." },
        { "p", "In Appearance, scroll to Custom theme colors and pick Background, Text, Border or Accent. Use the RGB sliders or type a six-digit hex color such as 4FC3F7. Apply selects the Custom theme and saves the color; Cancel or closing the picker discards the draft. Custom colors survive switching presets and reloading. Reset appearance restores Midnight, default custom colors, Sky accent and 96% panel opacity." },
        { "h", "Sounds" },
        { "p", "Repeat sound while nearby tasks flash is optional and off by default. Set it on the Sounds page and choose every 15, 30 or 60 seconds. It uses the Zone / NPC reminder sound, with one sound per interval even for several nearby tasks. Repeats stop when no eligible flashing task is visible, including after leaving, completion, hiding/collapsing the tracker or hiding it in combat. Play sounds, Zone/NPC reminders and location flashing must be enabled; setting the reminder sound to Off also silences repeats." },
        { "p", "Choose Off, Soft click, Chime, Quest complete, Page turn, Coin, Message or Alert separately for status changes, completed tasks, completed subtasks and reminders. Preview plays a choice without changing any tasks. The General Play sounds switch controls all of them; loudness follows the game's audio settings." },
        { "p", "Sounds can play with visual popups disabled. Reordering within a column and recurring resets are silent. Nearby repeated events may share one sound to avoid a burst of noise." },
        { "h", "Sharing boards" },
        { "e", "/tb share party" },
        { "e", "/tb share raid" },
        { "e", "/tb share guild" },
        { "e", "/tb unshare" },
        { "p", "Share the active board with group or guild members running Taskboard. Recipients accept an offer before importing; offers expire after one minute. General settings can reject offers. Each member tracks their own progress; recipients cannot edit the owner's tasks. The owner's cards show member progress." },
        { "p", "Stop sharing cancels pending outbound transfers. Temporary throttling is retried; terminal failures appear in chat/logs. Very large boards may exceed addon-message limits: use text export instead. Unsolicited whispers are not accepted as board shares." },
        { "h", "Text export and import" },
        { "e", "/tb export - copy the active board as text" },
        { "e", "/tb import - paste exported board text" },
        { "p", "Text import adds cards to your character's board and assigns live goals to your current character. The original board is not overwritten. Use Board settings for the same actions." },
        { "h", "Commands and troubleshooting" },
        { "e", "/tb list - list open tasks" },
        { "e", "/tb done 1 - finish the first listed task" },
        { "e", "/tb done Silverleaf - finish a matching task" },
        { "e", "/tb refresh - reevaluate live goals" },
        { "e", "/tb help - open this panel and print command help" },
        { "e", "/tb diag - client and addon diagnostic report" },
        { "e", "/tb selftest - run in-game checks" },
        { "e", "/tb log show - open a copyable log window" },
        { "e", "/tb log 20 - print the last 20 log entries" },
        { "e", "/tb log clear - clear the diagnostic log" },
        { "e", "/tb debug on - enable detailed logging; use off to disable" },
        { "h", "How to report a bug" },
        { "p", "On Taskboard's CurseForge project page, use Issues to report a bug. If Issues is unavailable, leave a project comment. If you received a test build directly, send the report to the person who shared it with you." },
        { "p", "Give the report a short title. List the exact steps to reproduce it, what you expected, what happened, and whether it happens every time. Include your Taskboard version and WoW Forever client build; mention other addons if the problem may be a conflict." },
        { "e", "Example: Open a mailbox with Check mail @mail in To Do; expected Done, but the card stayed in To Do." },
        { "p", "Run /tb diag to open Diagnostics, then click Select all and press Ctrl+C. Run /tb log show for the log; copy the relevant lines or use Select all and Ctrl+C. Add any Lua error text. Screenshots help with layout problems. Review copied text and images for private character names or task details before posting." },
        { "p", "The in-game self-test checks selected behaviors but cannot prove server delivery or every visual interaction. Please report a problem even if /tb selftest passes." },
        { "h", "Saved data and upgrades" },
        { "p", "Taskboard saves boards, settings and window positions through WoW's SavedVariables on logout/reload. When upgrading from Questboard, enable Taskboard and Taskboard - legacy data loader for the first login. Once migrated data survives a reload, the loader can be disabled. Existing key bindings are retained; commands use /tb, not the old shortcut." },
    } },
}

function Help:SearchEntries(query)
    query = string.lower((query or ""):match("^%s*(.-)%s*$"))
    local results = {}
    for _, section in ipairs(self.SECTIONS) do
        local group = {}
        local function flush()
            local match = string.lower(section.title):find(query, 1, true)
            for _, entry in ipairs(group) do
                if string.lower(entry[2]):find(query, 1, true) then match = true end
            end
            if match then
                results[#results + 1] = { "h", section.title .. " / " .. group[1][2] }
                for i = 2, #group do results[#results + 1] = group[i] end
            end
        end
        for _, entry in ipairs(section.entries) do
            if entry[1] == "h" and #group > 0 then flush(); group = {} end
            group[#group + 1] = entry
        end
        if #group > 0 then flush() end
    end
    if #results == 0 then results[1] = { "p", "No matching help topics. Try a shorter search or clear the search box." } end
    return results
end

function Help:Select(id)
    local section
    for _, item in ipairs(self.SECTIONS) do if item.id == id then section = item end end
    if not section then return end
    self.selected = id
    local query = self.search and self.search:GetText() or ""
    local searching = query:find("%S") ~= nil
    local entries = searching and self:SearchEntries(query) or section.entries
    for key, button in pairs(self.tabs) do button:SetActive(not searching and key == id) end
    self.scroll:SetVerticalScroll(0)
    local y = 0
    for i, entry in ipairs(entries) do
        local row = self.rows[i]
        if not row then row = W.Text(self.content); self.rows[i] = row end
        row:ClearAllPoints()
        local heading = entry[1] == "h"
        if heading and i > 1 then y = y + 10 end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(574)
        row:SetWordWrap(true)
        local font = heading and "GameFontNormalLarge" or "GameFontHighlight"
        row:SetFontObject(font)
        row:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", heading and 18 or 16, "")
        Theme.Text(row, font)
        row:SetText(entry[2])
        row:Show()
        y = y + row:GetStringHeight() + (entry[1] == "e" and 8 or 12)
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(y, 10))
end

function Help:Show(id)
    if not self.frame then
        local frame = CreateFrame("Frame", "TaskboardHelp", UIParent, "BackdropTemplate")
        self.frame, self.rows, self.tabs = frame, {}, {}
        frame:SetSize(630, 500)
        frame:SetPoint("CENTER", UIParent, "CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetToplevel(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function() frame:StartMoving() end)
        frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
        Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder, true)
        table.insert(UISpecialFrames, "TaskboardHelp")
        local title = W.Text(frame, "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("Taskboard Help")
        local close = W.CloseButton(frame)
        close:SetPoint("TOPRIGHT", 2, 2)
        for i, section in ipairs(self.SECTIONS) do
            local key = section.id
            local button = W.Button(frame, section.title, 194, 26, function()
                Help.search:SetText(""); Help:Select(key)
            end)
            button:SetPoint("TOPLEFT", 16 + (i - 1) * 200, -42)
            self.tabs[key] = button
        end
        self.scroll, self.content = W.Scroll(frame)
        self.scroll:SetPoint("TOPLEFT", 16, -116)
        self.scroll:SetPoint("BOTTOMRIGHT", -34, 16)
        self.content:SetWidth(574)
        self.search = W.EditBox(frame, 488, 26, "Search all help and examples...")
        self.search:SetPoint("TOPLEFT", 16, -78)
        self.search:HookScript("OnTextChanged", function() Help:Select(Help.selected or "quick") end)
        self.search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
        local clear = W.Button(frame, "Clear", 86, 26, function() Help.search:SetText("") end)
        clear:SetPoint("TOPLEFT", 514, -78)
        frame:SetScript("OnHide", function() Help.search:ClearFocus() end)
    end
    -- Keep board-launched Help in the board's window tree so raising or
    -- interacting with the board cannot strand its Help dialog behind it.
    -- Slash-command Help still works independently when the board is closed.
    local board = ns.Board and ns.Board.frame
    local parent = board and board:IsShown() and board or UIParent
    self.frame:SetParent(parent)
    self.frame:SetFrameStrata("DIALOG")
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 20)
    self.frame:Show()
    self.frame:Raise()
    self:Select(id or self.selected or "quick")
end

function Help:OnLogin()
    ns:On("SHOW_HELP", function() Help:Show() end)
end

function Help:Hide()
    if self.frame then self.frame:Hide() end
end
