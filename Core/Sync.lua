-- Board sharing over addon messages (party, raid or guild).
-- Everything received is untrusted: bounded, validated and sanitized.
local _, ns = ...
local Util, DB, Serialize = ns.Util, ns.DB, ns.Serialize

local Sync = ns:NewModule("Sync")
Sync.PREFIX = "QBRD1"
Sync.CHUNK = 220
Sync.MAX_ASSEMBLED = 60000
Sync.MAX_CHUNKS = 300
Sync.TIMEOUT = 60
Sync.MAX_MEMBERS = 40
Sync.stats = { sent = 0, received = 0, rejected = 0, offers = 0, imported = 0, sendFailures = 0, lastError = nil }

local queue = {}        -- { channel, text }
local incoming = {}     -- sender .. msgid -> { total, parts, n, size, t }
local dirtyBoards = {}  -- boardID -> true (progress to broadcast)
local msgCounter = 0
Sync.offers = {}

-------------------------------------------------------------------------------
-- Wire format: "<msgid>:<seq>:<total>:<escaped chunk>"
-------------------------------------------------------------------------------
function Sync.Encode(payload)
    local packed, err = Serialize.Pack(payload)
    if not packed then return nil, err end
    local escaped = Serialize.Escape(packed)
    msgCounter = (msgCounter + 1) % 100000
    local id = string.format("%x", msgCounter)
    local total = math.max(1, math.ceil(#escaped / Sync.CHUNK))
    if total > Sync.MAX_CHUNKS then return nil, "board too large to share" end
    local out = {}
    for i = 1, total do
        -- Chunks are joined before unescaping, so splitting inside "~XX" is fine.
        local chunk = string.sub(escaped, (i - 1) * Sync.CHUNK + 1, i * Sync.CHUNK)
        out[i] = string.format("%s:%d:%d:%s", id, i, total, chunk)
    end
    return out
end

-- Feeds one wire message. Returns payload when a message is complete,
-- nil while waiting, or nil, err when the message is invalid.
function Sync.Receive(sender, text, now)
    now = now or Util.Now()
    local id, seq, total, chunk = string.match(text or "", "^(%x+):(%d+):(%d+):(.*)$")
    seq, total = tonumber(seq), tonumber(total)
    if not id or not seq or not total or seq < 1 or total < 1 or seq > total or total > Sync.MAX_CHUNKS then
        return nil, "malformed message"
    end
    -- Drop stale partial messages.
    for key, entry in pairs(incoming) do
        if now - entry.t > Sync.TIMEOUT then incoming[key] = nil end
    end
    local key = sender .. "\001" .. id
    local entry = incoming[key]
    if not entry then
        local pendingFromSender = 0
        for k in pairs(incoming) do
            if string.sub(k, 1, #sender + 1) == sender .. "\001" then pendingFromSender = pendingFromSender + 1 end
        end
        if pendingFromSender >= 3 then return nil, "too many partial messages from sender" end
        entry = { total = total, parts = {}, n = 0, size = 0, t = now }
        incoming[key] = entry
    end
    if entry.total ~= total then incoming[key] = nil; return nil, "inconsistent chunk count" end
    if not entry.parts[seq] then
        entry.parts[seq] = chunk
        entry.n = entry.n + 1
        entry.size = entry.size + #chunk
    end
    if entry.size > Sync.MAX_ASSEMBLED then incoming[key] = nil; return nil, "message too large" end
    if entry.n < entry.total then return nil end
    incoming[key] = nil
    local escaped = table.concat(entry.parts, "", 1, entry.total)
    local packed, err = Serialize.Unescape(escaped)
    if not packed then return nil, err end
    local payload, perr = Serialize.Unpack(packed)
    if type(payload) ~= "table" then return nil, perr or "bad payload" end
    return payload
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------
function Sync:ChannelFor(target)
    target = Util.Lower(target or "group")
    if target == "guild" then return IsInGuild and IsInGuild() and "GUILD" or nil end
    if target == "raid" then return IsInRaid and IsInRaid() and "RAID" or nil end
    if target == "party" then return IsInGroup and IsInGroup() and "PARTY" or nil end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

function Sync:Send(payload, channel)
    local messages, err = Sync.Encode(payload)
    if not messages then return false, err end
    for _, text in ipairs(messages) do queue[#queue + 1] = { channel = channel, text = text } end
    return true, #messages
end

local function flushQueue()
    local item = table.remove(queue, 1)
    if not item then return end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Sync.PREFIX, item.text, item.channel)
    -- Newer clients return an enum; 0 means success. Older ones return a boolean.
    if ok and (result == nil or result == true or result == 0) then
        Sync.stats.sent = Sync.stats.sent + 1
    else
        Sync.stats.sendFailures = Sync.stats.sendFailures + 1
        Sync.stats.lastError = tostring(result)
        ns.Log:Warn("sync", "Send failed on %s: %s", item.channel, tostring(result))
    end
end

-- Strips per-player runtime data before sharing.
local function exportBoard(board)
    local copy = Util.DeepCopy(board)
    copy.shared = nil
    for _, card in pairs(copy.cards) do
        card.progress, card.char, card.auto = nil, nil, nil
        for _, s in ipairs(card.subtasks) do s.progress = nil end
    end
    return copy
end

function Sync:ShareBoard(board, target)
    if DB:IsReadOnly(board) then return false, "you can only share boards you own" end
    local channel = self:ChannelFor(target)
    if not channel then return false, "you're not in a " .. (target or "group") end
    board.shared = board.shared or { owner = true, members = {}, version = 0 }
    board.shared.owner = true
    board.shared.channel = channel
    board.shared.version = (board.shared.version or 0) + 1
    local ok, info = self:Send({ k = "board", v = board.shared.version, board = exportBoard(board) }, channel)
    if ok then
        ns.Log:Info("sync", "Sharing '%s' with %s (%d message(s))", board.name, channel, info)
        dirtyBoards[board.id] = true
    end
    return ok, ok and channel or info
end

function Sync:StopSharing(board)
    if board.shared and board.shared.owner then
        board.shared = nil
        ns.Log:Info("sync", "Stopped sharing '%s'", board.name)
        ns:Fire("BOARD_CHANGED", board)
    end
end

local function flushProgress()
    for boardID in pairs(dirtyBoards) do
        dirtyBoards[boardID] = nil
        local board = ns.db.boards[boardID]
        if board and board.shared and board.shared.channel then
            local cards = {}
            local any = false
            for id, card in pairs(board.cards) do
                local s = card._summary
                if s and ns.Goals.HasGoals(card) then
                    cards[id] = { f = math.floor((s.frac or 0) * 1000 + 0.5), d = s.done and true or false,
                                  x = card.progress and card.progress.text or nil }
                    any = true
                end
            end
            if any then Sync:Send({ k = "prog", b = boardID, c = cards }, board.shared.channel) end
        end
    end
end
Sync.FlushProgress = flushProgress

-------------------------------------------------------------------------------
-- Receiving
-------------------------------------------------------------------------------
function Sync:HandlePayload(payload, sender, channel)
    if payload.k == "board" then
        local board = DB.NormalizeBoard(payload.board)
        if not board then return false, "invalid board" end
        local existing = ns.db.boards[board.id]
        if existing and existing.shared and existing.shared.owner then return false, "we own this board" end
        -- Never let a received board replace one of our own boards.
        if existing and existing.scope ~= "shared" then return false, "board id collides with a local board" end
        local version = tonumber(payload.v) or 0
        if existing and existing.scope == "shared" and existing.shared and existing.shared.from == sender then
            if version <= (existing.shared.version or 0) then return false, "old version" end
            self:Import(board, sender, channel, version, existing)
            return true
        end
        if ns.db.settings.syncAccept == "never" then return false, "sharing disabled" end
        self.stats.offers = self.stats.offers + 1
        local offerID = Util.NewID("o")
        self.offers[offerID] = { board = board, sender = sender, channel = channel, version = version, t = Util.Now() }
        ns.Log:Info("sync", "%s offered board '%s' (%d cards)", sender, board.name, Util.Count(board.cards))
        ns:Fire("SHARE_OFFER", offerID, self.offers[offerID])
        return true
    elseif payload.k == "prog" then
        local board = type(payload.b) == "string" and ns.db.boards[payload.b]
        if not board or not board.shared or type(payload.c) ~= "table" then return false, "unknown board" end
        local members = board.shared.members
        if not members[sender] and Util.Count(members) >= self.MAX_MEMBERS then return false, "too many members" end
        local entry = {}
        for cardID, p in pairs(payload.c) do
            if board.cards[cardID] and type(p) == "table" then
                entry[cardID] = { frac = Util.Clamp((tonumber(p.f) or 0) / 1000, 0, 1), done = p.d == true,
                                  text = type(p.x) == "string" and Util.Sanitize(p.x, 80) or nil, t = Util.Now() }
            end
        end
        members[sender] = entry
        ns:Fire("BOARD_REFRESH")
        return true
    end
    return false, "unknown message type"
end

function Sync:Import(board, sender, channel, version, existing)
    board.scope = "shared"
    board.owner = nil
    board.shared = { from = sender, version = version, channel = channel,
                     members = existing and existing.shared and existing.shared.members or {} }
    for _, card in pairs(board.cards) do card.char = nil end
    ns.db.boards[board.id] = board
    self.stats.imported = self.stats.imported + 1
    ns.Log:Info("sync", "Imported '%s' from %s (v%d)", board.name, sender, version)
    ns:Fire("BOARDS_CHANGED")
    ns.Engine:MarkAll()
    dirtyBoards[board.id] = true
    return board
end

function Sync:AcceptOffer(offerID)
    local offer = self.offers[offerID]
    if not offer then return false end
    self.offers[offerID] = nil
    local board = self:Import(offer.board, offer.sender, offer.channel, offer.version)
    DB:SetActiveBoard(board)
    return true
end

function Sync:DeclineOffer(offerID)
    self.offers[offerID] = nil
end

local function onAddonMessage(_, prefix, text, channel, sender)
    if prefix ~= Sync.PREFIX then return end
    local me = ns.CharKey()
    if sender == me or sender == UnitName("player") then return end
    local payload, err = Sync.Receive(sender, text)
    if err then
        Sync.stats.rejected = Sync.stats.rejected + 1
        ns.Log:Debug("sync", "Rejected message from %s: %s", tostring(sender), err)
        return
    end
    if not payload then return end
    Sync.stats.received = Sync.stats.received + 1
    local ok, why = Sync:HandlePayload(payload, sender, channel)
    if not ok then ns.Log:Debug("sync", "Ignored %s from %s: %s", tostring(payload.k), sender, tostring(why)) end
end

function Sync:OnLogin()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then
        ns.Log:Warn("sync", "Addon messages are unavailable; sharing is disabled")
        return
    end
    C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    ns:RegisterEvent("CHAT_MSG_ADDON", onAddonMessage)
    self.sendTicker = ns.Ticker(0.15, "sync send", flushQueue)
    self.progressTicker = ns.Ticker(3, "sync progress", flushProgress)
    ns:On("PROGRESS_CHANGED", function(card, board)
        if board.shared and board.shared.channel then dirtyBoards[board.id] = true end
    end)
    -- Owners re-send their board when it changes, so members stay up to date.
    local pendingResend = {}
    ns:On("BOARD_CHANGED", function(board)
        if board.shared and board.shared.owner and board.shared.channel and not pendingResend[board.id] then
            pendingResend[board.id] = true
            ns.After(5, "sync resend", function()
                pendingResend[board.id] = nil
                if board.shared and board.shared.owner then
                    board.shared.version = (board.shared.version or 0) + 1
                    Sync:Send({ k = "board", v = board.shared.version, board = exportBoard(board) }, board.shared.channel)
                end
            end)
        end
    end)
end

function Sync:QueueLength()
    return #queue
end
