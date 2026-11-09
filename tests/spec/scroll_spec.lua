local T, Mock = ...

describe("Scroll panes", function()
    it("limits editor dragging to the title strip and gives footer buttons mouse ownership", function()
        local m, ns = T.client()
        local original, mouse, strata = m.env.CreateFrame, {}, {}
        m.env.CreateFrame = function(...)
            local f = original(...)
            local parent = f:GetParent()
            strata[f] = parent and strata[parent]
            f.SetFrameStrata = function(self, value) strata[self] = value end
            f.EnableMouse = function(self, value) mouse[self] = value end
            return f
        end
        local card = ns.Commands:Add("Footer input test")
        ns.Editor:Open(card, ns.DB:GetActiveBoard())
        local ed = ns.Editor:Internals()
        T.eq(strata[ed.frame], "DIALOG")
        T.eq(strata[ed.ui.title], "DIALOG")
        T.eq(mouse[ed.ui.footer], true)
        T.eq(ed.frame:GetScript("OnDragStart"), nil)
        T.eq(ed.frame:GetScript("OnDragStop"), nil)
        T.eq(ed.ui.titleBar:GetHeight(), 28)
        T.ok(ed.frame.closeButton:GetFrameLevel() > ed.ui.titleBar:GetFrameLevel())
        local starts, stops = 0, 0
        ed.frame.StartMoving = function() starts = starts + 1 end
        ed.frame.StopMovingOrSizing = function() stops = stops + 1 end
        ed.ui.titleBar:GetScript("OnDragStart")()
        ed.ui.titleBar:GetScript("OnDragStop")()
        T.eq(starts, 1); T.eq(stops, 1)
        for _, button in ipairs({ ed.ui.delete, ed.ui.archive, ed.ui.done }) do
            T.eq(mouse[button], true)
            T.eq(strata[button], "DIALOG")
        end
        ed.ui.done:Click(); T.no(ed.frame:IsShown())
        m.env.CreateFrame = original
        T.noErrors(ns)
    end)
    it("keeps editor footer actions above content and confirms before deleting the intended card", function()
        local m, ns = T.client(); ns.Board:Show()
        local board = ns.DB:GetActiveBoard()
        local first = ns.Commands:Add("Delete footer test")
        local other = ns.Commands:Add("Keep this card")
        ns.Editor:Open(first, board)
        local ed = ns.Editor:Internals()
        T.eq(ed.ui.delete:GetParent(), ed.ui.footer)
        T.eq(ed.ui.archive:GetParent(), ed.ui.footer)
        T.eq(ed.ui.done:GetParent(), ed.ui.footer)
        T.ok(ed.ui.footer:GetFrameLevel() > ed.ui.title:GetFrameLevel())
        ed.ui.delete:Click()
        T.contains(m.popups[#m.popups].text, first.title)
        T.ok(board.cards[first.id]); m.CancelPopup(); T.ok(board.cards[first.id])
        ed.ui.delete:Click(); m.AcceptPopup()
        T.eq(board.cards[first.id], nil); T.ok(board.cards[other.id])
        T.no(ed.frame:IsShown()); T.noErrors(ns)
    end)

    it("raises only Taskboard confirmations and restores the shared popup layer afterward", function()
        local m, ns = T.client()
        local definition = m.env.StaticPopupDialogs.TASKBOARD_CONFIRM
        local strata, raised = "DIALOG", false
        local popup = {
            GetFrameStrata = function() return strata end,
            SetFrameStrata = function(_, value) strata = value end,
            Raise = function() raised = true end,
        }
        definition.OnShow(popup); T.eq(strata, "FULLSCREEN_DIALOG"); T.ok(raised)
        definition.OnHide(popup); T.eq(strata, "DIALOG")
        T.eq(popup.taskboardPreviousStrata, nil); T.noErrors(ns)
    end)
    it("raises Settings and its picker above the board while retaining standalone Settings", function()
        local m, ns = T.client(); ns.Board:Show(); ns.Options:Show()
        local options = ns.Options:Internals().frame
        T.eq(options:GetParent(), ns.Board.frame)
        T.ok(options:GetFrameLevel() > ns.Board.frame:GetFrameLevel())
        ns.Options:OpenColorPicker("background")
        T.ok(ns.Options.picker:GetFrameLevel() > options:GetFrameLevel())
        ns.Board.frame:Hide(); T.no(options:IsShown()); T.no(ns.Options.picker:IsShown())
        ns.Options:Show(); T.eq(options:GetParent(), m.env.UIParent)
        ns.Board:Show(); ns.Board.frame:SetFrameLevel(100); ns.Options:Show()
        ns.Options:OpenColorPicker("text")
        T.ok(options:GetFrameLevel() > 100)
        T.ok(ns.Options.picker:GetFrameLevel() > options:GetFrameLevel())
        T.noErrors(ns)
    end)

    it("raises the editor above its board and supports opening from a standalone tracker", function()
        local m, ns = T.client(); local b = ns.DB:GetActiveBoard()
        local card = ns.Commands:Add("Editor layer test")
        ns.Board:Show(); ns.Editor:Open(card, b)
        local editor = ns.Editor:Internals().frame
        T.eq(editor:GetParent(), ns.Board.frame)
        T.ok(editor:GetFrameLevel() > ns.Board.frame:GetFrameLevel())
        ns.Board.frame:Hide(); T.no(editor:IsShown())
        ns.Editor:Open(card, b); T.eq(editor:GetParent(), m.env.UIParent)
        T.ok(editor:IsVisible()); T.noErrors(ns)
    end)

    it("raises log dialogs on user open without raising passive log updates", function()
        local m, ns = T.client(); ns.Board:Show(); ns.Board.frame:SetFrameLevel(100)
        ns.LogWindow:ShowLog()
        local log = ns.LogWindow:Internals().frame
        T.eq(log:GetParent(), m.env.UIParent)
        T.ok(log:GetFrameLevel() > ns.Board.frame:GetFrameLevel())
        local raises = 0
        log.Raise = function() raises = raises + 1 end
        ns.Log:Info("qa", "New log entry"); T.eq(raises, 0)
        ns.LogWindow:ShowDiag(); T.eq(raises, 1)
        ns.LogWindow:ShowExport(); T.eq(raises, 2)
        ns.LogWindow:ShowImport(); T.eq(raises, 3)
        ns.Board.frame:Hide(); T.ok(log:IsShown()); T.noErrors(ns)
    end)
    it("keeps board-launched Help above its board during wheel scrolling and retains standalone Help", function()
        local m, ns = T.client()
        ns.Help:Show()
        T.eq(ns.Help.frame:GetParent(), m.env.UIParent)
        local strata
        ns.Help.frame.SetFrameStrata = function(_, value) strata = value end
        ns.Board:Show(); ns.Help:Show()
        T.eq(ns.Help.frame:GetParent(), ns.Board.frame)
        T.eq(strata, "DIALOG")
        T.ok(ns.Help.frame:GetFrameLevel() > ns.Board.frame:GetFrameLevel())
        ns.Help.scroll.GetVerticalScrollRange = function() return 500 end
        ns.Help.frame:GetScript("OnMouseWheel")(ns.Help.frame, -1)
        T.eq(ns.Help.scroll:GetVerticalScroll(), 40)
        T.ok(ns.Help.frame:IsVisible()); T.ok(ns.Board.frame:IsVisible())
        ns.Board.frame:Hide(); T.no(ns.Help.frame:IsShown())
        ns.Help:Show(); T.eq(ns.Help.frame:GetParent(), m.env.UIParent)
        T.ok(ns.Help.frame:IsVisible()); T.noErrors(ns)
    end)
    it("scrolls Help from the content and viewport while synchronizing the thumb", function()
        local _, ns = T.client(); ns.Help:Show()
        local scroll, content = ns.Help.scroll, ns.Help.content
        scroll.GetVerticalScrollRange = function() return 500 end
        local thumb
        scroll.ScrollBar = { SetMinMaxValues = function() end, SetValue = function(_, value) thumb = value end }
        local childWheel = T.ok(content:GetScript("OnMouseWheel"))
        local paneWheel = T.ok(scroll:GetScript("OnMouseWheel"))
        childWheel(content, -1); T.eq(scroll:GetVerticalScroll(), 40); T.eq(thumb, 40)
        paneWheel(scroll, -2); T.eq(scroll:GetVerticalScroll(), 120); T.eq(thumb, 120)
        childWheel(content, 1); T.eq(scroll:GetVerticalScroll(), 80)
        T.noErrors(ns)
    end)

    it("consumes wheel input at both ends and when a search removes the scroll range", function()
        local _, ns = T.client(); ns.Help:Show()
        local scroll, content = ns.Help.scroll, ns.Help.content
        local limit = 70
        scroll.GetVerticalScrollRange = function() return limit end
        local wheel = T.ok(content:GetScript("OnMouseWheel"))
        wheel(content, -10); T.eq(scroll:GetVerticalScroll(), 70)
        wheel(content, -1); T.eq(scroll:GetVerticalScroll(), 70)
        wheel(content, 10); T.eq(scroll:GetVerticalScroll(), 0)
        wheel(content, 1); T.eq(scroll:GetVerticalScroll(), 0)
        limit = 0; scroll:SetVerticalScroll(40)
        wheel(content, -1); T.eq(scroll:GetVerticalScroll(), 0)
        T.noErrors(ns)
    end)

    it("registers wheel capture explicitly on new pane and content surfaces", function()
        local m, ns = T.client()
        local original = m.env.CreateFrame
        local enabled = {}
        m.env.CreateFrame = function(...)
            local frame = original(...)
            frame.EnableMouseWheel = function(self, value) enabled[self] = value end
            return frame
        end
        local scroll, content = ns.Widgets.Scroll(m.env.UIParent)
        T.eq(enabled[scroll], true); T.eq(enabled[content], true)
        T.ok(scroll:GetScript("OnMouseWheel")); T.ok(content:GetScript("OnMouseWheel"))
        m.env.CreateFrame = original
        T.noErrors(ns)
    end)

    it("clips overflowing text while keeping the scrollbar outside the clipped subtree", function()
        local m, ns = T.client()
        local original = m.env.CreateFrame
        local clipping = {}
        m.env.CreateFrame = function(kind, name, parent, template)
            local frame = original(kind, name, parent, template)
            frame.SetClipsChildren = function(self, value) clipping[self] = value end
            if template == "UIPanelScrollFrameTemplate" then
                frame.ScrollBar = original("Slider", nil, frame)
            end
            return frame
        end
        local parent = original("Frame", nil, m.env.UIParent)
        local scroll, content = ns.Widgets.Scroll(parent)
        local bar = scroll.ScrollBar
        T.eq(clipping[scroll], true)
        T.eq(content:GetParent(), scroll); T.eq(bar:GetParent(), parent)
        bar:GetScript("OnValueChanged")(bar, 150)
        T.eq(scroll:GetVerticalScroll(), 150)
        scroll:Hide(); T.no(bar:IsShown())
        scroll:Show(); T.ok(bar:IsShown())
        m.env.CreateFrame = original
        T.noErrors(ns)
    end)

    it("handles wheel on the dialog host and arrows with explicit mouse ownership", function()
        local m, ns = T.client()
        local original = m.env.CreateFrame
        local mouse = {}
        m.env.CreateFrame = function(kind, name, parent, template)
            local frame = original(kind, name, parent, template)
            frame.EnableMouse = function(self, value) mouse[self] = value end
            if template == "UIPanelScrollFrameTemplate" then
                local bar = frame.ScrollBar
                bar.ScrollUpButton = original("Button", nil, bar)
                bar.ScrollDownButton = original("Button", nil, bar)
            end
            return frame
        end
        local host = original("Frame", nil, m.env.UIParent)
        local scroll, content = ns.Widgets.Scroll(host)
        local bar = scroll.ScrollBar
        scroll.GetVerticalScrollRange = function() return 80 end
        T.eq(mouse[scroll], true); T.eq(mouse[content], true)
        scroll:GetScript("OnScrollRangeChanged")(scroll, 0, 80)
        T.no(bar.ScrollUpButton:IsEnabled()); T.ok(bar.ScrollDownButton:IsEnabled())
        host:GetScript("OnMouseWheel")(host, -1)
        T.eq(scroll:GetVerticalScroll(), 40)
        bar.ScrollDownButton:Click(); T.eq(scroll:GetVerticalScroll(), 80)
        T.no(bar.ScrollDownButton:IsEnabled()); T.ok(bar.ScrollUpButton:IsEnabled())
        bar.ScrollUpButton:Click(); T.eq(scroll:GetVerticalScroll(), 40)
        m.env.CreateFrame = original
        T.noErrors(ns)
    end)
end)
