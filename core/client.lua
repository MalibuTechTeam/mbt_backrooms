-- Ensure the configured language is applied before we read any locale strings
-- (config.lua has already run by the time this client script loads).
if MBT.RefreshLocale then MBT.RefreshLocale(MBT.Language) end

-- Seed the RNG once at startup, not on every interaction.
math.randomseed(GetGameTimer())

local isNear = false
local nearestLocation = nil

-------------------------------------------------------------------------------
-- Fall-through: pull players that glitch BELOW the map into the backrooms.
-------------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)

    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()

        if not IsEntityDead(playerPed) and DoesEntityExist(playerPed) then
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
                        Utils.TeleportPlayer(playerPed, MBT.Coords[math.random(1, #MBT.Coords)])
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-------------------------------------------------------------------------------
-- Enter / Exit interaction points.
-------------------------------------------------------------------------------
local function handleBackroomAction()
    if not isNear or not nearestLocation then return end

    local playerPed = PlayerPedId()

    if nearestLocation.Type == "Exit" then
        if math.random(1, 100) <= MBT.ExitToBackroomChance then
            Utils.TeleportPlayer(playerPed, MBT.Coords[math.random(1, #MBT.Coords)])
        else
            Utils.TeleportPlayer(playerPed, MBT.RandomExitPoint[math.random(1, #MBT.RandomExitPoint)])
        end
    elseif nearestLocation.Type == "Enter" then
        Utils.TeleportPlayer(playerPed, MBT.Coords[math.random(1, #MBT.Coords)])
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

        for i = 1, #MBT.BackRooms do
            local location = MBT.BackRooms[i]
            if #(playerCoords - location.Coords) <= location.Range then
                isNear = true
                nearestLocation = location
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
