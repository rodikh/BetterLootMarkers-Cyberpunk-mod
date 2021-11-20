local Utils = {}

function Utils.HasValue(items, val)
    for _, value in ipairs(items) do
        if value == val then
            return true
        end
    end

    return false
end

function Utils.HasKey(items, key)
    return items[key] ~= nil
end

function Utils.GetObjectId(object)
    return tostring(EntityID.GetHash(object:GetEntityID()))
end

function Utils.VectorDistance(pos1, pos2)
    return math.sqrt(((pos1.x - pos2.x) ^ 2) + ((pos1.y - pos2.y) ^ 2) + ((pos1.z - pos2.z) ^ 2))
end

return Utils