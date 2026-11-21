local _, F = ...
local job, controls

local function ActiveBank()
    if not BankFrame or not BankFrame:IsShown() then return nil end
    return BankFrame:GetActiveBankType()
end

local function Available(bankType)
    return bankType ~= nil and ActiveBank() == bankType and C_Bank.CanUseBank(bankType)
        and not InCombatLockdown() and not CursorHasItem()
end

function F.RefreshControls()
    if not controls then return end
    local enabled = Available(ActiveBank()) and F.FilterCount() > 0
    for _, key in ipairs({ 'deposit', 'withdraw' }) do
        local button = controls[key]
        local stopping = job and job.deposit == (key == 'deposit')
        local canClick = stopping or (not job and enabled) or false
        button:SetEnabled(canClick)
        button.Icon:SetTexture(stopping and 'Interface\\Buttons\\WHITE8X8' or button.arrowTexture)
        button.Icon:SetSize(stopping and 8 or 20, stopping and 8 or 20)
        button.Icon:SetVertexColor(stopping and 1 or 0.9, stopping and 0.4 or 0.9, stopping and 0.3 or 0.9)
        button.Icon:SetAlpha(canClick and 1 or 0.4)
    end
    controls.filter:SetEnabled(not job)
    controls.filter:SetDefaultText(F.FilterSummary())
end

function F.StopTransfer(reason)
    if not job then return end
    local old = job
    job = nil
    F.RefreshControls()
    F.Print(string.format("%s: %d item(s) moved. %s", old.deposit and "Deposit" or "Withdraw", old.moved, reason or "Done."))
end

local function BagIDs()
    local ids = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do ids[#ids + 1] = bag end
    return ids
end

local function Eligible(bag, slot, info, deposit, bankType)
    if not info or info.isLocked or not info.itemID or not F.Matches(info.itemID) then return false end
    if deposit then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if not C_Bank.IsItemAllowedInBankType(bankType, location) then return false end
        -- Do not silently discard a vendor refund window through a bulk action.
        if bankType == Enum.BankType.Account and C_Item.CanBeRefunded(location) then return false end
    end
    return true
end

local function Step()
    local current = job
    if not current then return end
    if not Available(current.bankType) then F.StopTransfer("Stopped: bank changed, closed, or unavailable."); return end
    local pending = current.pending
    if pending then
        local info = C_Container.GetContainerItemInfo(pending.bag, pending.slot)
        if not info or info.itemID ~= pending.itemID or info.stackCount < pending.count then
            current.moved = current.moved + (info and info.itemID == pending.itemID and (pending.count - info.stackCount) or pending.count)
            current.pending = nil
            if info and info.itemID == pending.itemID and info.stackCount > 0 then
                F.StopTransfer("Stopped: only part of the stack moved; check free space."); return
            end
        elseif GetTime() - pending.started > 2 then
            F.StopTransfer("Stopped: item did not move; check free space and bank restrictions."); return
        else
            C_Timer.After(0.1, function() if job == current then Step() end end)
            return
        end
    end
    while current.index <= #current.queue do
        local entry = current.queue[current.index]
        current.index = current.index + 1
        local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
        -- Revalidate every slot: another bag action must never transfer a replacement item.
        if info and info.itemID == entry.itemID and Eligible(entry.bag, entry.slot, info, current.deposit, current.bankType) then
            current.pending = { bag = entry.bag, slot = entry.slot, itemID = info.itemID, count = info.stackCount, started = GetTime() }
            C_Container.UseContainerItem(entry.bag, entry.slot, nil, current.deposit and current.bankType or nil, false)
            C_Timer.After(0.15, function() if job == current then Step() end end)
            return
        end
    end
    F.StopTransfer("Done.")
end

function F.StartTransfer(deposit)
    local bankType = ActiveBank()
    if job or not Available(bankType) then return end
    if F.FilterCount() == 0 then F.Print("Choose item types first."); return end
    local ids = deposit and BagIDs() or C_Bank.FetchPurchasedBankTabIDs(bankType)
    local queue = {}
    for _, bag in ipairs(ids or {}) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if Eligible(bag, slot, info, deposit, bankType) then
                queue[#queue + 1] = { bag = bag, slot = slot, itemID = info.itemID }
            end
        end
    end
    if #queue == 0 then F.Print("No matching transferable items. Locked, uncached, restricted or refundable account-bank items are skipped."); return end
    job = { deposit = deposit, bankType = bankType, queue = queue, index = 1, moved = 0 }
    F.RefreshControls()
    Step()
end

local function Tooltip(button, text, deposit)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local stopping = job and job.deposit == deposit
        GameTooltip:SetText(stopping and 'Stop transfer' or (deposit and 'Deposit' or 'Withdraw'))
        GameTooltip:AddLine(stopping and 'Stop the current transfer. Items already moved stay in their destination.' or text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function F.AttachBankControls()
    if controls or not BankFrame or not BankFrame.BankItemSearchBox or not F.filters then return end
    controls = {}
    local function Button(key, arrow, action)
        local button = CreateFrame("Button", nil, BankFrame, "UIPanelButtonTemplate")
        button:SetSize(24, 22)
        button:SetText('')
        button.arrowTexture = 'Interface\\Buttons\\UI-ScrollBar-Scroll' .. arrow .. 'Button-Up'
        button.Icon = button:CreateTexture(nil, 'OVERLAY')
        button.Icon:SetPoint('CENTER')
        button:SetScript("OnClick", action)
        controls[key] = button
        return button
    end
    local function Action(deposit)
        if job then
            if job.deposit == deposit then F.StopTransfer('Stopped.') end
        else
            F.StartTransfer(deposit)
        end
    end
    Tooltip(Button("deposit", "Down", function() Action(true) end),
        "Deposit matching items from your bags into the selected bank. Uses all purchased storage in that bank.", true)
    Tooltip(Button("withdraw", "Up", function() Action(false) end),
        "Withdraw matching items from all purchased storage in the selected bank into your bags.", false)
    local dropdown = CreateFrame("DropdownButton", nil, BankFrame, "WowStyle1DropdownTemplate")
    dropdown:SetSize(142, 22)
    -- Fit only our widgets into the existing header. All Blizzard anchors and
    -- dimensions remain owned by Blizzard, including the background artwork.
    dropdown:SetPoint('RIGHT', BankFrame.BankItemSearchBox, 'LEFT', -8, 0)
    controls.withdraw:SetPoint('RIGHT', dropdown, 'LEFT', -4, 0)
    controls.deposit:SetPoint('RIGHT', controls.withdraw, 'LEFT', -4, 0)
    controls.filter = dropdown
    dropdown:SetupMenu(function(_, root)
        root:CreateTitle("Transfer item types")
        local function SelectAll(value)
            for _, list in ipairs({ F.categories, F.tradeCategories }) do
                for _, category in ipairs(list) do
                    if category.key ~= 'tradegoods' then F.filters[category.key] = value end
                end
            end
            F.filters.tradegoods = nil
            F.RefreshControls()
        end
        root:CreateButton("Select all", function() SelectAll(true) end)
        root:CreateButton("Clear all", function() SelectAll(false) end)
        root:CreateDivider()
        local function Add(parent, category)
            local checkbox = parent:CreateCheckbox(category.label, function() return F.IsSelected(category) end,
                function() F.ToggleFilter(category); F.RefreshControls() end)
            checkbox:SetResponse(MenuResponse.Refresh)
            checkbox:SetSelectionIgnored()
            return checkbox
        end
        for _, category in ipairs(F.categories) do
            local checkbox = Add(root, category)
            if category.key == "tradegoods" then
                for _, trade in ipairs(F.tradeCategories) do Add(checkbox, trade) end
            end
        end
    end)
    BankFrame:HookScript("OnHide", function() F.StopTransfer("Bank closed.") end)
    BankFrame:HookScript("OnShow", F.RefreshControls)
    hooksecurefunc(BankFrame, "SetTab", function()
        if job then F.StopTransfer("Bank changed.") end
        F.RefreshControls()
    end)
    F.RefreshControls()
end
