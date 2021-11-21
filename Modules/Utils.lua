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
    return Vector4.Distance2D(pos1, pos2)
end

function Utils.Conditional(condition, left, right)
    if condition then return left else return right end
end

return Utils