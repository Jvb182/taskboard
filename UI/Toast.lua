-- Celebration and reminder toasts (stacked, fading), plus share-offer popups.
local _, ns = ...
local Util, Theme, W = ns.Util, ns.Theme, ns.Widgets

local Toast = ns:NewModule("Toast")
Toast.LIFETIME = 5
Toast.REMINDER_LIFETIME = 8
Toast.FADE = 1
Toast.MAX = 4
Toast.stats = { shown = 0 }

local pool, active = {}, {}
local recentCompletions, batchPending = {}, false

local SOUNDS = {
    quest = "IG_QUEST_LIST_COMPLETE",
    click = "IG_MAINMENU_OPTION_CHECKBOX_ON",
    chime = "IG_CHAT_EMOTE_BUTTON",
    page = "IG_ABILITY_PAGE_TURN",
    coin = "IG_BACKPACK_COIN_OK",
    message = "TELL_MESSAGE",
    alert = "ALARM_CLOCK_WARNING_1",
}
Toast.SOUND_CHOICES = {
    { "off", "Off" }, { "click", "Soft click" }, { "chime", "Chime" }, { "quest", "Quest complete" },
    { "page", "Page turn" }, { "coin", "Coin" }, { "message", "Message" }, { "alert", "Alert" },
}
local lastSound = {}

function Toast:PlaySound(kind, preview)
    if not ns.db.settings.sounds then return end
    local selection = ns.db.settings.soundEvents[kind]
    local id = SOUNDKIT and SOUNDKIT[SOUNDS[selection] or ""]
    local now = GetTime()
    if not preview and lastSound[kind] and now - lastSound[kind] < 0.15 then return end
    lastSound[kind] = now
    if id and PlaySound then pcall(PlaySound, id) end
end

local function layout()
    local y = -120
    for _, t in ipairs(active) do
        t:ClearAllPoints()
        t:SetPoint("TOP", UIParent, "TOP", 0, y)
        y = y - t:GetHeight() - 4
    end
end

local function release(t)
    t:Hide()
    t:SetScript("OnUpdate", nil)
    local i = Util.IndexOf(active, t)
    if i then table.remove(active, i) end
    pool[#pool + 1] = t
    layout()
end

local function create()
    local t = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    t:SetSize(340, 58)
    t:SetFrameStrata("DIALOG")
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Theme.Panel(t, Theme.colors.window, Theme.colors.accent)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(38, 38)
    t.icon:SetPoint("LEFT", 10, 0)
    t.title = W.Text(t, "GameFontNormal")
    t.title:SetPoint("TOPLEFT", 56, -9)
    t.title:SetPoint("RIGHT", -10, 0)
    t.body = W.Text(t, "GameFontHighlightSmall")
    t.body:SetPoint("TOPLEFT", 56, -28)
    t.body:SetPoint("RIGHT", -10, 0)
    t.body:SetWordWrap(true)
    t.body:SetJustifyV("TOP")
    t:SetScript("OnClick", ns.Wrap("toast click", function(self, button)
        if button == "LeftButton" and self.card then ns.Editor:Open(self.card, self.board) end
        release(self)
    end))
    return t
end

-- Shows a toast. opts = { title, body, icon, color, card, board, sound }
function Toast:Show(opts)
    if opts.sound then self:PlaySound(opts.sound) end
    if not ns.db.settings.toasts then return end
    if #active >= self.MAX then release(active[1]) end
    local t = table.remove(pool) or create()
    local reminder = opts.reminder == true
    t.card, t.board = opts.card, opts.board
    t.lifetime = reminder and self.REMINDER_LIFETIME or self.LIFETIME
    t:SetWidth(reminder and 390 or 340)
    t.icon:SetSize(reminder and 44 or 38, reminder and 44 or 38)
    t.icon:ClearAllPoints()
    t.icon:SetPoint("LEFT", reminder and 11 or 10, 0)
    t.title:SetFontObject(reminder and "GameFontNormalLarge" or "GameFontNormal")
    t.title:ClearAllPoints()
    t.title:SetPoint("TOPLEFT", reminder and 66 or 56, reminder and -10 or -9)
    t.title:SetPoint("RIGHT", reminder and -12 or -10, 0)
    t.body:SetFontObject(reminder and "GameFontHighlight" or "GameFontHighlightSmall")
    t.body:ClearAllPoints()
    t.body:SetPoint("TOPLEFT", reminder and 66 or 56, reminder and -34 or -28)
    t.body:SetPoint("RIGHT", reminder and -12 or -10, 0)
    t.icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_Note_01")
    t.title:SetText(opts.title or "")
    t.body:SetText(opts.body or "")
    local lines = select(2, string.gsub(opts.body or "", "\n", "\n")) + 1
    if reminder then
        t:SetHeight(math.max(70, 48 + math.max(t.body:GetStringHeight(), lines * 17)))
    else
        t:SetHeight(math.max(58, 40 + lines * 13))
    end
    t:SetBackdropBorderColor(unpack(opts.color or Theme.colors.accent))
    t:SetAlpha(1)
    t.age = 0
    t:SetScript("OnUpdate", function(self, elapsed)
        self.age = self.age + elapsed
        if self:IsMouseOver() then self.age = math.min(self.age, self.lifetime - 0.5) end
        if self.age > self.lifetime then
            local a = 1 - (self.age - self.lifetime) / Toast.FADE
            if a <= 0 then release(self) else self:SetAlpha(a) end
        end
    end)
    active[#active + 1] = t
    t:Show()
    layout()
    self.stats.shown = self.stats.shown + 1
    return t
end

-- Several completions in one moment (e.g. at login) become one toast.
local function flushCompletions()
    batchPending = false
    local list = recentCompletions
    recentCompletions = {}
    if #list == 0 then return end
    if #list == 1 then
        local c = list[1]
        Toast:Show({ title = "Task complete!", body = c.card.title, icon = ns.Goals.Icon(c.card.goal),
                     color = Theme.colors.good, card = c.card, board = c.board, sound = "complete" })
    else
        local names = {}
        for i = 1, math.min(5, #list) do names[#names + 1] = list[i].card.title end
        if #list > 5 then names[#names + 1] = "...and " .. (#list - 5) .. " more" end
        Toast:Show({ title = #list .. " cards complete!", body = table.concat(names, "\n"), color = Theme.colors.good, sound = "complete" })
    end
    for _, c in ipairs(list) do ns.Print("|cff5cd673Complete:|r %s", c.card.title) end
end

function Toast:OnLogin()
    ns:On("CARD_MOVED", function(card, board, from, to, reason)
        if reason == "daily reset" or reason == "weekly reset" then return end
        if ns.DB:Column(board, to).role ~= "done" then Toast:PlaySound("move") return end
        recentCompletions[#recentCompletions + 1] = { card = card, board = board }
        if not batchPending then
            batchPending = true
            ns.After(0.5, "toast batch", flushCompletions)
        end
    end)
    ns:On("CARD_STARTED", function(card)
        ns.Log:Info("toast", "Started: %s", card.title)
    end)
    ns:On("SUBTASK_COMPLETED", function(card, board, subtask)
        Toast:Show({ title = "Subtask done", body = subtask.text .. "  |cff959ba8(" .. card.title .. ")|r",
                     icon = ns.Goals.Icon(subtask.goal), card = card, board = board, sound = "subtask" })
    end)
    ns:On("REMINDER", function(title, lines)
        local body = {}
        for i = 1, math.min(6, #lines) do body[#body + 1] = "- " .. lines[i].text end
        if #lines > 6 then body[#body + 1] = "...and " .. (#lines - 6) .. " more" end
        Toast:Show({ title = "Reminder: " .. title, body = table.concat(body, "\n"), icon = "Interface\\Icons\\INV_Misc_Note_02",
                     color = Theme.colors.warn, card = lines[1].card, board = lines[1].board, sound = "reminder", reminder = true })
        for _, line in ipairs(lines) do ns.Print("|cffffb84dReminder:|r %s", line.text) end
    end)
    ns:On("SHARE_OFFER", function(offerID, offer)
        if ns.db.settings.syncAccept == "never" then return end
        StaticPopup_Show("TASKBOARD_SHARE_OFFER", string.match(offer.sender, "^[^%-]+") or offer.sender,
            offer.board.name .. " (" .. Util.Count(offer.board.cards) .. " cards)", offerID)
    end)
    StaticPopupDialogs["TASKBOARD_SHARE_OFFER"] = {
        text = "%s wants to share a Taskboard with you:\n\n%s",
        button1 = ACCEPT or "Accept", button2 = DECLINE or "Decline",
        OnAccept = function(_, offerID)
            if ns.Sync:AcceptOffer(offerID) then ns.Print("Shared board added. Your progress is shared with the group.") end
        end,
        OnCancel = function(_, offerID) ns.Sync:DeclineOffer(offerID) end,
        timeout = 60, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

function Toast:Active()
    return active
end

