-- Minimap button: left-click board, right-click tracker, drag to move.
local _, ns = ...
local W = ns.Widgets

local MinimapButton = ns:NewModule("MinimapButton")
local button

local function place()
    local angle = math.rad(ns.db.settings.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function MinimapButton:Create()
    if button or not Minimap then return end
    button = CreateFrame("Button", "TaskboardMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 1)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", ns.Wrap("minimap click", function(_, mouse)
        if mouse == "RightButton" then ns.Commands:Handle("tracker") else ns:Fire("TOGGLE_BOARD") end
    end))
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.settings.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    W.Tooltip(button, function()
        local open = 0
        for _, entry in ipairs(ns.DB:AllCards(false)) do
            if ns.DB:CardRole(entry.board, entry.card) ~= "done" then open = open + 1 end
        end
        return { "Taskboard", open .. " open card(s)", "|cff959ba8Left-click: board   Right-click: tracker   Drag: move|r" }
    end)
    place()
end

function MinimapButton:Refresh()
    if ns.db.settings.minimap.hide then
        if button then button:Hide() end
        return
    end
    self:Create()
    if button then button:Show() end
end

function MinimapButton:OnLogin()
    self:Refresh()
    ns:On("SETTINGS_CHANGED", function(key) if key == "minimapShown" then MinimapButton:Refresh() end end)
end

