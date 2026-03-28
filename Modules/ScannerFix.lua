-- Scanner-exit loot marker persistence fix.
--
-- Bug: Loot mappin markers vanish when exiting scanner / focus mode.
--
-- Root cause (engine flow):
--   1. DeactivateVisionMode sets PlayerStateMachine.Vision = 0 (Default).
--   2. HUDManager.OnVisionModeChanged switches ActiveMode from FOCUS → SEMI
--      and calls RefreshHUD().
--   3. IconsModule.Process re-evaluates every HUD actor under SEMI rules:
--      only looked-at / revealed / tagged / pulse-active actors keep
--      InstanceState.ON.  Everything else (including loot containers NOT
--      under the crosshair) receives InstanceState.DISABLED.
--   4. GameplayRoleComponent.OnHUDInstruction receives DISABLED →
--      HideRoleMappinsByTask → MappinSystem.SetMappinActive(id, false).
--   5. Deactivated mappin → IMappin.IsVisible() returns false → widget hidden.
--   The single container the player is aiming at survives because
--   IsActorLookedAt() keeps its instruction ON.
--
-- Fix: ObserveAfter OnHUDInstruction — within a short grace window after
-- scanner exit, call ShowRoleMappinsByTask on loot-bearing entities.
-- ShowRoleMappinsByTask sets m_canShowMappinsByTask = true and clears
-- m_canHideMappinsByTask, so the delayed show task cancels the pending
-- hide task that OnHUDInstruction already queued.

local ScannerFix = {}

local SCANNER_EXIT_GRACE = 0.5
local scannerExitTime = 0

local function IsLootSource(entity, itemDropCName)
    if not IsDefined(entity) then return false end
    if entity:IsContainer() then return true end
    if entity:IsA(itemDropCName) then return true end
    local okDead, dead = pcall(entity.IsDead, entity)
    if okDead and dead then
        local okNpc, npc = pcall(entity.IsNPC, entity)
        if okNpc and npc then return true end
    end
    return false
end

function ScannerFix.Init(itemDropCName)
    ObserveBefore("scannerGameController", "ShowScanner", function(_, show)
        if not show then
            scannerExitTime = os.clock()
        end
    end)

    ObserveAfter("GameplayRoleComponent", "OnHUDInstruction", function(self, evt)
        if (os.clock() - scannerExitTime) > SCANNER_EXIT_GRACE then return end

        local owner = self:GetOwner()
        if not IsLootSource(owner, itemDropCName) then return end

        pcall(self.ShowRoleMappinsByTask, self)
    end)
end

return ScannerFix
