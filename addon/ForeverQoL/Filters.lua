local _, F = ...
F.categories = {
    { key = "consumables", class = 0, label = "Consumables" },
    { key = "weapons", class = 2, label = "Weapons" },
    { key = "gems", class = 3, label = "Gems" },
    { key = "armor", class = 4, label = "Armor" },
    { key = "reagents", class = 5, label = "Reagents" },
    { key = "projectiles", class = 6, label = "Projectiles" },
    { key = "tradegoods", class = 7, label = "Trade goods" },
    { key = "recipes", class = 9, label = "Recipes" },
    { key = "quivers", class = 11, label = "Quivers" },
    { key = "quest", class = 12, label = "Quest items" },
    { key = "keys", class = 13, label = "Keys" },
    { key = "misc", class = 15, label = "Miscellaneous" },
    { key = "other", label = "Other item types" },
}
F.tradeCategories = {
    { key = "trade:5", subclass = 5, label = "Cloth" },
    { key = "trade:6", subclass = 6, label = "Leather" },
    { key = "trade:7", subclass = 7, label = "Metal & stone" },
    { key = "trade:9", subclass = 9, label = "Herbs" },
    { key = "trade:10", subclass = 10, label = "Elemental" },
    { key = "trade:12", subclass = 12, label = "Enchanting" },
    { key = "trade:other", label = "Other trade goods" },
}

function F.InitializeDB()
    if type(ForeverQoLDB) ~= "table" then ForeverQoLDB = {} end
    if type(ForeverQoLDB.bankFilters) ~= "table" then
        ForeverQoLDB.bankFilters = {} -- Explicit selection before the first transfer.
    end
    F.filters = ForeverQoLDB.bankFilters
    if F.filters.tradegoods then
        for _, category in ipairs(F.tradeCategories) do F.filters[category.key] = true end
        F.filters.tradegoods = nil
    end
end

function F.Matches(itemID)
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(itemID)
    if class == nil then return false end
    if class == 7 then
        if F.filters.tradegoods then return true end
        for _, category in ipairs(F.tradeCategories) do
            if category.subclass == subclass then return F.filters[category.key] == true end
        end
        return F.filters['trade:other'] == true
    end
    for _, category in ipairs(F.categories) do
        if category.class == class then return F.filters[category.key] == true end
    end
    return F.filters.other == true
end

function F.IsSelected(category)
    if category.key ~= 'tradegoods' then return F.filters[category.key] == true end
    if F.filters.tradegoods then return true end
    for _, trade in ipairs(F.tradeCategories) do
        if not F.filters[trade.key] then return false end
    end
    return true
end

function F.ToggleFilter(category)
    local value = not F.IsSelected(category)
    if category.key == 'tradegoods' then
        F.filters.tradegoods = nil
        for _, trade in ipairs(F.tradeCategories) do F.filters[trade.key] = value end
    else
        F.filters[category.key] = value
    end
end

function F.FilterCount()
    local n = 0
    for _, list in ipairs({ F.categories, F.tradeCategories }) do
        for _, category in ipairs(list) do
            if category.key ~= 'tradegoods' and F.filters[category.key] then n = n + 1 end
        end
    end
    if F.filters.tradegoods then n = n + 1 end
    return n
end

function F.FilterSummary()
    local labels, all = {}, true
    local allTrade = F.IsSelected({ key = 'tradegoods' })
    for _, category in ipairs(F.categories) do
        if category.key == 'tradegoods' then
            if allTrade then
                labels[#labels + 1] = category.label
            else
                all = false
                for _, trade in ipairs(F.tradeCategories) do
                    if F.IsSelected(trade) then labels[#labels + 1] = trade.label end
                end
            end
        elseif F.IsSelected(category) then
            labels[#labels + 1] = category.label
        else
            all = false
        end
    end
    if all then return 'All item types' end
    if #labels == 0 then return 'Item types' end
    if #labels == 1 then return labels[1] end
    return labels[1] .. ' +' .. (#labels - 1)
end
