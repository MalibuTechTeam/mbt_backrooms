-- Sanity Reality Errors (F4 depth). At low sanity, fire HARMLESS false events — a
-- fleeting silhouette at the edge of view, or a phantom sound. NO sanity hit, never
-- stalks: pure paranoia. Frequency is scaled by this visit's Haunt Deck `falseFreq`
-- card. You only know it was fake after it's gone. Guarded so it never overlaps a
-- real encounter (Entities.IsActive()).

local cfg = MBT.Hallucinations
local INLEVEL = 'mbt_backrooms:inLevel'

-- A point at the edge of view, `distance` m ahead. No strict raycast — a hallucination
-- that clips geometry just fades faster; it's fleeting by design.
local function edgePoint(distance)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local side = (math.random(0, 1) == 0) and -1.0 or 1.0
    local yaw = math.rad(rot.z + 35.0 * side) -- ~35° off-centre = peripheral
    local dir = vector3(-math.sin(yaw), math.cos(yaw), 0.0)
    local sp = cam + dir * distance
    local fg, gz = GetGroundZFor_3dCoord(sp.x, sp.y, sp.z + 2.0, false)
    return vector3(sp.x, sp.y, fg and gz or (cam.z - 1.0))
end

-- A silhouette that fades in, holds a beat, fades out — never moves, never hits.
local function falseSilhouette()
    local models = cfg.Models or (MBT.Entities and MBT.Entities.Models) or { 'a_m_m_downtown_01' }
    local model = models[math.random(1, #models)]
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local t = 3000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then return end

    local sp = edgePoint(cfg.Distance or 14.0)
    local ped = CreatePed(4, hash, sp.x, sp.y, sp.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    local cam = GetGameplayCamCoord()
    SetEntityHeading(ped, GetHeadingFromVector_2d(cam.x - sp.x, cam.y - sp.y))

    SetEntityAlpha(ped, 0, false)
    for a = 45, 180, 45 do
        if not DoesEntityExist(ped) then break end
        SetEntityAlpha(ped, a, false); Wait(45)
    end
    Wait(cfg.HoldMs or 500)
    for a = 180, 0, -30 do
        if not DoesEntityExist(ped) then break end
        SetEntityAlpha(ped, a, false); Wait(45)
    end
    if DoesEntityExist(ped) then SetEntityAsMissionEntity(ped, true, true); DeleteEntity(ped) end
end

local function phantomSound()
    local s = cfg.Sound
    SendNUIMessage({ action = 'entity:sound', data = { file = (s and s.File) or 'tape_warble', volume = (s and s.Volume) or 0.4 } })
end

-- Fire one false event (harmless — no glimpseSeen, so no sanity hit).
local function fireError()
    if math.random(1, 100) <= (cfg.SilhouetteChance or 55) then
        falseSilhouette()
    else
        phantomSound()
    end
end

if cfg and cfg.Enabled then
    CreateThread(function()
        while true do
            local sleep = cfg.CheckMs or 6000
            local busy = Entities and Entities.IsActive and Entities.IsActive()
            if LocalPlayer.state[INLEVEL] and not busy then
                local sanity = LocalPlayer.state['mbt_backrooms:sanity'] or 100
                if sanity < (cfg.SanityBelow or 40) then
                    local haunt = LocalPlayer.state['mbt_backrooms:haunt']
                    local chance = (cfg.Chance or 30) * ((haunt and haunt.falseFreq) or 1.0)
                    if math.random(1, 100) <= chance then fireError() end
                end
            end
            Wait(sleep)
        end
    end)

    -- Debug: force a reality error now.
    if MBT.Debug then
        RegisterCommand('brhallucinate', function()
            if LocalPlayer.state[INLEVEL] then fireError()
            else MBTLog.Debug('brhallucinate: must be inside a level') end
        end, false)
    end
end
