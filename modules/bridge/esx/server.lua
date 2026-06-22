if GetResourceState('es_extended') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'esx'

function Bridge.Notify(src, msg)
    TriggerClientEvent('esx:showNotification', src, msg)
end

Utils.MbtDebugger('bridge: esx loaded')
