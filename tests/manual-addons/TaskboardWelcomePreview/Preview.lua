-- Manual copy preview. It does not reset Taskboard's data or validate first-install creation.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        if type(TaskboardWelcomePreviewDB) == "table" and TaskboardWelcomePreviewDB.shown then return end
        local addon = Taskboard
        if not addon or not addon.DB or not addon.Board or not addon.Editor then return end
        if not addon.DB.WelcomeSpec or not addon.CharKey then return end

        local board = addon.DB:BoardForCharacter(addon.CharKey())
        if not board then return end
        local spec = addon.DB:WelcomeSpec()
        local card
        for _, existing in pairs(board.cards) do
            if existing.title == spec.title then card = existing; break end
        end
        if not card then card = addon.DB:AddCard(board, spec, nil, 1) end
        if not card then return end

        addon.db.ui.activeBoard = board.id
        addon.Board:Show()
        addon.Editor:Open(card, board, "board")
        TaskboardWelcomePreviewDB = { shown = true }
    end)
end)
