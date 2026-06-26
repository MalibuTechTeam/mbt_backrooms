-- Archive terminal placement (Section 10). The TV's transform is placed in-game by
-- an admin (/brsetarchive) and persisted server-side via KVP, so it survives restarts
-- and is shared by every client. (The recovered-ids reply lives in artifacts/server.)

local cfg = MBT.Archive
if not (cfg and cfg.Enabled) then return end

local PERM = 'mbt_backrooms.admin'
local KEY  = 'mbt_backrooms:archiveTransform'
local transform

local function load()
    local raw = GetResourceKvpString(KEY)
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then transform = t end
    end
    if not transform and cfg.DefaultSpawn then transform = cfg.DefaultSpawn end
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then load() end
end)

-- A client (re)spawning asks for the current transform.
RegisterNetEvent('mbt_backrooms:requestArchiveTransform', function()
    if transform then TriggerClientEvent('mbt_backrooms:archiveTransform', source, transform) end
end)

-- Admin places it at their position; persist + broadcast to everyone.
RegisterNetEvent('mbt_backrooms:placeArchive', function(t)
    local src = source
    if src ~= 0 and not MBT.Debug and not IsPlayerAceAllowed(src, PERM) then return end
    if type(t) ~= 'table' or not (t.x and t.y and t.z) then return end
    transform = { x = t.x + 0.0, y = t.y + 0.0, z = t.z + 0.0, h = (t.h or 0.0) + 0.0 }
    if type(t.cam) == 'table' then transform.cam = t.cam end       -- persisted camera framing
    if type(t.screen) == 'table' then transform.screen = t.screen end -- persisted screen rect geometry
    SetResourceKvp(KEY, json.encode(transform))
    TriggerClientEvent('mbt_backrooms:archiveTransform', -1, transform)
    if Utils and Utils.Notify then Utils.Notify(src, 'Archive terminal saved.') end
end)

-- Admin removes the terminal; clear KVP + tell everyone to despawn it.
RegisterNetEvent('mbt_backrooms:removeArchive', function()
    local src = source
    if src ~= 0 and not MBT.Debug and not IsPlayerAceAllowed(src, PERM) then return end
    transform = nil
    DeleteResourceKvp(KEY)
    TriggerClientEvent('mbt_backrooms:archiveRemoved', -1)
    if Utils and Utils.Notify then Utils.Notify(src, 'Archive terminal removed.') end
end)
