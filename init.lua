local Utils = require("Modules/Utils.lua")

local ITEM_DROP_CNAME

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {},
    Version = "1.4.0",
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
end

function BetterLootMarkers.HandleLootMarkersForController(ctrl)
    local ok, err = pcall(BetterLootMarkers._HandleLootMarkers, ctrl)
    if not ok then
        print("[BetterLootMarkers] Error: " .. tostring(err))
    end
end

function BetterLootMarkers._HandleLootMarkers(ctrl)
    if ctrl == nil then
        return
    end

    local mappin = ctrl:GetMappin()
    if mappin == nil then
        return
    end

    local variant = mappin:GetVariant()
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

    local target = Game.FindEntityByID(mappin:GetEntityID())
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
    if not BetterLootMarkers.Settings.showDefaultMappin and not ctrl:IsQuest() then
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
        local quality = RPGManager.GetItemDataQuality(item)
        local category = BetterLootMarkers.GetLootCategoryForItem(item)
        local newItem = {
            quality = quality,
            isIconic = RPGManager.IsItemIconic(item),
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
    if item:GetNameAsString() == "money" then
        return "Money"
    end

    if RPGManager.IsItemBroken(item) then
        return "Broken"
    end

    if item:HasTag("Recipe") then
        return "CraftingSpec"
    end

    local itemType = item:GetItemType()
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
    local transactionSystem = Game.GetTransactionSystem()
    if transactionSystem == nil then
        return {}
    end

    local _, itemList = transactionSystem:GetItemList(object)
    itemList = itemList or {}
    if #itemList == 0 then
        local owner = object:GetOwner()
        if not owner then
            return {}
        end
        if owner:IsA(ITEM_DROP_CNAME) then
            _, itemList = transactionSystem:GetItemList(owner)
            itemList = itemList or {}
        end
    end

    return itemList
end

return BetterLootMarkers:new()
