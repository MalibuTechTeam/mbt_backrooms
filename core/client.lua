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
RegisterNetEvent('mbt_backrooms:doTeleport', function(coords)
    local playerPed = PlayerPedId()

    DoScreenFadeOut(400)
    local guard = 1000
    while not IsScreenFadedOut() and guard > 0 do
        Wait(0)
        guard = guard - 1
    end

    Utils.TeleportPlayer(playerPed, coords)

    DoScreenFadeIn(600)
    TriggerServerEvent('mbt_backrooms:teleportDone')
end)
