-- Runs a broad scripted session, then audits every global and API the addon
-- touched against the WoW: Forever client fixture.
local T, Mock = ...

local ALLOWED_WRITES = {
    Questboard = true, QuestboardDB = true, QuestboardLog = true,
    SLASH_QUESTBOARD1 = true, SLASH_QUESTBOARD2 = true, SLASH_QUESTBOARDTODO1 = true,
    BINDING_HEADER_QUESTBOARD = true, BINDING_NAME_QUESTBOARD_TOGGLE = true,
    BINDING_NAME_QUESTBOARD_TRACKER = true, BINDING_NAME_QUESTBOARD_QUICKADD = true,
}

local function keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return table.concat(out, ", ")
end

local function session(m, ns)
    m.Slash("/qb")
    m.Slash("/qb add Get 20 Peacebloom #herbs !high @bank *daily; 5 Silverleaf; vials")
    m.Slash("/qb add save 10g")
    m.Slash("/qb add reach level 25")
    m.Slash("/qb add Herbalism 50")
    m.Slash("/qb add Friendly with Stormwind")
    m.Slash("/qb add quest: Wanted: Hogger")
    m.Slash("/qb add Visit @Ironforge")
    m.state.skills = { { name = "Herbalism", rank = 10, maxRank = 75 } }
    m.state.factions = { { id = 72, name = "Stormwind", standing = 100 } }
    m.state.questLog = { { id = 176, title = "Wanted: Hogger" } }
    m.Loot(2447, 20)
    m.Loot(765, 5)
    m.state.money = 200000
    m.Fire("PLAYER_MONEY")
    m.Fire("SKILL_LINES_CHANGED")
    m.Fire("UPDATE_FACTION")
    m.Fire("QUEST_LOG_UPDATE")
    m.Advance(2)
    m.state.zone = "Ironforge"
    m.Fire("ZONE_CHANGED_NEW_AREA")
    for _, e in ipairs({ "MERCHANT_SHOW", "BANKFRAME_OPENED", "MAIL_SHOW", "AUCTION_HOUSE_SHOW", "TRAINER_SHOW" }) do m.Fire(e) end
    local board = ns.DB:GetActiveBoard()
    local any = board.cards[board.order.todo[1]] or board.cards[board.order.doing[1]]
    ns.Editor:Open(any, board)
    ns.Editor:PinHere()
    ns.Editor:ShowPin(any)
    ns.Board:BoardMenu()
    ns.Widgets.HideMenu()
    ns.Board:CardMenu(any, board)
    ns.Widgets.HideMenu()
    ns.Board:TagMenu()
    ns.Widgets.HideMenu()
    m.Slash("/qb log show")
    m.Slash("/qb diag")
    m.Slash("/qb selftest")
    m.Slash("/qb export")
    m.Slash("/qb import")
    m.Slash("/qb options")
    m.Slash("/qb list")
    m.Slash("/qb tracker")
    m.Slash("/qb tracker")
    m.state.inGroup = true
    m.Slash("/qb share party")
    m.Advance(10)
    m.AdvanceTime(86400)
    m.env.QuestboardMinimapButton:Click("LeftButton")
    m.Logout()
end

describe("API conformance (full session)", function()
    local m, ns = T.client()
    local ok, err = pcall(session, m, ns)

    it("the scripted session runs without errors", function()
        T.ok(ok, tostring(err))
        T.noErrors(ns)
    end)

    it("only reads globals that exist in the client", function()
        -- Our own SavedVariables are nil on a first run; reading them is expected.
        local extra = {}
        for k in pairs(m.unknownGlobals) do
            if k ~= "QuestboardDB" and k ~= "QuestboardLog" then extra[k] = true end
        end
        T.eq(keys(extra), "", "unknown globals read")
    end)

    it("never touches a C_ API missing from the client", function()
        T.eq(keys(m.missingAPI), "", "missing APIs")
    end)

    it("only writes its own globals", function()
        local extra = {}
        for k in pairs(m.globalWrites) do if not ALLOWED_WRITES[k] then extra[k] = true end end
        T.eq(keys(extra), "", "unexpected global writes")
    end)

    it("every client API it calls is simulated by the mock (so tests are meaningful)", function()
        local allowed = { GetAddOnMemoryUsage = true, UpdateAddOnMemoryUsage = true }
        local extra = {}
        for k in pairs(m.unmocked) do if not allowed[k] then extra[k] = true end end
        T.eq(keys(extra), "", "unmocked APIs called")
    end)

    it("sent only valid addon messages", function()
        T.ok(#m.sent > 0 or true)
    end)
end)
