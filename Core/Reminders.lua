-- Reminders: cards pinned to a zone or an NPC type pop up at the right moment.
-- Smart reminders: at the AH, list item goals still missing; at the bank, list
-- goal items that are sitting in the bank.
local _, ns = ...
local Util, DB, Goals = ns.Util, ns.DB, ns.Goals

local Reminders = ns:NewModule("Reminders")
Reminders.COOLDOWN = 300
Reminders.MAIL_RADIUS = 35 -- yards
Reminders.MAIL_LEAVE_RADIUS = 50
Reminders.stats = { shown = 0 }

local lastShown = {} -- cardID .. context -> time
local mailOpen, nearMailbox = false, false
local mailVisitSeen = {}
local show

Reminders.NPC_EVENTS = {
    MERCHANT_SHOW = "vendor", BANKFRAME_OPENED = "bank", MAIL_SHOW = "mail",
    AUCTION_HOUSE_SHOW = "ah", TRAINER_SHOW = "trainer",
}

local function openCards()
    local out = {}
    for _, entry in ipairs(DB:AllCards(false)) do
        local role = DB:CardRole(entry.board, entry.card)
        if role ~= "done" and ns.Engine:Owns(entry.card, entry.board) then out[#out + 1] = entry end
    end
    return out
end

local function ready(key, now)
    if lastShown[key] and now - lastShown[key] < Reminders.COOLDOWN then return false end
    lastShown[key] = now
    return true
end

function Reminders.ZoneMatches(want, zone, subzone)
    want = Util.Lower(Util.Trim(want))
    if want == "" then return false end
    for _, z in ipairs({ zone or "", subzone or "" }) do
        local lz = Util.Lower(z)
        if lz ~= "" and (lz == want or string.sub(lz, 1, #want) == want) then return true end
    end
    return false
end

-- Returns the list of lines to show for a zone change.
function Reminders:ForZone(zone, subzone, now)
    local lines = {}
    for _, entry in ipairs(openCards()) do
        local where = entry.card.where
        if where and where.zone and Reminders.ZoneMatches(where.zone, zone, subzone)
            and ready(entry.card.id .. ":zone", now) then
            lines[#lines + 1] = { card = entry.card, board = entry.board, text = DB:DisplayTitle(entry.card) }
        end
    end
    return lines
end

function Reminders:ForNPC(npc, now, context, seen)
    local lines = {}
    for _, entry in ipairs(openCards()) do
        local where = entry.card.where
        if where and where.npc == npc and (not seen or not seen[entry.card.id]) then
            if seen then seen[entry.card.id] = true end
            if ready(entry.card.id .. ":" .. (context or npc), now) then
                lines[#lines + 1] = { card = entry.card, board = entry.board, text = DB:DisplayTitle(entry.card) }
            end
        end
    end
    if ns.db.settings.smartReminders and (npc == "ah" or npc == "bank") then
        for _, entry in ipairs(openCards()) do
            for _, g in ipairs(Goals.CardGoals(entry.card)) do
                local goal = g.goal
                if goal.type == "item" and goal.itemID then
                    local bags = ns.Items:Count(goal.itemID, false)
                    local all = ns.Items:Count(goal.itemID, true)
                    local name = goal.name or ("item " .. goal.itemID)
                    if npc == "ah" and all < goal.target and ready(entry.card.id .. ":ah:" .. goal.itemID, now) then
                        lines[#lines + 1] = { card = entry.card, board = entry.board,
                            text = string.format("Still need %d %s (%s)", goal.target - all, name, entry.card.title) }
                    elseif npc == "bank" and all > bags and ready(entry.card.id .. ":bank:" .. goal.itemID, now) then
                        lines[#lines + 1] = { card = entry.card, board = entry.board,
                            text = string.format("%d %s in your bank (%s)", all - bags, name, entry.card.title) }
                    end
                end
            end
        end
    end
    return lines
end

-- The client exposes player coordinates, but no mailbox locations. Remember
-- the position when a mailbox is opened, then remind on later approaches.
local function playerWorldPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    if C_Map.GetWorldPosFromMapPos then
        local ok, continent, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, pos)
        if ok and type(continent) == "number" and world then
            local x, y = tonumber(world.x), tonumber(world.y)
            if x and y and x == x and y == y then return continent, x, y end
        end
    end
    -- Some maps return no world position. Same-map dimensions still give a
    -- useful distance in yards without confusing different map coordinate sets.
    if C_Map.GetMapWorldSize then
        local ok, width, height = pcall(C_Map.GetMapWorldSize, mapID)
        local x, y = tonumber(pos.x), tonumber(pos.y)
        if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0
            and x and y and x == x and y == y then
            return "map:" .. tostring(mapID), x * width, y * height
        end
    end
end

local function distanceSquared(a, continent, x, y)
    if type(a) ~= "table" or a.continent ~= continent or type(a.x) ~= "number" or type(a.y) ~= "number" then return end
    return (a.x - x) ^ 2 + (a.y - y) ^ 2
end

function Reminders:LearnMailbox()
    local continent, x, y = playerWorldPosition()
    if not continent then return end
    local spots = ns.db.mailboxes
    if type(spots) ~= "table" then spots = {}; ns.db.mailboxes = spots end
    for _, spot in ipairs(spots) do
        local d2 = distanceSquared(spot, continent, x, y)
        if d2 and d2 < 20 * 20 then return end
    end
    -- Bound SavedVariables growth, even after many alts and mailboxes.
    if #spots >= 200 then table.remove(spots, 1) end
    spots[#spots + 1] = { continent = continent, x = x, y = y }
    ns.Log:Info("reminders", "Learned mailbox location (%d saved)", #spots)
end

function Reminders:CheckNearbyMailbox(now)
    if mailOpen then return end
    local continent, x, y = playerWorldPosition()
    if not continent then
        mailVisitSeen = {}
        if nearMailbox then nearMailbox = false; ns:Fire("TRACKER_SETTINGS") end
        return
    end
    local best
    for _, spot in ipairs(ns.db.mailboxes or {}) do
        local d2 = distanceSquared(spot, continent, x, y)
        if d2 and (not best or d2 < best) then best = d2 end
    end
    if not best or best > self.MAIL_LEAVE_RADIUS ^ 2 then
        mailVisitSeen = {}
        if nearMailbox then nearMailbox = false; ns:Fire("TRACKER_SETTINGS") end
        return
    end
    if not nearMailbox then
        if best > self.MAIL_RADIUS ^ 2 then return end
        nearMailbox = true
        ns:Fire("TRACKER_SETTINGS")
    end
    if ns.db.settings.reminders then
        show("Near a mailbox", self:ForNPC("mail", now, "mail-near", mailVisitSeen))
    end
end

function Reminders:IsNearMailbox()
    return nearMailbox
end

function Reminders:MailboxStatus()
    local continent, x, y = playerWorldPosition()
    local nearest
    for _, spot in ipairs(ns.db.mailboxes or {}) do
        local d2 = continent and distanceSquared(spot, continent, x, y)
        if d2 and (not nearest or d2 < nearest) then nearest = d2 end
    end
    local eligible = 0
    for _, entry in ipairs(openCards()) do
        if entry.card.where and entry.card.where.npc == "mail" then eligible = eligible + 1 end
    end
    return string.format("Mailbox: %d learned, %d eligible task(s), position %s, nearest %s, window %s, nearby %s, reminders %s",
        #(ns.db.mailboxes or {}), eligible, continent and "available" or "unavailable",
        nearest and string.format("%.1f yards", math.sqrt(nearest)) or "none on this map/continent",
        mailOpen and "open" or "closed", nearMailbox and "yes" or "no", ns.db.settings.reminders and "on" or "off")
end

function Reminders:CompleteMailChecks()
    if not ns.db.settings.autoComplete then return end
    for _, entry in ipairs(openCards()) do
        local card = entry.card
        if card.where and card.where.npc == "mail" and not card.goal and #card.subtasks == 0 then
            if ns.Parser.IsMailCheck(card.title) then
                local done = DB:ColumnByRole(entry.board, "done")
                if done then DB:MoveCard(entry.board, card.id, done.id, nil, "mailbox opened") end
            end
        end
    end
end

show = function(title, lines)
    if #lines == 0 then return end
    Reminders.stats.shown = Reminders.stats.shown + #lines
    ns.Log:Info("reminders", "%s: %d reminder(s)", title, #lines)
    ns:Fire("REMINDER", title, lines)
end

function Reminders:OnLogin()
    local function zoneChanged()
        if not ns.db.settings.reminders then return end
        local zone = GetRealZoneText and GetRealZoneText() or ""
        local sub = GetSubZoneText and GetSubZoneText() or ""
        show("Now in " .. zone, self:ForZone(zone, sub, Util.Now()))
    end
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", zoneChanged)
    ns:RegisterEvent("ZONE_CHANGED", zoneChanged)
    ns:RegisterEvent("ZONE_CHANGED_INDOORS", zoneChanged)
    ns.After(5, "login zone reminder", zoneChanged)
    for event, npc in pairs(self.NPC_EVENTS) do
        ns:RegisterEvent(event, function()
            if npc == "mail" then
                mailOpen = true; nearMailbox = true; self:LearnMailbox()
                ns:Fire("TRACKER_SETTINGS")
                self:CompleteMailChecks()
                for _, entry in ipairs(openCards()) do
                    if entry.card.where and entry.card.where.npc == "mail" then mailVisitSeen[entry.card.id] = true end
                end
            end
            if not ns.db.settings.reminders then return end
            show("At the " .. DB.NPCS[npc], self:ForNPC(npc, Util.Now()))
        end)
    end
    ns:RegisterEvent("MAIL_CLOSED", function() mailOpen = false end)
    ns.Ticker(3, "nearby mailbox", function() self:CheckNearbyMailbox(Util.Now()) end)
end

function Reminders:ResetCooldowns()
    lastShown = {}
end

