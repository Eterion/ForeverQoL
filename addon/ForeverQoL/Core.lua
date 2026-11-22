local addonName, F = ...
local developmentBuild = nil -- Replaced only in the local installation by tools/deploy.ps1.
F.version = developmentBuild or C_AddOns.GetAddOnMetadata(addonName, "Version")
function F.Print(message)
    print("|cffd6b86aForeverQoL|r " .. message)
end
SLASH_FOREVERQOL1 = "/fql"
SLASH_FOREVERQOL2 = "/foreverqol"
local blockedCount, lastBlocked = 0, nil
SlashCmdList.FOREVERQOL = function(command)
    if command == 'errors' then
        F.Print('Blocked actions since reload: ' .. blockedCount .. (lastBlocked and ('; last: ' .. lastBlocked) or ''))
        return
    end
    F.Print(F.version .. " — bank transfers, quest-item markers and movable windows enabled. Drag a window title; right-click it to reset.")
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CURSOR_CHANGED")
events:RegisterEvent("BANK_TABS_CHANGED")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(_, event, name, action)
    if event == 'ADDON_ACTION_BLOCKED' or event == 'ADDON_ACTION_FORBIDDEN' then
        if name == addonName then blockedCount, lastBlocked = blockedCount + 1, tostring(action) end
    elseif event == "ADDON_LOADED" then
        if name == addonName then
            F.InitializeDB()
            F.QuestItems.Initialize()
            F.Windows.Initialize()
        end
        F.AttachBankControls()
    elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        F.StopTransfer(event == "BANKFRAME_CLOSED" and "Bank closed." or "Combat started.")
        F.RefreshControls()
    else
        F.AttachBankControls()
        F.RefreshControls()
    end
end)
