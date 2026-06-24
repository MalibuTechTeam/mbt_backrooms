-- Found tapes/logs (F3 / Wave 1 — narrative spine). The server scatters a
-- per-visit subset of each level's pool; the client renders props + handles the
-- pickup prompt. Carrying artifacts out to the surface "recovers" them (the reward
-- is lore, not loot). Server-authoritative: pickup is validated like the exits.

local cfg = MBT.Artifacts
local STATE_INLEVEL   = 'mbt_backrooms:inLevel'
local STATE_ARTIFACTS = 'mbt_backrooms:artifacts'

local carried = {}    -- carried[src] = count carried this run (kept across levels)
local collected = {}  -- collected[src] = { [poolIndex] = true } for the current level

local function clearState(src)
    Player(src).state:set(STATE_ARTIFACTS, {}, true)
    collected[src] = nil
end

-- Scatter SpawnPerVisit artifacts from the level pool; publish {i,x,y,z,type}.
-- (dest text/lore stays server-side and is sent on collect, not exposed up-front.)
local function activate(src, level)
    local pool = cfg.Pool and cfg.Pool[level]
    if not pool or #pool == 0 then clearState(src); return end
    local idx = {}
    for i = 1, #pool do idx[i] = i end
    for i = #idx, 2, -1 do -- Fisher–Yates
        local j = math.random(1, i)
        idx[i], idx[j] = idx[j], idx[i]
    end
    local n = math.min(cfg.SpawnPerVisit or 2, #pool)
    local active = {}
    for k = 1, n do
        local a = pool[idx[k]]
        active[#active + 1] = { i = idx[k], x = a.coords.x, y = a.coords.y, z = a.coords.z, type = a.type or 'log' }
    end
    collected[src] = {}
    Player(src).state:set(STATE_ARTIFACTS, active, true)
end

if cfg and cfg.Enabled then
    -- Drive activation/recovery off the authoritative inLevel state.
    AddStateBagChangeHandler(STATE_INLEVEL, nil, function(bagName, _, value)
        local src = GetPlayerFromStateBagName(bagName)
        if src == 0 then return end
        if value then
            activate(src, value) -- new level: fresh scatter (carried count is kept)
        else
            local n = carried[src] or 0
            if n > 0 and Bridge and Bridge.Notify then
                local msg = (MBT.Locale and MBT.Locale.notify_recovered)
                    or 'Recovered %d recording(s) from the Backrooms'
                Bridge.Notify(src, msg:format(n))
            end
            carried[src] = 0
            clearState(src)
        end
    end)

    RegisterNetEvent('mbt_backrooms:requestCollect', function(poolIndex)
        local src = source
        if not Utils.RateLimit(src, 'collect', 400) then return end

        local level = Player(src).state[STATE_INLEVEL]
        if not level then return end
        local pool = cfg.Pool and cfg.Pool[level]
        local art = pool and pool[poolIndex]
        if not art then return end

        -- must be one of the player's currently active artifacts, not already taken
        local active = Player(src).state[STATE_ARTIFACTS]
        local isActive = false
        if type(active) == 'table' then
            for _, a in ipairs(active) do if a.i == poolIndex then isActive = true break end end
        end
        if not isActive then return end
        if collected[src] and collected[src][poolIndex] then return end

        local ped = GetPlayerPed(src)
        if not ped or ped == 0 or #(GetEntityCoords(ped) - art.coords) > ((cfg.PickupRange or 1.8) + 2.0) then
            Utils.MbtDebugger('collect rejected: not near', src, poolIndex)
            return
        end

        collected[src] = collected[src] or {}
        collected[src][poolIndex] = true
        carried[src] = (carried[src] or 0) + 1
        TriggerClientEvent('mbt_backrooms:artifactCollected', src, poolIndex, art.text or '', art.type or 'log')
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        carried[src] = nil
        collected[src] = nil
    end)
end
