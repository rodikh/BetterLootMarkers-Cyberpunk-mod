local Utils = require("Modules/Utils.lua")
local Ref = require("Modules/Ref.lua")
local Cron = require("Modules/Cron.lua")

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {},
    mappedObjects = {}
}

function BetterLootMarkers:new()
    BetterLootMarkers.Settings = require("Modules/Settings.lua")
    BetterLootMarkers.Settings.Init()

    registerForEvent("onInit", function()
        BetterLootMarkers.ItemTypes = require("Modules/Types.lua")

        Observe("GameplayRoleComponent", "ShowSingleMappin;Int32", function(self, index)
            if not BetterLootMarkers.IsLootMappin(self.mappins[index + 1]) then
                return
            end
            BetterLootMarkers.HandleMappinShown(self:GetOwner(), self)
        end)

        Observe("GameplayRoleComponent", "ShowSingleMappin;Int32GameplayRoleMappinData", function(self, index, _)
            if not BetterLootMarkers.IsLootMappin(self.mappins[index + 1]) then
                return
            end
            BetterLootMarkers.HandleMappinShown(self:GetOwner(), self)
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
    if BetterLootMarkers.FindMappedObjectByTarget(owner) == nil then
        if not BetterLootMarkers.IsLootableRole(gameplayRoleComponent:GetCurrentGameplayRole()) then
            return
        end
        if owner:IsNPC() and not owner:IsIncapacitated() then
            return
        end
        local playerPos = Game.GetPlayer():GetWorldPosition()
        local ownerPos = owner:GetWorldPosition()
        if Utils.VectorDistance(playerPos, ownerPos) > 50 then
            return
        end
        BetterLootMarkers.AddLootMappinsToObject(owner)
    else
        BetterLootMarkers.UpdateMappinsForObject(owner)
    end
end

function BetterLootMarkers.AddLootMappinsToObject(target)
    local itemList = BetterLootMarkers.GetItemListForObject(target)
    local itemCount = table.getn(itemList)
    if itemCount == 0 then
        return
    end

    local categories = BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    BetterLootMarkers.HandleHideDefaultMappin(target)

    local offsetIndex = 1;
    local mappins = {};
    for categoryKey, category in pairs(categories) do
        local mappin = BetterLootMarkers.AddMappin(categoryKey, category, target, offsetIndex)
        table.insert(mappins, mappin);
        offsetIndex = offsetIndex + 1
    end

    BetterLootMarkers.AddMappedObject({
        target = Ref.Weak(target),
        mappins = mappins,
        itemCount = itemCount
    })
end

function BetterLootMarkers.UpdateMappinsForObject(target)
    local mappedObject = BetterLootMarkers.FindMappedObjectByTarget(target)
    local mappins = mappedObject.mappins
    local itemList = BetterLootMarkers.GetItemListForObject(target)
    local itemCount = table.getn(itemList)

    if itemCount == 0 then
        return BetterLootMarkers.ClearMappinsForObject(target)
    end

    BetterLootMarkers.HandleHideDefaultMappin(target)

    if itemCount == mappedObject.itemCount then
        return
    end

    for _, mappinId in ipairs(mappins) do
        Game.GetMappinSystem():UnregisterMappin(mappinId)
    end
    BetterLootMarkers.AddLootMappinsToObject(target)
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
    local mappedObject = BetterLootMarkers.FindMappedObjectByTarget(object)
    if not mappedObject then
        return
    end

    for _, mappinId in ipairs(mappedObject.mappins) do
        Game.GetMappinSystem():UnregisterMappin(mappinId)
    end
    BetterLootMarkers.RemoveMappedObjectByTarget(object)
end

function BetterLootMarkers.HandleHideDefaultMappin(target)
    if not target:IsQuest() then
        if BetterLootMarkers.Settings.hideDefaultMappin then
            Cron.NextTick(function()
                local gameplayRoleComponent = target:FindComponentByName("GameplayRole")
                local originalMappinId = BetterLootMarkers.FindLootMappinId(gameplayRoleComponent)
                Game.GetMappinSystem():SetMappinActive(originalMappinId, false);
            end)
        end
    end
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
    local _, itemList = Game.GetTransactionSystem():GetItemList(object)
    local itemCount = table.getn(itemList)
    local owner = object:GetOwner()
    if itemCount == 0 and not owner then
        return {}
    end
    if itemCount == 0 and owner:IsA(CName.new("gameItemDropObject")) then
        object = object:GetOwner()
        _, itemList = Game.GetTransactionSystem():GetItemList(object)
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
    for _, v in ipairs(gameplayRoleComponent.mappins) do
        if BetterLootMarkers.IsLootMappin(v) then
            return v.id
        end
    end
    return nil
end

function BetterLootMarkers.HandleToggleHideDefaultMappin()
    for _, mappedObject in ipairs(BetterLootMarkers.mappedObjects) do
        if not mappedObject.target:IsQuest() then
            local gameplayRoleComponent = mappedObject.target:FindComponentByName("GameplayRole")
            local originalMappinId = BetterLootMarkers.FindLootMappinId(gameplayRoleComponent)
            Game.GetMappinSystem():SetMappinActive(originalMappinId, not BetterLootMarkers.Settings.hideDefaultMappin);
        end
    end
end

function BetterLootMarkers.AddMappedObject(mappedObject)
    table.insert(BetterLootMarkers.mappedObjects, mappedObject)
end

function BetterLootMarkers.RemoveMappedObjectByTarget(object)
    local objectId = Utils.GetObjectId(object)
    for i,v in ipairs(BetterLootMarkers.mappedObjects) do
        if objectId == Utils.GetObjectId(v.target) then
            table.remove(BetterLootMarkers.mappedObjects, i)
            return
        end
    end
end

function BetterLootMarkers.FindMappedObjectByTarget(object)
    local objectId = Utils.GetObjectId(object)
    for _,v in ipairs(BetterLootMarkers.mappedObjects) do
        if objectId == Utils.GetObjectId(v.target) then
            return v
        end
    end
    return nil
end


return BetterLootMarkers:new()
