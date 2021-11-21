local Utils = require("Modules/Utils.lua")
local Cron = require("Modules/Cron.lua")

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {},
    mappedObjects = {}
}

function BetterLootMarkers:new()
    BetterLootMarkers.Settings = require("Modules/Settings.lua")
    BetterLootMarkers.Settings.Init()

    registerHotkey("DebugMappins", "Debug mappins", function()
        print(" ")
        print("---- Dumping mappins ----")
        local playerPos = Game.GetPlayer():GetWorldPosition()
        print("My position: " .. tostring(playerPos))
        for objId, mappedObject in pairs(BetterLootMarkers.mappedObjects) do
            print("- Object:" .. objId .. " - " .. mappedObject.targetName)
            print("  Length - items:" .. mappedObject.itemCount .. " mappins:" .. table.getn(mappedObject.mappins) .. " - " .. Utils.VectorDistance(playerPos, mappedObject.targetPos))
        end
        print("---- --------------- ----")
    end)

    registerForEvent("onInit", function()
        BetterLootMarkers.ItemTypes = require("Modules/Types.lua")

        Observe("GameplayRoleComponent", "AddMappin", function(self, data)
            if not BetterLootMarkers.IsLootMappin(data) then
                return
            end

            -- before AddMappin is executed the mappin is not yet registered. delay HandleMappinShow to allow the mappin to be activated
            Cron.NextTick(function()
                print("? AddMappin: " .. Utils.GetObjectId(self:GetOwner()) .. ":" .. self:GetOwner():GetClassName().value)
                BetterLootMarkers.HandleMappinShown(self:GetOwner(), self)
            end)
        end)

        Observe("GameplayRoleComponent", "ActivateSingleMappin", function(self, index)
            if not BetterLootMarkers.IsLootMappin(self.mappins[index + 1]) then
                return
            end
            BetterLootMarkers.HandleMappinShown(self:GetOwner(), self)
        end)

        Observe("GameplayRoleComponent", "HideRoleMappins", function(self)
            BetterLootMarkers.ClearMappinsForObject(self:GetOwner())
        end)

        Observe("GameplayRoleComponent", "HideSingleMappin", function(self, index)
            if not BetterLootMarkers.IsLootMappin(self.mappins[index + 1]) then
                return
            end

            BetterLootMarkers.ClearMappinsForObject(self:GetOwner())
        end)

        Observe("GameplayRoleComponent", "OnPreUninitialize", function(self)
            BetterLootMarkers.ClearMappinsForObject(self:GetOwner())
        end)
    end)

    registerForEvent('onUpdate', function(delta)
        -- This is required for Cron to function
        Cron.Update(delta)
    end)
end

function BetterLootMarkers.HandleMappinShown(owner, gameplayRoleComponent)
    if not BetterLootMarkers.mappedObjects[Utils.GetObjectId(owner)] then
        if not BetterLootMarkers.IsLootableRole(gameplayRoleComponent:GetCurrentGameplayRole()) then
            return
        end
        local playerPos = Game.GetPlayer():GetWorldPosition()
        local ownerPos = owner:GetWorldPosition()
        if Utils.VectorDistance(playerPos, ownerPos) > 50 then
            return
        end
        BetterLootMarkers.AddLootMappinsToObject(owner, gameplayRoleComponent)
    else
        BetterLootMarkers.UpdateMappinsForObject(owner, gameplayRoleComponent)
    end
end

function BetterLootMarkers.AddLootMappinsToObject(target, gameplayRoleComponent)
    local itemList = BetterLootMarkers.GetItemListForObject(target)
    local itemCount = table.getn(itemList)
    if itemCount == 0 then
        return
    end

    local categories = BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    local originalMappinId = BetterLootMarkers.FindLootMappinId(gameplayRoleComponent)
    local isHidableMappin = BetterLootMarkers.HandleHideDefaultMappin(target, originalMappinId)

    local offsetIndex = 1;
    local mappins = {};
    for categoryKey, category in pairs(categories) do
        local mappin = BetterLootMarkers.AddMappin(categoryKey, category, target, offsetIndex)
        table.insert(mappins, mappin);
        offsetIndex = offsetIndex + 1
    end

    BetterLootMarkers.mappedObjects[Utils.GetObjectId(target)] = {
        mappins = mappins,
        itemCount = itemCount,
        targetName = target:GetClassName().value,
        targetPos = target:GetWorldPosition(),
        targetOriginalMappinId = Utils.Conditional(isHidableMappin, originalMappinId, nil)
    }
end

function BetterLootMarkers.UpdateMappinsForObject(target, gameplayRoleComponent)
    local mappins = BetterLootMarkers.mappedObjects[Utils.GetObjectId(target)].mappins
    local itemList = BetterLootMarkers.GetItemListForObject(target)
    local itemCount = table.getn(itemList)

    if itemCount == 0 then
        return BetterLootMarkers.ClearMappinsForObject(target)
    end

    local originalMappinId = BetterLootMarkers.FindLootMappinId(gameplayRoleComponent)
    BetterLootMarkers.HandleHideDefaultMappin(target, originalMappinId)

    if itemCount == BetterLootMarkers.mappedObjects[Utils.GetObjectId(target)].itemCount then
        return
    end

    for _, mappinId in pairs(mappins) do
        Game.GetMappinSystem():UnregisterMappin(mappinId)
    end
    BetterLootMarkers.AddLootMappinsToObject(target, gameplayRoleComponent)
end

function BetterLootMarkers.AddMappin(categoryKey, category, target, offsetIndex)
    local mappin = MappinData.new()
    mappin.mappinType = "Mappins.DeviceMappinDefinition"
    mappin.variant = gamedataMappinVariant.LootVariant
    mappin.visibleThroughWalls = false
    mappin.gameplayRole = EGameplayRole.Loot

    local roleMappinData = GameplayRoleMappinData.new()
    roleMappinData.quality = category.quality
    roleMappinData.isIconic = category.isIconic
    roleMappinData.textureID = BetterLootMarkers.ItemTypes.ItemIcons[categoryKey]
    roleMappinData.showOnMiniMap = false
    roleMappinData.visibleThroughWalls = false
    mappin.scriptData = roleMappinData

    local slot = CName.new("roleMappin_" .. categoryKey)
    local zoffset = 0
    if target:IsNPC() then
        zoffset = 0.16
    end
    local offset = Vector3.new(0, 0, zoffset + 0.16 * offsetIndex)
    return Game.GetMappinSystem():RegisterMappinWithObject(mappin, target, slot, offset)
end

function BetterLootMarkers.ClearMappinsForObject(object)
    local mappedObject = BetterLootMarkers.mappedObjects[Utils.GetObjectId(object)]
    if not mappedObject then
        return
    end

    for _, mappinId in pairs(mappedObject.mappins) do
        Game.GetMappinSystem():UnregisterMappin(mappinId)
    end
    BetterLootMarkers.mappedObjects[Utils.GetObjectId(object)] = nil
end

function BetterLootMarkers.HandleHideDefaultMappin(target, originalMappinId)
    local isHidableMappin = false
    if originalMappinId and not target:IsQuest() then
        isHidableMappin = true
        if BetterLootMarkers.Settings.hideDefaultMappin then
            Cron.NextTick(function()
                Game.GetMappinSystem():SetMappinActive(originalMappinId, false);
            end)
        end
    end
    return isHidableMappin
end

function BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    local categories = {}
    for _, item in ipairs(itemList) do
        local quality = RPGManager.GetItemDataQuality(item)
        local category = BetterLootMarkers.GetLootCategoryForItem(item)
        local newItem = {
            quality = quality,
            isIconic = RPGManager.IsItemIconic(item)
        }
        if not Utils.HasKey(categories, category) then
            categories[category] = newItem
        else
            qualityForCompare = quality
            if newItem.isIconic then
                qualityForCompare = BetterLootMarkers.ItemTypes.Qualities.Iconic
            end
            if BetterLootMarkers.ItemTypes.Qualities[qualityForCompare.value] > BetterLootMarkers.ItemTypes.Qualities[categories[category].quality.value] then
                categories[category] = newItem
            end
        end
    end

    return categories
end

function BetterLootMarkers.GetLootCategoryForItem(item)
    if item:GetNameAsString() == "money" then
        return "Money"
    end
    for type, list in pairs(BetterLootMarkers.ItemTypes.Categories) do
        if Utils.HasValue(list, item:GetItemType()) then
            return type
        end
    end

    return "Default"
end

function BetterLootMarkers.GetItemListForObject(object)
    local _, itemList = GetSingleton("gameTransactionSystem"):GetItemList(object)
    local itemCount = table.getn(itemList)
    local owner = object:GetOwner()
    if itemCount == 0 and not owner then
        return {}
    end
    if itemCount == 0 and owner:IsA(CName.new("gameItemDropObject")) then
        object = object:GetOwner()
        _, itemList = GetSingleton("gameTransactionSystem"):GetItemList(object)
    end

    return itemList
end

function BetterLootMarkers.IsLootableRole(role)
    return Utils.HasValue(BetterLootMarkers.ItemTypes.LootableGameplayRoles, role)
end

function BetterLootMarkers.IsLootMappin(mappin)
    return mappin ~= nil and (mappin.mappinVariant == gamedataMappinVariant.LootVariant or mappin.gameplayRole == EGameplayRole.Loot)
end

function BetterLootMarkers.FindLootMappinId(gameplayRoleComponent)
    for _, v in pairs(gameplayRoleComponent.mappins) do
        if BetterLootMarkers.IsLootMappin(v) then
            return v.id
        end
    end
    return nil
end

function BetterLootMarkers.HandleToggleHideDefaultMappin()
    for _, mappedObject in pairs(BetterLootMarkers.mappedObjects) do
        if mappedObject.targetOriginalMappinId then
            Game.GetMappinSystem():SetMappinActive(mappedObject.targetOriginalMappinId, not BetterLootMarkers.Settings.hideDefaultMappin);
        end
    end
end

return BetterLootMarkers:new()
