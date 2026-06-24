-- Almond Water (F4 survival counterplay) — server. Scatters a per-visit subset of
-- each level's pool as bottles; the client renders props + handles the [E] drink.
-- Drinking restores sanity on the spot (standalone — no inventory). Server-auth:
-- validated like the artifacts/exits (active-set + proximity + rate limit).

local cfg = MBT.AlmondWater
local STATE_INLEVEL = 'mbt_backrooms:inLevel'
local STATE_WATER   = 'mbt_backrooms:almondwater'

local taken = {} -- taken[src] = { [poolIndex] = true } for the current level

local function activate(src, level)
    local pool = cfg.Pool and cfg.Pool[level]
    if not pool or #pool == 0 then
        Player(src).state:set(STATE_WATER, {}, true); taken[src] = nil; return
    end
    local idx = {}
    for i = 1, #pool do idx[i] = i end
    for i = #idx, 2, -1 do local j = math.random(1, i); idx[i], idx[j] = idx[j], idx[i] end
    local n = math.min(cfg.SpawnPerVisit or 2, #pool)
    local active = {}
    for k = 1, n do
        local b = pool[idx[k]]
        active[#active + 1] = { i = idx[k], x = b.coords.x, y = b.coords.y, z = b.coords.z }
    end
    taken[src] = {}
    Player(src).state:set(STATE_WATER, active, true)
end

if cfg and cfg.Enabled then
    AddStateBagChangeHandler(STATE_INLEVEL, nil, function(bagName, _, value)
        local src = GetPlayerFromStateBagName(bagName)
        if src == 0 then return end
        if value then
            activate(src, value)
        else
            Player(src).state:set(STATE_WATER, {}, true); taken[src] = nil
        end
    end)

    RegisterNetEvent('mbt_backrooms:requestDrink', function(poolIndex)
        local src = source
        if not Utils.RateLimit(src, 'drink', 400) then return end

        local level = Player(src).state[STATE_INLEVEL]
        if not level then return end
        local pool = cfg.Pool and cfg.Pool[level]
        local bottle = pool and pool[poolIndex]
        if not bottle then return end

        local active = Player(src).state[STATE_WATER]
        local isActive = false
        if type(active) == 'table' then
            for _, a in ipairs(active) do if a.i == poolIndex then isActive = true break end end
        end
        if not isActive then return end
        if taken[src] and taken[src][poolIndex] then return end

        local ped = GetPlayerPed(src)
        if not ped or ped == 0 or #(GetEntityCoords(ped) - bottle.coords) > ((cfg.PickupRange or 1.8) + 2.0) then return end

        -- Drink on the spot. If (near) full, Sanity.Restore returns false -> leave
        -- the bottle for later instead of wasting it.
        if not (Sanity and Sanity.Restore and Sanity.Restore(src, cfg.SanityRestore or 35)) then
            TriggerClientEvent('mbt_backrooms:almondFull', src) -- "no point drinking now"
            return
        end

        taken[src] = taken[src] or {}
        taken[src][poolIndex] = true
        local remaining = {}
        for _, a in ipairs(active) do if a.i ~= poolIndex then remaining[#remaining + 1] = a end end
        Player(src).state:set(STATE_WATER, remaining, true)
        TriggerClientEvent('mbt_backrooms:almondDrunk', src, poolIndex)
    end)

    AddEventHandler('playerDropped', function() taken[source] = nil end)
end
