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

-- Pull-in particle: a localized paper-swirl that appears ONLY once the pull is
-- past StartAt, scaling up with progress, then hard-cut on teleport/cancel. At
-- rest the exit shows nothing — it stays unmarked. "Room losing pressure", not a
-- portal (Codex). core/env_dust_devil_urban_sma lifts paper litter.
local Ptfx = MBT.SoftPullIn and MBT.SoftPullIn.Ptfx
local pullPtfx, ptfxReady = nil, false

local function ensurePtfxAsset()
    if ptfxReady then return true end
    if not (Ptfx and Ptfx.Enabled) then return false end
    RequestNamedPtfxAsset(Ptfx.Dict)
    local t = 1500
    while not HasNamedPtfxAssetLoaded(Ptfx.Dict) and t > 0 do Wait(50); t = t - 50 end
    ptfxReady = HasNamedPtfxAssetLoaded(Ptfx.Dict)
    return ptfxReady
end

local function stopPullPtfx()
    if pullPtfx then
        if DoesParticleFxLoopedExist(pullPtfx) then StopParticleFxLooped(pullPtfx, false) end
        pullPtfx = nil
    end
end

-- Drive the swirl from pull progress (0..1) at the exit coords.
local function updatePullPtfx(progress, x, y, z)
    if not (Ptfx and Ptfx.Enabled) then return end
    local startAt = Ptfx.StartAt or 0.35
    if progress < startAt then
        stopPullPtfx()
        return
    end
    if not pullPtfx then
        if not ensurePtfxAsset() then return end
        UseParticleFxAsset(Ptfx.Dict)
        -- raise off the floor so the swirl reads in first person (you're standing
        -- in the exit; a ground-level column at your feet is hard to see).
        pullPtfx = StartParticleFxLoopedAtCoord(Ptfx.Name, x, y, z + 0.8, 0.0, 0.0, 0.0,
            Ptfx.MinScale or 0.2, false, false, false, false)
        if MBT.Debug then MBTLog.Debug('pull-in ptfx spawned', Ptfx.Name, 'at', x, y, z + 0.8, 'handle', pullPtfx) end
    end
    if pullPtfx and DoesParticleFxLoopedExist(pullPtfx) then
        local f = (progress - startAt) / math.max(0.001, 1.0 - startAt)
        local minS, maxS = Ptfx.MinScale or 0.2, Ptfx.MaxScale or 0.8
        SetParticleFxLoopedScale(pullPtfx, minS + (maxS - minS) * f)
    end
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
            local bestIdx, bestDist, bestR, bx, by, bz = nil, 1e9, 1.6, 0.0, 0.0, 0.0
            for _, e in ipairs(exits) do
                local d = #(pc - vector3(e.x, e.y, e.z))
                if d < bestDist then bestDist, bestIdx, bestR, bx, by, bz = d, e.i, (e.r or 1.6), e.x, e.y, e.z end
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
                updatePullPtfx(pull, bx, by, bz)
            elseif not cleared then
                cleared, insideSince, insideIdx, lastTell = true, nil, nil, -1.0
                sendWarp(0.0, 0.0)
                stopPullPtfx()
            end
        elseif not cleared then
            cleared, insideSince, insideIdx, lastTell = true, nil, nil, -1.0
            sendWarp(0.0, 0.0)
            stopPullPtfx()
        end

        Wait(sleep)
    end
end)

-- Clear the warp overlay the moment we leave a level.
AddStateBagChangeHandler('mbt_backrooms:inLevel', '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    -- Any inLevel change = a teleport just landed (entered/left). Drop the latch,
    -- hard-cut the swirl, and clear the overlay so neither bleeds into the next room.
    pullHoldUntil = 0
    stopPullPtfx()
    SendNUIMessage({ action = 'exit:warp', data = { tell = 0, pull = 0 } })
end)

-- Never leave an orphaned particle if the resource stops mid pull-in.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopPullPtfx() end
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
