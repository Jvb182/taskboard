local T, Mock = ...

describe("Appearance", function()
    it("keeps dialogs and board dropdown opaque across opacity and theme changes", function()
        local m, ns = T.client()
        ns.Board:Show(); ns.Options:Show(); ns.Help:Show(); ns.LogWindow:ShowLog()
        local board = ns.DB:GetActiveBoard()
        local _, card = next(board.cards)
        ns.Editor:Open(card, board)
        ns.Board:BoardMenu()
        for _, preset in ipairs(ns.Theme.PRESETS) do
            ns.Options:SetAppearance("theme", preset.id)
            ns.Options:SetAppearance("panelOpacity", 0.35)
            for _, f in ipairs({ ns.Options:Internals().frame, ns.Help.frame, ns.LogWindow:Internals().frame,
                ns.Editor:Internals().frame, m.env.TaskboardMenu }) do T.eq(f._bg[4], 1) end
            T.eq(ns.Board.frame._bg[4], 0.35)
        end
        T.noErrors(ns)
    end)

    it("applies every theme and accent to existing and newly created panels", function()
        local m, ns = T.client()
        ns.Board:Show(); ns.Options:Show()
        local frame = ns.Board.frame
        local before = frame._bg[1]
        ns.Options:SetAppearance("theme", "parchment")
        T.no(frame._bg[1] == before)
        for _, preset in ipairs(ns.Theme.PRESETS) do
            ns.Options:SetAppearance("theme", preset.id)
            T.eq(ns.db.settings.theme, preset.id)
            for _, accent in ipairs(ns.Theme.ACCENTS) do
                ns.Options:SetAppearance("accent", accent.id)
                T.near(ns.Theme.colors.accent[1], accent.color[1] * (ns.Theme:IsParchment() and 0.42 or 1))
                local panel = m.env.CreateFrame("Frame", nil, m.env.UIParent, "BackdropTemplate")
                ns.Theme.Panel(panel)
                T.eq(panel._bg[1], ns.Theme.colors.panel[1])
            end
        end
        T.noErrors(ns)
    end)

    it("changes background opacity without fading text or the whole frame", function()
        local m, ns = T.client()
        ns.Board:Show(); ns.Options:Show()
        ns.Options:Internals().opacity:SetValue(0.5)
        T.near(ns.Board.frame._bg[4], 0.5)
        T.eq(ns.Board.frame:GetAlpha(), 1)
        T.eq(ns.Theme.colors.text[4], 1)
        T.eq(ns.Theme.colors.accent[4], 1)
        ns.Options:SetAppearance("panelOpacity", 0)
        T.eq(ns.db.settings.panelOpacity, 0.35)
        T.noErrors(ns)
    end)

    it("persists personalization and sound choices across reload", function()
        local m, ns = T.client()
        ns.Options:SetAppearance("theme", "forest")
        ns.Options:SetAppearance("accent", "rose")
        ns.Options:SetAppearance("panelOpacity", 0.7)
        ns.Options:SetSound("move", "off")
        local m2, n2 = T.client(nil, m.Logout())
        T.eq(n2.db.settings.theme, "forest"); T.eq(n2.db.settings.accent, "rose")
        T.eq(n2.db.settings.panelOpacity, 0.7); T.eq(n2.db.settings.soundEvents.move, "off")
        n2.Board:Show(); T.eq(n2.Board.frame._bg[4], 0.7)
        T.noErrors(n2)
    end)

    it("shows only the selected settings page", function()
        local m, ns = T.client(); ns.Options:Show()
        ns.Options:Page("sounds")
        local ui = ns.Options:Internals()
        T.ok(ui.pages.sounds:IsShown()); T.no(ui.pages.general:IsShown()); T.no(ui.pages.style:IsShown())
        ns.Options:Page("style")
        T.ok(ui.pages.style:IsShown()); T.no(ui.pages.sounds:IsShown())
    end)

    it("closes settings with the board", function()
        local m, ns = T.client()
        ns.Board:Show(); ns.Options:Show()
        T.ok(ns.Options:Internals().frame:IsShown())
        ns.Board:Toggle()
        T.no(ns.Options:Internals().frame:IsShown())
        T.noErrors(ns)
    end)

    it("uses WoW frame artwork for both classic skins", function()
        local m, ns = T.client()
        ns.Board:Show()
        for _, name in ipairs({ "classic_stone", "classic_leather" }) do
            ns.Options:SetAppearance("theme", name)
            T.eq(ns.Board.frame._backdrop.edgeFile, "Interface\\DialogFrame\\UI-DialogBox-Border")
            T.eq(ns.db.settings.theme, name)
        end
        ns.Options:SetAppearance("theme", "midnight")
        T.eq(ns.Board.frame._backdrop.edgeFile, ns.Theme.WHITE)
        T.noErrors(ns)
    end)
end)

describe("Event sounds", function()
    it("plays move and manual completion sounds, but not reorder or reset sounds", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local c = ns.Commands:Add("Manual *daily")
        ns.DB:MoveCard(b, c.id, "doing")
        T.eq(#m.sounds, 1)
        T.eq(m.sounds[1], m.env.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.DB:MoveCard(b, c.id, "doing", 1)
        T.eq(#m.sounds, 1)
        ns.DB:MoveCard(b, c.id, "done"); m.Advance(1)
        T.eq(#m.sounds, 2)
        T.eq(m.sounds[2], m.env.SOUNDKIT.IG_QUEST_LIST_COMPLETE)
        ns.Recurring:Reset("daily"); m.Advance(1)
        T.eq(#m.sounds, 2); T.noErrors(ns)
    end)

    it("automatic completion produces only one completion sound", function()
        local m, ns = T.client()
        ns.Commands:Add("1 Peacebloom")
        m.Loot(2447, 1); m.Advance(1)
        T.eq(#m.sounds, 1)
        T.eq(m.sounds[1], m.env.SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    end)

    it("allows sounds without popups and per-event off", function()
        local m, ns = T.client(); ns.db.settings.toasts = false
        local c = ns.Commands:Add("Manual")
        ns.DB:MoveCard(ns.DB:GetActiveBoard(), c.id, "done"); m.Advance(1)
        T.eq(#m.sounds, 1); T.eq(#ns.Toast:Active(), 0)
        ns.Options:SetSound("move", "off")
        ns.DB:MoveCard(ns.DB:GetActiveBoard(), c.id, "doing")
        T.eq(#m.sounds, 1)
        ns.db.settings.sounds = false
        ns.Toast:PlaySound("complete", true); T.eq(#m.sounds, 1)
    end)

    it("previews each choice and keeps Off silent", function()
        local m, ns = T.client()
        for _, name in ipairs({ "click", "chime", "quest", "page", "coin", "message", "alert" }) do
            ns.Options:SetSound("move", name); ns.Toast:PlaySound("move", true)
        end
        T.eq(#m.sounds, 7)
        ns.Options:SetSound("move", "off"); ns.Toast:PlaySound("move", true)
        T.eq(#m.sounds, 7)
    end)

    it("plays feedback for a manually checked subtask", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local c = ns.Commands:Add("List; One; Two")
        local subs = ns.Util.DeepCopy(c.subtasks); subs[1].done = true
        ns.DB:UpdateCard(b, c, { subtasks = subs })
        T.eq(#m.sounds, 1)
        T.eq(m.sounds[1], m.env.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
end)

describe("Attached zone reminders", function()
    it("reminds on zone and indoor arrival and observes cooldown/disabled state", function()
        local m, ns = T.client()
        local c = ns.Commands:Add('Visit trainer @"Stormwind City"')
        T.eq(c.where.zone, "Stormwind City")
        m.state.zone = "Stormwind City"
        m.Fire("ZONE_CHANGED_NEW_AREA")
        T.eq(ns.Reminders.stats.shown, 1); T.eq(#m.sounds, 1)
        m.Fire("ZONE_CHANGED"); T.eq(ns.Reminders.stats.shown, 1)
        m.now = m.now + 301; m.Advance(1)
        m.Fire("ZONE_CHANGED_INDOORS"); T.eq(ns.Reminders.stats.shown, 2)
        ns.db.settings.reminders = false
        m.now = m.now + 301; m.Fire("ZONE_CHANGED_NEW_AREA")
        T.eq(ns.Reminders.stats.shown, 2); T.noErrors(ns)
    end)
end)

describe("Taskboard migration", function()
    it("updates the original welcome instructions", function()
        local _, ns = T.client(nil, { db = { boards = { b = { id = "b", name = "My Quests", cards = {
            c = { id = "c", title = "Welcome to Questboard! Right-click me", notes =
                "Add cards with /qb add, or type in the box at the top of the board.\n\n" ..
                "Try: Get 20 Peacebloom #herbs !high\nShift-click an item link into the box to track it live." },
        } } } } })
        T.contains(ns.db.boards.b.cards.c.notes, "/tb add")
        T.no(string.find(ns.db.boards.b.cards.c.notes, "/qb", 1, true))
        T.noErrors(ns)
    end)

    it("renames saved default labels once without rewriting custom or shared content", function()
        local saved = { db = { boards = {
            old = { id = "old", name = "My Quests", cards = {
                welcome = { id = "welcome", title = "Welcome to Questboard! Right-click me", notes = "My custom notes", subtasks = {
                    { text = "Open the board with /qb", done = true }, { text = "My custom task" },
                } },
            } },
            custom = { id = "custom", name = "My Quests for friends", cards = {} },
            shared = { id = "shared", name = "My Quests", scope = "shared", cards = {} },
        } } }
        local m, ns = T.client(nil, saved)
        local b = ns.db.boards.old
        T.eq(b.name, "My Tasks")
        T.eq(b.cards.welcome.title, "Welcome to Taskboard! Right-click me")
        T.eq(b.cards.welcome.notes, "My custom notes")
        T.eq(b.cards.welcome.subtasks[1].text, "Open the board with /tb")
        T.eq(b.cards.welcome.subtasks[1].done, true)
        T.eq(ns.db.boards.custom, nil, "empty extra board was merged")
        T.eq(ns.db.boards.shared.name, "My Quests")
        b.name = "My Quests"
        local _, again = T.client(nil, m.Logout())
        T.eq(again.db.boards.old.name, "My Quests")
        T.noErrors(ns); T.noErrors(again)
    end)

    it("copies legacy boards/settings/logs without modifying the old save", function()
        local old = { schema = 1, boards = { old = { id = "old", name = "Existing", cards = { c = { id = "c", title = "Keep me" } } } },
            settings = { sounds = false } }
        local log = { sessions = 4, entries = {} }
        local m = Mock.new()
        m.env.QuestboardDB, m.env.QuestboardLog = old, log
        local ns = m.Login()
        T.eq(ns.db.boards.old.cards.c.title, "Keep me")
        T.eq(ns.db.settings.sounds, false)
        T.eq(m.env.TaskboardLog.sessions, 5)
        T.eq(log.sessions, 4)
        ns.db.boards.old.cards.c.title = "Edited"
        T.eq(old.boards.old.cards.c.title, "Keep me")
        T.noErrors(ns)
    end)

    it("never overwrites an existing Taskboard save with legacy data", function()
        local m = Mock.new(); m.env.QuestboardDB = { boards = { legacy = { name = "Old" } } }
        local ns = m.Login({ db = { boards = { new = { id = "new", name = "Current" } } } })
        T.ok(ns.db.boards.new); T.eq(ns.db.boards.legacy, nil)
    end)

    it("supports Taskboard commands with retained binding IDs", function()
        local m, ns = T.client()
        m.Slash("/tb"); T.ok(ns.Board:IsShown())
        m.Slash("/taskboard"); T.no(ns.Board:IsShown())
        T.eq(m.env.SLASH_TASKBOARD3, nil)
        T.eq(m.env.BINDING_HEADER_QUESTBOARD, "Taskboard")
        T.eq(m.env.BINDING_NAME_QUESTBOARD_TOGGLE, "Open or close the board")
        T.noErrors(ns)
    end)
end)
