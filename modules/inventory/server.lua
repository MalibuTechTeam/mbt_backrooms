-- Inventory abstraction. Detected SEPARATELY from the framework bridge — a
-- server can run e.g. ESX + ox_inventory. Wired here for 2.0 but only exercised
-- from 2.1 (Almond Water + survival items); no item is granted/used in 2.0.
Inventory = Inventory or {}

local function detect()
    if GetResourceState('ox_inventory') == 'started' then return 'ox' end
    if GetResourceState('qb-inventory') == 'started' then return 'qb' end
    if GetResourceState('qs-inventory') == 'started' then return 'qs' end
    return 'none'
end

Inventory.System = detect()

local function qbPlayer(src)
    local core = exports['qb-core'] and exports['qb-core']:GetCoreObject()
    return core and core.Functions.GetPlayer(src) or nil
end

function Inventory.Has(src, item, count)
    count = count or 1
    local sys = Inventory.System
    if sys == 'ox' then
        return (exports.ox_inventory:GetItemCount(src, item) or 0) >= count
    elseif sys == 'qb' then
        local p = qbPlayer(src)
        local it = p and p.Functions.GetItemByName(item)
        return it ~= nil and it.amount >= count
    elseif sys == 'qs' then
        return (exports['qs-inventory']:GetItemTotalAmount(src, item) or 0) >= count
    end
    return false
end

function Inventory.Add(src, item, count)
    count = count or 1
    local sys = Inventory.System
    if sys == 'ox' then
        return exports.ox_inventory:AddItem(src, item, count)
    elseif sys == 'qb' then
        local p = qbPlayer(src)
        return p and p.Functions.AddItem(item, count) or false
    elseif sys == 'qs' then
        return exports['qs-inventory']:AddItem(src, item, count)
    end
    return false
end

function Inventory.Remove(src, item, count)
    count = count or 1
    local sys = Inventory.System
    if sys == 'ox' then
        return exports.ox_inventory:RemoveItem(src, item, count)
    elseif sys == 'qb' then
        local p = qbPlayer(src)
        return p and p.Functions.RemoveItem(item, count) or false
    elseif sys == 'qs' then
        return exports['qs-inventory']:RemoveItem(src, item, count)
    end
    return false
end

Utils.MbtDebugger('inventory: system =', Inventory.System)
