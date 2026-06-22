-- Sanity (F4) presentation. Reacts to the LOCAL player's sanity state bag:
-- pushes a "dread" value (0..1) to the NUI vignette and adds camera shake while
-- sanity is critical. Server owns the value; this only renders it.

local cfg = MBT.Sanity
local sanity = 100

local function dread()
    if not cfg.Enabled then return 0 end
    if not LocalPlayer.state['mbt_backrooms:inLevel'] then return 0 end -- only inside a level
    local low = cfg.LowThreshold or 50
    if sanity >= low then return 0 end
    return (low - sanity) / low
end

local function push()
    SendNUIMessage({ action = 'sanity:set', data = { dread = dread() } })
end

AddStateBagChangeHandler('mbt_backrooms:sanity', '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    sanity = value or 100
    push()
end)

-- Re-evaluate when entering/leaving a level (presentation only shows inside).
AddStateBagChangeHandler('mbt_backrooms:inLevel', '', function(bag, _, _)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    push()
end)

-- Critical-sanity camera shake (native; gated by accessibility).
if cfg.Enabled then
    CreateThread(function()
        while true do
            local sleep = 2500
            local crit = cfg.CriticalThreshold or 20
            if sanity < crit and LocalPlayer.state['mbt_backrooms:inLevel'] then
                sleep = 2000
                local reduceMotion = MBT.Atmosphere and MBT.Atmosphere.ReduceMotion
                if not reduceMotion then
                    local sev = (crit - sanity) / crit -- 0..1 as it worsens
                    ShakeGameplayCam('DRUNK_SHAKE', 0.12 + 0.18 * sev)
                    Wait(700)
                    StopGameplayCamShaking(true)
                end
            end
            Wait(sleep)
        end
    end)
end
