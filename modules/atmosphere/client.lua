-- Atmosphere controller (F3). Reacts to the player's own `inLevel` state bag:
-- applies native effects (timecycle, light flicker, entry postfx/shake) and
-- drives the NUI overlay/audio. One controller, no Wait(0) loops.

Atmosphere = Atmosphere or {}

local A = MBT.Atmosphere
local CAM = MBT.Camera or {}
local active = false          -- are we currently inside a level?
local flickerGen = 0         -- generation token to cancel pending flicker timeouts
local cameraGen = 0          -- generation token for the first-person lock loop
local prevViewMode = nil     -- player's camera view mode before we forced FP
local activePostFx = nil     -- currently-playing AnimpostfxPlay name (for cleanup)

-- Should this effect run given MBT.Atmosphere.Mode? Native-only/NUI-only effects
-- only run when the mode matches (or in 'mix'); source='mix' effects always run.
local function enabled(effect)
    if not effect or not effect.enabled then return false end
    local mode = A.Mode
    if mode == 'mix' or effect.source == 'mix' then return true end
    return effect.source == mode
end

-- final audio volume = per-effect volume * global Audio intensity
local function audioVol(effect)
    return (effect.volume or 0.5) * (A.Intensity.Audio or 1.0)
end

-------------------------------------------------------------------------------
-- Light flicker (native): recursive SetTimeout, cancelled via generation token.
-------------------------------------------------------------------------------
local function flickerLoop(gen)
    local cfg = A.Effects.LightFlicker
    SetTimeout(math.random(cfg.minDelayMs, cfg.maxDelayMs), function()
        if gen ~= flickerGen then return end
        SetArtificialLightsState(true) -- lights OFF (blackout blink)
        SetTimeout(math.random(cfg.burstMinMs, cfg.burstMaxMs), function()
            if gen ~= flickerGen then return end
            SetArtificialLightsState(false) -- restore
        end)
        flickerLoop(gen)
    end)
end

-------------------------------------------------------------------------------
-- Enter / Exit (persistent effects)
-------------------------------------------------------------------------------
-- Pick a timecycle variant for this entry per the configured select mode.
local function pickTimecycle(tc, level)
    local v = tc.variants
    if not v or #v == 0 then return nil end
    if tc.select == 'fixed' then
        return v[1]
    elseif tc.select == 'perLevel' and type(level) == 'number' then
        return v[((level - 1) % #v) + 1]
    end
    return v[math.random(1, #v)] -- 'random' (default)
end

function Atmosphere.Enter(level)
    if not A.Enabled or active then return end
    active = true

    -- Native
    if enabled(A.Effects.Timecycle) then
        local variant = pickTimecycle(A.Effects.Timecycle, level)
        if variant then
            SetTimecycleModifier(variant.modifier)
            SetTimecycleModifierStrength((variant.strength or 1.0) * (A.Intensity.Native or 1.0))
        end
    end
    if enabled(A.Effects.LightFlicker) and not A.ReduceFlashing then
        flickerGen = flickerGen + 1
        flickerLoop(flickerGen)
    end

    -- First person (found-footage view), optionally locked.
    if CAM.ForceFirstPerson then
        prevViewMode = GetFollowPedCamViewMode()
        SetFollowPedCamViewMode(4) -- 4 = first person
        if CAM.Lock then
            cameraGen = cameraGen + 1
            local gen = cameraGen
            CreateThread(function()
                local nextAssert = 0
                while gen == cameraGen and active do
                    DisableControlAction(0, 0, true) -- INPUT_NEXT_CAMERA (must be per-frame)
                    -- The view mode only changes via the (now-blocked) key, so
                    -- re-assert it on a throttle instead of every frame.
                    local now = GetGameTimer()
                    if now >= nextAssert then
                        if GetFollowPedCamViewMode() ~= 4 then SetFollowPedCamViewMode(4) end
                        nextAssert = now + 500
                    end
                    Wait(0)
                end
            end)
        end
    end

    -- NUI
    local vhs = enabled(A.Effects.Vhs)
    SendNUIMessage({
        action = 'atmosphere:state',
        data = {
            active = true,
            intensity = A.Intensity.NUI or 1.0,
            vhs = vhs,
            grain = vhs and A.Effects.Vhs.grain or false,
            reduceMotion = A.ReduceMotion or false,
            gloom = (A.Darkness and A.Darkness.Enabled) and (A.Darkness.Strength or 0) or 0,
            hum = enabled(A.Effects.Hum) and audioVol(A.Effects.Hum) or false,
            drone = enabled(A.Effects.Drone) and audioVol(A.Effects.Drone) or false,
        },
    })
end

function Atmosphere.Exit()
    if not active then return end
    active = false

    -- Native cleanup
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    flickerGen = flickerGen + 1            -- cancel pending flicker bursts
    cameraGen = cameraGen + 1              -- stop the first-person lock loop
    SetArtificialLightsState(false)        -- never leave lights off
    StopGameplayCamShaking(true)
    if activePostFx then AnimpostfxStop(activePostFx); activePostFx = nil end

    -- Restore the player's previous camera view.
    if prevViewMode ~= nil then
        SetFollowPedCamViewMode(prevViewMode)
        prevViewMode = nil
    end

    -- NUI
    SendNUIMessage({ action = 'atmosphere:stopAll' })
end

-------------------------------------------------------------------------------
-- Entry transition one-shot (the "reality shift" — postfx + shake + NUI burst).
-- Called by core/client.lua doTeleport when MBT.Transition == 'glitch'.
-------------------------------------------------------------------------------
function Atmosphere.EntryFx()
    if not A.Enabled then return end

    -- Native
    if enabled(A.Effects.EntryPostFx) then
        local fx = A.Effects.EntryPostFx
        AnimpostfxStop(fx.name)
        AnimpostfxPlay(fx.name, fx.durationMs or 900, false)
        activePostFx = fx.name
        SetTimeout(fx.durationMs or 900, function()
            if activePostFx == fx.name then AnimpostfxStop(fx.name); activePostFx = nil end
        end)
    end
    if enabled(A.Effects.EntryShake) and not A.ReduceMotion then
        local s = A.Effects.EntryShake
        ShakeGameplayCam(s.shake, (s.amplitude or 0.3) * (A.Intensity.Native or 1.0))
        SetTimeout(s.durationMs or 900, function() StopGameplayCamShaking(true) end)
    end

    -- NUI glitch burst + sting
    SendNUIMessage({
        action = 'atmosphere:entry',
        data = {
            intensity = A.Intensity.NUI or 1.0,
            sting = enabled(A.Effects.EntrySting) and audioVol(A.Effects.EntrySting) or false,
        },
    })
end

-------------------------------------------------------------------------------
-- Drive Enter/Exit off the LOCAL player's inLevel state bag.
-------------------------------------------------------------------------------
AddStateBagChangeHandler('mbt_backrooms:inLevel', '', function(bagName, _, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 or ply ~= PlayerId() then return end
    if value then Atmosphere.Enter(value) else Atmosphere.Exit() end
end)

-- Hard cleanup so a stopped resource never leaves the client tinted/dark/shaking.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    SetArtificialLightsState(false)
    StopGameplayCamShaking(true)
    if activePostFx then AnimpostfxStop(activePostFx) end
    if prevViewMode ~= nil then SetFollowPedCamViewMode(prevViewMode) end
    SendNUIMessage({ action = 'atmosphere:stopAll' })
end)
