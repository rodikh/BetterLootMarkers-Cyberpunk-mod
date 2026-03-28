local Utils = {}

function Utils.HasValue(items, val)
    for _, value in ipairs(items) do
        if value == val then
            return true
        end
    end

    return false
end

function Utils.sortedCategoryPairs(t, qualities)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end

    table.sort(keys, function(a, b)
        local aVal = t[a].isIconic and "Iconic" or t[a].quality.value
        local bVal = t[b].isIconic and "Iconic" or t[b].quality.value
        return qualities[bVal] < qualities[aVal]
    end)

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

return Utils
