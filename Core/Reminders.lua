-- Reminders: cards pinned to a zone or an NPC type pop up at the right moment.
-- Smart reminders: at the AH, list item goals still missing; at the bank, list
-- goal items that are sitting in the bank.
local _, ns = ...
local Util, DB, Goals = ns.Util, ns.DB, ns.Goals

local Reminders = ns:NewModule("Reminders")
Reminders.COOLDOWN = 300
Reminders.stats = { shown = 0 }

local lastShown = {} -- cardID .. context -> time

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
            lines[#lines + 1] = { card = entry.card, board = entry.board, text = entry.card.title }
        end
    end
    return lines
end

function Reminders:ForNPC(npc, now)
    local lines = {}
    for _, entry in ipairs(openCards()) do
        local where = entry.card.where
        if where and where.npc == npc and ready(entry.card.id .. ":" .. npc, now) then
            lines[#lines + 1] = { card = entry.card, board = entry.board, text = entry.card.title }
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

local function show(title, lines)
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
    ns.After(5, "login zone reminder", zoneChanged)
    for event, npc in pairs(self.NPC_EVENTS) do
        ns:RegisterEvent(event, function()
            if not ns.db.settings.reminders then return end
            show("At the " .. DB.NPCS[npc], self:ForNPC(npc, Util.Now()))
        end)
    end
end

function Reminders:ResetCooldowns()
    lastShown = {}
end
