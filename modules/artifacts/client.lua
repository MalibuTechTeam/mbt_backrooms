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
    current, nearestIdx = {}, nil
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
    local obj = CreateObject(hash, x, y, z, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    props[i] = obj
end

CreateThread(function()
    if not cfg or not cfg.Enabled then return end

    while true do
        local sleep = 700
        local active = LocalPlayer.state[STATE_INLEVEL] and LocalPlayer.state[STATE_ARTIFACTS]

        if type(active) == 'table' and #active > 0 then
            -- sync props to the active set
            local want = {}
            for _, a in ipairs(active) do want[a.i] = a end
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

            -- proximity -> nearest within pickup range
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
    if not value then clearProps() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearProps() end
end)
