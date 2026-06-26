-- First-contact dread (Tweak A, lore-faithful). The first time another lost soul
-- comes close in your level, fire the reality-jolt + report a sanity spike to the
-- server — for a beat you can't tell a person from the entity. No nameplate/marker.
-- Hysteresis (per player) stops a lingering wanderer from re-triggering; a global
-- cooldown stops a crowd from spamming it. Server owns the actual sanity loss.

local cfg = MBT.PlayerContact
local INLEVEL = 'mbt_backrooms:inLevel'

if cfg and cfg.Enabled then
    local inRange = {}      -- serverId -> true while inside the startle bubble (hysteresis)
    local lastStartle = 0   -- GetGameTimer() of the last startle (global cooldown)

    local function startle(sid)
        if Atmosphere and Atmosphere.EntryFx then Atmosphere.EntryFx() end -- the "is it the entity?" jolt
        TriggerServerEvent('mbt_backrooms:playerContact')
        if MBT.Debug then Utils.MbtDebugger('first-contact startle vs', sid) end
    end

    CreateThread(function()
        local range    = cfg.Range or 22.0
        local outRange = range + (cfg.Linger or 6.0)
        local cd       = (cfg.CooldownSec or 25) * 1000
        while true do
            if not LocalPlayer.state[INLEVEL] then
                inRange = {} -- left the level: forget who's near so a fresh visit re-arms
                Wait(1500)
            else
                local myCoords = GetEntityCoords(PlayerPedId())
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= PlayerId() then
                        local ped = GetPlayerPed(pid)
                        if ped ~= 0 and DoesEntityExist(ped) then
                            local sid = GetPlayerServerId(pid)
                            local d = #(myCoords - GetEntityCoords(ped))
                            -- only fellow wanderers (in a level) count, never surface players
                            if d <= range and Player(sid).state[INLEVEL] then
                                if not inRange[sid] then
                                    inRange[sid] = true
                                    local now = GetGameTimer()
                                    if (now - lastStartle) > cd then
                                        lastStartle = now
                                        startle(sid)
                                    end
                                end
                            elseif d > outRange then
                                inRange[sid] = nil -- moved away: a later approach re-arms
                            end
                        end
                    end
                end
                Wait(700)
            end
        end
    end)

    -- Debug: fire a first-contact startle on demand (no second player needed).
    if MBT.Debug then
        RegisterCommand('brcontact', function() startle(0) end, false)
    end
end
