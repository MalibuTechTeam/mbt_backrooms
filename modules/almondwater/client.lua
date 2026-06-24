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
            prop = CreateObject(h, c.x, c.y, c.z, true, true, false)
            local bone = GetPedBoneIndex(ped, 57005) -- SKEL_R_Hand
            AttachEntityToEntity(prop, ped, bone, hp.pos.x, hp.pos.y, hp.pos.z,
                hp.rot.x, hp.rot.y, hp.rot.z, false, false, false, false, 2, true)
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
