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

-- Proximity scan: show the prompt when the player is within range of a point.
CreateThread(function()
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
            sleep = 5
            Utils.ShowHelpNotification(MBT.Locale.prompt_pass_through)
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
end
