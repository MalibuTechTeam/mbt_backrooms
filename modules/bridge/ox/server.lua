if GetResourceState('ox_core') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'ox'

-- ox stacks use ox_lib for notifications.
function Bridge.Notify(src, msg)
    TriggerClientEvent('ox_lib:notify', src, { description = msg })
end

Utils.MbtDebugger('bridge: ox loaded')
