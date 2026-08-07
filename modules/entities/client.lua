-- Entity glimpse director (F6). Scripted (NOT AI): while inside a level with low
-- sanity, an entity appears at the EDGE of the player's view, holds briefly, then
-- vanishes when looked at / approached / timed out. Costs sanity. Full AI -> 2.1.
--
-- Placement is CAMERA-based (first person: camera heading != body heading) and
-- raycast-validated so the entity isn't spawned behind a wall/column.

local cfg = MBT.Entities
local activePed = nil
local silenced = false -- Dynamic Silence: ambient ducked for this glimpse

-- Exposed so other systems (hallucinations) don't overlap a live encounter.
Entities = Entities or {}
function Entities.IsActive() return activePed ~= nil end

-- Restore the ambient if this glimpse ducked it (idempotent).
local function restoreAmbient()
    if silenced then
        SendNUIMessage({ action = 'atmosphere:silence', data = { on = false } })
        silenced = false
    end
end

local function cleanup()
    if activePed and DoesEntityExist(activePed) then
        SetEntityAsMissionEntity(activePed, true, true)
        DeleteEntity(activePed)
    end
    activePed = nil
    restoreAmbient()
    SendNUIMessage({ action = 'entity:strain', data = { level = 0 } }) -- clear any tunnel-vision
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

    -- Dynamic Silence: drop the ambient so the scare lands in a vacuum. Chance scaled
    -- by this visit's Haunt Deck; the ambient is always restored in cleanup().
    local ds = MBT.DynamicSilence
    if ds and ds.Enabled and not silenced then
        local haunt = LocalPlayer.state['mbt_backrooms:haunt']
        local silChance = (ds.Chance or 55) * ((haunt and haunt.silence) or 1.0)
        if math.random(1, 100) <= silChance then
            silenced = true
            SendNUIMessage({ action = 'atmosphere:silence', data = { on = true } })
        end
    end

    local snd = cfg.Sound
    if snd and snd.OnSpawn then
        SendNUIMessage({ action = 'entity:sound', data = { file = snd.SpawnFile, volume = snd.Volume } })
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

    -- Don't-Blink state: focus drains while staring, regens while looking away.
    local db = cfg.DontBlink
    local focus, lastTick = 1.0, spawnAt
    local lastStrain, lastStrainAt = -1.0, 0
    local function sendStrain(level)
        if level < 0 then level = 0 elseif level > 1 then level = 1 end
        local t = GetGameTimer()
        if math.abs(level - lastStrain) >= 0.05 or (t - lastStrainAt) > 200 then
            SendNUIMessage({ action = 'entity:strain', data = { level = level } })
            lastStrain, lastStrainAt = level, t
        end
    end
    -- Forced blink: lunge closer along the line to the player (hidden by the
    -- NUI black-out) — classic "look away and it's nearer".
    local function blinkLunge()
        local ec, pc = GetEntityCoords(activePed), GetEntityCoords(PlayerPedId())
        local to = pc - ec
        local d = #(to)
        if d > 0.001 then
            local step = math.min(db.BlinkAdvance or 3.0, d - 0.5)
            if step > 0.0 then
                local np = ec + (to / d) * step
                SetEntityCoordsNoOffset(activePed, np.x, np.y, np.z, false, false, false)
                SetEntityHeading(activePed, GetHeadingFromVector_2d(pc.x - np.x, pc.y - np.y))
            end
        end
        SendNUIMessage({ action = 'entity:blink', data = { durationMs = db.BlinkMs or 220 } })
    end

    while activePed and DoesEntityExist(activePed) do
        local entCoord = GetEntityCoords(activePed)
        local cam = GetGameplayCamCoord()
        local ply = GetEntityCoords(PlayerPedId())
        local now = GetGameTimer()
        local dt = (now - lastTick) / 1000.0
        lastTick = now

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
                    SendNUIMessage({ action = 'entity:sound', data = { file = snd.LookFile, volume = snd.Volume } })
                end
            end

            if cfg.Approach then
                if looked then
                    -- Watched: freeze where it stands (never moves or pops while seen).
                    if moving then ClearPedTasksImmediately(activePed); moving = false end
                    FreezeEntityPosition(activePed, true)
                    -- Don't-Blink: staring drains focus; at zero you blink and it lunges.
                    if db and db.Enabled then
                        focus = focus - (db.DrainPerSec or 0.5) * dt
                        if focus <= 0.0 then
                            blinkLunge()
                            focus = db.FocusAfterBlink or 0.5
                        end
                        sendStrain(1.0 - focus)
                    end
                else
                    -- Unobserved: creep toward the player (re-tasked to track them).
                    FreezeEntityPosition(activePed, false)
                    if (now - lastTask) > 1000 then
                        TaskGoStraightToCoord(activePed, ply.x, ply.y, ply.z, cfg.ApproachSpeed or 1.2, -1, 0.0, 0.0)
                        moving = true
                        lastTask = now
                    end
                    -- Looking away lets focus recover (but it's closing on you).
                    if db and db.Enabled and focus < 1.0 then
                        focus = math.min(1.0, focus + (db.RegenPerSec or 0.4) * dt)
                        sendStrain(1.0 - focus)
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

-- The Mimic: the entity wears another lost player's shape (fake nametag + survivor
-- model) at mid distance. Approaching it or staring too long makes it REVEAL —
-- reality-jolt + sanity hit + a lunge — then it vanishes. A variant of the glimpse.
local function spawnMimic()
    local mc = MBT.Mimic
    local models = (mc and mc.Models) or { 'mp_m_freemode_01', 'mp_f_freemode_01' }
    local model = models[math.random(1, #models)]
    local isFreemode = (model == 'mp_m_freemode_01' or model == 'mp_f_freemode_01')
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then MBTLog.Warn('mimic: model not in cdimage', model); return end
    RequestModel(hash)
    local t = 5000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then MBTLog.Warn('mimic: model failed to load', model); return end

    local spawn = findPlacement()
    if not spawn then
        MBTLog.Debug('mimic: no clear placement')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    activePed = CreatePed(4, hash, spawn.x, spawn.y, spawn.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(activePed, true, true)
    -- Dress it like a real player: a random (valid) outfit, de-costumed so nothing
    -- screams "NPC" — no mask, no hat/helmet, no glasses. (Codex: look exactly like
    -- a player; the wrongness comes from behavior + the reveal, not the model.)
    if isFreemode then
        SetPedRandomComponentVariation(activePed, 0)
        SetPedComponentVariation(activePed, 1, 0, 0, 2) -- component 1 = mask -> none
        ClearPedProp(activePed, 0)                      -- prop 0 = hat/helmet
        ClearPedProp(activePed, 1)                      -- prop 1 = glasses
    else
        SetPedDefaultComponentVariation(activePed)
    end
    SetEntityInvincible(activePed, true)
    SetEntityCanBeDamaged(activePed, false)
    SetBlockingOfNonTemporaryEvents(activePed, true)
    FreezeEntityPosition(activePed, true)

    local cam = GetGameplayCamCoord()
    SetEntityHeading(activePed, GetHeadingFromVector_2d(cam.x - spawn.x, cam.y - spawn.y))

    MBTLog.Debug('mimic spawned', model)

    local revealRange = (mc and mc.RevealRange) or 6.0
    local deadline = GetGameTimer() + ((mc and mc.LingerSec) or 12) * 1000
    local leaving = false

    while activePed and DoesEntityExist(activePed) do
        local ec = GetEntityCoords(activePed)
        local ply = GetEntityCoords(PlayerPedId())

        -- Approach it -> it REVEALS (the scare): jolt + sanity hit + a lunge, then gone.
        if not leaving and #(ply - ec) < revealRange then
            if Atmosphere and Atmosphere.EntryFx then Atmosphere.EntryFx() end -- the "it's WRONG" jolt
            TriggerServerEvent('mbt_backrooms:glimpseSeen')                     -- sanity hit
            local to = ply - ec
            local dd = #(to)
            if dd > 0.5 then -- lunge as it reveals (hidden by the blink black-out)
                local step = math.min(3.0, dd - 0.5)
                local np = ec + (to / dd) * step
                SetEntityCoordsNoOffset(activePed, np.x, np.y, np.z, false, false, false)
            end
            SendNUIMessage({ action = 'entity:blink', data = { durationMs = 220 } })
            Wait(160)
            vanish()
            return
        end

        -- Left alone -> it turns and WALKS AWAY like a real survivor (no on/off pop).
        if not leaving and GetGameTimer() >= deadline then
            leaving = true
            FreezeEntityPosition(activePed, false)
            local dir = ec - ply
            local dl = #(dir)
            dir = (dl > 0.1) and (dir / dl) or vector3(0.0, 1.0, 0.0)
            local dest = ec + dir * 14.0
            TaskGoStraightToCoord(activePed, dest.x, dest.y, dest.z, 1.0, 9000, 0.0, 0.0)
            SetTimeout(7000, function()
                if activePed and DoesEntityExist(activePed) then cleanup() end
            end)
        end

        Wait(80)
    end
end

CreateThread(function()
    if not cfg.Enabled then return end
    local lastGlimpse = 0

    while true do
        local sleep = 4000
        if LocalPlayer.state['mbt_backrooms:inLevel'] and not activePed then
            local sanity = LocalPlayer.state['mbt_backrooms:sanity'] or 100
            -- Haunt Deck: this visit's director tunes aggression + cadence.
            local haunt = LocalPlayer.state['mbt_backrooms:haunt']
            local aggr   = (haunt and haunt.entityAggression) or 1.0
            local cdMult = (haunt and haunt.entityCooldownMult) or 1.0
            -- "Light attracts": torch ON raises the glimpse chance (F4 tension).
            local chance = (cfg.Chance or 50) * aggr
            if MBT.Light and MBT.Light.Enabled and LocalPlayer.state['mbt_backrooms:torch'] then
                chance = chance * (MBT.Light.LightEntityMult or 1.0)
            end
            if sanity < (cfg.MinSanityGate or 50)
                and (GetGameTimer() - lastGlimpse) > (cfg.CooldownSec or 90) * cdMult * 1000
                and math.random(1, 100) <= chance then
                lastGlimpse = GetGameTimer()
                local mc = MBT.Mimic
                if mc and mc.Enabled and math.random(1, 100) <= (mc.Chance or 25) then
                    spawnMimic()
                else
                    spawnGlimpse()
                end
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

    -- Debug: force a Mimic (fake-player entity) now.
    RegisterCommand('brmimic', function()
        if LocalPlayer.state['mbt_backrooms:inLevel'] and not activePed then
            spawnMimic()
        else
            MBTLog.Debug('brmimic: must be inside a level (and none active)')
        end
    end, false)

    -- Debug: print this visit's Haunt Deck (which cards drew + the merged multipliers).
    RegisterCommand('brhaunt', function()
        local h = LocalPlayer.state['mbt_backrooms:haunt']
        if type(h) ~= 'table' or not h.entityAggression then
            MBTLog.Debug('brhaunt: no haunt (must be inside a level)'); return
        end
        -- Plain-language read of what this visit's cards actually bend.
        local parts = {}
        if h.entityAggression >= 1.15 then parts[#parts + 1] = 'entity AGGRESSIVE'
        elseif h.entityAggression <= 0.85 then parts[#parts + 1] = 'entity calm' end
        if (h.entityCooldownMult or 1) <= 0.8 then parts[#parts + 1] = 'shows up more often' end
        if h.silence >= 1.4 then parts[#parts + 1] = 'heavy silence'
        elseif h.silence <= 0.7 then parts[#parts + 1] = 'little silence' end
        if h.falseFreq >= 1.4 then parts[#parts + 1] = 'high paranoia (hallucinations)'
        elseif h.falseFreq <= 0.8 then parts[#parts + 1] = 'few hallucinations' end
        if (h.sanitySensitivity or 1) >= 1.2 then parts[#parts + 1] = 'sanity drains faster' end
        MBTLog.Debug(('brhaunt: [%s] -> %s'):format(
            table.concat(h.cards or {}, '+'),
            #parts > 0 and table.concat(parts, ', ') or 'neutral visit'))
    end, false)
end
