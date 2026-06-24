-- Light (F4 survival) — torch toggle + darkness pressure. The torch is a light
-- source + a gameplay state ('mbt_backrooms:torch'); it NEVER touches the
-- timecycle (the atmosphere owns that). Sanity (server) reads the state for the
-- dark-decay multiplier; the entity director reads it for "light attracts".
--   Mode 'spotlight' = a drawn cone from the camera (drop-in safe).
--   Mode 'weapon'    = WEAPON_FLASHLIGHT (real engine light, takes the weapon slot).

local cfg = MBT.Light
local TORCH = 'mbt_backrooms:torch'
local FLASHLIGHT = GetHashKey('WEAPON_FLASHLIGHT')

local torchOn = false
local prevWeapon = nil

local function inLevel()
    return LocalPlayer.state['mbt_backrooms:inLevel']
end

local function setWeaponTorch(on)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    if on then
        prevWeapon = GetSelectedPedWeapon(ped)
        GiveWeaponToPed(ped, FLASHLIGHT, 1, false, true)
        SetCurrentPedWeapon(ped, FLASHLIGHT, true)
    else
        RemoveWeaponFromPed(ped, FLASHLIGHT)
        if prevWeapon then SetCurrentPedWeapon(ped, prevWeapon, true) end
        prevWeapon = nil
    end
end

local function setTorch(on)
    if torchOn == on then return end
    torchOn = on
    LocalPlayer.state:set(TORCH, on, true) -- replicated: the server reads it for decay
    if cfg.Mode == 'weapon' then setWeaponTorch(on) end
end

local function reset()
    if torchOn then setTorch(false) end
end

RegisterCommand('mbt_torch', function()
    if cfg.Enabled and inLevel() then setTorch(not torchOn) end
end, false)
RegisterKeyMapping('mbt_torch',
    (MBT.Locale and MBT.Locale.keymapping_torch) or 'Backrooms: toggle torch',
    'keyboard', cfg.Key or 'F')

-- Drawn-cone mode: spotlight from the gameplay camera, only while on + inside.
CreateThread(function()
    if not (cfg and cfg.Enabled) then return end
    while true do
        if torchOn and cfg.Mode == 'spotlight' and inLevel() then
            local cam = GetGameplayCamCoord()
            local rot = GetGameplayCamRot(2)
            local rz, rx = math.rad(rot.z), math.rad(rot.x)
            local cosRx = math.cos(rx)
            local dir = vector3(-math.sin(rz) * cosRx, math.cos(rz) * cosRx, math.sin(rx))
            DrawSpotLight(cam.x, cam.y, cam.z, dir.x, dir.y, dir.z,
                255, 250, 235, cfg.Range or 25.0, cfg.Brightness or 4.0, 0.0, cfg.Radius or 7.0, 1.0)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Torch off when leaving a level (and optionally on at entry); off on resource stop.
AddStateBagChangeHandler('mbt_backrooms:inLevel', '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    if value then
        if cfg.Enabled and cfg.StartOn then setTorch(true) end
    else
        reset()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then reset() end
end)
