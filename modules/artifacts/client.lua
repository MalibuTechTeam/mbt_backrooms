-- Found tapes/logs (F3 / Wave 1) — client. Renders the server-scattered artifacts
-- as in-world props, shows an [E] "take" prompt on proximity, and on pickup plays a
-- found-footage caption (the lore reward). The [E] keymapping is separate from the
-- Enter/Exit one in core/client.lua; both fire on the key and each no-ops when not
-- relevant. Prompt writes are transition-based so they don't fight core's prompt.

local cfg = MBT.Artifacts
local STATE_INLEVEL   = 'mbt_backrooms:inLevel'
local STATE_ARTIFACTS = 'mbt_backrooms:artifacts'

local props = {}     -- props[poolIndex] = object handle
local current = {}   -- current[poolIndex] = { x, y, z, type }
local taken = {}     -- locally-collected indices — suppress respawn until the level changes
                     -- (the state bag may still list a just-collected artifact for a frame)
local nearestIdx = nil
local shownIdx = nil

local function isLocked()
    return LocalPlayer.state['mbt_backrooms:exitLocked'] == true
end

local function hidePrompt()
    if shownIdx ~= nil then
        shownIdx = nil
        SendNUIMessage({ action = 'prompt:set', data = { visible = false } })
    end
end

local function clearProps()
    for i, obj in pairs(props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        props[i] = nil
    end
    current, nearestIdx, taken = {}, nil, {}
    hidePrompt()
end

local function spawnProp(i, x, y, z)
    local model = cfg.PropModel or 'prop_notepad_01'
    local hash = joaat(model)
    RequestModel(hash)
    local t = 2000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then
        MBTLog.Warn('artifact prop failed to load — swap MBT.Artifacts.PropModel:', model)
        return
    end
    -- spawn slightly ABOVE the configured z so PlaceObjectOnGroundProperly can
    -- raycast down onto the real floor (placeholder z values may sit under it).
    local obj = CreateObject(hash, x, y, z + 1.0, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    props[i] = obj
    if MBT.Debug then MBTLog.Debug('artifact prop spawned', model, 'i', i, 'at', x, y, z, 'handle', obj) end
end

CreateThread(function()
    if not cfg or not cfg.Enabled then return end

    while true do
        local sleep = 700
        local active = LocalPlayer.state[STATE_INLEVEL] and LocalPlayer.state[STATE_ARTIFACTS]

        if type(active) == 'table' and #active > 0 then
            local want = {}
            for _, a in ipairs(active) do if not taken[a.i] then want[a.i] = a end end
            for i, obj in pairs(props) do
                if not want[i] then
                    if DoesEntityExist(obj) then DeleteEntity(obj) end
                    props[i], current[i] = nil, nil
                    if shownIdx == i then hidePrompt() end
                end
            end
            for i, a in pairs(want) do
                if not props[i] then current[i] = a; spawnProp(i, a.x, a.y, a.z) end
            end

            local pc = GetEntityCoords(PlayerPedId())
            local best, bestD = nil, 1e9
            for i, a in pairs(current) do
                local d = #(pc - vector3(a.x, a.y, a.z))
                if d < bestD then bestD, best = d, i end
            end
            nearestIdx = (best and bestD <= (cfg.PickupRange or 1.8)) and best or nil

            if nearestIdx then
                sleep = 200
                if shownIdx ~= nearestIdx then
                    shownIdx = nearestIdx
                    SendNUIMessage({
                        action = 'prompt:set',
                        data = {
                            visible = true,
                            key = MBT.General.InteractKey,
                            label = (MBT.Locale and MBT.Locale.prompt_take) or 'record',
                            type = 'take',
                            reduceMotion = (MBT.Atmosphere and MBT.Atmosphere.ReduceMotion) or false,
                        },
                    })
                end
            else
                hidePrompt()
            end
        elseif next(props) ~= nil then
            clearProps()
        end

        Wait(sleep)
    end
end)

RegisterCommand('mbt_artifact_take', function()
    if nearestIdx and not isLocked() then
        TriggerServerEvent('mbt_backrooms:requestCollect', nearestIdx)
    end
end, false)
RegisterKeyMapping('mbt_artifact_take',
    (MBT.Locale and MBT.Locale.keymapping_take) or 'Backrooms: take recording',
    'keyboard', MBT.General.InteractKey)

-- Server confirmed a pickup: remove the prop, flash the lore caption + a soft blip.
RegisterNetEvent('mbt_backrooms:artifactCollected', function(poolIndex, text, kind)
    taken[poolIndex] = true -- never respawn this one (state bag may still list it briefly)
    local obj = props[poolIndex]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    props[poolIndex], current[poolIndex] = nil, nil
    if shownIdx == poolIndex then hidePrompt() end
    SendNUIMessage({ action = 'log:show', data = { text = text, kind = kind } })
    SendNUIMessage({ action = 'entity:sound', data = { file = 'tape_warble', volume = 0.5 } })
end)

AddStateBagChangeHandler(STATE_INLEVEL, '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    -- Any level change resets the local guard (a new scatter may reuse indices).
    taken = {}
    if not value then clearProps() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearProps() end
end)

-- Debug: dump the artifact pipeline state (server activation -> client props).
if MBT.Debug then
    RegisterCommand('brartifacts', function()
        local active = LocalPlayer.state[STATE_ARTIFACTS]
        local inLevel = LocalPlayer.state[STATE_INLEVEL]
        local n = 0
        for _ in pairs(props) do n = n + 1 end
        MBTLog.Debug(('brartifacts: inLevel=%s  stateCount=%s  spawnedProps=%d  model=%s')
            :format(tostring(inLevel), (type(active) == 'table' and #active or 'nil'), n, cfg.PropModel or 'nil'))
        if type(active) == 'table' then
            local pc = GetEntityCoords(PlayerPedId())
            for _, a in ipairs(active) do
                MBTLog.Debug(('  #%d  dist=%.1f  (%.1f, %.1f, %.1f)  type=%s')
                    :format(a.i, #(pc - vector3(a.x, a.y, a.z)), a.x, a.y, a.z, a.type or '?'))
            end
        end
    end, false)
end
