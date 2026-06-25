-- Server-authoritative teleport core.
-- Clients only REQUEST entry/exit; the server validates and dispatches the
-- destination, and owns the player's backrooms state via state bags.

math.randomseed(GetGameTimer())

local STATE_INLEVEL = 'mbt_backrooms:inLevel'   -- false (outside) | level index (inside)
local STATE_ENTRY   = 'mbt_backrooms:entryTime' -- GetGameTimer() at entry | false
local STATE_LOCKED  = 'mbt_backrooms:exitLocked'-- true while a transition is mid-flight
local STATE_EXITS   = 'mbt_backrooms:activeExits'-- per-visit active curated exits (server-picked)

local REQUEST_COOLDOWN = 500   -- ms (~2 requests/second/player)
local UNLOCK_SAFETY    = 8000  -- ms — clear a stuck lock (must exceed worst-case client teleport path)
local PENDING_EXPIRY   = 30000 -- ms — abandon a pending teleport that never confirmed

-- Per-player pending teleport: { token = n, level = idx|false }. The token
-- authenticates teleportDone so a client can't spoof state transitions.
local pendingTeleport = {}
local tokenCounter = 0

-- `exclude` (optional): avoid this level index so a curated 'backroom' exit never
-- dumps you back where you started (anti-bounce).
local function pickBackroom(exclude)
    if #MBT.Coords <= 1 then return MBT.Coords[1], 1 end
    local i
    repeat i = math.random(1, #MBT.Coords) until i ~= exclude
    return MBT.Coords[i], i
end

local function pickSurface()
    return MBT.RandomExitPoint[math.random(1, #MBT.RandomExitPoint)]
end

-- Weighted exit roll (F2). Uses the per-point override if present, else the
-- default rule. Returns coords, level (level = false for a surface escape).
local function rollExit(pointIndex)
    local rules = (MBT.ExitRules and MBT.ExitRules[pointIndex])
        or (MBT.ExitRules and MBT.ExitRules.default)
        or { surface = 30, backroom = 70 }

    local total = 0
    for _, w in pairs(rules) do total = total + (w or 0) end
    if total <= 0 then return pickBackroom() end -- misconfigured -> stay trapped

    local r = math.random(1, total)
    local acc = 0
    for category, w in pairs(rules) do
        acc = acc + (w or 0)
        if r <= acc then
            if category == 'surface' then
                return pickSurface(), false
            end
            return pickBackroom() -- 'backroom' (and any future trapped category)
        end
    end

    return pickBackroom() -- fallback
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

-- Curated exits (F2 / Wave 1): pick ActivePerVisit from the level's pool and
-- publish them via state bag (server picks; the client only senses them). Stored
-- as { i, x, y, z, r } — `dest` stays server-side so it can't be spoofed.
local function activateExits(src, level)
    local ce = MBT.CuratedExits
    local pool = ce and ce.Enabled and ce.Pool and ce.Pool[level]
    if not pool or #pool == 0 then
        Player(src).state:set(STATE_EXITS, {}, true)
        return
    end
    local idx = {}
    for i = 1, #pool do idx[i] = i end
    for i = #idx, 2, -1 do -- Fisher–Yates
        local j = math.random(1, i)
        idx[i], idx[j] = idx[j], idx[i]
    end
    local n = math.min(ce.ActivePerVisit or 2, #pool)
    local active = {}
    for k = 1, n do
        local e = pool[idx[k]]
        active[#active + 1] = { i = idx[k], x = e.coords.x, y = e.coords.y, z = e.coords.z, r = e.radius or 1.6 }
    end
    Player(src).state:set(STATE_EXITS, active, true)
end

-- No-clip zone state per player: { zone, passed } (passed=false means the
-- chance roll for this entry already failed — no re-roll until they leave).
local zoneState = {}

local function inNoClipZone(src, index)
    local z = MBT.NoClipZones and MBT.NoClipZones[index]
    if not z then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    if z.radius then
        return #(c - z.coords) <= (z.radius + 1.5)
    end
    local d = c - z.coords
    return math.abs(d.x) <= (z.size.x + 1.5) and math.abs(d.y) <= (z.size.y + 1.5) and math.abs(d.z) <= (z.size.z + 1.5)
end

RegisterNetEvent('mbt_backrooms:zoneEnter', function(index)
    local src = source
    local z = MBT.NoClipZones and MBT.NoClipZones[index]
    if not z then Utils.MbtDebugger('zoneEnter: no such zone', index); return end
    if zoneState[src] then return end -- already handling a zone entry (anti re-roll spam)

    local state = Player(src).state
    if state[STATE_LOCKED] or state[STATE_INLEVEL] then
        Utils.MbtDebugger('zoneEnter rejected: locked/inLevel', src)
        return
    end
    if not inNoClipZone(src, index) then
        Utils.MbtDebugger('zoneEnter rejected: not in zone (server pos check)', src, index)
        return
    end

    -- Roll the chance ONCE per physical entry.
    if math.random(1, 100) > (z.chance or 100) then
        Utils.MbtDebugger('zoneEnter: chance failed', src, index)
        zoneState[src] = { zone = index, passed = false }
        return
    end

    local dwellMs = (z.dwell or 0) * 1000
    if dwellMs <= 0 then
        Utils.MbtDebugger('zoneEnter: teleporting (instant)', src, index)
        zoneState[src] = nil
        dispatchTeleport(src, pickBackroom())
    else
        zoneState[src] = { zone = index, passed = true }
        SetTimeout(dwellMs, function()
            local st = zoneState[src]
            if not st or st.zone ~= index or not st.passed then return end
            local s2 = Player(src).state
            if s2[STATE_LOCKED] or s2[STATE_INLEVEL] or not inNoClipZone(src, index) then
                zoneState[src] = nil
                return
            end
            zoneState[src] = nil
            dispatchTeleport(src, pickBackroom())
        end)
    end
end)

RegisterNetEvent('mbt_backrooms:zoneExit', function(index)
    local src = source
    local st = zoneState[src]
    if st and st.zone == index then zoneState[src] = nil end
end)

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

    local coords, level = rollExit(data.point)
    dispatchTeleport(src, coords, level)
end)

-- Curated exit used (soft pull-in completed). The dest is the server's — we only
-- accept it if this pool entry is one of the player's CURRENTLY active exits and
-- they're actually standing in it.
RegisterNetEvent('mbt_backrooms:requestCuratedExit', function(poolIndex)
    local src = source
    if not Utils.RateLimit(src, 'teleport', REQUEST_COOLDOWN) then return end

    local state = Player(src).state
    local level = state[STATE_INLEVEL]
    if state[STATE_LOCKED] or not level then return end

    local ce = MBT.CuratedExits
    local pool = ce and ce.Pool and ce.Pool[level]
    local exit = pool and pool[poolIndex]
    if not exit then return end

    local active = state[STATE_EXITS]
    local isActive = false
    if type(active) == 'table' then
        for _, a in ipairs(active) do if a.i == poolIndex then isActive = true break end end
    end
    if not isActive then Utils.MbtDebugger('curatedExit rejected: not active', src, poolIndex); return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - exit.coords) > ((exit.radius or 1.6) + 2.0) then
        Utils.MbtDebugger('curatedExit rejected: not near', src, poolIndex)
        return
    end

    local coords, lvl
    if exit.dest == 'surface' then
        coords, lvl = pickSurface(), false
    else
        coords, lvl = pickBackroom(level) -- never bounce back into the same level
    end
    dispatchTeleport(src, coords, lvl)
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
        activateExits(src, p.level) -- fresh curated exits for this visit
        -- Debug-only: exercise the notification path.
        if MBT.Debug then
            Utils.Notify(src, (MBT.Locale and MBT.Locale.notify_entered) or 'Entered the Backrooms')
        end
    else
        state:set(STATE_INLEVEL, false, true)
        state:set(STATE_ENTRY, false, true)
        state:set(STATE_EXITS, {}, true) -- no curated exits on the surface
    end
end)

-- A freshly (re)connected client reconciles to a clean slate. A relog must never
-- inherit stale "inside a level" state — otherwise the replicated inLevel re-fires
-- the atmosphere and you wake up tinted/locked while actually on the surface.
RegisterNetEvent('mbt_backrooms:clientReady', function()
    Core.ClearState(source)
end)

-- Death inside a level (option A): the death spits you out. Clear state so GTA
-- respawns you on the surface clean, not stuck with the level's effects.
RegisterNetEvent('mbt_backrooms:exitOnDeath', function()
    local src = source
    if not Player(src).state[STATE_INLEVEL] then return end
    Core.ClearState(src)
    -- Return to the surface on respawn so they don't wake up stuck in the empty
    -- backroom (the client teleports once its ped is alive again).
    if MBT.OnDeathReturnSurface ~= false then
        local p = pickSurface()
        if p then TriggerClientEvent('mbt_backrooms:surfaceOnRespawn', src, p) end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Core.ClearState(src)        -- also resets the state bag, so a reused slot can't inherit "inside"
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
        state:set(STATE_EXITS, {}, true)
    end
end)

-- Startup: report which framework / inventory the bridge resolved to.
CreateThread(function()
    Wait(500)
    Utils.MbtDebugger(('bridge resolved: framework=%s inventory=%s')
        :format(Bridge and Bridge.Framework or 'none', Inventory and Inventory.System or 'none'))
end)

-------------------------------------------------------------------------------
-- Core API — used by the admin module (F9). Reuses the authoritative paths.
-------------------------------------------------------------------------------
Core = Core or {}

function Core.SendToLevel(src, n)
    local coords = MBT.Coords[n]
    if not coords then return false end
    dispatchTeleport(src, coords, n)
    return true
end

function Core.SendToSurface(src)
    dispatchTeleport(src, pickSurface(), false)
end

-- Clear a player's backrooms state (unstick + pull out of any level).
function Core.ClearState(src)
    pendingTeleport[src] = nil
    zoneState[src] = nil
    local state = Player(src).state
    state:set(STATE_LOCKED, false, true)
    state:set(STATE_INLEVEL, false, true)
    state:set(STATE_ENTRY, false, true)
    state:set(STATE_EXITS, {}, true)
end

function Core.GetState(src)
    local state = Player(src).state
    return {
        inLevel = state[STATE_INLEVEL] or false,
        locked = state[STATE_LOCKED] or false,
        sanity = state['mbt_backrooms:sanity'],
        entry = state[STATE_ENTRY] or false,
    }
end
