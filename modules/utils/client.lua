Utils = Utils or {}

-- Gated debug print. Enabled via MBT.Debug in config.lua.
function Utils.MbtDebugger(...)
    if not MBT.Debug then return end
    local args = { ... }
    local out = "[" .. GetCurrentResourceName() .. "] | "
    for _, v in ipairs(args) do
        out = out .. tostring(v) .. "\t"
    end
    print(out)
end

-- Teleport a ped to a vector3, waiting for collision to stream in.
-- Bounded by a timeout so a missing collision can never hang the thread.
function Utils.TeleportPlayer(ped, coords)
    if not coords or not DoesEntityExist(ped) then return end

    FreezeEntityPosition(ped, true)

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local timeout = 3000
    while not HasCollisionLoadedAroundEntity(ped) and timeout > 0 do
        Wait(50)
        timeout = timeout - 50
    end

    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, true, false, false)
    Wait(1200)
    FreezeEntityPosition(ped, false)
end

-- Native help prompt. ~INPUT_CONTEXT~ inside the text resolves to the key glyph.
function Utils.ShowHelpNotification(text)
    BeginTextCommandDisplayHelp("THREESTRINGS")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, 5000)
end
