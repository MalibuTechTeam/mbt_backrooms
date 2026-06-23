-- Entity glimpse director (F6). Scripted (NOT AI): while inside a level with low
-- sanity, an entity appears at the EDGE of the player's view, holds briefly, then
-- vanishes when looked at / approached / timed out. Costs sanity. Full AI -> 2.1.
--
-- Placement is CAMERA-based (first person: camera heading != body heading) and
-- raycast-validated so the entity isn't spawned behind a wall/column.

local cfg = MBT.Entities
local activePed = nil

local function cleanup()
    if activePed and DoesEntityExist(activePed) then
        SetEntityAsMissionEntity(activePed, true, true)
        DeleteEntity(activePed)
    end
    activePed = nil
end

-- Soft vanish: quick alpha fade then delete, so it never "pops" out of view.
local function vanish()
    local ped = activePed
    if ped and DoesEntityExist(ped) then
        for a = 204, 0, -51 do
            if not DoesEntityExist(ped) then break end
            SetEntityAlpha(ped, a, false)
            Wait(40)
        end
    end
    cleanup()
end

-- Camera rotation (deg) -> forward unit vector.
local function rotToDir(rot)
    local rz, rx = math.rad(rot.z), math.rad(rot.x)
    local cosRx = math.cos(rx)
    return vector3(-math.sin(rz) * cosRx, math.cos(rz) * cosRx, math.sin(rx))
end

-- Horizontal direction from a yaw (deg).
local function yawDir(yawDeg)
    local rz = math.rad(yawDeg)
    return vector3(-math.sin(rz), math.cos(rz), 0.0)
end

-- Horizontal FOV (deg) from the vertical gameplay FOV + screen aspect.
local function horizontalFovDeg()
    local vfov = GetGameplayCamFov()
    local sx, sy = GetActiveScreenResolution()
    local aspect = (sy ~= 0) and (sx / sy) or 1.777
    return math.deg(2.0 * math.atan(math.tan(math.rad(vfov) * 0.5) * aspect))
end

-- Synchronous-ish ray: returns hit(boolean), endCoords.
local function castRay(p1, p2, ignoreEnt)
    local h = StartShapeTestRay(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, 17, ignoreEnt, 7)
    local r, hit, ep, tries = 0, 0, nil, 0
    repeat
        r, hit, ep = GetShapeTestResult(h)
        if r ~= 2 then Wait(0) end
        tries = tries + 1
    until r == 2 or tries > 12
    return hit == 1, ep
end

-- Find an in-view spawn point at the edge of vision. The camera ray already
-- guarantees line-of-sight up to wherever it stops, so a point clamped just
-- short of the first obstacle is always visible — no extra LOS test needed.
-- Tries edge angles first (peripheral), then nearer center, the other side,
-- and finally straight ahead, so it almost always lands a spot.
local function findPlacement()
    local playerPed = PlayerPedId()
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local hFov = horizontalFovDeg()
    local side = (math.random(0, 1) == 0) and -1 or 1

    -- offsets as a fraction of the (total) horizontal FOV, signed.
    local maxDist = cfg.SpawnDistance or 18.0
    local offsets = { 0.40 * side, 0.30 * side, 0.40 * -side, 0.22 * side, 0.0 }
    for _, frac in ipairs(offsets) do
        local dir = yawDir(camRot.z + hFov * frac)
        local hit, ep = castRay(camPos, camPos + dir * maxDist, playerPed)
        local dist = hit and (#(ep - camPos) - 1.0) or maxDist
        -- keep min spawn distance well beyond ApproachDist so it never spawns
        -- inside the "reached you" radius (which would end it instantly).
        if dist >= 8.0 then
            local sp = camPos + dir * dist
            local fg, gz = GetGroundZFor_3dCoord(sp.x, sp.y, sp.z + 3.0, false)
            return vector3(sp.x, sp.y, fg and gz or (camPos.z - 1.0))
        end
    end
    return nil
end

local function spawnGlimpse()
    local model = cfg.Models[math.random(1, #cfg.Models)]
    local hash = joaat(model)

    if not IsModelInCdimage(hash) then
        MBTLog.Warn('glimpse: model not in cdimage', model)
        return
    end
    RequestModel(hash)
    local t = 5000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then
        MBTLog.Warn('glimpse: model failed to load', model)
        return
    end

    local spawn = findPlacement()
    if not spawn then
        MBTLog.Debug('glimpse: no clear placement (all candidates blocked)')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    activePed = CreatePed(4, hash, spawn.x, spawn.y, spawn.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(activePed, true, true) -- script-owned: no ambient cleanup
    SetPedDefaultComponentVariation(activePed)
    SetEntityInvincible(activePed, true)
    SetEntityCanBeDamaged(activePed, false)
    SetBlockingOfNonTemporaryEvents(activePed, true)
    SetEntityVisible(activePed, true, false)
    SetEntityAlpha(activePed, 255, false)
    FreezeEntityPosition(activePed, true)

    -- Face the camera (first person).
    local camPos = GetGameplayCamCoord()
    SetEntityHeading(activePed, GetHeadingFromVector_2d(camPos.x - spawn.x, camPos.y - spawn.y))

    TriggerServerEvent('mbt_backrooms:glimpseSeen')
    MBTLog.Debug('glimpse spawned', model, 'onScreen', IsEntityOnScreen(activePed))

    local snd = cfg.Sound
    if snd and snd.OnSpawn then
        SendNUIMessage({ action = 'entity:sound', data = { file = snd.File, volume = snd.Volume } })
    end

    -- Hold loop. Grace guarantees it's on screen briefly first. Then:
    --   static mode  -> vanish when looked at.
    --   stalk mode   -> creep toward you while UNOBSERVED, freeze while looked at.
    -- Either way: reaching you (ApproachDist) or timeout ends it (sanity hit).
    local spawnAt = GetGameTimer()
    local maxSec = cfg.Approach and (cfg.ApproachTimeoutSec or 15) or (cfg.HoldSec or 6)
    local deadline = spawnAt + maxSec * 1000
    local hardCap = deadline + 8000 -- vanish even if still stared at, after this
    local grace = 900
    local cosGaze = math.cos(math.rad(cfg.GazeAngle or 14.0))
    local moving, lastTask, lookedOnce = false, 0, false

    while activePed and DoesEntityExist(activePed) do
        local entCoord = GetEntityCoords(activePed)
        local cam = GetGameplayCamCoord()
        local ply = GetEntityCoords(PlayerPedId())
        local now = GetGameTimer()

        -- Reached the player: a final jolt of dread, then gone.
        if #(ply - entCoord) < (cfg.ApproachDist or 6.0) then
            TriggerServerEvent('mbt_backrooms:glimpseSeen')
            break
        end

        local looked = false
        if now - spawnAt >= grace then
            local torso = vector3(entCoord.x, entCoord.y, entCoord.z + 1.0)
            local dir = torso - cam
            local len = #(dir)
            if len > 0.0 then
                dir = dir / len
                local fwd = rotToDir(GetGameplayCamRot(2))
                looked = (fwd.x * dir.x + fwd.y * dir.y + fwd.z * dir.z) > cosGaze
            end

            -- Sound on the first time the player looks at it (the scare beat).
            if looked and not lookedOnce then
                lookedOnce = true
                local snd = cfg.Sound
                if snd and snd.OnLook then
                    SendNUIMessage({ action = 'entity:sound', data = { file = snd.File, volume = snd.Volume } })
                end
            end

            if cfg.Approach then
                if looked then
                    -- Watched: freeze where it stands (never moves or pops while seen).
                    if moving then ClearPedTasksImmediately(activePed); moving = false end
                    FreezeEntityPosition(activePed, true)
                else
                    -- Unobserved: creep toward the player (re-tasked to track them).
                    FreezeEntityPosition(activePed, false)
                    if (now - lastTask) > 1000 then
                        TaskGoStraightToCoord(activePed, ply.x, ply.y, ply.z, cfg.ApproachSpeed or 1.2, -1, 0.0, 0.0)
                        moving = true
                        lastTask = now
                    end
                end
            elseif looked then
                break -- static-glimpse mode: ends when looked at
            end
        end

        -- Timeout: don't pop out while being watched. Wait until the player
        -- looks away ("look back and it's gone"), with a hard cap as a backstop.
        if now >= deadline and (not looked or now >= hardCap) then
            break
        end

        Wait(80)
    end

    vanish()
end

CreateThread(function()
    if not cfg.Enabled then return end
    local lastGlimpse = 0

    while true do
        local sleep = 4000
        if LocalPlayer.state['mbt_backrooms:inLevel'] and not activePed then
            local sanity = LocalPlayer.state['mbt_backrooms:sanity'] or 100
            if sanity < (cfg.MinSanityGate or 50)
                and (GetGameTimer() - lastGlimpse) > (cfg.CooldownSec or 90) * 1000
                and math.random(1, 100) <= (cfg.Chance or 50) then
                lastGlimpse = GetGameTimer()
                spawnGlimpse()
            end
        end
        Wait(sleep)
    end
end)

-- Clean up the glimpse when leaving a level.
AddStateBagChangeHandler('mbt_backrooms:inLevel', '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    if not value then cleanup() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then cleanup() end
end)

-- Debug: force a glimpse now.
if MBT.Debug then
    RegisterCommand('brglimpse', function()
        if LocalPlayer.state['mbt_backrooms:inLevel'] and not activePed then
            spawnGlimpse()
        else
            MBTLog.Debug('brglimpse: must be inside a level (and none active)')
        end
    end, false)
end
