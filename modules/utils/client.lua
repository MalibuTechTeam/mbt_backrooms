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

-- Teleport a ped to a vector3. Move first (frozen so the ped doesn't fall),
-- THEN stream collision around the destination — checking collision before the
-- move would test the old position. Bounded by a timeout so a missing collision
-- can never hang the thread.
function Utils.TeleportPlayer(ped, coords)
    if not coords or not DoesEntityExist(ped) then return end

    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local timeout = 3000
    while not HasCollisionLoadedAroundEntity(ped) and timeout > 0 do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
        timeout = timeout - 50
    end

    FreezeEntityPosition(ped, false)
end

-- Native help prompt. ~INPUT_CONTEXT~ inside the text resolves to the key glyph.
function Utils.ShowHelpNotification(text)
    BeginTextCommandDisplayHelp("THREESTRINGS")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, 5000)
end
