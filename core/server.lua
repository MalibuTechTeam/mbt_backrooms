-- Server-authoritative teleport core.
-- Clients only REQUEST entry/exit; the server validates and dispatches the
-- destination, and owns the player's backrooms state via state bags.

math.randomseed(GetGameTimer())

local STATE_INLEVEL = 'mbt_backrooms:inLevel'   -- false (outside) | level index (inside)
local STATE_ENTRY   = 'mbt_backrooms:entryTime' -- GetGameTimer() at entry | false
local STATE_LOCKED  = 'mbt_backrooms:exitLocked'-- true while a transition is mid-flight

local REQUEST_COOLDOWN = 500   -- ms (~2 requests/second/player)
local UNLOCK_SAFETY    = 8000  -- ms — clear a stuck lock (must exceed worst-case client teleport path)
local PENDING_EXPIRY   = 30000 -- ms — abandon a pending teleport that never confirmed

-- Per-player pending teleport: { token = n, level = idx|false }. The token
-- authenticates teleportDone so a client can't spoof state transitions.
local pendingTeleport = {}
local tokenCounter = 0

local function pickBackroom()
    local i = math.random(1, #MBT.Coords)
    return MBT.Coords[i], i
end

local function pickSurface()
    return MBT.RandomExitPoint[math.random(1, #MBT.RandomExitPoint)]
end

-- Anti-exploit: for interaction points, verify the player is actually there
-- (a small grace margin absorbs latency/movement). Falls are rate-limited only.
local function isNearPoint(src, index)
    local point = MBT.BackRooms[index]
    if not point then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - point.Coords) <= (point.Range + 2.0)
end

local function dispatchTeleport(src, coords, level)
    tokenCounter = tokenCounter + 1
    local token = tokenCounter
    pendingTeleport[src] = { token = token, level = level }

    Player(src).state:set(STATE_LOCKED, true, true)
    TriggerClientEvent('mbt_backrooms:doTeleport', src, vector3(coords.x, coords.y, coords.z), token)

    -- Unstick the lock if the client never confirms. Clear the lock ONLY — keep
    -- pendingTeleport so a late but valid (token-matched) teleportDone can still
    -- finalize the level state.
    SetTimeout(UNLOCK_SAFETY, function()
        local p = pendingTeleport[src]
        if p and p.token == token then
            Player(src).state:set(STATE_LOCKED, false, true)
        end
    end)

    -- Hard-abandon a pending teleport that never confirmed at all.
    SetTimeout(PENDING_EXPIRY, function()
        local p = pendingTeleport[src]
        if p and p.token == token then
            pendingTeleport[src] = nil
        end
    end)
end

RegisterNetEvent('mbt_backrooms:requestEntry', function(data)
    local src = source
    if not Utils.RateLimit(src, 'teleport', REQUEST_COOLDOWN) then return end

    local state = Player(src).state
    if state[STATE_LOCKED] or state[STATE_INLEVEL] then return end

    data = data or {}
    if data.reason == 'interact' then
        local point = MBT.BackRooms[data.point]
        if not point or point.Type ~= 'Enter' or not isNearPoint(src, data.point) then
            Utils.MbtDebugger('rejected interact entry', src, data.point)
            return
        end
    elseif data.reason ~= 'fall' then
        return
    end

    local coords, level = pickBackroom()
    dispatchTeleport(src, coords, level)
end)

RegisterNetEvent('mbt_backrooms:requestExit', function(data)
    local src = source
    if not Utils.RateLimit(src, 'teleport', REQUEST_COOLDOWN) then return end

    local state = Player(src).state
    if state[STATE_LOCKED] or not state[STATE_INLEVEL] then return end

    data = data or {}
    local point = MBT.BackRooms[data.point]
    if not point or point.Type ~= 'Exit' or not isNearPoint(src, data.point) then return end

    local coords, level
    if math.random(1, 100) <= MBT.ExitToBackroomChance then
        coords, level = pickBackroom()
    else
        coords, level = pickSurface(), false
    end
    dispatchTeleport(src, coords, level)
end)

-- Client confirms the move finished; finalize authoritative state. The token
-- must match the pending dispatch — ignore spoofed / stale confirmations.
RegisterNetEvent('mbt_backrooms:teleportDone', function(token)
    local src = source
    local p = pendingTeleport[src]
    if not p or p.token ~= token then return end
    pendingTeleport[src] = nil

    local state = Player(src).state
    state:set(STATE_LOCKED, false, true)
    if p.level then
        state:set(STATE_INLEVEL, p.level, true)
        state:set(STATE_ENTRY, GetGameTimer(), true)
    else
        state:set(STATE_INLEVEL, false, true)
        state:set(STATE_ENTRY, false, true)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingTeleport[src] = nil
    Utils.ClearRateLimit(src)
end)

-- Resource restart reconciliation: Lua tables reset but state bags persist, so
-- a player flagged inLevel before the restart would be out of sync. Clear
-- everyone's backrooms state so server truth matches the fresh script.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local state = Player(src).state
        state:set(STATE_LOCKED, false, true)
        state:set(STATE_INLEVEL, false, true)
        state:set(STATE_ENTRY, false, true)
    end
end)
