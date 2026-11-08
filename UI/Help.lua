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
        { "p", "The bracketed item example is a placeholder: insert a real link. Unknown item names can stay pending until matching loot identifies them. A quest goal completes when the quest is turned in, not merely ready to turn in." },
        { "h", "Tags, priority and starting status" },
        { "e", "Organize bags #chores !low" },
        { "e", "Prepare potions #alchemy !med >doing" },
        { "e", "Repair equipment !high >todo" },
        { "e", "Finished preparations >done" },
        { "p", "Use #tag to group tasks. Priorities are !low, !med and !high. >todo, >doing and >done choose the initial column. The editor can change these later." },
        { "h", "Locations and NPC reminders" },
        { "p", "Type @ plus a letter to suggest zones and towns. @g narrows to @go for Goldshire. Click a result or use Up/Down and Tab/Enter. Enter first accepts the location; press it again to add the task. Scroll for more matches, or Escape to dismiss. Multiword names are quoted automatically. You can type a missing location manually." },
        { "e", "Buy vials @Goldshire" },
        { "e", 'Buy supplies @"Stormwind City"' },
        { "e", "Sort supplies @bank" },
        { "e", "Buy vials @vendor" },
        { "e", "Check mail @mail" },
        { "e", "List auctions @ah" },
        { "e", "Learn new skills @trainer" },
        { "p", "Each task has one reminder destination: either a location or an NPC type. If you type several @ tokens, the last parsed destination wins. Use separate tasks for separate destinations." },
        { "h", "Repeating tasks and subtasks" },
        { "e", "Check auctions *daily" },
        { "e", "Visit the trainer @Goldshire *weekly" },
        { "e", "Alchemy prep; 20 Peacebloom; 20 Silverleaf; buy vials" },
        { "e", "Alchemy prep #herbs !high @bank *daily; 20 Peacebloom; buy vials" },
        { "p", "A semicolon starts a subtask. Live goals update their checkboxes; manual subtasks can be checked off. Tags, reminder, repeat and starting-status tokens apply to the whole task, even when entered after a semicolon. See Tracking & reminders for reset rules." },
    } },
    { id = "tracking", title = "Tracking & reminders", entries = {
        { "h", "Progress and automatic movement" },
        { "p", "Taskboard tracks items, current money, level/XP, profession skill, reputation and quest turn-ins. With automatic movement enabled, progress starts a task and completing all its goals/subtasks moves it to Done. Goals already met can complete immediately when added." },
        { "e", "get 17 Silverleaf: 15 owned means 15/17; two more completes it." },
        { "p", "Money goals track current money, not lifetime earnings. Finished tasks stay in Done if you later spend or sell their items. If you manually move a completed task out of Done, it waits until its goal becomes incomplete before automatically completing again. Manual tasks without goals must be moved or marked done by you." },
        { "h", "Bank counting" },
        { "p", "Both the task's Count items in the bank checkbox and the General bank-counting setting must be enabled. Counts come from the game client; Taskboard does not keep a separate bank inventory cache. Availability away from the bank depends on the client. This does not scan other characters' or guild inventories." },
        { "h", "Daily and weekly tasks" },
        { "p", "Repeating tasks reset at the server's daily or weekly reset. Saved boards for offline characters are reset too; archived tasks are left alone. Missing a period breaks the task's streak." },
        { "p", "Repeating item goals default to net inventory gained above a starting amount, not total loot. Spending or selling reduces that gain. Baselines survive reloads; an offline character gets its new baseline at the next login. Changing bank-counting settings starts a fresh baseline." },
        { "e", "Hold 15 Silverleaf, then add get 17 Silverleaf *daily: gain 17 more." },
        { "p", "To count current stock instead, uncheck Items: collect extra each period (net gain) in the editor. After reset, a stock goal must drop below its target before it can automatically complete again." },
        { "h", "Arrival and NPC reminders" },
        { "p", "@Goldshire reminds you when you enter a matching zone or subzone. Matching is case-insensitive and accepts a name prefix. Arrival does not complete a task, move it, or limit where its goal counts. Reminders apply to unfinished, unarchived tasks evaluated by your character, with a five-minute cooldown per task/destination context." },
        { "p", "NPC reminders trigger when you open the relevant bank, vendor, mailbox, auction house or trainer. Smart reminders additionally list missing goal items at the auction house and goal items stored in your bank. General settings can disable reminders or smart reminders separately." },
        { "p", "The editor's zone field and Here button also attach reminders. Map pins are separate: Pin my location saves coordinates; Show on map sets a waypoint. A pin alone is not an arrival reminder." },
        { "h", "On-screen tracker" },
        { "p", "The tracker automatically lists In Progress tasks and tasks marked Show in tracker. Unchecking Show in tracker does not hide an In Progress task. Done and archived tasks are excluded. Click a tracker task to open its editor." },
        { "e", "/tb tracker - hide or show the whole tracker" },
        { "p", "You can hide the tracker and still open the board with /tb or the minimap. Click the tracker header to collapse it; drag it to move. Right-click its header to open the board, lock its position or hide it. Right-click a tracker task for its card menu. General settings can hide it in combat. Preferences persist across reloads." },
        { "h", "Progress feedback and statistics" },
        { "p", "Progress messages show counts as goals advance. Completion/reminder popups and sounds have separate controls. The board footer summarizes completions today and this week, your day streak and total completions." },
    } },
    { id = "settings", title = "Settings & sharing", entries = {
        { "h", "Boards, cards and layout" },
        { "p", "Drag the title or empty top bar to move the main board; use the bottom-right grip to resize it. Its position and size are saved. Scroll sideways when extra columns do not fit." },
        { "p", "The Board menu switches boards and creates account-wide or character-only boards. It also renames, exports, imports and deletes boards. Search filters text, Tags filters by tag, and Mine hides cards belonging to other characters." },
        { "e", "/tb board Alchemy - switch to or create a board" },
        { "p", "Drag cards between columns or reorder them. Right-click a card to edit, move, duplicate, archive or delete it. The editor changes title, notes, goals, subtasks, tags, priority, character, reminder, repeat, tracker and map pin settings. Shared cards have editing restrictions." },
        { "p", "Right-click column headers to rename them, add columns or remove custom columns. Core To Do/In Progress/Done roles stay intact even when renamed. Done columns can archive their tasks. Board > Show archived cards lets you restore an archived task; deletion is permanent." },
        { "h", "General settings" },
        { "e", "/tb options" },
        { "p", "General controls automatic starting/completion, progress messages, popups, the sound master switch, reminders, smart reminders, bank counting, tracker visibility, hiding in combat, the minimap button, share offers and debug logging." },
        { "p", "Bind Open or close the board, Show or hide the tracker, and Quick add a card in the game's Key Bindings > AddOns. Left-click the minimap button for the board, right-click it for the tracker, or drag it to reposition it." },
        { "h", "Appearance" },
        { "p", "Choose Midnight, Warm leather, Forest, Arcane or High contrast. Accent choices are Sky, Gold, Mint, Rose and Lilac. Panel opacity ranges from 35% to 100%; text stays opaque. Status and priority colors retain their meaning. Changes apply live and are saved. Reset appearance restores the defaults." },
        { "h", "Sounds" },
        { "p", "Choose Off, Soft click, Chime or Quest complete separately for status changes, completed tasks, completed subtasks and reminders. Preview plays a choice without changing any tasks. The General Play sounds switch controls all of them; loudness follows the game's audio settings." },
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
        { "p", "Text import creates a new board owned by you and assigns live goals to your current character. It does not overwrite the original board. Use the Board menu for the same actions." },
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
        { "p", "For a bug report, include what you typed/did, expected and actual results, your client build, /tb diag and relevant log lines. Screenshots help with layout issues. In-game checks cannot guarantee server delivery or every visual behavior." },
        { "h", "Saved data and upgrades" },
        { "p", "Taskboard saves boards, settings and window positions through WoW's SavedVariables on logout/reload. When upgrading from Questboard, enable Taskboard and Taskboard - legacy data loader for the first login. Once migrated data survives a reload, the loader can be disabled. Existing key bindings are retained; commands use /tb, not the old shortcut." },
    } },
}

function Help:Select(id)
    local section
    for _, item in ipairs(self.SECTIONS) do if item.id == id then section = item end end
    if not section then return end
    self.selected = id
    for key, button in pairs(self.tabs) do button:SetActive(key == id) end
    self.scroll:SetVerticalScroll(0)
    local y = 0
    for i, entry in ipairs(section.entries) do
        local row = self.rows[i]
        if not row then row = W.Text(self.content); self.rows[i] = row end
        row:ClearAllPoints()
        local heading = entry[1] == "h"
        if heading and i > 1 then y = y + 10 end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(574)
        row:SetWordWrap(true)
        local font = heading and "GameFontNormal" or "GameFontHighlightSmall"
        row:SetFontObject(font)
        Theme.Text(row, font)
        row:SetText(entry[2])
        row:Show()
        y = y + row:GetStringHeight() + (entry[1] == "e" and 8 or 12)
    end
    for i = #section.entries + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(y, 10))
end

function Help:Show(id)
    if not self.frame then
        local frame = CreateFrame("Frame", "TaskboardHelp", UIParent, "BackdropTemplate")
        self.frame, self.rows, self.tabs = frame, {}, {}
        frame:SetSize(630, 500)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function() frame:StartMoving() end)
        frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
        Theme.Panel(frame, Theme.colors.window, Theme.colors.windowBorder)
        table.insert(UISpecialFrames, "TaskboardHelp")
        local title = W.Text(frame, "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("Taskboard Help")
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        for i, section in ipairs(self.SECTIONS) do
            local key = section.id
            local button = W.Button(frame, section.title, 194, 26, function() Help:Select(key) end)
            button:SetPoint("TOPLEFT", 16 + (i - 1) * 200, -42)
            self.tabs[key] = button
        end
        self.scroll, self.content = W.Scroll(frame)
        self.scroll:SetPoint("TOPLEFT", 16, -82)
        self.scroll:SetPoint("BOTTOMRIGHT", -34, 16)
        self.content:SetWidth(574)
    end
    self.frame:Show()
    self:Select(id or self.selected or "quick")
end

function Help:OnLogin()
    ns:On("SHOW_HELP", function() Help:Show() end)
end
