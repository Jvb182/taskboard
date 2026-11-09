-- Quick-add syntax: "Get 20 Peacebloom #herbs !high @bank *daily >doing ; sub ; sub"
local _, ns = ...
local Util = ns.Util

local Parser = {}
ns.Parser = Parser

-- Deliberately match whole errands, not arbitrary sentences containing "mail".
function Parser.IsMailCheck(text)
    local title = Util.Trim(Util.Lower(text or ""):gsub("[%p%s]+", " "))
    local verb, rest = title:match("^(%a+)%s+(.+)$")
    if verb ~= "check" and verb ~= "open" and verb ~= "visit" then return false end
    rest = rest:gsub("^my ", ""):gsub("^the ", "")
    return rest == "mail" or rest == "mailbox" or rest == "mail box"
end

Parser.STANDINGS = { hated = 1, hostile = 2, unfriendly = 3, neutral = 4, friendly = 5, honored = 6, revered = 7, exalted = 8 }
Parser.STANDING_NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
Parser.SKILLS = {
    "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "inscription", "jewelcrafting",
    "leatherworking", "mining", "skinning", "tailoring", "cooking", "first aid", "fishing", "lockpicking",
    "riding", "archaeology",
}
Parser.PRIORITY = { low = 1, l = 1, ["1"] = 1, med = 2, medium = 2, m = 2, ["2"] = 2, high = 3, h = 3, ["3"] = 3, urgent = 3 }
Parser.NPC_ALIASES = { bank = "bank", vendor = "vendor", merchant = "vendor", mail = "mail", mailbox = "mail",
                       ah = "ah", auction = "ah", auctionhouse = "ah", trainer = "trainer" }
Parser.COLUMN_ALIASES = { todo = "todo", doing = "doing", progress = "doing", wip = "doing", done = "done" }

local ITEM_VERBS = { "get", "collect", "gather", "farm", "loot", "mine", "skin", "buy", "craft", "make",
                     "have", "need", "fish", "pick", "grab", "obtain", "find", "bring", "stack" }
local MONEY_VERBS = { "save", "have", "earn", "make", "reach", "get", "farm", "hit", "bank" }
local CUT_WORDS = { " for ", " from ", " to ", " in ", " at ", " before ", " by ", " (" }

local function startsWithVerb(lower, verbs)
    for _, v in ipairs(verbs) do
        local rest = string.match(lower, "^" .. v .. "%s+(.*)$")
        if rest then return rest, v end
    end
end

-- Candidate item names, longest first: "Peacebloom for alchemy" -> {"Peacebloom for alchemy", "Peacebloom"}
local function nameCandidates(name)
    local out = { Util.Trim(name) }
    local lower = " " .. Util.Lower(name) .. " "
    for _, cut in ipairs(CUT_WORDS) do
        local i = string.find(lower, cut, 2, true)
        if i then
            local candidate = Util.Trim(string.sub(name, 1, i - 2))
            if candidate ~= "" and not Util.IndexOf(out, candidate) then out[#out + 1] = candidate end
        end
    end
    -- Shortest candidates are least likely to include trailing words; try the
    -- full text first, then progressively cut versions.
    return out
end

local function itemGoal(name, count, linkID)
    local goal = { type = "item", target = math.max(1, math.min(tonumber(count) or 1, 100000)), bank = true }
    if linkID then
        goal.itemID, goal.name, goal.verified = linkID, name, true
        return goal
    end
    local candidates = nameCandidates(name)
    for _, candidate in ipairs(candidates) do
        local id, resolvedName, source = ns.Items:Resolve(candidate)
        if id then
            goal.itemID, goal.name = id, resolvedName or candidate
            goal.verified = source ~= "known" or nil
            goal.source = source
            return goal
        end
    end
    -- Not resolvable yet: track by name; the first matching loot binds it.
    goal.name = candidates[#candidates]
    goal.source = "pending"
    return goal
end

-- Parses a goal from free text. Returns goal or nil.
function Parser.ParseGoal(text)
    text = Util.Trim(text)
    if text == "" then return nil end

    local questID, questName = Util.ParseQuestLink(text)
    if questID then return { type = "quest", questID = questID, name = questName } end

    local linkID, linkName = Util.ParseItemLink(text)
    if linkID then
        local plain = Util.StripLinks(text)
        local count = string.match(plain, "(%d+)%s*[xX]?%s*%[") or string.match(plain, "%]%s*[xX]?%s*(%d+)")
        return itemGoal(linkName, count or 1, linkID)
    end

    local lower = Util.Lower(text)
    local plainLower = Util.Lower(Util.StripLinks(text))

    local qname = string.match(text, "^[Qq]uest:%s*(.+)$")
    if qname then return { type = "quest", name = Util.Trim(qname) } end

    local level = string.match(plainLower, "%f[%a]level%s+(%d+)") or string.match(plainLower, "%f[%a]lvl%s*(%d+)")
        or string.match(plainLower, "%f[%a]ding%s+(%d+)")
    if level then return { type = "level", target = tonumber(level), start = UnitLevel and UnitLevel("player") or nil } end

    -- Reputation: "Honored with Stormwind", "get exalted argent dawn"
    local body = startsWithVerb(plainLower, { "get", "reach", "hit", "be" }) or plainLower
    for word, index in pairs(Parser.STANDINGS) do
        local faction = string.match(body, "^" .. word .. "%s+with%s+(.+)$") or string.match(body, "^" .. word .. "%s+(.+)$")
            or string.match(plainLower, "%f[%a]" .. word .. "%s+with%s+(.+)$")
        if faction then
            faction = Util.Trim((faction:gsub("^the%s+", "")))
            -- Restore the original capitalization from the input text.
            local s = string.find(lower, faction, 1, true)
            local pretty = s and string.sub(text, s, s + #faction - 1) or faction
            return { type = "rep", name = pretty, target = index }
        end
    end

    -- Skill: "Herbalism 150", "get tailoring to 150"
    for _, skill in ipairs(Parser.SKILLS) do
        local target = string.match(plainLower, "%f[%a]" .. skill .. "%s+to%s+(%d+)") or string.match(plainLower, "%f[%a]" .. skill .. "%s+(%d+)")
        if target then
            local pretty = skill:gsub("(%a)(%a*)", function(a, b) return string.upper(a) .. b end)
            return { type = "skill", name = pretty, target = tonumber(target) }
        end
    end

    -- Money: needs a verb ("save 100g") or to be only money ("100g 50s").
    local copper = Util.ParseMoney(plainLower)
    if copper and copper > 0 then
        local onlyMoney = Util.Trim(plainLower:gsub("%d+%s*[gsc]%f[%A]", ""):gsub("gold", "")) == ""
        if onlyMoney or startsWithVerb(plainLower, MONEY_VERBS) then
            return { type = "money", target = copper }
        end
    end

    -- Items: "get 20 Peacebloom", "20x Peacebloom", "20 Peacebloom", "Peacebloom x20",
    -- also mid-sentence: "Raid prep: get 10 Peacebloom"
    local plain = Util.StripLinks(text)
    local lowerPlain = Util.Lower(plain)
    local afterVerb = startsWithVerb(lowerPlain, ITEM_VERBS)
    if not afterVerb then
        for _, v in ipairs(ITEM_VERBS) do
            local s, e = string.find(lowerPlain, "%f[%a]" .. v .. "%s+%d")
            if s then
                afterVerb = string.sub(lowerPlain, e)
                break
            end
        end
    end
    local subject = afterVerb and string.sub(plain, #plain - #afterVerb + 1) or plain
    local count, name = string.match(subject, "^(%d+)%s*[xX]%s+(.+)$")
    if not count then count, name = string.match(subject, "^(%d+)[xX](%a.+)$") end
    if not count then count, name = string.match(subject, "^(%d+)%s+(.+)$") end
    if not count then
        name, count = string.match(subject, "^(.-)%s+[xX]%s*(%d+)$")
    end
    if count and name and not string.match(name, "^%d+$") then
        return itemGoal(name, count)
    end
    return nil
end

-- Parses a full quick-add line into a card spec.
-- Returns spec, warnings (list of strings).
function Parser.Parse(text)
    local warnings = {}
    text = Util.Trim(text)
    local parts = Util.Split(text, ";")
    local spec = { tags = {}, priority = 0, subtasks = {} }

    -- Pulls card-level tokens (#tag !prio @where *repeat >column) out of a part,
    -- wherever they appear in the line. Returns the remaining text.
    local function extract(part)
        local quoted, quoteCount = {}, 0
        part = part:gsub('@"([^"]+)"', function(zone)
            quoteCount = quoteCount + 1
            local token = "\001" .. quoteCount .. "\002"
            quoted[token] = Util.Trim(zone)
            return token
        end)
        local kept = {}
        for word in string.gmatch(part, "%S+") do
            local lw = Util.Lower(word)
            local tag = string.match(word, "^#([%w%-_]+)$")
            local prio = string.match(lw, "^!(%w+)$")
            local at = string.match(word, "^@(.+)$")
            local recur = string.match(lw, "^%*(%a+)$")
            local col = string.match(lw, "^>(%a+)$")
            if quoted[word] then
                spec.where = { zone = quoted[word] }
            elseif tag then
                local t = Util.Lower(tag)
                if not Util.IndexOf(spec.tags, t) then spec.tags[#spec.tags + 1] = t end
            elseif prio and Parser.PRIORITY[prio] then
                spec.priority = Parser.PRIORITY[prio]
            elseif at and not string.find(word, "|", 1, true) then
                local npc = Parser.NPC_ALIASES[Util.Lower(at)]
                if npc then spec.where = { npc = npc } else spec.where = { zone = (at:gsub("_", " ")) } end
            elseif recur == "daily" or recur == "weekly" then
                spec.recur = recur
            elseif col and Parser.COLUMN_ALIASES[col] then
                spec.columnRole = Parser.COLUMN_ALIASES[col]
            else
                kept[#kept + 1] = word
            end
        end
        -- Words are rejoined with single spaces (links survive intact).
        return table.concat(kept, " ")
    end

    local titleRaw = extract(Util.Trim(parts[1]))
    spec.goal = Parser.ParseGoal(titleRaw)
    spec.title = Util.Trim(Util.StripLinks(titleRaw))

    for i = 2, #parts do
        local sub = Util.Trim(extract(parts[i]))
        if sub ~= "" then
            local goal = Parser.ParseGoal(sub)
            spec.subtasks[#spec.subtasks + 1] = { text = Util.Trim(Util.StripLinks(sub)), goal = goal }
            if goal and goal.type == "item" and goal.source == "pending" then
                warnings[#warnings + 1] = string.format("'%s' isn't known yet; it will start counting the first time you loot one.", goal.name)
            end
        end
    end

    if spec.title == "" and #spec.subtasks > 0 then
        spec.title = spec.subtasks[1].text
    end
    if spec.goal and spec.goal.type == "item" and spec.goal.source == "pending" then
        warnings[#warnings + 1] = string.format("'%s' isn't known yet; it will start counting the first time you loot one.", spec.goal.name)
    end
    return spec, warnings
end

-- Human-readable description of a goal, for previews and tooltips.
function Parser.Describe(goal)
    if not goal then return "No goal (manual card)" end
    if goal.type == "item" then
        return string.format("Have %d x %s%s", goal.target, goal.name or ("item " .. tostring(goal.itemID)),
            goal.itemID and "" or " (waiting for first loot)")
    elseif goal.type == "money" then
        return "Have " .. Util.FormatMoney(goal.target)
    elseif goal.type == "level" then
        return "Reach level " .. goal.target
    elseif goal.type == "skill" then
        return string.format("%s %d", goal.name, goal.target)
    elseif goal.type == "rep" then
        return string.format("%s with %s", Parser.STANDING_NAMES[goal.target] or "?", goal.name or "?")
    elseif goal.type == "quest" then
        return "Complete quest: " .. (goal.name or ("#" .. tostring(goal.questID)))
    end
    return "?"
end

