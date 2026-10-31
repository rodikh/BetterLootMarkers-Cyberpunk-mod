local Utils = require("Modules/Utils.lua")

local ITEM_DROP_CNAME

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {},
    Version = "1.4.1",
}

require("Modules/LootMarkerUI.lua")

function BetterLootMarkers.LoadVersion()
    local versionFile = io.open("version.txt", "r")
    if versionFile == nil then
        return BetterLootMarkers.Version
    end

    local version = versionFile:read("*l")
    versionFile:close()
    if version == nil or version == "" then
        return BetterLootMarkers.Version
    end

    return version
end

function BetterLootMarkers.LogDiagnostics()
    local cetVersion = "unknown"
    local okCet, verResult = pcall(GetVersion)
    if okCet and verResult ~= nil then
        cetVersion = tostring(verResult)
    end

    local gameVersion = "unknown"
    local okHandler, handler = pcall(Game.GetSystemRequestsHandler)
    if okHandler and handler ~= nil then
        local okVer, ver = pcall(handler.GetGameVersion, handler)
        if okVer and ver ~= nil then
            gameVersion = tostring(ver)
        end
    end

    print(("[BetterLootMarkers] CET %s / Game %s"):format(cetVersion, gameVersion))
end

function BetterLootMarkers:new()
    BetterLootMarkers.Settings = require("Modules/Settings.lua")
    BetterLootMarkers.Settings.Init()
    BetterLootMarkers.ScannerFix = require("Modules/ScannerFix.lua")
    BetterLootMarkers.ImmersiveMode = require("Modules/ImmersiveMode.lua")

    registerForEvent("onInit", function()
        BetterLootMarkers.CONTAINER_CNAME = CName.new("BetterLootMarkersContainer")
        ITEM_DROP_CNAME = CName.new("gameItemDropObject")

        BetterLootMarkers.Version = BetterLootMarkers.LoadVersion()
        BetterLootMarkers.ItemTypes = require("Modules/Types.lua")
        print("[BetterLootMarkers] Loaded v" .. BetterLootMarkers.Version)
        BetterLootMarkers.LogDiagnostics()

        ObserveAfter("GameplayMappinController", "UpdateVisibility", function(self)
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        ObserveAfter("GameplayMappinController", "UpdateIcon", function(self)
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        BetterLootMarkers.ScannerFix.Init(ITEM_DROP_CNAME)
        BetterLootMarkers.ImmersiveMode.Init()
    end)

    registerForEvent("onUpdate", function(dt)
        BetterLootMarkers.ImmersiveMode.Tick(dt)
    end)

    registerForEvent("onShutdown", function()
        BetterLootMarkers.Settings.Save()
    end)
end

function BetterLootMarkers.HandleLootMarkersForController(ctrl)
    local ok, err = pcall(BetterLootMarkers._HandleLootMarkers, ctrl)
    if not ok then
        Utils.LogError("Error: " .. tostring(err))
    end
end

function BetterLootMarkers._HandleLootMarkers(ctrl)
    if ctrl == nil then
        return
    end

    local mappin = Utils.TryValue("GameplayMappinController:GetMappin", function()
        return ctrl:GetMappin()
    end)
    if mappin == nil then
        return
    end

    local variant = Utils.TryValue("IMappin:GetVariant", function()
        return mappin:GetVariant()
    end)
    if variant == nil or variant ~= gamedataMappinVariant.LootVariant then
        return
    end

    local iconWidget = ctrl.iconWidget and ctrl.iconWidget.widget
    if iconWidget == nil then
        return
    end

    local parentWidget = iconWidget.parentWidget
    local containerPanel = parentWidget and parentWidget.parentWidget
    if parentWidget == nil or containerPanel == nil then
        return
    end

    BetterLootMarkers.ImmersiveMode.TrackController(ctrl)

    if BetterLootMarkers.Settings.immersiveMode and not BetterLootMarkers.ImmersiveMode.IsScannerActive() then
        iconWidget:SetScale(Vector2.new({ X = 1, Y = 1 }))
        containerPanel:RemoveChildByName(BetterLootMarkers.CONTAINER_CNAME)
        return
    end

    local entityId = Utils.TryValue("IMappin:GetEntityID", function()
        return mappin:GetEntityID()
    end)
    if entityId == nil then
        return
    end

    local target = Utils.TryValue("Game.FindEntityByID", function()
        return Game.FindEntityByID(entityId)
    end)
    if target == nil then
        return
    end

    local itemList = BetterLootMarkers.GetItemListForObject(target)
    if #itemList == 0 then
        containerPanel:RemoveChildByName(BetterLootMarkers.CONTAINER_CNAME)
        return
    end

    local categories = BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, iconWidget)

    parentWidget:SetFitToContent(true)
    parentWidget:SetAnchor(inkEAnchor.TopLeft)
    parentWidget:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))

    containerPanel:RemoveChildByName(BetterLootMarkers.CONTAINER_CNAME)

    local container = BetterLootMarkers.AddPanelToWidget(containerPanel)
    local showCounts = BetterLootMarkers.Settings.showItemCounts

    for categoryKey, category in Utils.sortedCategoryPairs(categories, BetterLootMarkers.ItemTypes.Qualities) do
        local colorIndex = category.isIconic and "Iconic" or category.quality.value
        local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
        local iconKey = BetterLootMarkers.ItemTypes.ItemIcons[categoryKey]
        local needsCountSlot = showCounts and category.count > 1
        local iconParent = container

        if needsCountSlot then
            local slot = inkVerticalPanel.new()
            slot:SetName(CName.new("BetterLootSlot-" .. categoryKey))
            slot:SetFitToContent(true)
            pcall(function()
                slot:SetChildHorizontalAlignment(inkEHorizontalAlign.Center)
            end)
            slot:Reparent(container)
            iconParent = slot
        end

        BetterLootMarkers.AddIconToWidget(iconParent, "BetterLootMappin-" .. categoryKey,
            iconKey, color)

        if needsCountSlot then
            BetterLootMarkers.AddCountBadge(iconParent, "BetterLootCount-" .. categoryKey,
                category.count, color)
        end
    end
end

function BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, icon)
    local isQuest = Utils.TryValue("GameplayMappinController:IsQuest", function()
        return ctrl:IsQuest()
    end)
    if not BetterLootMarkers.Settings.showDefaultMappin and not isQuest then
        icon:SetScale(Vector2.new({
            X = 0,
            Y = 0
        }))
    else
        icon:SetScale(Vector2.new({
            X = 1,
            Y = 1
        }))
    end
end

function BetterLootMarkers.GetItemScore(itemData)
    if itemData.isIconic then
        return BetterLootMarkers.ItemTypes.Qualities.Iconic
    end

    local qualityValue = itemData.quality and itemData.quality.value
    return BetterLootMarkers.ItemTypes.Qualities[qualityValue] or -1
end

function BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    local categories = {}
    for _, item in ipairs(itemList) do
        local quality = Utils.TryValue("RPGManager.GetItemDataQuality", function()
            return RPGManager.GetItemDataQuality(item)
        end)
        local category = BetterLootMarkers.GetLootCategoryForItem(item)
        local isIconic = Utils.TryValue("RPGManager.IsItemIconic", function()
            return RPGManager.IsItemIconic(item)
        end)
        local newItem = {
            quality = quality,
            isIconic = isIconic or false,
        }
        if categories[category] == nil then
            categories[category] = newItem
            categories[category].count = 1
        else
            categories[category].count = categories[category].count + 1
            local currentScore = BetterLootMarkers.GetItemScore(categories[category])
            local newScore = BetterLootMarkers.GetItemScore(newItem)
            if newScore > currentScore then
                local count = categories[category].count
                categories[category] = newItem
                categories[category].count = count
            end
        end
    end

    return categories
end

function BetterLootMarkers.GetLootCategoryForItem(item)
    local name = Utils.TryValue("ItemID:GetNameAsString", function()
        return item:GetNameAsString()
    end)
    if name == "money" then
        return "Money"
    end

    local isBroken = Utils.TryValue("RPGManager.IsItemBroken", function()
        return RPGManager.IsItemBroken(item)
    end)
    if isBroken then
        return "Broken"
    end

    local hasRecipeTag = Utils.TryValue("ItemID:HasTag", function()
        return item:HasTag("Recipe")
    end)
    if hasRecipeTag then
        return "CraftingSpec"
    end

    local itemType = Utils.TryValue("ItemID:GetItemType", function()
        return item:GetItemType()
    end)
    if itemType == nil then
        return "Default"
    end

    local mappedCategory = BetterLootMarkers.ItemTypes.TypeToCategoryByString[tostring(itemType)]
    if mappedCategory ~= nil then
        return mappedCategory
    end

    for cat, list in pairs(BetterLootMarkers.ItemTypes.Categories) do
        if Utils.HasValue(list, itemType) then
            return cat
        end
    end

    return "Default"
end

function BetterLootMarkers.GetItemListForObject(object)
    local transactionSystem = Utils.TryValue("Game.GetTransactionSystem", function()
        return Game.GetTransactionSystem()
    end)
    if transactionSystem == nil then
        return {}
    end

    local _, _, itemList = Utils.Try("TransactionSystem:GetItemList", function()
        return transactionSystem:GetItemList(object)
    end)
    itemList = itemList or {}
    if #itemList == 0 then
        local owner = Utils.TryValue("Entity:GetOwner", function()
            return object:GetOwner()
        end)
        if not owner then
            return {}
        end
        if owner:IsA(ITEM_DROP_CNAME) then
            local _, _, ownerItemList = Utils.Try("TransactionSystem:GetItemList(owner)", function()
                return transactionSystem:GetItemList(owner)
            end)
            itemList = ownerItemList or {}
        end
    end

    return itemList
end

BetterLootMarkers:new()

-- Exposes the mod table via GetMod("BetterLootMarkers") for console debugging.
return BetterLootMarkers
