-- Goal types: each evaluates live game state into { cur, target, frac, done, text }.
local _, ns = ...
local Util, Parser = ns.Util, ns.Parser

local Goals = ns:NewModule("Goals")

Goals.ICONS = {
    money = "Interface\\Icons\\INV_Misc_Coin_01",
    level = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
    skill = "Interface\\Icons\\INV_Misc_Book_09",
    rep = "Interface\\Icons\\INV_Scroll_03",
    quest = "Interface\\GossipFrame\\AvailableQuestIcon",
    none = "Interface\\Icons\\INV_Misc_Note_01",
}

-- Which goal types each game event can change.
Goals.EVENTS = {
    BAG_UPDATE_DELAYED = { item = true },
    PLAYERBANKSLOTS_CHANGED = { item = true },
    BANKFRAME_OPENED = { item = true },
    PLAYER_MONEY = { money = true },
    PLAYER_LEVEL_UP = { level = true },
    PLAYER_XP_UPDATE = { level = true },
    SKILL_LINES_CHANGED = { skill = true },
    UPDATE_FACTION = { rep = true },
    QUEST_LOG_UPDATE = { quest = true },
    QUEST_TURNED_IN = { quest = true },
}

local function result(cur, target, done, text, frac)
    target = (target and target > 0) and target or 1
    return { cur = cur, target = target, done = done and true or false, text = text,
             frac = Util.Clamp(frac or (cur / target), 0, 1) }
end

-------------------------------------------------------------------------------
-- item
-------------------------------------------------------------------------------
local function evalItem(goal)
    if not goal.itemID then
        -- Pending: bind as soon as a matching item shows up in the bags.
        local id, name = ns.Items:FindInBags(goal.name)
        if id then
            goal.itemID, goal.name, goal.verified = id, name or goal.name, true
            ns.Log:Info("goals", "Bound '%s' to item %d after it appeared in your bags", goal.name, id)
        else
            return result(0, goal.target, false, string.format("%s 0/%d (not looted yet)", goal.name, goal.target))
        end
    end
    local bank = goal.bank ~= false and ns.db.settings.includeBank
    local count = ns.Items:Count(goal.itemID, bank)
    local name = goal.name or ns.Items:Name(goal.itemID) or ("Item " .. goal.itemID)
    return result(count, goal.target, count >= goal.target, string.format("%s %d/%d", name, math.min(count, 999999), goal.target))
end

-------------------------------------------------------------------------------
-- money / level
-------------------------------------------------------------------------------
local function evalMoney(goal)
    local money = GetMoney and GetMoney() or 0
    return result(money, goal.target, money >= goal.target,
        string.format("%s / %s", Util.FormatMoney(money, true), Util.FormatMoney(goal.target, true)))
end

local function evalLevel(goal)
    local level = UnitLevel and UnitLevel("player") or 1
    local xp, xpMax = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
    local exact = level + ((xpMax and xpMax > 0) and (xp / xpMax) or 0)
    local start = goal.start or 1
    if start >= goal.target then start = 1 end
    local frac = (exact - start) / (goal.target - start)
    return result(level, goal.target, level >= goal.target, string.format("Level %.1f / %d", exact, goal.target), frac)
end

-------------------------------------------------------------------------------
-- skill
-------------------------------------------------------------------------------
-- Returns rank, maxRank for a skill by name, or nil if not learned.
function Goals.FindSkill(name)
    local want = Util.Lower(name)
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
        for i = 1, C_SkillInfo.GetNumSkillLines() or 0 do
            local info = C_SkillInfo.GetSkillLineInfo(i)
            if info and not info.isHeader and Util.Lower(info.name) == want then
                return info.rank, info.maxRank
            end
        end
    elseif GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() or 0 do
            local skillName, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader and Util.Lower(skillName) == want then return rank, maxRank end
        end
    end
end

local function evalSkill(goal)
    local rank, maxRank = Goals.FindSkill(goal.name)
    if not rank then
        return result(0, goal.target, false, string.format("%s not learned (0/%d)", goal.name, goal.target))
    end
    local text = string.format("%s %d/%d", goal.name, rank, goal.target)
    if maxRank and maxRank < goal.target and rank >= maxRank then text = text .. " (train for higher cap)" end
    return result(rank, goal.target, rank >= goal.target, text)
end

-------------------------------------------------------------------------------
-- reputation
-------------------------------------------------------------------------------
function Goals.FindFaction(goal)
    if not C_Reputation then return nil end
    if goal.factionID and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(goal.factionID)
        if data and data.name then return data end
    end
    if not C_Reputation.GetNumFactions then return nil end
    local want = Util.Lower(goal.name or "")
    local partial
    for i = 1, C_Reputation.GetNumFactions() or 0 do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.name and (not data.isHeader or data.isHeaderWithRep) then
            local name = Util.Lower(data.name)
            if name == want then return data end
            if not partial and want ~= "" and string.find(name, want, 1, true) then partial = data end
        end
    end
    return partial
end

local function evalRep(goal)
    local data = Goals.FindFaction(goal)
    local standingName = Parser.STANDING_NAMES[goal.target] or "?"
    if not data then
        return result(0, 1, false, string.format("%s: faction not found yet", goal.name or "?"), 0)
    end
    goal.factionID, goal.name = data.factionID, data.name
    local reaction = data.reaction or 4
    local span = (data.nextReactionThreshold or 0) - (data.currentReactionThreshold or 0)
    local within = span > 0 and ((data.currentStanding or 0) - (data.currentReactionThreshold or 0)) / span or 1
    local exact = (reaction - 1) + Util.Clamp(within, 0, 1)
    local done = reaction >= goal.target
    local text
    if done then
        text = string.format("%s: %s", data.name, Parser.STANDING_NAMES[reaction] or "?")
    else
        text = string.format("%s: %s %d/%d -> %s", data.name, Parser.STANDING_NAMES[reaction] or "?",
            (data.currentStanding or 0) - (data.currentReactionThreshold or 0), span, standingName)
    end
    return result(reaction, goal.target, done, text, exact / (goal.target - 1))
end

-------------------------------------------------------------------------------
-- quest
-------------------------------------------------------------------------------
function Goals.FindQuestByName(name)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return nil end
    local want = Util.Lower(name or "")
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and Util.Lower(info.title) == want then return info.questID, info.title end
    end
end

local function evalQuest(goal)
    if not goal.questID then
        local id, title = Goals.FindQuestByName(goal.name)
        if not id then
            return result(0, 3, false, string.format("%s: not in quest log yet", goal.name or "?"))
        end
        goal.questID, goal.name = id, title
        ns.Log:Info("goals", "Bound quest '%s' to quest %d", title, id)
    end
    local q = C_QuestLog
    local name = goal.name or ("Quest " .. goal.questID)
    if q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(goal.questID) then
        return result(3, 3, true, name .. ": turned in")
    end
    local inLog = q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(goal.questID)
    if not inLog then
        return result(0, 3, false, name .. ": not started")
    end
    if q.IsComplete and q.IsComplete(goal.questID) then
        return result(2, 3, false, name .. ": ready to turn in")
    end
    -- Objectives give finer progress: average of each objective's fraction.
    local frac, detail = 1 / 3, nil
    if q.GetQuestObjectives then
        local objectives = q.GetQuestObjectives(goal.questID)
        if objectives and #objectives > 0 then
            local sum = 0
            for _, o in ipairs(objectives) do
                local need = (o.numRequired and o.numRequired > 0) and o.numRequired or 1
                sum = sum + (o.finished and 1 or Util.Clamp((o.numFulfilled or 0) / need, 0, 1))
                if not o.finished and not detail and o.text then detail = o.text end
            end
            frac = (1 + sum / #objectives) / 3
        end
    end
    return result(1, 3, false, name .. ": " .. (detail or "in progress"), frac)
end

Goals.TYPES = {
    item = evalItem, money = evalMoney, level = evalLevel, skill = evalSkill, rep = evalRep, quest = evalQuest,
}

function Goals.Evaluate(goal)
    local fn = goal and Goals.TYPES[goal.type]
    if not fn then return nil end
    return fn(goal)
end

function Goals.Icon(goal)
    if not goal then return Goals.ICONS.none end
    if goal.type == "item" then
        return goal.itemID and ns.Items:Icon(goal.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    return Goals.ICONS[goal.type] or Goals.ICONS.none
end

-- All goals on a card, as a list of { goal, owner } where owner is the card or a subtask.
function Goals.CardGoals(card)
    local list = {}
    if card.goal then list[#list + 1] = { goal = card.goal, owner = card } end
    for _, s in ipairs(card.subtasks or {}) do
        if s.goal then list[#list + 1] = { goal = s.goal, owner = s } end
    end
    return list
end

function Goals.HasGoals(card)
    if card.goal then return true end
    for _, s in ipairs(card.subtasks or {}) do
        if s.goal then return true end
    end
    return false
end
