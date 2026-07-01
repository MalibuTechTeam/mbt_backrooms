-- Almond Water (F4 survival) — client. Renders the server-scattered bottles as
-- props, shows an [E] "drink" prompt on proximity, drinks on press. Mirrors the
-- artifacts module (own [E] keymapping; both fire and no-op when not relevant).

local cfg = MBT.AlmondWater
local STATE_INLEVEL = 'mbt_backrooms:inLevel'
local STATE_WATER   = 'mbt_backrooms:almondwater'

local props, current, taken = {}, {}, {}
local nearestIdx, shownIdx = nil, nil

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
    local model = cfg.PropModel or 'prop_ld_flow_bottle'
    local hash = joaat(model)
    RequestModel(hash)
    local t = 2000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then
        MBTLog.Warn('almond water prop failed to load — swap MBT.AlmondWater.PropModel:', model)
        return
    end
    local obj = CreateObject(hash, x, y, z + 1.0, false, false, false) -- raised: see artifacts spawnProp
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
        local active = LocalPlayer.state[STATE_INLEVEL] and LocalPlayer.state[STATE_WATER]

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
                            label = (MBT.Locale and MBT.Locale.prompt_drink) or 'drink',
                            type = 'drink',
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

local drinking = false

-- Play the drink animation (ox-style) with a bottle in hand for UseTime, then cb().
local function playDrink(cb)
    local ped = PlayerPedId()
    local useTime = cfg.UseTime or 2500
    local prop = nil

    local hp = cfg.HeldProp
    if hp and hp.model then
        local h = GetHashKey(hp.model)
        RequestModel(h)
        local t = 1000
        while not HasModelLoaded(h) and t > 0 do Wait(20); t = t - 20 end
        if HasModelLoaded(h) then
            local c = GetEntityCoords(ped)
            -- Match ox_inventory exactly so its tuned pos/rot read correctly: default
            -- bone 60309 (IK_L_Hand) + the same attach flags/rotation order as
            -- ox_lib's progress.lua (rotOrder 0). Override via HeldProp.bone/rotOrder.
            prop = CreateObject(h, c.x, c.y, c.z, false, false, false)
            local bone = GetPedBoneIndex(ped, hp.bone or 60309)
            AttachEntityToEntity(prop, ped, bone, hp.pos.x, hp.pos.y, hp.pos.z,
                hp.rot.x, hp.rot.y, hp.rot.z, true, true, false, true, hp.rotOrder or 0, true)
            SetModelAsNoLongerNeeded(h)
        end
    end

    local anim = cfg.Anim
    if anim and anim.dict then
        RequestAnimDict(anim.dict)
        local t = 1000
        while not HasAnimDictLoaded(anim.dict) and t > 0 do Wait(20); t = t - 20 end
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, useTime, 49, 0.0, false, false, false)
    end

    SetTimeout(useTime, function()
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        if anim and anim.dict then StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 3.0) end
        cb()
    end)
end

RegisterCommand('mbt_almond_drink', function()
    if not nearestIdx or isLocked() or drinking then return end
    -- Skip if already (near) full — server would refuse anyway.
    if (LocalPlayer.state['mbt_backrooms:sanity'] or 100) >= (MBT.Sanity.FullThreshold or 98) then return end
    drinking = true
    local idx = nearestIdx
    playDrink(function()
        drinking = false
        TriggerServerEvent('mbt_backrooms:requestDrink', idx)
    end)
end, false)
RegisterKeyMapping('mbt_almond_drink',
    (MBT.Locale and MBT.Locale.keymapping_drink) or 'Backrooms: drink Almond Water',
    'keyboard', MBT.General.InteractKey)

-- Drank: remove the prop (the sanity vignette eases on its own).
RegisterNetEvent('mbt_backrooms:almondDrunk', function(poolIndex)
    taken[poolIndex] = true
    local obj = props[poolIndex]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    props[poolIndex], current[poolIndex] = nil, nil
    if shownIdx == poolIndex then hidePrompt() end
end)

AddStateBagChangeHandler(STATE_INLEVEL, '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    taken = {}
    if not value then clearProps() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearProps() end
end)

-- Debug: pale marker on each active bottle (within 60m) + a list command, to spot
-- bottles that landed in the void / behind geometry while placing the pool.
if MBT.Debug then
    RegisterCommand('bralmond', function()
        local active = LocalPlayer.state[STATE_WATER]
        if type(active) ~= 'table' or #active == 0 then
            MBTLog.Debug('bralmond: no active bottles (must be inside a level)')
            return
        end
        local pc = GetEntityCoords(PlayerPedId())
        for _, a in ipairs(active) do
            MBTLog.Debug(('bralmond: #%d  dist=%.1f  (%.1f, %.1f, %.1f)')
                :format(a.i, #(pc - vector3(a.x, a.y, a.z)), a.x, a.y, a.z))
        end
    end, false)

    CreateThread(function()
        while true do
            local sleep = 1000
            local active = LocalPlayer.state[STATE_INLEVEL] and LocalPlayer.state[STATE_WATER]
            if type(active) == 'table' and #active > 0 then
                local pc = GetEntityCoords(PlayerPedId())
                for _, a in ipairs(active) do
                    if MBT.DebugMarkers ~= false and #(pc - vector3(a.x, a.y, a.z)) < 60.0 then
                        sleep = 0
                        DrawMarker(1, a.x, a.y, a.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.6, 0.6, 2.0, 200, 230, 180, 120, false, false, 2, false, nil, nil, false)
                    end
                end
            end
            Wait(sleep)
        end
    end)
end
