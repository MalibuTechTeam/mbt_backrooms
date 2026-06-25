-- Found tapes/logs (F3 / Wave 1 — narrative spine). The server scatters a
-- per-visit subset of each level's pool; the client renders props + handles the
-- pickup prompt. Carrying artifacts out to the surface "recovers" them (the reward
-- is lore, not loot). Server-authoritative: pickup is validated like the exits.

local cfg = MBT.Artifacts
local STATE_INLEVEL   = 'mbt_backrooms:inLevel'
local STATE_ARTIFACTS = 'mbt_backrooms:artifacts'
local STATE_LITERACY  = 'mbt_backrooms:exitLiteracy'

local carrying  = {} -- carrying[src]  = { [id] = true } collected this run (kept across levels)
local recovered = {} -- recovered[src] = { [id] = true } — the Archive (recovered on the surface)

-- id -> category, used only to resolve the exits "sensory literacy" tier server-side
-- (the archive's text field-notes are computed client-side from config).
local idCat = {}
if cfg and cfg.Pool then
    for _, level in pairs(cfg.Pool) do
        for _, a in ipairs(level) do
            if a.id and a.category then idCat[a.id] = a.category end
        end
    end
end
local rm  = MBT.Archive and MBT.Archive.ResearchMode
local lit = rm and rm.Enabled and rm.ExitLiteracy and rm.ExitLiteracy.Enabled and rm.ExitLiteracy

-- Publish the player's exits literacy from their recovered set: count distinct
-- recovered `exits` tapes, pick the highest threshold <= that, push its
-- {rangeBonus, tellMult} so the exits module can scale its tell (Research Mode).
local function updateExitLiteracy(src)
    if not lit then return end
    local rec, count = recovered[src], 0
    if type(rec) == 'table' then
        for id in pairs(rec) do if idCat[id] == 'exits' then count = count + 1 end end
    end
    local best
    for threshold, v in pairs(lit) do
        if type(threshold) == 'number' and count >= threshold and (not best or threshold > best.t) then
            best = { t = threshold, v = v }
        end
    end
    Player(src).state:set(STATE_LITERACY, best and best.v or nil, true)
end

local function clearState(src)
    Player(src).state:set(STATE_ARTIFACTS, {}, true)
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
            -- Surface: everything carried this run becomes recovered (the archive).
            local ids = carrying[src]
            if ids then
                recovered[src] = recovered[src] or {}
                local n = 0
                for id in pairs(ids) do recovered[src][id] = true; n = n + 1 end
                if n > 0 then
                    local msg = (MBT.Locale and MBT.Locale.notify_recovered)
                        or 'Recovered %d recording(s) from the Backrooms'
                    Utils.Notify(src, msg:format(n))
                end
                updateExitLiteracy(src)
            end
            carrying[src] = nil
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

        -- The published active set is the dedupe source of truth (pruned on collect).
        local active = Player(src).state[STATE_ARTIFACTS]
        local isActive = false
        if type(active) == 'table' then
            for _, a in ipairs(active) do if a.i == poolIndex then isActive = true break end end
        end
        if not isActive then return end

        local ped = GetPlayerPed(src)
        if not ped or ped == 0 or #(GetEntityCoords(ped) - art.coords) > ((cfg.PickupRange or 1.8) + 2.0) then
            Utils.MbtDebugger('collect rejected: not near', src, poolIndex)
            return
        end

        carrying[src] = carrying[src] or {}
        carrying[src][art.id or ('lv' .. level .. '_' .. poolIndex)] = true

        -- Drop it from the published set so the client despawns it and never
        -- respawns it (otherwise the prop + its [E] prompt come straight back).
        local remaining = {}
        for _, a in ipairs(active) do
            if a.i ~= poolIndex then remaining[#remaining + 1] = a end
        end
        Player(src).state:set(STATE_ARTIFACTS, remaining, true)

        TriggerClientEvent('mbt_backrooms:artifactCollected', src, poolIndex, art.text or '', art.type or 'log')
    end)

    -- Surface terminal (Section 10) asks for the player's archive (recovered ids).
    RegisterNetEvent('mbt_backrooms:openArchive', function()
        local src = source
        local rec, ids = recovered[src], {}
        if type(rec) == 'table' then for id in pairs(rec) do ids[#ids + 1] = id end end
        TriggerClientEvent('mbt_backrooms:archiveData', src, ids)
    end)

    AddEventHandler('playerDropped', function()
        carrying[source], recovered[source] = nil, nil
    end)
end
