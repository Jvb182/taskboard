-- Item resolution (name -> itemID), counting and verification.
local _, ns = ...
local Util = ns.Util

local Items = ns:NewModule("Items")

-- Common gathering and crafting materials, so "Get 20 Peacebloom" resolves even
-- before the item is in the client cache. Every ID from this table is verified
-- against the real item name before it is trusted (see Items:Verify).
Items.KNOWN = {
    -- Herbs
    ["peacebloom"] = 2447, ["silverleaf"] = 765, ["earthroot"] = 2449, ["mageroyal"] = 785,
    ["briarthorn"] = 2450, ["stranglekelp"] = 3820, ["bruiseweed"] = 2453, ["wild steelbloom"] = 3355,
    ["grave moss"] = 3369, ["kingsblood"] = 3356, ["liferoot"] = 3357, ["fadeleaf"] = 3818,
    ["goldthorn"] = 3821, ["khadgar's whisker"] = 3358, ["wintersbite"] = 3819, ["firebloom"] = 4625,
    ["purple lotus"] = 8831, ["arthas' tears"] = 8836, ["sungrass"] = 8838, ["blindweed"] = 8839,
    ["ghost mushroom"] = 8845, ["gromsblood"] = 8846, ["golden sansam"] = 13464, ["dreamfoil"] = 13463,
    ["mountain silversage"] = 13465, ["plaguebloom"] = 13466, ["icecap"] = 13467, ["black lotus"] = 13468,
    -- Ore, bars and stone
    ["copper ore"] = 2770, ["tin ore"] = 2771, ["iron ore"] = 2772, ["silver ore"] = 2775,
    ["gold ore"] = 2776, ["mithril ore"] = 3858, ["truesilver ore"] = 7911, ["thorium ore"] = 10620,
    ["copper bar"] = 2840, ["tin bar"] = 3576, ["bronze bar"] = 2841, ["iron bar"] = 3575,
    ["steel bar"] = 3859, ["mithril bar"] = 3860, ["thorium bar"] = 12359, ["silver bar"] = 2842,
    ["gold bar"] = 3577, ["truesilver bar"] = 6037,
    ["rough stone"] = 2835, ["coarse stone"] = 2836, ["heavy stone"] = 2838, ["solid stone"] = 7912, ["dense stone"] = 12365,
    -- Cloth
    ["linen cloth"] = 2589, ["wool cloth"] = 2592, ["silk cloth"] = 4306, ["mageweave cloth"] = 4338,
    ["runecloth"] = 14047, ["felcloth"] = 14256,
    -- Leather and hides
    ["light leather"] = 2318, ["medium leather"] = 2319, ["heavy leather"] = 4234, ["thick leather"] = 4304,
    ["rugged leather"] = 8170, ["light hide"] = 783, ["medium hide"] = 4232, ["heavy hide"] = 4235,
    ["thick hide"] = 8169, ["rugged hide"] = 8171,
    -- Enchanting
    ["strange dust"] = 10940, ["soul dust"] = 11083, ["vision dust"] = 11137, ["dream dust"] = 11176,
    ["illusion dust"] = 16204, ["lesser magic essence"] = 10938, ["greater magic essence"] = 10939,
}

Items.pending = {}     -- itemID -> { name = expected, callbacks }
Items.nameCache = {}   -- lower name -> itemID learned this session
Items.stats = { resolved = 0, verified = 0, mismatches = 0, bagScans = 0 }

local function bagRange()
    local last = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
    return 0, last
end

-- Scans the player's bags for an item whose name matches (case-insensitive).
function Items:FindInBags(name)
    local want = Util.Lower(Util.Trim(name))
    if want == "" or not C_Container then return nil end
    self.stats.bagScans = self.stats.bagScans + 1
    local first, last = bagRange()
    for bag = first, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                local id, linkName = Util.ParseItemLink(info.hyperlink)
                if linkName and Util.Lower(linkName) == want then
                    return info.itemID or id, linkName
                end
            end
        end
    end
end

-- Resolves free text or a link to an itemID. Returns id, name, source.
-- source: "link", "cache", "bags", "known" (needs verification) or nil.
function Items:Resolve(text)
    local id, name = Util.ParseItemLink(text)
    if id then return id, name, "link" end
    name = Util.Trim(Util.StripLinks(text))
    if name == "" then return nil end
    local lower = Util.Lower(name)
    if self.nameCache[lower] then return self.nameCache[lower], name, "cache" end
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, instantID = pcall(C_Item.GetItemInfoInstant, name)
        if ok and type(instantID) == "number" then return instantID, name, "cache" end
    end
    local bagID, bagName = self:FindInBags(name)
    if bagID then
        self.nameCache[lower] = bagID
        return bagID, bagName, "bags"
    end
    if self.KNOWN[lower] then return self.KNOWN[lower], name, "known" end
    return nil, name
end

function Items:Count(itemID, includeBank)
    if not itemID or not C_Item or not C_Item.GetItemCount then return 0 end
    local ok, count = pcall(C_Item.GetItemCount, itemID, includeBank and true or false)
    return ok and tonumber(count) or 0
end

function Items:Icon(itemID)
    if itemID and C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Items:Name(itemID)
    if itemID and C_Item and C_Item.GetItemNameByID then
        return C_Item.GetItemNameByID(itemID)
    end
end

-- Confirms itemID really has the expected name. Calls back(ok, actualName).
-- Uses the cache if possible, otherwise asks the server and waits.
function Items:Verify(itemID, expected, callback)
    local actual = self:Name(itemID)
    if actual then
        local ok = Util.Lower(actual) == Util.Lower(expected)
        if ok then self.stats.verified = self.stats.verified + 1 else self.stats.mismatches = self.stats.mismatches + 1 end
        callback(ok, actual)
        return
    end
    local entry = self.pending[itemID] or { name = expected, callbacks = {} }
    table.insert(entry.callbacks, callback)
    self.pending[itemID] = entry
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function onItemData(_, itemID, success)
    local entry = Items.pending[itemID]
    if not entry then return end
    Items.pending[itemID] = nil
    local actual = success ~= false and Items:Name(itemID) or nil
    local ok = actual ~= nil and Util.Lower(actual) == Util.Lower(entry.name)
    if actual then
        if ok then Items.stats.verified = Items.stats.verified + 1 else Items.stats.mismatches = Items.stats.mismatches + 1 end
    end
    for _, cb in ipairs(entry.callbacks) do ns.Safe("item verify", cb, ok, actual) end
end

function Items:OnInit()
    ns:RegisterEvent("ITEM_DATA_LOAD_RESULT", onItemData)
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", onItemData)
end
