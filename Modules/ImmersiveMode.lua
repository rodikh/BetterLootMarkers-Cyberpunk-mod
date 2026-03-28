-- Immersive mode: only show custom loot markers while the scanner is active.
-- Owns scanner state detection, controller tracking, and refresh/prune logic.

local ImmersiveMode = {}

local _cacheTime = 0
local _cacheValue = false
local _managedControllers = {}
local _lastState = nil
local _cleanupTimer = 0
local _pendingToggle = false
local _refreshQueue = {}
local _refreshIdx = 0
local REFRESH_BATCH = 8

function ImmersiveMode.IsScannerActive()
    local now = os.clock()
    if now - _cacheTime < 0.05 then
        return _cacheValue
    end
    _cacheTime = now

    local ok, result = pcall(function()
        local player = Game.GetPlayer()
        if player == nil then return false end

        local bb = Game.GetBlackboardSystem():GetLocalInstanced(
            player:GetEntityID(),
            GetAllBlackboardDefs().PlayerStateMachine
        )
        if bb == nil then return false end

        local visionValue = bb:GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision)
        return visionValue == 1
    end)

    if ok then
        _cacheValue = result
    else
        _cacheValue = false
    end
    return _cacheValue
end

function ImmersiveMode.TrackController(ctrl)
    _managedControllers[ctrl] = true
end

function ImmersiveMode.Init()
    ObserveBefore("scannerGameController", "ShowScanner", function(_, show)
        if not BetterLootMarkers.Settings.immersiveMode then return end
        _cacheValue = show
        _cacheTime = os.clock()
        _pendingToggle = true
    end)
end

function ImmersiveMode.Tick(dt)
    if not BetterLootMarkers.Settings.immersiveMode then
        return
    end

    _cleanupTimer = _cleanupTimer + dt
    if _cleanupTimer > 30 then
        _cleanupTimer = 0
        ImmersiveMode.PruneStaleControllers()
    end

    if _pendingToggle then
        _pendingToggle = false
        _lastState = _cacheValue
        ImmersiveMode.QueueRefresh()
    end

    if _refreshIdx > 0 then
        ImmersiveMode.ProcessRefreshBatch()
        return
    end

    local scannerNow = ImmersiveMode.IsScannerActive()

    if _lastState == nil then
        _lastState = scannerNow
        return
    end

    if scannerNow ~= _lastState then
        _lastState = scannerNow
        ImmersiveMode.QueueRefresh()
        ImmersiveMode.ProcessRefreshBatch()
    end
end

function ImmersiveMode.QueueRefresh()
    _refreshQueue = {}
    for ctrl, _ in pairs(_managedControllers) do
        _refreshQueue[#_refreshQueue + 1] = ctrl
    end
    _refreshIdx = 1
end

function ImmersiveMode.ProcessRefreshBatch()
    local endIdx = math.min(_refreshIdx + REFRESH_BATCH - 1, #_refreshQueue)
    for i = _refreshIdx, endIdx do
        local ctrl = _refreshQueue[i]
        if _managedControllers[ctrl] then
            local ok = pcall(BetterLootMarkers._HandleLootMarkers, ctrl)
            if not ok then
                _managedControllers[ctrl] = nil
            end
        end
    end
    _refreshIdx = endIdx + 1

    if _refreshIdx > #_refreshQueue then
        _refreshQueue = {}
        _refreshIdx = 0
    end
end

function ImmersiveMode.PruneStaleControllers()
    local toRemove = {}
    for ctrl, _ in pairs(_managedControllers) do
        local ok = pcall(ctrl.GetMappin, ctrl)
        if not ok then
            toRemove[#toRemove + 1] = ctrl
        end
    end
    for _, ctrl in ipairs(toRemove) do
        _managedControllers[ctrl] = nil
    end
end

return ImmersiveMode
