local Utils = {}

local _loggedLabels = {}

-- Logs an error once per label (via spdlog when available, otherwise print),
-- so a single broken hook/API call doesn't spam the log every frame.
function Utils.LogError(message)
    local line = "[BetterLootMarkers] " .. message
    if spdlog ~= nil and spdlog.error ~= nil then
        spdlog.error(line)
    else
        print(line)
    end
end

function Utils.LogErrorOnce(label, message)
    if _loggedLabels[label] then
        return
    end
    _loggedLabels[label] = true
    Utils.LogError(message)
end

-- Runs fn() in a pcall and logs (once per label) if it raises or if fn itself
-- is nil/missing. Game API methods get renamed/removed across CDPR patches;
-- this turns a silent no-op into a log line naming what broke.
-- Returns (ok, ...) same as pcall, so multi-return calls (e.g. GetItemList)
-- still work at the call site.
function Utils.Try(label, fn)
    if fn == nil then
        Utils.LogErrorOnce(label, label .. " is unavailable (nil)")
        return false
    end

    local ok, a, b, c = pcall(fn)
    if not ok then
        Utils.LogErrorOnce(label, label .. " failed: " .. tostring(a))
        return false
    end

    return true, a, b, c
end

-- Convenience for the common case of a single-value call: logs on
-- failure/missing-method same as Try, but returns just the value (or nil).
function Utils.TryValue(label, fn)
    local ok, result = Utils.Try(label, fn)
    if not ok then
        return nil
    end
    return result
end

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
