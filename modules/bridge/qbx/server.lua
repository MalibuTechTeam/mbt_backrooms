if GetResourceState('qbx_core') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'qbx'

-- qbx stacks use ox_lib for notifications.
function Bridge.Notify(src, msg)
    TriggerClientEvent('ox_lib:notify', src, { description = msg })
end

Utils.MbtDebugger('bridge: qbx loaded')
