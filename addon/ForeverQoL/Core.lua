local addonName, F = ...
local developmentBuild = nil -- Replaced only in the local installation by tools/deploy.ps1.
F.version = developmentBuild or C_AddOns.GetAddOnMetadata(addonName, "Version")
function F.Print(message)
    print("|cffd6b86aForeverQoL|r " .. message)
end
SLASH_FOREVERQOL1 = "/fql"
SLASH_FOREVERQOL2 = "/foreverqol"
SlashCmdList.FOREVERQOL = function()
    F.Print(F.version .. " — open the bank and choose Item types, then Deposit or Withdraw.")
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CURSOR_CHANGED")
events:RegisterEvent("BANK_TABS_CHANGED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then F.InitializeDB() end
        F.AttachBankControls()
    elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        F.StopTransfer(event == "BANKFRAME_CLOSED" and "Bank closed." or "Combat started.")
        F.RefreshControls()
    else
        F.AttachBankControls()
        F.RefreshControls()
    end
end)
