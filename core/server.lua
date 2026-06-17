-- Server-authoritative teleport core.
-- Clients only REQUEST entry/exit; the server validates and dispatches the
-- destination, and owns the player's backrooms state via state bags.

math.randomseed(GetGameTimer())

local STATE_INLEVEL = 'mbt_backrooms:inLevel'   -- false (outside) | level index (inside)
local STATE_ENTRY   = 'mbt_backrooms:entryTime' -- GetGameTimer() at entry | false
local STATE_LOCKED  = 'mbt_backrooms:exitLocked'-- true while a transition is mid-flight

local REQUEST_COOLDOWN = 500 -- ms (~2 requests/second/player)
local UNLOCK_SAFETY    = 5000 -- ms — force-unlock if the client never confirms

-- Server remembers the pending destination level per player so teleportDone
-- finalizes authoritative state without trusting any client-sent value.
local pendingLevel = {}

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
    pendingLevel[src] = level
    Player(src).state:set(STATE_LOCKED, true, true)
    TriggerClientEvent('mbt_backrooms:doTeleport', src, vector3(coords.x, coords.y, coords.z))

    SetTimeout(UNLOCK_SAFETY, function()
        if Player(src) and Player(src).state[STATE_LOCKED] then
            pendingLevel[src] = nil
            Player(src).state:set(STATE_LOCKED, false, true)
        end
    end)
end

RegisterNetEvent('mbt_backrooms:requestEntry', function(data)
    local src = source
    if not Utils.RateLimit(src, 'teleport', REQUEST_COOLDOWN) then return end
    if Player(src).state[STATE_LOCKED] then return end

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
    if Player(src).state[STATE_LOCKED] then return end

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

-- Client confirms the move finished; finalize authoritative state.
RegisterNetEvent('mbt_backrooms:teleportDone', function()
    local src = source
    local level = pendingLevel[src]
    pendingLevel[src] = nil

    local state = Player(src).state
    state:set(STATE_LOCKED, false, true)
    if level then
        state:set(STATE_INLEVEL, level, true)
        state:set(STATE_ENTRY, GetGameTimer(), true)
    else
        state:set(STATE_INLEVEL, false, true)
        state:set(STATE_ENTRY, false, true)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingLevel[src] = nil
    Utils.ClearRateLimit(src)
end)
