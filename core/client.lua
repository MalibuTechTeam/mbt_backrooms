-- Ensure the configured language is applied before we read any locale strings
-- (config.lua has already run by the time this client script loads).
if MBT.RefreshLocale then MBT.RefreshLocale(MBT.Language) end

local isNear = false
local nearestLocation = nil
local nearestIndex = nil

-- True while the server is moving us (set authoritatively via state bag).
local function isLocked()
    return LocalPlayer.state['mbt_backrooms:exitLocked'] == true
end

-------------------------------------------------------------------------------
-- Fall-through: detect a glitch below the map and REQUEST entry server-side.
-------------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)

    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()

        if not IsEntityDead(playerPed) and DoesEntityExist(playerPed) and not isLocked() then
            local playerCoords = GetEntityCoords(playerPed)

            if playerCoords.z < MBT.FallingPoint then
                local veh = GetVehiclePedIsIn(playerPed, false)

                -- Ignore swimming and ordinary grounded states; only react to a real fall.
                local ignore = IsPedSwimming(playerPed) or IsPedSwimmingUnderWater(playerPed)
                    or (not IsPedFalling(playerPed) and veh == 0)

                if not ignore then
                    local isFalling = IsPedFalling(playerPed) or (veh ~= 0 and IsEntityInAir(veh))

                    if isFalling then
                        sleep = 100
                        ClearPedTasksImmediately(playerPed)
                        TriggerServerEvent('mbt_backrooms:requestEntry', { reason = 'fall' })
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-------------------------------------------------------------------------------
-- Enter / Exit interaction points — REQUEST, the server decides the destination.
-------------------------------------------------------------------------------
local function handleBackroomAction()
    if not isNear or not nearestLocation or not nearestIndex or isLocked() then return end

    if nearestLocation.Type == 'Exit' then
        TriggerServerEvent('mbt_backrooms:requestExit', { point = nearestIndex })
    elseif nearestLocation.Type == 'Enter' then
        TriggerServerEvent('mbt_backrooms:requestEntry', { reason = 'interact', point = nearestIndex })
    end
end

RegisterCommand('mbt_backrooms_action', handleBackroomAction, false)
RegisterKeyMapping('mbt_backrooms_action', MBT.Locale.keymapping_label, 'keyboard', MBT.General.InteractKey)

-- Map a point type to the NUI prompt (found-footage caption: "[e] enter/leave").
local function promptFor(location)
    if location.Type == 'Exit' then
        return 'leave', MBT.Locale.prompt_leave
    end
    return 'enter', MBT.Locale.prompt_enter
end

-- Proximity scan: show/hide the NUI prompt on transition (no per-frame spam).
CreateThread(function()
    local shownIndex = nil

    while true do
        local sleep = 500
        local playerCoords = GetEntityCoords(PlayerPedId())

        isNear = false
        nearestLocation = nil
        nearestIndex = nil

        for i = 1, #MBT.BackRooms do
            local location = MBT.BackRooms[i]
            if #(playerCoords - location.Coords) <= location.Range then
                isNear = true
                nearestLocation = location
                nearestIndex = i
                break
            end
        end

        if isNear then
            sleep = 300
            if shownIndex ~= nearestIndex then
                shownIndex = nearestIndex
                local ptype, label = promptFor(nearestLocation)
                Utils.MbtDebugger('prompt:set visible', ptype, nearestIndex)
                SendNUIMessage({
                    action = 'prompt:set',
                    data = {
                        visible = true,
                        key = MBT.General.InteractKey,
                        label = label,
                        type = ptype,
                        reduceMotion = (MBT.Atmosphere and MBT.Atmosphere.ReduceMotion) or false,
                    },
                })
            end
        elseif shownIndex ~= nil then
            shownIndex = nil
            Utils.MbtDebugger('prompt:set hidden (left range)')
            SendNUIMessage({ action = 'prompt:set', data = { visible = false } })
        end

        Wait(sleep)
    end
end)

-------------------------------------------------------------------------------
-- Authoritative teleport dispatched by the server (with a screen transition).
-------------------------------------------------------------------------------
RegisterNetEvent('mbt_backrooms:doTeleport', function(coords, token)
    local playerPed = PlayerPedId()
    local mode = MBT.Transition or 'glitch'

    if mode == 'cut' then
        Utils.TeleportPlayer(playerPed, coords)
    else
        DoScreenFadeOut(mode == 'glitch' and 250 or 400)
        local deadline = GetGameTimer() + 1000
        while not IsScreenFadedOut() and GetGameTimer() < deadline do
            Wait(0)
        end

        Utils.TeleportPlayer(playerPed, coords)
        DoScreenFadeIn(mode == 'glitch' and 500 or 600)

        -- Reality-shift FX over the just-revealed scene (postfx + shake + NUI
        -- glitch burst + sting) — feels like reality settling, not a hidden flash.
        if mode == 'glitch' and Atmosphere and Atmosphere.EntryFx then
            Atmosphere.EntryFx()
        end
    end

    TriggerServerEvent('mbt_backrooms:teleportDone', token)
end)

-------------------------------------------------------------------------------
-- TEMP debug helpers (remove before release). Fire requests directly so F1 can
-- be tested from the chat box (the F8 console can't run raw Lua / table args).
--   /brfall          — simulate a fall-through (entry, reason 'fall').
--   /brenter [point] — request Enter at point index (default 1).
--   /brexit  [point] — request Exit  at point index (default 1).
-- Stand FAR from the point to verify the server's distance rejection; stand
-- near it to verify a successful teleport. Spam either to test the rate limit.
-------------------------------------------------------------------------------
if MBT.Debug then
    RegisterCommand('brfall', function()
        if isLocked() then return end
        Utils.MbtDebugger('brfall: requesting fall entry')
        TriggerServerEvent('mbt_backrooms:requestEntry', { reason = 'fall' })
    end, false)

    RegisterCommand('brenter', function(_, args)
        local point = tonumber(args[1]) or 1
        Utils.MbtDebugger('brenter: requesting interact entry at point', point)
        TriggerServerEvent('mbt_backrooms:requestEntry', { reason = 'interact', point = point })
    end, false)

    RegisterCommand('brexit', function(_, args)
        local point = tonumber(args[1]) or 1
        Utils.MbtDebugger('brexit: requesting exit at point', point)
        TriggerServerEvent('mbt_backrooms:requestExit', { point = point })
    end, false)

    -- Print the player's current coords (to place MBT.NoClipZones).
    RegisterCommand('brhere', function()
        local c = GetEntityCoords(PlayerPedId())
        Utils.MbtDebugger('brhere:', ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z))
    end, false)

    -- Preview a timecycle modifier live (to pick a good one for the atmosphere).
    --   /brtc <modifier> [strength]   e.g. /brtc scanline_cam 1.0
    --   /brtc off                     clears it
    RegisterCommand('brtc', function(_, args)
        ClearTimecycleModifier()
        local mod = args[1]
        if not mod or mod == 'off' then
            Utils.MbtDebugger('timecycle cleared')
            return
        end
        local strength = tonumber(args[2]) or 1.0
        SetTimecycleModifier(mod)
        SetTimecycleModifierStrength(strength)
        Utils.MbtDebugger('timecycle:', mod, 'strength', strength)
    end, false)

    -- Preview a looped particle FX at your feet (to pick atmosphere/exit ptfx).
    --   /brptfx <dict> <fxname> [scale]   e.g. /brptfx core ent_amb_smoke_foundry 1.0
    --   /brptfx off                       stop the preview
    local previewPtfx = nil
    RegisterCommand('brptfx', function(_, args)
        if previewPtfx and DoesParticleFxLoopedExist(previewPtfx) then
            StopParticleFxLooped(previewPtfx, false)
        end
        previewPtfx = nil
        local dict = args[1]
        if not dict or dict == 'off' then Utils.MbtDebugger('ptfx: stopped'); return end
        local fx = args[2]
        if not fx then Utils.MbtDebugger('ptfx: usage /brptfx <dict> <fxname> [scale]'); return end
        local scale = tonumber(args[3]) or 1.0

        RequestNamedPtfxAsset(dict)
        local t = 3000
        while not HasNamedPtfxAssetLoaded(dict) and t > 0 do Wait(50); t = t - 50 end
        if not HasNamedPtfxAssetLoaded(dict) then
            Utils.MbtDebugger('ptfx: dict failed to load (wrong name?)', dict)
            return
        end
        UseParticleFxAsset(dict)
        local ped = PlayerPedId()
        local fwd = GetEntityForwardVector(ped)
        local c = GetEntityCoords(ped) + fwd * 2.0 -- 2m ahead so it's not under your feet
        previewPtfx = StartParticleFxLoopedAtCoord(fx, c.x, c.y, c.z + 0.5, 0.0, 0.0, 0.0, scale, false, false, false, false)
        if not previewPtfx or previewPtfx == 0 or previewPtfx == -1 then
            Utils.MbtDebugger('ptfx: FAILED to start — effect name wrong for dict?', dict, fx, '(handle', previewPtfx, ')')
        else
            Utils.MbtDebugger('ptfx OK:', dict, fx, 'scale', scale, '-> 2m ahead, chest height, handle', previewPtfx)
        end
    end, false)
end
