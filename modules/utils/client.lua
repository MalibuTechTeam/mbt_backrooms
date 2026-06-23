Utils = Utils or {}

-- Canonical logging via MBTLog (modules/utils/logger.lua, shared). Kept as a
-- Utils.MbtDebugger alias for back-compat; new code can call MBTLog.Debug/.Warn
-- /.Error directly.
Utils.MbtDebugger = MBTLog.Debug

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
