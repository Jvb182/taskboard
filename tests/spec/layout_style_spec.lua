local T, Mock = ...

describe("Board layouts", function()
    it("counts tags only in available columns and excludes archived cards", function()
        local m, ns = T.client(); local board = ns.DB:GetActiveBoard(); ns.Board:Show()
        local active = ns.Commands:Add("Visible #qa")
        local archived = ns.Commands:Add("Archived #qa #archivedonly"); archived.archived = true
        local done = ns.Commands:Add("Completed #qa #doneonly")
        ns.DB:MoveCard(board, done.id, ns.DB:ColumnByRole(board, "done").id)
        ns.DB:SetShowCompleted(board, false)
        local entries
        ns.Widgets.Menu = function(_, items) entries = items end
        ns.Board:TagMenu()
        T.eq(#entries, 3); T.eq(entries[3].text, "#qa (1)")
        entries[3].func(); T.ok(ns.Board.MatchesFilter(active))
        ns.DB:SetShowCompleted(board, true); ns.Board:TagMenu()
        T.eq(entries[3].text, "#doneonly (1)"); T.eq(entries[4].text, "#qa (2)")
        T.noErrors(ns)
    end)
    it("keeps tag alternatives while honoring Mine and search filters", function()
        local m, ns = T.client(); local board = ns.DB:GetActiveBoard(); ns.Board:Show()
        local qa = ns.Commands:Add("Match #qa")
        local herb = ns.Commands:Add("Match #herb")
        local other = ns.Commands:Add("Match #other"); other.char = "Other-Realm"
        ns.Commands:Add("Unrelated #hidden")
        ns.db.settings.onlyMine = true
        ns.Board.filter.text = "match"
        ns.Board:SetTag("qa")
        local entries
        ns.Widgets.Menu = function(_, items) entries = items end
        ns.Board:TagMenu()
        T.eq(#entries, 4); T.eq(entries[3].text, "#herb (1)"); T.eq(entries[4].text, "#qa (1)")
        entries[3].func()
        T.ok(ns.Board.MatchesFilter(herb)); T.no(ns.Board.MatchesFilter(qa))
        T.no(ns.Board.MatchesFilter(other)); T.noErrors(ns)
    end)
    it("pages through every archived task and restores a task from a later page", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        for i = 1, 45 do local c = ns.Commands:Add(string.format("Archived %02d", i)); c.archived = true end
        ns.Board:ArchiveMenu(b)
        local function click(text)
            for _, row in ipairs(m.env.TaskboardMenu.rows) do
                if row:IsShown() and row.text:GetText() == text then row:Click(); return end
            end
            error("Missing archive menu entry: " .. text)
        end
        click("Next page"); click("Next page"); click("Archived 45")
        local count = 0
        for _, c in pairs(b.cards) do if c.archived then count = count + 1 end end
        T.eq(count, 44); T.noErrors(ns)
    end)
    it("searches all Help tabs case-insensitively with examples and clears the search", function()
        local m, ns = T.client(); ns.Help:Show("quick")
        ns.Help.search:SetText("  MAILBOX  ")
        local text = ""
        for _, row in ipairs(ns.Help.rows) do if row:IsShown() then text = text .. row:GetText() end end
        T.contains(text, "35 yards"); T.contains(text, "Tracking & reminders")
        ns.Help.search:SetText("no-such-topic-[%")
        T.contains(ns.Help.rows[1]:GetText(), "No matching help topics")
        ns.Help.tabs.quick:Click(); T.eq(ns.Help.search:GetText(), "")
        T.noErrors(ns)
    end)
    it("distinguishes dark Classic stone from parchment Classic leather with an atlas fallback", function()
        local m, ns = T.client(); ns.Board:Show(); ns.Help:Show()
        ns.Options:SetAppearance("theme", "classic_stone")
        T.ok(not ns.Help.frame.taskboardParchment or not ns.Help.frame.taskboardParchment:IsShown())
        T.ok(ns.Theme.colors.text[1] > 0.8)
        T.ok(ns.Board:Internals().frame.taskboardSolid:IsShown())
        T.eq(ns.Board:Internals().frame.taskboardSolid._color[4], ns.db.settings.panelOpacity)
        ns.Options:SetAppearance("panelOpacity", 0.35)
        T.eq(ns.Board:Internals().frame.taskboardSolid._color[4], 0.35)
        ns.Options:SetAppearance("panelOpacity", 1)
        ns.Options:SetAppearance("theme", "classic_leather")
        T.ok(ns.Help.frame.taskboardParchment:IsShown())
        T.ok(ns.Theme.colors.text[1] < 0.3)
        T.no(ns.Board:Internals().frame.taskboardSolid:IsShown())
        T.eq(ns.Help.frame.taskboardParchment:GetAlpha(), 1)
        local oldTexture = m.env.C_Texture
        m.env.C_Texture = { GetAtlasInfo = function() return nil end }
        local panel = m.env.CreateFrame("Frame", nil, m.env.UIParent, "BackdropTemplate")
        ns.Theme.Panel(panel); T.ok(panel.taskboardParchment:IsShown())
        m.env.C_Texture = oldTexture
        T.noErrors(ns)
    end)
    it("uses a solid, high-contrast column header on classic skins and resets it on Midnight", function()
        local _, ns = T.client(); ns.Board:Show()
        for _, theme in ipairs({ "quest_log", "classic_stone", "classic_leather" }) do
            ns.Options:SetAppearance("theme", theme)
            ns.Board:Layout()
            for _, col in ipairs(ns.Board:Internals().columns) do
                if col:IsShown() then
                    T.eq(col.headerBackground:IsShown(), theme ~= "classic_stone")
                    if theme ~= "classic_stone" then
                        T.ok(col.headerBackground._color[4] >= 0.95)
                        T.ok(col.title._textColor[1] >= 0.9)
                    end
                end
            end
        end
        ns.Options:SetAppearance("theme", "midnight")
        ns.Board:Layout()
        for _, col in ipairs(ns.Board:Internals().columns) do
            if col:IsShown() then T.no(col.headerBackground:IsShown()) end
        end
        T.noErrors(ns)
    end)
    it("reorders populated custom columns and retains order across reload", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local col = ns.DB:AddColumn(b, "Waiting")
        local card = ns.Commands:Add("Waiting task")
        ns.DB:MoveCard(b, card.id, col.id)
        T.ok(ns.DB:MoveColumn(b, col.id, -1))
        T.eq(b.columns[2].id, col.id); T.eq(card.column, col.id)
        T.eq(b.order[col.id][1], card.id)
        local _, restored = T.client(nil, m.Logout())
        T.eq(restored.DB:GetActiveBoard().columns[2].id, col.id)
        T.noErrors(restored)
    end)
    it("reorders visible neighbors while preserving hidden columns and rejecting invalid moves", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local col = ns.DB:AddColumn(b, "Waiting")
        ns.DB:SetShowCompleted(b, false)
        T.no(ns.DB:MoveColumn(b, col.id, 1))
        T.no(ns.DB:MoveColumn(b, "done", -1))
        T.no(ns.DB:MoveColumn(b, col.id, 0))
        ns.DB:SetSimpleMode(b, true); ns.DB:SetShowCompleted(b, true)
        T.ok(ns.DB:MoveColumn(b, "todo", 1))
        T.eq(b.columns[1].id, "done"); T.eq(b.columns[2].id, "doing")
        T.eq(b.columns[3].id, col.id)
        b.scope = "shared"; b.shared = { from = "Other-Realm" }
        T.no(ns.DB:MoveColumn(b, "done", 1)); T.noErrors(ns)
    end)
    it("offers working column menu moves with disabled boundary actions", function()
        local m, ns = T.client(); ns.Board:Show()
        local b = ns.DB:GetActiveBoard(); local col = ns.DB:AddColumn(b, "Waiting")
        ns.Board:ColumnMenu(col)
        for _, row in ipairs(m.env.TaskboardMenu.rows) do
            if row:IsShown() and row.text:GetText() == "Move column left" then row:Click(); break end
        end
        T.eq(b.columns[2].id, col.id); T.noErrors(ns)
    end)
    it("menu confirms Simple conversion and toggles completed visibility", function()
        local m, ns = T.client(); ns.Board:Show()
        local b = ns.DB:GetActiveBoard()
        local function click(label)
            ns.Board:BoardMenu()
            for _, row in ipairs(m.env.TaskboardMenu.rows) do
                if row:IsShown() and row.text:GetText():find(label, 1, true) then row:Click(); return end
            end
            error("missing menu option " .. label)
        end
        click("Simple mode"); T.no(b.simpleMode)
        m.AcceptPopup(); T.ok(b.simpleMode)
        click("Show completed"); T.eq(b.showCompleted, false)
        click("Simple mode"); T.no(b.simpleMode); T.noErrors(ns)
    end)
    it("defaults to Standard and keeps mode/completed visibility per character across reload", function()
        local m, ns = T.client({ name = "Alice" })
        local b = ns.DB:GetActiveBoard()
        T.no(b.simpleMode); T.eq(#ns.DB:DisplayColumns(b), 3)
        ns.DB:SetSimpleMode(b, true); ns.DB:SetShowCompleted(b, false)
        local n, a = T.client({ name = "Bob" }, m.Logout())
        T.no(a.DB:GetActiveBoard().simpleMode)
        local alice = a.db.boards[b.id]
        T.ok(alice.simpleMode); T.eq(#a.DB:DisplayColumns(alice), 1)
        T.eq(#a.DB:StatusColumns(alice), 2); T.noErrors(a)
    end)

    it("moves ordered work and archives from hidden statuses without completing or losing cards", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local custom = ns.DB:AddColumn(b, "Waiting")
        local a = ns.Commands:Add("First >doing")
        local c = ns.Commands:Add("Second >doing"); c.archived = true
        local d = ns.Commands:Add("Third"); ns.DB:MoveCard(b, d.id, custom.id)
        local done = ns.Commands:Add("Finished >done")
        local total = ns.Stats:Summary().total
        ns.DB:SetSimpleMode(b, true)
        T.eq(a.column, "todo"); T.eq(c.column, "todo"); T.ok(c.archived)
        T.eq(d.column, "todo"); T.eq(done.column, "done")
        T.eq(ns.Stats:Summary().total, total)
        T.eq(#ns.DB:DisplayColumns(b), 2)
        ns.DB:SetSimpleMode(b, false)
        T.eq(#ns.DB:DisplayColumns(b), 4); T.eq(a.column, "todo"); T.noErrors(ns)
    end)

    it("keeps partial live goals in To Do and auto-completes into hidden Done", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        ns.DB:SetSimpleMode(b, true); ns.DB:SetShowCompleted(b, false)
        local c = ns.Commands:Add("20 Peacebloom >doing")
        m.Loot(2447, 5); m.Advance(1)
        T.eq(c.column, "todo"); T.eq(c.progress.cur, 5)
        ns.DB:MoveCard(b, c.id, "doing"); T.eq(c.column, "todo")
        m.Loot(2447, 15); m.Advance(1); T.eq(c.column, "done")
        T.eq(#ns.DB:DisplayColumns(b), 1)
        ns.DB:SetShowCompleted(b, true); T.eq(#ns.DB:CardsIn(b, "done"), 1)
        T.noErrors(ns)
    end)

    it("keeps Simple goals in To Do while tracking and reminding until completion", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        ns.DB:SetSimpleMode(b, true)
        local c = ns.Commands:Add("2 Peacebloom @Ironforge")
        m.Loot(2447, 1); m.Advance(1)
        T.eq(c.column, "todo"); T.eq(c.progress.cur, 1)
        local tracked = false
        for _, entry in ipairs(ns.Tracker:Entries()) do if entry.card == c then tracked = true end end
        T.ok(tracked)
        local reminders = 0
        ns:On("REMINDER", function(_, lines)
            for _, line in ipairs(lines or {}) do if line.card == c then reminders = reminders + 1 end end
        end)
        m.state.zone = "Ironforge"; m.Fire("ZONE_CHANGED_NEW_AREA")
        T.eq(reminders, 1)
        m.Loot(2447, 1); m.Advance(1)
        T.eq(c.column, "done"); T.noErrors(ns)
    end)

    it("shows open Simple tasks in the tracker without forcing the tracker visible", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local c = ns.Commands:Add("Manual errand")
        ns.DB:SetSimpleMode(b, true); m.Advance(1)
        local found = false
        for _, e in ipairs(ns.Tracker:Entries()) do if e.card == c then found = true end end
        T.ok(found)
        ns.Commands:Handle("tracker"); T.no(ns.db.settings.trackerShown)
        T.noErrors(ns)
    end)

    it("removes the editor column controls while preserving board status changes", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local c = ns.Commands:Add("Manual")
        ns.DB:SetSimpleMode(b, true); ns.DB:SetShowCompleted(b, false)
        ns.Board:Show(); ns.Editor:Open(c, b); m.Advance(1)
        local shown = 0
        for _, col in ipairs(ns.Board:Internals().columns) do if col:IsShown() then shown = shown + 1 end end
        T.eq(shown, 1)
        T.eq(ns.Editor:Internals().ui.columnRow, nil)
        T.ok(ns.DB:MoveCard(b, c.id, "done")); T.eq(c.column, "done")
        T.noErrors(ns)
    end)

    it("rejects shared-board layout mutation and new custom columns in Simple mode", function()
        local _, ns = T.client(); local b = ns.DB:GetActiveBoard()
        ns.DB:SetSimpleMode(b, true)
        local col, err = ns.DB:AddColumn(b, "Waiting"); T.eq(col, nil); T.contains(err, "Standard")
        b.scope = "shared"; b.shared = { from = "Other-Forever" }
        T.no(ns.DB:SetSimpleMode(b, false)); T.no(ns.DB:SetShowCompleted(b, false))
    end)
end)

describe("Nearby repeating sound", function()
    local function setup()
        local m, ns = T.client()
        m.state.subzone = "Goldshire"
        ns.Commands:Add("Buy vials @Goldshire")
        ns.Commands:Add("Visit inn @Goldshire")
        m.Advance(6)
        return m, ns
    end

    it("is off by default and plays once per interval for several flashing tasks", function()
        local m, ns = setup()
        local before = #m.sounds; m.Advance(65); T.eq(#m.sounds, before)
        ns.db.settings.nearbySounds = true
        ns.db.settings.nearbySoundInterval = 15
        m.Advance(1); before = #m.sounds
        m.Advance(14); T.eq(#m.sounds, before)
        m.Advance(1); T.eq(#m.sounds, before + 1)
        m.Advance(15); T.eq(#m.sounds, before + 2); T.noErrors(ns)
    end)

    it("stops after leaving or hiding the tracker and restarts with a fresh interval", function()
        local m, ns = setup(); ns.db.settings.nearbySounds = true
        m.Advance(32); local before = #m.sounds
        m.state.subzone = "Elsewhere"; m.Fire("ZONE_CHANGED")
        m.Advance(40); T.eq(#m.sounds, before)
        m.state.subzone = "Goldshire"; m.Fire("ZONE_CHANGED"); m.Advance(2)
        ns.db.settings.trackerShown = false; ns:Fire("TRACKER_SETTINGS")
        before = #m.sounds; m.Advance(40); T.eq(#m.sounds, before); T.noErrors(ns)
    end)

    it("respects sound Off, the master setting, and completion", function()
        local m, ns = setup(); ns.db.settings.nearbySounds = true
        ns.db.settings.soundEvents.reminder = "off"
        local before = #m.sounds; m.Advance(35); T.eq(#m.sounds, before)
        ns.db.settings.soundEvents.reminder = "chime"; ns.db.settings.sounds = false
        m.Advance(35); T.eq(#m.sounds, before)
        local b = ns.DB:GetActiveBoard()
        for _, c in pairs(b.cards) do ns.DB:MoveCard(b, c.id, "done") end
        m.Advance(1); ns.db.settings.sounds = true; before = #m.sounds
        m.Advance(40); T.eq(#m.sounds, before); T.noErrors(ns)
    end)
end)

describe("Theme and dependent window regressions", function()
    it("uses parchment artwork and dark text while Help stays solid at minimum opacity", function()
        local m, ns = T.client()
        m.env.C_Texture = { GetAtlasInfo = function() return {} end }
        ns.Help:Show(); ns.Options:Show()
        ns.Options:SetAppearance("theme", "quest_log"); ns.Options:SetAppearance("panelOpacity", 0.35)
        T.eq(ns.Help.frame.taskboardParchment._atlas, "QuestBG-Parchment")
        T.eq(ns.Help.frame.taskboardParchment:GetAlpha(), 1)
        T.eq(ns.Help.frame.taskboardSolid._color[4], 1)
        T.ok(ns.Theme.colors.text[1] < 0.3)
        ns.Options:SetAppearance("theme", "classic_stone")
        T.no(ns.Help.frame.taskboardParchment:IsShown()); T.eq(ns.Help.frame.taskboardSolid._color[4], 1)
        T.noErrors(ns)
    end)

    it("custom colors persist, sanitize invalid values and keep dialogs opaque", function()
        local m, ns = T.client(); ns.Options:Show()
        ns.Options:SetCustomColor("background", 0.2, 0.3, 0.4)
        ns.Options:SetCustomColor("text", 0.9, 0.8, 0.7)
        ns.Options:SetCustomColor("border", -1, 2, 0/0)
        ns.Options:SetAppearance("panelOpacity", 0.35)
        T.eq(ns.Options:Internals().frame._bg[4], 1)
        T.eq(ns.Options:Internals().frame.taskboardSolid._drawLayer, "BACKGROUND")
        T.eq(ns.Options:Internals().frame.taskboardSolid._drawSublevel, 1,
            "opaque dialog fill draws above the translucent backdrop")
        local n, a = T.client(nil, m.Logout())
        T.eq(a.db.settings.theme, "custom"); T.near(a.Theme.colors.window[1], 0.2)
        T.near(a.Theme.colors.text[1], 0.9); T.eq(a.Theme:CustomColors().border[1], 0)
        T.eq(a.Theme:CustomColors().border[2], 1); T.noErrors(a)
    end)

    it("picker cancels drafts, rejects invalid hex, applies hex, and reuses its frame", function()
        local m, ns = T.client(); ns.Options:Show()
        ns.Options:OpenColorPicker("background"); local f = ns.Options.picker
        f.sliders[1]:SetValue(0.6); f.cancelButton:Click(); T.eq(ns.db.settings.theme, "midnight")
        ns.Options:OpenColorPicker("text"); T.eq(ns.Options.picker, f)
        f.hex:SetText("oops"); f.applyButton:Click(); T.ok(f:IsShown())
        f.hex:SetText("#ABCDEF"); f.applyButton:Click(); T.no(f:IsShown())
        T.near(ns.Theme.colors.text[1], 171/255); T.near(ns.Theme.colors.text[3], 239/255)
        T.noErrors(ns)
    end)

    it("closing the board closes dependent windows and saves the focused card", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local c = ns.Commands:Add("Before")
        ns.Board:Show(); ns.Help:Show(); ns.Options:Show(); ns.Options:OpenColorPicker("accent")
        ns.Editor:Open(c, b)
        local ed = ns.Editor:Internals(); ed.ui.title:SetFocus(); ed.ui.title:SetText("After")
        m.state.inCombat = true; m.Fire("PLAYER_REGEN_DISABLED")
        ns.Commands:Handle("")
        T.eq(c.title, "After"); T.eq(ns.Editor:Current(), nil)
        T.no(ns.Help.frame:IsShown()); T.no(ns.Options:Internals().frame:IsShown()); T.no(ns.Options.picker:IsShown())
        ns.Board:Show(); T.no(ns.Help.frame:IsShown()); T.no(ed.frame:IsShown()); T.noErrors(ns)
    end)
end)
