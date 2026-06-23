-- Curated exits (F2 / Wave 1). The server publishes a per-visit set of active,
-- invisible exits in the `activeExits` state bag. There is NO marker and NO
-- prompt: a screen "tell" intensifies as you near one, and lingering inside it
-- builds a soft pull-in that teleports you through (cancellable by stepping out).
-- The deliberate [E] doors (MBT.BackRooms) are handled in core/client.lua.

local ce = MBT.CuratedExits
local pullHoldUntil = 0 -- shared with the inLevel handler: latch pull=1 across the teleport

local function isLocked()
    return LocalPlayer.state['mbt_backrooms:exitLocked'] == true
end

local function sendWarp(tell, pull)
    SendNUIMessage({ action = 'exit:warp', data = { tell = tell, pull = pull } })
end

CreateThread(function()
    if not ce or not ce.Enabled then return end

    local tellRange = ce.TellRange or 9.0
    local pullMs = (MBT.SoftPullIn and MBT.SoftPullIn.Enabled and MBT.SoftPullIn.DurationMs) or 0
    local insideSince, insideIdx = nil, nil
    local cooldownUntil = 0
    local cleared = true
    local lastTell = -1.0

    while true do
        local sleep = 600
        local exits = LocalPlayer.state['mbt_backrooms:inLevel'] and LocalPlayer.state['mbt_backrooms:activeExits']

        if type(exits) == 'table' and #exits > 0 and not isLocked() then
            local pc = GetEntityCoords(PlayerPedId())
            local bestIdx, bestDist, bestR = nil, 1e9, 1.6
            for _, e in ipairs(exits) do
                local d = #(pc - vector3(e.x, e.y, e.z))
                if d < bestDist then bestDist, bestIdx, bestR = d, e.i, (e.r or 1.6) end
            end

            if bestDist <= tellRange then
                cleared = false
                sleep = 120
                -- clamp the radius in the normalisation so a misconfigured large
                -- radius can't collapse the ramp into a binary tell.
                local tell = (tellRange - bestDist) / math.max(0.1, tellRange - math.min(bestR, tellRange * 0.5))
                if tell < 0 then tell = 0 elseif tell > 1 then tell = 1 end

                local pull, now = 0.0, GetGameTimer()
                if now < pullHoldUntil then
                    pull = 1.0 -- latched after firing: hold the warp until the teleport lands
                elseif bestDist <= bestR and pullMs > 0 and now >= cooldownUntil then
                    if insideIdx ~= bestIdx then insideIdx, insideSince = bestIdx, now end
                    pull = (now - insideSince) / pullMs
                    if pull >= 1.0 then
                        pull = 1.0
                        TriggerServerEvent('mbt_backrooms:requestCuratedExit', bestIdx)
                        cooldownUntil = now + 4000  -- don't refire before the teleport lands
                        pullHoldUntil = now + 2000  -- keep pull=1 (no un-pull flash) until inLevel changes
                        insideSince, insideIdx = nil, nil
                    end
                else
                    insideSince, insideIdx = nil, nil
                end

                if pull > 0.0 or math.abs(tell - lastTell) >= 0.04 then
                    sendWarp(tell, pull)
                    lastTell = tell
                end
            elseif not cleared then
                cleared, insideSince, insideIdx, lastTell = true, nil, nil, -1.0
                sendWarp(0.0, 0.0)
            end
        elseif not cleared then
            cleared, insideSince, insideIdx, lastTell = true, nil, nil, -1.0
            sendWarp(0.0, 0.0)
        end

        Wait(sleep)
    end
end)

-- Clear the warp overlay the moment we leave a level.
AddStateBagChangeHandler('mbt_backrooms:inLevel', '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    -- Any inLevel change = a teleport just landed (entered/left). Drop the latch
    -- and clear the overlay so a held pull never bleeds into the next room.
    pullHoldUntil = 0
    SendNUIMessage({ action = 'exit:warp', data = { tell = 0, pull = 0 } })
end)

-- Debug: list this visit's active curated exits + your distance to each (for
-- placing the pool coords against Iakko's map).
if MBT.Debug then
    RegisterCommand('brexits', function()
        local exits = LocalPlayer.state['mbt_backrooms:activeExits']
        if type(exits) ~= 'table' or #exits == 0 then
            MBTLog.Debug('brexits: no active curated exits (must be inside a level)')
            return
        end
        local pc = GetEntityCoords(PlayerPedId())
        for _, e in ipairs(exits) do
            MBTLog.Debug(('brexits: pool#%d  dist=%.1f  at (%.1f, %.1f, %.1f)  r=%.1f')
                :format(e.i, #(pc - vector3(e.x, e.y, e.z)), e.x, e.y, e.z, e.r or 1.6))
        end
    end, false)
end
